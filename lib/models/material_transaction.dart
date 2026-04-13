import 'package:hive/hive.dart';

class MaterialTransactionAdapter extends TypeAdapter<MaterialTransaction> {
  @override
  final int typeId = 1;

  @override
  MaterialTransaction read(BinaryReader reader) {
    return MaterialTransaction(
      materialName: reader.readString(),
      quantity: reader.readDouble(),
      type: reader.readString(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, MaterialTransaction obj) {
    writer.writeString(obj.materialName);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.type);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
  }
}

class MaterialTransaction {
  String materialName;
  double quantity;
  String type; // IN / OUT / CONSUMPTION
  DateTime date;

  MaterialTransaction({
    required this.materialName,
    required this.quantity,
    required this.type,
    required this.date,
  });
}
