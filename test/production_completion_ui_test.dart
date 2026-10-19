import 'dart:io';

import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/screens/operations_screen.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets('Actual production completion at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        late WarehouseProvider warehouse;
        late ShopProvider shop;
        late String orderId, waterId;
        await tester.runAsync(() async {
          AccessControl.enabled = false;
          AccessControl.user = null;
          InventoryCoordinator.busy = false;
          directory = await Directory.systemTemp.createTemp('erp_actual_ui_');
          Hive.init(directory.path);
          warehouse = WarehouseProvider();
          shop = ShopProvider();
          await warehouse.ready;
          await shop.ready;
          await warehouse.addMaterial('Water', 100, 'Kilogram', 1);
          waterId = warehouse.materials.single.id;
          await shop.addProduct('Cleaner bottle', 3, 'Piece', 8);
          await warehouse.createOrder(
              'Cleaner', 24, 'Piece', 'COMPLETE-UI', '', {'Water': 10},
              requestId: 'ui-order');
          orderId = warehouse.orders.single['id'];
          await warehouse.approveOrder(orderId, 'Reviewed final bottle recipe');
        });
        addTearDown(() async {
          warehouse.dispose();
          shop.dispose();
          AccessControl.enabled = false;
          AccessControl.user = null;
          InventoryCoordinator.busy = false;
          await Hive.close();
          await directory.delete(recursive: true);
        });
        String t(String en, String ar) => language == 'ar' ? ar : en;
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: warehouse),
            ChangeNotifierProvider.value(value: shop),
          ],
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.2),
              ),
              child: child!,
            ),
            home: const OperationsScreen(),
          ),
        ));
        await tester.pumpAndSettle();
        final action = find.byKey(ValueKey('complete-finished-$orderId'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        final product = find.byKey(const ValueKey('completion-product'));
        await tester.ensureVisible(product);
        await tester.tap(product);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cleaner bottle • Piece').last);
        await tester.pumpAndSettle();
        Future<void> enter(String key, String value) async {
          final field = find.byKey(ValueKey(key));
          await tester.ensureVisible(field);
          await tester.enterText(field, value);
          await tester.pump();
        }

        await enter('completion-quantity', language == 'ar' ? '٢٣' : '23');
        await enter(
            'completion-material-$waterId', language == 'ar' ? '٩' : '9');
        await enter('completion-variance', 'Measured consumption and yield');
        await enter('completion-quality-note', 'QC sheet reviewed');
        await tester.tap(find.byKey(const ValueKey('completion-submit')));
        await tester.pumpAndSettle();
        expect(
            find.text(t('Confirm quality checks before receiving goods',
                'أكد اجتياز فحوص الجودة قبل استلام المنتجات')),
            findsOneWidget);
        expect(warehouse.getStock('Water'), 100);
        expect(shop.getStock('Cleaner bottle'), 3);
        final quality = find.byKey(const ValueKey('completion-quality-passed'));
        await tester.ensureVisible(quality);
        await tester.tap(quality);
        await tester.pumpAndSettle();
        final costStatus = find.byKey(const ValueKey('completion-cost-status'));
        await tester.ensureVisible(costStatus);
        await tester.tap(costStatus);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t('Estimated', 'تقديرية')).last);
        await tester.pumpAndSettle();
        await enter('completion-total-cost', '46');
        await enter('completion-cost-reference', 'Estimated cost sheet UI');
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('completion-submit')));
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (warehouse.orders.single['status'] != 'released' ||
              !warehouse.isLoaded ||
              !shop.isLoaded ||
              InventoryCoordinator.busy) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Combined production posting did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(warehouse.getStock('Water'), 91);
        expect(shop.getStock('Cleaner bottle'), 26);
        expect(shop.products.single.unitPrice, 8);
        expect(warehouse.orders.single['quantity'], 24);
        expect(warehouse.orders.single['completion']['costMinor'], 4600);
        expect(
            warehouse.orders.single['completion']['costStatus'], 'estimated');
        expect(
            find.text(
                t('Finished goods received', 'تم استلام المنتجات الجاهزة')),
            findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
