import 'dart:convert';
import '../models/trade_line.dart';
import '../models/trade_document.dart';
import '../models/journal_entry.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import 'access_control.dart';
import 'accounting.dart';
import 'finished_stock.dart';
import 'inventory_coordinator.dart';
import 'inventory_units.dart';
import 'money.dart';
import 'record_id.dart';
import 'transfer_service.dart';

class TradingPurchaseService {
  static Future<void> receive(
      WarehouseProvider warehouse, ShopProvider shop, List<TradeInput> items,
      {required String supplier,
      required String currency,
      int paidMinor = 0,
      String reference = '',
      String? partyId,
      required String requestId,
      String expiry = ''}) async {
    AccessControl.require('warehouse');
    InventoryCoordinator.check();
    Accounting.checkPeriod(warehouse.closedThrough);
    if (items.isEmpty ||
        requestId.trim().isEmpty ||
        supplier.trim().isEmpty ||
        !Money.currencies.contains(currency)) {
      throw ArgumentError('Select supplier, currency and products.');
    }
    if (expiry.isNotEmpty &&
        (DateTime.parse(expiry).toIso8601String().substring(0, 10) != expiry ||
            expiry.compareTo(Accounting.today()) <= 0)) {
      throw ArgumentError('Use a valid future expiry date.');
    }
    final prior = warehouse.purchases.where((d) => d.requestId == requestId);
    if (prior.isNotEmpty) {
      final d = prior.single;
      if (d.purchaseKind != 'trading' ||
          d.party != supplier.trim() ||
          d.partyId != partyId ||
          d.currency != currency ||
          d.paidMinor != paidMinor ||
          d.reference != reference.trim() ||
          d.lines.length != items.length) {
        throw StateError('Purchase request has different details.');
      }
      for (var i = 0; i < items.length; i++) {
        final input = items[i], line = d.lines[i];
        if (line.itemId != input.itemId ||
            line.quantity != input.quantity ||
            line.unit != input.unit ||
            line.unitPriceMinor != input.unitPriceMinor) {
          throw StateError('Purchase request has different items.');
        }
      }
      final oldLots = shop.stockLots.where((l) => l['sourceId'] == d.id);
      if (oldLots.any((l) => l['expiry'] != expiry)) {
        throw StateError('Purchase request has different expiry.');
      }
      return;
    }
    if (partyId != null &&
        !warehouse.parties.any(
            (p) => p.id == partyId && p.active && p.name == supplier.trim())) {
      throw ArgumentError('Select an active supplier.');
    }
    final wh = jsonDecode(warehouse.exportState()) as Map<String, dynamic>;
    final sh = jsonDecode(shop.exportState()) as Map<String, dynamic>;
    final lines = <TradeLine>[], ids = <String>{};
    for (final input in items) {
      if (input.itemId == null || !ids.add(input.itemId!)) {
        throw ArgumentError('Select unique product IDs.');
      }
      final product =
          (sh['products'] as List).firstWhere((p) => p['id'] == input.itemId);
      final unit = input.unit.isEmpty ? product['unit'] as String : input.unit;
      final conversion = InventoryUnits.snapshot(
          input.quantity,
          unit,
          product['unit'],
          (product['unitConversions'] as List)
              .map((c) => Map<String, dynamic>.from(c))
              .toList());
      lines.add(TradeLine(
          itemId: product['id'],
          itemName: product['name'],
          unit: unit,
          quantity: input.quantity,
          unitPriceMinor: input.unitPriceMinor,
          stockQuantity: conversion['baseQuantity'],
          stockUnit: product['unit'],
          conversion: conversion));
    }
    final total = lines.fold(0, (sum, l) => sum + l.totalMinor);
    if (total > Money.maxMinor || paidMinor < 0 || paidMinor > total) {
      throw ArgumentError('Invalid total or payment.');
    }
    final first = lines.first, date = DateTime.now(), id = RecordId.create();
    final doc = TradeDocument(
        id: id,
        number:
            'PUR-${((wh['purchases'] as List).length + 1).toString().padLeft(6, '0')}',
        type: 'purchase',
        purchaseKind: 'trading',
        stockTracked: true,
        date: date,
        party: supplier.trim(),
        partyId: partyId,
        currency: currency,
        itemId: first.itemId,
        itemName: first.itemName,
        unit: first.unit,
        quantity: first.quantity,
        unitPriceMinor: first.unitPriceMinor,
        totalMinor: total,
        paidMinor: paidMinor,
        lines: lines,
        reference: reference.trim(),
        requestId: requestId);
    (wh['purchases'] as List).add(doc.toJson());
    (wh['journals'] as List).add(JournalEntry.trade(doc).toJson());
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      FinishedStock.receive(sh,
          lotId: '$id:$i',
          productId: line.itemId,
          sourceKind: 'supplier_purchase',
          sourceId: id,
          sourceLine: i,
          quantity: line.baseQuantity,
          unit: line.baseUnit,
          date: date.toIso8601String(),
          lot: '${doc.number}-${i + 1}',
          expiry: expiry,
          supplierId: partyId,
          costMinor: line.totalMinor,
          currency: currency,
          costStatus: 'confirmed',
          costReference: doc.number,
          actor: doc.actor,
          requestId: requestId);
    }
    await TransferService.commitStates(warehouse, shop, wh, sh);
  }

  static Future<void> reverse(
      WarehouseProvider warehouse, ShopProvider shop, String id, String reason,
      {required String requestId}) async {
    AccessControl.require('warehouse');
    InventoryCoordinator.check();
    Accounting.checkPeriod(warehouse.closedThrough);
    if (reason.trim().isEmpty || requestId.trim().isEmpty) {
      throw ArgumentError('Return reason and request are required.');
    }
    final original = warehouse.purchases.firstWhere((d) => d.id == id);
    if (original.purchaseKind != 'trading' || original.reversalOf != null) {
      throw StateError('Select an original trading receipt.');
    }
    final prior = warehouse.purchases.where((d) => d.requestId == requestId);
    if (prior.isNotEmpty) {
      if (prior.single.reversalOf != id ||
          prior.single.reason != reason.trim()) {
        throw StateError('Return request differs.');
      }
      return;
    }
    if (warehouse.isPurchaseReversed(id) || warehouse.paidFor(original) != 0) {
      throw StateError(
          'Reconcile actual supplier refunds before returning an active receipt.');
    }
    final wh = jsonDecode(warehouse.exportState()) as Map<String, dynamic>;
    final sh = jsonDecode(shop.exportState()) as Map<String, dynamic>;
    final date = DateTime.now(), reverseId = RecordId.create();
    for (var i = 0; i < original.lines.length; i++) {
      final line = original.lines[i], lotId = '$id:$i';
      if (FinishedStock.balance(sh, lotId) + 0.0000001 < line.baseQuantity) {
        throw StateError('Return requires the original supplier lot stock.');
      }
      final p =
          (sh['products'] as List).firstWhere((p) => p['id'] == line.itemId);
      p['quantity'] = (p['quantity'] as num).toDouble() - line.baseQuantity;
      FinishedStock.record(sh,
          productId: line.itemId,
          sourceId: reverseId,
          kind: 'purchaseReturn',
          allocations: {lotId: line.baseQuantity},
          date: date.toIso8601String(),
          actor: AccessControl.actor,
          requestId: requestId,
          direction: -1);
      FinishedStock.lots(sh).firstWhere((l) => l['id'] == lotId)['status'] =
          'returned';
    }
    final doc = TradeDocument(
        id: reverseId,
        number:
            'PUR-${((wh['purchases'] as List).length + 1).toString().padLeft(6, '0')}',
        type: 'purchaseReturn',
        purchaseKind: 'trading',
        stockTracked: true,
        date: date,
        party: original.party,
        partyId: original.partyId,
        currency: original.currency,
        itemId: original.itemId,
        itemName: original.itemName,
        unit: original.unit,
        quantity: original.quantity,
        unitPriceMinor: original.unitPriceMinor,
        totalMinor: original.totalMinor,
        paidMinor: original.paidMinor,
        lines: original.lines,
        reversalOf: id,
        reason: reason.trim(),
        reference: original.reference,
        requestId: requestId);
    (wh['purchases'] as List).add(doc.toJson());
    (wh['journals'] as List).add(JournalEntry.trade(doc).toJson());
    await TransferService.commitStates(warehouse, shop, wh, sh);
  }
}
