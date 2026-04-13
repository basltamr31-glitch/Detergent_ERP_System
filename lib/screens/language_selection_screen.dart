import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_language_provider.dart';
import 'main_menu_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<AppLanguageProvider>(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)?.selectLanguage ?? 'اختر اللغة / Select Language',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              onPressed: () {
                langProvider.changeLanguage(const Locale('ar'));
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen()));
              },
              child: const Text('العربية', style: TextStyle(fontSize: 18, fontFamily: 'Cairo')),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              onPressed: () {
                langProvider.changeLanguage(const Locale('en'));
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen()));
              },
              child: const Text('English', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
