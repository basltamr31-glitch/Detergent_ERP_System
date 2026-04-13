import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/shop_provider.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  String _translateUnit(String unitKey, AppLocalizations loc) {
    if (unitKey.isEmpty) return '';
    switch (unitKey) {
      case 'Piece': return loc.unitPiece;
      case 'Box': return loc.unitBox;
      case 'Carton': return loc.unitCarton;
      case 'Package': return loc.unitPackage;
      default: return unitKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.shopTitle),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ShopProvider>(
        builder: (context, provider, child) {
          final items = provider.products;
          if (items.isEmpty) {
            return Center(child: Text(localizations.noItemsInStock));
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
                            Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('${localizations.availableQuantity}: ${item.quantity.toStringAsFixed(2)} ${_translateUnit(item.unit, localizations)}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${localizations.unitPriceLabel}: ${item.unitPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('${localizations.totalValueLabel}: ${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.point_of_sale, size: 18, color: Colors.white),
                        label: Text(localizations.sellBtn, style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _showSellDialog(context, provider, item.name, localizations),
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
        tooltip: localizations.addStock,
        onPressed: () => _showAddStockDialog(context, Provider.of<ShopProvider>(context, listen: false), localizations),
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, ShopProvider provider, AppLocalizations localizations) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitPriceController = TextEditingController();
    String selectedUnit = 'Piece';
    final units = ['Piece', 'Box', 'Carton', 'Package'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final qty = double.tryParse(quantityController.text) ?? 0.0;
            final price = double.tryParse(unitPriceController.text) ?? 0.0;
            final total = qty * price;

            return AlertDialog(
              title: Text(localizations.addProductToShop),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: localizations.productNameLabelShop),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      items: units.map((u) => DropdownMenuItem(value: u, child: Text(_translateUnit(u, localizations)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedUnit = val);
                      },
                      decoration: InputDecoration(labelText: localizations.unitLabel),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: localizations.quantity),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: unitPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: localizations.unitPriceLabel),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 15),
                    Text('${localizations.totalValueLabel}: ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.cancelBtn),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty && quantityController.text.isNotEmpty) {
                      if (qty > 0) {
                        provider.addProduct(nameController.text, qty, selectedUnit, price);
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Text(localizations.addStock),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSellDialog(BuildContext context, ShopProvider provider, String productName, AppLocalizations localizations) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(localizations.sellProductFromShop),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: localizations.quantity),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(localizations.cancelBtn),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text) ?? 0.0;
                if (quantity > 0) {
                  try {
                    provider.sellProduct(productName, quantity);
                    Navigator.pop(ctx);
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(localizations.sellBtn, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
