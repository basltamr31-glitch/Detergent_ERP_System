import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/models/trade_line.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/accounting.dart';
import 'package:detergent_factory/services/backup_service.dart';
import 'package:detergent_factory/services/finance_service.dart';
import 'package:detergent_factory/services/finance_summary.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';
import 'package:detergent_factory/services/transfer_service.dart';

void main() {
  test(
      'Complete business cycle reconciles stock, money, roles, closure, refunds and restored history',
      () async {
    final directory = await Directory.systemTemp.createTemp('erp_acceptance_');
    Hive.init(directory.path);
    AccessControl.enabled = true;
    InventoryCoordinator.busy = false;
    void role(String value) =>
        AccessControl.user = {'id': value, 'name': value, 'role': value};
    role('owner');
    final warehouse = WarehouseProvider(), shop = ShopProvider();
    final production = ProductionProvider(), packaging = PackagingProvider();
    try {
      await warehouse.ready;
      await shop.ready;
      FinanceSummary summary([String currency = 'USD']) => FinanceSummary(
            [...warehouse.journals, ...shop.journals],
            currency,
            documentReceivables: shop.sales
                .where((d) =>
                    d.currency == currency &&
                    d.reversalOf == null &&
                    !shop.isSaleReversed(d.id))
                .fold(0, (sum, d) => sum + d.totalMinor - shop.paidFor(d)),
            documentPayables: warehouse.purchases
                .where((d) =>
                    d.currency == currency &&
                    d.reversalOf == null &&
                    !warehouse.isPurchaseReversed(d.id))
                .fold(0, (sum, d) => sum + d.totalMinor - warehouse.paidFor(d)),
          );
      await warehouse.postJournal(
          '1000', '3000', 20000, 'USD', 'Reviewed opening cash',
          requestId: 'opening');
      await warehouse.postJournal(
          '1000', '3000', 500000, 'SYP', 'Separate currency opening',
          requestId: 'syp-opening');
      await warehouse.saveParty(name: 'Sample supplier');
      await shop.saveParty(name: 'Sample customer');
      role('warehouse');
      await warehouse.receivePurchases(const [
        TradeInput(
            name: 'Water',
            quantity: 100,
            unit: 'Kilogram',
            unitPriceMinor: 100),
        TradeInput(
            name: 'Fragrance',
            quantity: 10,
            unit: 'Kilogram',
            unitPriceMinor: 500),
      ],
          supplier: 'Sample supplier',
          partyId: warehouse.parties.single.id,
          currency: 'USD',
          paidMinor: 3000,
          requestId: 'receipt');
      final purchase = warehouse.purchases.single;
      expect(purchase.totalMinor, 15000);
      expect(summary().payables, 12000);
      expect(summary().reconciled, true);
      role('accountant');
      await warehouse.recordPayment(purchase.id, 12000,
          requestId: 'supplier-payment');
      expect(summary().payables, 0);
      role('warehouse');
      await warehouse.createOrder('Cleaner', 10, 'Kilogram', 'ACCEPT-001', '',
          {'Water': 9, 'Fragrance': 1},
          requestId: 'order');
      final orderId = warehouse.orders.single['id'] as String;
      await expectLater(
          warehouse.approveOrder(orderId, 'Recipe checked'), throwsStateError);
      role('manager');
      await warehouse.approveOrder(orderId, 'Recipe checked');
      role('warehouse');
      await warehouse.releaseOrder(orderId, 'Quality check passed');
      final batch = warehouse.manufacturedProducts.single;
      expect(warehouse.getStock('Water'), 91);
      expect(warehouse.getStock('Fragrance'), 9);
      await TransferService.post(warehouse, shop,
          batchId: batch.id,
          sourceQuantity: 10,
          sourceUnit: 'Kilogram',
          productName: 'Cleaner bottle',
          quantity: 20,
          unit: 'Piece',
          unitPriceMinor: 1000,
          currency: 'USD',
          requestId: 'transfer');
      final transfer = warehouse.transfers.single;
      role('cashier');
      await shop.sellProducts(const [
        TradeInput(name: 'Cleaner bottle', quantity: 4, unitPriceMinor: 1000)
      ],
          customer: 'Sample customer',
          partyId: shop.parties.single.id,
          currency: 'USD',
          paidMinor: 1000,
          requestId: 'sale');
      final sale = shop.sales.single;
      expect(shop.getStock('Cleaner bottle'), 16);
      expect(sale.lines.single.lots[transfer.id], 4);
      expect(summary().receivables, 3000);
      await shop.recordPayment(sale.id, 3000, requestId: 'customer-payment');
      await shop.recordPayment(sale.id, 3000, requestId: 'customer-payment');
      expect(summary().cash, 9000);
      expect(summary().receivables, 0);
      expect(summary().reconciled, true);
      expect(summary('SYP').cash, 500000);
      expect(shop.outstandingForParty(shop.parties.single.id)['USD'], 0);
      role('accountant');
      await FinanceService.setPeriod(
          warehouse, shop, Accounting.today(), 'Acceptance period reviewed');
      await expectLater(
          warehouse.postJournal(
              '5100', '1000', 100, 'USD', 'Closed-period expense',
              requestId: 'blocked'),
          throwsStateError);
      await expectLater(
          FinanceService.setPeriod(
              warehouse, shop, null, 'Unauthorized reopening'),
          throwsStateError);
      role('owner');
      final backup = BackupService.decode(BackupService.encode({
        'warehouse': jsonDecode(warehouse.exportState()),
        'shop': jsonDecode(shop.exportState()),
        'production': production.toDraft(),
        'packaging': packaging.toDraft(),
      }));
      await warehouse.reloadState();
      await shop.reloadState();
      expect(summary().cash, 9000);
      expect(shop.closedThrough, Accounting.today());
      await FinanceService.setPeriod(
          warehouse, shop, null, 'Owner reviewed correction');
      await shop.recordRefund(sale.id, 4000, 'Actual customer refund',
          requestId: 'customer-refund');
      await shop.reverseSale(sale.id, 'Returned all four bottles');
      expect(shop.getStock('Cleaner bottle'), 20);
      await TransferService.reverse(
          warehouse, shop, transfer.id, 'Return complete lot to production',
          requestId: 'transfer-return');
      await warehouse.reverseProduction(
          batch.id, 'Undo production for acceptance check');
      await warehouse.recordRefund(purchase.id, 15000, 'Actual supplier refund',
          requestId: 'supplier-refund');
      await warehouse.reversePurchase(
          purchase.id, 'Return unused raw materials');
      expect(warehouse.getStock('Water'), 0);
      expect(warehouse.getStock('Fragrance'), 0);
      expect(shop.getStock('Cleaner bottle'), 0);
      expect(summary().cash, 20000);
      expect(summary().reconciled, true);
      expect(
          (summary().balances['4000'] ?? 0) + (summary().balances['4010'] ?? 0),
          0);
      expect(
          (summary().balances['5000'] ?? 0) + (summary().balances['5010'] ?? 0),
          0);
      await BackupService.restore(backup);
      await warehouse.reloadState();
      await shop.reloadState();
      expect(warehouse.getStock('Water'), 91);
      expect(shop.getStock('Cleaner bottle'), 16);
      expect(summary().cash, 9000);
      expect(summary().reconciled, true);
      expect(shop.closedThrough, Accounting.today());
      expect(warehouse.orders.single['status'], 'released');
      expect(shop.sales.single.actor['role'], 'cashier');
      // A balanced manual entry can still disagree with operational balances.
      role('owner');
      await FinanceService.setPeriod(
          warehouse, shop, null, 'Review reconciliation warning');
      await warehouse.postJournal(
          '1100', '3000', 100, 'USD', 'Unallocated legacy receivable',
          requestId: 'difference');
      expect(summary().trialDifference, 0);
      expect(summary().receivableDifference, 100);
      expect(summary().reconciled, false);
    } finally {
      warehouse.dispose();
      shop.dispose();
      production.dispose();
      packaging.dispose();
      AccessControl.enabled = false;
      AccessControl.user = null;
      InventoryCoordinator.busy = false;
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
