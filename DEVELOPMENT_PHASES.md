# ERP development phases

## Phase 1 — ERP dashboard and navigation (13 October 2026)

Replaced the long button menu with a responsive workspace. Overview cards show active posted sales, customer/supplier document balances and ledger cash by selected currency. Production approval/quality queues, period closure, financial reconciliation status and recent documents provide context for daily work. Modules are grouped into daily operations and reports/controls, preserving Cairo, Arabic/English and the existing module colors. Readiness/recovery states avoid presenting an unloaded store as zero balances. Admin and backup routes remain role-aware.

Validation covers seeded balances, currency isolation, enlarged text, scrolling and module navigation at phone/desktop widths in both languages, plus actual sign-in/dashboard initialization/logout.

## Phase 2 — labor and overhead costing

Implemented explicit per-batch labor and overhead estimates, persisted production draft v2 migration and a visible cost breakdown in the screen and PDF report. Restored product names now appear in the editor. Dashboard surfaces use white cards with subtle borders, inspected with real Cairo and Material icon fonts. These estimates remain separate from posted inventory valuation and cost of goods sold until the valuation workflow is implemented.

Phase 1 verification: all 65 automated tests pass; static analysis reports no issues. The dashboard is part of the existing app and uses live local records, without changing posted business data.

Phase 2 validation covers batch charges, yield-dependent unit costs, volume-fill estimates, old drafts, persistence and backup schema checks, plus Arabic/English input at phone and desktop widths.

Phase 2 verification: all 71 regression tests pass; static analysis has no findings. Two additional dashboard render checks were inspected with actual Cairo and Material icon fonts. Production and packaging drafts use v2; old v1 fields are read only according to their original schema. Inventory schema remains v12.
