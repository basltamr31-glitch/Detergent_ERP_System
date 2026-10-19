import 'dart:convert';

import '../models/stock_transfer.dart';
import '../providers/shop_provider.dart';
import '../providers/warehouse_provider.dart';
import 'access_control.dart';
import 'accounting.dart';
import 'finished_stock.dart';
import 'inventory_coordinator.dart';
import 'money.dart';
import 'record_id.dart';
import 'state_schema.dart';
import 'stock_validation.dart';
import 'transfer_service.dart';

/// Completes an approved, sale-ready order in one recoverable stock posting.
/// Planned recipe values remain immutable; actual values live in completion.
class ProductionCompletionService {
  static Future<void> complete(
    WarehouseProvider warehouse,
    ShopProvider shop, {
    required String orderId,
    required Map<String, double> actualIngredients,
    required double actualQuantity,
    required String outputUnit,
    required String qualityNote,
    required String requestId,
    String? finishedProductId,
    String? newProductName,
    String? newSku,
    String varianceReason = '',
    int? costMinor,
    String? costCurrency,
    String costStatus = 'unknown',
    String costReference = '',
    String referenceCurrency = 'USD',
  }) async {
    AccessControl.require('warehouse');
    InventoryCoordinator.check();
    Accounting.checkPeriod(warehouse.closedThrough);
    outputUnit = StockValidation.name(outputUnit);
    qualityNote = StockValidation.name(qualityNote);
    requestId = StockValidation.name(requestId);
    varianceReason = varianceReason.trim();
    costReference = costReference.trim();
    Money.total(actualQuantity, 0);
    if (!Money.currencies.contains(referenceCurrency)) {
      throw ArgumentError('Select a reference-price currency.');
    }
    if (!['unknown', 'estimated', 'confirmed'].contains(costStatus)) {
      throw ArgumentError('Select a valid cost status.');
    }
    if (costStatus == 'unknown') {
      if (costMinor != null || costCurrency != null) {
        throw ArgumentError('Unknown cost must not have an invented amount.');
      }
    } else if (costMinor == null ||
        costMinor < 0 ||
        costMinor > Money.maxMinor ||
        !Money.currencies.contains(costCurrency)) {
      throw ArgumentError('Enter the total batch cost and its currency.');
    }
    if (costStatus == 'confirmed' && costReference.isEmpty) {
      throw ArgumentError(
          'A confirmed cost needs a reviewed source reference.');
    }
    if (actualIngredients.isEmpty) {
      throw ArgumentError('Record the actual consumed materials.');
    }
    final materialIds = actualIngredients.keys.toList()..sort();
    final actual = <String, double>{};
    for (final id in materialIds) {
      StockValidation.name(id);
      Money.total(actualIngredients[id]!, 0);
      actual[id] = actualIngredients[id]!;
    }
    final fingerprint = jsonEncode({
      'orderId': orderId,
      'actualIngredients': actual,
      'actualQuantity': actualQuantity,
      'outputUnit': outputUnit,
      'qualityNote': qualityNote,
      'finishedProductId': finishedProductId,
      'newProductName': newProductName?.trim(),
      'newSku': newSku?.trim(),
      'varianceReason': varianceReason,
      'costMinor': costMinor,
      'costCurrency': costCurrency,
      'costStatus': costStatus,
      'costReference': costReference,
      'referenceCurrency': referenceCurrency,
    });
    final wh = StateSchema.object(jsonDecode(warehouse.exportState()));
    final sh = StateSchema.object(jsonDecode(shop.exportState()));
    final order = (wh['orders'] as List).firstWhere(
      (o) => o['id'] == orderId,
      orElse: () => throw StateError('Production order not found.'),
    ) as Map<String, dynamic>;
    final previous = order['completion'];
    if (previous != null) {
      if (previous['requestId'] != requestId ||
          previous['inputFingerprint'] != fingerprint) {
        throw StateError('Production was completed with different details.');
      }
      return;
    }
    if ((wh['orders'] as List)
        .any((o) => o['completion']?['requestId'] == requestId)) {
      throw StateError('This completion request belongs to another order.');
    }
    if (order['status'] != 'approved') {
      throw StateError('Complete an approved, unreleased production order.');
    }
    if (order['unit'] != outputUnit) {
      throw ArgumentError(
          'Use the approved output unit; record bulk packaging separately.');
    }
    if (order['expiry'] != '' &&
        (order['expiry'] as String).compareTo(Accounting.today()) <= 0) {
      throw StateError('The production lot has expired.');
    }
    final planned = Map<String, dynamic>.from(order['materials'] as Map);
    if (planned.length != actual.length ||
        actual.keys.any((id) => !planned.containsKey(id))) {
      throw ArgumentError(
          'Use the approved materials; approve a revised recipe for substitutions.');
    }
    final differs = order['quantity'] != actualQuantity ||
        actual.entries.any((e) => planned[e.key] != e.value);
    if (differs && varianceReason.isEmpty) {
      throw ArgumentError(
          'Explain differences from the approved production plan.');
    }

    final consumedByName = <String, double>{};
    final linksByName = <String, String>{};
    final materials = wh['materials'] as List;
    for (final entry in actual.entries) {
      final material = materials.firstWhere(
        (m) => m['id'] == entry.key,
        orElse: () => throw StateError('An approved raw material is missing.'),
      );
      if ((material['quantity'] as num).toDouble() < entry.value) {
        throw StateError('Insufficient stock for ${material['name']}.');
      }
      consumedByName[material['name'] as String] = entry.value;
      linksByName[material['name'] as String] = entry.key;
    }

    final products = sh['products'] as List;
    final selected = finishedProductId == null
        ? null
        : products.firstWhere(
            (p) => p['id'] == finishedProductId,
            orElse: () => throw StateError('Finished product not found.'),
          );
    if (selected == null &&
        products.any(
            (p) => p['name'] == (newProductName ?? order['name']).trim())) {
      throw ArgumentError(
          'Select the existing finished SKU instead of merging by name.');
    }
    final product = FinishedStock.ensureProduct(
      sh,
      productId: finishedProductId,
      name: selected == null
          ? StockValidation.name(newProductName ?? order['name'] as String)
          : selected['name'] as String,
      unit: outputUnit,
      sku: newSku,
    );
    final now = DateTime.now().toUtc();
    final date = now.toIso8601String();
    final actor = AccessControl.actor;
    final batchId = RecordId.create();
    final batch = {
      'id': batchId,
      'actor': actor,
      'name': order['name'],
      'quantity': actualQuantity,
      'date': date,
      'materials': consumedByName,
      'materialIds': linksByName,
      'number':
          'PRD-${((wh['batches'] as List).length + 1).toString().padLeft(6, '0')}',
      'kind': 'production',
      'reason': varianceReason,
      'reversalOf': null,
      'replacesId': null,
      'requestId': orderId,
    };
    for (final entry in actual.entries) {
      final material = materials.firstWhere((m) => m['id'] == entry.key);
      material['quantity'] = double.parse(
          ((material['quantity'] as num).toDouble() - entry.value)
              .toStringAsFixed(6));
      (wh['transactions'] as List).add({
        'id': RecordId.create(),
        'documentId': batchId,
        'materialId': entry.key,
        'name': material['name'],
        'quantity': entry.value,
        'type': 'CONSUMPTION',
        'date': date,
      });
    }
    (wh['batches'] as List).add(batch);
    final transfer = StockTransfer(
      id: RecordId.create(),
      number:
          'TRF-${((wh['transfers'] as List).length + 1).toString().padLeft(6, '0')}',
      batchId: batchId,
      sourceQuantity: actualQuantity,
      sourceUnit: outputUnit,
      productId: product['id'] as String,
      productName: product['name'] as String,
      quantity: actualQuantity,
      unit: outputUnit,
      date: now,
      requestId: '$requestId:finished',
      unitPriceMinor: Money.parse((product['price'] as num).toStringAsFixed(2)),
      currency: referenceCurrency,
      lot: order['lot'] as String,
      expiry: order['expiry'] as String,
      actor: actor,
    );
    (wh['transfers'] as List).add(transfer.toJson());
    (sh['transfers'] as List).add(transfer.toJson());
    FinishedStock.receive(
      sh,
      lotId: transfer.id,
      productId: product['id'] as String,
      sourceKind: 'manufacturing',
      sourceId: batchId,
      quantity: actualQuantity,
      unit: outputUnit,
      date: date,
      lot: order['lot'] as String,
      expiry: order['expiry'] as String,
      costMinor: costMinor,
      currency: costCurrency,
      costStatus: costStatus,
      costReference: costReference,
      actor: actor,
      requestId: '$requestId:finished',
    );
    order['completion'] = {
      'requestId': requestId,
      'actualQuantity': actualQuantity,
      'unit': outputUnit,
      'actualIngredients': actual,
      'qualityNote': qualityNote,
      'varianceReason': varianceReason,
      'productId': product['id'],
      'transferId': transfer.id,
      'lotId': transfer.id,
      'costMinor': costMinor,
      'costCurrency': costCurrency,
      'costStatus': costStatus,
      'costReference': costReference,
      'inputFingerprint': fingerprint,
      'completedAt': date,
      'actor': actor,
    };
    order['batchId'] = batchId;
    order['status'] = 'released';
    (order['events'] as List).add({
      'kind': 'released',
      'date': date,
      'actor': actor,
      'reason': qualityNote,
    });
    await TransferService.commitStates(warehouse, shop, wh, sh);
  }
}
