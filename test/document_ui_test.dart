import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/screens/business_documents_screen.dart';
import 'package:detergent_factory/screens/trade_entry_screen.dart';
import 'package:detergent_factory/screens/warehouse_screen.dart';
import 'package:detergent_factory/screens/parties_screen.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_document_ui_');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets('Receipt form and populated documents at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late WarehouseProvider warehouse;
        late ShopProvider shop;
        await tester.runAsync(() async {
          warehouse = WarehouseProvider();
          shop = ShopProvider();
          await warehouse.ready;
          await shop.ready;
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
        await tester.pumpWidget(app(const PartiesScreen(initialTab: 1)));
        await tester.pumpAndSettle();
        await tester
            .tap(find.text(language == 'ar' ? 'سجل جديد' : 'New record').last);
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextFormField).at(0), 'Saved supplier');
        await tester.enterText(find.byType(TextFormField).at(1), '+358123456');
        await tester.enterText(
            find.byType(TextFormField).at(2), 'Supplier address');
        await tester.runAsync(() async {
          await tester
              .tap(find.text(language == 'ar' ? 'حفظ السجل' : 'Save record'));
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (warehouse.parties.isEmpty || warehouse.isSaving) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Supplier did not save.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(find.text('Saved supplier'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(Builder(
            builder: (ctx) => Scaffold(
                    body: FilledButton(
                  onPressed: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) =>
                              const TradeEntryScreen(purchase: true))),
                  child: const Text('Open'),
                )))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Supplier A');
        final savedParty = find.byType(DropdownButtonFormField<String>).first;
        await tester.ensureVisible(savedParty);
        await tester.tap(savedParty);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved supplier').last);
        await tester.pumpAndSettle();
        await tester.enterText(fields.at(1), 'Water');
        await tester.enterText(fields.at(2), language == 'ar' ? '١٠' : '10');
        await tester.enterText(fields.at(3), '2.25');
        await tester.enterText(fields.at(4), '10');
        final currency = find.byType(DropdownButtonFormField<String>).last;
        await tester.ensureVisible(currency);
        await tester.tap(currency);
        await tester.pumpAndSettle();
        await tester.tap(find.text('USD').last);
        await tester.pumpAndSettle();
        final post =
            find.text(language == 'ar' ? 'تسجيل المستند' : 'Post document');
        await tester.scrollUntilVisible(post, 250,
            scrollable: find.byType(Scrollable).first);
        await tester.runAsync(() async {
          await tester.tap(post);
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (warehouse.purchases.isEmpty || warehouse.isSaving) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Receipt did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(warehouse.getStock('Water'), 10);
        expect(warehouse.purchases.single.totalMinor, 2250);
        expect(warehouse.purchases.single.partyId, warehouse.parties.single.id);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          await warehouse.produceManufacturedProduct('Soap', 2, {'Water': 2});
          await shop.addProduct('Soap', 5, 'Piece', 2);
          await shop.sellProduct('Soap', 1, customer: 'Customer A');
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const BusinessDocumentsScreen()));
        await tester.pumpAndSettle();
        expect(find.textContaining('PRD-000001'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester
            .tap(find.text(language == 'ar' ? 'المشتريات' : 'Purchases'));
        await tester.pumpAndSettle();
        expect(find.textContaining('PUR-000001'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester
            .tap(find.text(language == 'ar' ? 'تسجيل دفعة' : 'Record payment'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
            find
                .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(TextField))
                .first,
            language == 'ar' ? '٥' : '5');
        await tester.enterText(
            find
                .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(TextField))
                .last,
            'Bank reference');
        await tester.runAsync(() async {
          await tester
              .tap(find.text(language == 'ar' ? 'حفظ الدفعة' : 'Save payment'));
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (warehouse.payments.isEmpty || warehouse.isSaving) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Payment did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(warehouse.paidFor(warehouse.purchases.single), 1500);
        expect(find.textContaining('Bank reference'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(language == 'ar' ? 'المبيعات' : 'Sales'));
        await tester.pumpAndSettle();
        expect(find.textContaining('SAL-000001'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final reverseLabel = language == 'ar' ? 'عكس' : 'Reverse';
        await tester.ensureVisible(find.text(reverseLabel));
        await tester.runAsync(() => tester.tap(find.text(reverseLabel)));
        await tester.pumpAndSettle();
        final reverse = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, reverseLabel));
        await tester.tap(reverse);
        await tester.pump();
        expect(
            find.text(
                language == 'ar' ? 'السبب مطلوب' : 'A reason is required'),
            findsOneWidget);
        await tester.enterText(
            find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextFormField)),
            'Returned by customer');
        final saleId = shop.sales.single.id;
        await tester.runAsync(() async {
          await tester.tap(reverse);
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (!shop.isSaleReversed(saleId) || shop.isSaving) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Reversal did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(shop.getStock('Soap'), 5);
        expect(shop.sales.length, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const WarehouseScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        warehouse.dispose();
        shop.dispose();
      });
    }
  }
  for (final language in ['en', 'ar']) {
    testWidgets('Sales entry posts a priced document in $language',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late WarehouseProvider warehouse;
      late ShopProvider shop;
      await tester.runAsync(() async {
        warehouse = WarehouseProvider();
        shop = ShopProvider();
        await warehouse.ready;
        await shop.ready;
        await shop.addProduct('Soap', 10, 'Piece', 2);
      });
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: warehouse),
            ChangeNotifierProvider.value(value: shop)
          ],
          child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                  builder: (ctx) => Scaffold(
                      body: FilledButton(
                          onPressed: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                  builder: (_) => const TradeEntryScreen(
                                      purchase: false, productName: 'Soap'))),
                          child: const Text('Open')))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('trade-party')), 'Customer A');
      await tester.enterText(find.byKey(const ValueKey('trade-quantity')),
          language == 'ar' ? '٢٫٥' : '2.5');
      await tester.enterText(find.byKey(const ValueKey('trade-price')), '3.25');
      await tester.enterText(find.byKey(const ValueKey('trade-paid')), '5');
      final currency = find.byType(DropdownButtonFormField<String>).last;
      await tester.ensureVisible(currency);
      await tester.tap(currency);
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD').last);
      await tester.pumpAndSettle();
      final post =
          find.text(language == 'ar' ? 'تسجيل المستند' : 'Post document');
      await tester.scrollUntilVisible(post, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.runAsync(() async {
        await tester.tap(post);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (shop.sales.isEmpty || shop.isSaving) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Sale did not complete.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(shop.getStock('Soap'), 7.5);
      expect(shop.sales.single.totalMinor, 813);
      expect(shop.sales.single.paidMinor, 500);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      warehouse.dispose();
      shop.dispose();
    });
  }
}
