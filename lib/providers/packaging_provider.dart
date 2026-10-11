import '../services/state_schema.dart';
import '../services/stock_validation.dart';
import 'package:hive/hive.dart';
import 'persisted_draft.dart';
import '../models/packaging_item.dart';
import '../services/fill_costing.dart';

class PackagingProvider extends PersistedDraft {
  PackagingProvider({Box<String>? storage}) : super(storage, 'packaging') {
    initializeDraft();
  }
  final List<PackagingItem> _packagingItems = [];
  int _packagesPerCarton = 1; // جعلناها تبدأ من 1 لتجنب القسمة على صفر
  double _cartonPrice = 0.0;
  double _cartonPriceSYP = 0.0;
  double _labelPrice = 0.0;
  double _labelPriceSYP = 0.0;
  double _densityKgPerLiter = 0;
  double get densityKgPerLiter => _densityKgPerLiter;
  void setDensity(double value) {
    StockValidation.price(value);
    _densityKgPerLiter = value;
    draftChanged();
  }

  double fillMassKg(PackagingItem item) =>
      FillCosting.massKg(item.size, item.unit, _densityKgPerLiter);

  List<PackagingItem> get packagingItems =>
      List.unmodifiable(_packagingItems.map((m) => m.copyWith()));
  int get packagesPerCarton => _packagesPerCarton;
  double get cartonPrice => _cartonPrice;
  double get cartonPriceSYP => _cartonPriceSYP;
  double get labelPrice => _labelPrice;
  double get labelPriceSYP => _labelPriceSYP;

  // 1. تكلفة العبوة الواحدة (سائل + عبوة فارغة + لصاقة)
  double calculateUnitCostUSD(
      double unitSize, double emptyBottlePrice, double costPerKgUSD,
      {String unit = 'g'}) {
    StockValidation.price(emptyBottlePrice);
    StockValidation.price(costPerKgUSD);
    double liquidCost =
        costPerKgUSD * FillCosting.massKg(unitSize, unit, _densityKgPerLiter);
    if (!liquidCost.isFinite) {
      throw ArgumentError('Cost exceeds supported range.');
    }
    final total = liquidCost + emptyBottlePrice + _labelPrice;
    if (!total.isFinite) throw ArgumentError('Cost exceeds supported range.');
    return total;
  }

  // 2. تكلفة الكرتونة كاملة بناءً على حجم عبوة محدد
  double calculateTotalCartonCostUSD(
      double unitSize, double emptyBottlePrice, double costPerKgUSD,
      {String unit = 'g'}) {
    double unitCost = calculateUnitCostUSD(
        unitSize, emptyBottlePrice, costPerKgUSD,
        unit: unit);
    final total = (unitCost * _packagesPerCarton) + _cartonPrice;
    if (!total.isFinite) throw ArgumentError('Cost exceeds supported range.');
    return total;
  }

  void addPackagingItem() {
    _packagingItems.add(PackagingItem());
    draftChanged();
  }

  void removePackagingItem(int index) {
    if (index >= 0 && index < _packagingItems.length) {
      _packagingItems.removeAt(index);
      draftChanged();
    }
  }

  void updatePackagingItem(int index, PackagingItem item) {
    StockValidation.price(item.size);
    StockValidation.price(item.price);
    StockValidation.price(item.priceSYP);
    if (!FillCosting.units.contains(item.unit)) {
      throw ArgumentError('Unsupported fill unit.');
    }

    if (index >= 0 && index < _packagingItems.length) {
      _packagingItems[index] = item;
      draftChanged();
    }
  }

  void syncPricesWithExchangeRate(double exchangeRate) {
    StockValidation.price(exchangeRate);
    for (int i = 0; i < _packagingItems.length; i++) {
      _packagingItems[i] = _packagingItems[i]
          .copyWith(priceSYP: _packagingItems[i].price * exchangeRate);
    }
    _cartonPriceSYP = _cartonPrice * exchangeRate;
    _labelPriceSYP = _labelPrice * exchangeRate;
    draftChanged();
  }

  void setPackagesPerCarton(int value) {
    if (value < 1) throw ArgumentError('Carton count must be positive.');
    _packagesPerCarton = value;
    draftChanged();
  }

  void incrementPackagesPerCarton() {
    _packagesPerCarton++;
    draftChanged();
  }

  void decrementPackagesPerCarton() {
    if (_packagesPerCarton > 1) {
      _packagesPerCarton--;
      draftChanged();
    }
  }

  void setCartonPriceUSD(double usdValue, double exchangeRate) {
    StockValidation.price(usdValue);
    _cartonPrice = usdValue;
    _cartonPriceSYP = exchangeRate > 0 ? usdValue * exchangeRate : 0.0;
    draftChanged();
  }

  void setCartonPriceSYP(double sypValue, double exchangeRate) {
    StockValidation.price(sypValue);
    StockValidation.positive(exchangeRate);
    _cartonPriceSYP = sypValue;
    _cartonPrice = exchangeRate > 0 ? sypValue / exchangeRate : 0.0;
    draftChanged();
  }

  void setLabelPriceUSD(double usdValue, double exchangeRate) {
    StockValidation.price(usdValue);
    _labelPrice = usdValue;
    _labelPriceSYP = exchangeRate > 0 ? usdValue * exchangeRate : 0.0;
    draftChanged();
  }

  void setLabelPriceSYP(double sypValue, double exchangeRate) {
    StockValidation.price(sypValue);
    StockValidation.positive(exchangeRate);
    _labelPriceSYP = sypValue;
    _labelPrice = exchangeRate > 0 ? sypValue / exchangeRate : 0.0;
    draftChanged();
  }

  @override
  Map<String, dynamic> toDraft() => {
        'version': 2,
        'density': _densityKgPerLiter,
        'perCarton': _packagesPerCarton,
        'cartonUSD': _cartonPrice,
        'cartonSYP': _cartonPriceSYP,
        'labelUSD': _labelPrice,
        'labelSYP': _labelPriceSYP,
        'items': _packagingItems
            .map((m) => {
                  'size': m.size,
                  'usd': m.price,
                  'syp': m.priceSYP,
                  'carton': m.hasCarton,
                  'unit': m.unit,
                  'unitConfirmed': m.unitConfirmed
                })
            .toList()
      };
  @override
  void loadDraft(Map<String, dynamic> data) {
    StateSchema.draft('packaging', data);
    _densityKgPerLiter = (data['density'] as num? ?? 0).toDouble();
    _packagesPerCarton = data['perCarton'] as int;
    _cartonPrice = (data['cartonUSD'] as num).toDouble();
    _cartonPriceSYP = (data['cartonSYP'] as num).toDouble();
    _labelPrice = (data['labelUSD'] as num).toDouble();
    _labelPriceSYP = (data['labelSYP'] as num).toDouble();
    _packagingItems
      ..clear()
      ..addAll((data['items'] as List).map((m) => PackagingItem(
          size: (m['size'] as num).toDouble(),
          price: (m['usd'] as num).toDouble(),
          priceSYP: (m['syp'] as num).toDouble(),
          hasCarton: m['carton'],
          unit: m['unit'] ?? 'g',
          unitConfirmed: data['version'] == 2 ? m['unitConfirmed'] : false)));
    loadError = null;
    saveError = null;
    notifyListeners();
  }
}
