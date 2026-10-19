import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../services/access_control.dart';
import '../services/production_completion_service.dart';
import '../widgets/storage_status.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String stage(String value) => t(
      value,
      switch (value) {
        'draft' => 'مسودة',
        'created' => 'تم الإنشاء',
        'approved' => 'معتمد',
        'released' => 'تم الإفراج',
        'cancelled' => 'ملغى',
        _ => value
      });
  Future<void> _action(String title, Future<void> Function(String) action,
      {bool quality = false}) async {
    String reason = '';
    bool saving = false, passed = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(title),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          enabled: !saving,
                          onChanged: (v) => reason = v,
                          decoration: InputDecoration(
                              labelText: t('Reason / quality record reference',
                                  'السبب / مرجع سجل الجودة'))),
                      if (quality)
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: passed,
                            onChanged: saving
                                ? null
                                : (v) => update(() => passed = v!),
                            title: Text(t(
                                'Quality checks passed; release this lot',
                                'اجتازت الدفعة فحوص الجودة ويمكن الإفراج عنها'))),
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
                                    if (quality && !passed) {
                                      throw StateError(t(
                                          'Confirm quality release',
                                          'أكد الإفراج بعد فحص الجودة'));
                                    }
                                    await action(reason);
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

  Future<void> _order() async {
    final warehouse = context.read<WarehouseProvider>();
    String name = '', qty = '', unit = '', lot = '', expiry = '';
    String? recipe;
    final amounts = <String, String>{},
        form = GlobalKey<FormState>(),
        token = RecordId.create();
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(t('Plan production order', 'تخطيط أمر إنتاج')),
                    content: SizedBox(
                        width: 560,
                        child: SingleChildScrollView(
                            child: Form(
                                key: form,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                              labelText: t(
                                                  'Saved recipe (optional)',
                                                  'وصفة محفوظة (اختياري)')),
                                          items: warehouse.recipes
                                              .map((r) => DropdownMenuItem(
                                                  value: r['id'] as String,
                                                  child: Text(
                                                      '${r['name']} v${r['version']}',
                                                      overflow: TextOverflow
                                                          .ellipsis)))
                                              .toList(),
                                          onChanged: saving
                                              ? null
                                              : (id) => update(() {
                                                    recipe = id;
                                                    final r = warehouse.recipes
                                                        .firstWhere((r) =>
                                                            r['id'] == id);
                                                    name = r['name'];
                                                    qty = r['quantity']
                                                        .toString();
                                                    unit = r['unit'];
                                                    amounts.clear();
                                                    for (final entry
                                                        in (r['materials']
                                                                as Map)
                                                            .entries) {
                                                      amounts[entry.key] = entry
                                                          .value
                                                          .toString();
                                                    }
                                                  })),
                                      for (final field in [
                                        'name',
                                        'quantity',
                                        'unit',
                                        'lot',
                                        'expiry'
                                      ])
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: TextFormField(
                                                key: ValueKey('$recipe:$field'),
                                                initialValue: switch (field) {
                                                  'name' => name,
                                                  'quantity' => qty,
                                                  'unit' => unit,
                                                  'lot' => lot,
                                                  _ => expiry
                                                },
                                                enabled: !saving,
                                                decoration: InputDecoration(
                                                    labelText: switch (field) {
                                                  'name' => t(
                                                      'Product / recipe name',
                                                      'اسم المنتج / الوصفة'),
                                                  'quantity' => t(
                                                      'Output quantity',
                                                      'كمية الإنتاج'),
                                                  'unit' => t('Output unit',
                                                      'وحدة الإنتاج'),
                                                  'lot' => t(
                                                      'Unique lot number',
                                                      'رقم دفعة فريد'),
                                                  _ => t(
                                                      'Expiry YYYY-MM-DD (optional)',
                                                      'الانتهاء YYYY-MM-DD (اختياري)')
                                                }),
                                                onChanged: (v) {
                                                  switch (field) {
                                                    case 'name':
                                                      name = v;
                                                    case 'quantity':
                                                      qty = v;
                                                    case 'unit':
                                                      unit = v;
                                                    case 'lot':
                                                      lot = v;
                                                    default:
                                                      expiry = v;
                                                  }
                                                },
                                                validator: (v) => field !=
                                                            'expiry' &&
                                                        (v == null ||
                                                            v.trim().isEmpty)
                                                    ? t('Required', 'مطلوب')
                                                    : null)),
                                      const SizedBox(height: 16),
                                      Text(t(
                                          'Ingredient quantities for this order',
                                          'كميات المواد لهذا الأمر')),
                                      for (final m in warehouse.materials)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: TextFormField(
                                                key:
                                                    ValueKey('$recipe:${m.id}'),
                                                initialValue:
                                                    amounts[m.id] ?? '',
                                                enabled: !saving,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                    labelText:
                                                        '${m.name} (${m.unit})',
                                                    helperText:
                                                        '${t('Available', 'المتاح')}: ${m.quantity}'),
                                                onChanged: (v) =>
                                                    amounts[m.id] = v)),
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
                                    final ingredients = <String, double>{};
                                    for (final m in warehouse.materials) {
                                      if ((amounts[m.id] ?? '')
                                          .trim()
                                          .isNotEmpty) {
                                        ingredients[m.name] =
                                            Money.quantity(amounts[m.id]!);
                                      }
                                    }
                                    await warehouse.createOrder(
                                        name,
                                        Money.quantity(qty),
                                        unit,
                                        lot,
                                        expiry.trim(),
                                        ingredients,
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
                          child: Text(t('Save order', 'حفظ الأمر')))
                    ]))));
  }

  Future<void> _count(bool raw) async {
    final warehouse = context.read<WarehouseProvider>(),
        shop = context.read<ShopProvider>();
    final items = raw
        ? warehouse.materials
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'quantity': m.quantity,
                  'unit': m.unit
                })
            .toList()
        : shop.products
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'quantity': m.quantity,
                  'unit': m.unit
                })
            .toList();
    String? id;
    String qty = '', reason = '';
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
                    title:
                        Text(t('Record physical count', 'تسجيل الجرد الفعلي')),
                    content: SizedBox(
                        width: 500,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText: t('Item', 'الصنف')),
                                  items: items
                                      .map((m) => DropdownMenuItem(
                                          value: m['id'] as String,
                                          child: Text(
                                              '${m['name']} • ${m['quantity']} ${m['unit']}',
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: saving ? null : (v) => id = v),
                              TextField(
                                  enabled: !saving,
                                  onChanged: (v) => qty = v,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                      labelText: t('Actual quantity',
                                          'الكمية الفعلية'))),
                              TextField(
                                  enabled: !saving,
                                  onChanged: (v) => reason = v,
                                  decoration: InputDecoration(
                                      labelText: t('Reason / count sheet',
                                          'السبب / ورقة الجرد'))),
                              Text(t(
                                  'Changes physical quantity. Record any financial valuation adjustment separately.',
                                  'يعدل الكمية الفعلية. سجل تعديل القيمة المالية بشكل منفصل.')),
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
                                    if (id == null) {
                                      throw ArgumentError(
                                          t('Select an item', 'اختر صنفاً'));
                                    }
                                    final parsed =
                                        double.parse(Money.normalize(qty));
                                    final count =
                                        parsed == 0 ? 0.0 : Money.quantity(qty);
                                    if (raw) {
                                      await warehouse.countStock(
                                          id!, count, reason,
                                          requestId: token);
                                    } else {
                                      await shop.countStock(id!, count, reason,
                                          requestId: token);
                                    }
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
                          child: Text(t('Save count', 'حفظ الجرد')))
                    ]))));
  }

  Future<void> _complete(Map<String, dynamic> order) async {
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductionCompletionDialog(
        warehouse: context.read<WarehouseProvider>(),
        shop: context.read<ShopProvider>(),
        order: order,
      ),
    );
    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('Production completed and finished goods received',
              'تم إتمام الإنتاج واستلام المنتجات الجاهزة'))));
    }
  }

  Widget _completionSummary(Map<String, dynamic> order, ShopProvider shop) {
    final completion = order['completion'] as Map;
    final matching =
        shop.products.where((p) => p.id == completion['productId']);
    final productName = matching.isEmpty
        ? completion['productId'].toString()
        : matching.single.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Finished goods received', 'تم استلام المنتجات الجاهزة'),
              style: Theme.of(context).textTheme.titleSmall),
          Text(
              '${completion['actualQuantity']} ${completion['unit']} → $productName'),
          Text(
              '${t('Manufacturing source lot', 'دفعة مصدر التصنيع')}: ${order['lot']}'),
          Text(completion['costStatus'] == 'unknown'
              ? t('Batch cost: unknown', 'تكلفة الدفعة: غير معلومة')
              : '${t('Total batch cost', 'تكلفة الدفعة الإجمالية')}: ${Money.format(completion['costMinor'])} ${completion['costCurrency']} • ${completion['costStatus'] == 'confirmed' ? t('Confirmed', 'مؤكدة') : t('Estimated', 'تقديرية')}'),
          if ((completion['varianceReason'] as String).isNotEmpty)
            Text(
                '${t('Actual production variance', 'اختلاف التنفيذ الفعلي')}: ${completion['varianceReason']}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = context.watch<WarehouseProvider>(),
        shop = context.watch<ShopProvider>();
    final busy = warehouse.isSaving || shop.isSaving;
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: AppBar(
                title: Text(t('Operations', 'العمليات')),
                bottom: TabBar(tabs: [
                  Tab(text: t('Production orders', 'أوامر الإنتاج')),
                  Tab(text: t('Stock counts', 'الجرد'))
                ])),
            body: !warehouse.isLoaded
                ? StorageStatus(
                    error: warehouse.loadError, onRetry: warehouse.initialize)
                : !shop.isLoaded
                    ? StorageStatus(
                        error: shop.loadError, onRetry: shop.initialize)
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: TabBarView(children: [
                              ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    FilledButton.icon(
                                        onPressed: busy ||
                                                !AccessControl.allows(
                                                    'warehouse')
                                            ? null
                                            : _order,
                                        icon: const Icon(Icons.add),
                                        label: Text(t('Plan production order',
                                            'تخطيط أمر إنتاج'))),
                                    for (final o in warehouse.orders.reversed)
                                      Card(
                                          child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '${o['number']} • ${o['name']} • ${stage(o['status'])}'),
                                                    Text(
                                                        '${o['quantity']} ${o['unit']} • ${o['lot']} • ${o['expiry']}'),
                                                    for (final e
                                                        in (o['materials']
                                                                as Map)
                                                            .entries)
                                                      Text(
                                                          '${warehouse.materials.firstWhere((m) => m.id == e.key).name}: ${e.value}'),
                                                    for (final e
                                                        in o['events'] as List)
                                                      Text(
                                                          '${stage(e['kind'])} • ${e['actor']['name']} • ${e['reason']}'),
                                                    if (o['completion'] != null)
                                                      _completionSummary(
                                                          o, shop),
                                                    if (o['status'] ==
                                                        'approved')
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 12),
                                                        child: Text(t(
                                                            'Receive sale-ready goods below. For bulk awaiting packaging, use Release and transfer it later.',
                                                            'استلم المنتجات الجاهزة للبيع أدناه. للناتج السائب الذي ينتظر التعبئة، استخدم إفراج ثم انقله لاحقًا.')),
                                                      ),
                                                    if (o['batchId'] != null &&
                                                        warehouse
                                                            .isProductionReversed(
                                                                o['batchId']))
                                                      Text(t(
                                                          'Production reversed',
                                                          'تم عكس الإنتاج')),
                                                    Wrap(
                                                        spacing: 12,
                                                        children: [
                                                          if (o['status'] ==
                                                              'draft')
                                                            TextButton(
                                                                onPressed: busy ||
                                                                        !AccessControl.allows(
                                                                            'approve')
                                                                    ? null
                                                                    : () => _action(
                                                                        t('Approve order',
                                                                            'اعتماد الأمر'),
                                                                        (reason) => warehouse.approveOrder(
                                                                            o[
                                                                                'id'],
                                                                            reason)),
                                                                child: Text(t(
                                                                    'Approve',
                                                                    'اعتماد'))),
                                                          if (o['status'] ==
                                                              'approved')
                                                            FilledButton.icon(
                                                              key: ValueKey(
                                                                  'complete-finished-${o['id']}'),
                                                              onPressed: busy ||
                                                                      !AccessControl
                                                                          .allows(
                                                                              'warehouse')
                                                                  ? null
                                                                  : () =>
                                                                      _complete(
                                                                          o),
                                                              icon: const Icon(Icons
                                                                  .inventory_2_outlined),
                                                              label: Text(t(
                                                                  'Complete & receive finished goods',
                                                                  'إتمام واستلام المنتجات الجاهزة')),
                                                            ),
                                                          if (o['status'] ==
                                                              'approved')
                                                            TextButton(
                                                                onPressed: busy ||
                                                                        !AccessControl.allows(
                                                                            'warehouse')
                                                                    ? null
                                                                    : () => _action(
                                                                        t('Complete bulk / prepare later transfer',
                                                                            'إتمام السائب / التجهيز للنقل لاحقًا'),
                                                                        (reason) => warehouse.releaseOrder(
                                                                            o[
                                                                                'id'],
                                                                            reason),
                                                                        quality:
                                                                            true),
                                                                child: Text(t(
                                                                    'Release',
                                                                    'إفراج'))),
                                                          if ([
                                                            'draft',
                                                            'approved'
                                                          ].contains(
                                                              o['status']))
                                                            TextButton(
                                                                onPressed: busy || !AccessControl.allows('approve')
                                                                    ? null
                                                                    : () => _action(
                                                                        t('Cancel order',
                                                                            'إلغاء الأمر'),
                                                                        (reason) => warehouse.cancelOrder(
                                                                            o[
                                                                                'id'],
                                                                            reason)),
                                                                child: Text(t(
                                                                    'Cancel order',
                                                                    'إلغاء الأمر')))
                                                        ])
                                                  ])))
                                  ]),
                              ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    Wrap(spacing: 12, children: [
                                      for (final raw in [true, false])
                                        FilledButton(
                                            onPressed: busy ||
                                                    !AccessControl.allows(
                                                        'warehouse')
                                                ? null
                                                : () => _count(raw),
                                            child: Text(raw
                                                ? t('Count raw materials',
                                                    'جرد المواد')
                                                : t('Count shop products',
                                                    'جرد منتجات المتجر')))
                                    ]),
                                    for (final c in [
                                      ...warehouse.counts,
                                      ...shop.counts
                                    ].reversed)
                                      Card(
                                          child: ListTile(
                                              title: Text(
                                                  '${warehouse.materials.where((m) => m.id == c.itemId).isNotEmpty ? warehouse.materials.firstWhere((m) => m.id == c.itemId).name : shop.products.firstWhere((p) => p.id == c.itemId).name}: ${c.before} → ${c.after}'),
                                              subtitle: Text(
                                                  '${c.reason} • ${c.actor['name']} • ${c.date.toLocal().toString().split('.').first}')))
                                  ])
                            ])))));
  }
}

class _ProductionCompletionDialog extends StatefulWidget {
  const _ProductionCompletionDialog({
    required this.warehouse,
    required this.shop,
    required this.order,
  });
  final WarehouseProvider warehouse;
  final ShopProvider shop;
  final Map<String, dynamic> order;
  @override
  State<_ProductionCompletionDialog> createState() =>
      _ProductionCompletionDialogState();
}

class _ProductionCompletionDialogState
    extends State<_ProductionCompletionDialog> {
  final _form = GlobalKey<FormState>();
  final _requestId = RecordId.create();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _quality = TextEditingController();
  final _variance = TextEditingController();
  final _cost = TextEditingController();
  final _costReference = TextEditingController();
  final _actual = <String, TextEditingController>{};
  late final TextEditingController _quantity;
  String _product = 'new', _costStatus = 'unknown', _currency = 'USD';
  bool _saving = false, _qualityPassed = false;
  String? _error;

  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void initState() {
    super.initState();
    _quantity =
        TextEditingController(text: widget.order['quantity'].toString());
    _name.text = widget.order['name'];
    for (final e in (widget.order['materials'] as Map).entries) {
      _actual[e.key as String] =
          TextEditingController(text: e.value.toString());
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _quality,
      _variance,
      _cost,
      _costReference,
      _quantity,
      ..._actual.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? t('Required', 'مطلوب') : null;

  String? _quantityValidator(String? value) {
    try {
      Money.quantity(value ?? '');
      return null;
    } catch (_) {
      return t('Enter a positive quantity with up to six decimals',
          'أدخل كمية موجبة حتى ست منازل عشرية');
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_qualityPassed) {
      setState(() => _error = t('Confirm quality checks before receiving goods',
          'أكد اجتياز فحوص الجودة قبل استلام المنتجات'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProductionCompletionService.complete(
        widget.warehouse,
        widget.shop,
        orderId: widget.order['id'],
        actualIngredients: {
          for (final e in _actual.entries) e.key: Money.quantity(e.value.text),
        },
        actualQuantity: Money.quantity(_quantity.text),
        outputUnit: widget.order['unit'],
        qualityNote: _quality.text,
        requestId: _requestId,
        finishedProductId: _product == 'new' ? null : _product,
        newProductName: _product == 'new' ? _name.text : null,
        newSku: _product == 'new' ? _sku.text : null,
        varianceReason: _variance.text,
        costMinor: _costStatus == 'unknown' ? null : Money.parse(_cost.text),
        costCurrency: _costStatus == 'unknown' ? null : _currency,
        costStatus: _costStatus,
        costReference: _costStatus == 'unknown' ? '' : _costReference.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    String? helper,
    String? Function(String?)? validator,
    bool number = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextFormField(
          key: ValueKey(key),
          controller: controller,
          enabled: !_saving,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          validator: validator,
          decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 4,
              errorMaxLines: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final products =
        widget.shop.products.where((p) => p.unit == widget.order['unit']);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(t('Complete & receive finished goods',
            'إتمام واستلام المنتجات الجاهزة')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.order['number']} • ${widget.order['lot']}'),
                  const SizedBox(height: 8),
                  Text(t(
                      'Use this action for finished, sale-ready output in the approved unit. Raw consumption and finished receipt are posted together.',
                      'استخدم هذا الإجراء للناتج النهائي الجاهز للبيع بوحدة الأمر المعتمدة. يُسجّل استهلاك الخام واستلام الجاهز معًا.')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('completion-product'),
                    initialValue: _product,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: t('Finished product / SKU',
                            'المنتج الجاهز / رمز الصنف')),
                    items: [
                      DropdownMenuItem(
                          value: 'new',
                          child: Text(t('Create a new finished SKU',
                              'إنشاء صنف جاهز جديد'))),
                      for (final p in products)
                        DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name} • ${p.unit}',
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _product = value!),
                  ),
                  if (_product == 'new') ...[
                    _field(
                        key: 'completion-product-name',
                        controller: _name,
                        label: t('Finished product name', 'اسم المنتج الجاهز'),
                        validator: _required),
                    _field(
                        key: 'completion-new-sku',
                        controller: _sku,
                        label: t('Unique SKU code', 'رمز صنف فريد'),
                        validator: _required),
                  ],
                  _field(
                      key: 'completion-quantity',
                      controller: _quantity,
                      label:
                          '${t('Actual accepted output', 'الناتج الفعلي المقبول')} (${widget.order['unit']})',
                      helper:
                          '${t('Planned output', 'الناتج المخطط')}: ${widget.order['quantity']} ${widget.order['unit']}',
                      validator: _quantityValidator,
                      number: true),
                  const SizedBox(height: 16),
                  Text(
                      t('Actual raw consumption',
                          'استهلاك المواد الخام الفعلي'),
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final e in _actual.entries)
                    _field(
                        key: 'completion-material-${e.key}',
                        controller: e.value,
                        label:
                            '${widget.warehouse.materials.firstWhere((m) => m.id == e.key).name} (${widget.warehouse.materials.firstWhere((m) => m.id == e.key).unit})',
                        validator: _quantityValidator,
                        number: true),
                  _field(
                      key: 'completion-variance',
                      controller: _variance,
                      label: t('Variance explanation', 'تفسير اختلاف التنفيذ'),
                      helper: t(
                          'Required if actual output or consumption differs from the approved plan.',
                          'مطلوب إذا اختلف الناتج أو الاستهلاك الفعلي عن الخطة المعتمدة.')),
                  _field(
                      key: 'completion-quality-note',
                      controller: _quality,
                      label: t('Quality record reference / note',
                          'مرجع سجل الجودة / الملاحظة'),
                      validator: _required),
                  CheckboxListTile(
                    key: const ValueKey('completion-quality-passed'),
                    contentPadding: EdgeInsets.zero,
                    value: _qualityPassed,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _qualityPassed = value!),
                    title: Text(t(
                        'Quality checks passed; output is ready for sale',
                        'اجتاز الناتج فحوص الجودة وأصبح جاهزًا للبيع')),
                  ),
                  const Divider(height: 24),
                  Text(t('Batch cost', 'تكلفة الدفعة'),
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(t(
                      'Record an explicit total cost, or leave it unknown. This does not change the selling price or post a financial cost journal.',
                      'سجّل تكلفة إجمالية محددة أو اتركها غير معلومة. لا تتغير أسعار البيع ولا يُرحّل قيد تكلفة محاسبي.')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('completion-cost-status'),
                    initialValue: _costStatus,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: t('Cost status', 'حالة التكلفة')),
                    items: [
                      DropdownMenuItem(
                          value: 'unknown',
                          child: Text(t('Unknown', 'غير معلومة'))),
                      DropdownMenuItem(
                          value: 'estimated',
                          child: Text(t('Estimated', 'تقديرية'))),
                      DropdownMenuItem(
                          value: 'confirmed',
                          child: Text(t('Confirmed from reviewed records',
                              'مؤكدة من سجلات مراجعة'))),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _costStatus = value!),
                  ),
                  if (_costStatus != 'unknown') ...[
                    _field(
                        key: 'completion-total-cost',
                        controller: _cost,
                        label: t('Total batch cost', 'تكلفة الدفعة الإجمالية'),
                        number: true,
                        validator: (value) {
                          try {
                            Money.parse(value ?? '');
                            return null;
                          } catch (_) {
                            return t('Enter an amount with up to two decimals',
                                'أدخل مبلغًا حتى منزلتين عشريتين');
                          }
                        }),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('completion-cost-currency'),
                      initialValue: _currency,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: t('Cost currency', 'عملة التكلفة')),
                      items: [
                        for (final currency in Money.currencies)
                          DropdownMenuItem(
                              value: currency, child: Text(currency))
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _currency = value!),
                    ),
                    _field(
                        key: 'completion-cost-reference',
                        controller: _costReference,
                        label: t('Cost source reference', 'مرجع مصدر التكلفة'),
                        validator:
                            _costStatus == 'confirmed' ? _required : null),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            key: ValueKey(_error),
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          ),
                  ),
                  if (_saving)
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(t('Cancel', 'إلغاء'))),
          FilledButton(
            key: const ValueKey('completion-submit'),
            onPressed: _saving ? null : _submit,
            child: Text(_saving
                ? t('Posting…', 'جارٍ التسجيل…')
                : t('Complete & receive', 'إتمام واستلام')),
          ),
        ],
      ),
    );
  }
}
