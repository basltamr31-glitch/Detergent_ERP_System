import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'access_control.dart';
import 'record_id.dart';

/// PBKDF2-HMAC-SHA256, one 256-bit block. Runs in an isolate for interactive UI.
String derivePassword(Map<String, dynamic> input) {
  final hmac = Hmac(sha256, utf8.encode(input['password'] as String));
  final salt = base64Decode(input['salt'] as String);
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(block);
  for (var i = 1; i < input['iterations']; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return base64Encode(result);
}

class AuthService extends ChangeNotifier {
  AuthService._(this._box, this._data);
  final Box<String> _box;
  Map<String, dynamic> _data;
  bool _saving = false;
  bool get busy => _saving;
  Map<String, String>? get user => AccessControl.user;
  bool get needsSetup => (_data['users'] as List).isEmpty;
  List<Map<String, dynamic>> get users => List.unmodifiable(
      (_data['users'] as List).map((u) => Map<String, dynamic>.unmodifiable({
            'id': u['id'],
            'name': u['name'],
            'role': u['role'],
            'active': u['active']
          })));
  static const roles = [
    'owner',
    'manager',
    'accountant',
    'warehouse',
    'cashier',
    'viewer'
  ];
  static Future<AuthService> open() async {
    final box = await Hive.openBox<String>('local_users_v1');
    final value = box.get('state');
    final data = value == null
        ? <String, dynamic>{'version': 1, 'users': [], 'events': []}
        : Map<String, dynamic>.from(jsonDecode(value));
    if (data['version'] != 1) {
      throw const FormatException('Unsupported local-user data.');
    }
    final ids = <String>{}, names = <String>{};
    for (final u in data['users'] as List) {
      if (u['id'] is! String ||
          !ids.add(u['id']) ||
          u['name'] is! String ||
          !names.add(u['name'].toLowerCase()) ||
          !roles.contains(u['role']) ||
          u['active'] is! bool ||
          u['iterations'] != 600000 ||
          base64Decode(u['salt']).length != 16 ||
          base64Decode(u['hash']).length != 32) {
        throw const FormatException('Invalid local-user data.');
      }
    }
    if ((data['users'] as List).isNotEmpty &&
        !(data['users'] as List)
            .any((u) => u['active'] && u['role'] == 'owner')) {
      throw const FormatException('No active owner account.');
    }
    return AuthService._(box, data);
  }

  Future<void> _save(Map<String, dynamic> data) async {
    try {
      await _box.put('state', jsonEncode(data));
      await _box.flush();
      _data = data;
    } catch (_) {
      _data = Map<String, dynamic>.from(
          jsonDecode(_box.get('state') ?? jsonEncode(_data)));
      rethrow;
    }
  }

  Future<void> saveUser(
      {String? id,
      required String name,
      required String role,
      String password = '',
      bool active = true}) async {
    if (_saving) throw StateError('User operation is busy.');
    if (!needsSetup) AccessControl.require('admin');
    name = name.trim();
    if (name.isEmpty ||
        !roles.contains(role) ||
        (needsSetup && (role != 'owner' || !active))) {
      throw ArgumentError('Valid name and owner setup are required.');
    }
    if (id == null || password.isNotEmpty) {
      if (password.length < 12 || password.length > 128) {
        throw ArgumentError('Use a password with 12–128 characters.');
      }
    }
    _saving = true;
    notifyListeners();
    try {
      final data = Map<String, dynamic>.from(jsonDecode(jsonEncode(_data)));
      final users = data['users'] as List;
      if (users.any((u) =>
          u['id'] != id && u['name'].toLowerCase() == name.toLowerCase())) {
        throw ArgumentError('Username already exists.');
      }
      final existing =
          id == null ? null : users.firstWhere((u) => u['id'] == id);
      final updated = existing == null
          ? <String, dynamic>{'id': RecordId.create()}
          : Map<String, dynamic>.from(existing);
      updated.addAll({'name': name, 'role': role, 'active': active});
      if (password.isNotEmpty) {
        final random = Random.secure();
        final salt =
            base64Encode(List.generate(16, (_) => random.nextInt(256)));
        final hash = await compute(derivePassword,
            {'password': password, 'salt': salt, 'iterations': 600000});
        updated.addAll({
          'salt': salt,
          'hash': hash,
          'iterations': 600000,
          'failures': 0,
          'retryAt': null
        });
      }
      if (!needsSetup) AccessControl.require('admin');
      if (id == null) {
        users.add(updated);
      } else {
        users[users.indexOf(existing)] = updated;
      }
      if (!users.any((u) => u['role'] == 'owner' && u['active'])) {
        throw StateError('Keep at least one active owner.');
      }
      (data['events'] as List).add({
        'id': RecordId.create(),
        'date': DateTime.now().toUtc().toIso8601String(),
        'actor': AccessControl.actor,
        'kind': 'userUpdated',
        'userId': updated['id'],
        'role': role,
        'active': active
      });
      await _save(data);
      if (AccessControl.user?['id'] == id) {
        AccessControl.user =
            active ? {'id': updated['id'], 'name': name, 'role': role} : null;
      }
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> login(String name, String password) async {
    if (_saving) throw StateError('Authentication is busy.');
    if (password.length > 128) throw ArgumentError('Password is too long.');
    _saving = true;
    notifyListeners();
    try {
      final data = Map<String, dynamic>.from(jsonDecode(jsonEncode(_data)));
      final matches = (data['users'] as List)
          .where((u) => u['name'].toLowerCase() == name.trim().toLowerCase());
      if (matches.isEmpty) throw StateError('Invalid username or password.');
      final u = matches.single;
      if (!u['active'] ||
          (u['retryAt'] != null &&
              DateTime.parse(u['retryAt']).isAfter(DateTime.now().toUtc()))) {
        throw StateError('Account is inactive or temporarily locked.');
      }
      final computed = await compute(derivePassword, {
        'password': password,
        'salt': u['salt'],
        'iterations': u['iterations']
      });
      final expected = base64Decode(u['hash']), actual = base64Decode(computed);
      var difference = 0;
      for (var i = 0; i < expected.length; i++) {
        difference |= expected[i] ^ actual[i];
      }
      if (difference != 0) {
        u['failures'] = (u['failures'] as int? ?? 0) + 1;
        if (u['failures'] >= 5) {
          u['retryAt'] = DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String();
        }
        await _save(data);
        throw StateError('Invalid username or password.');
      }
      u['failures'] = 0;
      u['retryAt'] = null;
      (data['events'] as List).add({
        'id': RecordId.create(),
        'date': DateTime.now().toUtc().toIso8601String(),
        'kind': 'login',
        'userId': u['id']
      });
      await _save(data);
      AccessControl.user = {
        'id': u['id'],
        'name': u['name'],
        'role': u['role']
      };
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void logout() {
    AccessControl.user = null;
    notifyListeners();
  }
}
