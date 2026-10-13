# Detergent Factory ERP

An offline Flutter ERP for a detergent factory, retaining the Cairo font, Arabic RTL/English interface and module colors. Current version: **1.0.6+7**. Windows x64 release and Android debug builds have been compiled; Chromebook support uses the installed Android application on ChromeOS.

## Current workflows

- Responsive dashboard: per-currency figures, approval/quality queues, reconciliation and recent documents.
- Customers/suppliers, multi-item purchases/sales, later payments and refunds.
- Versioned production recipes, approvals, quality release, lots/expiry and FIFO allocation.
- Finished-goods transfers with explicit packaging conversion, stock counts and immutable corrections.
- Balanced per-currency journals, trial balance, document reconciliation and accounting-period locks.
- Device-local owner enrollment, roles, salted password verification and sign-in lockout.
- Production/packaging estimates with fill units, measured density, labor and overhead; bilingual PDFs.
- Validated business backups, draft persistence, schema migration and durable recovery for paired writes.

Installations maintain independent accounts and business databases. A backup restore replaces the destination state; it does not merge concurrent changes or synchronize devices. Tax is unset until company/jurisdiction rules are confirmed. Costing estimates do not implement perpetual stock valuation or automatic cost of goods sold. See [ERP assessment](ERP_ASSESSMENT.md) for remaining business scope.

## Install and test the current build

Windows: extract the complete portable ZIP and launch `detergent_factory.exe` with its DLLs and data folder. On first use, create your own local owner with a password of at least 12 characters. Windows offers a native credential dialog; enter ERP account details there. The user confirmed this route reaches the menu.

ChromeOS: install the Android test APK through a permitted ADB setup. It includes ARM32, ARM64 and x86_64 libraries, optional touchscreen support and a resizable window. Physical keyboard numeric entry works at narrow widths with an optional touch keypad. The APK is debug-signed and has not been published to Google Play. Follow [Chromebook installation and test instructions](CHROMEBOOK_GUIDE.md); Play Store availability alone does not install a downloaded APK.

Open `ERP_Test_Pack_1.0.6.html` locally for **101 manual acceptance cases** and the full inventory of **72 passing automated tests**. Filter by platform/category, record status/notes and export JSON or CSV results. Physical Chromebook and printer acceptance remain pending. This HTML is a checklist for testing the installed ERP.

Generated APK/ZIP/HTML files live under ignored `artifacts/` in the build workspace. Source catalogs and scripts are tracked under `qa/` and `scripts/`; binaries are not repository downloads. Review the [release guide](RELEASE_GUIDE.md) before installation/upgrades. See [development phases](DEVELOPMENT_PHASES.md) for verification history.

## Build from source

Toolchain tested with Flutter 3.38.5 and Dart 3.10.4. Windows builds require Visual Studio C++ tools; Android builds require the Android SDK/JDK. The current APK minimum Android API is 24. Linux/macOS platform folders also exist, but these targets have not been verified in this delivery.

```sh
flutter pub get
flutter run -d windows
flutter build windows --release --no-pub
# Universal Android development APK for Android/ChromeOS:
flutter build apk --debug --no-pub --target-platform android-arm,android-arm64,android-x64
```

Windows packaging: `powershell -File scripts/package-windows.ps1`. For ChromeOS packaging, first generate the test file, then run `powershell -File scripts/package-chromebook.ps1`. Packaging checks versions and preserves existing archives.

Production Android releases require the owner's permanent application ID and private signing configuration described in [RELEASE_GUIDE.md](RELEASE_GUIDE.md). The build rejects missing identity/signing settings and never substitutes a debug key for release signing. Do not commit keystores or credentials.

## Verify and regenerate the test pack

Create `build/` if needed, then capture the actual analyzer and test-run output:

```sh
dart analyze lib test > build/chromebook_analysis.log
flutter test --no-pub --machine > build/current_tests.jsonl
python scripts/generate-test-pack.py
```

The generator consumes completed Flutter machine output, validates the manual catalog and embeds the actual automated outcomes and analyzer status. It records log hashes and snapshot time in `qa/automated_inventory.json` and the HTML. The latest suite contains 72 tests with clean static analysis; mocks/temporary stores do not replace physical-device testing.

## Backups and operating guides

Export a verified business backup regularly and keep a copy off the device. Leave the backup path blank for the application documents directory under `ERP Backups`, or copy backup text for manual device transfer. Existing filenames are not overwritten. Restore validates the payload, asks for confirmation and preserves current business data before replacement. Account credentials are device-local and excluded; preserve the full application-data directory separately for device recovery.

Both costing drafts use v2; business storage uses schema v12 with older-state migration. Preserve backups before upgrades and do not run older releases against upgraded data. Interrupted coordinated operations resume before new posting. Keep one Windows ERP instance and do not share the live database folder across devices.

- [Sample purchase-to-cash acceptance cycle](BUSINESS_CYCLE_TEST.md)
- [Production and packaging costing guide](COSTING_GUIDE.md)
- [ChromeOS installation and complete test-pack instructions](CHROMEBOOK_GUIDE.md)
- [Release, recovery and deployment requirements](RELEASE_GUIDE.md)
- [Warehouse reorganization analysis (Arabic, before implementation)](WAREHOUSE_REORGANIZATION_ANALYSIS_AR.md)

## Project structure

- `lib/models/`, `lib/providers/`, `lib/services/`: domain state, persistence and ERP operations.
- `lib/screens/`, `lib/widgets/`: bilingual responsive UI.
- `test/`: automated regression suite.
- `qa/`: manual catalog and captured automated inventory.
- `scripts/`: version-checked distribution and test-pack generation.
- `android/`, `windows/`: currently built native targets.
