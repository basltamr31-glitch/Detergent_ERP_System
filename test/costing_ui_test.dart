import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/models/raw_material.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/screens/packaging_filling_screen.dart';
import 'package:detergent_factory/screens/final_results_screen.dart';
import 'package:detergent_factory/widgets/custom_numeric_widgets.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      testWidgets(
          'Explicit fill units, density and costing readiness at $width in $locale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final production = ProductionProvider();
        final packaging = PackagingProvider();
        production.setProductName('Cleaner');
        production.setProducedQuantity(10);
        production.addRawMaterial();
        production.updateRawMaterial(
            0, RawMaterial(name: 'Concentrate', quantity: 2, priceUSD: 10));
        packaging.loadDraft({
          'version': 1,
          'perCarton': 6,
          'cartonUSD': 0.6,
          'cartonSYP': 0,
          'labelUSD': 0.1,
          'labelSYP': 0,
          'items': [
            {'size': 500, 'usd': 0.2, 'syp': 0, 'carton': false}
          ]
        });
        Widget app(Widget page) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: production),
                  ChangeNotifierProvider.value(value: packaging),
                ],
                child: MaterialApp(
                    locale: Locale(locale),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    theme: ThemeData(platform: TargetPlatform.windows),
                    home: page));
        await tester.pumpWidget(app(const FinalResultScreen()));
        await tester.pumpAndSettle();
        expect(
            find.text(locale == 'ar'
                ? 'أكمل بيانات التكلفة'
                : 'Complete costing inputs'),
            findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const PackagingFillingScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ml').last);
        await tester.pumpAndSettle();
        expect(packaging.packagingItems.single.unit, 'ml');
        final density = find.byWidgetPredicate(
            (w) => w is CustomNumericField && w.label.contains('kg/L'));
        await tester.ensureVisible(density);
        await tester.pumpAndSettle();
        await tester.enterText(
            find.descendant(of: density, matching: find.byType(TextField)),
            '1.2');
        await tester.pumpAndSettle();
        expect(packaging.densityKgPerLiter, 1.2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const FinalResultScreen()));
        await tester.pumpAndSettle();
        expect(find.text('0.600000'), findsOneWidget);
        expect(find.text('1.50 \$'), findsOneWidget);
        expect(
            find.text(locale == 'ar'
                ? 'حدد سعر صرف موجباً لحساب الإجماليات بالليرة السورية.'
                : 'Set a positive exchange rate to calculate SYP totals.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        packaging.setDensity(0);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
        expect(
            find.text(locale == 'ar'
                ? 'أكمل بيانات التكلفة'
                : 'Complete costing inputs'),
            findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        production.dispose();
        packaging.dispose();
      });
    }
  }
}
