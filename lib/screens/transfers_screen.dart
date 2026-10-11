import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../services/transfer_service.dart';
import '../services/inventory_coordinator.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../widgets/storage_status.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});
  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  bool _saving = false;
  String? _error;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _entry() async {
    final warehouse = context.read<WarehouseProvider>(),
        shop = context.read<ShopProvider>();
    String? batch, currency;
    String source = '',
        sourceUnit = '',
        name = '',
        qty = '',
        unit = '',
        price = '';
    final form = GlobalKey<FormState>(), token = RecordId.create();
    bool saving = false;
    String? error;
    String? required(String? v) =>
        v == null || v.trim().isEmpty ? t('Required', 'مطلوب') : null;
    Widget field(String label, void Function(String) change,
            {bool money = false, bool quantity = false}) =>
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
                enabled: !saving,
                decoration: InputDecoration(labelText: label),
                onChanged: change,
                keyboardType: money || quantity
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                validator: (v) {
                  try {
                    if (money) {
                      Money.parse(v ?? '');
                    } else if (quantity) {
                      Money.quantity(v ?? '');
                    } else {
                      return required(v);
                    }
                    return null;
                  } catch (_) {
                    return t(
                        'Invalid amount or quantity', 'مبلغ أو كمية غير صالحة');
                  }
                }));
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(
                        t('Transfer finished goods', 'نقل المنتجات الجاهزة')),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Form(
                                key: form,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          validator: required,
                                          decoration: InputDecoration(
                                              labelText: t('Production batch',
                                                  'دفعة الإنتاج')),
                                          items: warehouse.manufacturedProducts
                                              .map((b) => DropdownMenuItem(
                                                  value: b.id,
                                                  child: Text(
                                                      '${b.number} • ${b.name} • ${warehouse.finishedAvailable(b.id)}',
                                                      overflow: TextOverflow
                                                          .ellipsis)))
                                              .toList(),
                                          onChanged:
                                              saving ? null : (v) => batch = v),
                                      field(
                                          t('Manufactured quantity to use',
                                              'كمية الإنتاج المستخدمة'),
                                          (v) => source = v,
                                          quantity: true),
                                      field(
                                          t('Unit used when recording production',
                                              'وحدة كمية الإنتاج المسجلة'),
                                          (v) => sourceUnit = v),
                                      field(
                                          t('Shop product name',
                                              'اسم منتج المتجر'),
                                          (v) => name = v),
                                      field(
                                          t('Packaged quantity received by shop',
                                              'الكمية المعبأة المستلمة بالمتجر'),
                                          (v) => qty = v,
                                          quantity: true),
                                      field(
                                          t('Shop stock unit',
                                              'وحدة مخزون المتجر'),
                                          (v) => unit = v),
                                      field(
                                          t('Reference unit price',
                                              'سعر الوحدة المرجعي'),
                                          (v) => price = v,
                                          money: true),
                                      DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          validator: required,
                                          decoration: InputDecoration(
                                              labelText:
                                                  t('Currency', 'العملة')),
                                          items: Money.currencies
                                              .map((c) => DropdownMenuItem(
                                                  value: c, child: Text(c)))
                                              .toList(),
                                          onChanged: saving
                                              ? null
                                              : (v) => currency = v),
                                      const SizedBox(height: 12),
                                      Text(t(
                                          'Enter the actual manufacturing and packaged quantities. Confirm the conversion, including density and packaging loss, from your batch records.',
                                          'أدخل كميات الإنتاج والتعبئة الفعلية وتحقق من التحويل والكثافة وفاقد التعبئة حسب سجل الدفعة.')),
                                      if (error != null) Text(error!),
                                      if (saving)
                                        const LinearProgressIndicator()
                                    ])))),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t('Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await TransferService.post(warehouse, shop,
                                        batchId: batch!,
                                        sourceQuantity: Money.quantity(source),
                                        sourceUnit: sourceUnit,
                                        productName: name,
                                        quantity: Money.quantity(qty),
                                        unit: unit,
                                        unitPriceMinor: Money.parse(price),
                                        currency: currency!,
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
                          child: Text(t('Post transfer', 'تسجيل النقل')))
                    ]))));
    if (mounted) setState(() {});
  }

  Future<void> _return(String id) async {
    String reason = '';
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(t('Return transfer', 'إرجاع النقل')),
                content: Form(
                    key: form,
                    child: TextFormField(
                        onChanged: (v) => reason = v,
                        decoration:
                            InputDecoration(labelText: t('Reason', 'السبب')),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? t('Required', 'مطلوب')
                            : null)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t('Cancel', 'إلغاء'))),
                  FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(ctx, reason);
                        }
                      },
                      child: Text(t('Return transfer', 'إرجاع النقل')))
                ]));
    if (value != null && mounted) {
      await _run(() => TransferService.reverse(
          context.read<WarehouseProvider>(),
          context.read<ShopProvider>(),
          id,
          value,
          requestId: RecordId.create()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wh = context.watch<WarehouseProvider>(),
        shop = context.watch<ShopProvider>();
    final busy =
        _saving || wh.isSaving || shop.isSaving || InventoryCoordinator.busy;
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            appBar: AppBar(
                title: Text(
                    t('Finished-goods transfers', 'نقل المنتجات الجاهزة'))),
            body: !wh.isLoaded
                ? StorageStatus(error: wh.loadError, onRetry: wh.initialize)
                : !shop.isLoaded
                    ? StorageStatus(
                        error: shop.loadError, onRetry: shop.initialize)
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  if (InventoryCoordinator.busy)
                                    FilledButton(
                                        onPressed: _saving
                                            ? null
                                            : () => _run(() =>
                                                TransferService.retry(
                                                    wh, shop)),
                                        child: Text(t(
                                            'Recover pending transfer',
                                            'استعادة النقل المعلق'))),
                                  FilledButton.icon(
                                      key: const ValueKey('new-transfer'),
                                      onPressed: busy ? null : _entry,
                                      icon: const Icon(Icons.swap_horiz),
                                      label: Text(t('Transfer finished goods',
                                          'نقل المنتجات الجاهزة'))),
                                  if (_error != null) Text(_error!),
                                  if (_saving) const LinearProgressIndicator(),
                                  for (final transfer in wh.transfers.reversed)
                                    Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${transfer.number} • ${transfer.productName}'),
                                                  Text(
                                                      '${transfer.sourceQuantity} ${transfer.sourceUnit} → ${transfer.quantity} ${transfer.unit}'),
                                                  Text(
                                                      '${Money.format(transfer.unitPriceMinor)} ${transfer.currency} • ${transfer.date.toLocal().toString().split('.').first}'),
                                                  Text(wh.productionDocuments
                                                      .firstWhere((b) =>
                                                          b.id ==
                                                          transfer.batchId)
                                                      .number),
                                                  if (transfer
                                                      .reason.isNotEmpty)
                                                    Text(transfer.reason),
                                                  if (transfer.reversalOf !=
                                                      null)
                                                    Text(t('Return', 'إرجاع'))
                                                  else if (wh.transfers.any(
                                                      (t) =>
                                                          t.reversalOf ==
                                                          transfer.id))
                                                    Text(t('Returned',
                                                        'تم الإرجاع'))
                                                  else
                                                    TextButton(
                                                        onPressed: busy
                                                            ? null
                                                            : () => _return(
                                                                transfer.id),
                                                        child: Text(t(
                                                            'Return transfer',
                                                            'إرجاع النقل')))
                                                ])))
                                ])))));
  }
}
