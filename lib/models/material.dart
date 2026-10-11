import '../services/record_id.dart';
import 'package:hive/hive.dart';

class MaterialAdapter extends TypeAdapter<Material> {
  @override
  final int typeId = 0;

  @override
  Material read(BinaryReader reader) {
    return Material(
      name: reader.readString(),
      quantity: reader.readDouble(),
      unit: reader.readString(),
      unitPrice: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Material obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.unit);
    writer.writeDouble(obj.unitPrice);
  }
}

class Material {
  final String id;
  String name;
  double quantity;
  String unit;
  double unitPrice;
  String priceCurrency;

  Material({
    String? id,
    required this.name,
    this.quantity = 0.0,
    this.unit = '',
    this.unitPrice = 0.0,
    this.priceCurrency = '',
  }) : id = id ?? RecordId.create();

  double get totalPrice => quantity * unitPrice;
}
