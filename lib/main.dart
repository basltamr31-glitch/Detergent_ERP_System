import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/production_provider.dart';
import 'providers/packaging_provider.dart';
import 'providers/app_language_provider.dart';
import 'providers/warehouse_provider.dart';
import 'providers/shop_provider.dart';
import 'screens/language_selection_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'models/material.dart' as my_models;
import 'models/material_transaction.dart';
import 'models/product.dart';
import 'models/manufactured_product.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  Hive.registerAdapter(my_models.MaterialAdapter());
  Hive.registerAdapter(MaterialTransactionAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(ManufacturedProductAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductionProvider()),
        ChangeNotifierProvider(create: (_) => PackagingProvider()),
        ChangeNotifierProvider(create: (_) => AppLanguageProvider()),
        ChangeNotifierProvider(create: (_) => WarehouseProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
      ],
      child: Consumer<AppLanguageProvider>(
        builder: (context, langProvider, child) {
          return MaterialApp(
            title: 'Detergent Factory',
            debugShowCheckedModeBanner: false,
            locale: langProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              fontFamily: 'Cairo', // we could conditionally set this based on locale but keeping custom Cairo is fine
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(fontFamily: 'Cairo'),
                bodyMedium: TextStyle(fontFamily: 'Cairo'),
                bodySmall: TextStyle(fontFamily: 'Cairo'),
                titleLarge: TextStyle(fontFamily: 'Cairo'),
                titleMedium: TextStyle(fontFamily: 'Cairo'),
                titleSmall: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            home: const LanguageSelectionScreen(),
          );
        },
      ),
    );
  }
}

