import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/warehouse_provider.dart';
import '../models/manufactured_product.dart';
import 'package:intl/intl.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  String _translateUnit(String unitKey, AppLocalizations loc) {
    if (unitKey.isEmpty) return '';
    switch (unitKey) {
      case 'Kilogram': return loc.unitKilogram;
      case 'Gram': return loc.unitGram;
      case 'Liter': return loc.unitLiter;
      case 'Gallon': return loc.unitGallon;
      case 'Piece': return loc.unitPiece;
      default: return unitKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.warehouseTitle),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
             icon: const Icon(Icons.precision_manufacturing, color: Colors.white),
             label: Text(localizations.manufactureBtn, style: const TextStyle(color: Colors.white)),
             onPressed: () => _showManufactureDialog(context, Provider.of<WarehouseProvider>(context, listen: false), localizations),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transactions',
            onPressed: () => _showTransactionsHistory(context, Provider.of<WarehouseProvider>(context, listen: false)),
          ),
        ],
      ),
      body: Consumer<WarehouseProvider>(
        builder: (context, provider, child) {
          final items = provider.materials;
          final mfgItems = provider.manufacturedProducts;
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _buildSummaryCard(context, provider, localizations),
              if (items.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(localizations.noItemsInStock)))
              else
                ...items.map((item) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text('${localizations.availableQuantity}: ${item.quantity.toStringAsFixed(2)} ${_translateUnit(item.unit, localizations)}'),
                              const SizedBox(height: 4),
                              Text('${localizations.unitPriceLabel}: ${item.unitPrice.toStringAsFixed(2)}'),
                              const SizedBox(height: 4),
                              Text('${localizations.totalPriceLabel}: ${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          tooltip: localizations.removeStock,
                          onPressed: () => _showRemoveStockDialog(context, provider, item.name, localizations),
                        ),
                      ],
                    ),
                  ),
                )),
              
              if (mfgItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(height: 2, thickness: 2),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(localizations.manufacturedProductsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ),
                const SizedBox(height: 10),
                ...mfgItems.map((mfg) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Colors.indigo),
                    title: Text(mfg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${localizations.producedQuantity}: ${mfg.quantity.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(mfg.date)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: localizations.editBtn,
                          onPressed: () => _showEditManufactureDialog(context, provider, mfg, localizations),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: localizations.deleteBtn,
                          onPressed: () => _showDeleteManufactureDialog(context, provider, mfg, localizations),
                        ),
                      ],
                    )
                  )
                ))
              ]
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        tooltip: localizations.addStock,
        onPressed: () => _showAddStockDialog(context, Provider.of<WarehouseProvider>(context, listen: false), localizations),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, WarehouseProvider provider, AppLocalizations localizations) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.inventorySummary, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${localizations.totalMaterials}: ${provider.totalMaterials}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const Icon(Icons.inventory, size: 40, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, WarehouseProvider provider, AppLocalizations localizations) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitPriceController = TextEditingController();
    String selectedUnit = 'Kilogram';
    final units = ['Kilogram', 'Gram', 'Liter', 'Gallon', 'Piece'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final qty = double.tryParse(quantityController.text) ?? 0.0;
            final price = double.tryParse(unitPriceController.text) ?? 0.0;
            final total = qty * price;

            return AlertDialog(
              title: Text(localizations.addMaterialToWarehouse),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: localizations.materialName),
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
                    Text('${localizations.totalPriceLabel}: ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        provider.addMaterial(nameController.text, qty, selectedUnit, price);
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

  void _showManufactureDialog(BuildContext context, WarehouseProvider provider, AppLocalizations localizations) {
    if (provider.materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.noItemsInStock)));
      return;
    }

    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    
    final selectedMaterials = <String, double>{};
    final materialControllers = <String, TextEditingController>{};
    for (var m in provider.materials) {
      materialControllers[m.name] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.manufactureDialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: localizations.finalProductName),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: localizations.producedQuantity),
                      ),
                      const SizedBox(height: 20),
                      Text(localizations.selectRawMaterials, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...provider.materials.map((m) {
                        final isSelected = selectedMaterials.containsKey(m.name);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.name),
                          subtitle: isSelected 
                            ? TextField(
                                controller: materialControllers[m.name],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: localizations.materialUsedQuantity),
                                onChanged: (val) {
                                  selectedMaterials[m.name] = double.tryParse(val) ?? 0.0;
                                },
                              )
                            : Text('${localizations.availableQuantity}: ${m.quantity.toStringAsFixed(2)} ${_translateUnit(m.unit, localizations)}'),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedMaterials[m.name] = 0.0;
                              } else {
                                selectedMaterials.remove(m.name);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.cancelBtn),
                ),
                ElevatedButton(
                  onPressed: () {
                    final mfgQty = double.tryParse(quantityController.text) ?? 0.0;
                    if (nameController.text.isNotEmpty && mfgQty > 0 && selectedMaterials.isNotEmpty) {
                      bool valid = true;
                      for (var v in selectedMaterials.values) {
                        if (v <= 0) valid = false;
                      }
                      if (!valid) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ensure used quantities are greater than 0")));
                         return;
                      }

                      try {
                        provider.produceManufacturedProduct(nameController.text, mfgQty, selectedMaterials);
                        Navigator.pop(context);
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                      }
                    }
                  },
                  child: Text(localizations.confirmBtn),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showEditManufactureDialog(BuildContext context, WarehouseProvider provider, ManufacturedProduct oldMfg, AppLocalizations localizations) {
    if (provider.materials.isEmpty) return;

    final nameController = TextEditingController(text: oldMfg.name);
    final quantityController = TextEditingController(text: oldMfg.quantity.toString());
    
    final selectedMaterials = <String, double>{...oldMfg.rawMaterialsUsed};
    final materialControllers = <String, TextEditingController>{};
    for (var m in provider.materials) {
       materialControllers[m.name] = TextEditingController(text: selectedMaterials[m.name]?.toString() ?? "");
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.editManufactureTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: localizations.finalProductName),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: localizations.producedQuantity),
                      ),
                      const SizedBox(height: 20),
                      Text(localizations.selectRawMaterials, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...provider.materials.map((m) {
                        final isSelected = selectedMaterials.containsKey(m.name);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.name),
                          subtitle: isSelected 
                            ? TextField(
                                controller: materialControllers[m.name],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: localizations.materialUsedQuantity),
                                onChanged: (val) {
                                  selectedMaterials[m.name] = double.tryParse(val) ?? 0.0;
                                },
                              )
                            : Text('${localizations.availableQuantity}: ${m.quantity.toStringAsFixed(2)} ${_translateUnit(m.unit, localizations)}'),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedMaterials[m.name] = 0.0;
                              } else {
                                selectedMaterials.remove(m.name);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.cancelBtn),
                ),
                ElevatedButton(
                  onPressed: () {
                    final mfgQty = double.tryParse(quantityController.text) ?? 0.0;
                    if (nameController.text.isNotEmpty && mfgQty > 0 && selectedMaterials.isNotEmpty) {
                      bool valid = true;
                      for (var v in selectedMaterials.values) {
                        if (v <= 0) valid = false;
                      }
                      if (!valid) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ensure used quantities are greater than 0")));
                         return;
                      }

                      try {
                        provider.editManufacturedProduct(oldMfg, nameController.text, mfgQty, selectedMaterials);
                        Navigator.pop(context);
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                      }
                    }
                  },
                  child: Text(localizations.confirmBtn),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showDeleteManufactureDialog(BuildContext context, WarehouseProvider provider, ManufacturedProduct mfg, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(localizations.deleteBtn, style: const TextStyle(color: Colors.red)),
          content: Text(localizations.deleteManufactureConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(localizations.cancelBtn)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                provider.deleteManufacturedProduct(mfg);
                Navigator.pop(ctx);
              },
              child: Text(localizations.deleteBtn, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  void _showRemoveStockDialog(BuildContext context, WarehouseProvider provider, String itemName, AppLocalizations localizations) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(localizations.removeMaterialFromWarehouse),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    provider.removeMaterial(itemName, quantity);
                    Navigator.pop(ctx);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(localizations.removeStock, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showTransactionsHistory(BuildContext context, WarehouseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        final transactions = provider.transactions.reversed.toList();
        return AlertDialog(
          title: const Text('Transaction History'),
          content: SizedBox(
            width: double.maxFinite,
            child: transactions.isEmpty 
              ? const Text("No transactions yet.")
              : ListView.builder(
              shrinkWrap: true,
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                Color tColor = Colors.grey;
                String sig = "";
                if (t.type == "IN") { tColor = Colors.green; sig = "+"; }
                else if (t.type == "OUT") { tColor = Colors.red; sig = "-"; }
                else if (t.type == "CONSUMPTION") { tColor = Colors.orange; sig = "-"; }
                else if (t.type == "RESTORE") { tColor = Colors.purple; sig = "+"; }

                return ListTile(
                  title: Text(t.materialName),
                  subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(t.date) + " (${t.type == 'RESTORE' ? 'RESTORE' : t.type})"),
                  trailing: Text(
                    '$sig${t.quantity.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: tColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
          ],
        );
      }
    );
  }
}


