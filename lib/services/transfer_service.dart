import 'access_control.dart';
import 'accounting.dart';
import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/stock_transfer.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import 'inventory_coordinator.dart';
import 'money.dart';
import 'record_id.dart';
import 'state_schema.dart';
import 'stock_validation.dart';

class TransferService {
  static Future<void> recover() async {
    final journal = await Hive.openBox<String>('transfer_journal_v1');
    final value = journal.get('pending');
    if (value == null) {
      InventoryCoordinator.busy = false;
      return;
    }
    InventoryCoordinator.busy = true;
    final payload = StateSchema.object(jsonDecode(value));
    StateSchema.pair(StateSchema.object(payload['warehouse']),
        StateSchema.object(payload['shop']));
    for (final key in ['warehouse', 'shop']) {
      final box = await Hive.openBox<String>('${key}_state_v1');
      await box.put('state', jsonEncode(payload[key]));
      await box.flush();
    }
    await journal.delete('pending');
    await journal.flush();
    InventoryCoordinator.busy = false;
  }

  static Future<void> retry(
      WarehouseProvider warehouse, ShopProvider shop) async {
    await recover();
    InventoryCoordinator.busy = true;
    try {
      await warehouse.reloadState();
      await shop.reloadState();
    } finally {
      InventoryCoordinator.busy = false;
    }
  }

  static Future<void> post(WarehouseProvider warehouse, ShopProvider shop,
      {required String batchId,
      required double sourceQuantity,
      required String sourceUnit,
      required String productName,
      required double quantity,
      required String unit,
      required int unitPriceMinor,
      required String currency,
      required String requestId}) async {
    AccessControl.require('warehouse');
    InventoryCoordinator.check();
    Accounting.checkPeriod(warehouse.closedThrough);
    Money.total(sourceQuantity, 0);
    Money.total(quantity, unitPriceMinor);
    final name = StockValidation.name(productName);
    final source = StockValidation.name(sourceUnit),
        destination = StockValidation.name(unit);
    if (!Money.currencies.contains(currency) || requestId.trim().isEmpty) {
      throw ArgumentError('Currency and request are required.');
    }
    final prior = warehouse.transfers.where((t) => t.requestId == requestId);
    if (prior.isNotEmpty) {
      final p = prior.single;
      if (p.batchId != batchId ||
          p.sourceQuantity != sourceQuantity ||
          p.sourceUnit != source ||
          p.productName != name ||
          p.quantity != quantity ||
          p.unit != destination ||
          p.unitPriceMinor != unitPriceMinor ||
          p.currency != currency ||
          p.reversalOf != null) {
        throw StateError(
            'This transfer request already has different details.');
      }
      return;
    }
    if (warehouse.isSaving ||
        shop.isSaving ||
        !warehouse.isLoaded ||
        !shop.isLoaded) {
      throw StateError('Inventory is busy.');
    }
    if (warehouse.finishedAvailable(batchId) < sourceQuantity) {
      throw StateError('Insufficient finished quantity.');
    }
    final orders = warehouse.orders.where((o) => o['batchId'] == batchId);
    if (orders.isNotEmpty &&
        (orders.single['unit'] != source ||
            (orders.single['expiry'] != '' &&
                (orders.single['expiry'] as String)
                        .compareTo(Accounting.today()) <=
                    0))) {
      throw StateError(
          'Match the production unit and use an unexpired released lot.');
    }
    final wh = StateSchema.object(jsonDecode(warehouse.exportState()));
    final sh = StateSchema.object(jsonDecode(shop.exportState()));
    final matching = (sh['products'] as List).where((p) => p['name'] == name);
    final Map<String, dynamic> product;
    if (matching.isEmpty) {
      product = {
        'id': RecordId.create(),
        'name': name,
        'quantity': 0.0,
        'unit': destination,
        'price': unitPriceMinor / 100
      };
      (sh['products'] as List).add(product);
    } else {
      product = StateSchema.object(matching.single);
      if (product['unit'] != destination) {
        throw ArgumentError('Use the existing product unit.');
      }
      final index =
          (sh['products'] as List).indexWhere((p) => p['id'] == product['id']);
      sh['products'][index] = product;
    }
    product['quantity'] = (product['quantity'] as num).toDouble() + quantity;
    product['price'] = unitPriceMinor / 100;
    final transfer = StockTransfer(
        id: RecordId.create(),
        number:
            'TRF-${(warehouse.transfers.length + 1).toString().padLeft(6, '0')}',
        batchId: batchId,
        lot: orders.isNotEmpty
            ? orders.single['lot']
            : warehouse.productionDocuments
                .firstWhere((b) => b.id == batchId)
                .number,
        expiry: orders.isNotEmpty ? orders.single['expiry'] : '',
        sourceQuantity: sourceQuantity,
        sourceUnit: source,
        productId: product['id'],
        productName: name,
        quantity: quantity,
        unit: destination,
        date: DateTime.now(),
        requestId: requestId,
        unitPriceMinor: unitPriceMinor,
        currency: currency);
    await _commit(warehouse, shop, wh, sh, transfer);
  }

  static Future<void> reverse(
      WarehouseProvider warehouse, ShopProvider shop, String id, String reason,
      {required String requestId}) async {
    AccessControl.require('warehouse');
    InventoryCoordinator.check();
    Accounting.checkPeriod(warehouse.closedThrough);
    reason = StockValidation.name(reason);
    final prior = warehouse.transfers.where((t) => t.requestId == requestId);
    if (prior.isNotEmpty) {
      if (prior.single.reversalOf != id || prior.single.reason != reason) {
        throw StateError('Return request already has different details.');
      }
      return;
    }
    if (warehouse.isSaving || shop.isSaving) {
      throw StateError('Inventory is busy.');
    }
    final original = warehouse.transfers.firstWhere((t) => t.id == id);
    if (original.reversalOf != null ||
        warehouse.transfers.any((t) => t.reversalOf == id)) {
      throw StateError('Transfer already returned.');
    }
    final wh = StateSchema.object(jsonDecode(warehouse.exportState()));
    final sh = StateSchema.object(jsonDecode(shop.exportState()));
    final product = (sh['products'] as List)
        .firstWhere((p) => p['id'] == original.productId);
    if (shop.lotRemaining(original.id) < original.quantity ||
        product['quantity'] < original.quantity) {
      throw StateError('Insufficient shop stock to return this transfer.');
    }
    product['quantity'] -= original.quantity;
    final transfer = StockTransfer(
        id: RecordId.create(),
        number:
            'TRF-${(warehouse.transfers.length + 1).toString().padLeft(6, '0')}',
        batchId: original.batchId,
        lot: original.lot,
        expiry: original.expiry,
        sourceQuantity: original.sourceQuantity,
        sourceUnit: original.sourceUnit,
        productId: original.productId,
        productName: original.productName,
        quantity: original.quantity,
        unit: original.unit,
        date: DateTime.now(),
        requestId: requestId,
        unitPriceMinor: original.unitPriceMinor,
        currency: original.currency,
        reversalOf: id,
        reason: reason);
    await _commit(warehouse, shop, wh, sh, transfer);
  }

  static Future<void> _commit(
      WarehouseProvider warehouse,
      ShopProvider shop,
      Map<String, dynamic> wh,
      Map<String, dynamic> sh,
      StockTransfer transfer) async {
    wh['transfers'].add(transfer.toJson());
    sh['transfers'].add(transfer.toJson());
    await commitStates(warehouse, shop, wh, sh);
  }

  static Future<void> commitStates(
      WarehouseProvider warehouse,
      ShopProvider shop,
      Map<String, dynamic> wh,
      Map<String, dynamic> sh) async {
    InventoryCoordinator.check();
    if (warehouse.isSaving || shop.isSaving) {
      throw StateError('Inventory is busy.');
    }
    StateSchema.pair(wh, sh);
    InventoryCoordinator.busy = true;
    Box<String>? journal;
    try {
      journal = await Hive.openBox<String>('transfer_journal_v1');
      if (journal.containsKey('pending')) {
        throw StateError('Recover the pending transfer first.');
      }
      await journal.put('pending', jsonEncode({'warehouse': wh, 'shop': sh}));
      await journal.flush();
      await recover();
      // Hold the gate until both in-memory views match the committed states.
      InventoryCoordinator.busy = true;
      await warehouse.reloadState();
      await shop.reloadState();
      InventoryCoordinator.busy = false;
    } catch (_) {
      final pending = journal?.containsKey('pending') ?? false;
      if (!pending) {
        try {
          await warehouse.reloadState();
          await shop.reloadState();
        } catch (_) {}
      }
      InventoryCoordinator.busy = pending;
      rethrow;
    }
  }
}
