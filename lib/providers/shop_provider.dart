import 'package:flutter/material.dart' show ChangeNotifier;
import 'package:hive/hive.dart';
import '../models/product.dart';

class ShopProvider with ChangeNotifier {
  final List<Product> _products = [];

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<Product> get products => _products;

  ShopProvider() {
    _init();
  }

  Future<void> _init() async {
    final box = await Hive.openBox<Product>('shop_products');
    _products.addAll(box.values);
    _isLoaded = true;
    notifyListeners();
  }

  double getStock(String name) {
    final existingIndex = _products.indexWhere((p) => p.name == name);
    if (existingIndex >= 0) {
      return _products[existingIndex].quantity;
    }
    return 0.0;
  }

  void addProduct(String name, double quantity, String unit, double unitPrice) {
    if (quantity <= 0) return;

    final box = Hive.box<Product>('shop_products');

    final existingIndex = _products.indexWhere((p) => p.name == name);
    if (existingIndex >= 0) {
      _products[existingIndex].quantity += quantity;
      _products[existingIndex].unit = unit;
      _products[existingIndex].unitPrice = unitPrice;
      box.put(name, _products[existingIndex]);
    } else {
      final p = Product(name: name, quantity: quantity, unit: unit, unitPrice: unitPrice);
      _products.add(p);
      box.put(name, p);
    }

    notifyListeners();
  }

  void sellProduct(String name, double quantity) {
    if (quantity <= 0) throw Exception("Quantity must be greater than zero.");

    final box = Hive.box<Product>('shop_products');
    final existingIndex = _products.indexWhere((p) => p.name == name);
    
    if (existingIndex >= 0) {
      if (_products[existingIndex].quantity >= quantity) {
        _products[existingIndex].quantity -= quantity;
        box.put(name, _products[existingIndex]);
        notifyListeners();
      } else {
        throw Exception("Insufficient stock. Available: ${_products[existingIndex].quantity}");
      }
    } else {
      throw Exception("Product not found in stock.");
    }
  }

  Future<void> resetSales() async {
    final box = Hive.box<Product>('shop_products');
    await box.clear();
    _products.clear();
    notifyListeners();
  }
}
