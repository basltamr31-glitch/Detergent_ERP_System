import '../models/journal_entry.dart';

class FinanceSummary {
  FinanceSummary(Iterable<JournalEntry> journals, this.currency,
      {required this.documentReceivables, required this.documentPayables}) {
    final totals = <String, int>{};
    for (final journal in journals.where((j) => j.currency == currency)) {
      for (final line in journal.lines) {
        totals.update(line.account, (value) => value + line.debit - line.credit,
            ifAbsent: () => line.debit - line.credit);
      }
    }
    balances = Map.unmodifiable(totals);
  }
  final String currency;
  final int documentReceivables, documentPayables;
  late final Map<String, int> balances;
  int get cash => balances['1000'] ?? 0;
  int get receivables => balances['1100'] ?? 0;
  int get payables => -(balances['2000'] ?? 0);
  int get receivableDifference => receivables - documentReceivables;
  int get payableDifference => payables - documentPayables;
  int get trialDifference =>
      balances.values.fold(0, (sum, value) => sum + value);
  bool get reconciled =>
      trialDifference == 0 &&
      receivableDifference == 0 &&
      payableDifference == 0;
}
