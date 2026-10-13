import 'services/auth_service.dart';
import 'services/access_control.dart';
import 'screens/auth_screen.dart';
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
import 'services/backup_service.dart';
import 'services/transfer_service.dart';
import 'services/startup_error.dart';

bool _starting = false;

void main() async {
  if (_starting) return;
  _starting = true;
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(my_models.MaterialAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MaterialTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ManufacturedProductAdapter());
    }

    await TransferService.recover();
    await BackupService.recover();
    await Hive.openBox<String>('costing_drafts_v1');

    AccessControl.enabled = true;
    AccessControl.user = null;
    final auth = await AuthService.open();
    runApp(MyApp(auth: auth));
  } catch (e) {
    await Hive.close();
    runApp(MaterialApp(
        home: Scaffold(
            body: Center(
                child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isDatabaseLocked(e)
            ? 'التطبيق مفتوح بالفعل / App data is already in use'
            : 'تعذر فتح البيانات / Unable to open data'),
        const SizedBox(height: 12),
        if (isDatabaseLocked(e))
          const Text('Close other Detergent Factory windows, then press Retry. '
              'If none are visible, close detergent_factory.exe in Task Manager. '
              'Your saved data has not been deleted.\n'
              'أغلق نوافذ التطبيق الأخرى ثم اضغط إعادة المحاولة. '
              'إذا لم تظهر نافذة، أغلق detergent_factory.exe من مدير المهام. '
              'لم يتم حذف بياناتك المحفوظة.'),
        ExpansionTile(
          title: const Text('التفاصيل / Technical details'),
          children: [SelectableText(e.toString())],
        ),
        const SizedBox(height: 12),
        const FilledButton(
            onPressed: main, child: Text('إعادة المحاولة / Retry')),
      ]),
    )))));
  } finally {
    _starting = false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.auth, this.warehouse, this.shop});
  final AuthService auth;
  final WarehouseProvider? warehouse;
  final ShopProvider? shop;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider(
            create: (_) => ProductionProvider(
                storage: Hive.box<String>('costing_drafts_v1'))),
        ChangeNotifierProvider(
            create: (_) => PackagingProvider(
                storage: Hive.box<String>('costing_drafts_v1'))),
        ChangeNotifierProvider(create: (_) => AppLanguageProvider()),
        ChangeNotifierProvider(create: (_) => warehouse ?? WarehouseProvider()),
        ChangeNotifierProvider(create: (_) => shop ?? ShopProvider()),
      ],
      child: Consumer2<AppLanguageProvider, AuthService>(
        builder: (context, langProvider, session, child) {
          return MaterialApp(
            key: ValueKey(session.user?['id'] ?? 'signed-out'),
            title: 'Detergent Factory',
            debugShowCheckedModeBanner: false,
            locale: langProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              fontFamily:
                  'Cairo', // we could conditionally set this based on locale but keeping custom Cairo is fine
              inputDecorationTheme: InputDecorationTheme(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            home: session.user == null
                ? const AuthScreen()
                : const LanguageSelectionScreen(),
          );
        },
      ),
    );
  }
}
