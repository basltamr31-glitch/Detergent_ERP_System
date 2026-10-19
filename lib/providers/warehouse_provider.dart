import '../services/inventory_units.dart';
import '../services/inventory_migration.dart';
import '../services/inventory_upgrade.dart';
import '../models/stock_count.dart';
import '../services/access_control.dart';
import '../models/journal_entry.dart';
import '../services/accounting.dart';
import '../models/stock_transfer.dart';
import '../services/inventory_coordinator.dart';
import '../models/trade_line.dart';
import '../models/business_party.dart';
import '../models/document_payment.dart';
import '../models/trade_document.dart';
import '../services/money.dart';
import '../services/record_id.dart';
import '../services/state_schema.dart';
import 'dart:convert';
import '../services/stock_validation.dart';
import 'package:flutter/material.dart' show ChangeNotifier;
import 'package:hive/hive.dart';
import '../models/material.dart' as my_models;
import '../models/material_transaction.dart';
import '../models/manufactured_product.dart';

class WarehouseProvider with ChangeNotifier {
  Map<String, dynamic>? _migration;
  final List<my_models.Material> _materials = [];
  final List<MaterialTransaction> _transactions = [];
  final List<ManufacturedProduct> _manufacturedProducts = [];
  final List<TradeDocument> _purchases = [];
  final List<Map<String, dynamic>> _recipes = [], _orders = [];
  List<Map<String, dynamic>> get recipes => List.unmodifiable(_recipes.map(
      (r) => Map<String, dynamic>.unmodifiable(jsonDecode(jsonEncode(r)))));
  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders.map(
      (r) => Map<String, dynamic>.unmodifiable(jsonDecode(jsonEncode(r)))));
  Future<void> createOrder(String name, double quantity, String unit,
          String lot, String expiry, Map<String, double> ingredients,
          {required String requestId}) =>
      _post(() {
        name = StockValidation.name(name);
        unit = StockValidation.name(unit);
        lot = StockValidation.name(lot);
        Money.total(quantity, 0);
        StockValidation.ingredients(ingredients);
        if (expiry.isNotEmpty &&
            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiry) ||
                DateTime.parse(expiry).toIso8601String().substring(0, 10) !=
                    expiry)) {
          throw ArgumentError('Use a valid expiry date.');
        }
        final links = <String, double>{};
        for (final entry in ingredients.entries) {
          Money.total(entry.value, 0);
          final material = _materials.firstWhere((m) => m.name == entry.key);
          links[material.id] = entry.value;
        }
        final previous = _orders.where((o) => o['requestId'] == requestId);
        if (previous.isNotEmpty) {
          final o = previous.single;
          if (o['name'] != name ||
              o['quantity'] != quantity ||
              o['unit'] != unit ||
              o['lot'] != lot ||
              o['expiry'] != expiry ||
              jsonEncode(o['materials']) != jsonEncode(links)) {
            throw StateError('Order request already has different details.');
          }
          return;
        }
        if (requestId.trim().isEmpty || _orders.any((o) => o['lot'] == lot)) {
          throw ArgumentError('Use a unique lot number.');
        }
        final recipes = _recipes.where((r) => r['name'] == name).toList();
        final identical = recipes.where((r) =>
            r['quantity'] == quantity &&
            r['unit'] == unit &&
            jsonEncode(r['materials']) == jsonEncode(links));
        final recipe = identical.isNotEmpty
            ? identical.first
            : <String, dynamic>{
                'id': RecordId.create(),
                'name': name,
                'version': recipes.length + 1,
                'quantity': quantity,
                'unit': unit,
                'materials': links,
                'date': DateTime.now().toIso8601String(),
                'actor': AccessControl.actor
              };
        if (identical.isEmpty) _recipes.add(recipe);
        _orders.add({
          'id': RecordId.create(),
          'number': 'MOR-${(_orders.length + 1).toString().padLeft(6, '0')}',
          'requestId': requestId,
          'recipeId': recipe['id'],
          'name': name,
          'quantity': quantity,
          'unit': unit,
          'lot': lot,
          'expiry': expiry,
          'materials': links,
          'status': 'draft',
          'batchId': null,
          'events': [
            {
              'kind': 'created',
              'date': DateTime.now().toIso8601String(),
              'actor': AccessControl.actor,
              'reason': 'Planned production'
            }
          ]
        });
      });
  Future<void> approveOrder(String id, String reason) => _post(() {
        reason = StockValidation.name(reason);
        final o = _orders.firstWhere((o) => o['id'] == id);
        if (o['status'] != 'draft') {
          throw StateError('Only draft orders can be approved.');
        }
        o['status'] = 'approved';
        o['events'].add({
          'kind': 'approved',
          'date': DateTime.now().toIso8601String(),
          'actor': AccessControl.actor,
          'reason': reason
        });
      }, permission: 'approve');
  Future<void> releaseOrder(String id, String qualityNote) => _post(() {
        qualityNote = StockValidation.name(qualityNote);
        final o = _orders.firstWhere((o) => o['id'] == id);
        if (o['status'] == 'released' &&
            o['events'].last['reason'] == qualityNote) {
          return;
        }
        if (o['status'] != 'approved') {
          throw StateError('Approve the order before releasing production.');
        }
        if (o['expiry'] != '' &&
            (o['expiry'] as String).compareTo(Accounting.today()) <= 0) {
          throw StateError('Lot has expired.');
        }
        final ingredients = <String, double>{};
        for (final e in (o['materials'] as Map).entries) {
          ingredients[_materials.firstWhere((m) => m.id == e.key).name] =
              (e.value as num).toDouble();
        }
        _produce(o['name'], (o['quantity'] as num).toDouble(), ingredients,
            requestId: o['id']);
        o['batchId'] = _manufacturedProducts.last.id;
        o['status'] = 'released';
        o['events'].add({
          'kind': 'released',
          'date': DateTime.now().toIso8601String(),
          'actor': AccessControl.actor,
          'reason': qualityNote
        });
      });
  Future<void> cancelOrder(String id, String reason) => _post(() {
        reason = StockValidation.name(reason);
        final o = _orders.firstWhere((o) => o['id'] == id);
        if (!['draft', 'approved'].contains(o['status'])) {
          throw StateError('Only unposted orders can be cancelled.');
        }
        o['status'] = 'cancelled';
        o['events'].add({
          'kind': 'cancelled',
          'date': DateTime.now().toIso8601String(),
          'actor': AccessControl.actor,
          'reason': reason
        });
      }, permission: 'approve');
  final List<StockCount> _counts = [];
  List<StockCount> get counts => List.unmodifiable(_counts);
  Future<void> countStock(String itemId, double counted, String reason,
          {required String requestId}) =>
      _post(() {
        reason = StockValidation.name(reason);
        if (!counted.isFinite || counted < 0 || requestId.trim().isEmpty) {
          throw ArgumentError('Use a valid nonnegative count.');
        }
        if (counted > 0) Money.total(counted, 0);
        final previous = _counts.where((c) => c.requestId == requestId);
        if (previous.isNotEmpty) {
          final c = previous.single;
          if (c.itemId != itemId || c.after != counted || c.reason != reason) {
            throw StateError('Count request already has different details.');
          }
          return;
        }
        final item = _materials.firstWhere((i) => i.id == itemId);
        if (item.quantity == counted) {
          throw ArgumentError('Count is unchanged.');
        }
        final count = StockCount(
            itemId: itemId,
            before: item.quantity,
            after: counted,
            reason: reason,
            date: DateTime.now(),
            requestId: requestId);
        _transactions.add(MaterialTransaction(
            documentId: count.id,
            materialId: item.id,
            materialName: item.name,
            quantity: (counted - item.quantity).abs(),
            type: counted > item.quantity ? 'COUNT_IN' : 'COUNT_OUT',
            date: count.date));
        item.quantity = counted;
        _counts.add(count);
      }, permission: 'warehouse');
  final List<JournalEntry> _journals = [];
  List<JournalEntry> get journals => List.unmodifiable(_journals);
  final List<Map<String, dynamic>> _periodEvents = [];
  String? _closedThrough;
  String? get closedThrough => _closedThrough;
  String? _ledgerStartedAt;
  String? get ledgerStartedAt => _ledgerStartedAt;
  Future<void> postJournal(String debitAccount, String creditAccount,
          int amountMinor, String currency, String reference,
          {required String requestId}) =>
      _financePost(() {
        final previous = _journals.where((j) => j.sourceId == requestId);
        if (previous.isNotEmpty) {
          final j = previous.single;
          if (j.kind != 'manual' ||
              j.currency != currency ||
              j.reference != reference.trim() ||
              j.lines[0].account != debitAccount ||
              j.lines[1].account != creditAccount ||
              j.lines[0].debit != amountMinor) {
            throw StateError('Journal request already has different details.');
          }
          return;
        }
        if (amountMinor <= 0 ||
            debitAccount == creditAccount ||
            requestId.trim().isEmpty) {
          throw ArgumentError('Use distinct accounts and a positive amount.');
        }
        final entry = JournalEntry(
            sourceId: requestId,
            kind: 'manual',
            date: DateTime.now(),
            currency: currency,
            reference: StockValidation.name(reference),
            lines: [
              JournalLine(debitAccount, debit: amountMinor),
              JournalLine(creditAccount, credit: amountMinor)
            ]);
        Accounting.validate(entry);
        _journals.add(entry);
      });
  void _journalize(String before) {
    final old = jsonDecode(before) as Map<String, dynamic>;
    final sources = {
      for (final d in old['purchases'] as List) d['id'],
      for (final p in old['payments'] as List) p['id']
    };
    for (final d in _purchases.where((d) => !sources.contains(d.id))) {
      final entry = JournalEntry.trade(d);
      Accounting.validate(entry);
      _journals.add(entry);
    }
    for (final p in _payments.where((p) => !sources.contains(p.id))) {
      final entry = JournalEntry.payment(
          p, _purchases.firstWhere((d) => d.id == p.documentId));
      Accounting.validate(entry);
      _journals.add(entry);
    }
  }

  final List<StockTransfer> _transfers = [];
  List<StockTransfer> get transfers => List.unmodifiable(_transfers);
  final List<BusinessParty> _parties = [];
  List<BusinessParty> get parties => List.unmodifiable(_parties);
  Map<String, int> outstandingForParty(String id) {
    final balances = <String, int>{};
    for (final doc in _purchases.where((d) =>
        d.partyId == id && d.reversalOf == null && !isPurchaseReversed(d.id))) {
      balances.update(
          doc.currency, (value) => value + doc.totalMinor - paidFor(doc),
          ifAbsent: () => doc.totalMinor - paidFor(doc));
    }
    return Map.unmodifiable(balances);
  }

  Future<void> saveParty(
          {String? id,
          required String name,
          String phone = '',
          String address = '',
          bool active = true}) =>
      _partnersPost(() {
        name = StockValidation.name(name);
        if (_parties.any(
            (p) => p.id != id && p.name.toLowerCase() == name.toLowerCase())) {
          throw ArgumentError('A record with this name already exists.');
        }
        final party = BusinessParty(
            id: id,
            name: name,
            phone: phone.trim(),
            address: address.trim(),
            active: active);
        if (id == null) {
          _parties.add(party);
        } else {
          final index = _parties.indexWhere((p) => p.id == id);
          if (index < 0) throw StateError('Party not found.');
          _parties[index] = party;
        }
      });

  final List<DocumentPayment> _payments = [];
  List<DocumentPayment> get payments => List.unmodifiable(_payments);
  int paidFor(TradeDocument document) =>
      document.paidMinor +
      _payments.where((p) => p.documentId == document.id).fold(
          0,
          (sum, p) =>
              sum + (p.kind == 'refund' ? -p.amountMinor : p.amountMinor));
  Future<void> recordRefund(String documentId, int amountMinor, String reason,
          {required String requestId}) =>
      _financePost(() {
        reason = StockValidation.name(reason);
        final previous = _payments.where((p) => p.requestId == requestId);
        if (previous.isNotEmpty) {
          final p = previous.single;
          if (p.kind != 'refund' ||
              p.documentId != documentId ||
              p.amountMinor != amountMinor ||
              p.reason != reason) {
            throw StateError(
                'This refund request already has different details.');
          }
          return;
        }
        final document = _purchases.firstWhere((d) => d.id == documentId);
        if (requestId.trim().isEmpty ||
            document.reversalOf != null ||
            isPurchaseReversed(documentId)) {
          throw StateError('Select an active document.');
        }
        if (amountMinor <= 0 || amountMinor > paidFor(document)) {
          throw ArgumentError('Refund cannot exceed the paid amount.');
        }
        _payments.add(DocumentPayment(
            documentId: documentId,
            amountMinor: amountMinor,
            date: DateTime.now(),
            requestId: requestId,
            kind: 'refund',
            reason: reason));
      });
  Future<void> recordPayment(String documentId, int amountMinor,
          {required String requestId, String reference = ''}) =>
      _financePost(() {
        final previous = _payments.where((p) => p.requestId == requestId);
        if (previous.isNotEmpty) {
          final p = previous.single;
          if (p.kind != 'payment' ||
              p.documentId != documentId ||
              p.amountMinor != amountMinor ||
              p.reference != reference.trim()) {
            throw StateError(
                'This payment request already has different details.');
          }
          return;
        }
        if (requestId.trim().isEmpty) {
          throw ArgumentError('Payment request is required.');
        }
        final document = _purchases.firstWhere((d) => d.id == documentId);
        if (document.reversalOf != null || isPurchaseReversed(documentId)) {
          throw StateError('Cannot pay a reversed document.');
        }
        if (amountMinor <= 0 ||
            amountMinor > document.totalMinor - paidFor(document)) {
          throw ArgumentError(
              'Payment must be positive and cannot exceed the balance.');
        }
        _payments.add(DocumentPayment(
            documentId: documentId,
            amountMinor: amountMinor,
            date: DateTime.now(),
            requestId: requestId,
            reference: reference.trim()));
      });

  List<TradeDocument> get purchases => List.unmodifiable(_purchases);
  List<ManufacturedProduct> get productionDocuments =>
      List.unmodifiable(_manufacturedProducts);
  double finishedAvailable(String batchId) {
    final batch = _manufacturedProducts.firstWhere((b) => b.id == batchId);
    if (isProductionReversed(batchId)) return 0;
    final used = _transfers.where((t) => t.batchId == batchId).fold(
        0.0,
        (sum, t) =>
            sum +
            (t.reversalOf == null ? t.sourceQuantity : -t.sourceQuantity));
    return double.parse((batch.quantity - used).toStringAsFixed(6));
  }

  bool isProductionReversed(String id) =>
      _manufacturedProducts.any((p) => p.reversalOf == id);
  bool isPurchaseReversed(String id) =>
      _purchases.any((p) => p.reversalOf == id);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  bool _saving = false;
  bool get isSaving => _saving;
  String? loadError;
  late final Future<void> ready = initialize();
  Box<String>? _stateBox;
  bool _initializing = false;

  List<my_models.Material> get materials =>
      List.unmodifiable(_materials.map((m) => my_models.Material(
          id: m.id,
          name: m.name,
          quantity: m.quantity,
          unit: m.unit,
          priceCurrency: m.priceCurrency,
          sku: m.sku.isEmpty ? 'RAW-${m.id}' : m.sku,
          unitConversions: m.unitConversions,
          unitPrice: m.unitPrice)));
  List<MaterialTransaction> get transactions =>
      List.unmodifiable(_transactions.map((t) => MaterialTransaction(
          id: t.id,
          documentId: t.documentId,
          materialId: t.materialId,
          materialName: t.materialName,
          quantity: t.quantity,
          type: t.type,
          date: t.date)));
  List<ManufacturedProduct> get manufacturedProducts =>
      List.unmodifiable(_manufacturedProducts
          .where((m) => m.kind == 'production' && !isProductionReversed(m.id)));

  int get totalMaterials => _materials.length;

  WarehouseProvider() {
    ready;
  }

  String exportState() {
    InventoryCoordinator.check();
    if (!_isLoaded || _saving) throw StateError('Inventory is busy.');
    return _snapshot();
  }

  Future<void> reloadState() async {
    if (_saving) throw StateError('Inventory is busy.');
    _isLoaded = false;
    await initialize();
    if (!_isLoaded) {
      throw StateError(loadError ?? 'Unable to reload inventory.');
    }
  }

  String _snapshot() => jsonEncode({
        'version': 13,
        if (_migration != null) 'migration': _migration,
        'recipes': _recipes,
        'orders': _orders,
        'counts': _counts.map((c) => c.toJson()).toList(),
        'journals': _journals.map((j) => j.toJson()).toList(),
        'closedThrough': _closedThrough,
        'periodEvents': _periodEvents,
        'ledgerStartedAt':
            _ledgerStartedAt ?? DateTime.now().toUtc().toIso8601String(),
        'transfers': _transfers.map((t) => t.toJson()).toList(),
        'parties': _parties.map((p) => p.toJson()).toList(),
        'payments': _payments.map((p) => p.toJson()).toList(),
        'purchases': _purchases.map((p) => p.toJson()).toList(),
        'materials': _materials
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'quantity': m.quantity,
                  'unit': m.unit,
                  'price': m.unitPrice,
                  'priceCurrency': m.priceCurrency,
                  'sku': m.sku.isEmpty ? 'RAW-${m.id}' : m.sku,
                  'unitConversions': m.unitConversions
                })
            .toList(),
        'transactions': _transactions
            .map((t) => {
                  'id': t.id,
                  'documentId': t.documentId,
                  'materialId': t.materialId,
                  'name': t.materialName,
                  'quantity': t.quantity,
                  'type': t.type,
                  'date': t.date.toIso8601String()
                })
            .toList(),
        'batches': _manufacturedProducts
            .map((m) => {
                  'id': m.id,
                  'actor': m.actor,
                  'name': m.name,
                  'quantity': m.quantity,
                  'date': m.date.toIso8601String(),
                  'materials': m.rawMaterialsUsed,
                  'materialIds': m.materialIds,
                  'number': m.number,
                  'kind': m.kind,
                  'reason': m.reason,
                  'reversalOf': m.reversalOf,
                  'replacesId': m.replacesId,
                  'requestId': m.requestId
                })
            .toList()
      });
  void _restore(String value) {
    final data =
        InventoryMigration.warehouse(jsonDecode(value) as Map<String, dynamic>);
    StateSchema.inventory('warehouse', data);
    _migration = data['migration'] == null
        ? null
        : Map<String, dynamic>.from(data['migration']);
    if (![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
        .contains(data['version'])) {
      throw StateError('Unsupported inventory version.');
    }
    _recipes
      ..clear()
      ..addAll((data['recipes'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r)));
    _orders
      ..clear()
      ..addAll((data['orders'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r)));
    _counts
      ..clear()
      ..addAll((data['counts'] as List? ?? [])
          .map((c) => StockCount.fromJson(Map<String, dynamic>.from(c))));
    _periodEvents
      ..clear()
      ..addAll((data['periodEvents'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)));
    _closedThrough = data['closedThrough'];
    _ledgerStartedAt =
        data['ledgerStartedAt'] ?? DateTime.now().toUtc().toIso8601String();
    _journals
      ..clear()
      ..addAll((data['journals'] as List? ?? [])
          .map((j) => JournalEntry.fromJson(Map<String, dynamic>.from(j))));
    _transfers
      ..clear()
      ..addAll((data['transfers'] as List? ?? [])
          .map((t) => StockTransfer.fromJson(Map<String, dynamic>.from(t))));
    _parties
      ..clear()
      ..addAll((data['parties'] as List? ?? [])
          .map((p) => BusinessParty.fromJson(Map<String, dynamic>.from(p))));
    _payments
      ..clear()
      ..addAll((data['payments'] as List? ?? [])
          .map((p) => DocumentPayment.fromJson(Map<String, dynamic>.from(p))));
    _materials
      ..clear()
      ..addAll((data['materials'] as List).map((m) => my_models.Material(
          id: m['id'] as String?,
          sku: m['sku'],
          unitConversions: (m['unitConversions'] as List)
              .map((c) => Map<String, dynamic>.from(c))
              .toList(),
          name: m['name'],
          quantity: (m['quantity'] as num).toDouble(),
          unit: m['unit'],
          priceCurrency: m['priceCurrency'] ?? '',
          unitPrice: (m['price'] as num).toDouble())));
    _transactions
      ..clear()
      ..addAll((data['transactions'] as List).map((t) => MaterialTransaction(
          id: t['id'] as String?,
          documentId: t['documentId'] as String?,
          materialId: t['materialId'] as String?,
          materialName: t['name'],
          quantity: (t['quantity'] as num).toDouble(),
          type: t['type'],
          date: DateTime.parse(t['date']))));
    _manufacturedProducts
      ..clear()
      ..addAll((data['batches'] as List).asMap().entries.map((entry) {
        final m = entry.value;
        return ManufacturedProduct(
            id: m['id'] as String?,
            actor: Map<String, String>.from(m['actor'] ??
                {'id': 'legacy', 'name': 'Legacy record', 'role': 'legacy'}),
            number: m['number'] ??
                'PRD-${(entry.key + 1).toString().padLeft(6, '0')}',
            kind: m['kind'] ?? 'production',
            reason: m['reason'] ?? '',
            reversalOf: m['reversalOf'],
            replacesId: m['replacesId'],
            requestId: m['requestId'] ?? m['id'],
            materialIds: Map<String, String>.from(m['materialIds'] ?? {}),
            name: m['name'],
            quantity: (m['quantity'] as num).toDouble(),
            date: DateTime.parse(m['date']),
            rawMaterialsUsed: (m['materials'] as Map)
                .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
      }));
    _purchases
      ..clear()
      ..addAll((data['purchases'] as List? ?? [])
          .map((p) => TradeDocument.fromJson(Map<String, dynamic>.from(p))));
  }

  Future<void> initialize() async {
    if (_initializing || _isLoaded) return;
    _initializing = true;
    loadError = null;
    notifyListeners();
    try {
      await InventoryUpgrade.prepare();
      _ledgerStartedAt ??= DateTime.now().toUtc().toIso8601String();
      _stateBox = await Hive.openBox<String>('warehouse_state_v1');
      final saved = _stateBox!.get('state');
      if (saved != null) {
        _restore(saved);
        StateSchema.inventory(
            'warehouse', jsonDecode(_snapshot()) as Map<String, dynamic>);
        await _stateBox!.put('state', _snapshot());
        await _stateBox!.flush();
      } else {
        _materials.clear();
        _transactions.clear();
        _manufacturedProducts.clear();
        _purchases.clear();
        final boxMat =
            await Hive.openBox<my_models.Material>('warehouse_materials');
        final boxTrans =
            await Hive.openBox<MaterialTransaction>('warehouse_transactions');
        final boxMfg = await Hive.openBox<ManufacturedProduct>(
            'warehouse_mfg_products_v2');

        _materials.addAll(boxMat.values);
        _transactions.addAll(boxTrans.values);
        _manufacturedProducts
            .addAll(boxMfg.values.toList().asMap().entries.map((entry) {
          final m = entry.value;
          return ManufacturedProduct(
              id: m.id,
              number: 'PRD-${(entry.key + 1).toString().padLeft(6, '0')}',
              name: m.name,
              quantity: m.quantity,
              date: m.date,
              rawMaterialsUsed: m.rawMaterialsUsed);
        }));

        StateSchema.inventory(
            'warehouse', jsonDecode(_snapshot()) as Map<String, dynamic>);
        await _stateBox!.put('state', _snapshot());
        await _stateBox!.flush();
      }
      _isLoaded = true;
    } catch (e) {
      loadError = e.toString();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _financePost(void Function() change) =>
      _post(change, permission: 'finance');
  Future<void> _partnersPost(void Function() change) =>
      _post(change, permission: 'partners');
  Future<void> _post(void Function() change,
      {String permission = 'warehouse'}) async {
    AccessControl.require(permission);
    InventoryCoordinator.check();
    Accounting.checkPeriod(_closedThrough);
    if (!_isLoaded) throw StateError('Inventory is not ready.');
    if (_saving) throw StateError('Another stock operation is saving.');
    final before = _snapshot();
    bool changed = false;
    _saving = true;
    notifyListeners();
    try {
      change();
      _journalize(before);
      StateSchema.inventory(
          'warehouse', jsonDecode(_snapshot()) as Map<String, dynamic>);
      changed = true;
      await _stateBox!.put('state', _snapshot());
      await _stateBox!.flush();
    } catch (_) {
      // Hive rolls back failed puts; reload the committed record after I/O errors.
      _restore(changed ? (_stateBox!.get('state') ?? before) : before);
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> resetWarehouse() => Future.error(StateError(
      'Inventory history cannot be reset. Use reversals or restore a backup.'));

  double getStock(String name) {
    final existingIndex = _materials.indexWhere((m) => m.name == name);
    if (existingIndex >= 0) {
      return _materials[existingIndex].quantity;
    }
    return 0.0;
  }

  Future<void> addMaterial(
          String name, double quantity, String unit, double unitPrice) =>
      _post(() => _receiveStock(name, quantity, unit, unitPrice));
  void _receiveStock(
      String name, double quantity, String unit, double unitPrice,
      {String? documentId, String priceCurrency = ''}) {
    name = StockValidation.name(name);
    StockValidation.positive(quantity);
    StockValidation.price(unitPrice);
    if (unit.trim().isEmpty) throw ArgumentError('Unit is required.');

    final existingIndex = _materials.indexWhere((m) => m.name == name);
    if (existingIndex >= 0) {
      if (_materials[existingIndex].unit != unit) {
        throw ArgumentError('Use the existing stock unit.');
      }
      StockValidation.positive(_materials[existingIndex].quantity + quantity);
      _materials[existingIndex].quantity += quantity;
      _materials[existingIndex].unit = unit;
      _materials[existingIndex].unitPrice = unitPrice;
      _materials[existingIndex].priceCurrency = priceCurrency;
    } else {
      final newMat = my_models.Material(
          name: name,
          quantity: quantity,
          unit: unit,
          unitPrice: unitPrice,
          priceCurrency: priceCurrency);
      _materials.add(newMat);
    }

    final trans = MaterialTransaction(
      materialId: _materials.firstWhere((m) => m.name == name).id,
      documentId: documentId,
      materialName: name,
      quantity: quantity,
      type: 'IN',
      date: DateTime.now(),
    );
    _transactions.add(trans);
  }

  Future<void> removeMaterial(String name, double quantity) => _post(() {
        StockValidation.positive(quantity);

        final existingIndex = _materials.indexWhere((m) => m.name == name);
        if (existingIndex >= 0) {
          if (_materials[existingIndex].quantity >= quantity) {
            _materials[existingIndex].quantity -= quantity;

            final trans = MaterialTransaction(
              materialId: _materials[existingIndex].id,
              materialName: name,
              quantity: quantity,
              type: 'OUT',
              date: DateTime.now(),
            );
            _transactions.add(trans);
          } else {
            throw Exception(
                "Insufficient stock. Available: ${_materials[existingIndex].quantity}");
          }
        } else {
          throw Exception("Material not found in stock.");
        }
      });

  void _produce(String name, double quantity, Map<String, double> ingredients,
      {String? replacesId, String reason = '', String? requestId}) {
    name = StockValidation.name(name);
    StockValidation.positive(quantity);
    StockValidation.ingredients(ingredients);
    for (final entry in ingredients.entries) {
      if (getStock(entry.key) < entry.value) {
        throw StateError('Insufficient stock for ${entry.key}.');
      }
    }
    final batch = ManufacturedProduct(
        number:
            'PRD-${(_manufacturedProducts.length + 1).toString().padLeft(6, '0')}',
        name: name,
        quantity: quantity,
        date: DateTime.now(),
        rawMaterialsUsed: ingredients,
        materialIds: {
          for (final name in ingredients.keys)
            name: _materials.firstWhere((m) => m.name == name).id
        },
        replacesId: replacesId,
        requestId: requestId,
        reason: reason);
    for (final entry in ingredients.entries) {
      final material =
          _materials.firstWhere((m) => m.id == batch.materialIds[entry.key]);
      material.quantity -= entry.value;
      _transactions.add(MaterialTransaction(
          materialId: material.id,
          documentId: batch.id,
          materialName: material.name,
          quantity: entry.value,
          type: 'CONSUMPTION',
          date: batch.date));
    }
    _manufacturedProducts.add(batch);
  }

  Future<void> produceManufacturedProduct(
          String name, double quantity, Map<String, double> ingredients,
          {String? requestId}) =>
      _post(() {
        AccessControl.require('approve');
        if (_alreadyProduced(requestId, name, quantity, ingredients, null)) {
          return;
        }
        _produce(name, quantity, ingredients, requestId: requestId);
      });

  bool _alreadyProduced(String? requestId, String name, double quantity,
      Map<String, double> ingredients, String? replacesId) {
    if (requestId == null) return false;
    for (final existing
        in _manufacturedProducts.where((p) => p.requestId == requestId)) {
      if (existing.kind != 'production' ||
          existing.name != name.trim() ||
          existing.quantity != quantity ||
          existing.replacesId != replacesId ||
          existing.rawMaterialsUsed.length != ingredients.length ||
          ingredients.entries
              .any((e) => existing.rawMaterialsUsed[e.key] != e.value)) {
        throw StateError(
            'This request was already posted with different details.');
      }
      return true;
    }
    return false;
  }

  void _reverseProduction(String id, String reason) {
    reason = StockValidation.name(reason);
    if (_transfers.any((t) => t.batchId == id) &&
        finishedAvailable(id) !=
            _manufacturedProducts.firstWhere((b) => b.id == id).quantity) {
      throw StateError(
          'Return finished-goods transfers before reversing production.');
    }
    final batch = _manufacturedProducts.firstWhere((p) => p.id == id,
        orElse: () => throw StateError('Batch not found.'));
    if (batch.kind != 'production' || isProductionReversed(id)) {
      throw StateError('Batch has already been reversed.');
    }
    final reversal = ManufacturedProduct(
        number:
            'PRD-${(_manufacturedProducts.length + 1).toString().padLeft(6, '0')}',
        name: batch.name,
        quantity: batch.quantity,
        date: DateTime.now(),
        rawMaterialsUsed: batch.rawMaterialsUsed,
        materialIds: batch.materialIds,
        kind: 'reversal',
        reversalOf: id,
        reason: reason);
    for (final entry in batch.rawMaterialsUsed.entries) {
      final material = _materials.firstWhere(
          (m) => batch.materialIds[entry.key] != null
              ? m.id == batch.materialIds[entry.key]
              : m.name == entry.key,
          orElse: () => throw StateError(
              'Original material is missing; reconcile inventory first.'));
      StockValidation.positive(material.quantity + entry.value);
      material.quantity += entry.value;
      _transactions.add(MaterialTransaction(
          materialId: material.id,
          documentId: reversal.id,
          materialName: material.name,
          quantity: entry.value,
          type: 'RESTORE',
          date: reversal.date));
    }
    _manufacturedProducts.add(reversal);
  }

  Future<void> reverseProduction(String id, String reason) =>
      _post(() => _reverseProduction(id, reason));
  Future<void> deleteManufacturedProduct(ManufacturedProduct batch) =>
      reverseProduction(batch.id, 'Cancelled from warehouse');
  Future<void> editManufacturedProduct(ManufacturedProduct batch, String name,
          double quantity, Map<String, double> ingredients,
          {String? requestId}) =>
      _post(() {
        if (_alreadyProduced(
            requestId, name, quantity, ingredients, batch.id)) {
          return;
        }
        _reverseProduction(batch.id, 'Replaced by corrected production');
        _produce(name, quantity, ingredients,
            replacesId: batch.id, reason: 'Correction', requestId: requestId);
      });

  Future<void> configureMaterial(String id,
          {required String name,
          required String sku,
          required List<Map<String, dynamic>> unitConversions}) =>
      _post(() {
        name = StockValidation.name(name);
        sku = StockValidation.name(sku);
        final material = _materials.firstWhere((m) => m.id == id);
        if (_materials
            .any((m) => m.id != id && (m.name == name || m.sku == sku))) {
          throw ArgumentError('Use a unique raw material name and SKU.');
        }
        InventoryUnits.validateConversions(material.unit, unitConversions);
        material.name = name;
        material.sku = sku;
        material.unitConversions =
            unitConversions.map((c) => Map<String, dynamic>.from(c)).toList();
      });

  Future<void> receivePurchase(
          {required String supplier,
          required String materialName,
          required double quantity,
          required String unit,
          required int unitPriceMinor,
          required String currency,
          int paidMinor = 0,
          String reference = '',
          String? partyId,
          String? requestId}) =>
      receivePurchases([
        TradeInput(
            name: materialName,
            quantity: quantity,
            unit: unit,
            unitPriceMinor: unitPriceMinor)
      ],
          supplier: supplier,
          currency: currency,
          paidMinor: paidMinor,
          reference: reference,
          partyId: partyId,
          requestId: requestId);
  Future<void> receivePurchases(List<TradeInput> items,
          {required String supplier,
          required String currency,
          int paidMinor = 0,
          String reference = '',
          String? partyId,
          String? requestId}) =>
      _post(() {
        final token = requestId ?? RecordId.create();
        supplier = StockValidation.name(supplier);
        if (partyId != null &&
            !_parties.any(
                (p) => p.id == partyId && p.active && p.name == supplier)) {
          throw StateError('Select an active supplier and its current name.');
        }
        if (!Money.currencies.contains(currency) || items.isEmpty) {
          throw ArgumentError('Select currency and items.');
        }
        final names = <String>{};
        for (final item in items) {
          if (!names.add(StockValidation.name(item.name)) ||
              item.unit.trim().isEmpty) {
            throw ArgumentError('Use unique items and valid units.');
          }
        }
        final total = items.fold(
            0, (sum, l) => sum + Money.total(l.quantity, l.unitPriceMinor));
        if (total > Money.maxMinor || paidMinor < 0 || paidMinor > total) {
          throw ArgumentError('Invalid total or payment.');
        }
        final previous = _purchases.where((d) => d.requestId == token);
        if (previous.isNotEmpty) {
          final d = previous.single;
          bool same = d.lines.length == items.length;
          for (int i = 0; same && i < items.length; i++) {
            final l = d.lines[i], input = items[i];
            same = l.itemName == input.name.trim() &&
                l.quantity == input.quantity &&
                l.unit == input.unit &&
                l.unitPriceMinor == input.unitPriceMinor;
          }
          if (!same ||
              d.party != supplier ||
              d.partyId != partyId ||
              d.currency != currency ||
              d.paidMinor != paidMinor ||
              d.reference != reference.trim()) {
            throw StateError(
                'This request was already posted with different details.');
          }
          return;
        }
        final id = RecordId.create();
        final lines = <TradeLine>[];
        for (final item in items) {
          final matches = _materials.where((m) => item.itemId != null
              ? m.id == item.itemId
              : m.name == item.name.trim());
          final existing = matches.isEmpty ? null : matches.single;
          if (item.itemId != null && existing == null) {
            throw StateError('Material not found.');
          }
          final baseUnit = existing?.unit ?? item.unit;
          final conversion = InventoryUnits.snapshot(item.quantity, item.unit,
              baseUnit, existing?.unitConversions ?? []);
          final baseQuantity = (conversion['baseQuantity'] as num).toDouble();
          final name = existing?.name ?? item.name;
          _receiveStock(name, baseQuantity, baseUnit,
              item.unitPriceMinor / 100 * item.quantity / baseQuantity,
              documentId: id, priceCurrency: currency);
          final material = _materials.firstWhere((m) => m.name == name.trim());
          lines.add(TradeLine(
              itemId: material.id,
              itemName: material.name,
              unit: item.unit,
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              stockQuantity: baseQuantity,
              stockUnit: baseUnit,
              conversion: conversion));
        }
        final first = lines.first;
        _purchases.add(TradeDocument(
            id: id,
            number: 'PUR-${(_purchases.length + 1).toString().padLeft(6, '0')}',
            type: 'purchase',
            date: DateTime.now(),
            party: supplier,
            partyId: partyId,
            currency: currency,
            itemId: first.itemId,
            itemName: first.itemName,
            unit: first.unit,
            quantity: first.quantity,
            unitPriceMinor: first.unitPriceMinor,
            lines: lines,
            totalMinor: total,
            paidMinor: paidMinor,
            reference: reference.trim(),
            requestId: token));
      });
  Future<void> reversePurchase(String id, String reason) => _post(() {
        reason = StockValidation.name(reason);
        final receipt = _purchases.firstWhere((p) => p.id == id,
            orElse: () => throw StateError('Receipt not found.'));
        if (receipt.purchaseKind == 'trading') {
          throw StateError('Use the finished-goods purchase return action.');
        }
        if (paidFor(receipt) != 0) {
          throw StateError(
              'Record the actual refund of all payments before returning goods.');
        }
        if (receipt.reversalOf != null || isPurchaseReversed(id)) {
          throw StateError('Receipt has already been reversed.');
        }
        for (final line in receipt.lines) {
          final material = _materials.firstWhere((m) => m.id == line.itemId);
          if (material.quantity < line.baseQuantity) {
            throw StateError(
                'Received stock has been consumed; reversal would make stock negative.');
          }
          material.quantity -= line.baseQuantity;
        }
        final reversal = TradeDocument(
            number: 'PUR-${(_purchases.length + 1).toString().padLeft(6, '0')}',
            type: 'purchaseReturn',
            date: DateTime.now(),
            lines: receipt.lines,
            party: receipt.party,
            partyId: receipt.partyId,
            currency: receipt.currency,
            itemId: receipt.itemId,
            itemName: receipt.itemName,
            unit: receipt.unit,
            quantity: receipt.quantity,
            unitPriceMinor: receipt.unitPriceMinor,
            totalMinor: receipt.totalMinor,
            paidMinor: receipt.paidMinor,
            reversalOf: id,
            reason: reason,
            requestId: RecordId.create());
        _purchases.add(reversal);
        for (final line in receipt.lines) {
          _transactions.add(MaterialTransaction(
              materialId: line.itemId,
              documentId: reversal.id,
              materialName: line.itemName,
              quantity: line.baseQuantity,
              type: 'OUT',
              date: reversal.date));
        }
      });
}
