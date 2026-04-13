import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import 'app_shell.dart';
import 'warehouse_screen.dart';
import 'shop_screen.dart';
import 'language_selection_screen.dart';

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
              MaterialPageRoute(builder: (context) => const LanguageSelectionScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_backup_restore, color: Colors.red),
            tooltip: localizations.resetSystemBtn,
            onPressed: () => _showResetDialog(context, localizations),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMenuButton(
                context,
                title: localizations.btnProductionCalc,
                icon: Icons.calculate,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppShell())),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                title: localizations.btnWarehouse,
                icon: Icons.warehouse,
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseScreen())),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                title: localizations.btnSalesShop,
                icon: Icons.storefront,
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, AppLocalizations localizations) {
    bool resetWarehouse = true;
    bool resetSales = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.resetTargetTitle, style: const TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(localizations.resetConfirmation, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    title: Text(localizations.resetWarehouseBtn),
                    value: resetWarehouse,
                    onChanged: (val) => setState(() => resetWarehouse = val ?? false),
                  ),
                  CheckboxListTile(
                    title: Text(localizations.resetSalesBtn),
                    value: resetSales,
                    onChanged: (val) => setState(() => resetSales = val ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(localizations.cancelBtn),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (resetWarehouse) {
                      await Provider.of<WarehouseProvider>(context, listen: false).resetWarehouse();
                    }
                    if (resetSales) {
                      await Provider.of<ShopProvider>(context, listen: false).resetSales();
                    }
                    if (!ctx.mounted || !context.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.resetSuccess)));
                  },
                  child: Text(localizations.confirmBtn, style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }
}

