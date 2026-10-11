class FillCosting {
  static const units = ['g', 'kg', 'ml', 'L'];
  static double massKg(double size, String unit, double densityKgPerLiter) {
    if (!size.isFinite || size <= 0 || !units.contains(unit)) {
      throw ArgumentError('Enter a positive fill size and a supported unit.');
    }
    if ((unit == 'ml' || unit == 'L') &&
        (!densityKgPerLiter.isFinite || densityKgPerLiter <= 0)) {
      throw ArgumentError('Volume fills require a measured density in kg/L.');
    }
    final mass = switch (unit) {
      'g' => size / 1000,
      'kg' => size,
      'ml' => size / 1000 * densityKgPerLiter,
      'L' => size * densityKgPerLiter,
      _ => throw ArgumentError('Unsupported fill unit.')
    };
    if (!mass.isFinite || mass <= 0) throw ArgumentError('Invalid fill mass.');
    return mass;
  }
}
