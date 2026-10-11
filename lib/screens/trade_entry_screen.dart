import '../models/trade_line.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../services/money.dart';
import 'parties_screen.dart';
import '../services/record_id.dart';
import '../widgets/storage_status.dart';

class TradeEntryScreen extends StatefulWidget {
  const TradeEntryScreen({super.key, required this.purchase, this.productName});
  final bool purchase;
  final String? productName;
  @override
  State<TradeEntryScreen> createState() => _TradeEntryScreenState();
}

class _TradeEntryScreenState extends State<TradeEntryScreen> {
  final List<TradeInput> _extra = [];
  final _form = GlobalKey<FormState>();
  final _party = TextEditingController();
  final _item = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _paid = TextEditingController(text: '0');
  final _reference = TextEditingController();
  final _requestId = RecordId.create();
  String? _currency;
  String? _partyId;
  String _unit = 'Kilogram';
  String? _product;
  String? _error;
  bool _posting = false;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String unitLabel(String unit) => switch (unit) {
        'Kilogram' => t('Kilogram', 'كيلوغرام'),
        'Gram' => t('Gram', 'غرام'),
        'Liter' => t('Liter', 'لتر'),
        'Gallon' => t('Gallon', 'غالون'),
        'Piece' => t('Piece', 'قطعة'),
        _ => unit,
      };
  @override
  void initState() {
    super.initState();
    _product = widget.productName;
    if (_product != null) {
      final products = context
          .read<ShopProvider>()
          .products
          .where((p) => p.name == _product);
      if (products.isNotEmpty) {
        _price.text = products.first.unitPrice.toStringAsFixed(2);
      }
    }
  }

  int? get _total {
    try {
      return Money.total(
              Money.quantity(_quantity.text), Money.parse(_price.text)) +
          _extra.fold(
              0, (sum, l) => sum + Money.total(l.quantity, l.unitPriceMinor));
    } catch (_) {
      return null;
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? t('Required', 'مطلوب') : null;
  String? _amount(String? value) {
    try {
      Money.parse(value ?? '');
      return null;
    } catch (_) {
      return t('Use a nonnegative amount with up to 2 decimals',
          'أدخل مبلغاً موجباً أو صفراً بمنزلتين عشريتين كحد أقصى');
    }
  }

  Future<void> _save() async {
    if (_posting || !_form.currentState!.validate()) return;
    final warehouse = context.read<WarehouseProvider>();
    final shop = context.read<ShopProvider>();
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final quantity = Money.quantity(_quantity.text);
      final price = Money.parse(_price.text);
      final paid = Money.parse(_paid.text);
      if (widget.purchase) {
        await warehouse.receivePurchases([
          TradeInput(
              name: _item.text,
              quantity: quantity,
              unit: _unit,
              unitPriceMinor: price),
          ..._extra
        ],
            supplier: _party.text,
            partyId: _partyId,
            currency: _currency!,
            paidMinor: paid,
            reference: _reference.text,
            requestId: _requestId);
      } else {
        await shop.sellProducts([
          TradeInput(
              name: _product!, quantity: quantity, unitPriceMinor: price),
          ..._extra
        ],
            customer: _party.text,
            partyId: _partyId,
            currency: _currency!,
            paidMinor: paid,
            reference: _reference.text,
            requestId: _requestId);
      }
      if (mounted) {
        setState(() => _posting = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _posting = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _addItem() async {
    String name = '', quantity = '', price = '', unit = 'Kilogram';
    final form = GlobalKey<FormState>();
    final shop = context.read<ShopProvider>();
    final line = await showDialog<TradeInput>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: Text(t('Add item', 'إضافة صنف')),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Form(
                                key: form,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.purchase)
                                        TextFormField(
                                            decoration: InputDecoration(
                                                labelText: t('Material name',
                                                    'اسم المادة')),
                                            onChanged: (v) => name = v,
                                            validator: _required)
                                      else
                                        DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                                labelText:
                                                    t('Product', 'المنتج')),
                                            validator: _required,
                                            items: shop.products
                                                .map((p) => DropdownMenuItem(
                                                    value: p.name,
                                                    child: Text(p.name)))
                                                .toList(),
                                            onChanged: (v) => name = v ?? ''),
                                      if (widget.purchase)
                                        TextFormField(
                                            initialValue: unit,
                                            decoration: InputDecoration(
                                                labelText: t('Stock unit',
                                                    'وحدة المخزون')),
                                            onChanged: (v) => unit = v,
                                            validator: _required),
                                      TextFormField(
                                          decoration: InputDecoration(
                                              labelText:
                                                  t('Quantity', 'الكمية')),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          onChanged: (v) => quantity = v,
                                          validator: (v) {
                                            try {
                                              Money.quantity(v ?? '');
                                              return null;
                                            } catch (_) {
                                              return t(
                                                  'Enter a positive quantity',
                                                  'أدخل كمية موجبة');
                                            }
                                          }),
                                      TextFormField(
                                          decoration: InputDecoration(
                                              labelText: t(
                                                  'Unit price', 'سعر الوحدة')),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          onChanged: (v) => price = v,
                                          validator: _amount)
                                    ])))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t('Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: () {
                            if (form.currentState!.validate()) {
                              Navigator.pop(
                                  ctx,
                                  TradeInput(
                                      name: name.trim(),
                                      unit: unit.trim(),
                                      quantity: Money.quantity(quantity),
                                      unitPriceMinor: Money.parse(price)));
                            }
                          },
                          child: Text(t('Add item', 'إضافة صنف')))
                    ])));
    if (line != null && mounted) setState(() => _extra.add(line));
  }

  Widget _field(TextEditingController controller, String label,
          {bool amount = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: controller,
              enabled: !_posting,
              decoration: InputDecoration(labelText: label),
              keyboardType: amount
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              validator: amount ? _amount : _required,
              onChanged: (_) => setState(() {
                    if (controller == _party) _partyId = null;
                  })));

  @override
  Widget build(BuildContext context) {
    final warehouse = context.watch<WarehouseProvider>();
    final shop = context.watch<ShopProvider>();
    final loaded = widget.purchase ? warehouse.isLoaded : shop.isLoaded;
    final units = [
      'Kilogram',
      'Gram',
      'Liter',
      'Gallon',
      'Piece',
      ...warehouse.materials.map((m) => m.unit)
    ].where((u) => u.isNotEmpty).toSet().toList();
    return PopScope(
        canPop: !_posting,
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.purchase
                  ? t('Receive purchase', 'استلام مشتريات')
                  : t('Record sale', 'تسجيل بيع')),
              backgroundColor: widget.purchase ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: !_posting),
          body: !loaded
              ? StorageStatus(
                  error: widget.purchase ? warehouse.loadError : shop.loadError,
                  onRetry:
                      widget.purchase ? warehouse.initialize : shop.initialize)
              : Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Form(
                          key: _form,
                          child: ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                _field(
                                    _party,
                                    widget.purchase
                                        ? t('Supplier', 'المورد')
                                        : t('Customer', 'العميل')),
                                DropdownButtonFormField<String>(
                                    key: ValueKey(_partyId),
                                    initialValue: (widget.purchase
                                                ? warehouse.parties
                                                : shop.parties)
                                            .any((p) =>
                                                p.id == _partyId && p.active)
                                        ? _partyId
                                        : null,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: t(
                                            'Choose saved record (optional)',
                                            'اختيار سجل محفوظ (اختياري)')),
                                    items: (widget.purchase
                                            ? warehouse.parties
                                            : shop.parties)
                                        .where((p) => p.active)
                                        .map((p) => DropdownMenuItem(
                                            value: p.id, child: Text(p.name)))
                                        .toList(),
                                    onChanged: _posting
                                        ? null
                                        : (id) => setState(() {
                                              _partyId = id;
                                              _party.text = (widget.purchase
                                                      ? warehouse.parties
                                                      : shop.parties)
                                                  .firstWhere((p) => p.id == id)
                                                  .name;
                                            })),
                                TextButton.icon(
                                    onPressed: _posting
                                        ? null
                                        : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => PartiesScreen(
                                                    initialTab: widget.purchase
                                                        ? 1
                                                        : 0))),
                                    icon: const Icon(Icons.people_outline),
                                    label: Text(t('Customers & suppliers',
                                        'العملاء والموردون'))),
                                const SizedBox(height: 16),
                                if (widget.purchase) ...[
                                  TextFormField(
                                      controller: _item,
                                      enabled: !_posting,
                                      validator: _required,
                                      decoration: InputDecoration(
                                          labelText:
                                              t('Material name', 'اسم المادة')),
                                      onChanged: (name) {
                                        final matching = warehouse.materials
                                            .where(
                                                (m) => m.name == name.trim());
                                        if (matching.isNotEmpty &&
                                            matching.first.unit.isNotEmpty) {
                                          setState(() =>
                                              _unit = matching.first.unit);
                                        }
                                      }),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      key: ValueKey(_unit),
                                      initialValue: _unit,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText:
                                              t('Stock unit', 'وحدة المخزون')),
                                      items: units
                                          .map((u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(unitLabel(u))))
                                          .toList(),
                                      onChanged: _posting
                                          ? null
                                          : (u) => setState(() => _unit = u!)),
                                ] else ...[
                                  DropdownButtonFormField<String>(
                                      initialValue: _product,
                                      isExpanded: true,
                                      validator: _required,
                                      decoration: InputDecoration(
                                          labelText: t('Product', 'المنتج')),
                                      items: shop.products
                                          .map((p) => DropdownMenuItem(
                                              value: p.name,
                                              child: Text(p.name)))
                                          .toList(),
                                      onChanged: _posting
                                          ? null
                                          : (name) => setState(() {
                                                _product = name;
                                                _price.text = shop.products
                                                    .firstWhere(
                                                        (p) => p.name == name)
                                                    .unitPrice
                                                    .toStringAsFixed(2);
                                              })),
                                  if (_product != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            '${t('Available', 'المتاح')}: ${shop.getStock(_product!)} ${shop.products.firstWhere((p) => p.name == _product).unit}')),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _quantity,
                                    enabled: !_posting,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                        labelText: t('Quantity', 'الكمية')),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      try {
                                        Money.total(
                                            Money.quantity(value ?? ''), 0);
                                        return null;
                                      } catch (_) {
                                        return t(
                                            'Enter a positive quantity (up to 6 decimals)',
                                            'أدخل كمية موجبة (حتى ٦ منازل عشرية)');
                                      }
                                    }),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                    initialValue: _currency,
                                    validator: _required,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: t('Currency', 'العملة')),
                                    items: Money.currencies
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: _posting
                                        ? null
                                        : (c) => setState(() => _currency = c)),
                                const SizedBox(height: 16),
                                _field(_price, t('Unit price', 'سعر الوحدة'),
                                    amount: true),
                                for (final line in _extra)
                                  ListTile(
                                      title: Text(line.name),
                                      subtitle: Text(
                                          '${line.quantity} • ${Money.format(Money.total(line.quantity, line.unitPriceMinor))}'),
                                      trailing: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: _posting
                                              ? null
                                              : () => setState(
                                                  () => _extra.remove(line)))),
                                TextButton.icon(
                                    onPressed: _posting ? null : _addItem,
                                    icon: const Icon(Icons.add),
                                    label: Text(t('Add item', 'إضافة صنف'))),
                                _field(
                                    _paid,
                                    widget.purchase
                                        ? t('Amount paid to supplier',
                                            'المبلغ المدفوع للمورد')
                                        : t('Amount received',
                                            'المبلغ المقبوض'),
                                    amount: true),
                                TextFormField(
                                    controller: _reference,
                                    enabled: !_posting,
                                    decoration: InputDecoration(
                                        labelText: t('Reference (optional)',
                                            'مرجع (اختياري)'))),
                                const SizedBox(height: 20),
                                Text(
                                    _total == null
                                        ? t('Enter quantity and unit price',
                                            'أدخل الكمية وسعر الوحدة')
                                        : '${t('Total', 'الإجمالي')}: ${Money.format(_total!)} ${_currency ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                                const SizedBox(height: 12),
                                Text(t(
                                    'Prices and payments use the selected currency. Later payments are recorded from document history.',
                                    'الأسعار والدفعات بالعملة المحددة. تُسجل الدفعات اللاحقة من سجل المستندات.')),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                    onPressed: _posting ? null : _save,
                                    icon: const Icon(Icons.check),
                                    label: Text(
                                        t('Post document', 'تسجيل المستند'))),
                                if (_posting) const LinearProgressIndicator(),
                              ])))),
        ));
  }

  @override
  void dispose() {
    for (final c in [_party, _item, _quantity, _price, _paid, _reference]) {
      c.dispose();
    }
    super.dispose();
  }
}
