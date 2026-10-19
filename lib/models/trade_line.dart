import '../services/money.dart';

class TradeLine {
  TradeLine(
      {required this.itemId,
      required this.itemName,
      required this.unit,
      required this.quantity,
      required this.unitPriceMinor,
      this.stockQuantity,
      this.stockUnit,
      this.conversion,
      Map<String, double> lots = const {}})
      : lots = Map.unmodifiable(lots);
  final Map<String, double> lots;
  final String itemId, itemName, unit;
  final double quantity;
  final double? stockQuantity;
  final String? stockUnit;
  final Map<String, dynamic>? conversion;
  double get baseQuantity => stockQuantity ?? quantity;
  String get baseUnit => stockUnit ?? unit;
  final int unitPriceMinor;
  int get totalMinor => Money.total(quantity, unitPriceMinor);
  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'quantity': quantity,
        'unitPriceMinor': unitPriceMinor,
        'totalMinor': totalMinor,
        'lots': lots,
        if (stockQuantity != null) 'stockQuantity': stockQuantity,
        if (stockUnit != null) 'stockUnit': stockUnit,
        if (conversion != null) 'conversion': conversion
      };
  factory TradeLine.fromJson(Map<String, dynamic> data) => TradeLine(
      itemId: data['itemId'],
      itemName: data['itemName'],
      unit: data['unit'],
      quantity: (data['quantity'] as num).toDouble(),
      unitPriceMinor: data['unitPriceMinor'],
      stockQuantity: (data['stockQuantity'] as num?)?.toDouble(),
      stockUnit: data['stockUnit'],
      conversion: data['conversion'] == null
          ? null
          : Map<String, dynamic>.from(data['conversion']),
      lots: (data['lots'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
}

class TradeInput {
  const TradeInput(
      {required this.name,
      required this.quantity,
      required this.unitPriceMinor,
      this.itemId,
      this.unit = ''});
  final String name, unit;
  final String? itemId;
  final double quantity;

  final int unitPriceMinor;
}
