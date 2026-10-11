import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journal_entry.dart';
import '../providers/shop_provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/finance_service.dart';
import '../services/finance_summary.dart';
import '../services/access_control.dart';
import '../services/inventory_coordinator.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../widgets/storage_status.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _currency = 'USD';
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String accountName(String code) => t(
      JournalEntry.accounts[code]!,
      switch (code) {
        '1000' => 'النقدية / التسوية',
        '1100' => 'الذمم المدينة',
        '1200' => 'المخزون الافتتاحي / التقييم اليدوي',
        '2000' => 'الذمم الدائنة',
        '3000' => 'حقوق الملكية / الرصيد الافتتاحي',
        '4000' => 'المبيعات',
        '4010' => 'مردودات المبيعات',
        '5000' => 'المشتريات',
        '5010' => 'مردودات المشتريات',
        _ => 'مصاريف التشغيل'
      });
  Future<void> _journal() async {
    final warehouse = context.read<WarehouseProvider>();
    String? debit, credit;
    String amount = '', reference = '';
    bool saving = false;
    String? error;
    final token = RecordId.create();
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(t('Post journal', 'تسجيل قيد')),
                    content: SizedBox(
                        width: 500,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Text(_currency),
                              for (final isDebit in [true, false])
                                DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: isDebit
                                            ? t('Debit account',
                                                'الحساب المدين')
                                            : t('Credit account',
                                                'الحساب الدائن')),
                                    items: JournalEntry.accounts.entries
                                        .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(
                                                '${e.key} ${accountName(e.key)}',
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (v) {
                                            if (isDebit) {
                                              debit = v;
                                            } else {
                                              credit = v;
                                            }
                                          }),
                              TextField(
                                  enabled: !saving,
                                  onChanged: (v) => amount = v,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                      labelText: t('Amount', 'المبلغ'))),
                              TextField(
                                  enabled: !saving,
                                  onChanged: (v) => reference = v,
                                  decoration: InputDecoration(
                                      labelText: t('Reason / reference',
                                          'السبب / المرجع'))),
                              if (error != null) Text(error!),
                              if (saving) const LinearProgressIndicator()
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t('Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    if (debit == null || credit == null) {
                                      throw ArgumentError(t(
                                          'Choose both accounts',
                                          'اختر الحسابين'));
                                    }
                                    await warehouse.postJournal(
                                        debit!,
                                        credit!,
                                        Money.parse(amount),
                                        _currency,
                                        reference,
                                        requestId: token);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: Text(t('Post journal', 'تسجيل قيد')))
                    ]))));
  }

  Future<void> _period(bool reopen) async {
    final wh = context.read<WarehouseProvider>(),
        shop = context.read<ShopProvider>();
    String through = '', reason = '';
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(reopen
                        ? t('Reopen period', 'فتح الفترة')
                        : t('Close period', 'إغلاق الفترة')),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      if (!reopen)
                        TextField(
                            enabled: !saving,
                            onChanged: (v) => through = v,
                            decoration: InputDecoration(
                                labelText: t('Closed through (YYYY-MM-DD, UTC)',
                                    'مغلق حتى (YYYY-MM-DD، UTC)'))),
                      TextField(
                          enabled: !saving,
                          onChanged: (v) => reason = v,
                          decoration:
                              InputDecoration(labelText: t('Reason', 'السبب'))),
                      Text(t(
                          'Closing today blocks further postings today. Reopening retains the reason in history.',
                          'إغلاق اليوم يمنع التسجيل خلال اليوم. إعادة الفتح تحتفظ بالسبب في السجل.')),
                      if (error != null) Text(error!),
                      if (saving) const LinearProgressIndicator()
                    ])),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t('Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await FinanceService.setPeriod(wh, shop,
                                        reopen ? null : through, reason);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: Text(t('Confirm', 'تأكيد')))
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final wh = context.watch<WarehouseProvider>(),
        shop = context.watch<ShopProvider>();
    final journals = [...wh.journals, ...shop.journals]
        .where((j) => j.currency == _currency)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final summary = FinanceSummary(journals, _currency,
        documentReceivables: shop.sales
            .where((d) =>
                d.currency == _currency &&
                d.reversalOf == null &&
                !shop.isSaleReversed(d.id))
            .fold(0, (sum, d) => sum + d.totalMinor - shop.paidFor(d)),
        documentPayables: wh.purchases
            .where((d) =>
                d.currency == _currency &&
                d.reversalOf == null &&
                !wh.isPurchaseReversed(d.id))
            .fold(0, (sum, d) => sum + d.totalMinor - wh.paidFor(d)));
    final balances = summary.balances;
    final busy = wh.isSaving || shop.isSaving || InventoryCoordinator.busy;
    return Scaffold(
        appBar: AppBar(title: Text(t('Finance', 'المالية'))),
        body: !wh.isLoaded
            ? StorageStatus(error: wh.loadError, onRetry: wh.initialize)
            : !shop.isLoaded
                ? StorageStatus(error: shop.loadError, onRetry: shop.initialize)
                : Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(t(
                                  'Ledger starts with new postings. Enter reviewed opening balances for existing business data. Purchases are recorded in the purchases account; automatic inventory valuation and tax are not configured.',
                                  'يبدأ الدفتر بالعمليات الجديدة. أدخل أرصدة افتتاحية مراجعة للبيانات السابقة. المشتريات بحساب المشتريات؛ تقييم المخزون والضرائب غير معدة.')),
                              Text(
                                  '${t('Ledger started', 'بداية الدفتر')}: ${wh.ledgerStartedAt ?? ''}'),
                              DropdownButtonFormField<String>(
                                  initialValue: _currency,
                                  isExpanded: true,
                                  items: Money.currencies
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _currency = v!)),
                              Wrap(spacing: 12, children: [
                                TextButton.icon(
                                    onPressed:
                                        busy || !AccessControl.allows('finance')
                                            ? null
                                            : _journal,
                                    icon: const Icon(Icons.add),
                                    label:
                                        Text(t('Post journal', 'تسجيل قيد'))),
                                TextButton(
                                    onPressed:
                                        busy || !AccessControl.allows('finance')
                                            ? null
                                            : () => _period(false),
                                    child: Text(
                                        t('Close period', 'إغلاق الفترة'))),
                                if (wh.closedThrough != null)
                                  TextButton(
                                      onPressed:
                                          busy || !AccessControl.allows('admin')
                                              ? null
                                              : () => _period(true),
                                      child: Text(
                                          t('Reopen period', 'فتح الفترة')))
                              ]),
                              if (wh.closedThrough != null)
                                Text(
                                    '${t('Closed through', 'مغلق حتى')}: ${wh.closedThrough}'),
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                t('Document reconciliation',
                                                    'مطابقة المستندات'),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                                '${t('Ledger cash', 'النقد في الدفتر')}: ${Money.format(summary.cash)} $_currency'),
                                            Text(
                                                '${t('Receivables: ledger / documents', 'الذمم المدينة: الدفتر / المستندات')}: ${Money.format(summary.receivables)} / ${Money.format(summary.documentReceivables)} $_currency'),
                                            Text(
                                                '${t('Payables: ledger / documents', 'الذمم الدائنة: الدفتر / المستندات')}: ${Money.format(summary.payables)} / ${Money.format(summary.documentPayables)} $_currency'),
                                            Text(summary.reconciled
                                                ? t('Ledger and document balances agree',
                                                    'أرصدة الدفتر والمستندات متطابقة')
                                                : t('Review differences, historical opening balances and manual control-account entries',
                                                    'راجع الفروق والأرصدة الافتتاحية التاريخية والقيود اليدوية لحسابات الذمم')),
                                            if (!summary.reconciled)
                                              Text(
                                                  '${t('Receivable / payable differences', 'فروق الذمم المدينة / الدائنة')}: ${Money.format(summary.receivableDifference)} / ${Money.format(summary.payableDifference)} $_currency'),
                                          ]))),
                              Text(
                                  t('Trial balance (debit minus credit)',
                                      'ميزان المراجعة (مدين ناقص دائن)'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              for (final a in JournalEntry.accounts.entries)
                                ListTile(
                                    title:
                                        Text('${a.key} ${accountName(a.key)}'),
                                    subtitle: Text(
                                        '${Money.format(balances[a.key] ?? 0)} $_currency')),
                              Text(
                                  '${t('Difference', 'الفرق')}: ${Money.format(balances.values.fold(0, (sum, v) => sum + v))} $_currency'),
                              for (final j in journals)
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  '${j.reference} • ${j.date.toLocal().toString().split('.').first}'),
                                              for (final l in j.lines)
                                                Text(
                                                    '${l.account} • ${t('Debit', 'مدين')}: ${Money.format(l.debit)} • ${t('Credit', 'دائن')}: ${Money.format(l.credit)}')
                                            ])))
                            ]))));
  }
}
