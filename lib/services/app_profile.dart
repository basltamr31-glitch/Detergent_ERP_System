import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

/// Explicit trial storage. Production never provisions a shared account.
class AppProfile {
  const AppProfile({this.isTest = false});
  factory AppProfile.fromArguments(List<String> arguments) =>
      AppProfile(isTest: arguments.contains('--demo'));

  final bool isTest;
  static const testerName = 'tester';
  static const testerPassword = 'Tester@2026!Demo';
  static const testDirectoryName = 'test-profile-v1';

  Future<void> initializeStorage() async {
    if (!isTest) {
      await Hive.initFlutter();
      return;
    }
    // Local application support avoids Documents/OneDrive and the real boxes.
    final support = await getApplicationSupportDirectory();
    final directory =
        Directory('${support.path}${Platform.pathSeparator}$testDirectoryName');
    await directory.create(recursive: true);
    Hive.init(directory.path);
  }

  Future<void> prepareAccount(AuthService auth) async {
    if (isTest && auth.needsSetup) {
      await auth.saveUser(
          name: testerName, role: 'owner', password: testerPassword);
    }
  }
}
