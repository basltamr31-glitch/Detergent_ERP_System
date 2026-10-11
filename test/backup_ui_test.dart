import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/screens/backup_screen.dart';
import 'package:detergent_factory/services/backup_service.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_backup_ui_');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final width in [320.0, 1280.0]) {
    for (final language in ['en', 'ar']) {
      testWidgets('Backup restore cancellation at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late WarehouseProvider warehouse;
        late ShopProvider shop;
        final production = ProductionProvider();
        final packaging = PackagingProvider();
        await tester.runAsync(() async {
          warehouse = WarehouseProvider();
          shop = ShopProvider();
          await warehouse.ready;
          await shop.ready;
        });
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: warehouse),
              ChangeNotifierProvider.value(value: shop),
              ChangeNotifierProvider.value(value: production),
              ChangeNotifierProvider.value(value: packaging),
            ],
            child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: const BackupScreen())));
        final payload = {
          'warehouse': jsonDecode(warehouse.exportState()),
          'shop': jsonDecode(shop.exportState()),
          'production': production.toDraft(),
          'packaging': packaging.toDraft()
        };
        final before = warehouse.exportState();
        await tester.enterText(
            find.byType(TextField).last, BackupService.encode(payload));
        final restore = find.widgetWithIcon(OutlinedButton, Icons.restore);
        await tester.ensureVisible(restore);
        await tester.tap(restore);
        // The screen intentionally shows progress while confirmation is open.
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(
            TextButton, language == 'ar' ? 'إلغاء' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(warehouse.exportState(), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        warehouse.dispose();
        shop.dispose();
        production.dispose();
        packaging.dispose();
      });
    }
  }
}
