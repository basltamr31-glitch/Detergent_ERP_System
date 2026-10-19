import 'package:flutter_test/flutter_test.dart';
import 'package:detergent_factory/services/inventory_units.dart';

Map<String, dynamic> carton(int packages,
        {int revision = 1, bool allowFraction = false}) =>
    {
      'id': 'carton-to-package',
      'unit': 'Carton',
      'numerator': packages,
      'denominator': 1,
      'revision': revision,
      'allowFraction': allowFraction,
    };

void main() {
  test('Carton factors belong to each SKU and snapshots retain their revision',
      () {
    final firstSku = [carton(12, revision: 2)];
    final secondSku = [carton(24)];
    expect(InventoryUnits.toBase(2, 'Carton', 'Package', firstSku), 24);
    expect(InventoryUnits.toBase(2, 'Carton', 'Package', secondSku), 48);
    final receipt = InventoryUnits.snapshot(2, 'Carton', 'Package', firstSku);
    firstSku.single['numerator'] = 24;
    firstSku.single['revision'] = 3;
    expect(receipt, {
      'inputUnit': 'Carton',
      'inputQuantity': 2.0,
      'baseUnit': 'Package',
      'baseQuantity': 24.0,
      'factorNumerator': 12,
      'factorDenominator': 1,
      'conversionId': 'carton-to-package',
      'revision': 2,
    });
    expect(InventoryUnits.toBase(2, 'Carton', 'Package', firstSku), 48);
  });

  test('Standard mass and volume convert within their own dimensions', () {
    expect(InventoryUnits.toBase(500, 'g', 'kg', []), 0.5);
    expect(InventoryUnits.toBase(500, 'Gram', 'Kilogram', []), 0.5);
    expect(InventoryUnits.toBase(0.5, 'kg', 'Gram', []), 500);
    expect(InventoryUnits.toBase(250, 'Milliliter', 'Liter', []), 0.25);
    expect(InventoryUnits.toBase(0.25, 'L', 'ml', []), 250);
    expect(InventoryUnits.toBase(0.1, 'Liter', 'L', []), 0.1);
    expect(InventoryUnits.toBase(0.000001, 'kg', 'g', []), 0.001);
  });

  test('Undefined packaging and mass-volume relationships are never inferred',
      () {
    for (final units in [
      ['Carton', 'Package'],
      ['Unit', 'Piece'],
      ['Package', 'Piece'],
      ['kg', 'L'],
      ['Liter', 'Kilogram'],
      ['Gallon', 'Liter'],
    ]) {
      expect(() => InventoryUnits.toBase(1, units[0], units[1], []),
          throwsArgumentError);
    }
    expect(InventoryUnits.toBase(12, 'Piece', 'Piece', []), 12);
  });

  test('Fractions require permission and converted precision must be exact',
      () {
    expect(() => InventoryUnits.toBase(0.5, 'Carton', 'Package', [carton(12)]),
        throwsArgumentError);
    expect(
        InventoryUnits.toBase(
            0.5, 'Carton', 'Package', [carton(12, allowFraction: true)]),
        6);
    final third = carton(1, allowFraction: true)..['denominator'] = 3;
    expect(() => InventoryUnits.toBase(1, 'Carton', 'Package', [third]),
        throwsArgumentError);
    expect(InventoryUnits.toBase(3, 'Carton', 'Package', [third]), 1);
    final eighth = carton(1)..['denominator'] = 8;
    expect(InventoryUnits.toBase(1, 'Carton', 'Package', [eighth]), 0.125);
    expect(() => InventoryUnits.toBase(0.000001, 'g', 'kg', []),
        throwsArgumentError);
    expect(() => InventoryUnits.toBase(0.0000001, 'Package', 'Package', []),
        throwsArgumentError);
    expect(InventoryUnits.toBase(0.123456, 'Package', 'Package', []), 0.123456);
  });

  test('Malformed definitions, duplicate units and standard overrides fail',
      () {
    final invalid = <Map<String, dynamic>>[
      {...carton(12), 'numerator': 0},
      {...carton(12), 'denominator': -1},
      {...carton(12), 'numerator': double.infinity},
      {...carton(12), 'numerator': 12.0},
      {...carton(12), 'denominator': InventoryUnits.maxFactorPart + 1},
      {...carton(12), 'revision': 0},
      {...carton(12), 'allowFraction': 'yes'},
      {...carton(12), 'id': ''},
      {...carton(12), 'unit': ''},
      {...carton(12), 'unit': 'Package'},
    ];
    for (final definition in invalid) {
      expect(() => InventoryUnits.validateConversions('Package', [definition]),
          throwsArgumentError);
    }
    expect(
        () => InventoryUnits.validateConversions('Package', [
              carton(12),
              {...carton(24), 'id': 'other'}
            ]),
        throwsArgumentError);
    expect(
        () => InventoryUnits.validateConversions('Package', [
              carton(12),
              {...carton(24), 'unit': 'Box'}
            ]),
        throwsArgumentError);
    expect(
        () => InventoryUnits.validateConversions('kg', [
              {...carton(12), 'unit': 'Gram'}
            ]),
        throwsArgumentError);
    expect(
        () => InventoryUnits.validateConversions('kg', [
              {...carton(12), 'unit': 'Kilogram'}
            ]),
        throwsArgumentError);
    expect(
        () => InventoryUnits.validateConversions('kg', [
              {...carton(1), 'unit': 'g', 'denominator': 1000},
              {
                ...carton(1),
                'id': 'second-gram',
                'unit': 'Gram',
                'denominator': 1000
              }
            ]),
        throwsArgumentError);
  });

  test('Surrounding whitespace cannot bypass conversion uniqueness or lookup',
      () {
    final definition = carton(12)
      ..['id'] = ' carton-to-package '
      ..['unit'] = ' Carton ';
    final snapshot =
        InventoryUnits.snapshot(2, ' Carton ', ' Package ', [definition]);
    expect(snapshot['baseQuantity'], 24);
    expect(snapshot['conversionId'], 'carton-to-package');
    expect(snapshot['inputUnit'], 'Carton');
    expect(snapshot['baseUnit'], 'Package');
    expect(InventoryUnits.toBase(500, ' Gram ', ' kg ', []), 0.5);
    expect(
        () => InventoryUnits.validateConversions('Package', [
              definition,
              {...carton(24), 'id': 'different-id'}
            ]),
        throwsArgumentError);
  });

  test('Invalid quantities and overflowing converted balances fail', () {
    for (final quantity in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1000000001.0,
      0.1234561,
    ]) {
      expect(() => InventoryUnits.toBase(quantity, 'Package', 'Package', []),
          throwsArgumentError);
    }
    expect(
        () => InventoryUnits.toBase(
            1000000000, 'Carton', 'Package', [carton(12)]),
        throwsArgumentError);
    expect(
        () => InventoryUnits.toBase(1, '', 'Package', []), throwsArgumentError);
    expect(
        () => InventoryUnits.toBase(1, 'Package', '', []), throwsArgumentError);
  });
}
