class RawMaterial {
  String name;
  double quantity;
  double priceUSD;
  double priceSYP; // ← أضفنا هذا الحقل الجديد
  bool isActive; // ← أضفنا هذا الحقل

  RawMaterial({
    this.name = '',
    this.quantity = 0.0,
    this.priceUSD = 0.0,
    this.priceSYP = 0.0,
    this.isActive = false, // ← القيمة الافتراضية
  });

  RawMaterial copyWith({
    String? name,
    double? quantity,
    double? priceUSD,
    double? priceSYP,
    bool? isActive, // ← أضفنا هنا
  }) {
    return RawMaterial(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      priceUSD: priceUSD ?? this.priceUSD,
      priceSYP: priceSYP ?? this.priceSYP,
      isActive: isActive ?? this.isActive,
      // ← هنا
    );
  }
}
