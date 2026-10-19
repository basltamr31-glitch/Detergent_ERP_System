import 'dart:convert';

import 'package:detergent_factory/services/finished_stock.dart';
import 'package:detergent_factory/services/inventory_migration.dart';
import 'package:detergent_factory/services/inventory_units.dart';
import 'package:detergent_factory/services/stock_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actor = {'id': 'owner', 'name': 'Owner', 'role': 'owner'};
  const date = '2026-01-10T00:00:00.000Z';
  final carton = <String, dynamic>{
    'id': 'carton-12',
    'unit': 'Carton',
    'numerator': 12,
    'denominator': 1,
    'revision': 1,
    'allowFraction': false,
  };
  Map<String, dynamic> empty() => InventoryMigration.shop({
        'version': 12,
        'products': [
          {
            'id': 'p1',
            'name': 'Cleaner',
            'quantity': 0.0,
            'unit': 'Piece',
            'price': 5.0
          }
        ],
        'sales': <Map<String, dynamic>>[],
        'transfers': <Map<String, dynamic>>[],
        'counts': <Map<String, dynamic>>[],
        'ledgerStartedAt': '2026-01-01T00:00:00.000Z',
      });
  Map<String, dynamic> copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  void receive(Map<String, dynamic> state,
          {double quantity = 20,
          String sourceKind = 'adjustment',
          String sourceId = 'opening-receipt',
          String lotId = 'l1',
          String expiry = '',
          String? supplierId,
          int? costMinor,
          String? currency}) =>
      FinishedStock.receive(state,
          lotId: lotId,
          productId: 'p1',
          sourceKind: sourceKind,
          sourceId: sourceId,
          quantity: quantity,
          unit: 'Piece',
          date: date,
          expiry: expiry,
          lot: 'LOT-1',
          supplierId: supplierId,
          costMinor: costMinor,
          currency: currency,
          costStatus: costMinor == null ? 'unknown' : 'confirmed',
          actor: actor,
          requestId: 'receipt-$lotId');
  void sell(Map<String, dynamic> state,
      {double quantity = 3,
      double? allocated,
      String unit = 'Piece',
      Map<String, dynamic>? conversion}) {
    final amount = allocated ?? quantity;
    FinishedStock.record(state,
        productId: 'p1',
        sourceId: 's1',
        kind: 'sale',
        allocations: {'l1': amount},
        date: date,
        actor: actor,
        requestId: 'sale-1',
        direction: -1);
    state['products'][0]['quantity'] -= amount;
    state['sales'].add(<String, dynamic>{
      'id': 's1',
      'type': 'sale',
      'date': date,
      'stockTracked': true,
      'lines': [
        <String, dynamic>{
          'itemId': 'p1',
          'unit': unit,
          'quantity': unit == 'Piece' ? quantity : 2.0,
          'stockQuantity': quantity,
          'stockUnit': 'Piece',
          if (conversion != null) 'conversion': conversion,
          'lots': {'l1': amount},
        }
      ],
    });
  }

  test('Legacy baselines validate without invented raw lots or cost', () {
    final shop = InventoryMigration.shop({
      'version': 1,
      'products': [
        {
          'name': 'Undated product',
          'quantity': 0.00000001,
          'unit': '',
          'price': 1.0
        }
      ],
    });
    StockSchema.validate(shop);
    final raw = InventoryMigration.warehouse({'version': 1, 'materials': []});
    StockSchema.pair(raw, shop);
  });

  test('Receipt, complete sale allocations and count shortages conserve stock',
      () {
    final shop = empty();
    receive(shop, costMinor: 10000, currency: 'USD');
    sell(shop);
    FinishedStock.record(shop,
        productId: 'p1',
        sourceId: 'count1',
        kind: 'count_out',
        allocations: {'l1': 2},
        date: date,
        actor: actor,
        requestId: 'count-1',
        direction: -1);
    shop['products'][0]['quantity'] = 15.0;
    shop['counts'].add({
      'id': 'count1',
      'itemId': 'p1',
      'before': 17.0,
      'after': 15.0,
      'stockTracked': true,
      'lots': {'l1': 2.0},
    });
    StockSchema.validate(shop);
  });

  test('Partial allocation and missing document postings are rejected', () {
    final partial = empty();
    receive(partial);
    sell(partial, quantity: 4, allocated: 3);
    expect(() => StockSchema.validate(partial), throwsFormatException);
    final missing = empty();
    receive(missing);
    sell(missing);
    missing['stockMovements'].removeLast();
    missing['products'][0]['quantity'] = 20.0;
    expect(() => StockSchema.validate(missing), throwsFormatException);
  });

  test(
      'Legacy partial sale return restores known lots and an unknown remainder',
      () {
    final oldSale = <String, dynamic>{
      'id': 'old-sale',
      'type': 'sale',
      'date': date,
      'lines': [
        {
          'itemId': 'p1',
          'unit': 'Piece',
          'quantity': 5.0,
          'lots': {'t1': 3.0}
        }
      ],
    };
    final shop = InventoryMigration.shop({
      'version': 12,
      'products': [
        {
          'id': 'p1',
          'name': 'Cleaner',
          'quantity': 17.0,
          'unit': 'Piece',
          'price': 1.0
        }
      ],
      'transfers': [
        {
          'id': 't1',
          'batchId': 'old-batch',
          'productId': 'p1',
          'quantity': 20.0,
          'unit': 'Piece',
          'date': date,
          'lot': 'LOT-1',
          'expiry': ''
        }
      ],
      'sales': [oldSale],
    });
    FinishedStock.record(shop,
        productId: 'p1',
        sourceId: 'old-return',
        kind: 'saleReturn',
        allocations: {'t1': 3.0},
        date: date,
        actor: actor,
        requestId: 'old-return');
    shop['products'][0]['quantity'] = 20.0;
    FinishedStock.receive(shop,
        lotId: 'untraced-return',
        productId: 'p1',
        sourceKind: 'legacy_opening',
        sourceId: 'old-return',
        quantity: 2,
        unit: 'Piece',
        date: date,
        actor: actor,
        requestId: 'old-return');
    final returned = copy(oldSale);
    returned['id'] = 'old-return';
    returned['type'] = 'saleReturn';
    returned['stockTracked'] = false;
    returned['reversalOf'] = 'old-sale';
    shop['sales'].add(returned);
    StockSchema.validate(shop);
    expect(shop['products'][0]['quantity'], 22.0);
    expect(shop['stockLots'][1]['costStatus'], 'unknown');
    final corrupt = copy(shop);
    corrupt['stockLots'][1]['sourceKind'] = 'adjustment';
    expect(() => StockSchema.validate(corrupt), throwsFormatException);
  });

  test('Frozen conversion arithmetic survives later master changes', () {
    final shop = empty();
    receive(shop, quantity: 36);
    shop['products'][0]['unitConversions'] = [copy(carton)];
    final conversion = InventoryUnits.snapshot(2, 'Carton', 'Piece', [carton]);
    sell(shop, quantity: 24, unit: 'Carton', conversion: conversion);
    shop['products'][0]['unitConversions'][0]['numerator'] = 24;
    StockSchema.validate(shop);
    final corrupt = copy(shop);
    corrupt['sales'][0]['lines'][0]['conversion']['factorNumerator'] = 13;
    expect(() => StockSchema.validate(corrupt), throwsFormatException);
  });

  test('Duplicate SKUs, unknown-cost amounts and balance drift are rejected',
      () {
    final shop = empty();
    receive(shop);
    final duplicate = copy(shop);
    duplicate['products'].add({
      'id': 'p2',
      'name': 'Other',
      'quantity': 0.0,
      'unit': 'Piece',
      'price': 0.0,
      'sku': 'SKU-p1',
      'unitConversions': [],
    });
    duplicate['stockBaseline']['p2'] = 0.0;
    expect(() => StockSchema.validate(duplicate), throwsFormatException);
    final cost = copy(shop);
    cost['stockLots'][0]['costMinor'] = 0;
    expect(() => StockSchema.validate(cost), throwsFormatException);
    final drift = copy(shop);
    drift['products'][0]['quantity'] = 21.0;
    expect(() => StockSchema.validate(drift), throwsFormatException);
  });

  test('Movement overruns, duplicate postings and orphan sales are rejected',
      () {
    final shop = empty();
    receive(shop);
    final overrun = copy(shop);
    sell(overrun, quantity: 21);
    expect(() => StockSchema.validate(overrun), throwsFormatException);
    final duplicate = copy(shop);
    final movement =
        copy({'movement': duplicate['stockMovements'][0]})['movement'];
    movement['id'] = 'duplicate-id';
    duplicate['stockMovements'].add(movement);
    expect(() => StockSchema.validate(duplicate), throwsFormatException);
    sell(shop);
    shop['sales'].clear();
    expect(() => StockSchema.validate(shop), throwsFormatException);
  });

  test('Held or expired lots cannot supply active tracked sales', () {
    final held = empty();
    receive(held);
    sell(held);
    held['stockLots'][0]['status'] = 'held';
    expect(() => StockSchema.validate(held), throwsFormatException);
    final expired = empty();
    receive(expired, expiry: '2026-01-10');
    sell(expired);
    expect(() => StockSchema.validate(expired), throwsFormatException);
  });

  test('Supplier purchase and full return match invoice quantities and cost',
      () {
    final shop = empty();
    final conversion = InventoryUnits.snapshot(2, 'Carton', 'Piece', [carton]);
    final purchase = <String, dynamic>{
      'id': 'purchase1',
      'purchaseKind': 'trading',
      'type': 'purchase',
      'partyId': 'supplier1',
      'currency': 'USD',
      'lines': [
        {
          'itemId': 'p1',
          'unit': 'Carton',
          'quantity': 2.0,
          'stockQuantity': 24.0,
          'stockUnit': 'Piece',
          'conversion': conversion,
          'totalMinor': 12000
        }
      ],
    };
    final warehouse = InventoryMigration.warehouse({
      'version': 12,
      'materials': [],
      'purchases': [purchase],
    });
    receive(shop,
        quantity: 24,
        sourceKind: 'supplier_purchase',
        sourceId: 'purchase1',
        supplierId: 'supplier1',
        costMinor: 12000,
        currency: 'USD');
    StockSchema.pair(warehouse, shop);
    final changed = copy(warehouse);
    changed['purchases'][0]['currency'] = 'SYP';
    expect(() => StockSchema.pair(changed, shop), throwsFormatException);
    final returned = copy(purchase);
    returned['id'] = 'return-purchase1';
    returned['type'] = 'purchaseReturn';
    returned['reversalOf'] = 'purchase1';
    warehouse['purchases'].add(returned);
    FinishedStock.record(shop,
        productId: 'p1',
        sourceId: 'return-purchase1',
        kind: 'purchaseReturn',
        allocations: {'l1': 24.0},
        date: date,
        actor: actor,
        requestId: 'purchase-return',
        direction: -1);
    shop['products'][0]['quantity'] = 0.0;
    shop['stockLots'][0]['status'] = 'returned';
    StockSchema.pair(warehouse, shop);
  });

  test('Manufacturing completion links actual consumption, output and cost',
      () {
    final warehouse = InventoryMigration.warehouse({
      'version': 12,
      'materials': [
        {
          'id': 'water',
          'name': 'Water',
          'quantity': 40.0,
          'unit': 'L',
          'price': 1.0
        }
      ],
      'batches': [
        {
          'id': 'batch1',
          'kind': 'production',
          'quantity': 20.0,
          'date': date,
          'materials': {'Water': 10.0},
          'materialIds': {'Water': 'water'}
        }
      ],
      'transfers': [
        {
          'id': 't1',
          'batchId': 'batch1',
          'productId': 'p1',
          'unit': 'Piece',
          'sourceUnit': 'Piece',
          'sourceQuantity': 20.0,
          'quantity': 20.0,
          'lot': 'LOT-1',
          'expiry': '',
          'date': date
        }
      ],
      'orders': [
        {
          'id': 'order1',
          'status': 'released',
          'batchId': 'batch1',
          'completion': {
            'productId': 'p1',
            'transferId': 't1',
            'lotId': 't1',
            'actualQuantity': 20.0,
            'unit': 'Piece',
            'actualIngredients': {'water': 10.0},
            'costMinor': 5000,
            'costCurrency': 'USD',
            'costStatus': 'confirmed',
            'requestId': 'completion1',
            'qualityNote': 'Passed',
            'varianceReason': '',
            'completedAt': date,
            'actor': actor
          }
        }
      ],
    });
    final shop = empty();
    receive(shop,
        sourceKind: 'manufacturing',
        sourceId: 'batch1',
        lotId: 't1',
        costMinor: 5000,
        currency: 'USD');
    StockSchema.pair(warehouse, shop);
    final changed = copy(warehouse);
    changed['orders'][0]['completion']['actualIngredients']['water'] = 11.0;
    expect(() => StockSchema.pair(changed, shop), throwsFormatException);
    changed['orders'][0]['completion']['actualIngredients']['water'] = 10.0;
    changed['orders'][0]['completion']['costMinor'] = 4999;
    expect(() => StockSchema.pair(changed, shop), throwsFormatException);
  });
}
