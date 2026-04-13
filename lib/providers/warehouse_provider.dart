import 'package:flutter/material.dart' show ChangeNotifier;
import 'package:hive/hive.dart';
import '../models/material.dart' as my_models;
import '../models/material_transaction.dart';
import '../models/manufactured_product.dart';

class WarehouseProvider with ChangeNotifier {
  final List<my_models.Material> _materials = [];
  final List<MaterialTransaction> _transactions = [];
  final List<ManufacturedProduct> _manufacturedProducts = [];

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<my_models.Material> get materials => _materials;
  List<MaterialTransaction> get transactions => _transactions;
  List<ManufacturedProduct> get manufacturedProducts => _manufacturedProducts;

  int get totalMaterials => _materials.length;

  WarehouseProvider() {
    _init();
  }

  Future<void> _init() async {
    final boxMat = await Hive.openBox<my_models.Material>('warehouse_materials');
    final boxTrans = await Hive.openBox<MaterialTransaction>('warehouse_transactions');
    final boxMfg = await Hive.openBox<ManufacturedProduct>('warehouse_mfg_products_v2');

    _materials.addAll(boxMat.values);
    _transactions.addAll(boxTrans.values);
    _manufacturedProducts.addAll(boxMfg.values);

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> resetWarehouse() async {
    final boxMat = Hive.box<my_models.Material>('warehouse_materials');
    final boxTrans = Hive.box<MaterialTransaction>('warehouse_transactions');
    final boxMfg = Hive.box<ManufacturedProduct>('warehouse_mfg_products_v2');
    await boxMat.clear();
    await boxTrans.clear();
    await boxMfg.clear();
    _materials.clear();
    _transactions.clear();
    _manufacturedProducts.clear();
    notifyListeners();
  }

  double getStock(String name) {
    final existingIndex = _materials.indexWhere((m) => m.name == name);
    if (existingIndex >= 0) {
      return _materials[existingIndex].quantity;
    }
    return 0.0;
  }

  void addMaterial(String name, double quantity, String unit, double unitPrice) {
    if (quantity <= 0) return;

    final boxMat = Hive.box<my_models.Material>('warehouse_materials');
    final boxTrans = Hive.box<MaterialTransaction>('warehouse_transactions');

    final existingIndex = _materials.indexWhere((m) => m.name == name);
    if (existingIndex >= 0) {
      _materials[existingIndex].quantity += quantity;
      _materials[existingIndex].unit = unit;
      _materials[existingIndex].unitPrice = unitPrice;
      boxMat.put(name, _materials[existingIndex]);
    } else {
      final newMat = my_models.Material(name: name, quantity: quantity, unit: unit, unitPrice: unitPrice);
      _materials.add(newMat);
      boxMat.put(name, newMat);
    }

    final trans = MaterialTransaction(
      materialName: name,
      quantity: quantity,
      type: 'IN',
      date: DateTime.now(),
    );
    _transactions.add(trans);
    boxTrans.add(trans);

    notifyListeners();
  }

  void removeMaterial(String name, double quantity) {
    if (quantity <= 0) throw Exception("Quantity must be greater than zero.");

    final boxMat = Hive.box<my_models.Material>('warehouse_materials');
    final boxTrans = Hive.box<MaterialTransaction>('warehouse_transactions');

    final existingIndex = _materials.indexWhere((m) => m.name == name);
    if (existingIndex >= 0) {
      if (_materials[existingIndex].quantity >= quantity) {
        _materials[existingIndex].quantity -= quantity;
        boxMat.put(name, _materials[existingIndex]);

        final trans = MaterialTransaction(
          materialName: name,
          quantity: quantity,
          type: 'OUT',
          date: DateTime.now(),
        );
        _transactions.add(trans);
        boxTrans.add(trans);

        notifyListeners();
      } else {
        throw Exception("Insufficient stock. Available: ${_materials[existingIndex].quantity}");
      }
    } else {
      throw Exception("Material not found in stock.");
    }
  }

  void produceManufacturedProduct(String mfgName, double mfgQuantity, Map<String, double> rawMaterialsUsed) {
    for (var entry in rawMaterialsUsed.entries) {
      final stock = getStock(entry.key);
      if (stock < entry.value) {
        throw Exception("Insufficient stock for ${entry.key}. Available: $stock");
      }
    }

    final boxMat = Hive.box<my_models.Material>('warehouse_materials');
    final boxTrans = Hive.box<MaterialTransaction>('warehouse_transactions');
    final boxMfg = Hive.box<ManufacturedProduct>('warehouse_mfg_products_v2');

    for (var entry in rawMaterialsUsed.entries) {
      final existingIndex = _materials.indexWhere((m) => m.name == entry.key);
      _materials[existingIndex].quantity -= entry.value;
      boxMat.put(entry.key, _materials[existingIndex]);

      final trans = MaterialTransaction(
        materialName: entry.key,
        quantity: entry.value,
        type: 'CONSUMPTION',
        date: DateTime.now(),
      );
      _transactions.add(trans);
      boxTrans.add(trans);
    }

    final mfg = ManufacturedProduct(name: mfgName, quantity: mfgQuantity, date: DateTime.now(), rawMaterialsUsed: Map.from(rawMaterialsUsed));
    _manufacturedProducts.add(mfg);
    boxMfg.add(mfg);

    notifyListeners();
  }

  void deleteManufacturedProduct(ManufacturedProduct mfg) {
    final index = _manufacturedProducts.indexOf(mfg);
    if (index < 0) return;

    final boxMat = Hive.box<my_models.Material>('warehouse_materials');
    final boxTrans = Hive.box<MaterialTransaction>('warehouse_transactions');
    final boxMfg = Hive.box<ManufacturedProduct>('warehouse_mfg_products_v2');

    boxMfg.deleteAt(index);
    _manufacturedProducts.removeAt(index);

    for (var entry in mfg.rawMaterialsUsed.entries) {
      final materialName = entry.key;
      final quantityRestored = entry.value;
      final stockIndex = _materials.indexWhere((m) => m.name == materialName);

      if (stockIndex >= 0) {
        _materials[stockIndex].quantity += quantityRestored;
        boxMat.put(materialName, _materials[stockIndex]);
      } else {
        final newMat = my_models.Material(name: materialName, quantity: quantityRestored);
        _materials.add(newMat);
        boxMat.put(materialName, newMat);
      }

      final trans = MaterialTransaction(
        materialName: materialName,
        quantity: quantityRestored,
        type: 'RESTORE',
        date: DateTime.now(),
      );
      _transactions.add(trans);
      boxTrans.add(trans);
    }

    notifyListeners();
  }

  void editManufacturedProduct(ManufacturedProduct oldMfg, String newName, double newQty, Map<String, double> newMaterials) {
    final index = _manufacturedProducts.indexOf(oldMfg);
    if (index < 0) return;

    for (var entry in newMaterials.entries) {
      final materialName = entry.key;
      final targetConsume = entry.value;
      final currentConsumed = oldMfg.rawMaterialsUsed[materialName] ?? 0.0;
      final delta = targetConsume - currentConsumed; 

      if (delta > 0) {
        final stock = getStock(materialName);
        if (stock < delta) {
          throw Exception("Insufficient stock for $materialName to apply changes. Short by: $delta\nAvailable: $stock");
        }
      }
    }

    final boxMat = Hive.box<my_models.Material>('warehouse_materials');
    final boxTrans = Hive.box<MaterialTransaction>('warehouse_transactions');
    final boxMfg = Hive.box<ManufacturedProduct>('warehouse_mfg_products_v2');

    final allKeys = <String>{...oldMfg.rawMaterialsUsed.keys, ...newMaterials.keys};

    for (var materialName in allKeys) {
      final oldQty = oldMfg.rawMaterialsUsed[materialName] ?? 0.0;
      final newQtyVal = newMaterials[materialName] ?? 0.0;
      final delta = newQtyVal - oldQty;

      if (delta != 0) {
        final stockIndex = _materials.indexWhere((m) => m.name == materialName);
        if (stockIndex >= 0) {
          _materials[stockIndex].quantity -= delta;
          boxMat.put(materialName, _materials[stockIndex]);
        } else if (delta < 0) {
           final newMat = my_models.Material(name: materialName, quantity: -delta);
           _materials.add(newMat);
           boxMat.put(materialName, newMat);
        }

        final transType = delta > 0 ? 'CONSUMPTION' : 'RESTORE';
        final trans = MaterialTransaction(
          materialName: materialName,
          quantity: delta.abs(),
          type: transType,
          date: DateTime.now(),
        );
        _transactions.add(trans);
        boxTrans.add(trans);
      }
    }

    oldMfg.name = newName;
    oldMfg.quantity = newQty;
    oldMfg.rawMaterialsUsed = Map.from(newMaterials);
    
    boxMfg.putAt(index, oldMfg);
    notifyListeners();
  }
}


