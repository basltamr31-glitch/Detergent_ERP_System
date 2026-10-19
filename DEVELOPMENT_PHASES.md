# ERP development phases

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


## Warehouse phase 1 — schema13, units and source-tracked inventory (19 October 2026)

Implements additive SKU/unit definitions, immutable conversion snapshots, generalized finished-stock lots and movements, full allocation of new sales/counts and exact per-source cost reversals. Supplier receipts can enter finished stock through a coordinated domain service; raw receipt quantities can convert to their base unit while retaining invoice amounts. Source costs are distinct from selling reference prices. Unknown legacy costs remain unknown.

A deterministic cutover validates both candidate states, preserves before-images, uses a durable joint migration journal and rejects quantity conflicts before writing. Tests cover older-state imports, interrupted upgrade/paired-write recovery, unit precision, lot/source validation, frozen conversions, supplier refund/return constraints and minor-unit rounding. The integrated workspace regression run passes all126 named tests; UI and automatic completion are delivered in the following source phase. No live customer data was opened or migrated during development.
