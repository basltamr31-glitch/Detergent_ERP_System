import 'access_control.dart';
import 'inventory_coordinator.dart';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'state_schema.dart';

class BackupService {
  static const maxBytes = 20 * 1024 * 1024;
  static int checksum(String value) {
    var crc = 0xffffffff;
    for (final byte in utf8.encode(value)) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    return crc ^ 0xffffffff;
  }

  static Map<String, dynamic> validatePayload(dynamic value) {
    final payload = StateSchema.object(value);
    StateSchema.inventory(
        'warehouse', StateSchema.object(payload['warehouse']));
    StateSchema.inventory('shop', StateSchema.object(payload['shop']));
    StateSchema.pair(StateSchema.object(payload['warehouse']),
        StateSchema.object(payload['shop']));
    StateSchema.draft('production', StateSchema.object(payload['production']));
    StateSchema.draft('packaging', StateSchema.object(payload['packaging']));
    return payload;
  }

  static String encode(Map<String, dynamic> payload) {
    AccessControl.require('backup');
    validatePayload(payload);
    final content = jsonEncode(payload);
    return jsonEncode({
      'format': 'detergent-factory-backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'checksum': checksum(content),
      'payload': content
    });
  }

  static Map<String, dynamic> decode(String value) {
    if (utf8.encode(value).length > maxBytes) {
      throw const FormatException('Backup file is too large.');
    }
    final envelope = StateSchema.object(jsonDecode(value));
    if (envelope['format'] != 'detergent-factory-backup' ||
        envelope['version'] != 1) {
      throw const FormatException('Unsupported backup format.');
    }
    final payload = envelope['payload'] as String;
    if (checksum(payload) != envelope['checksum']) {
      throw const FormatException('Backup checksum mismatch.');
    }
    return validatePayload(jsonDecode(payload));
  }

  static Future<File> write(String path, Map<String, dynamic> payload) async {
    final value = encode(payload);
    if (utf8.encode(value).length > maxBytes) {
      throw const FormatException('Backup file is too large.');
    }
    final target = File(path);
    if (await target.exists()) {
      throw StateError('Choose a new backup filename.');
    }
    final temporary = File('$path.partial');
    await temporary.writeAsString(value, flush: true);
    decode(await temporary.readAsString());
    return temporary.rename(path);
  }

  static Future<Map<String, dynamic>> read(String path) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const FormatException('Backup file is too large.');
    }
    return decode(await file.readAsString());
  }

  static Future<void> _apply(Map<String, dynamic> payload) async {
    for (final key in ['warehouse', 'shop']) {
      final box = await Hive.openBox<String>('${key}_state_v1');
      await box.put('state', jsonEncode(payload[key]));
      await box.flush();
    }
    final drafts = await Hive.openBox<String>('costing_drafts_v1');
    await drafts.putAll({
      for (final key in ['production', 'packaging'])
        key: jsonEncode(payload[key])
    });
    await drafts.flush();
  }

  static Future<void> restore(Map<String, dynamic> payload) async {
    AccessControl.require('admin');
    InventoryCoordinator.check();
    validatePayload(payload);
    final journal = await Hive.openBox<String>('restore_journal_v1');
    if (journal.containsKey('pending')) {
      throw StateError('Complete the pending restore first.');
    }
    await journal.put('pending', jsonEncode(payload));
    await journal.flush();
    await recover();
  }

  static Future<void> recover() async {
    final journal = await Hive.openBox<String>('restore_journal_v1');
    final pending = journal.get('pending');
    if (pending == null) return;
    final payload = validatePayload(jsonDecode(pending));
    await _apply(payload);
    await journal.delete('pending');
    await journal.flush();
  }

  // Preserve unreadable current data before restoring a valid business backup.
  // This recovery file is for manual repair, not a validated business backup.
  static Future<void> preserveRaw(String path) async {
    AccessControl.require('admin');
    final raw = <String, dynamic>{
      'format': 'detergent-factory-recovery',
      'version': 1
    };
    for (final key in ['warehouse', 'shop']) {
      final box = await Hive.openBox<String>('${key}_state_v1');
      raw[key] = box.get('state');
    }
    final drafts = await Hive.openBox<String>('costing_drafts_v1');
    raw['production'] = drafts.get('production');
    raw['packaging'] = drafts.get('packaging');
    final value = jsonEncode(raw);
    final file = File(path);
    if (await file.exists()) {
      throw StateError('Recovery filename already exists.');
    }
    await file.writeAsString(value, flush: true);
    if (await file.readAsString() != value) {
      throw StateError('Recovery copy verification failed.');
    }
  }
}
