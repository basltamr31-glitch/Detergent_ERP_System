import 'package:detergent_factory/services/transfer_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/models/trade_line.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/accounting.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';
import 'package:detergent_factory/services/production_completion_service.dart';
import 'package:detergent_factory/services/trading_purchase_service.dart';
import 'package:detergent_factory/services/state_schema.dart';

void main() {
  late Directory directory;
  late WarehouseProvider warehouse;
  late ShopProvider shop;
  late String productId;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_trading_');
    Hive.init(directory.path);
    AccessControl.enabled = false;
    InventoryCoordinator.busy = false;
    Accounting.clock = DateTime.now;
    warehouse = WarehouseProvider();
    shop = ShopProvider();
    await warehouse.ready;
    await shop.ready;
    productId = await shop.registerProduct('Cleaner 1L', 'Package', 'CL-1L');
    await shop.configureProduct(productId,
        name: 'Cleaner 1L',
        sku: 'CL-1L',
        unitConversions: [
          {
            'id': 'carton12',
            'unit': 'Carton',
            'numerator': 12,
            'denominator': 1,
            'revision': 1,
            'allowFraction': false
          }
        ]);
  });
  tearDown(() async {
    AccessControl.enabled = false;
    AccessControl.user = null;
    InventoryCoordinator.busy = false;
    Accounting.clock = DateTime.now;
    warehouse.dispose();
    shop.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<void> buy(String requestId,
          {double quantity = 3,
          int price = 3600,
          String unit = 'Carton',
          String currency = 'USD',
          int paid = 0}) =>
      TradingPurchaseService.receive(
          warehouse,
          shop,
          [
            TradeInput(
                itemId: productId,
                name: 'Cleaner 1L',
                unit: unit,
                quantity: quantity,
                unitPriceMinor: price)
          ],
          supplier: 'Supplier',
          currency: currency,
          paidMinor: paid,
          requestId: requestId);

  test(
      'Same SKU combines production and carton purchasing with exact source costs',
      () async {
    await warehouse.addMaterial('Water', 100, 'Kilogram', 1);
    await warehouse.createOrder(
        'Cleaner', 24, 'Package', 'MAKE-001', '', {'Water': 24},
        requestId: 'make');
    final order = warehouse.orders.single;
    await warehouse.approveOrder(order['id'], 'Approved');
    await ProductionCompletionService.complete(warehouse, shop,
        orderId: order['id'],
        actualIngredients: {warehouse.materials.single.id: 24},
        actualQuantity: 24,
        outputUnit: 'Package',
        qualityNote: 'QC passed',
        finishedProductId: productId,
        requestId: 'complete',
        costMinor: 4800,
        costCurrency: 'USD',
        costStatus: 'confirmed',
        costReference: 'Reviewed batch sheet');
    await buy('buy');
    await buy('buy');
    expect(shop.products.single.quantity, 60);
    expect(warehouse.getStock('Water'), 76);
    expect(warehouse.purchases.single.purchaseKind, 'trading');
    expect(warehouse.purchases.single.totalMinor, 10800);
    expect(warehouse.purchases.single.lines.single.baseQuantity, 36);
    await shop.sellProducts([
      TradeInput(
          itemId: productId,
          name: 'Cleaner 1L',
          quantity: 30,
          unit: 'Package',
          unitPriceMinor: 400)
    ], customer: 'Customer', currency: 'USD', requestId: 'sale');
    expect(shop.products.single.quantity, 30);
    final line = shop.sales.single.lines.single;
    expect(line.lots.values.toList(), [24, 6]);
    expect(
        shop.stockMovements
            .where((m) => m['kind'] == 'sale')
            .fold<int>(0, (a, m) => a + (m['costMinor'] as int)),
        -6600);
    await shop.reloadState();
    await warehouse.reloadState();
    StateSchema.pair(
        jsonDecode(warehouse.exportState()), jsonDecode(shop.exportState()));
    await shop.reverseSale(shop.sales.single.id, 'Returned unopened bottles');
    expect(shop.products.single.quantity, 60);
  });

  test(
      'Original supplier lot required for return; replenishment cannot substitute',
      () async {
    await buy('buy');
    final receipt = warehouse.purchases.single;
    await shop.sellProducts([
      TradeInput(
          itemId: productId,
          name: 'Cleaner 1L',
          quantity: 1,
          unitPriceMinor: 400)
    ], customer: 'C', currency: 'USD');
    await buy('replenish', quantity: 1);
    final before = shop.exportState();
    await expectLater(
        TradingPurchaseService.reverse(warehouse, shop, receipt.id, 'Return',
            requestId: 'return'),
        throwsStateError);
    expect(shop.exportState(), before);
    await shop.reverseSale(shop.sales.single.id, 'Sales return');
    await TradingPurchaseService.reverse(
        warehouse, shop, receipt.id, 'Return original lot',
        requestId: 'return');
    await TradingPurchaseService.reverse(
        warehouse, shop, receipt.id, 'Return original lot',
        requestId: 'return');
    expect(shop.products.single.quantity, 12);
    expect(
        warehouse.purchases.where((d) => d.reversalOf == receipt.id).length, 1);
  });

  test(
      'Purchase and sale preserve invoice and stock units after master revision',
      () async {
    await buy('buy');
    await shop.configureProduct(productId,
        name: 'Cleaner 1L',
        sku: 'CL-1L',
        unitConversions: [
          {
            'id': 'carton12',
            'unit': 'Carton',
            'numerator': 24,
            'denominator': 1,
            'revision': 2,
            'allowFraction': false
          }
        ]);
    await buy(
        'buy'); // Retry uses original entered values, not the revised factor.
    expect(shop.products.single.quantity, 36);
    expect(
        warehouse.purchases.single.lines.single.conversion!['factorNumerator'],
        12);
    await shop.sellProducts([
      TradeInput(
          itemId: productId,
          name: 'Cleaner 1L',
          quantity: 1,
          unit: 'Carton',
          unitPriceMinor: 9600)
    ], customer: 'C', currency: 'USD');
    expect(shop.products.single.quantity, 12);
    expect(shop.sales.single.lines.single.quantity, 1);
    expect(shop.sales.single.lines.single.baseQuantity, 24);
    expect(shop.sales.single.totalMinor, 9600);
  });

  test('Wrong units, changed retries and overpayments leave both stores intact',
      () async {
    final wh = warehouse.exportState(), sh = shop.exportState();
    await expectLater(buy('wrong', unit: 'Liter'), throwsArgumentError);
    await expectLater(buy('paid', paid: 999999), throwsArgumentError);
    expect(warehouse.exportState(), wh);
    expect(shop.exportState(), sh);
    await buy('buy');
    await expectLater(buy('buy', quantity: 2), throwsStateError);
    expect(shop.products.single.quantity, 36);
  });

  test('Trading supplier refunds and returns reconcile the existing journals',
      () async {
    await buy('buy', paid: 10800);
    final receipt = warehouse.purchases.single;
    await expectLater(
        TradingPurchaseService.reverse(warehouse, shop, receipt.id, 'Return',
            requestId: 'return'),
        throwsStateError);
    await warehouse.recordRefund(receipt.id, 10800, 'Actual supplier refund',
        requestId: 'refund');
    await TradingPurchaseService.reverse(warehouse, shop, receipt.id, 'Return',
        requestId: 'return');
    expect(shop.products.single.quantity, 0);
    expect(warehouse.journals.length, 3);
    for (final j in warehouse.journals) {
      Accounting.validate(j);
    }
    StateSchema.pair(
        jsonDecode(warehouse.exportState()), jsonDecode(shop.exportState()));
  });

  test('Mass unit receipt keeps supplier invoice total and raw base quantity',
      () async {
    await warehouse.addMaterial('Powder', 1, 'Kilogram', 2);
    await warehouse.receivePurchases([
      TradeInput(
          itemId: warehouse.materials.single.id,
          name: 'Powder',
          quantity: 500,
          unit: 'Gram',
          unitPriceMinor: 1)
    ], supplier: 'Supplier', currency: 'USD', requestId: 'raw-grams');
    expect(warehouse.getStock('Powder'), 1.5);
    expect(warehouse.purchases.single.totalMinor, 500);
    expect(warehouse.purchases.single.lines.single.baseQuantity, .5);
    await warehouse.reversePurchase(
        warehouse.purchases.single.id, 'Unused powder');
    expect(warehouse.getStock('Powder'), 1);
  });
  test('Intervening sales and return preserve exact minor-unit layer costs',
      () async {
    await warehouse.addMaterial('Water', 3, 'Kilogram', 1);
    await warehouse.createOrder(
        'Tiny batch', 3, 'Package', 'ROUND-01', '', {'Water': 3},
        requestId: 'tiny');
    final order = warehouse.orders.single;
    await warehouse.approveOrder(order['id'], 'Approved');
    await ProductionCompletionService.complete(warehouse, shop,
        orderId: order['id'],
        actualIngredients: {warehouse.materials.single.id: 3},
        actualQuantity: 3,
        outputUnit: 'Package',
        qualityNote: 'QC passed',
        finishedProductId: productId,
        requestId: 'rounding',
        costMinor: 2,
        costCurrency: 'USD',
        costStatus: 'confirmed',
        costReference: 'Reviewed tiny batch');
    Future<void> sale(String token, double quantity) => shop.sellProducts([
          TradeInput(
              itemId: productId,
              name: 'Cleaner 1L',
              quantity: quantity,
              unitPriceMinor: 100)
        ], customer: 'C', currency: 'USD', requestId: token);
    await sale('first', 1);
    final original = shop.sales.single;
    final originalCost = shop.stockMovements
        .singleWhere((m) => m['sourceId'] == original.id)['costMinor'] as int;
    await sale('second', 1);
    await shop.reverseSale(original.id, 'Return first sale after another sale');
    expect(
        shop.stockMovements
            .singleWhere((m) => m['kind'] == 'saleReturn')['costMinor'],
        -originalCost);
    await sale('remaining', 2);
    expect(shop.products.single.quantity, 0);
    expect(
        shop.stockMovements.fold<int>(0, (a, m) => a + (m['costMinor'] as int)),
        0);
    final state = jsonDecode(shop.exportState()) as Map<String, dynamic>;
    (state['stockMovements'] as List).first['costMinor'] = 3;
    expect(() => StateSchema.inventory('shop', state), throwsFormatException);
    await shop.reloadState();
    expect(shop.products.single.quantity, 0);
  });
  test('Bulk packaging selects existing SKU and freezes a reviewed total cost',
      () async {
    await warehouse.addMaterial('Water', 10, 'Kilogram', 1);
    await warehouse.produceManufacturedProduct(
        'Bulk cleaner', 10, {'Water': 10},
        requestId: 'bulk');
    final batch = warehouse.manufacturedProducts.single;
    Future<void> post() => TransferService.post(warehouse, shop,
        batchId: batch.id,
        sourceQuantity: 10,
        sourceUnit: 'Kilogram',
        productId: productId,
        productName: 'Cleaner 1L',
        quantity: 20,
        unit: 'Package',
        unitPriceMinor: 500,
        currency: 'USD',
        requestId: 'pack',
        costMinor: 4000,
        costCurrency: 'USD',
        costStatus: 'confirmed',
        costReference: 'Reviewed packaging sheet');
    await post();
    await post();
    expect(shop.products.single.quantity, 20);
    expect(shop.products.single.unitPrice, 5);
    expect(shop.stockLots.single['costMinor'], 4000);
    expect(shop.stockLots.single['productId'], productId);
    expect(warehouse.finishedAvailable(batch.id), 0);
    await TransferService.reverse(warehouse, shop,
        warehouse.transfers.single.id, 'Return unused packaged stock',
        requestId: 'pack-return');
    expect(shop.products.single.quantity, 0);
    expect(warehouse.finishedAvailable(batch.id), 10);
    expect(
        shop.stockMovements
            .fold<int>(0, (sum, m) => sum + (m['costMinor'] as int)),
        0);
  });
}
