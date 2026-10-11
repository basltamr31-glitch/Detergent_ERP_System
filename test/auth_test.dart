import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/services/auth_service.dart';
import 'package:detergent_factory/services/access_control.dart';

void main() {
  test('PBKDF2 result agrees with independent Python SHA256 implementation',
      () {
    expect(
        derivePassword({
          'password': 'password',
          'salt': base64Encode(utf8.encode('salt')),
          'iterations': 2
        }),
        'rk0Mla9rRtMtCt/5KPBt0CowP47zwlHf1uLYWpVHTEM=');
  });
  test(
      'Owner setup, hashed passwords, role restrictions and owner retention persist',
      () async {
    final directory = await Directory.systemTemp.createTemp('erp_auth_');
    Hive.init(directory.path);
    AccessControl.enabled = true;
    AccessControl.user = null;
    final auth = await AuthService.open();
    try {
      await expectLater(
          auth.saveUser(name: 'Owner', role: 'owner', password: 'short'),
          throwsArgumentError);
      await auth.saveUser(
          name: 'Owner', role: 'owner', password: 'Test password 12345');
      expect(auth.needsSetup, false);
      expect(
          Hive.box<String>('local_users_v1')
              .get('state')!
              .contains('Test password 12345'),
          false);
      await expectLater(
          auth.login('Owner', 'Incorrect password'), throwsStateError);
      await auth.login('Owner', 'Test password 12345');
      expect(auth.user!['role'], 'owner');
      final owner = auth.users.single;
      await expectLater(
          auth.saveUser(id: owner['id'], name: 'Owner', role: 'viewer'),
          throwsStateError);
      await auth.saveUser(
          name: 'Read only', role: 'viewer', password: 'Viewer password 12345');
      auth.logout();
      expect(AccessControl.allows('sales'), false);
      await auth.login('Read only', 'Viewer password 12345');
      await expectLater(
          auth.saveUser(
              name: 'Unauthorized',
              role: 'owner',
              password: 'Test password 12345'),
          throwsStateError);
      expect(AccessControl.allows('warehouse'), false);
      final reopened = await AuthService.open();
      expect(reopened.users.length, 2);
      reopened.dispose();
    } finally {
      auth.dispose();
      AccessControl.enabled = false;
      AccessControl.user = null;
      await Hive.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
