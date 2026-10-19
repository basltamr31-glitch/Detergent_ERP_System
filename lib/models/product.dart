import '../services/record_id.dart';
import 'package:hive/hive.dart';

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 2;

  @override
  Product read(BinaryReader reader) {
    return Product(
      name: reader.readString(),
      quantity: reader.readDouble(),
      unit: reader.readString(),
      unitPrice: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.unit);
    writer.writeDouble(obj.unitPrice);
  }
}

class Product {
  final String id;
  String sku;
  List<Map<String, dynamic>> unitConversions;
  String name;
  double quantity;
  String unit;
  double unitPrice;

  Product({
    String? id,
    String? sku,
    List<Map<String, dynamic>> unitConversions = const [],
    required this.name,
    this.quantity = 0.0,
    this.unit = '',
    this.unitPrice = 0.0,
  })  : id = id ?? RecordId.create(),
        sku = sku ?? '',
        unitConversions =
            unitConversions.map((u) => Map<String, dynamic>.from(u)).toList();

  double get totalPrice => quantity * unitPrice;
}
