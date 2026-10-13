# Chromebook test build 1.0.6

This package installs the ERP as an Android application on ChromeOS. It includes ARM (32/64-bit) and x86_64 native libraries, optional touchscreen support and a resizable window. Numeric fields accept a physical keyboard even in a narrow window; the dialpad button opens the touch keypad. The existing Arabic/English Cairo template and offline ERP workflows are retained.

The APK is debug-signed for testing, with application ID `com.example.detergent_factory`, version 1.0.6 and build 7. It has not been published to Google Play. APK compilation and automated checks succeeded; physical Chromebook installation, keyboards, printing and suspend/resume still need device acceptance.

## Install the APK on your Chromebook

Google Play Store availability confirms the Android route is relevant, but does not itself enable installation of this downloaded APK. Use the supported ADB testing route or an owner-managed Google Play testing release.

1. Transfer `Detergent_ERP_ChromeOS_Test_1.0.6.apk` to the Chromebook.
2. In Settings, enable the Linux development environment if permitted. In its settings, open **Develop Android apps**, enable **ADB debugging**, and restart when prompted.
3. Copy the APK into **Linux files** using the Files app. Open the Linux Terminal in that folder and run:

```sh
sudo apt install adb
adb connect arc
# Accept the Chromebook's debugging authorization prompt.
adb install -r ./Detergent_ERP_ChromeOS_Test_1.0.6.apk
```

4. After installation reports `Success`, open **إدارة مصنع المنظفات** from the launcher. Create your own local ERP owner account with a password of at least 12 characters. Choose the language and enter the dashboard.

These steps follow [Google's Chromebook Android development instructions](https://developer.android.com/develop/devices/chromeos/learn/development-environment). Availability depends on the device and its management policy. If the Linux/ADB setting is unavailable or blocked, stop this route and use a permitted Play testing release instead. Do not factory-reset the Chromebook to test the ERP.

An update through `adb install -r` retains app data when application ID and signing key match. If installation reports a signature mismatch, export/preserve the existing app's data before considering any uninstall. Changing the signing key or final application ID requires a planned migration.

## Installation through Google Play

A Play testing release is a separate distribution step. It needs the owner's Play Console account, permanent application ID and private release signing configuration. This repository rejects release builds without those settings; this debug APK cannot serve as that release. No Play Console upload has been performed. See [Flutter's Android release instructions](https://docs.flutter.dev/deployment/android) and [Google Play internal testing instructions](https://support.google.com/googleplay/android-developer/answer/9845334).

## Transfer existing business data

Windows and Chromebook installations have independent accounts and business databases. To transfer a snapshot, export a business backup from Windows, enroll an owner on the Chromebook, then use the ERP backup screen to paste and validate the backup text before confirming restore. Back up the destination first: restore replaces its business dataset. Business backups exclude local account credentials. There is no live synchronization or merge between devices.

## Test the current version

Open `ERP_Test_Pack_1.0.6.html` locally in Chrome on either device. This HTML is the test checklist; the ERP runs in the installed application. It works offline and contains all 101 manual cases plus the names, source paths and captured outcomes of all 72 automated tests.

Enter your tester name, device model and installed build, select **ChromeOS Android** or **Windows**, then follow each case's steps and expected result. Mark Pass, Fail, Blocked or Not applicable and record useful notes. Results begin as Pending. The automated section is a developer-run snapshot, separate from your manual results.

Use **Export results JSON** to save and later import your answers, or **Export results CSV** to share a report. Browser storage may save answers locally, but exporting is the reliable way to keep them after moving the file or clearing browser data. Keep passwords and real customer information out of test notes. Exact business-cycle balances require an empty sample dataset; preserve real data before testing.

Start with ChromeOS installation, sign-in deletion/retyping, narrow/maximized windows, keyboard entry, Arabic layout, restart persistence and backup restoration. Then follow the purchase-to-cash, production, finance, costing, permissions and PDF cases. Physical printing and interruption checks remain device tests.

## Reproduce developer verification

From the repository root with the Flutter/Android toolchains installed:

```sh
flutter pub get
dart analyze lib test > build/chromebook_analysis.log
flutter test --no-pub --machine > build/current_tests.jsonl
flutter build apk --debug --no-pub --target-platform android-arm,android-arm64,android-x64
python scripts/generate-test-pack.py
```

Ensure `build/` exists before redirecting logs. On Windows, run `powershell -File scripts/package-chromebook.ps1` after those commands. The packaging script checks the APK's version, architectures and manifest, refuses to overwrite an existing package, and writes SHA-256 checksums. The generated HTML and APK/ZIP are local build artifacts; their catalogs, generator, packaging script and application changes are committed to GitHub.
