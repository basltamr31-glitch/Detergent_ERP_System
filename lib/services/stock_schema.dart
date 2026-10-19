import 'finished_stock.dart';
import 'inventory_units.dart';
import 'money.dart';

/// Validates the schema-13 cutover baseline and all subsequent stock postings.
class StockSchema {
  static const _tolerance = 0.0000001;
  static const _sources = {
    'manufacturing',
    'legacy_opening',
    'adjustment',
    'supplier_purchase'
  };
  static const _kinds = {
    'receipt',
    'sale',
    'saleReturn',
    'count_out',
    'transferReturn',
    'purchaseReturn',
    'adjustment'
  };

  static void validate(Map<String, dynamic> shop) {
    if (shop['version'] != 13) _fail('Unsupported finished-stock schema.');
    final products = _masters(shop, 'products');
    final lots = <String, Map<String, dynamic>>{};
    for (final lot in _rows(shop, 'stockLots')) {
      final id = _text(lot['id']);
      final product = products[_text(lot['productId'])];
      if (product == null || lots.containsKey(id)) {
        _fail('Duplicate stock lot or missing product.');
      }
      lots[id] = lot;
      if (!_sources.contains(lot['sourceKind']) ||
          !['available', 'held', 'returned'].contains(lot['status'])) {
        _fail('Invalid stock source or lot status.');
      }
      _text(lot['sourceId']);
      _integer(lot['sourceLine'], minimum: 0);
      _number(lot['quantity'], positive: true);
      if (lot['unit'] is! String || lot['unit'] != product['unit']) {
        _fail('Lot unit differs from the product base unit.');
      }
      _date(lot['receivedAt']);
      _expiry(lot['expiry']);
      if (lot['lot'] is! String) _fail('Invalid lot label.');
      _actor(lot['actor']);
      if (lot['supplierId'] != null) _text(lot['supplierId']);
      _cost(lot);
    }
    final stockBaseline = _map(shop['stockBaseline']);
    final lotBaseline = _map(shop['lotBaseline']);
    if (!_sameKeys(stockBaseline, products) || !_sameKeys(lotBaseline, lots)) {
      _fail('Stock baseline references differ from their masters.');
    }
    final balances = <String, double>{};
    final productMovements = <String, double>{};
    for (final entry in lotBaseline.entries) {
      final opening = _number(entry.value);
      if (opening > _number(lots[entry.key]!['quantity']) + _tolerance) {
        _fail('Lot opening exceeds its received quantity.');
      }
      balances[entry.key] = opening;
    }
    for (final value in stockBaseline.values) {
      _number(value);
    }
    final costBalances = <String, int>{
      for (final e in lots.entries)
        if (e.value['costMinor'] != null)
          e.key: FinishedStock.proportion(
              e.value['costMinor'] as int,
              (lotBaseline[e.key] as num).toDouble(),
              (e.value['quantity'] as num).toDouble())
    };
    final movements = _rows(shop, 'stockMovements');
    final movementIds = <String>{};
    final postings = <String>{};
    for (final movement in movements) {
      final id = _text(movement['id']);
      final productId = _text(movement['productId']);
      final lotId = _text(movement['lotId']);
      final lot = lots[lotId];
      final sourceId = _text(movement['sourceId']);
      final kind = _text(movement['kind']);
      final quantity = _signed(movement['quantity']);
      if (!movementIds.add(id) ||
          !postings.add('$sourceId:$kind:$productId:$lotId') ||
          !_kinds.contains(kind) ||
          lot == null ||
          lot['productId'] != productId) {
        _fail('Invalid or duplicate stock movement.');
      }
      if ((['receipt', 'saleReturn'].contains(kind) && quantity <= 0) ||
          (['sale', 'count_out', 'transferReturn', 'purchaseReturn']
                  .contains(kind) &&
              quantity >= 0)) {
        _fail('Stock movement direction differs from its kind.');
      }
      _date(movement['date']);
      _actor(movement['actor']);
      _text(movement['requestId']);
      final cost = movement['costMinor'];
      if (lot['costStatus'] == 'unknown') {
        if (cost != null || movement['currency'] != null) {
          _fail('Unknown-cost movement has a cost amount.');
        }
      } else {
        if (cost is! int ||
            cost.abs() > Money.maxMinor ||
            (quantity > 0 && cost < 0) ||
            (quantity < 0 && cost > 0) ||
            movement['currency'] != lot['currency']) {
          _fail('Invalid stock movement cost.');
        }
      }
      if (lot['costStatus'] != 'unknown') {
        final amount = cost as int;
        if (kind == 'receipt' &&
            (amount != lot['costMinor'] ||
                !_equal(quantity, (lot['quantity'] as num).toDouble()))) {
          _fail('Receipt cost differs from its original lot total.');
        }
        if (quantity < 0 &&
            amount !=
                -FinishedStock.proportion(
                    costBalances[lotId]!, -quantity, balances[lotId]!)) {
          _fail('Issued stock cost differs from the remaining layer.');
        }
        if (kind == 'saleReturn') {
          final returns = _optionalRows(shop, 'sales')
              .where((d) => d['id'] == sourceId && d['stockTracked'] == true);
          if (returns.isNotEmpty) {
            final original = movements.where((m) =>
                m['kind'] == 'sale' &&
                m['sourceId'] == returns.single['reversalOf'] &&
                m['lotId'] == lotId &&
                m['productId'] == productId);
            if (original.length != 1 ||
                amount != -(original.single['costMinor'] as int)) {
              _fail(
                  'Returned stock cost differs from the original sale allocation.');
            }
          }
        }
        costBalances[lotId] = costBalances[lotId]! + amount;
        if (costBalances[lotId]! < 0 ||
            costBalances[lotId]! > (lot['costMinor'] as int)) {
          _fail('Stock lot cost balance is outside its original cost.');
        }
      }
      final remaining = balances[lotId]! + quantity;
      if (remaining < -_tolerance ||
          remaining > _number(lot['quantity']) + _tolerance) {
        _fail('Stock movement exceeds its lot balance.');
      }
      balances[lotId] = remaining;
      productMovements.update(productId, (value) => value + quantity,
          ifAbsent: () => quantity);
    }
    final totals = <String, double>{};
    for (final entry in lots.entries) {
      final balance = balances[entry.key]!;
      if (_equal(balance, 0) && (costBalances[entry.key] ?? 0) != 0) {
        _fail('An exhausted lot retains allocated cost.');
      }
      if (entry.value['status'] == 'returned' && !_equal(balance, 0)) {
        _fail('Returned lot retains stock.');
      }
      final productId = entry.value['productId'] as String;
      totals.update(productId, (value) => value + balance,
          ifAbsent: () => balance);
    }
    for (final entry in products.entries) {
      final quantity = _number(entry.value['quantity']);
      if (!_equal(totals[entry.key] ?? 0, quantity) ||
          !_equal(
              _number(stockBaseline[entry.key]) +
                  (productMovements[entry.key] ?? 0),
              quantity)) {
        _fail('Product balance does not reconcile with its lots and baseline.');
      }
    }
    _documents(shop, products, lots, movements);
  }

  static void pair(Map<String, dynamic> warehouse, Map<String, dynamic> shop) {
    validate(shop);
    if (warehouse['version'] != 13) _fail('Inventory upgrade is incomplete.');
    _masters(warehouse, 'materials');
    final purchases = {
      for (final document in _optionalRows(warehouse, 'purchases'))
        _text(document['id']): document,
    };
    final transfers = {
      for (final transfer in _optionalRows(warehouse, 'transfers'))
        _text(transfer['id']): transfer,
    };
    final batches = {
      for (final batch in _optionalRows(warehouse, 'batches'))
        _text(batch['id']): batch,
    };
    final lots = _rows(shop, 'stockLots');
    final movements = _rows(shop, 'stockMovements');
    for (final lot in lots) {
      if (lot['sourceKind'] == 'supplier_purchase') {
        final document = purchases[lot['sourceId']];
        if (document == null ||
            document['purchaseKind'] != 'trading' ||
            document['reversalOf'] != null) {
          _fail('Supplier lot has no original trading purchase.');
        }
        final lines = document['lines'] as List? ?? [document];
        final index = lot['sourceLine'] as int;
        if (index >= lines.length) _fail('Missing trading purchase line.');
        final line = _map(lines[index]);
        final quantity = _lineQuantity(line);
        if (line['itemId'] != lot['productId'] ||
            (line['stockUnit'] ?? line['unit']) != lot['unit'] ||
            !_equal(quantity, _number(lot['quantity'])) ||
            line['totalMinor'] != lot['costMinor'] ||
            lot['costStatus'] != 'confirmed' ||
            document['currency'] != lot['currency'] ||
            document['partyId'] != lot['supplierId']) {
          _fail('Supplier lot differs from its purchase snapshot.');
        }
        _matches(movements,
            sourceId: document['id'],
            kind: 'receipt',
            productId: lot['productId'],
            allocations: {lot['id']: quantity});
      } else if (lot['sourceKind'] == 'manufacturing') {
        final transfer = transfers[lot['id']];
        final batch = batches[lot['sourceId']];
        if (transfer == null ||
            transfer['reversalOf'] != null ||
            transfer['batchId'] != lot['sourceId'] ||
            batch == null ||
            batch['kind'] != 'production' ||
            transfer['productId'] != lot['productId'] ||
            transfer['unit'] != lot['unit'] ||
            !_equal(_number(transfer['quantity']), _number(lot['quantity'])) ||
            (transfer['expiry'] ?? '') != lot['expiry'] ||
            (transfer['lot'] ?? '') != lot['lot']) {
          _fail('Manufacturing lot differs from its production transfer.');
        }
        if (transfer['costMinor'] != null &&
            (transfer['costMinor'] != lot['costMinor'] ||
                transfer['costCurrency'] != lot['currency'])) {
          _fail('Manufacturing cost differs from its transfer snapshot.');
        }
      }
    }
    for (final document in purchases.values
        .where((document) => document['purchaseKind'] == 'trading')) {
      final lines = document['lines'] as List? ?? [document];
      for (var index = 0; index < lines.length; index++) {
        final line = _map(lines[index]);
        final originalId = document['reversalOf'] ?? document['id'];
        final matching = lots
            .where((lot) =>
                lot['sourceKind'] == 'supplier_purchase' &&
                lot['sourceId'] == originalId &&
                lot['sourceLine'] == index)
            .toList();
        if (matching.length != 1 ||
            matching.single['productId'] != line['itemId']) {
          _fail('Trading purchase has a missing or duplicated stock lot.');
        }
        if (document['reversalOf'] != null) {
          _matches(movements,
              sourceId: document['id'],
              kind: 'purchaseReturn',
              productId: line['itemId'],
              allocations: {matching.single['id']: -_lineQuantity(line)});
        }
      }
    }
    for (final order in _optionalRows(warehouse, 'orders')) {
      if (order['completion'] == null) continue;
      if (order['status'] != 'released') {
        _fail('Unreleased production has completion stock links.');
      }
      final completion = _map(order['completion']);
      final transfer = transfers[completion['transferId']];
      final batch = batches[order['batchId']];
      final matching =
          lots.where((lot) => lot['id'] == completion['lotId']).toList();
      if (transfer == null ||
          matching.length != 1 ||
          batch == null ||
          transfer['batchId'] != order['batchId'] ||
          transfer['productId'] != completion['productId'] ||
          matching.single['productId'] != completion['productId'] ||
          matching.single['sourceId'] != order['batchId'] ||
          completion['lotId'] != completion['transferId'] ||
          !_equal(_number(completion['actualQuantity'], positive: true),
              _number(batch['quantity'])) ||
          !_equal(_number(completion['actualQuantity']),
              _number(transfer['quantity'])) ||
          !_equal(_number(completion['actualQuantity']),
              _number(transfer['sourceQuantity'])) ||
          completion['unit'] != transfer['unit'] ||
          completion['unit'] != transfer['sourceUnit']) {
        _fail('Production completion links do not reconcile.');
      }
      if (completion['costMinor'] != matching.single['costMinor'] ||
          completion['costCurrency'] != matching.single['currency'] ||
          completion['costStatus'] != matching.single['costStatus']) {
        _fail('Production completion cost differs from its stock lot.');
      }
      _text(completion['requestId']);
      _text(completion['qualityNote']);
      _actor(completion['actor']);
      if (completion['varianceReason'] is! String ||
          _date(completion['completedAt']) != _date(batch['date'])) {
        _fail('Invalid production completion history.');
      }
      final actual = _map(completion['actualIngredients']);
      final materials = _map(batch['materials']);
      final links = _map(batch['materialIds']);
      final consumed = {
        for (final entry in materials.entries)
          _text(links[entry.key]): _number(entry.value, positive: true)
      };
      if (!_sameKeys(actual, consumed) ||
          actual.entries.any((entry) => !_equal(
              _number(entry.value, positive: true), consumed[entry.key]!))) {
        _fail('Completion ingredients differ from its production batch.');
      }
      _matches(movements,
          sourceId: batch['id'],
          kind: 'receipt',
          productId: completion['productId'],
          allocations: {
            matching.single['id']: _number(completion['actualQuantity'])
          });
    }
  }

  static void _documents(
      Map<String, dynamic> shop,
      Map<String, Map<String, dynamic>> products,
      Map<String, Map<String, dynamic>> lots,
      List<Map<String, dynamic>> movements) {
    final sales = _optionalRows(shop, 'sales');
    final reversed = {
      for (final document in sales)
        if (document['reversalOf'] != null) document['reversalOf'],
    };
    final checkedMovements = <String>{};
    final bridgedReturns = <String>{};
    for (final document in sales) {
      if (document['stockTracked'] != true) {
        if (document['reversalOf'] == null ||
            !movements
                .any((movement) => movement['sourceId'] == document['id'])) {
          continue;
        }
        final originals = sales
            .where((original) =>
                original['id'] == document['reversalOf'] &&
                original['stockTracked'] != true &&
                original['reversalOf'] == null)
            .toList();
        if (originals.length != 1) {
          _fail('Legacy stock return has no untracked original sale.');
        }
        final id = _text(document['id']);
        bridgedReturns.add(id);
        for (final raw in document['lines'] as List? ?? [document]) {
          final line = _map(raw);
          final productId = _text(line['itemId']);
          final quantity = _lineQuantity(line);
          final allocations = _allocations(line['lots'] ?? {}, lots, productId);
          final allocated =
              allocations.values.fold(0.0, (sum, value) => sum + value);
          if (allocated > quantity + _tolerance) {
            _fail('Legacy return allocations exceed its original quantity.');
          }
          _matches(movements,
              sourceId: id,
              kind: 'saleReturn',
              productId: productId,
              allocations: allocations,
              checked: checkedMovements);
          final missing = quantity - allocated;
          final openings = lots.values
              .where((lot) =>
                  lot['sourceId'] == id &&
                  lot['productId'] == productId &&
                  lot['sourceKind'] == 'legacy_opening')
              .toList();
          final receipts = <String, double>{};
          if (missing > _tolerance) {
            if (openings.length != 1 ||
                openings.single['costStatus'] != 'unknown' ||
                !_equal(_number(openings.single['quantity']), missing)) {
              _fail(
                  'Untraced legacy return has no matching unknown opening lot.');
            }
            receipts[openings.single['id']] = missing;
          } else if (openings.isNotEmpty) {
            _fail('Legacy return created an extra opening lot.');
          }
          _matches(movements,
              sourceId: id,
              kind: 'receipt',
              productId: productId,
              allocations: receipts,
              checked: checkedMovements);
        }
        continue;
      }
      final id = _text(document['id']);
      final returned = document['reversalOf'] != null;
      final kind = returned ? 'saleReturn' : 'sale';
      final direction = returned ? 1.0 : -1.0;
      final date =
          _date(document['date']).toUtc().toIso8601String().substring(0, 10);
      for (final raw in document['lines'] as List? ?? [document]) {
        final line = _map(raw);
        final productId = _text(line['itemId']);
        final product = products[productId];
        final quantity = _lineQuantity(line);
        if (product == null ||
            (line['stockUnit'] ?? line['unit']) != product['unit']) {
          _fail('Tracked sale product or base unit is missing.');
        }
        final allocations = _allocations(line['lots'], lots, productId);
        if (!_equal(allocations.values.fold(0.0, (sum, value) => sum + value),
            quantity)) {
          _fail('Tracked sale quantity is not fully allocated.');
        }
        if (!returned && !reversed.contains(id)) {
          for (final lotId in allocations.keys) {
            final lot = lots[lotId]!;
            if (lot['status'] != 'available' ||
                (lot['expiry'] != '' &&
                    (lot['expiry'] as String).compareTo(date) <= 0)) {
              _fail('Tracked sale uses a held, returned or expired lot.');
            }
          }
        }
        _matches(movements,
            sourceId: id,
            kind: kind,
            productId: productId,
            allocations: {
              for (final e in allocations.entries) e.key: direction * e.value
            },
            checked: checkedMovements);
      }
    }
    final trackedCounts = <String>{};
    for (final count in _optionalRows(shop, 'counts')) {
      if (count['stockTracked'] != true) continue;
      final id = _text(count['id']);
      trackedCounts.add(id);
      final productId = _text(count['itemId']);
      if (!products.containsKey(productId)) _fail('Count product is missing.');
      final difference = _number(count['after']) - _number(count['before']);
      if (difference < 0) {
        final allocations = _allocations(count['lots'], lots, productId);
        if (!_equal(allocations.values.fold(0.0, (sum, value) => sum + value),
            -difference)) {
          _fail('Stock count shortage is not fully allocated.');
        }
        _matches(movements,
            sourceId: id,
            kind: 'count_out',
            productId: productId,
            allocations: {for (final e in allocations.entries) e.key: -e.value},
            checked: checkedMovements);
      } else if (difference > 0) {
        final receipts = movements.where((movement) =>
            movement['sourceId'] == id &&
            movement['productId'] == productId &&
            movement['kind'] == 'receipt');
        if (!_equal(
            receipts.fold(
                0.0, (sum, movement) => sum + _signed(movement['quantity'])),
            difference)) {
          _fail('Stock count increase has no matching receipt.');
        }
        checkedMovements
            .addAll(receipts.map((movement) => movement['id'] as String));
      } else {
        _fail('Tracked stock count has no change.');
      }
    }
    for (final movement in movements) {
      if (['sale', 'saleReturn'].contains(movement['kind']) &&
          !checkedMovements.contains(movement['id'])) {
        _fail('Sale movement has no tracked source document.');
      }
      if (movement['kind'] == 'count_out' &&
          !checkedMovements.contains(movement['id'])) {
        _fail('Count movement has no tracked source document.');
      }
      if ((bridgedReturns.contains(movement['sourceId']) ||
              trackedCounts.contains(movement['sourceId'])) &&
          !checkedMovements.contains(movement['id'])) {
        _fail('Stock movement is not represented in its source document.');
      }
    }
  }

  static Map<String, double> _allocations(
      dynamic value, Map<String, Map<String, dynamic>> lots, String productId) {
    final result = <String, double>{};
    for (final entry in _map(value).entries) {
      final lot = lots[entry.key];
      if (lot == null || lot['productId'] != productId) {
        _fail('Allocation refers to another product or a missing lot.');
      }
      result[entry.key] = _number(entry.value, positive: true);
    }
    return result;
  }

  static void _matches(List<Map<String, dynamic>> movements,
      {required String sourceId,
      required String kind,
      required String productId,
      required Map<String, double> allocations,
      Set<String>? checked}) {
    final matching = movements
        .where((movement) =>
            movement['sourceId'] == sourceId &&
            movement['kind'] == kind &&
            movement['productId'] == productId)
        .toList();
    if (matching.length != allocations.length) {
      _fail('Document and stock movement count differ.');
    }
    for (final entry in allocations.entries) {
      final rows =
          matching.where((movement) => movement['lotId'] == entry.key).toList();
      if (rows.length != 1 ||
          !_equal(_signed(rows.single['quantity']), entry.value)) {
        _fail('Document allocation differs from its stock movement.');
      }
      checked?.add(rows.single['id'] as String);
    }
  }

  static double _lineQuantity(Map<String, dynamic> line) {
    final entered = _number(line['quantity'], positive: true);
    final base = _number(line['stockQuantity'] ?? entered, positive: true);
    final conversion = line['conversion'];
    if (conversion == null) {
      if (!_equal(entered, base) ||
          (line['stockUnit'] != null && line['stockUnit'] != line['unit'])) {
        _fail('Converted stock line has no immutable conversion snapshot.');
      }
      return base;
    }
    final snapshot = _map(conversion);
    final numerator = _integer(snapshot['factorNumerator'],
        minimum: 1, maximum: InventoryUnits.maxFactorPart);
    final denominator = _integer(snapshot['factorDenominator'],
        minimum: 1, maximum: InventoryUnits.maxFactorPart);
    _integer(snapshot['revision'],
        minimum: 1, maximum: InventoryUnits.maxFactorPart);
    _text(snapshot['conversionId']);
    if (snapshot['inputUnit'] != line['unit'] ||
        snapshot['baseUnit'] != (line['stockUnit'] ?? line['unit']) ||
        !_equal(_number(snapshot['inputQuantity'], positive: true), entered) ||
        !_equal(_number(snapshot['baseQuantity'], positive: true), base)) {
      _fail('Conversion snapshot differs from its document line.');
    }
    try {
      Money.total(entered, 0);
      Money.total(base, 0);
    } on ArgumentError {
      _fail('Invalid converted stock quantity precision.');
    }
    final enteredMicro =
        BigInt.parse(entered.toStringAsFixed(6).replaceAll('.', ''));
    final baseMicro = BigInt.parse(base.toStringAsFixed(6).replaceAll('.', ''));
    if (enteredMicro * BigInt.from(numerator) !=
        baseMicro * BigInt.from(denominator)) {
      _fail('Conversion snapshot arithmetic does not reconcile.');
    }
    return base;
  }

  static Map<String, Map<String, dynamic>> _masters(
      Map<String, dynamic> state, String key) {
    final result = <String, Map<String, dynamic>>{};
    final skus = <String>{};
    for (final row in _rows(state, key)) {
      final id = _text(row['id']);
      if (result.containsKey(id) || !skus.add(_text(row['sku']))) {
        _fail('Duplicate stock identity or SKU.');
      }
      if (row['unit'] is! String) _fail('Invalid stock base unit.');
      final conversions = _rows(row, 'unitConversions');
      if ((row['unit'] as String).trim().isEmpty && conversions.isNotEmpty) {
        _fail('Unresolved stock base unit has conversions.');
      }
      if ((row['unit'] as String).trim().isNotEmpty) {
        try {
          InventoryUnits.validateConversions(row['unit'], conversions);
        } on ArgumentError {
          _fail('Invalid stock unit conversions.');
        }
      }
      _number(row['quantity']);
      result[id] = row;
    }
    return result;
  }

  static void _cost(Map<String, dynamic> lot) {
    if (lot['costStatus'] == 'unknown') {
      if (lot['costMinor'] != null || lot['currency'] != null) {
        _fail('Unknown lot cost must remain absent.');
      }
    } else if (['confirmed', 'estimated'].contains(lot['costStatus'])) {
      _integer(lot['costMinor'], minimum: 0, maximum: Money.maxMinor);
      if (!Money.currencies.contains(lot['currency'])) {
        _fail('Invalid cost currency.');
      }
    } else {
      _fail('Invalid cost status.');
    }
  }

  static List<Map<String, dynamic>> _rows(
      Map<String, dynamic> state, String key) {
    final value = state[key];
    if (value is! List) _fail('Missing stock list: $key.');
    return value.map(_map).toList();
  }

  static List<Map<String, dynamic>> _optionalRows(
          Map<String, dynamic> state, String key) =>
      state[key] == null ? [] : _rows(state, key);
  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      _fail('Invalid stock object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static String _text(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      _fail('Missing stock identifier.');
    }
    return value;
  }

  static double _number(dynamic value, {bool positive = false}) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        (positive && value == 0)) {
      _fail('Invalid stock quantity.');
    }
    return value.toDouble();
  }

  static double _signed(dynamic value) {
    if (value is! num || !value.isFinite || value == 0) {
      _fail('Invalid stock movement quantity.');
    }
    return value.toDouble();
  }

  static int _integer(dynamic value, {required int minimum, int? maximum}) {
    if (value is! int ||
        value < minimum ||
        (maximum != null && value > maximum)) {
      _fail('Invalid stock integer.');
    }
    return value;
  }

  static DateTime _date(dynamic value) {
    if (value is! String) _fail('Invalid stock date.');
    final date = DateTime.tryParse(value);
    if (date == null) _fail('Invalid stock date.');
    return date;
  }

  static void _expiry(dynamic value) {
    if (value == '') return;
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        _date(value).toIso8601String().substring(0, 10) != value) {
      _fail('Invalid stock expiry.');
    }
  }

  static void _actor(dynamic value) {
    final actor = _map(value);
    _text(actor['id']);
    _text(actor['name']);
    if (![
      'legacy',
      'owner',
      'manager',
      'accountant',
      'warehouse',
      'cashier',
      'viewer'
    ].contains(actor['role'])) {
      _fail('Invalid stock actor role.');
    }
  }

  static bool _sameKeys(Map left, Map right) =>
      left.length == right.length && left.keys.every(right.containsKey);
  static bool _equal(double left, double right) =>
      (left - right).abs() <= _tolerance;
  static Never _fail(String message) => throw FormatException(message);
}
