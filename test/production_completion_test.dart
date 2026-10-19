import 'dart:convert';
import 'dart:io';

import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/services/access_control.dart';
import 'package:detergent_factory/services/accounting.dart';
import 'package:detergent_factory/services/finance_service.dart';
import 'package:detergent_factory/services/inventory_coordinator.dart';
import 'package:detergent_factory/services/production_completion_service.dart';
import 'package:detergent_factory/services/state_schema.dart';
import 'package:detergent_factory/services/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late WarehouseProvider warehouse;
  late ShopProvider shop;

  setUp(() async {
    AccessControl.enabled = false;
    AccessControl.user = null;
    Accounting.clock = DateTime.now;
    InventoryCoordinator.busy = false;
    directory = await Directory.systemTemp.createTemp('erp_completion_');
    Hive.init(directory.path);
    warehouse = WarehouseProvider();
    shop = ShopProvider();
    await warehouse.ready;
    await shop.ready;
  });

  tearDown(() async {
    AccessControl.enabled = false;
    AccessControl.user = null;
    Accounting.clock = DateTime.now;
    InventoryCoordinator.busy = false;
    warehouse.dispose();
    shop.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<String> order({bool approve = true}) async {
    await warehouse.addMaterial('Water', 100, 'Kilogram', 10);
    await warehouse.addMaterial('Fragrance', 10, 'Kilogram', 30);
    final expiry = DateTime.now()
        .toUtc()
        .add(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    await warehouse.createOrder(
      'Cleaner',
      24,
      'Piece',
      'COMPLETE-001',
      expiry,
      {'Water': 10, 'Fragrance': 1},
      requestId: 'planned-order',
    );
    final id = warehouse.orders.single['id'] as String;
    if (approve) {
      await warehouse.approveOrder(id, 'Reviewed final bottle recipe');
    }
    return id;
  }

  Map<String, double> ingredients({double water = 10}) => {
        warehouse.materials.firstWhere((m) => m.name == 'Water').id: water,
        warehouse.materials.firstWhere((m) => m.name == 'Fragrance').id: 1,
      };

  test(
      'Actual completion and finished receipt persist atomically and retry once',
      () async {
    final id = await order();
    await shop.addProduct('Cleaner bottle', 3, 'Piece', 8);
    final productId = shop.products.single.id;
    Future<void> complete(Map<String, double> actual) =>
        ProductionCompletionService.complete(
          warehouse,
          shop,
          orderId: id,
          actualIngredients: actual,
          actualQuantity: 23,
          outputUnit: 'Piece',
          qualityNote: 'Final bottle quality accepted',
          requestId: 'complete-order',
          finishedProductId: productId,
          varianceReason: 'Measured consumption and one rejected bottle',
          costMinor: 4600,
          costCurrency: 'USD',
          costStatus: 'confirmed',
          costReference: 'Reviewed batch cost sheet 001',
        );
    final actual = ingredients(water: 9);
    await complete(actual);
    // Equivalent maps supplied in a different order are the same request.
    await complete(Map.fromEntries(actual.entries.toList().reversed));
    expect(warehouse.getStock('Water'), 91);
    expect(warehouse.getStock('Fragrance'), 9);
    expect(shop.getStock('Cleaner bottle'), 26);
    expect(shop.products.single.unitPrice, 8);
    expect(warehouse.productionDocuments.length, 1);
    expect(warehouse.transfers.length, 1);
    expect(warehouse.finishedAvailable(warehouse.productionDocuments.single.id),
        0);
    final savedOrder = warehouse.orders.single;
    expect(savedOrder['quantity'], 24);
    expect(savedOrder['materials'], ingredients());
    expect(savedOrder['completion']['actualQuantity'], 23);
    expect(savedOrder['completion']['actualIngredients'], actual);
    expect(savedOrder['completion']['costMinor'], 4600);
    expect(warehouse.recipes.single['quantity'], 24);
    final state = jsonDecode(shop.exportState()) as Map<String, dynamic>;
    final lot = (state['stockLots'] as List).singleWhere(
        (l) => l['sourceId'] == warehouse.productionDocuments.single.id);
    expect(lot['id'], savedOrder['completion']['lotId']);
    expect(lot['sourceKind'], 'manufacturing');
    expect(lot['quantity'], 23);
    expect(lot['costMinor'], 4600);
    expect(lot['costStatus'], 'confirmed');
    expect(lot['currency'], 'USD');
    await warehouse.reloadState();
    await shop.reloadState();
    await complete(actual);
    expect(shop.getStock('Cleaner bottle'), 26);
    expect(warehouse.productionDocuments.length, 1);
    expect(warehouse.orders.single['completion']['costReference'],
        'Reviewed batch cost sheet 001');
    StateSchema.pair(
        jsonDecode(warehouse.exportState()), jsonDecode(shop.exportState()));
  });

  test('Validation never consumes raw stock or creates partial finished stock',
      () async {
    final id = await order(approve: false);
    final beforeDraft = warehouse.exportState();
    final emptyShop = shop.exportState();
    await expectLater(
        ProductionCompletionService.complete(warehouse, shop,
            orderId: id,
            actualIngredients: ingredients(),
            actualQuantity: 24,
            outputUnit: 'Piece',
            qualityNote: 'Quality accepted',
            requestId: 'draft-complete',
            newProductName: 'Cleaner bottle',
            newSku: 'CLN-001'),
        throwsStateError);
    expect(warehouse.exportState(), beforeDraft);
    expect(shop.exportState(), emptyShop);
    await warehouse.approveOrder(id, 'Reviewed recipe');
    final approved = warehouse.exportState();
    for (final variant in ['shortage', 'unit', 'variance', 'cost']) {
      await expectLater(
          ProductionCompletionService.complete(
            warehouse,
            shop,
            orderId: id,
            actualIngredients:
                ingredients(water: variant == 'shortage' ? 101 : 10),
            actualQuantity: variant == 'variance' ? 23 : 24,
            outputUnit: variant == 'unit' ? 'Carton' : 'Piece',
            qualityNote: 'Quality accepted',
            requestId: 'invalid-$variant',
            newProductName: 'Cleaner bottle',
            newSku: 'CLN-001',
            varianceReason: variant == 'shortage' ? 'Extra measured water' : '',
            costMinor: variant == 'cost' ? 4800 : null,
            costCurrency: variant == 'cost' ? 'USD' : null,
            costStatus: variant == 'cost' ? 'confirmed' : 'unknown',
          ),
          variant == 'shortage' ? throwsStateError : throwsArgumentError);
      expect(warehouse.exportState(), approved);
      expect(shop.exportState(), emptyShop);
    }
  });

  test('Unknown cost stays unknown and completion creates an explicit new SKU',
      () async {
    final id = await order();
    await ProductionCompletionService.complete(warehouse, shop,
        orderId: id,
        actualIngredients: ingredients(),
        actualQuantity: 24,
        outputUnit: 'Piece',
        qualityNote: 'Quality accepted',
        requestId: 'new-sku-complete',
        newProductName: 'Cleaner bottle',
        newSku: 'CLN-001');
    final state = jsonDecode(shop.exportState()) as Map<String, dynamic>;
    expect((state['products'] as List).single['sku'], 'CLN-001');
    final lot = (state['stockLots'] as List).single;
    expect(lot['costStatus'], 'unknown');
    expect(lot['costMinor'], isNull);
    expect(lot['currency'], isNull);
    expect(warehouse.journals, isEmpty);
    expect(shop.journals, isEmpty);
    expect(shop.getStock('Cleaner bottle'), 24);
  });

  test('Changed retry and legacy released orders cannot add a second receipt',
      () async {
    final id = await order();
    await ProductionCompletionService.complete(warehouse, shop,
        orderId: id,
        actualIngredients: ingredients(),
        actualQuantity: 24,
        outputUnit: 'Piece',
        qualityNote: 'Quality accepted',
        requestId: 'complete-once',
        newProductName: 'Cleaner bottle',
        newSku: 'CLN-001');
    final beforeWh = warehouse.exportState();
    final beforeShop = shop.exportState();
    await expectLater(
        ProductionCompletionService.complete(warehouse, shop,
            orderId: id,
            actualIngredients: ingredients(),
            actualQuantity: 23,
            outputUnit: 'Piece',
            qualityNote: 'Quality accepted',
            requestId: 'complete-once',
            newProductName: 'Cleaner bottle',
            newSku: 'CLN-001',
            varianceReason: 'Changed result'),
        throwsStateError);
    expect(warehouse.exportState(), beforeWh);
    expect(shop.exportState(), beforeShop);
    await warehouse.createOrder(
        'Other cleaner', 2, 'Piece', 'LEGACY-002', '', {'Water': 1},
        requestId: 'legacy-order');
    final legacy = warehouse.orders.last['id'] as String;
    await warehouse.approveOrder(legacy, 'Reviewed recipe');
    await warehouse.releaseOrder(legacy, 'Existing release path');
    await expectLater(
        ProductionCompletionService.complete(warehouse, shop,
            orderId: legacy,
            actualIngredients: {
              warehouse.materials.firstWhere((m) => m.name == 'Water').id: 1
            },
            actualQuantity: 2,
            outputUnit: 'Piece',
            qualityNote: 'Quality accepted',
            requestId: 'legacy-complete',
            finishedProductId: shop.products.single.id),
        throwsStateError);
    expect(shop.getStock('Cleaner bottle'), 24);
  });

  test(
      'Permissions, accounting lock and lot expiry apply to combined completion',
      () async {
    final id = await order();
    Future<void> complete() => ProductionCompletionService.complete(
          warehouse,
          shop,
          orderId: id,
          actualIngredients: ingredients(),
          actualQuantity: 24,
          outputUnit: 'Piece',
          qualityNote: 'Quality accepted',
          requestId: 'protected-completion',
          newProductName: 'Cleaner bottle',
          newSku: 'CLN-001',
        );
    AccessControl.enabled = true;
    AccessControl.user = {'id': 'viewer', 'name': 'Viewer', 'role': 'viewer'};
    await expectLater(complete(), throwsStateError);
    AccessControl.user = {'id': 'owner', 'name': 'Owner', 'role': 'owner'};
    await FinanceService.setPeriod(
        warehouse, shop, Accounting.today(), 'Reviewed period');
    await expectLater(complete(), throwsStateError);
    await FinanceService.setPeriod(warehouse, shop, null, 'Reviewed reopening');
    Accounting.clock =
        () => DateTime.now().toUtc().add(const Duration(days: 8));
    await expectLater(complete(), throwsStateError);
    Accounting.clock = DateTime.now;
    AccessControl.user = {
      'id': 'warehouse',
      'name': 'Warehouse',
      'role': 'warehouse'
    };
    await complete();
    expect(shop.getStock('Cleaner bottle'), 24);
    expect(warehouse.orders.single['completion']['actor']['id'], 'warehouse');
  });

  test('Interrupted combined payload restores raw consumption and finished lot',
      () async {
    final id = await order();
    final beforeWh = warehouse.exportState();
    final beforeShop = shop.exportState();
    await ProductionCompletionService.complete(warehouse, shop,
        orderId: id,
        actualIngredients: ingredients(),
        actualQuantity: 24,
        outputUnit: 'Piece',
        qualityNote: 'Quality accepted',
        requestId: 'recover-completion',
        newProductName: 'Cleaner bottle',
        newSku: 'CLN-001');
    final payload = jsonEncode({
      'warehouse': jsonDecode(warehouse.exportState()),
      'shop': jsonDecode(shop.exportState()),
    });
    final journal = await Hive.openBox<String>('transfer_journal_v1');
    await journal.put('pending', payload);
    await journal.flush();
    await Hive.box<String>('warehouse_state_v1').put('state', beforeWh);
    await Hive.box<String>('shop_state_v1').put('state', beforeShop);
    InventoryCoordinator.busy = true;
    await expectLater(
        warehouse.addMaterial('Water', 1, 'Kilogram', 10), throwsStateError);
    await TransferService.retry(warehouse, shop);
    expect(warehouse.getStock('Water'), 90);
    expect(shop.getStock('Cleaner bottle'), 24);
    expect(warehouse.orders.single['status'], 'released');
    expect(journal.containsKey('pending'), isFalse);
    await ProductionCompletionService.complete(warehouse, shop,
        orderId: id,
        actualIngredients: ingredients(),
        actualQuantity: 24,
        outputUnit: 'Piece',
        qualityNote: 'Quality accepted',
        requestId: 'recover-completion',
        newProductName: 'Cleaner bottle',
        newSku: 'CLN-001');
    expect(warehouse.getStock('Water'), 90);
    expect(shop.getStock('Cleaner bottle'), 24);
  });
}
