import 'package:hive/hive.dart';

class ManufacturedProductAdapter extends TypeAdapter<ManufacturedProduct> {
  @override
  final int typeId = 3;

  @override
  ManufacturedProduct read(BinaryReader reader) {
    return ManufacturedProduct(
      name: reader.readString(),
      quantity: reader.readDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      rawMaterialsUsed: reader.readMap().cast<String, double>(),
    );
  }

  @override
  void write(BinaryWriter writer, ManufacturedProduct obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.quantity);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeMap(obj.rawMaterialsUsed);
  }
}

class ManufacturedProduct {
  String name;
  double quantity;
  DateTime date;
  Map<String, double> rawMaterialsUsed;

  ManufacturedProduct({
    required this.name,
    required this.quantity,
    required this.date,
    this.rawMaterialsUsed = const {},
  });
}

