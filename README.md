# Detergent Factory ERP

An offline Flutter ERP for a detergent factory, retaining the Cairo font, Arabic RTL/English interface and module colors. Current Windows version: **1.1.1+9**. Latest packaged Chromebook/Android test build: **1.1.0+8**. Chromebook support uses the installed Android application on ChromeOS.

## Current workflows

- Responsive dashboard: per-currency figures, approval/quality queues, reconciliation and recent documents.
- Separate raw-material purchasing and direct trading-goods receipts, with unified finished-SKU sales, later payments and refunds.
- Item-specific package/carton conversions, immutable invoice/base-unit snapshots, generalized receipt lots, full sale allocations and exact source-cost returns.
- Approved production completion with actual consumption/yield and one recoverable finished receipt; reviewed total cost snapshots remain distinct from cost-estimating drafts and COGS.
- Versioned production recipes, approvals, quality release, lots/expiry and FIFO allocation.
- Finished-goods transfers with explicit packaging conversion, stock counts and immutable corrections.
- Balanced per-currency journals, trial balance, document reconciliation and accounting-period locks.
- Device-local owner enrollment, roles, salted password verification and sign-in lockout.
- Production/packaging estimates with fill units, measured density, labor and overhead; bilingual PDFs.
- Validated business backups, draft persistence, schema migration and durable recovery for paired writes.

Installations maintain independent accounts and business databases. A backup restore replaces the destination state; it does not merge concurrent changes or synchronize devices. Tax is unset until company/jurisdiction rules are confirmed. Costing estimates do not implement perpetual stock valuation or automatic cost of goods sold. See [ERP assessment](ERP_ASSESSMENT.md) for remaining business scope.

## Install and test the current build

Windows trial: extract the complete portable ZIP, open **START-TEST.cmd**, and click **Enter test app**. A separate test workspace has username `tester` and password `Tester@2026!Demo`; no typing is required for the shortcut. Test records persist independently of the existing business database. See [Windows test access](WINDOWS_TEST_LOGIN.md). The regular login page also offers **Open test workspace**.

Windows business access: launch `detergent_factory.exe` directly with its DLLs and data folder. Use the local account created on this computer, or create the first owner on a new business installation. The temporary tester credentials are provisioned only in the explicit trial workspace. Business accounts, password verification and lockout remain in place.

ChromeOS: install the Android test APK through a permitted ADB setup. It includes ARM32, ARM64 and x86_64 libraries, optional touchscreen support and a resizable window. Physical keyboard numeric entry works at narrow widths with an optional touch keypad. The APK is debug-signed and has not been published to Google Play. Follow [Chromebook installation and test instructions](CHROMEBOOK_GUIDE.md); Play Store availability alone does not install a downloaded APK.

Open **ERP_Full_Acceptance_1.1.1.html** for **133 manual acceptance cases**, seven ordered walkthroughs with exact stock/money/costing checkpoints, the role matrix, module coverage and an exportable approval report. It includes the captured inventory of **132 passing automated tests**, separately from your manual observations. Failed, blocked, pending, unexplained N/A or missing core evidence prevent a Ready recommendation. Justified exclusions require scope review. Record the actual installed build, including 1.1.0+8 for the existing Chromebook APK. Physical Windows/Chromebook and printer acceptance remain pending.

The original Windows 1.1.1 ZIP retains its earlier 125-case checklist; the expanded full acceptance HTML is a separate, self-contained file and needs no app rebuild. Import earlier 1.1.1 results JSON to preserve observations; the eight new cases remain pending. Filter by phase/platform/category, record actual results and export JSON after each session. The file records user observations and cannot inspect or automatically approve the ERP database.

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

The generator consumes completed Flutter machine output, validates the manual catalog and walkthrough coverage, and embeds the actual automated outcomes and analyzer status. It records log hashes and snapshot time in `qa/automated_inventory.json` and the HTML; unchanged source logs keep the original capture time. The latest suite contains 132 tests with clean static analysis; mocks/temporary stores do not replace physical-device testing.

Generate the full acceptance artifact with `--output artifacts/ERP_Full_Acceptance_1.1.1.html` and the appropriate `--results`/`--analysis` log paths. Its standalone HTML inlines `qa/acceptance_plan.json` and `qa/acceptance_ui.js`. With Playwright and Chrome available, `node scripts/verify-acceptance-pack.cjs` verifies the checklist's approval rules, platform scope, required observations, backward-compatible import, safe report generation and narrow layout using disposable synthetic results only. It does not mark any real manual case passed.

See [the warehouse1.1 upgrade and operating guide (Arabic)](WAREHOUSE_UPGRADE_GUIDE_AR.md) before using the new migration and purchasing/production flows. Physical-device acceptance remains necessary; costs are recorded explicitly, not inferred as perpetual inventory valuation.

## Backups and operating guides

Export a verified business backup regularly and keep a copy off the device. Leave the backup path blank for the application documents directory under `ERP Backups`, or copy backup text for manual device transfer. Existing filenames are not overwritten. Restore validates the payload, asks for confirmation and preserves current business data before replacement. Account credentials are device-local and excluded; preserve the full application-data directory separately for device recovery.

Both costing drafts use v2; business storage uses schema v13 with older-state migration. Preserve backups before upgrades and do not run older releases against upgraded data. Interrupted coordinated operations resume before new posting. Keep one Windows ERP instance and do not share the live database folder across devices.

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
