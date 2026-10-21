# ERP release guide

## Arabic acceptance edition

Open ERP_Full_Acceptance_1.1.1_AR.html for the complete Arabic/RTL edition of the133-case full acceptance file. All manual instructions, expected figures, walkthroughs, display names of the132 captured automated tests, controls and the exported report are localized. Test IDs and JSON result statuses remain compatible with the English edition; import a previous results JSON to continue with the same observations. The source evidence timestamp/checksums and app binaries remain unchanged. Use the same TEST-workspace precautions and approval criteria as the English edition.

## Full acceptance file for Windows1.1.1 / ChromeOS1.1.0

ERP_Full_Acceptance_1.1.1.html is a separate, self-contained acceptance artifact:133 manual cases, seven ordered examples, expected cash/stock/costing tables, permission matrix, screen/module coverage and an exportable sign-off report. Start in the TEST workspace and follow the phases before running independent returns/rejection cases. Record actual checkpoint figures and export JSON after each session. Earlier1.1.1 results imports preserve existing observations and leave the eight new cases pending.

Select the platform being approved and its exact installed build. Filters do not affect readiness. All applicable cases must pass; pending/fail/blocked/core exclusions or missing required evidence prevent readiness. Justified N/A remains a scope-review exception. Controlled interruption/legacy migration checks need disposable copied stores and assistance; if unavailable record Blocked. The existing132-test automated snapshot stays separate from user observations and is not proof of native device/printer acceptance. Remaining tax/valuation/COGS/WIP/partial-return/synchronization/distribution work is explicitly listed. The original Windows ZIP retains its earlier125-case file; no application rebuild is needed for this expanded test artifact.

## Windows 1.1.1 test login (20 October 2026)

Extract the full Windows ZIP and open **START-TEST.cmd**, then click **Enter test app / دخول التطبيق التجريبي**. The temporary credentials are username `tester`, password `Tester@2026!Demo`. Read WINDOWS_TEST_LOGIN.md. The explicit `--demo` profile stores its own account and business boxes under the local application support directory's `test-profile-v1` subdirectory, with a separate native instance guard and a persistent amber TEST banner. It starts with empty business records and preserves trial work across restarts.

The regular Windows login page can open the same separate test window. Direct executable launch keeps the original business database and local authentication; no shared account is added there and no existing password is reset. Incorrect credentials now show a bilingual explanation. Creating a user no longer accidentally marks it signed in through a null-ID comparison; the normal password login establishes the session.

The native runner resolves assets from the executable directory and explains an incomplete data folder before engine creation. Packaging includes the test launcher and instructions with the full runtime/assets folder. Automated coverage includes account/storage isolation, persistence, unchanged business records, changed test passwords, one-click login, manual tester login, logout, regular login failure messages and mocked native trial launch. Native window launch, keyboard/device behavior and a clean Windows machine remain manual acceptance checks. The existing Chromebook APK is still 1.1.0+8; this delivery rebuilds Windows only.

This release is an offline factory ERP baseline for independent Windows and Android installations. It preserves the Cairo font, Arabic/English template and module colors. Devices do not share live data; importing a backup replaces the destination business state rather than merging it.

## Windows

Build with `flutter build windows --release --no-pub`, then run `powershell -File scripts/package-windows.ps1`. Extract the complete ZIP into a writable installation folder and launch detergent_factory.exe. Keep the DLLs and data directory beside the executable. The package manifest records SHA-256 and build time. This portable package is unsigned; an installer and publisher signing certificate are still release decisions. Follow Flutter's [Windows distribution requirements](https://docs.flutter.dev/deployment/windows) for the Visual C++ runtime on a clean target PC.

On first launch, create the local owner account with a password of at least 12 characters. The owner can create manager, accountant, warehouse, cashier and viewer accounts. Credentials are device-local and deliberately excluded from business backups. Preserve the local application-data directory separately for full device recovery. Passwords use salted PBKDF2-HMAC-SHA256 with 600,000 iterations; local storage is not encrypted or tamper-proof against someone controlling the Windows account or device. These controls do not replace server authorization for a future shared deployment.

Before upgrading, export and verify a business backup and preserve the full application-data directory. Do not run older releases against data upgraded by this release. Restore the matching old executable and pre-upgrade data together if rollback is necessary. Do not share a live Hive database folder over a network drive.

## Android

The Android debug build now completes successfully with the installed SDK; no license acceptance was automated. Any additional SDK licenses must be reviewed by the device owner if future toolchain changes require them. Configure a permanent application ID and your existing/private release signing identity before production distribution. Copy android/key.properties.example to the ignored android/key.properties and supply the keystore path and credentials privately. Never commit signing files or passwords.

After the SDK is ready, use `flutter build apk --debug` for device testing. Signed releases require the owner application ID through Gradle, for example `ORG_GRADLE_PROJECT_erpApplicationId` in the build environment, plus the private signing properties, then `flutter build appbundle --release`. The build deliberately rejects missing release identity/signing configuration and never substitutes debug signing. Retain the same application ID and signing key for updates. See [Flutter Android release guidance](https://docs.flutter.dev/deployment/android).

## Operating workflow

1. Record suppliers, customers and raw materials; receive multi-item purchases and allocate subsequent payments.
2. Plan production using a versioned recipe, unique lot and optional expiry. A manager/owner approves it; quality release records its check and consumes raw stock.
3. Transfer finished output into sale units using an explicit source-to-destination conversion. Transfers and their returns update both stores through a durable recovery journal.
4. Sell available stock, with FIFO lot allocation and expiry checks. Refund actual money before reversing paid documents. Corrections preserve original records.
5. Count physical stock with a reason. Negative shop counts consume available lots by FIFO; positive adjustments have unknown provenance and should be reviewed.
6. Review per-currency journals and trial balance. Enter reviewed opening balances and manual valuation adjustments, then close the accounting period. Only the owner can reopen it, with a recorded reason.
7. Export backups regularly. Restore validates schema and references, makes a safety backup and replaces business data. Resume a pending transfer recovery before posting new transactions.

## Acceptance and remaining business scope

Automated widget tests cover narrow phone and desktop widths in English/Arabic, production approval/release, transfers, finance, authentication and PDF generation. Run acceptance checks on a clean Windows PC, a physical Android device and your printer: installation, restart, keyboard/touch entry, Arabic font/RTL, printing, backup restoration and interruption recovery. A successful compilation does not verify a physical printer or Android hardware.

Tax jurisdiction, legal invoice fields, company identity and opening balances require business confirmation. PDFs are goods/payment documents and explicitly leave tax unset. Purchase journals use an expense/purchases account; automatic perpetual inventory valuation, cost of goods sold, tax posting, bank reconciliation, payroll, purchase-order approval chains, partial returns and shared-device synchronization are future work. Existing historical postings are not reconstructed as financial journals during migration. Review opening balances with the responsible accountant before relying on financial reports.

The earlier Gradle download failure has been resolved. Android debug APK 1.0.6+7 was built on 13 October 2026 with ARM32, ARM64 and x86_64 libraries. Release signing and physical-device acceptance remain separate steps.

## Windows 1.0.1 startup repair

Windows now permits one running ERP process per session. Opening another copy brings the existing window forward instead of attempting to lock the same database again. Close all older builds before launching 1.0.1: those older executables do not participate in the new instance guard. If a lock remains, close detergent_factory.exe processes in Task Manager and retry. Do not delete database or lock files to recover. Existing business data and account files remain in their original storage location. The default Windows Documents path can be redirected into OneDrive by Windows; this patch does not relocate or overwrite existing data.

## Windows 1.0.2 authentication editor repair

Username/password editors now have persistent controllers. Submission captures the displayed values before asynchronous updates. Autocorrection, spelling and smart substitutions are disabled; password suggestions and IME personalized learning are disabled. Password visibility can be toggled and Enter submits. Field validation appears inline in Arabic/English. Regression tests exercise composing text, deletion/retyping, visibility/language rebuilds and account creation/sign-in with the resulting edited values. All 53 automated tests pass; native Windows IME acceptance still requires testing with the user's keyboard.

## Windows 1.0.3 sign-in repair

The sign-in page is now a normal route inside MaterialApp's Navigator, providing the Overlay required by editable controls and tooltips. Login/logout reset the route tree through the session key. The Windows default sign-in button opens a native Windows credential dialog, bypassing the Flutter editor path that repeated deleted letters on the user's computer. Enter local ERP credentials, not a Windows account. Cancellation changes nothing. The existing owner account and business data remain in place. The optional in-app editor is available through Use in-app fields.

The native integration uses generic credentials with DO_NOT_PERSIST; it neither authenticates against Windows accounts nor saves passwords to Windows Credential Manager. It forwards the entered values to the existing ERP password verification, roles and lockout checks. See Microsoft's CredUIPromptForCredentialsW documentation: https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-creduipromptforcredentialsw . Full-app tests cover cancellation, account creation, arrival at language selection and the real menu, logout and subsequent sign-in. The native dialog itself still needs the user's keyboard acceptance check; the automated test mocks its method-channel response.

## Windows 1.0.4 business-cycle validation

The user confirmed successful native Windows sign-in and arrival at the ERP menu. Finance now compares journal receivables/payables against active documents after payments/refunds, displays ledger cash and identifies discrepancies, including legacy opening balances/manual control-account entries. UI posting controls follow role permissions and pending paired-write locks. BUSINESS_CYCLE_TEST.md gives a sample purchase-to-cash walkthrough and expected balances. Automatic inventory valuation and profit/COGS remain outside this release.

## Windows 1.0.5 costing upgrade

Review COSTING_GUIDE.md after upgrading. Old packaging draft values survive, but you must confirm their fill units before generating cost reports. Volume fills require measured density. Export a backup before upgrading; do not run an older executable against the new packaging draft version. Existing account and operational inventory data remain in place. All 61 tests pass; actual printer/device acceptance remains pending.

## Windows 1.0.6 phased delivery (13 October 2026)

The workspace now opens a responsive dashboard with per-currency sales, document balances, ledger cash, production approval/quality queues, reconciliation status and recent documents. Navigation is grouped into daily operations and reports/controls with Cairo, Arabic RTL and the existing module colors. Dashboard readiness/errors appear before financial figures are presented.

Production estimates now include explicit per-batch labor and overhead. Reports separate raw-material cost, labor and overhead, then derive cost per good-output kilogram and packaging estimates. Production draft v2 migrates old v1 charges as zero; inventory schema remains v12. Product names reload into the editor. Both drafts use v2; preserve matching backups for rollback to earlier builds. Tax, automatic inventory valuation/COGS, shared synchronization and Android release identity/device acceptance remain pending.

Phase 1 and phase 2 were committed separately and verified. All 71 regression tests pass and analysis is clean; additional English/Arabic dashboard renders were inspected using actual fonts. See DEVELOPMENT_PHASES.md and COSTING_GUIDE.md. Windows packaging now reads the project version and rejects a mismatch with the executable metadata.


## ChromeOS Android test build and acceptance pack (13 October 2026)

A debug-signed installed Android build is available for Chromebook devices with Android support. The manifest permits a resizable window and does not require a touchscreen. Android numeric fields accept physical keyboard input at narrow widths and retain an optional touch keypad; Arabic decimal normalization is covered by a regression test.

See [CHROMEBOOK_GUIDE.md](CHROMEBOOK_GUIDE.md) for approved ADB installation and the separate Google Play testing-release route. Google Play Store availability does not itself install our downloaded APK. The test build retains the development application ID; it is not a published or production-signed release. No physical Chromebook has been connected for acceptance.

All 72 automated tests pass and static analysis is clean. The offline HTML acceptance pack contains 101 manual scenarios, the complete captured automated inventory, filters, notes and JSON/CSV results export/import. Generate it with scripts/generate-test-pack.py from completed Flutter machine output and the analyzer log; package the APK, guides and checklist with scripts/package-chromebook.ps1. The package records checksums and actual automated verification metadata. Binary and generated HTML artifacts remain local/ignored; source catalogs and scripts are committed.


## Warehouse release 1.1.0+8 (19 October 2026)

Read WAREHOUSE_UPGRADE_GUIDE_AR.md before opening existing business data. Schema 13 adds SKU/unit definitions, generic source/cost lots, movements and fully allocated sales. The shared migration preserves before-images and validates reconciled candidate states before either is written, then uses a durable recovery journal. Unknown old sources/costs remain unknown. Existing accounts, business document identifiers, payments, period locks and costing draftv2 remain.

The UI separates raw and trading procurement while retaining a single finished SKU for manufacturing/supplier stock. Approved sale-ready production records actual inputs/output and receives finished stock in one coordinated posting. Bulk production still uses an explicit later-packaging transfer, now with existing SKU selection and an optional reviewed totalcost snapshot. Quantities/units/factors are frozen per document. Returns require original lot availability and preserve exact source costs.

All 128 named automated tests pass and static analysis has no issues. The acceptance pack includes 119 manual cases and the complete captured regression inventory. Automatic raw-material consumption valuation, perpetual inventory/COGS journals, separate WIP/quality-hold execution, partial returns, tax setup and live device synchronization remain outside this release. Batch costs are entered/reviewed explicitly; reference selling prices and estimating drafts are not historical actual costs.
