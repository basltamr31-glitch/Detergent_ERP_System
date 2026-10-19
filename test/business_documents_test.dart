import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/services/money.dart';
import 'package:detergent_factory/services/backup_service.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_documents_');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('Later payments persist, retry once and reject overpayment or reversal',
      () async {
    final shop = ShopProvider();
    final warehouse = WarehouseProvider();
    await shop.ready;
    await warehouse.ready;
    await shop.addProduct('Soap', 10, 'Piece', 2);
    await shop.sellProduct('Soap', 3, unitPriceMinor: 200, paidMinor: 100);
    final sale = shop.sales.single;
    await shop.recordPayment(sale.id, 200,
        requestId: 'payment-1', reference: 'Bank');
    await shop.recordPayment(sale.id, 200,
        requestId: 'payment-1', reference: 'Bank');
    expect(shop.payments.length, 1);
    expect(shop.paidFor(sale), 300);
    expect(sale.paidMinor, 100);
    expect(shop.getStock('Soap'), 7);
    await expectLater(shop.recordPayment(sale.id, 400, requestId: 'too-much'),
        throwsArgumentError);
    await expectLater(shop.recordPayment(sale.id, 100, requestId: 'payment-1'),
        throwsStateError);
    await expectLater(shop.reverseSale(sale.id, 'Cancel'), throwsStateError);
    await shop.reloadState();
    expect(shop.paidFor(shop.sales.single), 300);
    await warehouse.receivePurchase(
        supplier: 'Supplier',
        materialName: 'Water',
        quantity: 5,
        unit: 'Kilogram',
        unitPriceMinor: 100,
        currency: 'USD');
    final receipt = warehouse.purchases.single;
    await warehouse.recordPayment(receipt.id, 500,
        requestId: 'supplier-payment');
    expect(warehouse.paidFor(receipt), 500);
    await warehouse.reloadState();
    expect(warehouse.payments.single.amountMinor, 500);
    await expectLater(
        warehouse.reversePurchase(receipt.id, 'Cancel'), throwsStateError);
    final state = jsonDecode(shop.exportState()) as Map<String, dynamic>;
    state['payments'][0]['amountMinor'] = 1000;
    final payload = {
      'warehouse': jsonDecode(warehouse.exportState()),
      'shop': state,
      'production': ProductionProvider().toDraft(),
      'packaging': PackagingProvider().toDraft()
    };
    expect(() => BackupService.validatePayload(payload), throwsFormatException);
    shop.dispose();
    warehouse.dispose();
  });

  test('Party records link new documents and preserve historical names',
      () async {
    final shop = ShopProvider();
    final warehouse = WarehouseProvider();
    await shop.ready;
    await warehouse.ready;
    await shop.saveParty(name: 'Customer', phone: '123', address: 'Street');
    final customer = shop.parties.single;
    await shop.addProduct('Soap', 10, 'Piece', 2);
    await shop.sellProduct('Soap', 1,
        customer: customer.name,
        partyId: customer.id,
        requestId: 'linked-sale');
    await shop.saveParty(
        id: customer.id, name: 'Renamed customer', active: false);
    expect(shop.sales.single.party, 'Customer');
    expect(shop.sales.single.partyId, customer.id);
    expect(shop.outstandingForParty(customer.id), {'USD': 200});
    await expectLater(
        shop.sellProduct('Soap', 1,
            customer: 'Renamed customer', partyId: customer.id),
        throwsStateError);
    await expectLater(
        shop.saveParty(name: 'RENAMED CUSTOMER'), throwsArgumentError);
    await shop.reloadState();
    expect(shop.parties.single.active, false);
    await shop.reverseSale(shop.sales.single.id, 'Returned');
    expect(shop.sales.last.partyId, customer.id);
    expect(shop.outstandingForParty(customer.id), isEmpty);
    await warehouse.saveParty(name: 'Supplier');
    final supplier = warehouse.parties.single;
    await warehouse.receivePurchase(
        supplier: supplier.name,
        partyId: supplier.id,
        materialName: 'Water',
        quantity: 2,
        unit: 'Kilogram',
        unitPriceMinor: 100,
        currency: 'USD');
    await warehouse.reloadState();
    expect(warehouse.purchases.single.partyId, warehouse.parties.single.id);
    final production = ProductionProvider();
    final packaging = PackagingProvider();
    final payload = {
      'warehouse': jsonDecode(warehouse.exportState()),
      'shop': jsonDecode(shop.exportState()),
      'production': production.toDraft(),
      'packaging': packaging.toDraft()
    };
    expect(BackupService.decode(BackupService.encode(payload)), payload);
    payload['shop']['sales'][0]['partyId'] = 'missing-party';
    expect(() => BackupService.encode(payload), throwsFormatException);
    production.dispose();
    packaging.dispose();
    shop.dispose();
    warehouse.dispose();
  });

  test(
      'Purchasing posts once with stock references and blocks consumed-stock return',
      () async {
    final warehouse = WarehouseProvider();
    await warehouse.ready;
    Future<void> receive() => warehouse.receivePurchase(
        supplier: 'Supplier A',
        materialName: 'Water',
        quantity: 10,
        unit: 'Kilogram',
        unitPriceMinor: 225,
        currency: 'USD',
        paidMinor: 1000,
        requestId: 'purchase-retry');
    await receive();
    await receive();
    await expectLater(
        warehouse.receivePurchase(
            supplier: 'Supplier A',
            materialName: 'Water',
            quantity: 11,
            unit: 'Kilogram',
            unitPriceMinor: 225,
            currency: 'USD',
            paidMinor: 1000,
            requestId: 'purchase-retry'),
        throwsStateError);
    expect(warehouse.getStock('Water'), 10);
    expect(warehouse.purchases.length, 1);
    final receipt = warehouse.purchases.single;
    expect(receipt.number, 'PUR-000001');
    expect(receipt.totalMinor, 2250);
    expect(receipt.outstandingMinor, 1250);
    expect(warehouse.transactions.single.documentId, receipt.id);
    expect(warehouse.transactions.single.materialId, receipt.itemId);
    expect(warehouse.materials.single.priceCurrency, 'USD');
    await warehouse.produceManufacturedProduct('Soap', 5, {'Water': 4});
    await expectLater(
        warehouse.reversePurchase(receipt.id, 'Incorrect receipt'),
        throwsStateError);
    expect(warehouse.getStock('Water'), 6);
    expect(warehouse.purchases.length, 1);
    await warehouse.reverseProduction(
        warehouse.manufacturedProducts.single.id, 'Cancel batch');
    await warehouse.recordRefund(
        receipt.id, warehouse.paidFor(receipt), 'Supplier refunded',
        requestId: 'initial-refund');
    await warehouse.reversePurchase(receipt.id, 'Goods returned');
    expect(warehouse.getStock('Water'), 0);
    expect(warehouse.purchases.length, 2);
    expect(warehouse.purchases.first.totalMinor, 2250);
    expect(warehouse.purchases.last.reversalOf, receipt.id);
    await expectLater(
        warehouse.reversePurchase(receipt.id, 'Again'), throwsStateError);
    await expectLater(warehouse.resetWarehouse(), throwsStateError);
    warehouse.dispose();
  });
  test(
      'Invalid correction rolls back reversal and successful correction retains original',
      () async {
    final warehouse = WarehouseProvider();
    await warehouse.ready;
    await warehouse.addMaterial('Water', 10, 'kg', 1);
    await warehouse.produceManufacturedProduct('Original', 5, {'Water': 5});
    final original = warehouse.manufacturedProducts.single;
    await expectLater(
        warehouse
            .editManufacturedProduct(original, 'Too much', 20, {'Water': 20}),
        throwsStateError);
    expect(warehouse.getStock('Water'), 5);
    expect(warehouse.productionDocuments.length, 1);
    expect(warehouse.isProductionReversed(original.id), false);
    await warehouse
        .editManufacturedProduct(original, 'Corrected', 7, {'Water': 7});
    expect(warehouse.productionDocuments.first.name, 'Original');
    expect(warehouse.productionDocuments.first.quantity, 5);
    expect(warehouse.productionDocuments[1].reversalOf, original.id);
    expect(warehouse.productionDocuments.last.replacesId, original.id);
    expect(warehouse.manufacturedProducts.single.name, 'Corrected');
    expect(warehouse.getStock('Water'), 3);
    final snapshot = warehouse.exportState();
    warehouse.dispose();
    await Hive.close();
    Hive.init(directory.path);
    final restarted = WarehouseProvider();
    await restarted.ready;
    expect(restarted.exportState(), snapshot);
    expect(restarted.manufacturedProducts.single.name, 'Corrected');
    restarted.dispose();
  });
  test('Sales snapshot price and currency and reversal restores stock once',
      () async {
    final shop = ShopProvider();
    await shop.ready;
    await shop.addProduct('Soap', 10, 'Piece', 2);
    Future<void> sell() => shop.sellProduct('Soap', 2.5,
        customer: 'Customer A',
        currency: 'SYP',
        unitPriceMinor: 12345,
        paidMinor: 10000,
        requestId: 'sale-retry');
    await sell();
    await sell();
    await expectLater(
        shop.sellProduct('Soap', 3,
            customer: 'Customer A',
            currency: 'SYP',
            unitPriceMinor: 12345,
            paidMinor: 10000,
            requestId: 'sale-retry'),
        throwsStateError);
    expect(shop.getStock('Soap'), 7.5);
    expect(shop.sales.length, 1);
    final sale = shop.sales.single;
    expect(sale.totalMinor, 30863);
    expect(sale.outstandingMinor, 20863);
    await shop.addProduct('Soap', 1, 'Piece', 50);
    expect(shop.sales.single.unitPriceMinor, 12345);
    final snapshot = shop.exportState();
    shop.dispose();
    await Hive.close();
    Hive.init(directory.path);
    final restarted = ShopProvider();
    await restarted.ready;
    expect(restarted.exportState(), snapshot);
    await restarted.recordRefund(
        sale.id, restarted.paidFor(sale), 'Refund to customer',
        requestId: 'customer-refund');
    await restarted.reverseSale(sale.id, 'Customer return');
    expect(restarted.getStock('Soap'), 11);
    expect(restarted.sales.last.reversalOf, sale.id);
    expect(restarted.sales.first.party, 'Customer A');
    await expectLater(
        restarted.reverseSale(sale.id, 'Again'), throwsStateError);
    await expectLater(restarted.resetSales(), throwsStateError);
    restarted.dispose();
  });
  test('Excess payments, invalid currency and quantity cannot create sales',
      () async {
    final shop = ShopProvider();
    await shop.ready;
    await shop.addProduct('Soap', 10, 'Piece', 2);
    await expectLater(
        shop.sellProduct('Soap', 1, unitPriceMinor: 100, paidMinor: 101),
        throwsArgumentError);
    await expectLater(
        shop.sellProduct('Soap', 1, currency: 'BAD'), throwsArgumentError);
    await expectLater(shop.sellProduct('Soap', 0.0000001), throwsArgumentError);
    expect(shop.getStock('Soap'), 10);
    expect(shop.sales, isEmpty);
    shop.dispose();
  });
  test('Backups preserve document history and reject an unreconciled receipt',
      () async {
    final warehouse = WarehouseProvider();
    final shop = ShopProvider();
    await warehouse.ready;
    await shop.ready;
    await warehouse.receivePurchase(
        supplier: 'Supplier',
        materialName: 'Water',
        quantity: 5,
        unit: 'kg',
        unitPriceMinor: 100,
        currency: 'USD');
    final production = ProductionProvider();
    final packaging = PackagingProvider();
    final payload = {
      'warehouse': jsonDecode(warehouse.exportState()),
      'shop': jsonDecode(shop.exportState()),
      'production': production.toDraft(),
      'packaging': packaging.toDraft()
    };
    expect(BackupService.decode(BackupService.encode(payload)), payload);
    payload['warehouse']['transactions'][0]['quantity'] = 1;
    expect(() => BackupService.encode(payload), throwsFormatException);
    warehouse.dispose();
    shop.dispose();
    production.dispose();
    packaging.dispose();
  });
  test('Money parses Arabic decimals and uses exact half-up line rounding', () {
    expect(Money.parse('١٢٫٣٤'), 1234);
    expect(Money.quantity('٢٫٥'), 2.5);
    expect(Money.total(2.5, 12345), 30863);
    expect(Money.total(0.1, 10), 1);
    expect(Money.format(5), '0.05');
    expect(() => Money.parse('1.234'), throwsArgumentError);
    expect(() => Money.total(double.infinity, 100), throwsArgumentError);
    expect(() => Money.total(1000000000, Money.maxMinor), throwsArgumentError);
  });

  test('Production and correction retries do not consume ingredients twice',
      () async {
    final warehouse = WarehouseProvider();
    await warehouse.ready;
    await warehouse.addMaterial('Water', 10, 'kg', 1);
    await warehouse.produceManufacturedProduct('Original', 4, {'Water': 4},
        requestId: 'production-retry');
    await warehouse.produceManufacturedProduct('Original', 4, {'Water': 4},
        requestId: 'production-retry');
    expect(warehouse.getStock('Water'), 6);
    expect(warehouse.productionDocuments.length, 1);
    final original = warehouse.manufacturedProducts.single;
    await warehouse.editManufacturedProduct(
        original, 'Corrected', 5, {'Water': 5},
        requestId: 'correction-retry');
    await warehouse.editManufacturedProduct(
        original, 'Corrected', 5, {'Water': 5},
        requestId: 'correction-retry');
    expect(warehouse.getStock('Water'), 5);
    expect(warehouse.productionDocuments.length, 3);
    await expectLater(
        warehouse.produceManufacturedProduct('Other', 4, {'Water': 4},
            requestId: 'production-retry'),
        throwsStateError);
    warehouse.dispose();
  });

  test(
      'Schema v2 inventory upgrades without inventing historical sales or receipts',
      () async {
    final warehouseBox = await Hive.openBox<String>('warehouse_state_v1');
    final shopBox = await Hive.openBox<String>('shop_state_v1');
    await warehouseBox.put(
        'state',
        jsonEncode({
          'version': 2,
          'materials': [
            {
              'id': 'water',
              'name': 'Water',
              'quantity': 6,
              'unit': 'kg',
              'price': 1
            }
          ],
          'transactions': [],
          'batches': [
            {
              'id': 'batch',
              'name': 'Old batch',
              'quantity': 4,
              'date': '2026-10-01T10:00:00.000',
              'materials': {'Water': 4}
            }
          ]
        }));
    await shopBox.put(
        'state',
        jsonEncode({
          'version': 2,
          'products': [
            {
              'id': 'soap',
              'name': 'Soap',
              'quantity': 10,
              'unit': 'Piece',
              'price': 2
            }
          ]
        }));
    final warehouse = WarehouseProvider();
    final shop = ShopProvider();
    await warehouse.ready;
    await shop.ready;
    expect(warehouse.loadError, isNull);
    expect(shop.loadError, isNull);
    expect(jsonDecode(warehouse.exportState())['version'], 13);
    expect(warehouse.manufacturedProducts.single.id, 'batch');
    expect(warehouse.purchases, isEmpty);
    expect(shop.sales, isEmpty);
    expect(shop.getStock('Soap'), 10);
    await warehouse.reverseProduction('batch', 'Legacy batch cancelled');
    expect(warehouse.getStock('Water'), 10);
    expect(warehouse.productionDocuments.length, 2);
    warehouse.dispose();
    shop.dispose();
  });
}
