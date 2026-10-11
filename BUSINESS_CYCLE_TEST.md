# Business-cycle acceptance walkthrough

Windows sign-in in version 1.0.3 has been confirmed by the user. This walkthrough checks actual daily operation beyond the automated tests. Version 1.0.4 adds the document reconciliation card in Finance.

Use sample records in an empty trial dataset. If this installation already contains real transactions, export a backup first and do not expect these absolute balances to match; use the changes below instead. These steps create real local postings. Do not restore a sample backup over real business records.

Keep currency USD for this exercise. Screen amounts below are dollars (the tests store integer cents). You may perform the steps as owner. For separate-user acceptance, assign the warehouse steps to warehouse staff, approval to a manager, sales/payment to a cashier and financial steps to an accountant. Owner approval is required to reopen a closed period.

1. Customers & suppliers: create Sample supplier and Sample customer.
2. Finance: post reviewed opening cash of $200, debit 1000 Cash and credit 3000 Equity. This is trial funding, not a suggested real business opening balance.
3. Warehouse purchase entry: select Sample supplier. Receive Water, 100 Kilogram at $1 each, and Fragrance, 10 Kilogram at $5 each. Total $150. Enter $30 paid at posting. Do not separately add these raw stocks beforehand.
4. Business documents: record the remaining supplier payment of $120 against that receipt.
5. Operations: plan Cleaner, output 10 Kilogram, lot ACCEPT-001, no expiry for this trial. Ingredients: Water 9 and Fragrance 1. Approve with a review note, then release with the quality check and a note. Raw stocks should become Water 91 and Fragrance 9.
6. Finished-goods transfers: transfer the 10 Kilogram batch into 20 Piece of Cleaner bottle, reference selling price $10. Acknowledge this explicit packaging conversion. Shop stock should be 20 bottles, and untransferred batch stock zero.
7. Sales entry: select Sample customer; sell 4 Cleaner bottle at $10 each. Total $40; enter $10 paid. Shop stock should become 16; the document should show lot ACCEPT-001.
8. Business documents: allocate the customer's remaining payment of $30.
9. Finance: select USD and check the reconciliation card. Ledger/document receivables and payables should agree. Print the sale document to PDF and verify readable Arabic and English text with the correct quantities and payments.
10. Export a business backup, restart the app, sign back in and verify the same stock, documents, payments and ledger balances. Keep the exported backup off the device too.

| After step | Cash | Customer receivable | Supplier payable |
|---|---:|---:|---:|
| Opening cash | $200 | $0 | $0 |
| Purchase with $30 paid | $170 | $0 | $120 |
| Remaining supplier payment | $50 | $0 | $0 |
| Sale with $10 paid | $60 | $30 | $0 |
| Remaining customer payment | $90 | $0 | $0 |

The trial-balance difference must remain zero. This is a cash/document reconciliation check, not a completed profit calculation: inventory valuation and cost of goods sold still require implementation and a reviewed valuation policy.

## Optional controls in the trial dataset

- Close the accounting period through today. Verify a new posting is blocked. Reopen as owner with a reason; accountant/manager reopening must be rejected.
- A cashier must not approve production or change raw stock; a warehouse user must not approve their own production order.
- Record an actual $40 customer refund before reversing the complete sale. Stock returns to 20 bottles. Cash returns to $50; receivables remain zero after the return document posts. Do not claim money was refunded if no actual cash movement occurred.
- Return the complete transfer, reverse the production batch, obtain an actual $150 supplier refund and reverse the receipt. Final raw/shop stock is zero and cash returns to the original $200. Original records and reversal links must remain visible.
- Backup restore replaces business history; test it only in a trial dataset. Local credentials are excluded from business backups.

## Automated evidence

The business-cycle regression checks the same stock/money transitions, currency isolation, payment retry idempotency, lot allocation, permissions, period closure/reopening, full refunds/reversals, persistence, paired-state schema validation and replacement restore. It also verifies that a balanced but unallocated manual receivable is flagged as a reconciliation difference instead of presenting the ledger as reconciled. Actual keyboard, device, printer and power-loss acceptance must still be checked outside widget tests.
