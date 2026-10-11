import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/models/packaging_item.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/services/fill_costing.dart';
import 'package:detergent_factory/services/state_schema.dart';

void main() {
  test('Mass and volume fills use explicit units and measured density', () {
    final pack = PackagingProvider();
    pack.setLabelPriceUSD(0.1, 0);
    expect(FillCosting.massKg(500, 'g', 0), 0.5);
    expect(FillCosting.massKg(0.5, 'kg', 0), 0.5);
    expect(() => pack.calculateUnitCostUSD(500, 0.2, 2, unit: 'ml'),
        throwsArgumentError);
    pack.setDensity(1.2);
    expect(pack.calculateUnitCostUSD(500, 0.2, 2, unit: 'ml'),
        closeTo(1.5, 1e-12));
    expect(
        pack.calculateUnitCostUSD(0.5, 0.2, 2, unit: 'L'), closeTo(1.5, 1e-12));
    expect(
        pack.calculateUnitCostUSD(500, 0.2, 2, unit: 'g'), closeTo(1.3, 1e-12));
    pack.setPackagesPerCarton(6);
    pack.setCartonPriceUSD(0.6, 0);
    expect(pack.calculateTotalCartonCostUSD(500, 0.2, 2, unit: 'ml'),
        closeTo(9.6, 1e-12));
    expect(() => FillCosting.massKg(0, 'g', 1), throwsArgumentError);
    expect(() => FillCosting.massKg(10, 'unknown', 1), throwsArgumentError);
    expect(() => FillCosting.massKg(double.infinity, 'kg', 1),
        throwsArgumentError);
    expect(() => pack.calculateUnitCostUSD(2, 1, double.maxFinite, unit: 'kg'),
        throwsArgumentError);
    pack.dispose();
  });
  test(
      'Legacy fill sizes require confirmation; unit and density survive persistence and schema validation',
      () async {
    final directory = await Directory.systemTemp.createTemp('fill_costing_');
    Hive.init(directory.path);
    final box = await Hive.openBox<String>('costing_drafts_v1');
    final pack = PackagingProvider(storage: box);
    final old = {
      'version': 1,
      'perCarton': 6,
      'cartonUSD': 0.6,
      'cartonSYP': 0,
      'labelUSD': 0.1,
      'labelSYP': 0,
      'items': [
        {'size': 500, 'usd': 0.2, 'syp': 0, 'carton': true}
      ]
    };
    pack.loadDraft(old);
    expect(pack.packagingItems.single.unitConfirmed, false);
    expect(pack.packagingItems.single.size, 500);
    pack.setDensity(1.2);
    pack.updatePackagingItem(0,
        pack.packagingItems.single.copyWith(unit: 'ml', unitConfirmed: true));
    await pack.flushDraft();
    final reopened = PackagingProvider(storage: box);
    expect(reopened.densityKgPerLiter, 1.2);
    expect(reopened.packagingItems.single.unit, 'ml');
    expect(reopened.packagingItems.single.unitConfirmed, true);
    StateSchema.draft('packaging', reopened.toDraft());
    final invalid = reopened.toDraft();
    (invalid['items'] as List).single['unit'] = 'unknown';
    expect(
        () => StateSchema.draft('packaging', invalid), throwsFormatException);
    expect(
        () => reopened.updatePackagingItem(0, PackagingItem(unit: 'unknown')),
        throwsArgumentError);
    pack.dispose();
    reopened.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
}
