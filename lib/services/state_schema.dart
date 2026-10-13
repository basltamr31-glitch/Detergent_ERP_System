import '../models/journal_entry.dart';
import '../models/trade_document.dart';
import '../models/document_payment.dart';
import 'accounting.dart';
import 'dart:convert';
import 'money.dart';
import 'fill_costing.dart';

class StateSchema {
  static Map<String, dynamic> object(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  static void actor(dynamic value) {
    final data = object(value);
    for (final f in ['id', 'name', 'role']) {
      text(data[f], required: true);
    }
    if (![
      'legacy',
      'owner',
      'manager',
      'accountant',
      'warehouse',
      'cashier',
      'viewer'
    ].contains(data['role'])) {
      throw const FormatException('Invalid actor role.');
    }
  }

  static void number(dynamic value, {bool positive = false}) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        (positive && value == 0)) {
      throw const FormatException('Invalid quantity or price in saved data.');
    }
  }

  static void text(dynamic value, {bool required = false}) {
    if (value is! String || (required && value.trim().isEmpty)) {
      throw const FormatException('Invalid name in saved data.');
    }
  }

  static void draft(String key, Map<String, dynamic> data) {
    if (![1, 2].contains(data['version'])) {
      throw const FormatException('Unsupported draft version.');
    }
    if (key == 'production') {
      if (data['version'] == 2) {
        number(data['laborUSD']);
        number(data['overheadUSD']);
      }
      text(data['name']);
      number(data['rate']);
      number(data['quantity']);
      for (final row in data['materials'] as List) {
        text(row['name']);
        number(row['quantity']);
        number(row['usd']);
        number(row['syp']);
        if (row['active'] is! bool) {
          throw const FormatException('Invalid ingredient flag.');
        }
      }
    } else {
      if (data['version'] == 2) number(data['density']);
      if (data['perCarton'] is! int || data['perCarton'] < 1) {
        throw const FormatException('Invalid carton count.');
      }
      for (final field in ['cartonUSD', 'cartonSYP', 'labelUSD', 'labelSYP']) {
        number(data[field]);
      }
      for (final row in data['items'] as List) {
        if (data['version'] == 2 &&
            (!FillCosting.units.contains(row['unit']) ||
                row['unitConfirmed'] is! bool)) {
          throw const FormatException('Invalid packaging fill unit.');
        }
        number(row['size']);
        number(row['usd']);
        number(row['syp']);
        if (row['carton'] is! bool) {
          throw const FormatException('Invalid carton flag.');
        }
      }
    }
  }

  static void inventory(String key, Map<String, dynamic> data) {
    if (![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].contains(data['version'])) {
      throw const FormatException('Unsupported inventory version.');
    }
    final ids = <String>{};
    for (final group in key == 'warehouse'
        ? ['materials', 'transactions', 'batches']
        : ['products']) {
      final names = <String>{};
      for (final row in data[group] as List) {
        text(row['name'], required: true);
        number(row['quantity'],
            positive: group == 'transactions' || group == 'batches');
        if (data['version'] >= 2) {
          text(row['id'], required: true);
          if (!ids.add(row['id'] as String)) {
            throw const FormatException('Duplicate record ID.');
          }
        }
        if (group == 'materials' || group == 'products') {
          if (!names.add(row['name'] as String)) {
            throw const FormatException('Duplicate stock name.');
          }
          text(row['unit']);
          number(row['price']);
          if (row['priceCurrency'] != null &&
              !['', ...Money.currencies].contains(row['priceCurrency'])) {
            throw const FormatException('Invalid stock price currency.');
          }
        } else {
          DateTime.parse(row['date'] as String);
          if (group == 'transactions') {
            if (![
              'IN',
              'OUT',
              'CONSUMPTION',
              'RESTORE',
              'COUNT_IN',
              'COUNT_OUT'
            ].contains(row['type'])) {
              throw const FormatException('Invalid movement type.');
            }
          } else {
            final ingredients = row['materials'] as Map;
            if (ingredients.isEmpty) {
              throw const FormatException('Batch has no ingredients.');
            }
            for (final entry in ingredients.entries) {
              text(entry.key, required: true);
              number(entry.value, positive: true);
            }
          }
        }
      }
    }
    if (data['version'] >= 9) {
      for (final group in key == 'warehouse'
          ? ['purchases', 'payments', 'batches', 'transfers', 'journals']
          : ['sales', 'payments', 'transfers', 'journals']) {
        for (final row in data[group] as List) {
          if (row['actor'] != null) actor(row['actor']);
        }
      }
    }
    if (data['version'] >= 3) _documents(key, data, ids);
  }

  static void _documents(
      String key, Map<String, dynamic> data, Set<String> ids) {
    final partyIds = <String>{};
    if (data['version'] >= 5) {
      final names = <String>{};
      for (final party in data['parties'] as List) {
        text(party['id'], required: true);
        text(party['name'], required: true);
        text(party['phone']);
        text(party['address']);
        if (party['active'] is! bool ||
            !ids.add(party['id']) ||
            !partyIds.add(party['id']) ||
            !names.add((party['name'] as String).toLowerCase())) {
          throw const FormatException('Invalid or duplicate business party.');
        }
      }
    }
    final stocks = {
      for (final row
          in data[key == 'warehouse' ? 'materials' : 'products'] as List)
        row['id']: row
    };
    final trade = data[key == 'warehouse' ? 'purchases' : 'sales'] as List;
    final documents = <String, dynamic>{};
    final numbers = <String>{};
    final tokens = <String>{};
    final reversed = <String>{};
    for (final doc in trade) {
      for (final field in [
        'id',
        'number',
        'party',
        'currency',
        'itemId',
        'itemName',
        'unit',
        'requestId'
      ]) {
        text(doc[field], required: true);
      }
      if (doc['partyId'] != null && !partyIds.contains(doc['partyId'])) {
        throw const FormatException('Invalid party reference.');
      }
      text(doc['reason']);
      text(doc['reference']);
      DateTime.parse(doc['date'] as String);
      if (!ids.add(doc['id']) ||
          !numbers.add(doc['number']) ||
          !tokens.add(doc['requestId'])) {
        throw const FormatException('Duplicate business document.');
      }
      final originalType = key == 'warehouse' ? 'purchase' : 'sale';
      final returnType = key == 'warehouse' ? 'purchaseReturn' : 'saleReturn';
      if (![originalType, returnType].contains(doc['type']) ||
          !Money.currencies.contains(doc['currency']) ||
          !stocks.containsKey(doc['itemId'])) {
        throw const FormatException('Invalid document reference.');
      }
      for (final field in ['unitPriceMinor', 'totalMinor', 'paidMinor']) {
        if (doc[field] is! int ||
            doc[field] < 0 ||
            doc[field] > Money.maxMinor) {
          throw const FormatException('Invalid money amount.');
        }
      }
      final lines = data['version'] >= 6 ? doc['lines'] as List : [doc];
      if (lines.isEmpty) throw const FormatException('Document has no items.');
      final lineIds = <String>{};
      int total = 0;
      for (final line in lines) {
        for (final field in ['itemId', 'itemName', 'unit']) {
          text(line[field], required: true);
        }
        if (!stocks.containsKey(line['itemId']) ||
            !lineIds.add(line['itemId']) ||
            line['unitPriceMinor'] is! int ||
            line['totalMinor'] is! int) {
          throw const FormatException('Invalid document item.');
        }
        try {
          if (Money.total((line['quantity'] as num).toDouble(),
                  line['unitPriceMinor']) !=
              line['totalMinor']) {
            throw const FormatException('Item total does not reconcile.');
          }
        } on ArgumentError {
          throw const FormatException('Invalid document item quantity.');
        }
        total += line['totalMinor'] as int;
      }
      if (total > Money.maxMinor ||
          total != doc['totalMinor'] ||
          doc['paidMinor'] > total) {
        throw const FormatException('Document total does not reconcile.');
      }
      if (data['version'] >= 6) {
        for (final field in [
          'itemId',
          'itemName',
          'unit',
          'quantity',
          'unitPriceMinor'
        ]) {
          if (doc[field] != lines.first[field]) {
            throw const FormatException(
                'Document summary differs from first item.');
          }
        }
      }
      if (doc['reversalOf'] != null) {
        text(doc['reason'], required: true);
        final original = documents[doc['reversalOf']];
        if (doc['type'] != returnType ||
            original == null ||
            original['type'] != originalType ||
            !reversed.add(doc['reversalOf'])) {
          throw const FormatException('Invalid document reversal.');
        }
        if (jsonEncode(doc['lines']) != jsonEncode(original['lines'])) {
          throw const FormatException('Return items differ from original.');
        }
        for (final field in [
          'party',
          'partyId',
          'currency',
          'itemId',
          'itemName',
          'unit',
          'quantity',
          'unitPriceMinor',
          'totalMinor',
          'paidMinor'
        ]) {
          if (doc[field] != original[field]) {
            throw const FormatException(
                'Reversal does not match original document.');
          }
        }
      } else if (doc['type'] != originalType) {
        throw const FormatException('Return is missing its original document.');
      }
      documents[doc['id']] = doc;
    }

    final paid = <String, int>{};
    if (data['version'] >= 4) {
      for (final payment in data['payments'] as List) {
        for (final field in ['id', 'documentId', 'requestId']) {
          text(payment[field], required: true);
        }
        text(payment['reference']);
        DateTime.parse(payment['date'] as String);
        final doc = documents[payment['documentId']];
        final amount = payment['amountMinor'];
        if (!ids.add(payment['id']) ||
            !tokens.add(payment['requestId']) ||
            doc == null ||
            doc['reversalOf'] != null ||
            (data['version'] < 8 && reversed.contains(doc['id'])) ||
            amount is! int ||
            amount <= 0 ||
            amount > Money.maxMinor) {
          throw const FormatException('Invalid payment allocation.');
        }
        final kind = payment['kind'] ?? 'payment';
        if (!['payment', 'refund'].contains(kind)) {
          throw const FormatException('Invalid payment kind.');
        }
        if (kind == 'refund') text(payment['reason'], required: true);
        final total = (paid[doc['id']] ?? doc['paidMinor'] as int) +
            (kind == 'refund' ? -amount : amount);
        if (total < 0 || total > doc['totalMinor']) {
          throw const FormatException('Payments exceed the document balance.');
        }
        paid[doc['id']] = total;
      }
    }
    if (data['version'] >= 8) {
      for (final doc in trade.where(
          (d) => d['reversalOf'] == null && reversed.contains(d['id']))) {
        if (paid.containsKey(doc['id']) && paid[doc['id']] != 0) {
          throw const FormatException(
              'Returned goods retain unrefunded payments.');
        }
      }
    }
    if (data['version'] >= 9) {
      DateTime.parse(data['ledgerStartedAt'] as String);
      if (data['closedThrough'] != null &&
          (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(data['closedThrough']) ||
              DateTime.parse(data['closedThrough'])
                      .toIso8601String()
                      .substring(0, 10) !=
                  data['closedThrough'])) {
        throw const FormatException('Invalid period lock.');
      }
      final eventIds = <String>{};
      String? lastClosed;
      for (final e in data['periodEvents'] as List? ?? []) {
        text(e['id'], required: true);
        text(e['reason'], required: true);
        DateTime.parse(e['date'] as String);
        if (!eventIds.add(e['id']) ||
            !['close', 'reopen'].contains(e['kind'])) {
          throw const FormatException('Invalid period event.');
        }
        if (e['kind'] == 'close') {
          text(e['through'], required: true);
          if (DateTime.parse(e['through']).toIso8601String().substring(0, 10) !=
              e['through']) {
            throw const FormatException('Invalid closed date.');
          }
          lastClosed = e['through'];
        } else {
          lastClosed = null;
        }
      }
      if (lastClosed != data['closedThrough']) {
        throw const FormatException('Period events differ from lock.');
      }
      final sources = <String>{};
      for (final raw in data['journals'] as List) {
        final j = JournalEntry.fromJson(object(raw));
        Accounting.validate(j);
        text(j.sourceId, required: true);
        text(j.reference, required: true);
        if (!ids.add(j.id) || !sources.add(j.sourceId)) {
          throw const FormatException('Duplicate journal.');
        }
        JournalEntry? expected;
        if (j.kind == 'trade') {
          final doc = documents[j.sourceId];
          if (doc == null) {
            throw const FormatException('Missing journal document.');
          }
          expected = JournalEntry.trade(TradeDocument.fromJson(object(doc)));
        } else if (j.kind == 'payment') {
          final payments =
              (data['payments'] as List).where((p) => p['id'] == j.sourceId);
          if (payments.length != 1) {
            throw const FormatException('Missing journal payment.');
          }
          final payment = DocumentPayment.fromJson(object(payments.single));
          expected = JournalEntry.payment(payment,
              TradeDocument.fromJson(object(documents[payment.documentId])));
        }
        if (expected != null &&
            (j.currency != expected.currency ||
                j.date != expected.date ||
                jsonEncode(j.lines.map((l) => l.toJson()).toList()) !=
                    jsonEncode(
                        expected.lines.map((l) => l.toJson()).toList()))) {
          throw const FormatException('Journal differs from source document.');
        }
      }
    }
    final counts = <String, dynamic>{};
    if (data['version'] >= 10) {
      for (final c in data['counts'] as List) {
        for (final f in ['id', 'itemId', 'reason', 'requestId']) {
          text(c[f], required: true);
        }
        actor(c['actor']);
        DateTime.parse(c['date'] as String);
        number(c['before']);
        number(c['after']);
        if (!stocks.containsKey(c['itemId']) ||
            !ids.add(c['id']) ||
            !tokens.add(c['requestId']) ||
            c['before'] == c['after']) {
          throw const FormatException('Invalid stock count.');
        }
        counts[c['id']] = c;
      }
    }
    if (data['version'] >= 7) _transfers(key, data, ids, tokens);
    if (data['version'] >= 12 && key == 'shop') {
      final transfers = {for (final t in data['transfers'] as List) t['id']: t};
      final used = <String, double>{};
      void allocations(dynamic value, String itemId, double maximum,
          {bool active = true, String? date}) {
        final lots = value as Map? ?? {};
        double total = 0;
        for (final e in lots.entries) {
          final t = transfers[e.key];
          number(e.value, positive: true);
          if (t == null ||
              t['reversalOf'] != null ||
              t['productId'] != itemId ||
              (date != null &&
                  (t['expiry'] ?? '') != '' &&
                  (t['expiry'] as String).compareTo(date) <= 0)) {
            throw const FormatException('Invalid or expired lot allocation.');
          }
          final amount = (e.value as num).toDouble();
          total += amount;
          if (active) {
            used.update(e.key, (v) => v + amount, ifAbsent: () => amount);
          }
        }
        if (total > maximum + 0.0000001) {
          throw const FormatException('Lot allocation exceeds item quantity.');
        }
      }

      for (final doc in trade.where((d) => d['reversalOf'] == null)) {
        for (final line in doc['lines'] as List) {
          allocations(line['lots'], line['itemId'],
              (line['quantity'] as num).toDouble(),
              active: !reversed.contains(doc['id']),
              date: DateTime.parse(doc['date'])
                  .toUtc()
                  .toIso8601String()
                  .substring(0, 10));
        }
      }
      for (final c in counts.values) {
        allocations(
            c['lots'],
            c['itemId'],
            c['before'] > c['after']
                ? (c['before'] - c['after']).toDouble()
                : 0);
      }
      for (final e in used.entries) {
        if (e.value > transfers[e.key]['quantity'] + 0.0000001 ||
            (data['transfers'] as List).any((t) => t['reversalOf'] == e.key)) {
          throw const FormatException('Lot usage does not reconcile.');
        }
      }
    }

    if (key != 'warehouse') return;
    final batches = <String, dynamic>{};
    final reversedBatches = <String>{};
    final replacements = <String>{};
    final productionTokens = <String>{};
    for (final batch in data['batches'] as List) {
      text(batch['number'], required: true);
      text(batch['reason']);
      if (batch['requestId'] != null) {
        text(batch['requestId'], required: true);
        if (!productionTokens.add(batch['requestId'])) {
          throw const FormatException('Duplicate production request.');
        }
      }
      if (!numbers.add(batch['number']) ||
          !['production', 'reversal'].contains(batch['kind'])) {
        throw const FormatException('Invalid production document.');
      }
      final links = batch['materialIds'] as Map;
      for (final entry in links.entries) {
        text(entry.key, required: true);
        text(entry.value, required: true);
        if (!(batch['materials'] as Map).containsKey(entry.key) ||
            !stocks.containsKey(entry.value)) {
          throw const FormatException('Invalid production material reference.');
        }
      }
      if (batch['kind'] == 'reversal') {
        text(batch['reason'], required: true);
        final original = batches[batch['reversalOf']];
        if (original == null ||
            original['kind'] != 'production' ||
            !reversedBatches.add(batch['reversalOf'])) {
          throw const FormatException('Invalid production reversal.');
        }
        for (final field in ['name', 'quantity']) {
          if (batch[field] != original[field]) {
            throw const FormatException(
                'Production reversal differs from original.');
          }
        }
        final originalIngredients = original['materials'] as Map;
        final ingredients = batch['materials'] as Map;
        if (ingredients.length != originalIngredients.length ||
            ingredients.entries
                .any((e) => originalIngredients[e.key] != e.value)) {
          throw const FormatException(
              'Production reversal ingredients differ from original.');
        }
        final originalLinks = original['materialIds'] as Map;
        if (links.length != originalLinks.length ||
            links.entries.any((e) => originalLinks[e.key] != e.value)) {
          throw const FormatException(
              'Production reversal material IDs differ from original.');
        }
      } else if (batch['reversalOf'] != null) {
        throw const FormatException('Invalid reversal link.');
      }
      if (batch['replacesId'] != null &&
          (batch['kind'] != 'production' ||
              !reversedBatches.contains(batch['replacesId']) ||
              !replacements.add(batch['replacesId']))) {
        throw const FormatException(
            'Correction must reverse an existing production document.');
      }
      batches[batch['id']] = batch;
    }
    if (data['version'] >= 11) {
      final recipes = <String, dynamic>{},
          versions = <String>{},
          lots = <String>{};
      for (final r in data['recipes'] as List) {
        text(r['id'], required: true);
        text(r['name'], required: true);
        text(r['unit'], required: true);
        number(r['quantity'], positive: true);
        actor(r['actor']);
        DateTime.parse(r['date'] as String);
        if (!ids.add(r['id']) ||
            r['version'] is! int ||
            r['version'] < 1 ||
            !versions.add('${r['name']}:${r['version']}')) {
          throw const FormatException('Invalid recipe version.');
        }
        if ((r['materials'] as Map).isEmpty) {
          throw const FormatException('Recipe is empty.');
        }
        for (final e in (r['materials'] as Map).entries) {
          if (!stocks.containsKey(e.key)) {
            throw const FormatException('Recipe material is missing.');
          }
          number(e.value, positive: true);
        }
        recipes[r['id']] = r;
      }
      for (final o in data['orders'] as List) {
        for (final f in ['id', 'number', 'name', 'unit', 'lot', 'requestId']) {
          text(o[f], required: true);
        }
        number(o['quantity'], positive: true);
        text(o['expiry']);
        if (o['expiry'] != '' &&
            DateTime.parse(o['expiry']).toIso8601String().substring(0, 10) !=
                o['expiry']) {
          throw const FormatException('Invalid expiry.');
        }
        if (!ids.add(o['id']) ||
            !numbers.add(o['number']) ||
            !tokens.add(o['requestId']) ||
            !lots.add(o['lot'])) {
          throw const FormatException('Duplicate production order.');
        }
        final recipe = recipes[o['recipeId']];
        if (recipe == null ||
            recipe['quantity'] != o['quantity'] ||
            recipe['name'] != o['name'] ||
            recipe['unit'] != o['unit'] ||
            jsonEncode(recipe['materials']) != jsonEncode(o['materials'])) {
          throw const FormatException(
              'Order differs from its recipe snapshot.');
        }
        final events = o['events'] as List;
        final stages = events.map((e) => e['kind']).join(',');
        if (![
          'created',
          'created,approved',
          'created,cancelled',
          'created,approved,cancelled',
          'created,approved,released'
        ].contains(stages)) {
          throw const FormatException('Invalid order approval history.');
        }
        for (final e in events) {
          if (e['kind'] == 'approved' &&
              !['owner', 'manager', 'legacy'].contains(e['actor']['role'])) {
            throw const FormatException(
                'Order was not approved by an authorized role.');
          }
          text(e['reason'], required: true);
          actor(e['actor']);
          DateTime.parse(e['date'] as String);
        }
        final expectedStatus =
            events.last['kind'] == 'created' ? 'draft' : events.last['kind'];
        if (o['status'] != expectedStatus) {
          throw const FormatException('Order status differs from history.');
        }
        if (o['status'] == 'released') {
          final batch = batches[o['batchId']];
          if (batch == null ||
              batch['kind'] != 'production' ||
              batch['requestId'] != o['id'] ||
              batch['quantity'] != o['quantity'] ||
              batch['name'] != o['name']) {
            throw const FormatException('Missing order production batch.');
          }
          final ingredients = {
            for (final e in (batch['materials'] as Map).entries)
              batch['materialIds'][e.key]: e.value
          };
          if (jsonEncode(ingredients) != jsonEncode(o['materials'])) {
            throw const FormatException(
                'Order ingredients differ from production.');
          }
        } else if (o['batchId'] != null) {
          throw const FormatException('Unreleased order has a batch.');
        }
      }
    }
    for (final movement in data['transactions'] as List) {
      if (movement['materialId'] != null &&
          !stocks.containsKey(movement['materialId'])) {
        throw const FormatException('Missing movement material.');
      }
      if (movement['documentId'] != null &&
          !documents.containsKey(movement['documentId']) &&
          !batches.containsKey(movement['documentId']) &&
          !counts.containsKey(movement['documentId'])) {
        throw const FormatException('Missing movement document.');
      }
    }
    for (final c in counts.values) {
      final matching = (data['transactions'] as List)
          .where((m) => m['documentId'] == c['id'])
          .toList();
      if (matching.length != 1 ||
          matching.single['materialId'] != c['itemId'] ||
          matching.single['quantity'] != (c['after'] - c['before']).abs() ||
          matching.single['type'] !=
              (c['after'] > c['before'] ? 'COUNT_IN' : 'COUNT_OUT')) {
        throw const FormatException('Stock count does not reconcile.');
      }
    }
    for (final doc in trade) {
      final movements = (data['transactions'] as List)
          .where((t) => t['documentId'] == doc['id'])
          .toList();
      final lines = data['version'] >= 6 ? doc['lines'] as List : [doc];
      if (movements.length != lines.length) {
        throw const FormatException('Receipt movements do not reconcile.');
      }
      for (final line in lines) {
        if (movements
                .where((m) =>
                    m['materialId'] == line['itemId'] &&
                    m['quantity'] == line['quantity'] &&
                    m['type'] == (doc['reversalOf'] == null ? 'IN' : 'OUT'))
                .length !=
            1) {
          throw const FormatException(
              'Receipt item differs from stock movement.');
        }
      }
    }

    for (final batch in batches.values) {
      final links = batch['materialIds'] as Map;
      if (links.isEmpty) {
        continue; // Legacy batches have no document-linked ledger.
      }
      final movements = (data['transactions'] as List)
          .where((t) => t['documentId'] == batch['id'])
          .toList();
      if (links.length != (batch['materials'] as Map).length ||
          movements.length != links.length) {
        throw const FormatException('Production movements do not reconcile.');
      }
      for (final entry in links.entries) {
        final matching = movements.where((t) =>
            t['materialId'] == entry.value &&
            t['quantity'] == batch['materials'][entry.key] &&
            t['type'] ==
                (batch['kind'] == 'production' ? 'CONSUMPTION' : 'RESTORE'));
        if (matching.length != 1) {
          throw const FormatException(
              'Production movement differs from document.');
        }
      }
    }
  }

  static void pair(Map<String, dynamic> warehouse, Map<String, dynamic> shop) {
    inventory('warehouse', warehouse);
    inventory('shop', shop);
    if (jsonEncode(warehouse['periodEvents'] ?? []) !=
        jsonEncode(shop['periodEvents'] ?? [])) {
      throw const FormatException('Period event histories differ.');
    }
    if (warehouse['closedThrough'] != shop['closedThrough']) {
      throw const FormatException('Accounting locks differ between stores.');
    }
    if (jsonEncode(warehouse['transfers'] ?? []) !=
        jsonEncode(shop['transfers'] ?? [])) {
      throw const FormatException(
          'Warehouse and shop transfers do not reconcile.');
    }
  }

  static void _transfers(String key, Map<String, dynamic> data, Set<String> ids,
      Set<String> tokens) {
    final prior = <String, dynamic>{},
        reversed = <String>{},
        numbers = <String>{};
    final used = <String, double>{}, units = <String, String>{};
    for (final t in data['transfers'] as List) {
      for (final field in [
        'id',
        'number',
        'batchId',
        'sourceUnit',
        'productId',
        'productName',
        'unit',
        'requestId'
      ]) {
        text(t[field], required: true);
      }
      text(t['reason']);
      DateTime.parse(t['date'] as String);
      if (!ids.add(t['id']) ||
          !tokens.add(t['requestId']) ||
          !numbers.add(t['number']) ||
          !Money.currencies.contains(t['currency']) ||
          t['unitPriceMinor'] is! int) {
        throw const FormatException('Invalid stock transfer.');
      }
      try {
        Money.total((t['quantity'] as num).toDouble(), t['unitPriceMinor']);
        Money.total((t['sourceQuantity'] as num).toDouble(), 0);
      } on ArgumentError {
        throw const FormatException('Invalid transfer quantity.');
      }
      if (t['reversalOf'] != null) {
        final original = prior[t['reversalOf']];
        text(t['reason'], required: true);
        if (original == null ||
            original['reversalOf'] != null ||
            !reversed.add(t['reversalOf'])) {
          throw const FormatException('Invalid transfer return.');
        }
        for (final f in [
          'batchId',
          'sourceQuantity',
          'sourceUnit',
          'productId',
          'productName',
          'quantity',
          'unit',
          'unitPriceMinor',
          'currency',
          'lot',
          'expiry'
        ]) {
          if (t[f] != original[f]) {
            throw const FormatException(
                'Transfer return differs from original.');
          }
        }
      }
      if (key == 'warehouse') {
        final batches = (data['batches'] as List)
            .where((b) => b['id'] == t['batchId'] && b['kind'] == 'production');
        if (batches.length != 1 ||
            (units[t['batchId']] != null &&
                units[t['batchId']] != t['sourceUnit'])) {
          throw const FormatException('Invalid transfer batch or unit.');
        }
        units[t['batchId']] = t['sourceUnit'];
        final amount = (used[t['batchId']] ?? 0) +
            (t['reversalOf'] == null ? 1 : -1) *
                (t['sourceQuantity'] as num).toDouble();
        if (amount < -0.0000001 ||
            amount > batches.single['quantity'] + 0.0000001) {
          throw const FormatException('Transfer exceeds produced quantity.');
        }
        used[t['batchId']] = amount;
      } else if (!(data['products'] as List)
          .any((p) => p['id'] == t['productId'] && p['unit'] == t['unit'])) {
        throw const FormatException('Invalid transfer product.');
      }
      prior[t['id']] = t;
    }
    if (key == 'warehouse') {
      for (final entry in used.entries) {
        if (entry.value.abs() > 0.0000001 &&
            (data['batches'] as List)
                .any((b) => b['reversalOf'] == entry.key)) {
          throw const FormatException(
              'Reversed production has transferred goods.');
        }
      }
    }
  }
}
