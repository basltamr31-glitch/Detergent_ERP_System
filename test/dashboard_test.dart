import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/screens/main_menu_screen.dart';
import 'package:detergent_factory/services/access_control.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets(
          'Dashboard balances and module navigation at $width in $locale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        late WarehouseProvider wh;
        late ShopProvider shop;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('dashboard_');
          Hive.init(directory.path);
          AccessControl.enabled = false;
          AccessControl.user = null;
          wh = WarehouseProvider();
          shop = ShopProvider();
          await wh.ready;
          await shop.ready;
          await wh.receivePurchase(
              materialName: 'Water',
              quantity: 10,
              unit: 'Kilogram',
              unitPriceMinor: 100,
              supplier: 'Supplier',
              currency: 'USD',
              paidMinor: 200,
              requestId: 'purchase');
          await shop.addProduct('Cleaner', 10, 'Piece', 5);
          await shop.sellProduct('Cleaner', 2,
              unitPriceMinor: 500,
              customer: 'Customer',
              currency: 'USD',
              paidMinor: 300,
              requestId: 'sale');
        });
        addTearDown(() async {
          wh.dispose();
          shop.dispose();
          AccessControl.enabled = false;
          AccessControl.user = null;
          await Hive.close();
          await directory.delete(recursive: true);
        });
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: wh),
              ChangeNotifierProvider.value(value: shop),
            ],
            child: MaterialApp(
                locale: Locale(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (_, child) => MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 1000),
                        textScaler: const TextScaler.linear(1.4)),
                    child: child!),
                home: const MainMenuScreen())));
        await tester.pumpAndSettle();
        expect(find.text('7.00 USD'), findsOneWidget);
        expect(find.text('8.00 USD'), findsOneWidget);
        final reconciliation = find.text(locale == 'ar'
            ? 'أرصدة المستندات مطابقة للدفتر'
            : 'Document balances agree with ledger');
        await tester.scrollUntilVisible(reconciliation, 200);
        expect(reconciliation, findsOneWidget);
        expect(tester.takeException(), isNull);
        final currency = find.byKey(const ValueKey('dashboard-currency'));
        await tester.scrollUntilVisible(currency, -200);
        await Scrollable.ensureVisible(tester.element(currency),
            alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(currency);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SYP').last);
        await tester.pumpAndSettle();
        expect(find.text('0.00 SYP'), findsNWidgets(4));
        final module = find.byKey(const ValueKey('module-finance'));
        await tester.scrollUntilVisible(module, 250);
        await tester.pumpAndSettle();
        await tester.tap(module);
        await tester.pumpAndSettle();
        expect(
            find.text(locale == 'ar'
                ? 'مطابقة المستندات'
                : 'Document reconciliation'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
