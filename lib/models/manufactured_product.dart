import '../services/access_control.dart';
import '../services/record_id.dart';
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
  final Map<String, String> actor;
  final String id;
  final String name;
  final double quantity;
  final DateTime date;
  final Map<String, double> rawMaterialsUsed;
  final Map<String, String> materialIds;
  final String number;
  final String kind;
  final String reason;
  final String requestId;
  final String? reversalOf;
  final String? replacesId;

  ManufacturedProduct({
    String? id,
    required this.name,
    required this.quantity,
    required this.date,
    Map<String, double> rawMaterialsUsed = const {},
    Map<String, String> materialIds = const {},
    this.number = '',
    this.kind = 'production',
    this.reason = '',
    this.reversalOf,
    this.replacesId,
    String? requestId,
    Map<String, String>? actor,
  })  : actor = Map.unmodifiable(actor ?? AccessControl.actor),
        id = id ?? RecordId.create(),
        requestId = requestId ?? RecordId.create(),
        rawMaterialsUsed = Map.unmodifiable(rawMaterialsUsed),
        materialIds = Map.unmodifiable(materialIds);
}
