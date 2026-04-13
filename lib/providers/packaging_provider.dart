import 'package:flutter/foundation.dart';
import '../models/packaging_item.dart';

class PackagingProvider extends ChangeNotifier {
  final List<PackagingItem> _packagingItems = [];
  int _packagesPerCarton = 1; // جعلناها تبدأ من 1 لتجنب القسمة على صفر
  double _cartonPrice = 0.0;
  double _cartonPriceSYP = 0.0;
  double _labelPrice = 0.0;
  double _labelPriceSYP = 0.0;

  List<PackagingItem> get packagingItems => _packagingItems;
  int get packagesPerCarton => _packagesPerCarton;
  double get cartonPrice => _cartonPrice;
  double get cartonPriceSYP => _cartonPriceSYP;
  double get labelPrice => _labelPrice;
  double get labelPriceSYP => _labelPriceSYP;

  // 1. تكلفة العبوة الواحدة (سائل + عبوة فارغة + لصاقة)
  double calculateUnitCostUSD(double unitSize, double emptyBottlePrice, double costPerKgUSD) {
    double liquidCost = (costPerKgUSD * unitSize) / 1000;
    return liquidCost + emptyBottlePrice + _labelPrice;
  }

  // 2. تكلفة الكرتونة كاملة بناءً على حجم عبوة محدد
  double calculateTotalCartonCostUSD(double unitSize, double emptyBottlePrice, double costPerKgUSD) {
    double unitCost = calculateUnitCostUSD(unitSize, emptyBottlePrice, costPerKgUSD);
    return (unitCost * _packagesPerCarton) + _cartonPrice;
  }

  void addPackagingItem() {
    _packagingItems.add(PackagingItem());
    notifyListeners();
  }

  void removePackagingItem(int index) {
    if (index >= 0 && index < _packagingItems.length) {
      _packagingItems.removeAt(index);
      notifyListeners();
    }
  }

  void updatePackagingItem(int index, PackagingItem item) {
    if (index >= 0 && index < _packagingItems.length) {
      _packagingItems[index] = item;
      notifyListeners();
    }
  }

  void syncPricesWithExchangeRate(double exchangeRate) {
    for(int i = 0; i < _packagingItems.length; i++) {
      _packagingItems[i] = _packagingItems[i].copyWith(priceSYP: _packagingItems[i].price * exchangeRate);
    }
    _cartonPriceSYP = _cartonPrice * exchangeRate;
    _labelPriceSYP = _labelPrice * exchangeRate;
    notifyListeners();
  }

  void setPackagesPerCarton(int value) {
    _packagesPerCarton = value;
    notifyListeners();
  }

  void incrementPackagesPerCarton() {
    _packagesPerCarton++;
    notifyListeners();
  }

  void decrementPackagesPerCarton() {
    if (_packagesPerCarton > 1) {
      _packagesPerCarton--;
      notifyListeners();
    }
  }

  void setCartonPriceUSD(double usdValue, double exchangeRate) {
    _cartonPrice = usdValue;
    _cartonPriceSYP = exchangeRate > 0 ? usdValue * exchangeRate : 0.0;
    notifyListeners();
  }

  void setCartonPriceSYP(double sypValue, double exchangeRate) {
    _cartonPriceSYP = sypValue;
    _cartonPrice = exchangeRate > 0 ? sypValue / exchangeRate : 0.0;
    notifyListeners();
  }

  void setLabelPriceUSD(double usdValue, double exchangeRate) {
    _labelPrice = usdValue;
    _labelPriceSYP = exchangeRate > 0 ? usdValue * exchangeRate : 0.0;
    notifyListeners();
  }

  void setLabelPriceSYP(double sypValue, double exchangeRate) {
    _labelPriceSYP = sypValue;
    _labelPrice = exchangeRate > 0 ? sypValue / exchangeRate : 0.0;
    notifyListeners();
  }
}