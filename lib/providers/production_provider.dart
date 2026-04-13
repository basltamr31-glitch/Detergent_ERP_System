import 'package:flutter/foundation.dart';
import '../models/raw_material.dart';

class ProductionProvider extends ChangeNotifier {
  String _productName = '';
  double _exchangeRate = 0.0; // افتراضي 1 لتجنب الضرب في صفر
  double _producedQuantity = 0.0;
  final List<RawMaterial> _rawMaterials = [];

  String get productName => _productName;
  double get exchangeRate => _exchangeRate;
  double get producedQuantity => _producedQuantity;
  List<RawMaterial> get rawMaterials => _rawMaterials;

  double get totalCostUSD => _rawMaterials.fold(0.0, (sum, item) => sum + (item.quantity * item.priceUSD));
  double get totalCostSYP => totalCostUSD * _exchangeRate;
  double get totalCostUSDKG => _producedQuantity > 0 ? totalCostUSD / _producedQuantity : 0.0;
  double get totalCostSYPKG => totalCostUSDKG * _exchangeRate;

  double get activeIngredientsPercentage {
    if (_producedQuantity <= 0) return 0.0;
    double totalActiveWeight = _rawMaterials
        .where((material) => material.isActive)
        .fold(0.0, (sum, material) => sum + material.quantity);
    return (totalActiveWeight / _producedQuantity) * 100;
  }

  void setProductName(String value) { _productName = value; notifyListeners(); }
  
  void setExchangeRate(double value) { 
    _exchangeRate = value; 
    // تحديث أسعار السوري لجميع المواد بناءً على الدولار وسعر الصرف الجديد
    for(int i = 0; i < _rawMaterials.length; i++) {
      _rawMaterials[i] = _rawMaterials[i].copyWith(priceSYP: _rawMaterials[i].priceUSD * _exchangeRate);
    }
    notifyListeners(); 
  }
  
  void setProducedQuantity(double value) { _producedQuantity = value; notifyListeners(); }

  void addRawMaterial() {
    _rawMaterials.add(RawMaterial());
    notifyListeners();
  }

  void removeRawMaterial(int index) {
    _rawMaterials.removeAt(index);
    notifyListeners();
  }

  void updateRawMaterial(int index, RawMaterial material) {
    _rawMaterials[index] = material;
    notifyListeners(); // مهم جداً لتحديث القيم عند تغيير السعر أو الكمية داخل القائمة
  }
}