import '../services/access_control.dart';
import 'trade_line.dart';
import '../services/money.dart';
import '../services/record_id.dart';

class TradeDocument {
  TradeDocument(
      {String? id,
      required this.number,
      required this.type,
      required this.date,
      required this.party,
      required this.currency,
      required this.itemId,
      required this.itemName,
      required this.unit,
      required this.quantity,
      required this.unitPriceMinor,
      required this.totalMinor,
      this.paidMinor = 0,
      this.reversalOf,
      this.partyId,
      this.reason = '',
      this.reference = '',
      required this.requestId,
      List<TradeLine>? lines,
      Map<String, String>? actor})
      : actor = Map.unmodifiable(actor ?? AccessControl.actor),
        id = id ?? RecordId.create(),
        lines = List.unmodifiable(lines ??
            [
              TradeLine(
                  itemId: itemId,
                  itemName: itemName,
                  unit: unit,
                  quantity: quantity,
                  unitPriceMinor: unitPriceMinor)
            ]);
  final String id,
      number,
      type,
      party,
      currency,
      itemId,
      itemName,
      unit,
      reason,
      reference,
      requestId;
  final Map<String, String> actor;
  final List<TradeLine> lines;
  final DateTime date;
  final double quantity;
  final int unitPriceMinor, totalMinor, paidMinor;
  final String? reversalOf, partyId;
  int get outstandingMinor => totalMinor - paidMinor;
  String get amount => '${Money.format(totalMinor)} $currency';
  Map<String, dynamic> toJson() => {
        'id': id,
        'actor': actor,
        'lines': lines.map((l) => l.toJson()).toList(),
        'number': number,
        'type': type,
        'date': date.toIso8601String(),
        'party': party,
        'partyId': partyId,
        'currency': currency,
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'quantity': quantity,
        'unitPriceMinor': unitPriceMinor,
        'totalMinor': totalMinor,
        'paidMinor': paidMinor,
        'reversalOf': reversalOf,
        'reason': reason,
        'reference': reference,
        'requestId': requestId
      };
  factory TradeDocument.fromJson(Map<String, dynamic> data) => TradeDocument(
      id: data['id'],
      actor: Map<String, String>.from(data['actor'] ??
          {'id': 'legacy', 'name': 'Legacy record', 'role': 'legacy'}),
      lines: (data['lines'] as List?)
          ?.map((l) => TradeLine.fromJson(Map<String, dynamic>.from(l)))
          .toList(),
      number: data['number'],
      type: data['type'],
      date: DateTime.parse(data['date']),
      party: data['party'],
      partyId: data['partyId'],
      currency: data['currency'],
      itemId: data['itemId'],
      itemName: data['itemName'],
      unit: data['unit'],
      quantity: (data['quantity'] as num).toDouble(),
      unitPriceMinor: data['unitPriceMinor'],
      totalMinor: data['totalMinor'],
      paidMinor: data['paidMinor'],
      reversalOf: data['reversalOf'],
      reason: data['reason'],
      reference: data['reference'],
      requestId: data['requestId']);
}
