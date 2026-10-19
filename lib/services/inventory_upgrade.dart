import 'dart:convert';
import 'package:hive/hive.dart';
import 'inventory_migration.dart';
import 'state_schema.dart';

/// Stages before-images and both upgraded snapshots before changing either store.
class InventoryUpgrade {
  static Future<void>? _running;
  static Future<void> prepare() {
    if (_running != null) return _running!;
    final work = _prepare();
    _running = work;
    return work.whenComplete(() => _running = null);
  }

  static Future<void> _prepare() async {
    final journal = await Hive.openBox<String>('inventory_upgrade_v13');
    if (journal.containsKey('pending')) {
      await _apply(
          journal, jsonDecode(journal.get('pending')!) as Map<String, dynamic>);
    }
    final before = <String, String?>{};
    final after = <String, Map<String, dynamic>>{};
    var changed = false;
    for (final key in ['warehouse', 'shop']) {
      final box = await Hive.openBox<String>('${key}_state_v1');
      before[key] = box.get('state');
      if (before[key] == null) {
        continue; // Old typed boxes are left to their importer.
      }
      final data = jsonDecode(before[key]!) as Map<String, dynamic>;
      StateSchema.inventory(key, data);
      changed = changed || data['version'] != 13;
      after[key] = key == 'shop'
          ? InventoryMigration.shop(data)
          : InventoryMigration.warehouse(data);
    }
    if (!changed) return;
    for (final e in after.entries) {
      StateSchema.inventory(e.key, e.value);
    }
    if (after.length == 2) {
      StateSchema.pair(after['warehouse']!, after['shop']!);
    }
    final payload = {'before': before, 'after': after};
    // Keep each immutable before-image after pending work has been recovered.
    final id =
        after.values.map((s) => s['migration']?['id'] ?? 'current').join(':');
    if (!journal.containsKey('before:$id')) {
      await journal.put('before:$id', jsonEncode(before));
      await journal.flush();
    }
    await journal.put('pending', jsonEncode(payload));
    await journal.flush();
    await _apply(journal, payload);
  }

  static Future<void> _apply(
      Box<String> journal, Map<String, dynamic> payload) async {
    final states = payload['after'] as Map;
    for (final e in states.entries) {
      StateSchema.inventory(e.key, Map<String, dynamic>.from(e.value));
    }
    if (states.length == 2) {
      StateSchema.pair(Map<String, dynamic>.from(states['warehouse']),
          Map<String, dynamic>.from(states['shop']));
    }
    for (final e in states.entries) {
      final box = await Hive.openBox<String>('${e.key}_state_v1');
      await box.put('state', jsonEncode(e.value));
      await box.flush();
    }
    await journal.delete('pending');
    await journal.flush();
  }
}
