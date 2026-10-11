import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/services/backup_service.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/models/raw_material.dart';
import 'package:detergent_factory/models/packaging_item.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_backup_test_');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Map<String, dynamic> payload() => {
        'warehouse': {
          'version': 2,
          'materials': [
            {
              'id': 'water-id',
              'name': 'Water',
              'quantity': 10,
              'unit': 'kg',
              'price': 1
            }
          ],
          'transactions': [],
          'batches': []
        },
        'shop': {'version': 2, 'products': []},
        'production': {
          'version': 1,
          'name': 'Detergent',
          'rate': 100,
          'quantity': 20,
          'materials': []
        },
        'packaging': {
          'version': 1,
          'perCarton': 12,
          'cartonUSD': 1,
          'cartonSYP': 100,
          'labelUSD': 0.1,
          'labelSYP': 10,
          'items': []
        },
      };

  test('Backup file is verified and existing files are not overwritten',
      () async {
    final path = '${directory.path}/backup.json';
    await BackupService.write(path, payload());
    expect(await BackupService.read(path), payload());
    await expectLater(BackupService.write(path, payload()), throwsStateError);
    final envelope = jsonDecode(await File(path).readAsString());
    envelope['payload'] =
        (envelope['payload'] as String).replaceFirst('Water', 'Other');
    expect(() => BackupService.decode(jsonEncode(envelope)),
        throwsFormatException);
  });
  test('Invalid data is rejected before any restore writes', () async {
    final warehouse = await Hive.openBox<String>('warehouse_state_v1');
    await warehouse.put('state', 'original');
    final invalid = payload();
    invalid['warehouse']['materials'][0]['quantity'] = -1;
    await expectLater(BackupService.restore(invalid), throwsFormatException);
    expect(warehouse.get('state'), 'original');
    expect(Hive.isBoxOpen('restore_journal_v1'), isFalse);
  });
  test('Interrupted restore journal replays all stores and is cleared',
      () async {
    final journal = await Hive.openBox<String>('restore_journal_v1');
    await journal.put('pending', jsonEncode(payload()));
    // Simulate termination after only the warehouse write.
    final warehouse = await Hive.openBox<String>('warehouse_state_v1');
    await warehouse.put('state', jsonEncode(payload()['warehouse']));
    await Hive.close();
    Hive.init(directory.path);
    await BackupService.recover();
    expect(jsonDecode(Hive.box<String>('shop_state_v1').get('state')!),
        payload()['shop']);
    expect(jsonDecode(Hive.box<String>('costing_drafts_v1').get('production')!),
        payload()['production']);
    expect(Hive.box<String>('restore_journal_v1').get('pending'), isNull);
    await BackupService.recover(); // Repeated recovery is harmless.
  });
  test('Both costing drafts survive reopen with quantities and derived costs',
      () async {
    final box = await Hive.openBox<String>('costing_drafts_v1');
    final production = ProductionProvider(storage: box);
    final packaging = PackagingProvider(storage: box);
    production.setProductName('Soap');
    production.setExchangeRate(100);
    production.setProducedQuantity(20);
    production.addRawMaterial();
    production.updateRawMaterial(
        0,
        RawMaterial(
            name: 'Water',
            quantity: 20,
            priceUSD: 2,
            priceSYP: 200,
            isActive: true));
    packaging.setPackagesPerCarton(12);
    packaging.setLabelPriceUSD(0.1, 100);
    packaging.addPackagingItem();
    packaging.updatePackagingItem(
        0, PackagingItem(size: 500, price: 1, priceSYP: 100, hasCarton: true));
    await production.flushDraft();
    await packaging.flushDraft();
    production.dispose();
    packaging.dispose();
    await Hive.close();
    Hive.init(directory.path);
    final reopened = await Hive.openBox<String>('costing_drafts_v1');
    final p = ProductionProvider(storage: reopened);
    final k = PackagingProvider(storage: reopened);
    expect(p.productName, 'Soap');
    expect(p.totalCostUSD, 40);
    expect(p.activeIngredientsPercentage, 100);
    expect(k.packagesPerCarton, 12);
    expect(k.packagingItems.single.size, 500);
    expect(k.calculateUnitCostUSD(500, 1, p.totalCostUSDKG), 2.1);
    p.dispose();
    k.dispose();
  });
  test('Corrupt drafts report errors without replacing stored data', () async {
    final box = await Hive.openBox<String>('costing_drafts_v1');
    await box.put('production', '{"version":999}');
    final production = ProductionProvider(storage: box);
    expect(production.loadError, isNotNull);
    await expectLater(production.flushDraft(), throwsStateError);
    expect(box.get('production'), '{"version":999}');
    production.dispose();
  });

  test('Raw safety copy preserves corrupt stores for manual recovery',
      () async {
    final warehouse = await Hive.openBox<String>('warehouse_state_v1');
    final shop = await Hive.openBox<String>('shop_state_v1');
    final drafts = await Hive.openBox<String>('costing_drafts_v1');
    await warehouse.put('state', 'bad warehouse');
    await shop.put('state', 'bad shop');
    await drafts.put('production', 'bad draft');
    final path = '${directory.path}/recovery.json';
    await BackupService.preserveRaw(path);
    final copy = jsonDecode(await File(path).readAsString());
    expect(copy['warehouse'], 'bad warehouse');
    expect(copy['production'], 'bad draft');
    await BackupService.restore(payload());
    expect(jsonDecode(warehouse.get('state')!), payload()['warehouse']);
  });
}
