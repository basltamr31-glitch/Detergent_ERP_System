import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:detergent_factory/models/raw_material.dart';
import 'package:detergent_factory/providers/production_provider.dart';
import 'package:detergent_factory/providers/packaging_provider.dart';
import 'package:detergent_factory/providers/warehouse_provider.dart';
import 'package:detergent_factory/providers/shop_provider.dart';
import 'package:detergent_factory/services/backup_service.dart';
import 'package:detergent_factory/services/state_schema.dart';

void main() {
  test('Batch labor and overhead flow into yield and packaging estimates', () {
    final production = ProductionProvider(), packaging = PackagingProvider();
    production.setProducedQuantity(10);
    production.setExchangeRate(100);
    production.addRawMaterial();
    production.updateRawMaterial(
        0, RawMaterial(name: 'Concentrate', quantity: 2, priceUSD: 10));
    production.setLaborUSD(5);
    production.setOverheadUSD(3);
    expect(production.materialCostUSD, 20);
    expect(production.totalCostUSD, 28);
    expect(production.totalCostSYP, 2800);
    expect(production.totalCostUSDKG, 2.8);
    packaging.setDensity(1.2);
    packaging.setLabelPriceUSD(0.1, 100);
    expect(
        packaging.calculateUnitCostUSD(500, 0.2, production.totalCostUSDKG,
            unit: 'ml'),
        closeTo(1.98, 1e-12));
    production.setProducedQuantity(8);
    expect(production.totalCostUSDKG, 3.5);
    expect(() => production.setLaborUSD(-1), throwsArgumentError);
    expect(() => production.setOverheadUSD(double.nan), throwsArgumentError);
    production.dispose();
    packaging.dispose();
  });
  test(
      'Legacy charges default to zero and new estimates survive persistence and backup validation',
      () async {
    final directory = await Directory.systemTemp.createTemp('batch_costs_');
    Hive.init(directory.path);
    final box = await Hive.openBox<String>('costing_drafts_v1');
    final production = ProductionProvider(storage: box),
        packaging = PackagingProvider(storage: box);
    final wh = WarehouseProvider(), shop = ShopProvider();
    await wh.ready;
    await shop.ready;
    try {
      production.loadDraft({
        'version': 1,
        'name': 'Legacy',
        'laborUSD': 999,
        'overheadUSD': -10,
        'rate': 100,
        'quantity': 10,
        'materials': [
          {
            'name': 'Water',
            'quantity': 10,
            'usd': 1,
            'syp': 100,
            'active': false
          }
        ]
      });
      expect(production.laborUSD, 0);
      expect(production.overheadUSD, 0);
      expect(production.totalCostUSD, 10);
      production.setLaborUSD(5);
      production.setOverheadUSD(3);
      await production.flushDraft();
      final saved = jsonDecode(box.get('production')!) as Map<String, dynamic>;
      expect(saved['version'], 2);
      expect(saved['laborUSD'], 5);
      expect(saved['overheadUSD'], 3);
      final restored = ProductionProvider(storage: box);
      expect(restored.totalCostUSD, 18);
      expect(restored.productName, 'Legacy');
      restored.dispose();
      final backup = BackupService.decode(BackupService.encode({
        'warehouse': jsonDecode(wh.exportState()),
        'shop': jsonDecode(shop.exportState()),
        'production': production.toDraft(),
        'packaging': packaging.toDraft()
      }));
      expect(backup['production']['overheadUSD'], 3);
      final invalid = production.toDraft()..['laborUSD'] = -1;
      expect(() => StateSchema.draft('production', invalid),
          throwsFormatException);
    } finally {
      production.dispose();
      packaging.dispose();
      wh.dispose();
      shop.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
