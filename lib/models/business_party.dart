import '../services/record_id.dart';

class BusinessParty {
  BusinessParty(
      {String? id,
      required this.name,
      this.phone = '',
      this.address = '',
      this.active = true})
      : id = id ?? RecordId.create();
  final String id, name, phone, address;
  final bool active;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'active': active
      };
  factory BusinessParty.fromJson(Map<String, dynamic> data) => BusinessParty(
      id: data['id'],
      name: data['name'],
      phone: data['phone'],
      address: data['address'],
      active: data['active']);
}
