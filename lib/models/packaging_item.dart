class PackagingItem {
  double size; // هنا أصبح رقماً حسابياً
  final double price;
  final double priceSYP;
  final bool hasCarton;
  final String unit;
  final bool unitConfirmed;

  PackagingItem({
    this.size = 0.0,
    this.price = 0.0,
    this.priceSYP = 0.0,
    this.hasCarton = false,
    this.unit = 'g',
    this.unitConfirmed = true,
  });

  PackagingItem copyWith({
    double? size,
    double? price,
    double? priceSYP,
    bool? hasCarton,
    String? unit,
    bool? unitConfirmed,
  }) {
    return PackagingItem(
      size: size ?? this.size,
      price: price ?? this.price,
      priceSYP: priceSYP ?? this.priceSYP,
      hasCarton: hasCarton ?? this.hasCarton,
      unit: unit ?? this.unit,
      unitConfirmed: unitConfirmed ?? this.unitConfirmed,
    );
  }
}
