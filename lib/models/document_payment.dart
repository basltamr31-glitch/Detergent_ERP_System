import '../services/access_control.dart';
import '../services/record_id.dart';

/// An immutable allocation in the referenced document's currency.
class DocumentPayment {
  DocumentPayment(
      {String? id,
      required this.documentId,
      required this.amountMinor,
      required this.date,
      required this.requestId,
      this.reference = '',
      this.kind = 'payment',
      this.reason = '',
      Map<String, String>? actor})
      : actor = Map.unmodifiable(actor ?? AccessControl.actor),
        id = id ?? RecordId.create();
  final String id, documentId, requestId, reference, kind, reason;
  final Map<String, String> actor;
  final int amountMinor;
  final DateTime date;
  Map<String, dynamic> toJson() => {
        'id': id,
        'actor': actor,
        'documentId': documentId,
        'amountMinor': amountMinor,
        'date': date.toIso8601String(),
        'requestId': requestId,
        'reference': reference,
        'kind': kind,
        'reason': reason
      };
  factory DocumentPayment.fromJson(Map<String, dynamic> data) =>
      DocumentPayment(
          id: data['id'],
          actor: Map<String, String>.from(data['actor'] ??
              {'id': 'legacy', 'name': 'Legacy record', 'role': 'legacy'}),
          documentId: data['documentId'],
          amountMinor: data['amountMinor'],
          date: DateTime.parse(data['date']),
          requestId: data['requestId'],
          reference: data['reference'],
          kind: data['kind'] ?? 'payment',
          reason: data['reason'] ?? '');
}
