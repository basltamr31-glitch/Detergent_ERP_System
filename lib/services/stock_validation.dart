class StockValidation {
  static String name(String value) {
    final result = value.trim();
    if (result.isEmpty) throw ArgumentError('Name is required.');
    return result;
  }

  static void positive(double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('Quantity must be finite and greater than zero.');
    }
  }

  static void price(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('Price must be finite and nonnegative.');
    }
  }

  static void ingredients(Map<String, double> values) {
    if (values.isEmpty) {
      throw ArgumentError('At least one ingredient is required.');
    }
    for (final entry in values.entries) {
      if (name(entry.key) != entry.key) {
        throw ArgumentError('Select an existing material name.');
      }
      positive(entry.value);
    }
  }
}
