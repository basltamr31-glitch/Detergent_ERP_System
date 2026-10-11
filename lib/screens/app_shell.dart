import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/production_provider.dart';
import '../providers/packaging_provider.dart';
import '../widgets/storage_status.dart';
import '../l10n/app_localizations.dart';
import 'production_management_screen.dart';
import 'packaging_filling_screen.dart';
import 'final_results_screen.dart';

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
    final production = context.watch<ProductionProvider>();
    final packaging = context.watch<PackagingProvider>();
    final error = production.loadError ?? packaging.loadError;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.tabProduction)),
        body: StorageStatus(
            error: error,
            onRetry: () async {
              production.initializeDraft();
              packaging.initializeDraft();
              setState(() {});
            }),
      );
    }

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final content = Column(children: [
          if (production.saveError != null || packaging.saveError != null)
            MaterialBanner(
              content: Text(Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تعذر حفظ المسودة.'
                  : 'Draft could not be saved.'),
              actions: [
                TextButton(
                    onPressed: () async {
                      try {
                        await production.flushDraft();
                        await packaging.flushDraft();
                      } catch (_) {
                        /* The banner remains visible until saving succeeds. */
                      }
                      if (mounted) setState(() {});
                    },
                    child: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'إعادة المحاولة'
                            : 'Retry'))
              ],
            ),
          Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
        ]);
        if (constraints.maxWidth < 800) return content;
        return Row(children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                  icon: const Icon(Icons.factory),
                  label: Text(localizations.tabProduction)),
              NavigationRailDestination(
                  icon: const Icon(Icons.inventory_2),
                  label: Text(localizations.tabPackaging)),
              NavigationRailDestination(
                  icon: const Icon(Icons.analytics),
                  label: Text(localizations.tabReports)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: content,
          ))),
        ]);
      }),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 800
          ? null
          : BottomNavigationBar(
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
