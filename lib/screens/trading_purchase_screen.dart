import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/trade_line.dart';
import '../providers/shop_provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/access_control.dart';
import '../services/inventory_coordinator.dart';
import '../services/inventory_units.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../services/trading_purchase_service.dart';
import '../widgets/storage_status.dart';
import 'finished_product_screen.dart';
import 'parties_screen.dart';

class TradingPurchaseScreen extends StatefulWidget {
  const TradingPurchaseScreen({super.key});
  @override
  State<TradingPurchaseScreen> createState() => _TradingPurchaseScreenState();
}

class _TradingPurchaseScreenState extends State<TradingPurchaseScreen> {
  final _form = GlobalKey<FormState>();
  final _rows = [_PurchaseRow()];
  final _paid = TextEditingController(text: '0'),
      _reference = TextEditingController(),
      _expiry = TextEditingController();
  final _requestId = RecordId.create();
  String? _supplierId;
  String _currency = 'USD';
  bool _saving = false;
  String? _error;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  Product? _product(_PurchaseRow row, ShopProvider shop) {
    final matches = shop.products.where((p) => p.id == row.productId).toList();
    return matches.isEmpty ? null : matches.single;
  }

  List<String> _units(Product product) {
    final units = {
      product.unit,
      ...product.unitConversions.map((u) => u['unit'] as String)
    };
    for (final unit in [
      'g',
      'Gram',
      'kg',
      'Kilogram',
      'ml',
      'Milliliter',
      'L',
      'Liter'
    ]) {
      try {
        InventoryUnits.toBase(1, unit, product.unit, product.unitConversions);
        units.add(unit);
      } catch (_) {/* Undefined units stay unavailable. */}
    }
    return units.toList();
  }

  String? _money(String? value) {
    try {
      Money.parse(value ?? '');
      return null;
    } catch (_) {
      return t('Use a nonnegative amount with at most 2 decimals',
          'أدخل مبلغاً موجباً أو صفراً بمنزلتين عشريتين');
    }
  }

  int? get _total {
    try {
      return _rows.fold<int>(
          0,
          (sum, row) =>
              sum +
              Money.total(Money.quantity(row.quantity.text),
                  Money.parse(row.price.text)));
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final warehouse = context.read<WarehouseProvider>(),
          shop = context.read<ShopProvider>();
      final supplier =
          warehouse.parties.firstWhere((p) => p.id == _supplierId && p.active);
      final rows = _rows.map((row) {
        final product = _product(row, shop)!;
        return TradeInput(
            itemId: product.id,
            name: product.name,
            unit: row.unit!,
            quantity: Money.quantity(row.quantity.text),
            unitPriceMinor: Money.parse(row.price.text));
      }).toList();
      await TradingPurchaseService.receive(warehouse, shop, rows,
          supplier: supplier.name,
          partyId: supplier.id,
          currency: _currency,
          paidMinor: Money.parse(_paid.text),
          reference: _reference.text,
          expiry: _expiry.text.trim(),
          requestId: _requestId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _row(_PurchaseRow row, int index, ShopProvider shop, bool busy) {
    final product = _product(row, shop);
    String? preview;
    if (product != null && row.quantity.text.isNotEmpty) {
      try {
        final base = InventoryUnits.toBase(Money.quantity(row.quantity.text),
            row.unit!, product.unit, product.unitConversions);
        preview =
            '${t('Stock receipt', 'كمية الاستلام بالمخزون')}: ${base.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} ${product.unit}';
      } catch (_) {
        preview = t('Check quantity and this product\'s defined conversion.',
            'تحقق من الكمية والتحويل المعرّف لهذا المنتج.');
      }
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${t('Item', 'الصنف')} ${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium)),
                if (_rows.length > 1)
                  IconButton(
                      tooltip: t('Remove item', 'إزالة الصنف'),
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                _rows.remove(row);
                                row.dispose();
                              }),
                      icon: const Icon(Icons.close))
              ]),
              DropdownButtonFormField<String>(
                  key: ValueKey('trading-product-${row.id}'),
                  initialValue: row.productId,
                  isExpanded: true,
                  validator: (v) =>
                      v == null ? t('Select a product', 'اختر منتجاً') : null,
                  decoration: InputDecoration(
                      labelText: t('Finished product / SKU',
                          'المنتج الجاهز / رمز الصنف')),
                  items: shop.products
                      .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.sku} • ${p.name}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: busy
                      ? null
                      : (id) => setState(() {
                            row.productId = id;
                            row.unit = _product(row, shop)!.unit;
                          })),
              const SizedBox(height: 12),
              if (product != null)
                DropdownButtonFormField<String>(
                    key: ValueKey('${row.id}:${product.id}:${row.unit}'),
                    initialValue: row.unit,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: t('Invoice unit', 'وحدة الفاتورة')),
                    items: _units(product)
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged:
                        busy ? null : (v) => setState(() => row.unit = v)),
              const SizedBox(height: 12),
              TextFormField(
                  key: ValueKey('trading-quantity-${row.id}'),
                  controller: row.quantity,
                  enabled: !busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: t('Invoice quantity', 'كمية الفاتورة')),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    try {
                      if (product == null || row.unit == null) {
                        return t('Select a product first', 'اختر المنتج أولاً');
                      }
                      InventoryUnits.toBase(Money.quantity(v ?? ''), row.unit!,
                          product.unit, product.unitConversions);
                      return null;
                    } catch (_) {
                      return t(
                          'Use a positive quantity and a valid conversion (up to 6 decimals)',
                          'أدخل كمية موجبة وتحويلاً صحيحاً (حتى ٦ منازل عشرية)');
                    }
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  key: ValueKey('trading-price-${row.id}'),
                  controller: row.price,
                  enabled: !busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: t('Purchase price per invoice unit',
                          'سعر الشراء لكل وحدة فاتورة')),
                  validator: _money,
                  onChanged: (_) => setState(() {})),
              if (preview != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(preview)),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = context.watch<WarehouseProvider>(),
        shop = context.watch<ShopProvider>();
    final busy = _saving ||
        warehouse.isSaving ||
        shop.isSaving ||
        InventoryCoordinator.busy;
    final total = _total;
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            appBar: AppBar(
                title: Text(
                    t('Receive trading purchase', 'استلام مشتريات تجارية')),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            body: !warehouse.isLoaded
                ? StorageStatus(
                    error: warehouse.loadError, onRetry: warehouse.initialize)
                : !shop.isLoaded
                    ? StorageStatus(
                        error: shop.loadError, onRetry: shop.initialize)
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Form(
                                key: _form,
                                child: ListView(
                                    padding: const EdgeInsets.all(20),
                                    children: [
                                      Text(t(
                                          'Supplier products go directly into the finished-goods warehouse. Raw-material stock and manufacturing are separate.',
                                          'تدخل منتجات المورد مباشرة إلى مستودع المنتجات الجاهزة. مخزون المواد الخام وعمليات التصنيع منفصلان.')),
                                      const SizedBox(height: 16),
                                      DropdownButtonFormField<String>(
                                          key: const ValueKey(
                                              'trading-supplier'),
                                          initialValue: _supplierId,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                              labelText:
                                                  t('Supplier', 'المورد')),
                                          items: warehouse.parties
                                              .where((p) => p.active)
                                              .map((p) => DropdownMenuItem(
                                                  value: p.id,
                                                  child: Text(p.name,
                                                      overflow: TextOverflow
                                                          .ellipsis)))
                                              .toList(),
                                          validator: (v) => v == null
                                              ? t('Select an active supplier',
                                                  'اختر مورداً نشطاً')
                                              : null,
                                          onChanged: busy
                                              ? null
                                              : (v) => setState(
                                                  () => _supplierId = v)),
                                      Wrap(spacing: 8, children: [
                                        TextButton.icon(
                                            onPressed: busy ||
                                                    !AccessControl.allows(
                                                        'partners')
                                                ? null
                                                : () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const PartiesScreen(
                                                                initialTab:
                                                                    1))),
                                            icon: const Icon(
                                                Icons.people_outline),
                                            label: Text(t('Manage suppliers',
                                                'إدارة الموردين'))),
                                        TextButton.icon(
                                            onPressed: busy ||
                                                    !AccessControl.allows(
                                                        'warehouse')
                                                ? null
                                                : () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const FinishedProductScreen())),
                                            icon: const Icon(
                                                Icons.add_box_outlined),
                                            label: Text(t('Register product',
                                                'تسجيل منتج')))
                                      ]),
                                      if (shop.products.isEmpty)
                                        Text(t(
                                            'Register a finished SKU before receiving its purchase.',
                                            'سجّل صنفاً جاهزاً قبل استلام مشترياته.')),
                                      for (var index = 0;
                                          index < _rows.length;
                                          index++)
                                        _row(_rows[index], index, shop, busy),
                                      TextButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => setState(() =>
                                                  _rows.add(_PurchaseRow())),
                                          icon: const Icon(Icons.add),
                                          label:
                                              Text(t('Add item', 'إضافة صنف'))),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                          key: const ValueKey(
                                              'trading-currency'),
                                          initialValue: _currency,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                              labelText: t('Invoice currency',
                                                  'عملة الفاتورة')),
                                          items: Money.currencies
                                              .map((c) => DropdownMenuItem(
                                                  value: c, child: Text(c)))
                                              .toList(),
                                          onChanged: busy
                                              ? null
                                              : (v) => setState(
                                                  () => _currency = v!)),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          controller: _paid,
                                          enabled: !busy,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                              labelText: t('Amount paid',
                                                  'المبلغ المدفوع')),
                                          validator: (v) {
                                            final error = _money(v);
                                            if (error != null) return error;
                                            return total != null &&
                                                    Money.parse(v!) > total
                                                ? t('Payment cannot exceed invoice total',
                                                    'لا يمكن أن تتجاوز الدفعة إجمالي الفاتورة')
                                                : null;
                                          }),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          controller: _reference,
                                          enabled: !busy,
                                          decoration: InputDecoration(
                                              labelText: t(
                                                  'Supplier invoice / reference',
                                                  'فاتورة المورد / المرجع'))),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          controller: _expiry,
                                          enabled: !busy,
                                          decoration: InputDecoration(
                                              labelText: t(
                                                  'Expiry YYYY-MM-DD (optional, all receipt lines)',
                                                  'الصلاحية YYYY-MM-DD (اختياري لجميع الأصناف)')),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return null;
                                            }
                                            final parsed =
                                                DateTime.tryParse(v.trim());
                                            return parsed == null ||
                                                    parsed
                                                            .toIso8601String()
                                                            .substring(0, 10) !=
                                                        v.trim()
                                                ? t('Use YYYY-MM-DD',
                                                    'استخدم YYYY-MM-DD')
                                                : null;
                                          }),
                                      const SizedBox(height: 16),
                                      Text(
                                          total == null
                                              ? t('Enter quantities and purchase prices',
                                                  'أدخل الكميات وأسعار الشراء')
                                              : '${t('Invoice total', 'إجمالي الفاتورة')}: ${Money.format(total)} $_currency',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                          key: const ValueKey(
                                              'receive-trading-purchase'),
                                          onPressed: busy ||
                                                  !AccessControl.allows(
                                                      'warehouse')
                                              ? null
                                              : _save,
                                          icon: const Icon(
                                              Icons.inventory_2_outlined),
                                          label: Text(t('Post trading receipt',
                                              'تسجيل استلام المشتريات التجارية'))),
                                      if (_error != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(_error!,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error))),
                                      if (_saving)
                                        const LinearProgressIndicator(),
                                    ]))))));
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _paid.dispose();
    _reference.dispose();
    _expiry.dispose();
    super.dispose();
  }
}

class _PurchaseRow {
  final id = RecordId.create();
  String? productId, unit;
  final quantity = TextEditingController(), price = TextEditingController();
  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}
