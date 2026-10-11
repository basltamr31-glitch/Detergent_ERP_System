import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/screens/app_shell.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    for (final locale in ['en', 'ar']) {
      testWidgets('Production navigation at $width in $locale', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProductionProvider()),
            ChangeNotifierProvider(create: (_) => PackagingProvider()),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const AppShell(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail),
            width >= 800 ? findsOneWidget : findsNothing);
        expect(find.byType(BottomNavigationBar),
            width < 800 ? findsOneWidget : findsNothing);
        await tester.tap(find.byIcon(Icons.inventory_2).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
