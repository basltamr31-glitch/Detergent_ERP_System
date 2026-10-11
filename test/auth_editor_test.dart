import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:detergent_factory/l10n/app_localizations.dart';
import 'package:detergent_factory/providers/app_language_provider.dart';
import 'package:detergent_factory/screens/auth_screen.dart';
import 'package:detergent_factory/services/auth_service.dart';
import 'package:detergent_factory/services/access_control.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets(
        'Authentication edits survive deletion, composition and rebuilds in $locale',
        (tester) async {
      late Directory directory;
      late AuthService auth;
      final language = AppLanguageProvider()..changeLanguage(Locale(locale));
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('auth_editor_');
        Hive.init(directory.path);
        AccessControl.enabled = true;
        AccessControl.user = null;
        auth = await AuthService.open();
      });
      addTearDown(() async {
        auth.dispose();
        language.dispose();
        AccessControl.user = null;
        AccessControl.enabled = false;
        await Hive.close();
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: language),
          ],
          child: Consumer<AppLanguageProvider>(
              builder: (_, lang, __) => MaterialApp(
                    locale: lang.appLocale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    theme: ThemeData(platform: TargetPlatform.android),
                    home: const AuthScreen(),
                  ))));
      await tester.pumpAndSettle();
      final username = find.byKey(const ValueKey('auth-username'));
      final password = find.byKey(const ValueKey('auth-password'));
      final original = locale == 'ar' ? 'باسل' : 'Owner';
      final deleted = original.substring(0, original.length - 1);
      final replacement = '$deleted${locale == 'ar' ? 'م' : 'X'}';
      await tester.showKeyboard(username);
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: original,
          selection: TextSelection.collapsed(offset: original.length),
          composing: TextRange(start: 0, end: original.length)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: deleted,
          selection: TextSelection.collapsed(offset: deleted.length)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: replacement,
          selection: TextSelection.collapsed(offset: replacement.length)));
      await tester.pump();
      const editedPassword = 'Trial passworX 123';
      await tester.enterText(password, 'Trial password 123');
      await tester.enterText(password, 'Trial passwor 123');
      await tester.enterText(password, editedPassword);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      expect(
          tester.widget<TextFormField>(username).controller!.text, replacement);
      expect(tester.widget<TextFormField>(password).controller!.text,
          editedPassword);
      // Submit through the editor's Done action, using the edited values.
      await tester.showKeyboard(password);
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (auth.user == null || auth.busy) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Edited account did not sign in');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(auth.user!['name'], replacement);
      expect(auth.needsSetup, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
