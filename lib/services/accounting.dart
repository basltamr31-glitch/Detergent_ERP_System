import '../models/journal_entry.dart';
import 'money.dart';

class Accounting {
  static void validate(JournalEntry entry) {
    if (!Money.currencies.contains(entry.currency) ||
        entry.lines.length < 2 ||
        !['trade', 'payment', 'manual'].contains(entry.kind)) {
      throw const FormatException('Invalid journal.');
    }
    BigInt debits = BigInt.zero, credits = BigInt.zero;
    for (final line in entry.lines) {
      if (!JournalEntry.accounts.containsKey(line.account) ||
          line.debit < 0 ||
          line.credit < 0 ||
          line.debit > Money.maxMinor ||
          line.credit > Money.maxMinor ||
          (line.debit > 0 && line.credit > 0)) {
        throw const FormatException('Invalid journal line.');
      }
      debits += BigInt.from(line.debit);
      credits += BigInt.from(line.credit);
    }
    if (debits != credits || debits > BigInt.from(Money.maxMinor)) {
      throw const FormatException('Journal is not balanced.');
    }
  }

  static DateTime Function() clock = DateTime.now;
  static String today() => clock().toUtc().toIso8601String().substring(0, 10);
  static void checkPeriod(String? closedThrough) {
    if (closedThrough != null && today().compareTo(closedThrough) <= 0) {
      throw StateError('This accounting period is closed.');
    }
  }
}
