import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/screens/transfers_screen.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';

void main() {
  late Directory directory;
  late WarehouseProvider warehouse;
  late ShopProvider shop;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_transfer_editor_');
    Hive.init(directory.path);
    AccessControl.enabled = false;
    AccessControl.user = null;
    InventoryCoordinator.busy = false;
    warehouse = WarehouseProvider();
    shop = ShopProvider();
    await warehouse.ready;
    await shop.ready;
    await warehouse.addMaterial('Water', 10, 'Kilogram', 1);
    await warehouse.produceManufacturedProduct('Bulk', 10, {'Water': 10});
    await shop.registerProduct('Bottles', 'Package', 'BOT-01');
  });
  tearDown(() async {
    warehouse.dispose();
    shop.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
    AccessControl.enabled = false;
    AccessControl.user = null;
    InventoryCoordinator.busy = false;
  });
  for (final language in ['en', 'ar']) {
    testWidgets(
        'Packaging editor retains typed quantities when selecting SKU in $language',
        (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: warehouse),
            ChangeNotifierProvider.value(value: shop)
          ],
          child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const TransfersScreen())));
      await tester.tap(find.byKey(const ValueKey('new-transfer')));
      await tester.pumpAndSettle();
      final sourceLabel = language == 'ar'
          ? 'كمية الإنتاج المستخدمة'
          : 'Manufactured quantity to use';
      final source = find.byKey(ValueKey('transfer-input:$sourceLabel'));
      await tester.enterText(source, '10');
      final picker = find.byKey(const ValueKey('transfer-product'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BOT-01 • Bottles').last);
      await tester.pumpAndSettle();
      expect(
          tester.widget<TextFormField>(source).controller?.text ??
              tester
                  .widget<TextField>(find.descendant(
                      of: source, matching: find.byType(TextField)))
                  .controller!
                  .text,
          '10');
      await tester.enterText(source, '9');
      await tester.enterText(source, '10');
      await tester.tap(find.text(language == 'ar' ? 'إلغاء' : 'Cancel').last);
      await tester.pumpAndSettle();
      expect(shop.products.single.quantity, 0);
      expect(
          warehouse.finishedAvailable(warehouse.manufacturedProducts.single.id),
          10);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
