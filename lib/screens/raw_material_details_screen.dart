import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/access_control.dart';
import '../services/inventory_units.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../widgets/storage_status.dart';

class RawMaterialDetailsScreen extends StatefulWidget {
  const RawMaterialDetailsScreen({super.key, required this.materialId});
  final String materialId;
  @override
  State<RawMaterialDetailsScreen> createState() =>
      _RawMaterialDetailsScreenState();
}

class _RawMaterialDetailsScreenState extends State<RawMaterialDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _sku = TextEditingController();
  final _conversions = <Map<String, dynamic>>[];
  final _original = <String, Map<String, dynamic>>{};
  bool _initialized = false, _saving = false;
  String? _error;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String? required(String? v) =>
      v == null || v.trim().isEmpty ? t('Required', 'مطلوب') : null;
  Future<void> _save(String baseUnit) async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final rows = _conversions.map((row) {
        final result = Map<String, dynamic>.from(row);
        final before = _original[row['id']];
        if (before != null &&
            ['unit', 'numerator', 'denominator', 'allowFraction']
                .any((k) => before[k] != row[k])) {
          result['revision'] = (before['revision'] as int) + 1;
        }
        return result;
      }).toList();
      InventoryUnits.validateConversions(baseUnit, rows);
      await context.read<WarehouseProvider>().configureMaterial(
          widget.materialId,
          name: _name.text,
          sku: _sku.text,
          unitConversions: rows);
      _original.clear();
      for (final row in rows) {
        _original[row['id'] as String] = Map<String, dynamic>.from(row);
      }
      _conversions
        ..clear()
        ..addAll(rows);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('Material and unit conversions saved',
                'تم حفظ المادة وتحويلات الوحدات'))));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = context.watch<WarehouseProvider>();
    final matches =
        warehouse.materials.where((m) => m.id == widget.materialId).toList();
    final material = matches.isEmpty ? null : matches.single;
    if (material != null && !_initialized) {
      _name.text = material.name;
      _sku.text = material.sku;
      _conversions.addAll(
          material.unitConversions.map((r) => Map<String, dynamic>.from(r)));
      for (final row in _conversions) {
        _original[row['id'] as String] = Map<String, dynamic>.from(row);
      }
      _initialized = true;
    }
    final editable =
        !_saving && !warehouse.isSaving && AccessControl.allows('warehouse');
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            appBar: AppBar(
                title: Text(t('Raw material & stock units',
                    'المادة الخام ووحدات المخزون')),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
            body: !warehouse.isLoaded
                ? StorageStatus(
                    error: warehouse.loadError, onRetry: warehouse.initialize)
                : material == null
                    ? Center(
                        child:
                            Text(t('Material not found', 'المادة غير موجودة')))
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Form(
                                key: _form,
                                child: ListView(
                                    padding: const EdgeInsets.all(20),
                                    children: [
                                      Text(
                                          '${t('Raw stock balance', 'رصيد المواد الخام')}: ${material.quantity.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} ${material.unit}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          key: const ValueKey('raw-name'),
                                          controller: _name,
                                          enabled: editable,
                                          validator: required,
                                          decoration: InputDecoration(
                                              labelText: t('Material name',
                                                  'اسم المادة'))),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          key: const ValueKey('raw-sku'),
                                          controller: _sku,
                                          enabled: editable,
                                          validator: required,
                                          decoration: InputDecoration(
                                              labelText: t('Raw SKU',
                                                  'رمز المادة الخام'))),
                                      const SizedBox(height: 16),
                                      Text(
                                          '${t('Fixed base stock unit', 'وحدة المخزون الأساسية الثابتة')}: ${material.unit}'),
                                      const SizedBox(height: 8),
                                      Text(t(
                                          'Standard g/kg and ml/L conversions keep their dimensions. Packaging relationships belong only to this material; liters and kilograms have no automatic relationship.',
                                          'تحويلات g/kg وml/L تبقى ضمن نفس نوع القياس. علاقات التعبئة خاصة بهذه المادة ولا يُفترض تحويل تلقائي بين اللتر والكيلوغرام.')),
                                      const SizedBox(height: 16),
                                      for (final row in _conversions)
                                        Card(
                                            key: ValueKey(row['id']),
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      TextFormField(
                                                          key: ValueKey(
                                                              '${row['id']}-unit'),
                                                          initialValue:
                                                              row['unit']
                                                                  as String,
                                                          enabled: editable,
                                                          validator: required,
                                                          onChanged: (v) =>
                                                              row['unit'] = v,
                                                          decoration: InputDecoration(
                                                              labelText: t(
                                                                  'Purchase / consumption unit',
                                                                  'وحدة الشراء / الاستهلاك'))),
                                                      for (final field in [
                                                        'numerator',
                                                        'denominator'
                                                      ])
                                                        TextFormField(
                                                            key: ValueKey(
                                                                '${row['id']}-$field'),
                                                            initialValue: row[field]
                                                                .toString(),
                                                            enabled: editable,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            onChanged: (v) =>
                                                                row[field] =
                                                                    int.tryParse(
                                                                        Money.normalize(
                                                                            v)),
                                                            decoration: InputDecoration(
                                                                labelText: field ==
                                                                        'numerator'
                                                                    ? t('Base units: numerator',
                                                                        'الوحدات الأساسية: البسط')
                                                                    : t('Entered units: denominator', 'وحدات الإدخال: المقام')),
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
                                                          onChanged: editable
                                                              ? (v) => setState(
                                                                  () => row[
                                                                      'allowFraction'] = v)
                                                              : null),
                                                      Text(
                                                          '${t('Revision', 'الإصدار')}: ${row['revision']}'),
                                                      TextButton.icon(
                                                          onPressed: editable
                                                              ? () => setState(() =>
                                                                  _conversions
                                                                      .remove(
                                                                          row))
                                                              : null,
                                                          icon: const Icon(Icons
                                                              .delete_outline),
                                                          label: Text(t(
                                                              'Remove unit',
                                                              'إزالة الوحدة'))),
                                                    ]))),
                                      TextButton.icon(
                                          key: const ValueKey(
                                              'raw-add-conversion'),
                                          onPressed: editable
                                              ? () => setState(
                                                  () => _conversions.add({
                                                        'id': RecordId.create(),
                                                        'unit': '',
                                                        'numerator': 1,
                                                        'denominator': 1,
                                                        'revision': 1,
                                                        'allowFraction': true
                                                      }))
                                              : null,
                                          icon: const Icon(Icons.add),
                                          label: Text(t('Add conversion',
                                              'إضافة تحويل'))),
                                      Text(t(
                                          'Changing a conversion creates a new revision. Posted receipts retain their original quantities and factors.',
                                          'تعديل التحويل ينشئ إصداراً جديداً. تحتفظ الاستلامات المسجلة بكمياتها ومعاملاتها الأصلية.')),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                          key: const ValueKey(
                                              'raw-save-conversions'),
                                          onPressed: editable
                                              ? () => _save(material.unit)
                                              : null,
                                          icon: const Icon(Icons.check),
                                          label: Text(t('Save material & units',
                                              'حفظ المادة والوحدات'))),
                                      if (_error != null)
                                        Text(_error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                      if (_saving)
                                        const LinearProgressIndicator(),
                                      const SizedBox(height: 24),
                                      Text(
                                          t('Raw stock movements',
                                              'حركات المواد الخام'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      for (final movement in warehouse
                                          .transactions
                                          .where((m) =>
                                              m.materialId == material.id)
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
                                                          '${movement.type} • ${movement.quantity} ${material.unit}'),
                                                      Text(movement.date
                                                          .toLocal()
                                                          .toString()),
                                                      if (movement.documentId !=
                                                          null)
                                                        Text(
                                                            '${t('Document ID', 'معرّف المستند')}: ${movement.documentId}')
                                                    ]))),
                                    ]))))));
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    super.dispose();
  }
}
