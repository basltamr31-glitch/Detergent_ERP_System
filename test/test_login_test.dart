import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/main.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/screens/auth_screen.dart';
import 'package:detergent_factory/screens/language_selection_screen.dart';
import 'package:detergent_factory/screens/main_menu_screen.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/app_profile.dart';
import 'package:detergent_factory/services/auth_service.dart';
import 'package:detergent_factory/services/windows_credentials.dart';

void main() {
  testWidgets(
      'Windows trial button reaches dashboard without typing or a native prompt and works after logout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory root;
    late AuthService auth;
    late WarehouseProvider warehouse;
    late ShopProvider shop;
    const profile = AppProfile(isTest: true);
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('trial_login_');
      Hive.init(root.path);
      await Hive.openBox<String>('costing_drafts_v1');
      warehouse = WarehouseProvider();
      shop = ShopProvider();
      await warehouse.ready;
      await shop.ready;
      AccessControl.enabled = true;
      AccessControl.user = null;
      auth = await AuthService.open();
      await profile.prepareAccount(auth);
    });
    int prompts = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WindowsCredentials.channel, (_) async {
      prompts++;
      throw StateError('The test shortcut must not open the Windows dialog');
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(WindowsCredentials.channel, null);
      debugDefaultTargetPlatformOverride = null;
      auth.dispose();
      AccessControl.enabled = false;
      AccessControl.user = null;
      await Hive.close();
      await root.delete(recursive: true);
    });

    await tester.pumpWidget(
        MyApp(auth: auth, warehouse: warehouse, shop: shop, profile: profile));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-profile-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('test-sign-in')), findsOneWidget);
    expect(
        tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data),
        contains(
            'Username: ${AppProfile.testerName}\nPassword: ${AppProfile.testerPassword}'));
    Future<void> enter() async {
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('test-sign-in')));
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (auth.user == null || auth.busy) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Test sign-in timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
    }

    await enter();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.byType(MainMenuScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('test-profile-banner')), findsOneWidget);
    expect(auth.user!['name'], AppProfile.testerName);
    expect(prompts, 0);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    await enter();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(prompts, 0);
    auth.logout();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use in-app fields'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('auth-username')), AppProfile.testerName);
    await tester.enterText(
        find.byKey(const ValueKey('auth-password')), AppProfile.testerPassword);
    await tester.runAsync(() async {
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (auth.user == null || auth.busy) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Manual tester sign-in timed out');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(prompts, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
