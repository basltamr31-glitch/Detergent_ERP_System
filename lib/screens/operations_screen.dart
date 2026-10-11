import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../services/access_control.dart';
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
                                                            TextButton(
                                                                onPressed: busy ||
                                                                        !AccessControl.allows(
                                                                            'warehouse')
                                                                    ? null
                                                                    : () => _action(
                                                                        t('Release production',
                                                                            'الإفراج عن الإنتاج'),
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
