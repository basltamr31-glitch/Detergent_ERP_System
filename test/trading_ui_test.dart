import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/screens/finished_product_screen.dart';
import 'package:detergent_factory/screens/trading_purchase_screen.dart';
import 'package:detergent_factory/screens/trade_entry_screen.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets(
          'Trading receipt converts cartons and shows source cost at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        late WarehouseProvider warehouse;
        late ShopProvider shop;
        late String productId;
        await tester.runAsync(() async {
          AccessControl.enabled = false;
          AccessControl.user = null;
          InventoryCoordinator.busy = false;
          directory = await Directory.systemTemp.createTemp('erp_trading_ui_');
          Hive.init(directory.path);
          warehouse = WarehouseProvider();
          shop = ShopProvider();
          await warehouse.ready;
          await shop.ready;
          await warehouse.addMaterial('Water', 10, 'Kilogram', 1);
          await warehouse.saveParty(name: 'Supplier');
          productId = await shop.registerProduct('Cleaner', 'Package', 'CL-01');
          await shop.configureProduct(productId,
              name: 'Cleaner',
              sku: 'CL-01',
              unitConversions: [
                {
                  'id': 'carton-12',
                  'unit': 'Carton',
                  'numerator': 12,
                  'denominator': 1,
                  'revision': 1,
                  'allowFraction': false
                }
              ]);
        });
        addTearDown(() async {
          warehouse.dispose();
          shop.dispose();
          AccessControl.enabled = false;
          AccessControl.user = null;
          await Hive.close();
          await directory.delete(recursive: true);
        });
        Widget app(Widget screen) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: warehouse),
                  ChangeNotifierProvider.value(value: shop)
                ],
                child: MaterialApp(
                    locale: Locale(language),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    home: screen));
        String t(String en, String ar) => language == 'ar' ? ar : en;
        Finder keyed(String prefix) => find.byWidgetPredicate((widget) =>
            widget.key is ValueKey &&
            (widget.key as ValueKey).value.toString().startsWith(prefix));
        await tester.pumpWidget(app(Builder(
            builder: (ctx) => Scaffold(
                body: FilledButton(
                    onPressed: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => const TradingPurchaseScreen())),
                    child: const Text('Open receipt'))))));
        await tester.tap(find.text('Open receipt'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('trading-supplier')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supplier').last);
        await tester.pumpAndSettle();
        await tester.tap(keyed('trading-product-'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CL-01 • Cleaner').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Carton').last);
        await tester.pumpAndSettle();
        await tester.enterText(keyed('trading-quantity-'), '2');
        await tester.enterText(keyed('trading-price-'), '12');
        await tester.pumpAndSettle();
        expect(
            find.text(
                '${t('Stock receipt', 'كمية الاستلام بالمخزون')}: 24 Package'),
            findsOneWidget);
        final post = find.byKey(const ValueKey('receive-trading-purchase'));
        await tester.scrollUntilVisible(post, 240,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(post);
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (shop.stockLots.isEmpty ||
              shop.isSaving ||
              warehouse.isSaving ||
              InventoryCoordinator.busy) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Trading receipt did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(shop.products.single.quantity, 24);
        expect(warehouse.materials.single.quantity, 10);
        expect(shop.stockLots.single['sourceKind'], 'supplier_purchase');
        expect(shop.stockLots.single['costMinor'], 2400);
        expect(
            shop.stockLots.single['supplierId'], warehouse.parties.single.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester
            .pumpWidget(app(FinishedProductScreen(productId: productId)));
        await tester.pumpAndSettle();
        expect(find.text('${t('SKU', 'رمز الصنف')}: CL-01'), findsOneWidget);
        final cost = find.text(
            '${t('Original total lot cost', 'إجمالي تكلفة الدفعة الأصلي')}: 24.00 USD');
        await tester.scrollUntilVisible(cost, 160,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(cost, findsOneWidget);
        expect(find.text(t('Confirmed cost', 'تكلفة مؤكدة')), findsOneWidget);
        expect(
            find.text(
                '${t('Derived cost per base unit', 'التكلفة المشتقة لكل وحدة أساسية')}: 1.000000 USD'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(Builder(
            builder: (ctx) => Scaffold(
                body: FilledButton(
                    onPressed: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => const TradeEntryScreen(
                                purchase: false, productName: 'Cleaner'))),
                    child: const Text('Open sale'))))));
        await tester.tap(find.text('Open sale'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const ValueKey('trade-party')), 'Customer');
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Carton').last);
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const ValueKey('trade-quantity')), '1');
        await tester.enterText(find.byKey(const ValueKey('trade-price')), '24');
        final saleCurrency = find.byKey(const ValueKey('trade-currency'));
        await tester.ensureVisible(saleCurrency);
        await tester.pumpAndSettle();
        await tester.tap(saleCurrency);
        await tester.pumpAndSettle();
        await tester.tap(find.text('USD').last);
        await tester.pumpAndSettle();
        expect(
            find.text(
                '${t('Stock quantity issued', 'الكمية المصروفة من المخزون')}: 12 Package'),
            findsOneWidget);
        final salePost = find.text(t('Post document', 'تسجيل المستند'));
        await tester.scrollUntilVisible(salePost, 240,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(salePost);
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (shop.sales.isEmpty || shop.isSaving) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Converted sale did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(shop.products.single.quantity, 12);
        expect(shop.sales.single.lines.single.quantity, 1);
        expect(shop.sales.single.lines.single.unit, 'Carton');
        expect(shop.sales.single.lines.single.baseQuantity, 12);
        expect(shop.sales.single.lines.single.lots.values.single, 12);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
