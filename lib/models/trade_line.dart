import '../services/money.dart';

class TradeLine {
  TradeLine(
      {required this.itemId,
      required this.itemName,
      required this.unit,
      required this.quantity,
      required this.unitPriceMinor,
      Map<String, double> lots = const {}})
      : lots = Map.unmodifiable(lots);
  final Map<String, double> lots;
  final String itemId, itemName, unit;
  final double quantity;
  final int unitPriceMinor;
  int get totalMinor => Money.total(quantity, unitPriceMinor);
  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'quantity': quantity,
        'unitPriceMinor': unitPriceMinor,
        'totalMinor': totalMinor,
        'lots': lots
      };
  factory TradeLine.fromJson(Map<String, dynamic> data) => TradeLine(
      itemId: data['itemId'],
      itemName: data['itemName'],
      unit: data['unit'],
      quantity: (data['quantity'] as num).toDouble(),
      unitPriceMinor: data['unitPriceMinor'],
      lots: (data['lots'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
}

class TradeInput {
  const TradeInput(
      {required this.name,
      required this.quantity,
      required this.unitPriceMinor,
      this.unit = ''});
  final String name, unit;
  final double quantity;
  final int unitPriceMinor;
}
