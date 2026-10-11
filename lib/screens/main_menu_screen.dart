import 'package:provider/provider.dart';
import '../services/access_control.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'app_shell.dart';
import 'warehouse_screen.dart';
import 'shop_screen.dart';
import 'language_selection_screen.dart';
import 'backup_screen.dart';
import 'business_documents_screen.dart';
import 'parties_screen.dart';
import 'transfers_screen.dart';
import 'finance_screen.dart';
import 'operations_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.mainMenuTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.language),
          tooltip: localizations.backToLanguageBtn,
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => const LanguageSelectionScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
              tooltip: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'المزيد'
                  : 'More',
              itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'partners',
                        child:
                            Text('Customers & suppliers / العملاء والموردون')),
                    if (AccessControl.allows('backup'))
                      const PopupMenuItem(
                          value: 'backup',
                          child: Text('Backup & restore / النسخ الاحتياطي')),
                    if (AccessControl.enabled && AccessControl.allows('admin'))
                      const PopupMenuItem(
                          value: 'users',
                          child: Text('Users & roles / المستخدمون')),
                    if (AccessControl.enabled)
                      const PopupMenuItem(
                          value: 'logout',
                          child: Text('Sign out / تسجيل الخروج'))
                  ],
              onSelected: (value) {
                if (value == 'logout') {
                  context.read<AuthService>().logout();
                  return;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => switch (value) {
                              'partners' => const PartiesScreen(),
                              'users' => const UsersScreen(),
                              _ => const BackupScreen()
                            }));
              })
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMenuButton(context,
                          title: Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? 'أوامر الإنتاج والجرد'
                              : 'Production orders & stock counts',
                          icon: Icons.assignment,
                          color: Colors.deepPurple,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const OperationsScreen()))),
                      const SizedBox(height: 20),
                      _buildMenuButton(context,
                          title: Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? 'المالية'
                              : 'Finance',
                          icon: Icons.account_balance,
                          color: Colors.indigo,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FinanceScreen()))),
                      const SizedBox(height: 20),
                      _buildMenuButton(context,
                          title: Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? 'نقل المنتجات الجاهزة'
                              : 'Finished-goods transfers',
                          icon: Icons.swap_horiz,
                          color: Colors.teal,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TransfersScreen()))),
                      const SizedBox(height: 20),
                      _buildMenuButton(context,
                          title: Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? 'المستندات التجارية'
                              : 'Business documents',
                          icon: Icons.receipt_long,
                          color: Colors.blueGrey,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BusinessDocumentsScreen()))),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        context,
                        title: localizations.btnProductionCalc,
                        icon: Icons.calculate,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AppShell())),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        context,
                        title: localizations.btnWarehouse,
                        icon: Icons.warehouse,
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WarehouseScreen())),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        context,
                        title: localizations.btnSalesShop,
                        icon: Icons.storefront,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ShopScreen())),
                      ),
                    ],
                  ),
                ))),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 15),
          Flexible(
              child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          )),
        ],
      ),
    );
  }
}
