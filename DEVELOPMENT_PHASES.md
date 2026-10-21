# ERP development phases

## Acceptance localization — complete Arabic edition (20 October 2026)

Adds an RTL Arabic acceptance file with translations of all133 case titles/steps/expectations, the seven walkthroughs/checkpoint tables,132 automated display titles, the role/coverage/remaining-scope tables, controls, validation messages and exported approval report. Original technical test names remain in metadata for traceability. Build-time localization preserves IDs, machine result enums, currency amounts, build numbers and the original automated snapshot. The generator validates translation coverage and identical permission matrices. Technical build/date/file tokens are isolated visually without adding hidden characters to copied values.

Verification covers the Arabic approval gates, UTF-8 exports/imports, safe report escaping, RTL report metadata, narrow layout, and result exchange to English and back with Arabic notes intact. Arabic desktop/walkthrough renders were inspected. The default English artifact remains byte-for-byte identical. All test observations were synthetic in a disposable browser context and discarded; no application binary or live business data changed and no manual acceptance was approved for the user.

## Acceptance phase — full implemented-workflow sign-off (20 October 2026)

Expands the manual catalog from125 to133 checks with active-ingredient percentages, Arabic decimals, draft-row deletion, duplicate SKU protection, exact decimal settlement, form cancellation, restore/account separation and multipage Arabic PDFs. Seven ordered walkthroughs specify safe test setup, purchase-to-cash figures, mixed-source manufacturing/trading FIFO, cost-estimate arithmetic, permissions, rejections/corrections and backup/device acceptance. Every catalog case maps to a phase and module/screens.

The self-contained full acceptance HTML records manual observations separately from the existing132-test source snapshot. Its readiness calculation uses an explicit platform/build, requires core cases and actual checkpoint references, and keeps failures/blocked/pending cases visible regardless of filters. N/A needs a reason and remains a scope exclusion requiring review. A downloadable HTML approval report includes all observations, outstanding items and features outside the current build, with a human sign-off line. Imported readiness claims are ignored; old125-case exports leave new cases pending. Unchanged evidence logs retain their original snapshot time.

Playwright verification passed for catalog/coverage rendering, seven walkthroughs, platform/build scope, core/evidence/N/A rules, all incomplete statuses, persistence, phase/platform filters, JSON/CSV import/export, safely escaped report notes and390-pixel layout. All UI-test observations were synthetic in a disposable context and discarded. ERP application source/binaries remain unchanged; no live database was opened and no manual acceptance case was marked passed for the user.

## Windows access phase — separate trial workspace 1.1.1 (20 October 2026)

The reported screenshot shows a running app rejecting a local username/password. Adds explicit trial access through START-TEST.cmd or the regular Windows login's Open test workspace button. The trial workspace provisions an owner-level tester account once, uses normal salted password verification, preserves its own records and displays a persistent TEST banner. It has an independent local-support data directory and native mutex; business data/accounts are not reset or copied. Changed test passwords remain changed.

Corrects a null-ID comparison that marked newly created users signed in before password verification. The runner resolves assets beside the executable and reports an incomplete extraction. New tests cover isolated storage, account provisioning/restart, original business-state preservation, no production tester account and both shortcut/manual tester login through the real app/dashboard. Existing native login tests also exercise trial launch dispatch and the invalid-credential explanation. Windows packaging includes the launcher and bilingual instructions. The existing Android/Chromebook package remains 1.1.0+8.

Verification: all 132 named automated tests passed and static analysis reports no issues. Windows x64 release compiled successfully. The offline checklist contains 125 manual cases and the full captured automated inventory; its persistence, filters, exports/imports and narrow layout passed isolated Chrome checks. The native Windows dialog/process launch is mocked in automated tests; physical Windows acceptance remains to be confirmed on the user's computer. No live business data was opened during development.

## Phase 1 — ERP dashboard and navigation (13 October 2026)

Replaced the long button menu with a responsive workspace. Overview cards show active posted sales, customer/supplier document balances and ledger cash by selected currency. Production approval/quality queues, period closure, financial reconciliation status and recent documents provide context for daily work. Modules are grouped into daily operations and reports/controls, preserving Cairo, Arabic/English and the existing module colors. Readiness/recovery states avoid presenting an unloaded store as zero balances. Admin and backup routes remain role-aware.

Validation covers seeded balances, currency isolation, enlarged text, scrolling and module navigation at phone/desktop widths in both languages, plus actual sign-in/dashboard initialization/logout.

## Phase 2 — labor and overhead costing

Implemented explicit per-batch labor and overhead estimates, persisted production draft v2 migration and a visible cost breakdown in the screen and PDF report. Restored product names now appear in the editor. Dashboard surfaces use white cards with subtle borders, inspected with real Cairo and Material icon fonts. These estimates remain separate from posted inventory valuation and cost of goods sold until the valuation workflow is implemented.

Phase 1 verification: all 65 automated tests pass; static analysis reports no issues. The dashboard is part of the existing app and uses live local records, without changing posted business data.

Phase 2 validation covers batch charges, yield-dependent unit costs, volume-fill estimates, old drafts, persistence and backup schema checks, plus Arabic/English input at phone and desktop widths.

Phase 2 verification: all 71 regression tests pass; static analysis has no findings. Two additional dashboard render checks were inspected with actual Cairo and Material icon fonts. Production and packaging drafts use v2; old v1 fields are read only according to their original schema. Inventory schema remains v12.

## Phase 3 — Windows release 1.0.6

Release metadata matches the application version. The packaging script reads the project version by default and rejects a mismatched executable, preserving existing archives. The complete runtime/assets bundle includes operating, costing and phase guides and a SHA-256 manifest. Build and archive verification are recorded when packaging completes; binaries remain local/ignored rather than committed as source.

Phase 3 build verification: Windows x64 release 1.0.6+7 compiled successfully. A deliberately mismatched package version was rejected before archive creation. Distribution checks cover complete runtime/assets, included guides, archive integrity and the generated SHA-256 manifest.

## Phase 4 — ChromeOS Android build and complete test pack

The installed Android route supports Chromebook devices with Google Play/Android capability. The compiled APK contains armeabi-v7a, arm64-v8a and x86_64 libraries, a resizable activity and optional touchscreen/faketouch requirements. Native numeric editing now accepts physical keyboards even in narrow Android windows, with an optional touch keypad and normalized Arabic decimals. Windows keeps its existing release and credential workflow.

Android debug APK 1.0.6+7 built successfully. All 72 regressions pass, including the new narrow Android keyboard/keypad check; static analysis has no findings. APK identity, version, architectures, compiled resize/touch settings and signing were inspected. The offline acceptance file contains 101 manual cases and the complete captured automated inventory. Its persistence, platform/search filters, JSON/CSV export, valid/invalid import, reset and narrow layout were verified in isolated headless Chrome.

Source-controlled catalogs and generation/packaging scripts reproduce the delivery. Packages include installation/workflow guides and SHA-256 manifests and refuse to overwrite existing archives. Physical Chromebook installation, suspend/resume, keyboard behavior and printing remain pending device acceptance. Approved ADB sideloading is the current installation route; Play distribution still needs the owner's account, permanent application ID and private release signing identity. See CHROMEBOOK_GUIDE.md.


## Warehouse phase 1 — schema 13, units and source-tracked inventory (19 October 2026)

Implements additive SKU/unit definitions, immutable conversion snapshots, generalized finished-stock lots and movements, full allocation of new sales/counts and exact per-source cost reversals. Supplier receipts can enter finished stock through a coordinated domain service; raw receipt quantities can convert to their base unit while retaining invoice amounts. Source costs are distinct from selling reference prices. Unknown legacy costs remain unknown.

A deterministic cutover validates both candidate states, preserves before-images, uses a durable joint migration journal and rejects quantity conflicts before writing. Tests cover older-state imports, interrupted upgrade/paired-write recovery, unit precision, lot/source validation, frozen conversions, supplier refund/return constraints and minor-unit rounding. The integrated workspace regression run passes all 126 named tests; UI and automatic completion are delivered in the following source phase. No live customer data was opened or migrated during development.


## Warehouse phase 2 — trading/production workflows and bilingual warehouse UI

Adds zero-stock SKU registration, product/material unit-definition editors, direct trading receipts, source/cost/movement details, invoice-to-base quantity previews and ID-based sales. Approved sale-ready production can now record actual consumption/yield and QC then atomically receive the selected finished SKU. Planned recipe values remain unchanged; variances require reasons. Bulk output retains the explicit later-packaging route with existing-SKU selection and an optional reviewed total-cost snapshot.

Purchase history distinguishes raw/trading destinations; sales show per-lot source/cost and source filters. The existing Cairo/Arabic/English colors and native platform behavior remain. Four trading and four completion UI cases cover320/1280 widths in both languages; domain tests verify the60-package mixed-source example, frozen conversions, original-lot returns and exact minor-unit cost restoration. All 126 named regressions pass; static analysis is clean. Actual batch costs are explicitly recorded/reviewed, not silently inferred from costing drafts; perpetual valuation/COGS and separate WIP/quality-hold execution remain outside this delivery.


## Warehouse phase 3 — stable packaging editors

Keyed transfer inputs retain their editing state when switching between a new product and a registered SKU. Two English/Arabic regressions enter a source quantity before selecting the SKU and verify deletion/retyping and cancellation preserve the form and original stock. Fixture I/O runs outside widget fake time. The final integrated run passes 128 named tests with no analyzer issues; Windows x64 release and universal Android debug APK compile successfully.


## Warehouse phase 4 — release1.1.0 and acceptance delivery

Windows x64 and the ARM32/ARM64/x86_64 Android test build were rebuilt after the editor fix. The offline acceptance pack contains119 manual cases and the full128-test captured inventory; its notes/persistence, filters, JSON/CSV export, valid/invalid imports and narrow layout were checked in isolated Chrome. The operating guide explains backups, schema13 migration, the combined manufacturing/trading example, explicit cost snapshots and remaining device/business-policy checks. Binary packages and SHA-256 manifests are generated locally; source and verification catalogs are tracked in Git.
