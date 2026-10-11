import '../services/access_control.dart';

class StockTransfer {
  StockTransfer(
      {required this.id,
      required this.number,
      required this.batchId,
      required this.sourceQuantity,
      required this.sourceUnit,
      required this.productId,
      required this.productName,
      required this.quantity,
      required this.unit,
      required this.date,
      required this.requestId,
      required this.unitPriceMinor,
      required this.currency,
      this.reversalOf,
      this.reason = '',
      this.lot = '',
      this.expiry = '',
      Map<String, String>? actor})
      : actor = Map.unmodifiable(actor ?? AccessControl.actor);
  final String id,
      number,
      batchId,
      sourceUnit,
      productId,
      productName,
      unit,
      requestId,
      currency,
      reason;
  final String lot, expiry;
  final double sourceQuantity, quantity;
  final int unitPriceMinor;
  final Map<String, String> actor;
  final DateTime date;
  final String? reversalOf;
  Map<String, dynamic> toJson() => {
        'id': id,
        'actor': actor,
        'number': number,
        'batchId': batchId,
        'lot': lot,
        'expiry': expiry,
        'sourceQuantity': sourceQuantity,
        'sourceUnit': sourceUnit,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'date': date.toIso8601String(),
        'requestId': requestId,
        'unitPriceMinor': unitPriceMinor,
        'currency': currency,
        'reversalOf': reversalOf,
        'reason': reason
      };
  factory StockTransfer.fromJson(Map<String, dynamic> d) => StockTransfer(
      id: d['id'],
      actor: Map<String, String>.from(d['actor'] ??
          {'id': 'legacy', 'name': 'Legacy record', 'role': 'legacy'}),
      number: d['number'],
      batchId: d['batchId'],
      lot: d['lot'] ?? '',
      expiry: d['expiry'] ?? '',
      sourceQuantity: (d['sourceQuantity'] as num).toDouble(),
      sourceUnit: d['sourceUnit'],
      productId: d['productId'],
      productName: d['productName'],
      quantity: (d['quantity'] as num).toDouble(),
      unit: d['unit'],
      date: DateTime.parse(d['date']),
      requestId: d['requestId'],
      unitPriceMinor: d['unitPriceMinor'],
      currency: d['currency'],
      reversalOf: d['reversalOf'],
      reason: d['reason']);
}
