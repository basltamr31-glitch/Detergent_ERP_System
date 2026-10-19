import '../services/trading_purchase_service.dart';
import '../services/record_id.dart';
import '../services/access_control.dart';
import 'package:printing/printing.dart';
import '../services/document_report.dart';
import '../models/document_payment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../models/trade_document.dart';
import '../services/money.dart';
import '../widgets/storage_status.dart';
import 'trade_entry_screen.dart';

class BusinessDocumentsScreen extends StatefulWidget {
  const BusinessDocumentsScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<BusinessDocumentsScreen> createState() =>
      _BusinessDocumentsScreenState();
}

class _BusinessDocumentsScreenState extends State<BusinessDocumentsScreen> {
  String _query = '';
  String _purchaseFilter = 'all', _saleSource = 'all';
  Widget _search(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          initialValue: _query,
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: t(context, 'Search number, party or item',
                  'البحث بالرقم أو الطرف أو الصنف')),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase())));
  String t(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String _allocationCost(
      BuildContext context, TradeDocument document, String lotId) {
    final moves = context.read<ShopProvider>().stockMovements.where((m) =>
        m['sourceId'] == document.id &&
        m['lotId'] == lotId &&
        ['sale', 'saleReturn'].contains(m['kind']));
    if (moves.isEmpty || moves.first['costMinor'] == null) {
      return t(context, 'Cost unknown', 'التكلفة غير معروفة');
    }
    return '${t(context, 'Allocated cost', 'التكلفة المخصصة')}: ${Money.format((moves.first['costMinor'] as int).abs())} ${moves.first['currency']}';
  }

  bool _matchesSource(BuildContext context, TradeDocument document) {
    if (_saleSource == 'all') { return true; }
    final lots = context.read<ShopProvider>().stockLots;
    return document.lines.any((line) => line.lots.keys.any((id) =>
        lots.any((l) => l['id'] == id && l['sourceKind'] == _saleSource)));
  }

  Future<void> _reverse(
      BuildContext context, Future<void> Function(String) action) async {
    String reason = '';
    final form = GlobalKey<FormState>();
    final text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(t(context, 'Reverse document', 'عكس المستند')),
                content: Form(
                    key: form,
                    child: TextFormField(
                        onChanged: (value) => reason = value,
                        validator: (value) => value == null ||
                                value.trim().isEmpty
                            ? t(context, 'A reason is required', 'السبب مطلوب')
                            : null,
                        decoration: InputDecoration(
                            labelText: t(context, 'Reason (required)',
                                'السبب (مطلوب)')))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t(context, 'Cancel', 'إلغاء'))),
                  FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(ctx, reason.trim());
                        }
                      },
                      child: Text(t(context, 'Reverse', 'عكس')))
                ]));
    if (text == null || !context.mounted) return;
    try {
      await action(text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _payment(
      BuildContext context,
      TradeDocument doc,
      Future<void> Function(String, int,
              {required String requestId, String reference})
          save) async {
    String amount = '';
    String reference = '';
    final token = RecordId.create();
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(t(context, 'Record payment', 'تسجيل دفعة')),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${doc.number} • ${doc.currency}'),
                      TextField(
                          onChanged: (value) => amount = value,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: t(context, 'Amount', 'المبلغ')),
                          enabled: !saving),
                      TextField(
                          onChanged: (value) => reference = value,
                          enabled: !saving,
                          decoration: InputDecoration(
                              labelText: t(context, 'Reference', 'مرجع'))),
                      if (error != null) Text(error!),
                      if (saving) const LinearProgressIndicator()
                    ])),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t(context, 'Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await save(doc.id, Money.parse(amount),
                                        requestId: token, reference: reference);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: Text(t(context, 'Save payment', 'حفظ الدفعة')))
                    ]))));
  }

  Future<void> _refund(
      BuildContext context,
      TradeDocument doc,
      Future<void> Function(String, int, String, {required String requestId})
          save) async {
    String amount = '', reason = '';
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
                    title: Text(t(context, 'Record refund', 'تسجيل رد مبلغ')),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${doc.number} • ${doc.currency}'),
                      TextField(
                          enabled: !saving,
                          decoration: InputDecoration(
                              labelText: t(context, 'Amount', 'المبلغ')),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (v) => amount = v),
                      TextField(
                          enabled: !saving,
                          decoration: InputDecoration(
                              labelText: t(
                                  context,
                                  'Reason / payment reference',
                                  'السبب / مرجع الدفع')),
                          onChanged: (v) => reason = v),
                      Text(t(
                          context,
                          'Record this only after the money has actually been refunded.',
                          'سجل العملية بعد رد المبلغ فعلياً.')),
                      if (error != null) Text(error!),
                      if (saving) const LinearProgressIndicator()
                    ])),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t(context, 'Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await save(
                                        doc.id, Money.parse(amount), reason,
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
                          child:
                              Text(t(context, 'Save refund', 'حفظ رد المبلغ')))
                    ]))));
  }

  Future<void> _print(BuildContext context, TradeDocument doc,
      List<DocumentPayment> payments) async {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final bytes = await DocumentReport.build(doc, payments, arabic: arabic);
      await Printing.layoutPdf(name: doc.number, onLayout: (_) async => bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = context.watch<WarehouseProvider>();
    final shop = context.watch<ShopProvider>();
    return DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab,
        child: Scaffold(
          appBar: AppBar(
              title:
                  Text(t(context, 'Business documents', 'المستندات التجارية')),
              bottom: TabBar(tabs: [
                Tab(text: t(context, 'Production', 'الإنتاج')),
                Tab(text: t(context, 'Purchases', 'المشتريات')),
                Tab(text: t(context, 'Sales', 'المبيعات'))
              ])),
          body: !warehouse.isLoaded
              ? StorageStatus(
                  error: warehouse.loadError, onRetry: warehouse.initialize)
              : !shop.isLoaded
                  ? StorageStatus(
                      error: shop.loadError, onRetry: shop.initialize)
                  : TabBarView(children: [
                      _production(context, warehouse),
                      _trade(context, warehouse.purchases,
                          purchase: true,
                          busy: warehouse.isSaving,
                          reversed: warehouse.isPurchaseReversed,
                          onReverse: (id, reason) => warehouse.purchases
                                      .firstWhere((d) => d.id == id)
                                      .purchaseKind ==
                                  'trading'
                              ? TradingPurchaseService.reverse(
                                  warehouse, shop, id, reason,
                                  requestId: RecordId.create())
                              : warehouse.reversePurchase(id, reason),
                          payments: warehouse.payments,
                          paidFor: warehouse.paidFor,
                          onPayment: warehouse.recordPayment,
                          onRefund: warehouse.recordRefund),
                      _trade(context, shop.sales,
                          purchase: false,
                          busy: shop.isSaving,
                          reversed: shop.isSaleReversed,
                          onReverse: shop.reverseSale,
                          payments: shop.payments,
                          paidFor: shop.paidFor,
                          onPayment: shop.recordPayment,
                          onRefund: shop.recordRefund),
                    ]),
        ));
  }

  Widget _production(BuildContext context, WarehouseProvider warehouse) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _search(context),
        if (warehouse.productionDocuments.isEmpty)
          Text(t(context, 'No production documents yet',
              'لا توجد مستندات إنتاج بعد')),
        ...warehouse.productionDocuments.reversed
            .where(
                (b) => '${b.number} ${b.name}'.toLowerCase().contains(_query))
            .map((batch) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${batch.number} • ${batch.name}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              '${batch.date.toLocal().toString().split('.').first} • ${batch.quantity}'),
                          Text(batch.kind == 'reversal'
                              ? t(context, 'Reversal', 'عكس')
                              : warehouse.isProductionReversed(batch.id)
                                  ? t(context, 'Reversed', 'تم العكس')
                                  : t(context, 'Posted', 'مسجل')),
                          for (final entry in batch.rawMaterialsUsed.entries)
                            Text('${entry.key}: ${entry.value}'),
                          if (batch.reason.isNotEmpty) Text(batch.reason),
                          if (batch.reversalOf != null)
                            SelectableText(
                                '${t(context, 'Original document', 'المستند الأصلي')}: ${_productionNumber(warehouse, batch.reversalOf!)}'),
                          if (batch.replacesId != null)
                            Text(
                                '${t(context, 'Corrects', 'يصحح')}: ${_productionNumber(warehouse, batch.replacesId!)}'),
                          if (batch.kind == 'production' &&
                              !warehouse.isProductionReversed(batch.id))
                            TextButton.icon(
                                onPressed: warehouse.isSaving ||
                                        !AccessControl.allows('warehouse')
                                    ? null
                                    : () => _reverse(
                                        context,
                                        (reason) => warehouse.reverseProduction(
                                            batch.id, reason)),
                                icon: const Icon(Icons.undo),
                                label: Text(t(context, 'Reverse', 'عكس'))),
                        ]))))
      ]);
  String _productionNumber(WarehouseProvider warehouse, String id) =>
      warehouse.productionDocuments.firstWhere((b) => b.id == id).number;
  String _lotLabel(BuildContext context, String id) {
    final shop = context.read<ShopProvider>();
    final lots = shop.stockLots.where((l) => l['id'] == id);
    if (lots.isNotEmpty) {
      return '${lots.first['lot']} / ${lots.first['sourceKind']} / ${lots.first['sourceId']}';
    }
    final transfers = shop.transfers.where((t) => t.id == id);
    return transfers.isEmpty ? id : transfers.first.lot;
  }

  Widget _trade(BuildContext context, List<TradeDocument> docs,
          {required bool purchase,
          required bool busy,
          required bool Function(String) reversed,
          required Future<void> Function(String, String) onReverse,
          required List<DocumentPayment> payments,
          required int Function(TradeDocument) paidFor,
          required Future<void> Function(String, int,
                  {required String requestId, String reference})
              onPayment,
          required Future<void> Function(String, int, String,
                  {required String requestId})
              onRefund}) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _search(context),
        DropdownButtonFormField<String>(
            key: ValueKey(
                purchase ? 'purchase-kind-filter' : 'sale-source-filter'),
            initialValue: purchase ? _purchaseFilter : _saleSource,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: purchase
                    ? t(context, 'Purchase destination', 'وجهة المشتريات')
                    : t(context, 'Stock source', 'مصدر المخزون')),
            items: (purchase
                    ? <String, String>{
                        'all': t(context, 'All purchases', 'كل المشتريات'),
                        'raw': t(context, 'Raw materials', 'المواد الخام'),
                        'trading':
                            t(context, 'Trading goods', 'البضائع التجارية')
                      }
                    : <String, String>{
                        'all': t(context, 'All sources', 'كل المصادر'),
                        'manufacturing':
                            t(context, 'Manufactured', 'تصنيع داخلي'),
                        'supplier_purchase': t(
                            context, 'Supplier purchases', 'مشتريات الموردين'),
                        'legacy_opening':
                            t(context, 'Legacy opening', 'رصيد افتتاحي قديم'),
                        'adjustment':
                            t(context, 'Stock adjustment', 'تسوية مخزون')
                      })
                .entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(
                () => purchase ? _purchaseFilter = v! : _saleSource = v!)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: busy ||
                    !AccessControl.allows(purchase ? 'warehouse' : 'sales')
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TradeEntryScreen(purchase: purchase))),
            icon: const Icon(Icons.add),
            label: Text(purchase
                ? t(context, 'Receive purchase', 'استلام مشتريات')
                : t(context, 'Record sale', 'تسجيل بيع'))),
        const SizedBox(height: 16),
        if (docs.isEmpty)
          Text(t(context, 'No documents yet', 'لا توجد مستندات بعد')),
        ...docs.reversed
            .where((d) => purchase
                ? (_purchaseFilter == 'all' ||
                    d.purchaseKind == _purchaseFilter)
                : _matchesSource(context, d))
            .where((d) =>
                '${d.number} ${d.party} ${d.lines.map((l) => l.itemName).join(' ')}'
                    .toLowerCase()
                    .contains(_query))
            .map((doc) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (purchase)
                            Text(doc.purchaseKind == 'trading'
                                ? t(
                                    context,
                                    'Trading purchase → finished goods',
                                    'شراء تجاري ← المنتجات الجاهزة')
                                : t(context, 'Raw-material purchase',
                                    'شراء مواد خام')),
                          Text('${doc.number} • ${doc.party}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          for (final line in doc.lines)
                            Text(
                                '${line.itemName} • ${line.quantity} ${line.unit} • ${Money.format(line.totalMinor)} ${doc.currency}'),
                          for (final line in doc.lines)
                            if (line.stockQuantity != null &&
                                (line.unit != line.baseUnit ||
                                    line.quantity != line.baseQuantity))
                              Text(
                                  '${t(context, 'Stock quantity', 'كمية المخزون')}: ${line.baseQuantity} ${line.baseUnit}'),
                          for (final line in doc.lines)
                            for (final lot in line.lots.entries)
                              Text(
                                  '${t(context, 'Lot', 'الدفعة')}: ${_lotLabel(context, lot.key)} • ${lot.value} • ${_allocationCost(context, doc, lot.key)}'),
                          Text(
                              '${doc.date.toLocal().toString().split('.').first} • ${doc.amount}'),
                          Text(doc.reversalOf != null
                              ? t(context, 'Reversal', 'عكس')
                              : reversed(doc.id)
                                  ? t(context, 'Reversed', 'تم العكس')
                                  : t(context, 'Posted', 'مسجل')),
                          if (doc.reversalOf == null && !reversed(doc.id))
                            Text(
                                '${t(context, 'Paid', 'المدفوع')}: ${Money.format(paidFor(doc))} ${doc.currency} • ${t(context, 'Outstanding', 'المتبقي')}: ${Money.format(doc.totalMinor - paidFor(doc))} ${doc.currency}'),
                          for (final payment
                              in payments.where((p) => p.documentId == doc.id))
                            Text(
                                '${payment.date.toLocal().toString().split('.').first} • ${Money.format(payment.amountMinor)} ${doc.currency} • ${payment.reference} ${payment.kind == 'refund' ? t(context, 'Refund', 'رد مبلغ') : ''} ${payment.reason}'),
                          if (doc.reversalOf == null &&
                              !reversed(doc.id) &&
                              paidFor(doc) < doc.totalMinor)
                            TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _payment(context, doc, onPayment),
                                icon: const Icon(Icons.payments_outlined),
                                label: Text(t(
                                    context, 'Record payment', 'تسجيل دفعة'))),
                          if (doc.reversalOf == null &&
                              !reversed(doc.id) &&
                              paidFor(doc) > 0)
                            TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _refund(context, doc, onRefund),
                                icon: const Icon(Icons.currency_exchange),
                                label: Text(t(context, 'Record refund',
                                    'تسجيل رد مبلغ'))),
                          Text(
                              '${t(context, 'Posted by', 'سجل بواسطة')}: ${doc.actor['name']}'),
                          TextButton.icon(
                              onPressed: () => _print(context, doc, payments),
                              icon: const Icon(Icons.print),
                              label: Text(
                                  t(context, 'Print / PDF', 'طباعة / PDF'))),
                          if (doc.reference.isNotEmpty)
                            Text(
                                '${t(context, 'Reference', 'مرجع')}: ${doc.reference}'),
                          if (doc.reason.isNotEmpty) Text(doc.reason),
                          if (doc.reversalOf != null)
                            Text(
                                '${t(context, 'Original document', 'المستند الأصلي')}: ${docs.firstWhere((d) => d.id == doc.reversalOf).number}'),
                          if (doc.reversalOf == null && !reversed(doc.id))
                            TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _reverse(context,
                                        (reason) => onReverse(doc.id, reason)),
                                icon: const Icon(Icons.undo),
                                label: Text(t(context, 'Reverse', 'عكس'))),
                        ]))))
      ]);
}
