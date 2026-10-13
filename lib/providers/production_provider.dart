import '../services/state_schema.dart';
import '../services/stock_validation.dart';
import 'package:hive/hive.dart';
import 'persisted_draft.dart';
import '../models/raw_material.dart';

class ProductionProvider extends PersistedDraft {
  ProductionProvider({Box<String>? storage}) : super(storage, 'production') {
    initializeDraft();
  }
  String _productName = '';
  double _exchangeRate = 0.0; // افتراضي 1 لتجنب الضرب في صفر
  double _producedQuantity = 0.0;
  double _laborUSD = 0, _overheadUSD = 0;
  final List<RawMaterial> _rawMaterials = [];

  String get productName => _productName;
  double get exchangeRate => _exchangeRate;
  double get producedQuantity => _producedQuantity;
  List<RawMaterial> get rawMaterials =>
      List.unmodifiable(_rawMaterials.map((m) => m.copyWith()));

  double get materialCostUSD => _rawMaterials.fold(
      0.0, (sum, item) => sum + (item.quantity * item.priceUSD));
  double get laborUSD => _laborUSD;
  double get overheadUSD => _overheadUSD;
  double get totalCostUSD => materialCostUSD + _laborUSD + _overheadUSD;
  void setLaborUSD(double value) {
    StockValidation.price(value);
    _laborUSD = value;
    draftChanged();
  }

  void setOverheadUSD(double value) {
    StockValidation.price(value);
    _overheadUSD = value;
    draftChanged();
  }

  double get totalCostSYP => totalCostUSD * _exchangeRate;
  double get totalCostUSDKG =>
      _producedQuantity > 0 ? totalCostUSD / _producedQuantity : 0.0;
  double get totalCostSYPKG => totalCostUSDKG * _exchangeRate;

  double get activeIngredientsPercentage {
    if (_producedQuantity <= 0) return 0.0;
    double totalActiveWeight = _rawMaterials
        .where((material) => material.isActive)
        .fold(0.0, (sum, material) => sum + material.quantity);
    return (totalActiveWeight / _producedQuantity) * 100;
  }

  void setProductName(String value) {
    _productName = value;
    draftChanged();
  }

  void setExchangeRate(double value) {
    StockValidation.price(value);
    _exchangeRate = value;
    // تحديث أسعار السوري لجميع المواد بناءً على الدولار وسعر الصرف الجديد
    for (int i = 0; i < _rawMaterials.length; i++) {
      _rawMaterials[i] = _rawMaterials[i]
          .copyWith(priceSYP: _rawMaterials[i].priceUSD * _exchangeRate);
    }
    draftChanged();
  }

  void setProducedQuantity(double value) {
    StockValidation.price(value);
    _producedQuantity = value;
    draftChanged();
  }

  void addRawMaterial() {
    _rawMaterials.add(RawMaterial());
    draftChanged();
  }

  void removeRawMaterial(int index) {
    _rawMaterials.removeAt(index);
    draftChanged();
  }

  void updateRawMaterial(int index, RawMaterial material) {
    StockValidation.price(material.quantity);
    StockValidation.price(material.priceUSD);
    StockValidation.price(material.priceSYP);

    _rawMaterials[index] = material;
    draftChanged(); // مهم جداً لتحديث القيم عند تغيير السعر أو الكمية داخل القائمة
  }

  @override
  Map<String, dynamic> toDraft() => {
        'version': 2,
        'laborUSD': _laborUSD,
        'overheadUSD': _overheadUSD,
        'name': _productName,
        'rate': _exchangeRate,
        'quantity': _producedQuantity,
        'materials': _rawMaterials
            .map((m) => {
                  'name': m.name,
                  'quantity': m.quantity,
                  'usd': m.priceUSD,
                  'syp': m.priceSYP,
                  'active': m.isActive
                })
            .toList()
      };
  @override
  void loadDraft(Map<String, dynamic> data) {
    StateSchema.draft('production', data);
    _laborUSD = data['version'] == 2 ? (data['laborUSD'] as num).toDouble() : 0;
    _overheadUSD =
        data['version'] == 2 ? (data['overheadUSD'] as num).toDouble() : 0;
    _productName = data['name'] as String;
    _exchangeRate = (data['rate'] as num).toDouble();
    _producedQuantity = (data['quantity'] as num).toDouble();
    _rawMaterials
      ..clear()
      ..addAll((data['materials'] as List).map((m) => RawMaterial(
          name: m['name'],
          quantity: (m['quantity'] as num).toDouble(),
          priceUSD: (m['usd'] as num).toDouble(),
          priceSYP: (m['syp'] as num).toDouble(),
          isActive: m['active'])));
    loadError = null;
    saveError = null;
    notifyListeners();
  }
}
