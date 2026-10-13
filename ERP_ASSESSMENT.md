# ERP readiness assessment

Reviewed 4 October 2026. This is an offline factory management prototype. Keep
Flutter, Cairo fonts, Arabic/English localization, and the existing module colors.

## Existing capabilities
Production and packaging costing in USD/SYP; local Hive warehouse stock,
consumption history and manufactured batches; shop stock; PDF costing reports;
Android and Windows platform projects.

## Initial audit findings

The table records the original audit. Implementation sections below describe
which findings have since been addressed and what remains.

| Priority | Evidence | Required work |
| --- | --- | --- |
| P0 | WarehouseProvider writes stock, history and batches separately without awaiting writes. | Transactional posting, durable completion, error handling and crash recovery. |
| P0 | ShopProvider.sellProduct only decreases stock. | Persist numbered invoices, lines, prices, customers, payments and reversals. |
| P0 | Provider constructors initialize Hive asynchronously without error states. | Gate actions on readiness; surface failures and support retry. |
| P0 | ProductionProvider and PackagingProvider hold drafts only in memory. | Save drafts and recipes; integrate manufacturing consumption and output with costing. |
| P0 | Manufacturing accepts negative/non-finite ingredient quantities. | Domain validation for finite positive amounts, valid names, units and stock availability. |
| P0 | Names identify stock and getters expose mutable lists. | Stable IDs, immutable read views and validated repository operations. |
| P0 | No roles, actor identity or protected audit trail; resets clear records. | Permissions and immutable posting history; reverse posted records instead of deleting them. |
| P0 | No backup, restore or migration workflow. | Versioned backups, verified restore, migration and reconciliation tests. |
| P1 | Packaging divides unit size by 1000 to cost against kilograms. | Explicit mass/volume units and density conversion where needed. |
| P1 | Money uses doubles and exchange rate starts at zero. | Defined precision/rounding, currency codes and per-document rate snapshots. |
| P1 | Android release uses debug signing and com.example ID. | Owner-approved application identity and private release signing. |

## Missing ERP workflows

1. Master data: customers, suppliers, SKU IDs, units/conversions, warehouses,
   recipes, packaging components, density and reorder thresholds.
2. Purchasing: orders, goods receipts, supplier bills, returns and payables.
3. Manufacturing: versioned bills of materials, production orders, lots, expiry,
   quality release, waste, labor/overhead and finished-goods transfers.
4. Inventory: unified raw/packaging/finished stock ledger, stock counts,
   adjustments, transfers, valuation and traceability.
5. Sales: quotes/orders, invoices, dispatch, returns, receivables and payments.
   Current shop stock is independent of warehouse manufactured batches.
6. Finance: balanced journals, accounts, cash/bank reconciliation and period locks.
   Country, tax rules, currencies and invoicing requirements need business input.
7. Governance: roles, approvals, audit records, backup, search and management reports.

## Android and Windows

Implemented bottom navigation below 800 logical pixels and a labeled desktop
navigation rail above it. Desktop production content is bounded to 1200 pixels.
The existing main menu is now scrollable and bounded to 720 pixels, and button
labels can wrap. The Windows title uses the app display name. Existing template,
localized labels, fonts and colors are preserved.

Still required: populated-form and dialog responsiveness, large text/landscape
checks, desktop keyboard access (numeric fields currently force a touch keypad),
searchable tables, barcode input, printing/export checks and release packaging.
Validate physical Android devices and Windows with multiple display scale factors.

Each installation currently has its own Hive data. Shared Android/Windows use
requires an authenticated backend, server-side transactions, offline queue,
idempotent posting and conflict resolution. Do not sync live Hive files.

## Delivery sequence

1. Reliability: validation, transactional persistence, initialization errors,
   backups, migrations and meaningful stock/recovery tests.
2. Integrated operations: unified IDs/ledger, purchasing, manufacturing orders,
   finished stock and persistent invoices. Reconcile every posting to stock.
3. Finance and controls: balances, journals, permission checks, audit and jurisdiction settings.
4. Shared deployment: backend/sync if required, signed Android release, Windows
   packaging and documented recovery/update procedures.

The platform changes are an initial improvement, not completion of ERP readiness.

## Reliability implementation progress

Warehouse and shop now migrate their legacy Hive records into separate version-1
aggregate records. A warehouse posting writes stock, movement history and batches
together using one awaited Hive put and flush. Legacy boxes are retained for
recovery and are no longer updated. Each provider rejects overlapping submissions,
exposes initialization errors and retry, and validates finite positive quantities,
nonnegative finite prices, names and consistent stock units. Public inventory
reads return defensive copies. Dialogs await persistence and surface failures.

Tests cover legacy migration, close/reopen persistence, invalid/insufficient stock,
duplicate submission, unsupported schemas, retry, and batch edit/reversal.
This remains a small local-store design: writing full history on each posting is
not appropriate for large datasets. Crash/power-loss fault injection remains
required; successful Hive flush is not a substitute for tested recovery/backups.

## Backup, drafts, and IDs implementation

The main menu now opens an Arabic/English Backup & restore screen. It exports
warehouse, shop and both costing drafts as a versioned JSON file with CRC32
integrity checking and schema validation. Restore validates before writing and
requires confirmation in the app. It saves a safety backup first; when current
data cannot be validated, it preserves the raw records for manual repair instead.
An interrupted restore is replayed from a durable journal before normal startup.
The UI blocks leaving an incomplete restore and provides a retry action.

Production and packaging drafts autosave through ordered writes and reload on
startup. Storage errors appear in the costing workspace with retry. Stock,
movements and batches now have persistent random IDs in aggregate schema v2;
schema v1 and legacy Hive data migrate without changing legacy adapters. Batch
edit/reversal uses IDs and canonical stored amounts instead of caller snapshots.
Existing material recipe links still use names and need ID-based references in
the integrated production-order design.

Backup files are plain JSON business data. CRC32 detects accidental corruption;
it does not provide encryption or authenticity. Keep an off-device copy. File
paths are supported on Windows; Android can also copy/paste the backup text.
These are complete replacement backups, not multi-device synchronization.
Raw recovery files preserve unreadable data and require manual repair; they are
not directly accepted as normal business backups. Physical device/printing and
release-build checks are still outstanding.

Backup-stage validation: 19 automated tests passed, covering persistence, ID migration, backup
integrity, rejected restores, journal replay, raw preservation, and English/Arabic
navigation and backup confirmation at phone/desktop widths. Static analysis has
no errors or warnings; informational lint findings remain, mostly in PDF reports.

## Production and trade documents implementation

Aggregate inventory schema v3 now retains numbered production documents,
correction links, and reversal documents. Correcting a batch reverses the old
consumption and posts a replacement in the same save; failure restores the
previous state. Original batch content is immutable. Cancelling production keeps
the original and a linked reversal. New production links ingredients and stock
movements by stable IDs. Legacy batches retain their original name-based links
without inventing historical movements.

The Business documents menu shows production, supplier receipts and sales.
Supplier receipts capture supplier, reference, item, quantity, unit, currency,
price and payment stated at posting, and atomically increase raw stock. Sales
capture customer and the same trade details while reducing shop stock. Reversals
retain original documents; purchase returns reject insufficient remaining stock.
Sales reversals restore stock once. Posting tokens make form retries idempotent
and reject reused tokens with changed details. Destructive system reset controls
have been removed and reset APIs reject history deletion.

Trade amounts use integer minor units with an explicit application policy of
two decimal places for USD/SYP. Line totals use exact integer arithmetic with
half-up rounding. Trade quantities support six decimal places. Currency is
explicit in entry forms; no currency conversion is assumed. Receipt price
currency is displayed in warehouse reference prices. This does not implement
inventory valuation, tax rules, bank/cash movements, refunds, or a general ledger.
Outstanding amounts reflect the payment stated when the document was posted;
later payments and financial reconciliation are still required.

Backups include document history, and validation checks links, reversal content,
trade totals and receipt/production stock movements. Existing schema v1/v2 records
upgrade to v3; previous sales cannot be reconstructed from historical quantity
reductions. Legacy storage is retained. These are initial single-item receipts
and sales documents, not purchase orders, multi-line tax invoices or dispatches.

Next: unified finished-goods movements between manufacturing and the shop,
customer/supplier master records, multi-line purchasing/sales, and payment
allocation. Then accounting, approvals/permissions, and shared-device services.

All 33 automated tests pass after the document stage. Checks cover failed corrections, immutable originals, idempotent
posting/retries, currency/amount validation, stock-linked receipts, prevented
double reversals, backup reconciliation and v2-to-v3 migration. UI checks exercise
receipt/sales posting and required reversal reasons in English/Arabic, populated
document histories and the warehouse at 320/1280 logical pixels. The warehouse
summary now wraps on narrow screens. Static analysis reports no errors or warnings;
existing informational PDF-report lint findings remain.


## Later document payments (schema v4)

Purchase and sales history now offer Record payment in Arabic and English.
Each payment allocation retains an immutable ID, date, document reference,
request token, amount and optional reference. The original payment-at-posting
remains unchanged. Displayed paid and outstanding balances include subsequent
allocations in the document currency. Positive amounts and remaining balances
are checked before an atomic inventory save; retries cannot create duplicates
or silently change an already posted allocation. Stock is unaffected.

Schema v1-v3 inventory migrates to v4 with empty later-payment history. Backups
include allocations and validate document links, uniqueness and aggregate paid
amounts. Documents with later allocations cannot be reversed until refund
reconciliation is implemented. This stage does not represent a cash/bank ledger,
payment cancellation, cross-invoice allocation or currency conversion.

Remaining next steps: finished-goods transfers with explicit packaging/unit
conversion, customer/supplier master records, multi-line documents, and refund
reconciliation. Android/Windows release and physical-device checks remain open.

Payment-stage validation: all 34 automated tests passed, including payment persistence, duplicate retries, overpayment rejection, backup allocation validation and payment entry at 320/1280 pixels in English/Arabic. Changed sources have no analyzer errors or warnings; existing report informational lints remain.


## Customer and supplier records (schema v5)

The menu now opens Customers & suppliers. Each record has a persistent ID,
name, phone, address and active status. Records can be edited or made inactive;
there is no destructive deletion. Names must be unique within each role.
Customer and supplier roles are separate records stored with their respective
shop/warehouse aggregates, so saves and backup restoration retain the existing
atomic storage safeguards.

Trade entry can select an active saved record or retain a manually entered name.
Linked documents save both the stable party ID and the name at posting; later
edits do not rewrite document history. Reversals preserve the same party ID.
Inactive records cannot be used for new linked documents. Party list entries
show outstanding balances by currency, using linked active documents and later
payments. Legacy/manual-name documents remain unlinked and are excluded from
these record balances; names are not used to guess identities.

Schema v1-v4 data upgrades to v5 without inventing historical master records.
Backups include records and validate uniqueness, contact fields, active flags
and document references. Existing backups remain supported. Next steps are
finished-goods transfers with explicit packaging conversion, multi-item trade
documents and refund reconciliation, followed by accounting and permissions.
Physical Android/Windows release testing remains outstanding.

Validation: all 35 automated tests pass. Coverage includes persisted records,
duplicate names, renaming/deactivation, immutable document-name snapshots,
linked reversals, balances, backup round trips and invalid party references.
Supplier creation and selection are tested at 320/1280 logical pixels in both
English and Arabic, alongside the existing navigation, document and backup checks.

## Completed offline ERP implementation (schema v12)

The earlier stage notes above are historical. The current implementation adds multi-item purchase/sales documents; reconciled payments and refunds; durable paired finished-goods transfers with explicit packaging conversion; immutable stock counts; versioned recipes, production approval and quality release; lot/expiry checks and FIFO allocation; balanced per-currency journals, trial balance and audited accounting-period closure/reopening; device-local owner enrollment, role permissions and hashed credentials; searchable document history and bilingual PDFs.

Business-state migration supports schema versions 1–12 without inventing historical actors, parties or accounting entries. Backup validation includes cross-store transfers, document balances, recipe/order links, journal balance and lot references. Interrupted paired writes are replayed before normal posting. The existing template remains in use, with phone layouts and desktop navigation/keyboard entry.

The independently deployable offline scope is implemented. Enterprise completion still needs confirmed company/tax rules, reviewed opening balances and valuation policy, Android signing identity and SDK license acceptance, physical device/printer acceptance, and a server architecture if installations must share live data. Automatic inventory valuation/COGS, bank reconciliation, payroll and advanced procurement remain outside this baseline. Local role controls are not a tamper-proof server security boundary. See RELEASE_GUIDE.md for installation, recovery and acceptance requirements.

## Verification on 2026-10-10

Flutter 3.38.5 / Dart 3.10.4: all 49 ERP regression tests passed, plus the desktop numeric-entry regression test (50 total). Tests cover durable storage/recovery, backups/migrations, multi-item documents, payments/refunds, roles, periods, production recipes/approval/quality, transfers, counts, FIFO/expiry, bilingual PDFs and English/Arabic phone/desktop layouts. Windows x64 release compilation succeeds. Android debug build is blocked by Gradle dependency downloads; physical Android/Windows/printer acceptance remains pending.

## Business-cycle acceptance stage (10 October 2026)

The user confirmed that Windows 1.0.3 accepts credentials through its native dialog and reaches the ERP menu. A complete isolated purchase-to-cash regression now validates reviewed opening cash, multi-item purchasing, supplier settlement, recipe approval/quality release, explicit unit conversion, FIFO lot allocation, customer settlement, permissions, period locks, persisted balances, full refund/reversal chains and backup restoration. USD and SYP remain separate.

Finance now shows document-to-ledger reconciliation for receivables and payables. A balanced journal alone is insufficient: manual/unallocated opening balances are reported as differences. Finance buttons follow role permissions and coordinated-write locks. The new card passes English/Arabic phone/desktop checks with enlarged text. All 55 regression tests pass, with no analyzer findings. BUSINESS_CYCLE_TEST.md provides expected balances for a manual sample-data walkthrough; the user has confirmed sign-in, not yet every business step or printer/device acceptance. Valuation, COGS, tax and shared deployment remain open.

## Windows 1.0.5 costing accuracy (11 October 2026)

Packaging estimates now use explicit g/kg/ml/L units and measured density for volume fills. Legacy draft values are preserved but require unit confirmation. Packaging draft v2 includes density, units and confirmation; inventory schema remains v12. Reports show fill mass and liquid/container/label breakdowns, require complete inputs and flag missing exchange rates. Label costs are available without a carton. SYP editing requires a configured rate. Narrow-screen layout and calculation overflow guards were improved. All 61 automated tests pass. COSTING_GUIDE.md explains the sample arithmetic and migration; valuation, COGS, waste, labor and overhead posting remain future work.

## Dashboard and batch costing phases (13 October 2026)

The new ERP workspace adds live per-currency overview cards, grouped module navigation, approval/quality queues, period closure and document reconciliation status, recent records and useful empty/loading/error states. English/Arabic phone and desktop layouts were checked with enlarged text and actual font renders. Phase 1 was committed as b1d41c5.

Batch labor and overhead estimates contribute to production and packaging unit costs, with separate components in the screen/PDF. Old production drafts migrate charges as zero, and names remain visible when reopening the editor. Both drafts use v2; inventory schema remains v12. These estimates do not post payroll, expense journals, stock valuation or COGS. Phase 2 was committed as 24f7a80. All 71 regressions pass; analysis is clean. Refer to DEVELOPMENT_PHASES.md for phase evidence and remaining work.

## ChromeOS delivery and acceptance pack (13 October 2026)

The previous Android dependency-download blocker is resolved: debug APK 1.0.6+7 compiles with ARM32, ARM64 and x86_64 libraries. Chromebook compatibility settings allow resizable windows without a touchscreen requirement. Android quantity/cost fields support physical keyboards in narrow windows and an optional touch keypad. All 72 automated tests pass; analysis is clean.

The current release has a single offline HTML acceptance file with 101 manual scenarios and all automated test names/source paths/outcomes. It captures tester/device/build, status and notes, saves locally where possible and exports/imports results. Test/catalog and packaging sources are tracked; generated binary/HTML packages are local artifacts.

Physical Chromebook acceptance and production Android signing/Play distribution remain open. Independent device databases still require explicit backup transfer; there is no live synchronization. Company/tax rules, reviewed opening balances, perpetual stock valuation/COGS, bank reconciliation, payroll and advanced procurement remain business/product work beyond this offline baseline. CHROMEBOOK_GUIDE.md explains installation and testing without treating ChromeOS as a browser application.
