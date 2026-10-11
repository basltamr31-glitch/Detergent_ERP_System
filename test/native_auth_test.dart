import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/main.dart';
import 'package:detergent_factory/screens/auth_screen.dart';
import 'package:detergent_factory/screens/language_selection_screen.dart';
import 'package:detergent_factory/screens/main_menu_screen.dart';
import 'package:detergent_factory/services/auth_service.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/windows_credentials.dart';

void main() {
  testWidgets(
      'Windows native credentials open the real ERP and sign back in after logout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    late Directory directory;
    late AuthService auth;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('native_login_');
      Hive.init(directory.path);
      await Hive.openBox<String>('costing_drafts_v1');
      AccessControl.enabled = true;
      AccessControl.user = null;
      auth = await AuthService.open();
    });
    int prompts = 0;
    bool cancel = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WindowsCredentials.channel,
        (call) async {
      expect(call.method, 'prompt');
      prompts++;
      if (cancel) return null;
      expect(call.arguments['setup'], auth.needsSetup);
      return {'name': 'باسل', 'password': 'Native test password 123'};
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(WindowsCredentials.channel, null);
      debugDefaultTargetPlatformOverride = null;
      auth.dispose();
      AccessControl.enabled = false;
      AccessControl.user = null;
      await Hive.close();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(MyApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(auth.needsSetup, true);
    expect(prompts, 1);
    cancel = false;
    Future<void> submit() async {
      await tester.runAsync(() async {
        await tester.tap(find.byType(FilledButton));
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (auth.user == null || auth.busy) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('ERP sign-in did not complete');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
    }

    await submit();
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(auth.user!['name'], 'باسل');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.byType(MainMenuScreen), findsOneWidget);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    await submit();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(prompts, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
