import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/shop_provider.dart';
import '../services/access_control.dart';
import '../services/inventory_units.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../widgets/storage_status.dart';

class FinishedProductScreen extends StatefulWidget {
  const FinishedProductScreen({super.key, this.productId});
  final String? productId;
  @override
  State<FinishedProductScreen> createState() => _FinishedProductScreenState();
}

class _FinishedProductScreenState extends State<FinishedProductScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _sku = TextEditingController();
  String _unit = 'Package';
  bool _saving = false;
  String? _error;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String quantity(num value) =>
      value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  String source(String? kind) => switch (kind) {
        'manufacturing' => t('Manufactured', 'إنتاج داخلي'),
        'supplier_purchase' => t('Trading purchase', 'مشتريات تجارية'),
        'adjustment' => t('Opening / adjustment', 'رصيد افتتاحي / تسوية'),
        'legacy_opening' =>
          t('Legacy / source unknown', 'رصيد سابق / مصدر غير معروف'),
        _ => kind ?? t('Unknown', 'غير معروف'),
      };
  String costStatus(String? status) => switch (status) {
        'confirmed' => t('Confirmed cost', 'تكلفة مؤكدة'),
        'estimated' => t('Estimated cost', 'تكلفة تقديرية'),
        _ => t('Cost unknown', 'تكلفة غير معروفة'),
      };
  String? required(String? v) =>
      v == null || v.trim().isEmpty ? t('Required', 'مطلوب') : null;
  Future<void> _register() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await context
          .read<ShopProvider>()
          .registerProduct(_name.text, _unit, _sku.text);
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => FinishedProductScreen(productId: id)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _configure(Product product) async {
    final name = TextEditingController(text: product.name),
        sku = TextEditingController(text: product.sku);
    final conversions = product.unitConversions
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final original = {
      for (final r in product.unitConversions)
        r['id']: Map<String, dynamic>.from(r)
    };
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                  title:
                      Text(t('Product & stock units', 'المنتج ووحدات المخزون')),
                  content: SizedBox(
                      width: 600,
                      child: SingleChildScrollView(
                          child: Form(
                              key: form,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                        controller: name,
                                        enabled: !saving,
                                        validator: required,
                                        decoration: InputDecoration(
                                            labelText: t(
                                                'Product name', 'اسم المنتج'))),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        controller: sku,
                                        enabled: !saving,
                                        validator: required,
                                        decoration: InputDecoration(
                                            labelText: t('SKU', 'رمز الصنف'))),
                                    const SizedBox(height: 16),
                                    Text(
                                        '${t('Fixed base stock unit', 'وحدة المخزون الأساسية الثابتة')}: ${product.unit}'),
                                    const SizedBox(height: 8),
                                    Text(t(
                                        'Define packaging for this SKU. Changing a factor creates a new revision; posted documents retain their original factor.',
                                        'عرّف التعبئة لهذا الصنف. تعديل معامل التحويل ينشئ إصداراً جديداً وتحتفظ المستندات المسجلة بمعاملها الأصلي.')),
                                    for (final row in conversions)
                                      Card(
                                          child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    TextFormField(
                                                        key: ValueKey(
                                                            '${row['id']}-unit'),
                                                        initialValue:
                                                            row['unit']
                                                                as String,
                                                        enabled: !saving,
                                                        validator: required,
                                                        onChanged: (v) =>
                                                            row['unit'] = v,
                                                        decoration: InputDecoration(
                                                            labelText: t(
                                                                'Entered unit (e.g. Carton)',
                                                                'وحدة الإدخال (مثل Carton)'))),
                                                    const SizedBox(height: 8),
                                                    for (final field in [
                                                      'numerator',
                                                      'denominator'
                                                    ])
                                                      TextFormField(
                                                          key: ValueKey(
                                                              '${row['id']}-$field'),
                                                          initialValue: row[field]
                                                              .toString(),
                                                          enabled: !saving,
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          decoration: InputDecoration(
                                                              labelText: field ==
                                                                      'numerator'
                                                                  ? t('Base units: numerator',
                                                                      'الوحدات الأساسية: البسط')
                                                                  : t('Entered units: denominator',
                                                                      'وحدات الإدخال: المقام')),
                                                          onChanged: (v) => row[
                                                                  field] =
                                                              int.tryParse(
                                                                  Money.normalize(v)),
                                                          validator: (v) {
                                                            final n = int
                                                                .tryParse(Money
                                                                    .normalize(
                                                                        v ??
                                                                            ''));
                                                            return n == null ||
                                                                    n < 1 ||
                                                                    n >
                                                                        InventoryUnits
                                                                            .maxFactorPart
                                                                ? t('Enter a positive whole number',
                                                                    'أدخل عدداً صحيحاً موجباً')
                                                                : null;
                                                          }),
                                                    SwitchListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Text(t(
                                                            'Allow fractional entered quantities',
                                                            'السماح بكميات كسرية عند الإدخال')),
                                                        value:
                                                            row['allowFraction']
                                                                as bool,
                                                        onChanged: saving
                                                            ? null
                                                            : (v) => update(() =>
                                                                row['allowFraction'] =
                                                                    v)),
                                                    Text(
                                                        '${t('Revision', 'الإصدار')}: ${row['revision']}'),
                                                    TextButton.icon(
                                                        onPressed: saving
                                                            ? null
                                                            : () => update(() =>
                                                                conversions
                                                                    .remove(
                                                                        row)),
                                                        icon: const Icon(Icons
                                                            .delete_outline),
                                                        label: Text(t(
                                                            'Remove unit',
                                                            'إزالة الوحدة'))),
                                                  ]))),
                                    TextButton.icon(
                                        onPressed: saving
                                            ? null
                                            : () =>
                                                update(() => conversions.add({
                                                      'id': RecordId.create(),
                                                      'unit': '',
                                                      'numerator': 1,
                                                      'denominator': 1,
                                                      'revision': 1,
                                                      'allowFraction': false
                                                    })),
                                        icon: const Icon(Icons.add),
                                        label: Text(t(
                                            'Add conversion', 'إضافة تحويل'))),
                                    if (error != null)
                                      Text(error!,
                                          style: TextStyle(
                                              color: Theme.of(ctx)
                                                  .colorScheme
                                                  .error)),
                                    if (saving) const LinearProgressIndicator(),
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
                                  final revisionRows = conversions.map((row) {
                                    final result =
                                        Map<String, dynamic>.from(row);
                                    final before = original[row['id']];
                                    if (before != null &&
                                        [
                                          'unit',
                                          'numerator',
                                          'denominator',
                                          'allowFraction'
                                        ].any((k) => before[k] != row[k])) {
                                      result['revision'] =
                                          (before['revision'] as int) + 1;
                                    }
                                    return result;
                                  }).toList();
                                  InventoryUnits.validateConversions(
                                      product.unit, revisionRows);
                                  await context
                                      .read<ShopProvider>()
                                      .configureProduct(product.id,
                                          name: name.text,
                                          sku: sku.text,
                                          unitConversions: revisionRows);
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
                        child: Text(t('Save product', 'حفظ المنتج')))
                  ],
                ))));
    name.dispose();
    sku.dispose();
  }

  Widget _lot(ShopProvider shop, Map<String, dynamic> lot) {
    final received = (lot['quantity'] as num).toDouble(),
        remaining = shop.lotRemaining(lot['id'] as String);
    final cost = lot['costMinor'] as int?;
    final currency = lot['currency'] as String?;
    final expired = (lot['expiry'] as String? ?? '').isNotEmpty &&
        (lot['expiry'] as String).compareTo(
                DateTime.now().toUtc().toIso8601String().substring(0, 10)) <=
            0;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${source(lot['sourceKind'] as String?)} • ${lot['lot'] == '' ? lot['id'] : lot['lot']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  '${t('Remaining / received', 'المتبقي / المستلم')}: ${quantity(remaining)} / ${quantity(received)} ${lot['unit']}'),
              Text(
                  '${t('Stock status', 'حالة المخزون')}: ${expired ? t('Expired', 'منتهي الصلاحية') : remaining <= 0 ? t('Consumed / returned', 'مستهلك / مرتجع') : lot['status'] == 'available' ? t('Available', 'متاح') : lot['status']}'),
              Text(costStatus(lot['costStatus'] as String?)),
              if (cost != null && currency != null) ...[
                Text(
                    '${t('Original total lot cost', 'إجمالي تكلفة الدفعة الأصلي')}: ${Money.format(cost)} $currency'),
                Text(
                    '${t('Derived cost per base unit', 'التكلفة المشتقة لكل وحدة أساسية')}: ${(cost / 100 / received).toStringAsFixed(6)} $currency'),
              ],
              Text(
                  '${t('Source document / batch ID', 'معرّف المستند / دفعة الإنتاج')}: ${lot['sourceId']}'),
              if (lot['supplierId'] != null)
                Text(
                    '${t('Supplier ID', 'معرّف المورد')}: ${lot['supplierId']}'),
              if ((lot['costReference'] as String? ?? '').isNotEmpty)
                Text(
                    '${t('Cost reference', 'مرجع التكلفة')}: ${lot['costReference']}'),
              Text('${t('Received', 'تاريخ الاستلام')}: ${lot['receivedAt']}'),
              if ((lot['expiry'] as String? ?? '').isNotEmpty)
                Text('${t('Expiry', 'الصلاحية')}: ${lot['expiry']}'),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final matches =
        shop.products.where((p) => p.id == widget.productId).toList();
    final product = matches.isEmpty ? null : matches.single;
    final lots = product == null
        ? <Map<String, dynamic>>[]
        : shop.stockLots.where((l) => l['productId'] == product.id).toList();
    final sources = <String, double>{};
    for (final lot in lots) {
      final kind = lot['sourceKind'] as String;
      sources[kind] =
          (sources[kind] ?? 0) + shop.lotRemaining(lot['id'] as String);
    }
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            appBar: AppBar(
                title: Text(widget.productId == null
                    ? t('Register finished product', 'تسجيل منتج جاهز')
                    : t('Product stock & sources', 'مخزون المنتج ومصادره')),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            body: !shop.isLoaded
                ? StorageStatus(error: shop.loadError, onRetry: shop.initialize)
                : Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: widget.productId == null
                                ? [
                                    Text(t(
                                        'Create the SKU without adding stock. Receive a trading purchase or complete approved production to add quantities.',
                                        'سجّل الصنف دون إضافة مخزون. تُضاف الكميات باستلام مشتريات تجارية أو إكمال إنتاج معتمد.')),
                                    const SizedBox(height: 16),
                                    Form(
                                        key: _form,
                                        child: Column(children: [
                                          TextFormField(
                                              key: const ValueKey(
                                                  'product-name'),
                                              controller: _name,
                                              enabled: !_saving,
                                              validator: required,
                                              decoration: InputDecoration(
                                                  labelText: t('Product name',
                                                      'اسم المنتج'))),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                              key:
                                                  const ValueKey('product-sku'),
                                              controller: _sku,
                                              enabled: !_saving,
                                              validator: required,
                                              decoration: InputDecoration(
                                                  labelText: t('Unique SKU',
                                                      'رمز صنف فريد'))),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                              initialValue: _unit,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                  labelText: t(
                                                      'Base stock unit',
                                                      'وحدة المخزون الأساسية')),
                                              items: [
                                                'Piece',
                                                'Unit',
                                                'Package',
                                                'Carton',
                                                'Box',
                                                'Kilogram',
                                                'Gram',
                                                'Liter',
                                                'Milliliter'
                                              ]
                                                  .map((u) => DropdownMenuItem(
                                                      value: u, child: Text(u)))
                                                  .toList(),
                                              onChanged: _saving
                                                  ? null
                                                  : (v) => setState(
                                                      () => _unit = v!)),
                                          const SizedBox(height: 16),
                                          FilledButton.icon(
                                              key: const ValueKey(
                                                  'register-product'),
                                              onPressed: _saving ||
                                                      !AccessControl.allows(
                                                          'warehouse')
                                                  ? null
                                                  : _register,
                                              icon: const Icon(
                                                  Icons.add_box_outlined),
                                              label: Text(t(
                                                  'Register product (zero stock)',
                                                  'تسجيل المنتج (رصيد صفر)'))),
                                        ])),
                                    if (_error != null)
                                      Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error)),
                                    if (_saving)
                                      const LinearProgressIndicator(),
                                  ]
                                : product == null
                                    ? [
                                        Text(t('Product not found',
                                            'المنتج غير موجود'))
                                      ]
                                    : [
                                        Text(product.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall),
                                        Text(
                                            '${t('SKU', 'رمز الصنف')}: ${product.sku}'),
                                        Text(
                                            '${t('Stock balance', 'رصيد المخزون')}: ${quantity(product.quantity)} ${product.unit}'),
                                        const SizedBox(height: 12),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              for (final entry
                                                  in sources.entries)
                                                Chip(
                                                    label: Text(
                                                        '${source(entry.key)}: ${quantity(entry.value)} ${product.unit}'))
                                            ]),
                                        Text(t(
                                            'Source quantities include all remaining lots. Expiry and stock status determine which lots can be sold. Costs keep their own currency; estimates and unknown costs are shown explicitly.',
                                            'تتضمن كميات المصادر جميع الدفعات المتبقية. تحدد الصلاحية وحالة المخزون الكميات القابلة للبيع. تُعرض التكاليف بعملتها مع بيان التكاليف التقديرية وغير المعروفة.')),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                            key: const ValueKey(
                                                'configure-product'),
                                            onPressed: shop.isSaving ||
                                                    !AccessControl.allows(
                                                        'warehouse')
                                                ? null
                                                : () => _configure(product),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                            label: Text(t(
                                                'Edit product & conversions',
                                                'تعديل المنتج والتحويلات'))),
                                        for (final row
                                            in product.unitConversions)
                                          Text(
                                              '1 ${row['unit']} = ${row['numerator']} / ${row['denominator']} ${product.unit} • ${t('Revision', 'الإصدار')} ${row['revision']}'),
                                        const SizedBox(height: 20),
                                        Text(t('Stock lots', 'دفعات المخزون'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        if (lots.isEmpty)
                                          Text(t(
                                              'No receipts yet. This SKU has no stock.',
                                              'لا توجد استلامات بعد. هذا الصنف بلا مخزون.')),
                                        for (final lot in lots.reversed)
                                          _lot(shop, lot),
                                        const SizedBox(height: 20),
                                        Text(
                                            t('Stock movements',
                                                'حركات المخزون'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        for (final move in shop.stockMovements
                                            .where((m) =>
                                                m['productId'] == product.id)
                                            .toList()
                                            .reversed)
                                          Card(
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            '${move['kind']} • ${quantity(move['quantity'] as num)} ${product.unit}'),
                                                        Text(
                                                            '${move['date']} • ${move['sourceId']}'),
                                                        Text(
                                                            '${t('Lot ID', 'معرّف الدفعة')}: ${move['lotId']}')
                                                      ]))),
                                      ])))));
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    super.dispose();
  }
}
