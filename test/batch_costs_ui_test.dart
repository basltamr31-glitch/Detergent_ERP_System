import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/models/raw_material.dart';
import 'package:detergent_factory/models/packaging_item.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/screens/production_management_screen.dart';
import 'package:detergent_factory/screens/final_results_screen.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets(
          'Batch charges and restored product name at $width in $locale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final production = ProductionProvider(),
            packaging = PackagingProvider();
        production.setProductName('Saved cleaner');
        production.setProducedQuantity(10);
        production.addRawMaterial();
        production.updateRawMaterial(
            0, RawMaterial(name: 'Concentrate', quantity: 2, priceUSD: 10));
        packaging.setDensity(1.2);
        packaging.setLabelPriceUSD(0.1, 0);
        packaging.addPackagingItem();
        packaging.updatePackagingItem(
            0, PackagingItem(size: 500, price: 0.2, unit: 'ml'));
        Widget app(Widget page) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: production),
                  ChangeNotifierProvider.value(value: packaging)
                ],
                child: MaterialApp(
                    locale: Locale(locale),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    theme: ThemeData(platform: TargetPlatform.windows),
                    home: page));
        await tester.pumpWidget(app(const ProductionManagementScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Saved cleaner'), findsOneWidget);
        final labor = find.byKey(const ValueKey('batch-labor')),
            overhead = find.byKey(const ValueKey('batch-overhead'));
        await tester.ensureVisible(labor);
        await tester.enterText(
            find.descendant(of: labor, matching: find.byType(TextField)), '5');
        await tester.ensureVisible(overhead);
        await tester.enterText(
            find.descendant(of: overhead, matching: find.byType(TextField)),
            '3');
        await tester.pumpAndSettle();
        expect(production.totalCostUSD, 28);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const FinalResultScreen()));
        await tester.pumpAndSettle();
        expect(find.text('1.98 \$'), findsOneWidget);
        expect(
            find.text(
                locale == 'ar' ? 'عمالة الدفعة (USD)' : 'Batch labor (USD)'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        production.dispose();
        packaging.dispose();
      });
    }
  }
}
