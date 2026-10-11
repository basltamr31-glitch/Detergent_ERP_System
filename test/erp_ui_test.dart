import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/app_language_provider.dart';
import 'package:detergent_factory/services/auth_service.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';
import 'package:detergent_factory/services/document_report.dart';
import 'package:detergent_factory/screens/operations_screen.dart';
import 'package:detergent_factory/screens/transfers_screen.dart';
import 'package:detergent_factory/screens/finance_screen.dart';
import 'package:detergent_factory/screens/auth_screen.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets(
          'Production approval, transfer, finance and sign-in at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        late WarehouseProvider warehouse;
        late ShopProvider shop;
        late AuthService auth;
        await tester.runAsync(() async {
          AccessControl.enabled = false;
          AccessControl.user = null;
          InventoryCoordinator.busy = false;
          directory = await Directory.systemTemp.createTemp('erp_full_ui_');
          Hive.init(directory.path);
          warehouse = WarehouseProvider();
          shop = ShopProvider();
          await warehouse.ready;
          await shop.ready;
          await warehouse.addMaterial('Water', 100, 'Kilogram', 1);
          auth = await AuthService.open();
        });
        addTearDown(() async {
          warehouse.dispose();
          shop.dispose();
          auth.dispose();
          await Hive.close();
          await directory.delete(recursive: true);
        });
        final lang = AppLanguageProvider()..changeLanguage(Locale(language));
        Widget app(Widget page, {double scale = 1}) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: warehouse),
                  ChangeNotifierProvider.value(value: shop),
                  ChangeNotifierProvider.value(value: lang),
                  ChangeNotifierProvider.value(value: auth)
                ],
                child: MaterialApp(
                    locale: Locale(language),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    builder: (_, child) => MediaQuery(
                        data: MediaQueryData(
                            size: Size(width, 900),
                            textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: page));
        String t(String en, String ar) => language == 'ar' ? ar : en;
        Future<void> save(String label, bool Function() complete) async {
          await tester.runAsync(() async {
            await tester.tap(find.text(label).last);
            final deadline = DateTime.now().add(const Duration(seconds: 10));
            while (!complete() ||
                warehouse.isSaving ||
                shop.isSaving ||
                InventoryCoordinator.busy ||
                !warehouse.isLoaded ||
                !shop.isLoaded) {
              if (DateTime.now().isAfter(deadline)) {
                throw StateError('UI posting did not complete: $label');
              }
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(app(const OperationsScreen()));
        await tester.pumpAndSettle();
        await tester
            .tap(find.text(t('Plan production order', 'تخطيط أمر إنتاج')));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        for (final entry in {
          0: 'Cleaner',
          1: '10',
          2: 'Kilogram',
          3: 'LOT-UI',
          5: '10'
        }.entries) {
          await tester.ensureVisible(fields.at(entry.key));
          await tester.enterText(fields.at(entry.key), entry.value);
        }
        await save(
            t('Save order', 'حفظ الأمر'), () => warehouse.orders.length == 1);
        await tester.tap(find.text(t('Approve', 'اعتماد')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Recipe reviewed');
        await save(t('Confirm', 'تأكيد'),
            () => warehouse.orders.single['status'] == 'approved');
        await tester.tap(find.text(t('Release', 'إفراج')));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextField).first, 'QC sheet approved');
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await save(t('Confirm', 'تأكيد'),
            () => warehouse.orders.single['status'] == 'released');
        expect(warehouse.getStock('Water'), 90);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const TransfersScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new-transfer')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('PRD-000001').last);
        await tester.pumpAndSettle();
        final transferFields = find.byType(TextFormField);
        for (final entry in {
          0: '5',
          1: 'Kilogram',
          2: 'Cleaner bottles',
          3: '10',
          4: 'Piece',
          5: '2'
        }.entries) {
          await tester.ensureVisible(transferFields.at(entry.key));
          await tester.enterText(transferFields.at(entry.key), entry.value);
        }
        await tester
            .ensureVisible(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('USD').last);
        await tester.pumpAndSettle();
        await save(t('Post transfer', 'تسجيل النقل'),
            () => warehouse.transfers.length == 1);
        expect(shop.getStock('Cleaner bottles'), 10);
        await tester.runAsync(() async {
          await shop.sellProduct('Cleaner bottles', 2, unitPriceMinor: 250);
          final pdf = await DocumentReport.build(
              shop.sales.single, shop.payments,
              arabic: language == 'ar');
          expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
          expect(pdf.length, greaterThan(3000));
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const FinanceScreen(), scale: 1.4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(t('Document reconciliation', 'مطابقة المستندات')),
            findsOneWidget);
        expect(
            find.text(t('Ledger and document balances agree',
                'أرصدة الدفتر والمستندات متطابقة')),
            findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const AuthScreen(), scale: 1.4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNWidgets(2));
        await tester.pumpWidget(const SizedBox());
        lang.dispose();
      });
    }
  }
}
