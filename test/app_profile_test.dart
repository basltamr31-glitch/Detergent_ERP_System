import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/app_profile.dart';
import 'package:detergent_factory/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Trial storage is enabled only by the explicit demo argument', () {
    expect(AppProfile.fromArguments([]).isTest, false);
    expect(AppProfile.fromArguments(['--demonstration']).isTest, false);
    expect(AppProfile.fromArguments(['--demo']).isTest, true);
  });

  test('Production profile never provisions the shared tester account',
      () async {
    final root = await Directory.systemTemp.createTemp('production_profile_');
    Hive.init(root.path);
    AccessControl.enabled = true;
    AccessControl.user = null;
    final auth = await AuthService.open();
    try {
      await const AppProfile().prepareAccount(auth);
      expect(auth.needsSetup, true);
      expect(auth.users, isEmpty);
    } finally {
      auth.dispose();
      AccessControl.enabled = false;
      await Hive.close();
      await root.delete(recursive: true);
    }
  });

  test(
      'Trial bootstrap persists access and records without touching business boxes',
      () async {
    final root = await Directory.systemTemp.createTemp('isolated_profile_');
    final business = await Directory('${root.path}/documents').create();
    final support = await Directory('${root.path}/support').create();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getApplicationSupportDirectory');
      return support.path;
    });
    AuthService? auth;
    AccessControl.enabled = true;
    AccessControl.user = null;
    try {
      Hive.init(business.path);
      auth = await AuthService.open();
      await auth.saveUser(
          name: 'Business owner',
          role: 'owner',
          password: 'Private owner password 123');
      final before = Hive.box<String>('local_users_v1').get('state');
      final originalBox = await Hive.openBox<String>('business_sentinel');
      await originalBox.put('record', 'existing real record');
      auth.dispose();
      auth = null;
      await Hive.close();

      const trial = AppProfile(isTest: true);
      await trial.initializeStorage();
      auth = await AuthService.open();
      await trial.prepareAccount(auth);
      expect(auth.user, isNull);
      expect(auth.users.single['name'], AppProfile.testerName);
      expect(Hive.box<String>('local_users_v1').get('state'),
          isNot(contains(AppProfile.testerPassword)));
      await auth.login(AppProfile.testerName, AppProfile.testerPassword);
      expect(auth.user!['role'], 'owner');
      final trialBox = await Hive.openBox<String>('business_sentinel');
      expect(trialBox.get('record'), isNull);
      await trialBox.put('record', 'saved trial record');
      // An explicitly changed test password must not be silently reset.
      final testerId = auth.users.single['id'] as String;
      await auth.saveUser(
          id: testerId,
          name: AppProfile.testerName,
          role: 'owner',
          password: 'Changed tester password 123');
      auth.logout();
      auth.dispose();
      auth = null;
      await Hive.close();

      await trial.initializeStorage();
      auth = await AuthService.open();
      await trial.prepareAccount(auth);
      await expectLater(
          auth.login(AppProfile.testerName, AppProfile.testerPassword),
          throwsStateError);
      await auth.login(AppProfile.testerName, 'Changed tester password 123');
      expect((await Hive.openBox<String>('business_sentinel')).get('record'),
          'saved trial record');
      auth.logout();
      auth.dispose();
      auth = null;
      await Hive.close();

      Hive.init(business.path);
      auth = await AuthService.open();
      expect(auth.users.single['name'], 'Business owner');
      expect(Hive.box<String>('local_users_v1').get('state'), before);
      expect((await Hive.openBox<String>('business_sentinel')).get('record'),
          'existing real record');
      await expectLater(
          auth.login(AppProfile.testerName, AppProfile.testerPassword),
          throwsStateError);
      await auth.login('Business owner', 'Private owner password 123');
      expect(auth.user!['name'], 'Business owner');
    } finally {
      auth?.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      AccessControl.enabled = false;
      AccessControl.user = null;
      await Hive.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
