import 'dart:convert';
import 'dart:io';

import 'package:detergent_factory/services/inventory_migration.dart';
import 'package:detergent_factory/services/inventory_upgrade.dart';
import 'package:detergent_factory/services/state_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  const date = '2026-01-01T00:00:00.000Z';
  const actor = {'id': 'legacy', 'name': 'Legacy record', 'role': 'legacy'};

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_upgrade_test_');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Map<String, dynamic> common() => {
        'version': 12,
        'counts': <Map<String, dynamic>>[],
        'journals': <Map<String, dynamic>>[],
        'closedThrough': null,
        'periodEvents': <Map<String, dynamic>>[],
        'ledgerStartedAt': date,
        'transfers': <Map<String, dynamic>>[],
        'parties': <Map<String, dynamic>>[],
        'payments': <Map<String, dynamic>>[],
      };
  Map<String, dynamic> warehouse() => {
        ...common(),
        'recipes': <Map<String, dynamic>>[],
        'orders': <Map<String, dynamic>>[],
        'purchases': <Map<String, dynamic>>[],
        'materials': [
          {
            'id': 'water',
            'name': 'Water',
            'quantity': 10.0,
            'unit': 'kg',
            'price': 1.0,
            'priceCurrency': 'USD'
          }
        ],
        'transactions': <Map<String, dynamic>>[],
        'batches': <Map<String, dynamic>>[],
      };
  Map<String, dynamic> shop() => {
        ...common(),
        'sales': <Map<String, dynamic>>[],
        'products': [
          {
            'id': 'p1',
            'name': 'Cleaner',
            'quantity': 4.0,
            'unit': 'Piece',
            'price': 3.0
          }
        ],
      };
  Future<Map<String, String>> store(
      Map<String, dynamic> raw, Map<String, dynamic> finished) async {
    final originals = {
      'warehouse': jsonEncode(raw),
      'shop': jsonEncode(finished)
    };
    for (final entry in originals.entries) {
      final box = await Hive.openBox<String>('${entry.key}_state_v1');
      await box.put('state', entry.value);
      await box.flush();
    }
    return originals;
  }

  Map<String, String> current() => {
        for (final key in ['warehouse', 'shop'])
          key: Hive.box<String>('${key}_state_v1').get('state')!,
      };
  List<String> beforeKeys(Box<String> journal) => journal.keys
      .whereType<String>()
      .where((key) => key.startsWith('before:'))
      .toList();

  test('Valid paired upgrade preserves exact before-images and both balances',
      () async {
    final raw = warehouse();
    final finished = shop();
    StateSchema.pair(raw, finished);
    final originals = await store(raw, finished);
    await InventoryUpgrade.prepare();
    final results = current();
    final upgradedRaw =
        Map<String, dynamic>.from(jsonDecode(results['warehouse']!));
    final upgradedFinished =
        Map<String, dynamic>.from(jsonDecode(results['shop']!));
    expect(upgradedRaw['version'], 13);
    expect(upgradedFinished['version'], 13);
    expect(upgradedRaw['materials'][0]['id'], 'water');
    expect(upgradedRaw['materials'][0]['quantity'], 10.0);
    expect(upgradedFinished['products'][0]['id'], 'p1');
    expect(upgradedFinished['products'][0]['quantity'], 4.0);
    expect(upgradedFinished['stockLots'][0]['id'], 'legacy:p1');
    expect(upgradedFinished['stockLots'][0]['costMinor'], isNull);
    expect(upgradedFinished['stockBaseline'], {'p1': 4.0});
    StateSchema.pair(upgradedRaw, upgradedFinished);
    final journal = Hive.box<String>('inventory_upgrade_v13');
    expect(journal.containsKey('pending'), isFalse);
    final keys = beforeKeys(journal);
    expect(keys, hasLength(1));
    expect(jsonDecode(journal.get(keys.single)!), originals);
  });

  test('Repeated and concurrent prepare calls do not duplicate upgrade or lots',
      () async {
    await store(warehouse(), shop());
    await Future.wait([InventoryUpgrade.prepare(), InventoryUpgrade.prepare()]);
    final first = current();
    final journal = Hive.box<String>('inventory_upgrade_v13');
    final preserved = {
      for (final key in beforeKeys(journal)) key: journal.get(key)
    };
    await InventoryUpgrade.prepare();
    expect(current(), first);
    expect({for (final key in beforeKeys(journal)) key: journal.get(key)},
        preserved);
    expect(jsonDecode(current()['shop']!)['stockLots'], hasLength(1));
    expect(journal.containsKey('pending'), isFalse);
  });

  test('Unreconciled legacy lot stops before either original store is changed',
      () async {
    final raw = warehouse();
    final finished = shop();
    raw['batches'].add({
      'id': 'batch1',
      'name': 'Cleaner',
      'quantity': 20.0,
      'date': date,
      'materials': {'Water': 1.0},
      'materialIds': <String, String>{},
      'number': 'PRD-000001',
      'kind': 'production',
      'reason': '',
      'requestId': 'batch-request',
      'actor': actor,
    });
    final transfer = <String, dynamic>{
      'id': 'transfer1',
      'number': 'TRF-000001',
      'batchId': 'batch1',
      'sourceQuantity': 20.0,
      'sourceUnit': 'Piece',
      'productId': 'p1',
      'productName': 'Cleaner',
      'quantity': 20.0,
      'unit': 'Piece',
      'date': date,
      'requestId': 'transfer-request',
      'unitPriceMinor': 100,
      'currency': 'USD',
      'reversalOf': null,
      'reason': '',
      'lot': 'LOT-1',
      'expiry': '',
      'actor': actor,
    };
    raw['transfers'].add(transfer);
    finished['transfers'].add(transfer);
    finished['products'][0]['quantity'] = 19.0;
    StateSchema.pair(raw, finished); // Version 12 allowed unmatched balances.
    final originals = await store(raw, finished);
    await expectLater(
        InventoryUpgrade.prepare(),
        throwsA(isA<FormatException>().having((error) => error.message,
            'reconciliation reason', contains('reconcile'))));
    expect(current(), originals);
    final journal = Hive.box<String>('inventory_upgrade_v13');
    expect(journal.containsKey('pending'), isFalse);
    expect(beforeKeys(journal), isEmpty);
  });

  test('Pending upgrade replays both results after one store was written',
      () async {
    final raw = warehouse();
    final finished = shop();
    final originals = await store(raw, finished);
    final after = {
      'warehouse': InventoryMigration.warehouse(raw),
      'shop': InventoryMigration.shop(finished),
    };
    StateSchema.pair(after['warehouse']!, after['shop']!);
    final journal = await Hive.openBox<String>('inventory_upgrade_v13');
    await journal.put('before:interrupted-upgrade', jsonEncode(originals));
    await journal.put(
        'pending', jsonEncode({'before': originals, 'after': after}));
    await journal.flush();
    final rawBox = Hive.box<String>('warehouse_state_v1');
    await rawBox.put('state', jsonEncode(after['warehouse']));
    await rawBox.flush();
    await Hive.close();
    Hive.init(directory.path);
    await InventoryUpgrade.prepare();
    final expected = {
      for (final entry in after.entries) entry.key: jsonEncode(entry.value)
    };
    expect(current(), expected);
    final reopened = Hive.box<String>('inventory_upgrade_v13');
    expect(reopened.containsKey('pending'), isFalse);
    expect(jsonDecode(reopened.get('before:interrupted-upgrade')!), originals);
    await InventoryUpgrade.prepare();
    expect(current(), expected);
    expect(beforeKeys(reopened), ['before:interrupted-upgrade']);
  });

  test('Unsupported input schema leaves both original strings untouched',
      () async {
    final finished = shop()..['version'] = 999;
    final originals = await store(warehouse(), finished);
    await expectLater(InventoryUpgrade.prepare(), throwsFormatException);
    expect(current(), originals);
    final journal = Hive.box<String>('inventory_upgrade_v13');
    expect(journal.containsKey('pending'), isFalse);
    expect(beforeKeys(journal), isEmpty);
  });
}
