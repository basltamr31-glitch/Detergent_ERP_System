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
import 'package:provider/provider.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';

void main() {
  testWidgets(
      'Windows native credentials open the real ERP and sign back in after logout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    late Directory directory;
    late AuthService auth;
    late WarehouseProvider warehouse;
    late ShopProvider shop;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('native_login_');
      Hive.init(directory.path);
      await Hive.openBox<String>('costing_drafts_v1');
      // Prepare persisted stores in real async time; the app still creates its
      // own providers, while widget pumps exercise the existing-user flow.
      warehouse = WarehouseProvider();
      shop = ShopProvider();
      await warehouse.ready;
      await shop.ready;
      AccessControl.enabled = true;
      AccessControl.user = null;
      auth = await AuthService.open();
    });
    int prompts = 0;
    int trialLaunches = 0;
    bool cancel = true;
    bool wrongAccount = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WindowsCredentials.channel,
        (call) async {
      if (call.method == 'openTestWorkspace') {
        trialLaunches++;
        return null;
      }
      expect(call.method, 'prompt');
      prompts++;
      if (cancel) return null;
      expect(call.arguments['setup'], auth.needsSetup);
      if (wrongAccount) {
        return {'name': 'Missing account', 'password': 'Not the password'};
      }
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
    await tester
        .pumpWidget(MyApp(auth: auth, warehouse: warehouse, shop: shop));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-test-workspace')));
    await tester.pumpAndSettle();
    expect(trialLaunches, 1);
    expect(auth.user, isNull);
    expect(auth.needsSetup, true);
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
    await tester.pump();
    for (var i = 0;
        i < 10 && find.byType(MainMenuScreen).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final dashboard = tester.element(find.byType(MainMenuScreen));
    expect(dashboard.read<WarehouseProvider>(), same(warehouse));
    expect(dashboard.read<ShopProvider>(), same(shop));
    for (var i = 0; i < 10 && (!warehouse.isLoaded || !shop.isLoaded); i++) {
      await tester.pump();
    }
    expect(warehouse.isLoaded, true);
    expect(shop.isLoaded, true);
    await tester.pumpAndSettle();
    expect(find.byType(MainMenuScreen), findsOneWidget);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('test-sign-in')), findsNothing);
    expect(find.byKey(const ValueKey('test-profile-banner')), findsNothing);
    wrongAccount = true;
    await tester.runAsync(() async {
      await tester.tap(find.byType(FilledButton));
      // Native dialog and authentication are asynchronous even for an unknown user.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
    expect(find.textContaining('START-TEST.cmd'), findsOneWidget);
    wrongAccount = false;
    await submit();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(prompts, 4);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
