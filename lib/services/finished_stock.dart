import '../services/record_id.dart';
import 'accounting.dart';
import 'money.dart';

/// Operations on a candidate snapshot. The caller validates and commits it.
class FinishedStock {
  static List<Map<String, dynamic>> lots(Map<String, dynamic> state) =>
      (state['stockLots'] as List).cast<Map<String, dynamic>>();

  static double balance(Map<String, dynamic> state, String lotId) {
    var value = ((state['lotBaseline'] as Map)[lotId] as num? ?? 0).toDouble();
    for (final m in state['stockMovements'] as List) {
      if (m['lotId'] == lotId) value += (m['quantity'] as num).toDouble();
    }
    return double.parse(value.toStringAsFixed(6));
  }

  static Map<String, dynamic> ensureProduct(Map<String, dynamic> state,
      {String? productId,
      required String name,
      required String unit,
      String? sku,
      double salePrice = 0}) {
    final products = state['products'] as List;
    final matches = products.where((p) =>
        productId != null ? p['id'] == productId : p['name'] == name.trim());
    if (matches.isNotEmpty) {
      final p = matches.single as Map<String, dynamic>;
      if (p['unit'] != unit) throw ArgumentError('Use the product base unit.');
      return p;
    }
    if (productId != null) throw StateError('Product not found.');
    if (name.trim().isEmpty || unit.trim().isEmpty) {
      throw ArgumentError('Product name and unit are required.');
    }
    final id = RecordId.create();
    final code = (sku == null || sku.trim().isEmpty) ? 'SKU-$id' : sku.trim();
    if (products.any((p) => p['sku'] == code)) {
      throw ArgumentError('Product SKU must be unique.');
    }
    final product = <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'quantity': 0.0,
      'unit': unit,
      'price': salePrice,
      'sku': code,
      'unitConversions': <Map<String, dynamic>>[]
    };
    products.add(product);
    (state['stockBaseline'] as Map)[id] = 0.0;
    return product;
  }

  static void receive(Map<String, dynamic> state,
      {required String lotId,
      required String productId,
      required String sourceKind,
      required String sourceId,
      required double quantity,
      required String unit,
      required String date,
      String lot = '',
      String expiry = '',
      String? supplierId,
      int sourceLine = 0,
      int? costMinor,
      String? currency,
      String costStatus = 'unknown',
      String costReference = '',
      required Map<String, String> actor,
      required String requestId}) {
    Money.total(quantity, 0);
    if (lots(state).any((l) => l['id'] == lotId)) {
      throw StateError('Stock lot already received.');
    }
    if (!['unknown', 'estimated', 'confirmed'].contains(costStatus) ||
        (costStatus == 'unknown' && (costMinor != null || currency != null)) ||
        (costStatus != 'unknown' &&
            (costMinor == null ||
                costMinor < 0 ||
                costMinor > Money.maxMinor ||
                !Money.currencies.contains(currency)))) {
      throw ArgumentError('Use explicit valid total cost and currency.');
    }
    final product =
        (state['products'] as List).firstWhere((p) => p['id'] == productId);
    if (product['unit'] != unit) {
      throw ArgumentError('Receipt unit differs from product base unit.');
    }
    lots(state).add({
      'id': lotId,
      'productId': productId,
      'sourceKind': sourceKind,
      'sourceId': sourceId,
      'sourceLine': sourceLine,
      'quantity': quantity,
      'unit': unit,
      'receivedAt': date,
      'expiry': expiry,
      'lot': lot,
      'status': 'available',
      'costStatus': costStatus,
      'costMinor': costMinor,
      'currency': currency,
      'supplierId': supplierId,
      'costReference': costReference,
      'actor': actor
    });
    (state['lotBaseline'] as Map)[lotId] = 0.0;
    record(state,
        productId: productId,
        sourceId: sourceId,
        kind: 'receipt',
        allocations: {lotId: quantity},
        date: date,
        actor: actor,
        requestId: requestId);
    product['quantity'] = ((product['quantity'] as num).toDouble() + quantity);
  }

  static Map<String, double> allocate(
      Map<String, dynamic> state, String productId, double quantity,
      {bool includeExpired = false}) {
    Money.total(quantity, 0);
    var remaining = quantity;
    final result = <String, double>{};
    for (final l in lots(state).where((l) => l['productId'] == productId)) {
      if (l['status'] != 'available' ||
          (!includeExpired &&
              (l['expiry'] as String).isNotEmpty &&
              (l['expiry'] as String).compareTo(Accounting.today()) <= 0)) {
        continue;
      }
      final available = balance(state, l['id']);
      final take = remaining < available ? remaining : available;
      if (take > 0) {
        result[l['id']] = take;
        remaining = double.parse((remaining - take).toStringAsFixed(6));
      }
      if (remaining <= 0) break;
    }
    if (remaining > 0.0000001) {
      throw StateError('Insufficient eligible stock lots.');
    }
    return result;
  }

  /// Allocate integer minor units without floating-point money rounding.
  static int proportion(int total, double part, double whole) {
    if (part == 0) return 0;
    if (whole <= 0) throw StateError('No stock balance for cost allocation.');
    final numerator = BigInt.parse(part.toStringAsFixed(6).replaceAll('.', ''));
    final denominator =
        BigInt.parse(whole.toStringAsFixed(6).replaceAll('.', ''));
    return ((BigInt.from(total) * numerator + denominator ~/ BigInt.two) ~/
            denominator)
        .toInt();
  }

  static void record(Map<String, dynamic> state,
      {required String productId,
      required String sourceId,
      required String kind,
      required Map<String, double> allocations,
      required String date,
      required Map<String, String> actor,
      required String requestId,
      int direction = 1,
      Map<String, int?> costOverrides = const {}}) {
    for (final e in allocations.entries) {
      final l = lots(state).firstWhere((l) => l['id'] == e.key);
      int? cost;
      if (l['costMinor'] != null) {
        if (kind == 'receipt') {
          cost = l['costMinor'] as int;
        } else if (costOverrides.containsKey(e.key)) {
          cost = costOverrides[e.key];
        } else {
          var remainingCost = proportion(
              l['costMinor'] as int,
              ((state['lotBaseline'] as Map)[e.key] as num).toDouble(),
              (l['quantity'] as num).toDouble());
          for (final movement in state['stockMovements'] as List) {
            if (movement['lotId'] == e.key) {
              remainingCost += (movement['costMinor'] as int? ?? 0);
            }
          }
          cost = direction *
              proportion(remainingCost, e.value, balance(state, e.key));
        }
      }
      (state['stockMovements'] as List).add({
        'id': RecordId.create(),
        'productId': productId,
        'lotId': e.key,
        'sourceId': sourceId,
        'kind': kind,
        'quantity': direction * e.value,
        'date': date,
        'actor': actor,
        'requestId': requestId,
        'costMinor': cost,
        'currency': l['currency']
      });
    }
  }
}
