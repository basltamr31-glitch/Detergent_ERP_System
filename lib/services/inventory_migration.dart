import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Builds an upgraded snapshot without changing its input or writing to storage.
///
/// The caller must validate the original state and commit both stores together.
/// Historical documents remain unchanged; baselines describe stock at cutover.
class InventoryMigration {
  static const version = 13;
  static const _tolerance = 0.0000001;
  static const _legacyActor = {
    'id': 'legacy',
    'name': 'Legacy record',
    'role': 'legacy',
  };

  static Map<String, dynamic> warehouse(Map<String, dynamic> data) {
    final state = _copy(data);
    final previous = _version(state);
    if (previous == version) return state;
    final digest = _digest(data);
    _legacyShape(state, 'warehouse', previous, digest);
    _stockMasters(state, 'materials', previous, digest);
    state['version'] = version;
    state['migration'] = _metadata(previous, digest, 'warehouse');
    return state;
  }

  static Map<String, dynamic> shop(Map<String, dynamic> data) {
    final state = _copy(data);
    final previous = _version(state);
    if (previous == version) return state;
    final digest = _digest(data);
    _legacyShape(state, 'shop', previous, digest);
    _stockMasters(state, 'products', previous, digest);
    final products = {
      for (final raw in state['products'] as List)
        (raw as Map<String, dynamic>)['id'] as String: raw,
    };
    final transfers = <String, Map<String, dynamic>>{};
    final returned = <String>{};
    for (final row in _rows(state, 'transfers')) {
      final id = _id(row['id']);
      if (transfers.containsKey(id)) {
        throw const FormatException('Duplicate transfer in migration.');
      }
      transfers[id] = row;
      if (row['reversalOf'] != null) returned.add(_id(row['reversalOf']));
    }
    final sales = _rows(state, 'sales');
    final reversedSales = {
      for (final sale in sales)
        if (sale['reversalOf'] != null) _id(sale['reversalOf']),
    };
    final used = <String, double>{};
    void consume(Map<String, dynamic> row) {
      final allocations = row['lots'];
      if (allocations == null) return;
      if (allocations is! Map) {
        throw const FormatException('Invalid legacy lot allocations.');
      }
      for (final allocation in allocations.entries) {
        final transferId = _id(allocation.key);
        final transfer = transfers[transferId];
        final quantity = _quantity(allocation.value, positive: true);
        if (transfer == null ||
            transfer['reversalOf'] != null ||
            transfer['productId'] != row['itemId']) {
          throw const FormatException('Invalid legacy lot source.');
        }
        used.update(transferId, (value) => value + quantity,
            ifAbsent: () => quantity);
      }
    }

    for (final sale in sales) {
      if (sale['reversalOf'] != null || reversedSales.contains(sale['id'])) {
        continue;
      }
      for (final line in sale['lines'] as List? ?? [sale]) {
        consume(Map<String, dynamic>.from(line as Map));
      }
    }
    for (final count in _rows(state, 'counts')) {
      consume(count);
    }

    final lots = <Map<String, dynamic>>[];
    final stockBaseline = <String, double>{};
    final lotBaseline = <String, double>{};
    final known = <String, double>{};
    for (final entry in transfers.entries) {
      final transfer = entry.value;
      if (transfer['reversalOf'] != null) continue;
      final quantity = _quantity(transfer['quantity'], positive: true);
      final consumed = used[entry.key] ?? 0;
      if (returned.contains(entry.key)) {
        if (consumed > _tolerance) {
          throw const FormatException(
              'Returned transfer has active usage; review stock before migration.');
        }
        continue;
      }
      if (consumed > quantity + _tolerance) {
        throw const FormatException(
            'Legacy lot is overallocated; review stock before migration.');
      }
      final productId = _id(transfer['productId']);
      final product = products[productId];
      if (product == null || product['unit'] != transfer['unit']) {
        throw const FormatException('Legacy lot product or unit is missing.');
      }
      // Match the six-place remaining-lot convention of the existing provider.
      final remaining = double.parse((quantity - consumed).toStringAsFixed(6));
      if (remaining < -_tolerance) {
        throw const FormatException('Legacy lot has negative remaining stock.');
      }
      final available = remaining < 0 ? 0.0 : remaining;
      lots.add(_lot(
          id: entry.key,
          productId: productId,
          sourceKind: 'manufacturing',
          sourceId: _id(transfer['batchId']),
          quantity: quantity,
          unit: transfer['unit'] as String,
          receivedAt: _date(transfer['date']),
          expiry: transfer['expiry'] as String? ?? '',
          lot: transfer['lot'] as String? ?? '',
          actor: transfer['actor'] as Map?));
      lotBaseline[entry.key] = available;
      known.update(productId, (value) => value + available,
          ifAbsent: () => available);
    }
    final openingDate = _openingDate(state);
    for (final entry in products.entries) {
      final product = entry.value;
      final quantity = _quantity(product['quantity']);
      final traced = known[entry.key] ?? 0;
      stockBaseline[entry.key] = quantity;
      if (traced > quantity + _tolerance) {
        throw FormatException(
            'Known lots exceed stock for ${entry.key}; reconcile before migration.');
      }
      final residual = quantity - traced;
      if (residual > 0) {
        final id = 'legacy:${entry.key}';
        if (transfers.containsKey(id) || lotBaseline.containsKey(id)) {
          throw const FormatException('Legacy opening lot ID conflicts.');
        }
        lots.add(_lot(
            id: id,
            productId: entry.key,
            sourceKind: 'legacy_opening',
            sourceId: id,
            quantity: residual,
            unit: product['unit'] as String,
            receivedAt: openingDate));
        lotBaseline[id] = residual;
      }
    }
    state['version'] = version;
    state['stockLots'] = lots;
    state['stockMovements'] = <Map<String, dynamic>>[];
    state['stockBaseline'] = stockBaseline;
    state['lotBaseline'] = lotBaseline;
    state['migration'] = _metadata(previous, digest, 'shop');
    return state;
  }

  static Map<String, dynamic> _lot(
          {required String id,
          required String productId,
          required String sourceKind,
          required String sourceId,
          required double quantity,
          required String unit,
          required String receivedAt,
          String expiry = '',
          String lot = '',
          Map? actor}) =>
      {
        'id': id,
        'productId': productId,
        'sourceKind': sourceKind,
        'sourceId': sourceId,
        'sourceLine': 0,
        'quantity': quantity,
        'unit': unit,
        'receivedAt': receivedAt,
        'expiry': expiry,
        'lot': lot,
        'status': 'available',
        'costStatus': 'unknown',
        'costMinor': null,
        'currency': null,
        'supplierId': null,
        'actor': Map<String, dynamic>.from(actor ?? _legacyActor),
      };

  static void _stockMasters(
      Map<String, dynamic> state, String key, int previous, String digest) {
    final masters = state[key];
    if (masters is! List) {
      throw const FormatException('Missing legacy stock masters.');
    }
    final ids = <String>{};
    for (var index = 0; index < masters.length; index++) {
      final row = Map<String, dynamic>.from(masters[index] as Map);
      if (row['id'] == null && previous == 1) {
        row['id'] = 'legacy-$key:${digest.substring(0, 20)}:$index';
      }
      final id = _id(row['id']);
      if (!ids.add(id)) {
        throw const FormatException('Duplicate legacy stock master.');
      }
      _quantity(row['quantity']);
      if (row['unit'] is! String) {
        throw const FormatException('Invalid legacy stock unit.');
      }
      row.putIfAbsent('sku', () => 'SKU-$id');
      row.putIfAbsent('unitConversions', () => <Map<String, dynamic>>[]);
      masters[index] = row;
    }
  }

  static void _legacyShape(
      Map<String, dynamic> state, String store, int previous, String digest) {
    final groups = store == 'warehouse'
        ? [
            'materials',
            'transactions',
            'batches',
            'purchases',
            'recipes',
            'orders'
          ]
        : ['products', 'sales'];
    for (final key in [
      ...groups,
      'payments',
      'parties',
      'transfers',
      'counts',
      'journals',
      'periodEvents'
    ]) {
      state.putIfAbsent(key, () => <Map<String, dynamic>>[]);
    }
    state.putIfAbsent('closedThrough', () => null);
    state.putIfAbsent('ledgerStartedAt', () => _openingDate(state));
    if (store == 'warehouse') {
      for (final key in ['transactions', 'batches']) {
        final rows = state[key] as List;
        for (var index = 0; index < rows.length; index++) {
          final row = Map<String, dynamic>.from(rows[index] as Map);
          if (row['id'] == null && previous == 1) {
            row['id'] = 'legacy-$key:${digest.substring(0, 20)}:$index';
          }
          if (key == 'batches' && previous < 12) {
            row.putIfAbsent('number',
                () => 'PRD-${(index + 1).toString().padLeft(6, '0')}');
            row.putIfAbsent('kind', () => 'production');
            row.putIfAbsent('reason', () => '');
            row.putIfAbsent('materialIds', () => <String, String>{});
            row.putIfAbsent('requestId', () => row['id']);
            row.putIfAbsent(
                'actor', () => Map<String, String>.from(_legacyActor));
          }
          rows[index] = row;
        }
      }
    }
    if (previous >= 12) return;
    for (final key in [
      store == 'warehouse' ? 'purchases' : 'sales',
      'payments',
      'transfers',
      'journals'
    ]) {
      final rows = state[key] as List;
      for (var index = 0; index < rows.length; index++) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        row.putIfAbsent('actor', () => Map<String, String>.from(_legacyActor));
        if (key == 'payments') {
          row.putIfAbsent('kind', () => 'payment');
          row.putIfAbsent('reason', () => '');
        } else if (key == 'transfers') {
          row.putIfAbsent('lot', () => '');
          row.putIfAbsent('expiry', () => '');
        } else if (key == 'purchases' || key == 'sales') {
          row.putIfAbsent('purchaseKind', () => 'raw');
          row.putIfAbsent('stockTracked', () => false);
          row.putIfAbsent(
              'lines',
              () => [
                    <String, dynamic>{
                      for (final field in [
                        'itemId',
                        'itemName',
                        'unit',
                        'quantity',
                        'unitPriceMinor',
                        'totalMinor'
                      ])
                        field: row[field],
                      'lots': <String, double>{},
                    }
                  ]);
        }
        rows[index] = row;
      }
    }
  }

  static int _version(Map<String, dynamic> state) {
    final value = state['version'];
    if (value is! int || value < 1 || value > version) {
      throw const FormatException('Unsupported inventory migration version.');
    }
    return value;
  }

  static List<Map<String, dynamic>> _rows(
      Map<String, dynamic> state, String key) {
    final values = state[key];
    if (values == null) return [];
    if (values is! List) {
      throw const FormatException('Invalid legacy document list.');
    }
    return values.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static double _quantity(dynamic value, {bool positive = false}) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        (positive && value == 0)) {
      throw const FormatException('Invalid legacy stock quantity.');
    }
    return value.toDouble();
  }

  static String _id(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Missing legacy inventory identifier.');
    }
    return value;
  }

  static String _date(dynamic value) {
    if (value is! String || DateTime.tryParse(value) == null) {
      throw const FormatException('Invalid legacy inventory date.');
    }
    return value;
  }

  static String _openingDate(Map<String, dynamic> state) {
    if (state['ledgerStartedAt'] != null) {
      return _date(state['ledgerStartedAt']);
    }
    DateTime? earliest;
    String? original;
    for (final key in [
      'transfers',
      'sales',
      'counts',
      'transactions',
      'batches',
      'purchases',
      'orders'
    ]) {
      for (final row in _rows(state, key)) {
        final value = row['date'];
        if (value is! String) continue;
        final date = DateTime.tryParse(value);
        if (date != null && (earliest == null || date.isBefore(earliest))) {
          earliest = date;
          original = value;
        }
      }
    }
    // A sorting sentinel for undated legacy openings, not a receipt-date claim.
    return original ?? '1970-01-01T00:00:00.000Z';
  }

  static Map<String, dynamic> _metadata(
          int previous, String digest, String store) =>
      {
        'fromVersion': previous,
        'sourceSha256': digest,
        'id': 'inventory-$version-$store:$digest',
      };

  static String _digest(Map<String, dynamic> data) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(data)))).toString();

  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key as String).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
}
