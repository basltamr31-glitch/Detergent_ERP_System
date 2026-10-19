import 'trade_entry_screen.dart';
import 'business_documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/storage_status.dart';
import '../l10n/app_localizations.dart';
import '../providers/shop_provider.dart';
import '../services/access_control.dart';
import 'finished_product_screen.dart';
import 'trading_purchase_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  String t(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  String _translateUnit(String unitKey, AppLocalizations loc) {
    if (unitKey.isEmpty) return '';
    switch (unitKey) {
      case 'Piece':
        return loc.unitPiece;
      case 'Box':
        return loc.unitBox;
      case 'Carton':
        return loc.unitCarton;
      case 'Package':
        return loc.unitPackage;
      default:
        return unitKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            t(context, 'Finished goods & trading', 'المنتجات الجاهزة والتجارة'),
            maxLines: 2),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              key: const ValueKey('new-finished-product'),
              icon: const Icon(Icons.add_box_outlined),
              tooltip: t(context, 'Register product (zero stock)',
                  'تسجيل منتج (رصيد صفر)'),
              onPressed: context.watch<ShopProvider>().isSaving ||
                      !AccessControl.allows('warehouse')
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FinishedProductScreen()))),
          IconButton(
              key: const ValueKey('new-trading-purchase'),
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: t(
                  context, 'Receive trading purchase', 'استلام مشتريات تجارية'),
              onPressed: context.watch<ShopProvider>().isSaving ||
                      !AccessControl.allows('warehouse')
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TradingPurchaseScreen()))),
          IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'سجل المبيعات'
                  : 'Sales history',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const BusinessDocumentsScreen(initialTab: 2))))
        ],
      ),
      body: Consumer<ShopProvider>(
        builder: (context, provider, child) {
          if (!provider.isLoaded) {
            return StorageStatus(
                error: provider.loadError, onRetry: provider.initialize);
          }
          final items = provider.products;
          if (items.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      Text(
                          t(context, 'Register a finished product to begin',
                              'سجّل منتجاً جاهزاً للبدء'),
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                          t(
                              context,
                              'Manufactured and purchased stock share one SKU, while each receipt keeps its source.',
                              'يجتمع المخزون المصنع والمشترى ضمن صنف واحد مع حفظ مصدر كل استلام.'),
                          textAlign: TextAlign.center),
                    ])));
          }
          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                                '${t(context, 'SKU', 'رمز الصنف')}: ${item.sku}'),
                            Text(
                                '${localizations.availableQuantity}: ${item.quantity.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} ${_translateUnit(item.unit, localizations)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                                '${t(context, 'Reference sale price', 'سعر البيع المرجعي')}: ${item.unitPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 4),
                            TextButton.icon(
                                key: ValueKey('product-details-${item.id}'),
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => FinishedProductScreen(
                                            productId: item.id))),
                                icon: const Icon(Icons.layers_outlined),
                                label: Text(t(
                                    context,
                                    'Sources, costs & movements',
                                    'المصادر والتكاليف والحركات'))),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.point_of_sale,
                            size: 18, color: Colors.white),
                        label: Text(localizations.sellBtn,
                            style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: !context.watch<ShopProvider>().isLoaded ||
                                context.watch<ShopProvider>().isSaving ||
                                !AccessControl.allows('sales')
                            ? null
                            : () => _showSellDialog(
                                context, provider, item.name, localizations),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        tooltip:
            t(context, 'Opening stock / adjustment', 'رصيد افتتاحي / تسوية'),
        onPressed: !context.watch<ShopProvider>().isLoaded ||
                context.watch<ShopProvider>().isSaving ||
                !AccessControl.allows('warehouse')
            ? null
            : () => _showAddStockDialog(
                context,
                Provider.of<ShopProvider>(context, listen: false),
                localizations),
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, ShopProvider provider,
      AppLocalizations localizations) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitPriceController = TextEditingController();
    String selectedUnit = 'Piece';
    final units = ['Piece', 'Box', 'Carton', 'Package'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final qty = double.tryParse(quantityController.text) ?? 0.0;
          final price = double.tryParse(unitPriceController.text) ?? 0.0;
          final total = qty * price;

          return AlertDialog(
            title: Text(t(
                context, 'Opening stock / adjustment', 'رصيد افتتاحي / تسوية')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t(
                      context,
                      'Use a trading purchase for supplier products. This adds an opening or adjustment layer with an unknown acquisition cost.',
                      'استخدم المشتريات التجارية لمنتجات الموردين. يضيف هذا رصيداً افتتاحياً أو تسوية بتكلفة شراء غير معروفة.')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: localizations.productNameLabelShop),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUnit,
                    items: units
                        .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(_translateUnit(u, localizations))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedUnit = val);
                    },
                    decoration:
                        InputDecoration(labelText: localizations.unitLabel),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: localizations.quantity),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: unitPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: t(context, 'Reference sale price (not cost)',
                            'سعر بيع مرجعي (ليس تكلفة)')),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 15),
                  Text(
                      '${t(context, 'Quantity × reference price (not valuation)', 'الكمية × السعر المرجعي (ليس تقييماً للمخزون)')}: ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations.cancelBtn),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      quantityController.text.isNotEmpty) {
                    if (qty > 0) {
                      try {
                        await provider.addProduct(
                            nameController.text, qty, selectedUnit, price);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())));
                        }
                      }
                    }
                  }
                },
                child: Text(t(context, 'Post opening / adjustment',
                    'تسجيل رصيد / تسوية')),
              ),
            ],
          );
        });
      },
    );
  }

  void _showSellDialog(BuildContext context, ShopProvider provider,
      String productName, AppLocalizations localizations) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                TradeEntryScreen(purchase: false, productName: productName)));
  }
}
