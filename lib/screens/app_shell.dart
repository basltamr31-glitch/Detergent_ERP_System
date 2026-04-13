import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'production_management_screen.dart';
import 'packaging_filling_screen.dart';
import 'FinalResultsScreen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ProductionManagementScreen(),
    PackagingFillingScreen(),
    FinalResultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blue,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.factory),
            label: localizations.tabProduction,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2),
            label: localizations.tabPackaging,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: localizations.tabReports,
          ),
        ],
      ),
    );
  }
}
