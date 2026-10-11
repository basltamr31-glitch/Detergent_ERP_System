import '../services/access_control.dart';
import '../services/record_id.dart';
import 'trade_document.dart';
import 'document_payment.dart';

class JournalLine {
  const JournalLine(this.account, {this.debit = 0, this.credit = 0});
  final String account;
  final int debit, credit;
  Map<String, dynamic> toJson() =>
      {'account': account, 'debit': debit, 'credit': credit};
}

class JournalEntry {
  JournalEntry(
      {String? id,
      required this.sourceId,
      required this.kind,
      required this.date,
      required this.currency,
      required this.reference,
      required List<JournalLine> lines,
      Map<String, String>? actor})
      : actor = Map.unmodifiable(actor ?? AccessControl.actor),
        id = id ?? RecordId.create(),
        lines = List.unmodifiable(lines);
  final String id, sourceId, kind, currency, reference;
  final DateTime date;
  final Map<String, String> actor;
  final List<JournalLine> lines;
  static const accounts = {
    '1000': 'Cash / settlement',
    '1100': 'Receivables',
    '1200': 'Inventory opening / manual valuation',
    '2000': 'Payables',
    '3000': 'Equity / opening balance',
    '4000': 'Sales',
    '4010': 'Sales returns',
    '5000': 'Purchases',
    '5010': 'Purchase returns',
    '5100': 'Operating expenses'
  };
  Map<String, dynamic> toJson() => {
        'id': id,
        'actor': actor,
        'sourceId': sourceId,
        'kind': kind,
        'date': date.toIso8601String(),
        'currency': currency,
        'reference': reference,
        'lines': lines.map((l) => l.toJson()).toList()
      };
  factory JournalEntry.fromJson(Map<String, dynamic> d) => JournalEntry(
      id: d['id'],
      actor: Map<String, String>.from(d['actor'] ??
          {'id': 'legacy', 'name': 'Legacy record', 'role': 'legacy'}),
      sourceId: d['sourceId'],
      kind: d['kind'],
      date: DateTime.parse(d['date']),
      currency: d['currency'],
      reference: d['reference'],
      lines: (d['lines'] as List)
          .map((l) =>
              JournalLine(l['account'], debit: l['debit'], credit: l['credit']))
          .toList());
  factory JournalEntry.trade(TradeDocument d) {
    final List<JournalLine> lines;
    if (d.type == 'sale') {
      lines = [
        if (d.paidMinor > 0) JournalLine('1000', debit: d.paidMinor),
        JournalLine('1100', debit: d.outstandingMinor),
        JournalLine('4000', credit: d.totalMinor)
      ];
    } else if (d.type == 'purchase') {
      lines = [
        JournalLine('5000', debit: d.totalMinor),
        if (d.paidMinor > 0) JournalLine('1000', credit: d.paidMinor),
        JournalLine('2000', credit: d.outstandingMinor)
      ];
    } else if (d.type == 'saleReturn') {
      lines = [
        JournalLine('4010', debit: d.totalMinor),
        JournalLine('1100', credit: d.totalMinor)
      ];
    } else {
      lines = [
        JournalLine('2000', debit: d.totalMinor),
        JournalLine('5010', credit: d.totalMinor)
      ];
    }
    return JournalEntry(
        actor: d.actor,
        sourceId: d.id,
        kind: 'trade',
        date: d.date,
        currency: d.currency,
        reference: d.number,
        lines: lines);
  }
  factory JournalEntry.payment(DocumentPayment p, TradeDocument d) {
    final sale = d.type == 'sale';
    final cashDebit = sale != (p.kind == 'refund');
    final control = sale ? '1100' : '2000';
    return JournalEntry(
        actor: p.actor,
        sourceId: p.id,
        kind: 'payment',
        date: p.date,
        currency: d.currency,
        reference: '${d.number} ${p.reference} ${p.reason}',
        lines: [
          JournalLine('1000',
              debit: cashDebit ? p.amountMinor : 0,
              credit: cashDebit ? 0 : p.amountMinor),
          JournalLine(control,
              debit: cashDebit ? 0 : p.amountMinor,
              credit: cashDebit ? p.amountMinor : 0)
        ]);
  }
}
