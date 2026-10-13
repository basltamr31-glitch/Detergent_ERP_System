# ERP development phases

## Phase 1 — ERP dashboard and navigation (13 October 2026)

Replaced the long button menu with a responsive workspace. Overview cards show active posted sales, customer/supplier document balances and ledger cash by selected currency. Production approval/quality queues, period closure, financial reconciliation status and recent documents provide context for daily work. Modules are grouped into daily operations and reports/controls, preserving Cairo, Arabic/English and the existing module colors. Readiness/recovery states avoid presenting an unloaded store as zero balances. Admin and backup routes remain role-aware.

Validation covers seeded balances, currency isolation, enlarged text, scrolling and module navigation at phone/desktop widths in both languages, plus actual sign-in/dashboard initialization/logout.

## Phase 2 — labor and overhead costing

Planned next: explicit per-batch labor and overhead estimates, persisted draft migration and a visible cost breakdown. These estimates will remain separate from posted inventory valuation and cost of goods sold until the valuation workflow is implemented.

Phase 1 verification: all 65 automated tests pass; static analysis reports no issues. The dashboard is part of the existing app and uses live local records, without changing posted business data.
