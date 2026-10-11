import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/models/material.dart' as model;
import 'package:detergent_factory/models/material_transaction.dart';
import 'package:detergent_factory/models/manufactured_product.dart';
import 'package:detergent_factory/models/product.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('erp_inventory_test_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(model.MaterialAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MaterialTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ManufacturedProductAdapter());
    }
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('Legacy warehouse migrates once and committed batch survives restart',
      () async {
    final legacy = await Hive.openBox<model.Material>('warehouse_materials');
    await legacy.put(
        'Water', model.Material(name: 'Water', quantity: 100, unit: 'kg'));
    final warehouse = WarehouseProvider();
    await warehouse.ready;
    expect(warehouse.loadError, isNull);
    final materialId = warehouse.materials.single.id;
    await warehouse.produceManufacturedProduct('Detergent', 20, {'Water': 20});
    final batchId = warehouse.manufacturedProducts.single.id;
    warehouse.dispose();
    await Hive.close();
    Hive.init(directory.path);
    final restarted = WarehouseProvider();
    await restarted.ready;
    expect(restarted.getStock('Water'), 80);
    expect(restarted.transactions.single.quantity, 20);
    expect(restarted.manufacturedProducts.single.name, 'Detergent');
    expect(restarted.materials.single.id, materialId);
    expect(restarted.manufacturedProducts.single.id, batchId);
    final retained = await Hive.openBox<model.Material>('warehouse_materials');
    expect(retained.get('Water')!.quantity, 100);
    restarted.dispose();
  });

  test(
      'Invalid and insufficient consumption leave inventory and history unchanged',
      () async {
    final warehouse = WarehouseProvider();
    await warehouse.ready;
    await warehouse.addMaterial('Water', 10, 'kg', 1);
    for (final quantity in [-1.0, 0.0, double.nan, double.infinity, 11.0]) {
      await expectLater(
          warehouse.produceManufacturedProduct('Batch', 1, {'Water': quantity}),
          throwsA(anyOf(isA<ArgumentError>(), isA<StateError>())));
      expect(warehouse.getStock('Water'), 10);
      expect(warehouse.transactions.length, 1);
      expect(warehouse.manufacturedProducts, isEmpty);
    }
    warehouse.dispose();
  });

  test('Unit changes and duplicate submissions cannot alter stock', () async {
    final shop = ShopProvider();
    await shop.ready;
    await shop.addProduct(' Soap ', 10, 'Piece', 2);
    await expectLater(
        shop.addProduct('Soap', 1, 'Box', 2), throwsArgumentError);
    final first = shop.sellProduct('Soap', 2);
    await expectLater(shop.sellProduct('Soap', 2), throwsStateError);
    await first;
    expect(shop.getStock('Soap'), 8);
    shop.dispose();
    final restarted = ShopProvider();
    await restarted.ready;
    expect(restarted.getStock('Soap'), 8);
    restarted.dispose();
  });

  test('Batch editing and reversal reconcile stock after defensive reads',
      () async {
    final warehouse = WarehouseProvider();
    await warehouse.ready;
    await warehouse.addMaterial('Water', 100, 'kg', 1);
    warehouse.materials.single.quantity = 999;
    expect(warehouse.getStock('Water'), 100);
    await warehouse.produceManufacturedProduct('Batch', 20, {'Water': 20});
    final staleRead = warehouse.manufacturedProducts.single;
    await warehouse.editManufacturedProduct(
        warehouse.manufacturedProducts.single,
        'Updated batch',
        30,
        {'Water': 30});
    expect(warehouse.getStock('Water'), 70);
    // The stale read still identifies the same batch after a rename; the
    // provider must restore the canonical 30 units, not its old 20 units.
    await expectLater(
        warehouse.deleteManufacturedProduct(staleRead), throwsStateError);
    expect(warehouse.productionDocuments.first.name, 'Batch');
    expect(warehouse.productionDocuments.length, 3);
    await warehouse
        .deleteManufacturedProduct(warehouse.manufacturedProducts.single);
    expect(warehouse.getStock('Water'), 100);
    expect(warehouse.manufacturedProducts, isEmpty);
    expect(warehouse.transactions.map((t) => t.type),
        ['IN', 'CONSUMPTION', 'RESTORE', 'CONSUMPTION', 'RESTORE']);
    warehouse.dispose();
  });

  test('Unsupported schema reports startup error and retry recovers', () async {
    final box = await Hive.openBox<String>('shop_state_v1');
    await box.put('state', '{"version":999}');
    final shop = ShopProvider();
    await shop.ready;
    expect(shop.isLoaded, isFalse);
    expect(shop.loadError, isNotNull);
    await expectLater(shop.sellProduct('Soap', 1), throwsStateError);
    await box.delete('state');
    await shop.initialize();
    expect(shop.isLoaded, isTrue);
    expect(shop.loadError, isNull);
    shop.dispose();
  });
}
