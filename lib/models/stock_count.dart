import '../services/access_control.dart';
import '../services/record_id.dart';

class StockCount {
  StockCount(
      {String? id,
      required this.itemId,
      required this.before,
      required this.after,
      required this.reason,
      required this.date,
      required this.requestId,
      Map<String, String>? actor,
      Map<String, double> lots = const {}})
      : lots = Map.unmodifiable(lots),
        id = id ?? RecordId.create(),
        actor = Map.unmodifiable(actor ?? AccessControl.actor);
  final Map<String, double> lots;
  final String id, itemId, reason, requestId;
  final double before, after;
  final DateTime date;
  final Map<String, String> actor;
  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'before': before,
        'after': after,
        'reason': reason,
        'date': date.toIso8601String(),
        'requestId': requestId,
        'actor': actor,
        'lots': lots
      };
  factory StockCount.fromJson(Map<String, dynamic> d) => StockCount(
      id: d['id'],
      lots: (d['lots'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      itemId: d['itemId'],
      before: (d['before'] as num).toDouble(),
      after: (d['after'] as num).toDouble(),
      reason: d['reason'],
      date: DateTime.parse(d['date']),
      requestId: d['requestId'],
      actor: Map<String, String>.from(d['actor']));
}
