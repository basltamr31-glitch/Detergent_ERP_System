import 'dart:convert';

import 'package:detergent_factory/services/inventory_migration.dart';
import 'package:detergent_factory/services/state_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> product(String id, double quantity) => {
        'id': id,
        'name': 'Cleaner $id',
        'quantity': quantity,
        'unit': 'Piece',
        'price': 99.0,
      };
  Map<String, dynamic> transfer(String id, double quantity,
          {String productId = 'p1', String? reversalOf}) =>
      {
        'id': id,
        'batchId': 'batch-$id',
        'productId': productId,
        'quantity': quantity,
        'unit': 'Piece',
        'date': '2026-01-02T08:00:00.000Z',
        'expiry': '2027-01-01',
        'lot': 'LOT-$id',
        'unitPriceMinor': 9900,
        'currency': 'USD',
        'reversalOf': reversalOf,
        'actor': {'id': 'u1', 'name': 'Owner', 'role': 'owner'},
      };
  Map<String, dynamic> state({double quantity = 20}) => {
        'version': 12,
        'products': [product('p1', quantity)],
        'transfers': [transfer('t1', 20)],
        'sales': <Map<String, dynamic>>[],
        'counts': <Map<String, dynamic>>[],
        'journals': [
          {'id': 'journal-preserved'}
        ],
        'ledgerStartedAt': '2026-01-01T00:00:00.000Z',
        'closedThrough': '2025-12-31',
        'periodEvents': [
          {'id': 'period-preserved'}
        ],
      };

  test('Cutover retains received quantities and baselines the current balances',
      () {
    final original = state(quantity: 14);
    original['sales'] = [
      {
        'id': 's1',
        'lines': [
          {
            'itemId': 'p1',
            'quantity': 5.0,
            'lots': {'t1': 5.0}
          }
        ],
        'reversalOf': null,
      }
    ];
    original['counts'] = [
      {
        'itemId': 'p1',
        'before': 15.0,
        'after': 14.0,
        'lots': {'t1': 1.0}
      }
    ];
    final untouched = jsonEncode(original);
    final result = InventoryMigration.shop(original);
    expect(jsonEncode(original), untouched);
    expect(result['version'], 13);
    expect(result['stockLots'], hasLength(1));
    final lot = (result['stockLots'] as List).single as Map;
    expect(lot['id'], 't1');
    expect(lot['sourceId'], 'batch-t1');
    expect(lot['sourceKind'], 'manufacturing');
    expect(lot['quantity'], 20);
    expect(lot['expiry'], '2027-01-01');
    expect(lot['actor'], original['transfers'][0]['actor']);
    expect(result['lotBaseline'], {'t1': 14.0});
    expect(result['stockBaseline'], {'p1': 14.0});
    expect(result['stockMovements'], isEmpty);
    for (final key in [
      'sales',
      'counts',
      'transfers',
      'journals',
      'periodEvents'
    ]) {
      expect(result[key], original[key]);
    }
    expect(result['closedThrough'], original['closedThrough']);
  });

  test('Untraced residual becomes unknown opening stock without invented cost',
      () {
    final original = state(quantity: 23);
    original['sales'] = [
      {
        'id': 's1',
        'lines': [
          {
            'itemId': 'p1',
            'quantity': 8.0,
            'lots': {'t1': 3.0}
          }
        ],
      }
    ];
    final result = InventoryMigration.shop(original);
    final lots = result['stockLots'] as List;
    expect(lots, hasLength(2));
    expect(result['lotBaseline'], {'t1': 17.0, 'legacy:p1': 6.0});
    final opening = lots.last as Map;
    expect(opening['sourceKind'], 'legacy_opening');
    expect(opening['receivedAt'], original['ledgerStartedAt']);
    expect(opening['supplierId'], isNull);
    for (final lot in lots.cast<Map>()) {
      expect(lot['costStatus'], 'unknown');
      expect(lot['costMinor'], isNull);
      expect(lot['currency'], isNull);
    }
  });

  test('Returned transfers and reversed sales keep immutable historical links',
      () {
    final original = state(quantity: 7);
    original['transfers'].add(transfer('return-t1', 20, reversalOf: 't1'));
    original['sales'] = [
      {
        'id': 's1',
        'lines': [
          {
            'itemId': 'p1',
            'quantity': 5.0,
            'lots': {'t1': 5.0}
          }
        ],
        'reversalOf': null,
      },
      {
        'id': 'return-s1',
        'lines': [
          {
            'itemId': 'p1',
            'quantity': 5.0,
            'lots': {'t1': 5.0}
          }
        ],
        'reversalOf': 's1',
      }
    ];
    final result = InventoryMigration.shop(original);
    expect((result['stockLots'] as List).single['id'], 'legacy:p1');
    expect(result['lotBaseline'], {'legacy:p1': 7.0});
    expect(result['sales'], original['sales']);
    expect(result['transfers'], original['transfers']);
  });

  test('Consumed lots remain identifiable with zero remaining baseline', () {
    final original = state(quantity: 0);
    original['sales'] = [
      {
        'id': 's1',
        'lines': [
          {
            'itemId': 'p1',
            'quantity': 20.0,
            'lots': {'t1': 20.0}
          }
        ]
      }
    ];
    final result = InventoryMigration.shop(original);
    expect((result['stockLots'] as List).single['quantity'], 20.0);
    expect(result['lotBaseline'], {'t1': 0.0});
    expect(result['stockBaseline'], {'p1': 0.0});
  });

  test('Small legacy openings are preserved rather than discarded as tolerance',
      () {
    final original = state(quantity: 0.00000001);
    original['transfers'] = <Map<String, dynamic>>[];
    final result = InventoryMigration.shop(original);
    expect(result['stockBaseline'], {'p1': 0.00000001});
    expect(result['lotBaseline'], {'legacy:p1': 0.00000001});
    expect(result['stockLots'][0]['quantity'], 0.00000001);
  });

  test('Overallocations and lots exceeding balance require reconciliation', () {
    final insufficientBalance = state(quantity: 19);
    expect(() => InventoryMigration.shop(insufficientBalance),
        throwsFormatException);
    final excessiveUsage = state(quantity: 0);
    excessiveUsage['counts'] = [
      {
        'itemId': 'p1',
        'lots': {'t1': 21.0}
      }
    ];
    expect(
        () => InventoryMigration.shop(excessiveUsage), throwsFormatException);
    final usedReturn = state();
    usedReturn['transfers'].add(transfer('return-t1', 20, reversalOf: 't1'));
    usedReturn['counts'] = [
      {
        'itemId': 'p1',
        'lots': {'t1': 1.0}
      }
    ];
    expect(() => InventoryMigration.shop(usedReturn), throwsFormatException);
  });

  test('Upgrade is deterministic, idempotent and returns independent snapshots',
      () {
    final original = state();
    original['products'][0]['sku'] = 'KNOWN-SKU';
    original['products'][0]['unitConversions'] = [
      {'id': 'existing-conversion'}
    ];
    final first = InventoryMigration.shop(original);
    final second = InventoryMigration.shop(original);
    expect(second, first);
    expect(InventoryMigration.shop(first), first);
    expect(first['products'][0]['sku'], 'KNOWN-SKU');
    expect(first['products'][0]['unitConversions'],
        original['products'][0]['unitConversions']);
    expect(
        first['migration']['sourceSha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    final reopened = InventoryMigration.shop(first);
    reopened['products'][0]['quantity'] = 999;
    expect(first['products'][0]['quantity'], 20);
    expect(original['products'][0]['quantity'], 20);
  });

  test('Old snapshots and ID-less schema 1 get stable additive master identity',
      () {
    final original = <String, dynamic>{
      'version': 1,
      'products': [
        {'name': 'Old product', 'quantity': 4.5, 'unit': '', 'price': 0.0}
      ]
    };
    final first = InventoryMigration.shop(original);
    final second = InventoryMigration.shop(original);
    final id = first['products'][0]['id'] as String;
    expect(first, second);
    expect(original['products'][0].containsKey('id'), isFalse);
    expect(first['products'][0]['sku'], 'SKU-$id');
    expect(first['stockBaseline'], {id: 4.5});
    expect(first['lotBaseline'], {'legacy:$id': 4.5});
    expect(first['stockLots'][0]['costMinor'], isNull);
    expect(first['stockLots'][0]['receivedAt'], '1970-01-01T00:00:00.000Z');
  });

  test(
      'Raw upgrade preserves quantities and history without inventing raw lots',
      () {
    final original = <String, dynamic>{
      'version': 12,
      'materials': [
        {
          'id': 'water',
          'name': 'Water',
          'quantity': 123.456,
          'unit': 'L',
          'price': 2.0,
          'priceCurrency': 'SYP',
        }
      ],
      'transactions': [
        {'id': 'movement-preserved'}
      ],
      'batches': [
        {'id': 'batch-preserved'}
      ],
    };
    final result = InventoryMigration.warehouse(original);
    expect(result['version'], 13);
    expect(result['materials'][0]['quantity'], 123.456);
    expect(result['materials'][0]['priceCurrency'], 'SYP');
    expect(result['materials'][0]['sku'], 'SKU-water');
    expect(result['materials'][0]['unitConversions'], isEmpty);
    expect(result['transactions'], original['transactions']);
    expect(result['batches'], original['batches']);
    expect(result.containsKey('stockLots'), isFalse);
    expect(InventoryMigration.warehouse(result), result);
  });

  test('Older loader-compatible shapes upgrade into fully valid paired states',
      () {
    for (var previous = 1; previous <= 11; previous++) {
      final original = <String, dynamic>{
        'version': previous,
        'materials': [
          {
            'id': 'water',
            'name': 'Water',
            'quantity': 10.0,
            'unit': 'kg',
            'price': 1.0
          }
        ],
        'transactions': <Map<String, dynamic>>[],
        'batches': [
          {
            'id': 'batch',
            'name': 'Cleaner',
            'quantity': 2.0,
            'date': '2026-01-01T00:00:00.000Z',
            'materials': {'Water': 2.0}
          }
        ],
      };
      final oldShop = <String, dynamic>{
        'version': previous,
        'products': [
          {
            'id': 'p1',
            'name': 'Cleaner',
            'quantity': 3.0,
            'unit': 'Piece',
            'price': 5.0
          }
        ],
      };
      final raw = InventoryMigration.warehouse(original);
      final finished = InventoryMigration.shop(oldShop);
      StateSchema.pair(raw, finished);
      expect(raw['batches'][0]['id'], 'batch');
      expect(raw['batches'][0]['number'], 'PRD-000001');
      expect(raw['batches'][0]['kind'], 'production');
      expect(raw['batches'][0]['requestId'], 'batch');
      expect(raw['batches'][0]['materialIds'], isEmpty);
      expect(raw['batches'][0]['actor']['role'], 'legacy');
      expect(raw['materials'][0]['quantity'], 10.0);
      expect(finished['products'][0]['quantity'], 3.0);
      expect(raw['journals'], isEmpty);
    }
  });
}
