/// Converts entered stock quantities into each item's own base unit.
///
/// Packaging relationships belong to the item and never to a global carton or
/// package definition. Quantities and ratios are evaluated as exact integers;
/// a result requiring more than six decimals is rejected instead of rounded.
class InventoryUnits {
  static const maxQuantity = 1000000000;
  static const maxFactorPart = 1000000000;
  static final _scale = BigInt.from(1000000);
  static final _maximumMicro = BigInt.from(maxQuantity) * _scale;

  static double toBase(double quantity, String enteredUnit, String baseUnit,
          List<Map<String, dynamic>> conversions) =>
      snapshot(quantity, enteredUnit, baseUnit, conversions)['baseQuantity']
          as double;

  /// A transaction stores this snapshot so future master-data changes cannot
  /// change its historical quantity, factor, or conversion revision.
  static Map<String, dynamic> snapshot(double quantity, String enteredUnit,
      String baseUnit, List<Map<String, dynamic>> conversions) {
    validateConversions(baseUnit, conversions);
    final entered = _unit(enteredUnit);
    final base = _unit(baseUnit);
    final micro = _quantityMicro(quantity);
    final factor = _factor(entered, base, conversions);
    if (!factor.allowFraction && micro % _scale != BigInt.zero) {
      throw ArgumentError('This stock unit requires a whole quantity.');
    }
    final numerator = micro * BigInt.from(factor.numerator);
    final denominator = BigInt.from(factor.denominator);
    if (numerator % denominator != BigInt.zero) {
      throw ArgumentError('The converted quantity exceeds six decimal places.');
    }
    final baseMicro = numerator ~/ denominator;
    if (baseMicro <= BigInt.zero || baseMicro > _maximumMicro) {
      throw ArgumentError('The converted quantity is outside the stock range.');
    }
    return Map<String, dynamic>.unmodifiable({
      'inputUnit': entered,
      'inputQuantity': quantity,
      'baseUnit': base,
      'baseQuantity': baseMicro.toDouble() / 1000000,
      'factorNumerator': factor.numerator,
      'factorDenominator': factor.denominator,
      'conversionId': factor.id,
      'revision': factor.revision,
    });
  }

  /// Validates the optional `unitConversions` list from an item master map.
  /// Each row contains id, unit, numerator, denominator, revision, and
  /// allowFraction. Its ratio is the number of base units per entered unit.
  static void validateConversions(
      String baseUnit, List<Map<String, dynamic>> conversions) {
    final base = _unit(baseUnit);
    final ids = <String>{};
    final units = <String>{_unitKey(base)};
    for (final row in conversions) {
      final id = _text(row['id'], 'conversion id');
      final unit = _text(row['unit'], 'conversion unit');
      if (!ids.add(id) || !units.add(_unitKey(unit))) {
        throw ArgumentError('Conversion IDs and units must be unique.');
      }
      final numerator = _part(row['numerator'], 'numerator');
      final denominator = _part(row['denominator'], 'denominator');
      _part(row['revision'], 'revision');
      if (row['allowFraction'] is! bool) {
        throw ArgumentError('Specify whether the unit allows fractions.');
      }
      final builtIn = _builtIn(unit, base);
      if (builtIn != null &&
          BigInt.from(numerator) * BigInt.from(builtIn.denominator) !=
              BigInt.from(denominator) * BigInt.from(builtIn.numerator)) {
        throw ArgumentError('Standard mass or volume factors cannot change.');
      }
    }
  }

  static _UnitFactor _factor(
      String unit, String base, List<Map<String, dynamic>> conversions) {
    if (_unitKey(unit) == _unitKey(base)) {
      return const _UnitFactor(1, 1, 'base', 1, true);
    }
    for (final row in conversions) {
      if (_unitKey(row['unit'] as String) == _unitKey(unit)) {
        return _UnitFactor(
            row['numerator'] as int,
            row['denominator'] as int,
            (row['id'] as String).trim(),
            row['revision'] as int,
            row['allowFraction'] as bool);
      }
    }
    final builtIn = _builtIn(unit, base);
    if (builtIn != null) return builtIn;
    throw ArgumentError('Define this item\'s stock-unit conversion first.');
  }

  static _UnitFactor? _builtIn(String unit, String base) {
    final source = _measurement(unit), target = _measurement(base);
    if (source == null ||
        target == null ||
        source.dimension != target.dimension) {
      return null;
    }
    return _UnitFactor(source.scale, target.scale,
        'builtin:${source.symbol}:${target.symbol}', 1, true);
  }

  static _Measurement? _measurement(String value) =>
      switch (value.trim().toLowerCase()) {
        'g' || 'gram' => const _Measurement('mass', 'g', 1),
        'kg' || 'kilogram' => const _Measurement('mass', 'kg', 1000),
        'ml' || 'milliliter' => const _Measurement('volume', 'ml', 1),
        'l' || 'liter' => const _Measurement('volume', 'L', 1000),
        _ => null,
      };

  static String _unitKey(String unit) =>
      _measurement(unit)?.symbol ?? unit.trim();

  static String _unit(String unit) => _text(unit, 'base or entered unit');

  static String _text(dynamic value, String label) {
    if (value is! String || value.trim().isEmpty || value.length > 128) {
      throw ArgumentError('Enter a valid $label.');
    }
    return value.trim();
  }

  static int _part(dynamic value, String label) {
    if (value is! int || value <= 0 || value > maxFactorPart) {
      throw ArgumentError('Invalid conversion $label.');
    }
    return value;
  }

  static BigInt _quantityMicro(double quantity) {
    if (!quantity.isFinite || quantity <= 0 || quantity > maxQuantity) {
      throw ArgumentError('Enter a positive quantity within the stock range.');
    }
    final parts = quantity.toString().toLowerCase().split('e');
    final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
    final decimals = parts[0].split('.');
    var digits = BigInt.parse(decimals.join());
    final fractionDigits = decimals.length == 2 ? decimals[1].length : 0;
    final power = 6 + exponent - fractionDigits;
    if (power >= 0) {
      digits *= BigInt.from(10).pow(power);
    } else {
      final divisor = BigInt.from(10).pow(-power);
      if (digits % divisor != BigInt.zero) {
        throw ArgumentError('Quantity supports up to six decimal places.');
      }
      digits ~/= divisor;
    }
    if (digits <= BigInt.zero || digits > _maximumMicro) {
      throw ArgumentError('Quantity supports up to six decimal places.');
    }
    return digits;
  }
}

class _UnitFactor {
  const _UnitFactor(this.numerator, this.denominator, this.id, this.revision,
      this.allowFraction);
  final int numerator, denominator, revision;
  final String id;
  final bool allowFraction;
}

class _Measurement {
  const _Measurement(this.dimension, this.symbol, this.scale);
  final String dimension, symbol;
  final int scale;
}
