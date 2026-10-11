import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/models/trade_line.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/services/transfer_service.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/finance_service.dart';
import 'package:detergent_factory/services/accounting.dart';
import 'package:detergent_factory/services/state_schema.dart';

void main() {
  late Directory directory;
  late WarehouseProvider warehouse;
  late ShopProvider shop;
  setUp(() async {
    Accounting.clock = DateTime.now;
    AccessControl.enabled = false;
    AccessControl.user = null;
    InventoryCoordinator.busy = false;
    directory = await Directory.systemTemp.createTemp('erp_complete_');
    Hive.init(directory.path);
    warehouse = WarehouseProvider();
    shop = ShopProvider();
    await warehouse.ready;
    await shop.ready;
  });
  tearDown(() async {
    Accounting.clock = DateTime.now;
    AccessControl.enabled = false;
    AccessControl.user = null;
    InventoryCoordinator.busy = false;
    warehouse.dispose();
    shop.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
      'Multiple receipt lines persist and fail atomically on inconsistent units',
      () async {
    const items = [
      TradeInput(
          name: 'Water', quantity: 10, unit: 'Kilogram', unitPriceMinor: 100),
      TradeInput(
          name: 'Fragrance', quantity: 2, unit: 'Liter', unitPriceMinor: 350)
    ];
    await warehouse.receivePurchases(items,
        supplier: 'Supplier', currency: 'USD', requestId: 'multi');
    await warehouse.receivePurchases(items,
        supplier: 'Supplier', currency: 'USD', requestId: 'multi');
    expect(warehouse.purchases.single.lines.length, 2);
    expect(warehouse.purchases.single.totalMinor, 1700);
    final before = warehouse.exportState();
    await expectLater(
        warehouse.receivePurchases([
          const TradeInput(
              name: 'Water',
              quantity: 1,
              unit: 'Kilogram',
              unitPriceMinor: 100),
          const TradeInput(
              name: 'Fragrance',
              quantity: 1,
              unit: 'Kilogram',
              unitPriceMinor: 100)
        ], supplier: 'S', currency: 'USD'),
        throwsArgumentError);
    expect(warehouse.exportState(), before);
    await warehouse.reloadState();
    expect(warehouse.purchases.single.lines.length, 2);
    await warehouse.reversePurchase(
        warehouse.purchases.single.id, 'Return unused goods');
    expect(warehouse.getStock('Water'), 0);
    expect(warehouse.getStock('Fragrance'), 0);
  });
  test('Multi-item sale, actual refunds, return and journals reconcile',
      () async {
    await shop.addProduct('Soap', 10, 'Piece', 2);
    await shop.addProduct('Cleaner', 10, 'Piece', 3);
    const items = [
      TradeInput(name: 'Soap', quantity: 2, unitPriceMinor: 200),
      TradeInput(name: 'Cleaner', quantity: 3, unitPriceMinor: 300)
    ];
    await shop.sellProducts(items,
        customer: 'Customer',
        currency: 'USD',
        paidMinor: 500,
        requestId: 'sale');
    await shop.sellProducts(items,
        customer: 'Customer',
        currency: 'USD',
        paidMinor: 500,
        requestId: 'sale');
    final sale = shop.sales.single;
    expect(sale.totalMinor, 1300);
    expect(shop.journals.length, 1);
    final before = shop.exportState();
    await expectLater(
        shop.sellProducts([
          const TradeInput(name: 'Soap', quantity: 1, unitPriceMinor: 200),
          const TradeInput(name: 'Cleaner', quantity: 99, unitPriceMinor: 300)
        ], customer: 'C', currency: 'USD'),
        throwsStateError);
    expect(shop.exportState(), before);
    await shop.recordPayment(sale.id, 800, requestId: 'settlement');
    await expectLater(shop.reverseSale(sale.id, 'Return'), throwsStateError);
    await expectLater(
        shop.recordRefund(sale.id, 1400, 'Over refund', requestId: 'over'),
        throwsArgumentError);
    await shop.recordRefund(sale.id, 1300, 'Cash refunded',
        requestId: 'refund');
    await shop.recordRefund(sale.id, 1300, 'Cash refunded',
        requestId: 'refund');
    expect(shop.paidFor(sale), 0);
    await shop.reverseSale(sale.id, 'Goods returned');
    expect(shop.getStock('Soap'), 10);
    expect(shop.getStock('Cleaner'), 10);
    expect(shop.journals.length, 4);
    for (final j in shop.journals) {
      Accounting.validate(j);
    }
    await shop.reloadState();
    StateSchema.inventory('shop', jsonDecode(shop.exportState()));
  });
  test('Transfers conserve batch quantity and cannot reverse consumed output',
      () async {
    await warehouse.addMaterial('Water', 20, 'Kilogram', 1);
    await warehouse.produceManufacturedProduct('Cleaner', 10, {'Water': 10});
    final batch = warehouse.manufacturedProducts.single;
    Future<void> transfer() => TransferService.post(warehouse, shop,
        batchId: batch.id,
        sourceQuantity: 5,
        sourceUnit: 'Kilogram',
        productName: 'Cleaner 500g',
        quantity: 10,
        unit: 'Piece',
        unitPriceMinor: 200,
        currency: 'USD',
        requestId: 'transfer');
    await transfer();
    await transfer();
    expect(warehouse.finishedAvailable(batch.id), 5);
    expect(shop.getStock('Cleaner 500g'), 10);
    expect(warehouse.transfers.length, 1);
    expect(shop.transfers.length, 1);
    await expectLater(
        warehouse.reverseProduction(batch.id, 'Cancel'), throwsStateError);
    await shop.sellProduct('Cleaner 500g', 1);
    await expectLater(
        TransferService.reverse(
            warehouse, shop, warehouse.transfers.single.id, 'Return',
            requestId: 'return'),
        throwsStateError);
    await shop.reverseSale(shop.sales.single.id, 'Customer return');
    await TransferService.reverse(
        warehouse, shop, warehouse.transfers.single.id, 'Return',
        requestId: 'return');
    expect(warehouse.finishedAvailable(batch.id), 10);
    expect(shop.getStock('Cleaner 500g'), 0);
    await warehouse.reverseProduction(batch.id, 'Batch returned');
    expect(warehouse.getStock('Water'), 20);
    StateSchema.pair(
        jsonDecode(warehouse.exportState()), jsonDecode(shop.exportState()));
  });
  test('Transfer journal recovers both sides and rejects inconsistent backups',
      () async {
    await warehouse.addMaterial('Water', 20, 'Kilogram', 1);
    await warehouse.produceManufacturedProduct('Cleaner', 10, {'Water': 10});
    final originalShop = shop.exportState();
    await TransferService.post(warehouse, shop,
        batchId: warehouse.manufacturedProducts.single.id,
        sourceQuantity: 2,
        sourceUnit: 'Kilogram',
        productName: 'Bottle',
        quantity: 4,
        unit: 'Piece',
        unitPriceMinor: 100,
        currency: 'USD',
        requestId: 'transfer');
    final payload = {
      'warehouse': jsonDecode(warehouse.exportState()),
      'shop': jsonDecode(shop.exportState())
    };
    final journal = await Hive.openBox<String>('transfer_journal_v1');
    await journal.put('pending', jsonEncode(payload));
    await journal.flush();
    await Hive.box<String>('shop_state_v1').put('state', originalShop);
    InventoryCoordinator.busy = true;
    await expectLater(
        warehouse.addMaterial('Water', 1, 'Kilogram', 1), throwsStateError);
    await TransferService.retry(warehouse, shop);
    expect(shop.getStock('Bottle'), 4);
    expect(journal.containsKey('pending'), false);
    payload['shop']['transfers'].clear();
    expect(() => StateSchema.pair(payload['warehouse'], payload['shop']),
        throwsFormatException);
  });
  test('Period locks are paired and reopening retains history', () async {
    await warehouse.postJournal(
        '1000', '3000', 10000, 'USD', 'Reviewed cash opening',
        requestId: 'opening');
    await FinanceService.setPeriod(
        warehouse, shop, Accounting.today(), 'Month reviewed');
    await expectLater(shop.addProduct('Soap', 1, 'Piece', 1), throwsStateError);
    await expectLater(
        warehouse.postJournal('1000', '3000', 10, 'USD', 'Blocked',
            requestId: 'blocked'),
        throwsStateError);
    await FinanceService.setPeriod(
        warehouse, shop, null, 'Correct approved opening');
    await shop.addProduct('Soap', 1, 'Piece', 1);
    expect(jsonDecode(warehouse.exportState())['periodEvents'].length, 2);
    await warehouse.reloadState();
    expect(warehouse.closedThrough, isNull);
    expect(warehouse.journals.single.reference, 'Reviewed cash opening');
  });
  test('Provider permissions and posted actor identity are enforced', () async {
    AccessControl.enabled = true;
    AccessControl.user = {'id': 'viewer', 'name': 'Viewer', 'role': 'viewer'};
    await expectLater(shop.addProduct('Soap', 1, 'Piece', 1), throwsStateError);
    await expectLater(
        warehouse.addMaterial('Water', 1, 'Kilogram', 1), throwsStateError);
    AccessControl.user = {'id': 'owner', 'name': 'Owner', 'role': 'owner'};
    await shop.addProduct('Soap', 10, 'Piece', 2);
    AccessControl.user = {
      'id': 'cashier',
      'name': 'Cashier',
      'role': 'cashier'
    };
    await shop.sellProduct('Soap', 1);
    expect(shop.sales.single.actor['id'], 'cashier');
    await expectLater(
        shop.postJournal('1000', '3000', 100, 'USD', 'Unauthorized',
            requestId: 'journal'),
        throwsStateError);
    await expectLater(
        FinanceService.setPeriod(warehouse, shop, null, 'Unauthorized'),
        throwsStateError);
  });
  test(
      'Physical counts retain reason, prevent repeat changes and reconcile movements',
      () async {
    await warehouse.addMaterial('Water', 10, 'Kilogram', 1);
    final material = warehouse.materials.single;
    await warehouse.countStock(material.id, 8, 'Physical count sheet',
        requestId: 'count');
    await warehouse.countStock(material.id, 8, 'Physical count sheet',
        requestId: 'count');
    expect(warehouse.getStock('Water'), 8);
    expect(warehouse.counts.length, 1);
    await warehouse.reloadState();
    expect(warehouse.counts.single.before, 10);
    final data = jsonDecode(warehouse.exportState());
    data['counts'][0]['after'] = 7;
    expect(
        () => StateSchema.inventory('warehouse', data), throwsFormatException);
    await shop.addProduct('Soap', 10, 'Piece', 2);
    await shop.countStock(shop.products.single.id, 0, 'Empty shelf',
        requestId: 'empty');
    expect(shop.getStock('Soap'), 0);
    expect(shop.counts.single.after, 0);
  });
  test(
      'Approved recipe orders release once, transfer and trace sale lots with expiry protection',
      () async {
    await warehouse.addMaterial('Water', 100, 'Kilogram', 1);
    final expiry = DateTime.now()
        .toUtc()
        .add(const Duration(days: 5))
        .toIso8601String()
        .substring(0, 10);
    await warehouse.createOrder(
        'Cleaner', 10, 'Kilogram', 'LOT-1', expiry, {'Water': 10},
        requestId: 'order');
    final order = warehouse.orders.single;
    expect(warehouse.getStock('Water'), 100);
    await expectLater(warehouse.releaseOrder(order['id'], 'Quality passed'),
        throwsStateError);
    AccessControl.enabled = true;
    AccessControl.user = {
      'id': 'warehouse',
      'name': 'Warehouse',
      'role': 'warehouse'
    };
    await expectLater(
        warehouse.approveOrder(order['id'], 'Approve'), throwsStateError);
    AccessControl.user = {'id': 'owner', 'name': 'Owner', 'role': 'owner'};
    await warehouse.approveOrder(order['id'], 'Reviewed recipe');
    await warehouse.releaseOrder(order['id'], 'QC record 1 passed');
    await warehouse.releaseOrder(order['id'], 'QC record 1 passed');
    expect(warehouse.productionDocuments.length, 1);
    expect(warehouse.getStock('Water'), 90);
    await TransferService.post(warehouse, shop,
        batchId: warehouse.manufacturedProducts.single.id,
        sourceQuantity: 10,
        sourceUnit: 'Kilogram',
        productName: 'Bottles',
        quantity: 20,
        unit: 'Piece',
        unitPriceMinor: 100,
        currency: 'USD',
        requestId: 'lot-transfer');
    await shop.sellProduct('Bottles', 3, requestId: 'lot-sale');
    await shop.sellProduct('Bottles', 3, requestId: 'lot-sale');
    final transfer = shop.transfers.single;
    expect(shop.sales.single.lines.single.lots, {transfer.id: 3});
    expect(shop.lotRemaining(transfer.id), 17);
    await shop.countStock(shop.products.single.id, 16, 'One damaged bottle',
        requestId: 'damage');
    expect(shop.lotRemaining(transfer.id), 16);
    Accounting.clock =
        () => DateTime.now().toUtc().add(const Duration(days: 6));
    await expectLater(shop.sellProduct('Bottles', 1), throwsStateError);
    Accounting.clock = DateTime.now;
    await shop.reloadState();
    await warehouse.reloadState();
    StateSchema.pair(
        jsonDecode(warehouse.exportState()), jsonDecode(shop.exportState()));
    expect(warehouse.recipes.single['version'], 1);
  });
}
