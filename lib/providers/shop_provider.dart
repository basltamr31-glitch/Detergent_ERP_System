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
import '../models/product.dart';

class ShopProvider with ChangeNotifier {
  final List<Product> _products = [];
  final List<TradeDocument> _sales = [];
  double lotRemaining(String transferId) {
    final transfer = _transfers.firstWhere((t) => t.id == transferId);
    if (transfer.reversalOf != null ||
        _transfers.any((t) => t.reversalOf == transferId)) {
      return 0;
    }
    double used = 0;
    for (final sale
        in _sales.where((s) => s.reversalOf == null && !isSaleReversed(s.id))) {
      for (final line in sale.lines) {
        used += line.lots[transferId] ?? 0;
      }
    }
    for (final count in _counts) {
      used += count.lots[transferId] ?? 0;
    }
    return double.parse((transfer.quantity - used).toStringAsFixed(6));
  }

  Map<String, double> _allocateLots(String productId, double quantity,
      {bool includeExpired = false}) {
    final lots = <String, double>{};
    var remaining = quantity;
    for (final t in _transfers
        .where((t) => t.productId == productId && t.reversalOf == null)) {
      if (!includeExpired &&
          t.expiry.isNotEmpty &&
          t.expiry.compareTo(Accounting.today()) <= 0) {
        continue;
      }
      final available = lotRemaining(t.id);
      final take = remaining < available ? remaining : available;
      if (take > 0) {
        lots[t.id] = take;
        remaining = double.parse((remaining - take).toStringAsFixed(6));
      }
      if (remaining <= 0) break;
    }
    return lots;
  }

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
        final item = _products.firstWhere((i) => i.id == itemId);
        if (item.quantity == counted) {
          throw ArgumentError('Count is unchanged.');
        }
        final count = StockCount(
            itemId: itemId,
            before: item.quantity,
            after: counted,
            reason: reason,
            date: DateTime.now(),
            requestId: requestId,
            lots: counted < item.quantity
                ? _allocateLots(itemId, item.quantity - counted,
                    includeExpired: true)
                : const {});

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
      for (final d in old['sales'] as List) d['id'],
      for (final p in old['payments'] as List) p['id']
    };
    for (final d in _sales.where((d) => !sources.contains(d.id))) {
      final entry = JournalEntry.trade(d);
      Accounting.validate(entry);
      _journals.add(entry);
    }
    for (final p in _payments.where((p) => !sources.contains(p.id))) {
      final entry = JournalEntry.payment(
          p, _sales.firstWhere((d) => d.id == p.documentId));
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
    for (final doc in _sales.where((d) =>
        d.partyId == id && d.reversalOf == null && !isSaleReversed(d.id))) {
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
      _paymentsPost(() {
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
        final document = _sales.firstWhere((d) => d.id == documentId);
        if (requestId.trim().isEmpty ||
            document.reversalOf != null ||
            isSaleReversed(documentId)) {
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
      _paymentsPost(() {
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
        final document = _sales.firstWhere((d) => d.id == documentId);
        if (document.reversalOf != null || isSaleReversed(documentId)) {
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

  List<TradeDocument> get sales => List.unmodifiable(_sales);
  bool isSaleReversed(String id) => _sales.any((p) => p.reversalOf == id);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  bool _saving = false;
  bool get isSaving => _saving;
  String? loadError;
  late final Future<void> ready = initialize();
  Box<String>? _stateBox;
  bool _initializing = false;

  List<Product> get products => List.unmodifiable(_products.map((p) => Product(
      id: p.id,
      name: p.name,
      quantity: p.quantity,
      unit: p.unit,
      unitPrice: p.unitPrice)));

  ShopProvider() {
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
        'version': 12,
        'counts': _counts.map((c) => c.toJson()).toList(),
        'journals': _journals.map((j) => j.toJson()).toList(),
        'closedThrough': _closedThrough,
        'periodEvents': _periodEvents,
        'ledgerStartedAt':
            _ledgerStartedAt ?? DateTime.now().toUtc().toIso8601String(),
        'transfers': _transfers.map((t) => t.toJson()).toList(),
        'parties': _parties.map((p) => p.toJson()).toList(),
        'payments': _payments.map((p) => p.toJson()).toList(),
        'sales': _sales.map((s) => s.toJson()).toList(),
        'products': _products
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'quantity': p.quantity,
                  'unit': p.unit,
                  'price': p.unitPrice
                })
            .toList()
      });
  void _restore(String value) {
    final data = jsonDecode(value) as Map<String, dynamic>;
    StateSchema.inventory('shop', data);
    if (![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].contains(data['version'])) {
      throw StateError('Unsupported inventory version.');
    }
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
    _products
      ..clear()
      ..addAll((data['products'] as List).map((p) => Product(
          id: p['id'] as String?,
          name: p['name'],
          quantity: (p['quantity'] as num).toDouble(),
          unit: p['unit'],
          unitPrice: (p['price'] as num).toDouble())));
    _sales
      ..clear()
      ..addAll((data['sales'] as List? ?? [])
          .map((p) => TradeDocument.fromJson(Map<String, dynamic>.from(p))));
  }

  Future<void> initialize() async {
    if (_initializing || _isLoaded) return;
    _initializing = true;
    loadError = null;
    notifyListeners();
    try {
      _ledgerStartedAt ??= DateTime.now().toUtc().toIso8601String();
      _stateBox = await Hive.openBox<String>('shop_state_v1');
      final saved = _stateBox!.get('state');
      if (saved != null) {
        _restore(saved);
        StateSchema.inventory(
            'shop', jsonDecode(_snapshot()) as Map<String, dynamic>);
        await _stateBox!.put('state', _snapshot());
        await _stateBox!.flush();
      } else {
        _products.clear();
        final box = await Hive.openBox<Product>('shop_products');
        _products.addAll(box.values);

        StateSchema.inventory(
            'shop', jsonDecode(_snapshot()) as Map<String, dynamic>);
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
  Future<void> _paymentsPost(void Function() change) =>
      _post(change, permission: 'payments');
  Future<void> _post(void Function() change,
      {String permission = 'sales'}) async {
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
          'shop', jsonDecode(_snapshot()) as Map<String, dynamic>);
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

  double getStock(String name) => _products
      .where((p) => p.name == name)
      .fold(0.0, (sum, p) => sum + p.quantity);

  Future<void> addProduct(
          String name, double quantity, String unit, double unitPrice) =>
      _post(() {
        name = StockValidation.name(name);
        StockValidation.positive(quantity);
        StockValidation.price(unitPrice);
        if (unit.trim().isEmpty) throw ArgumentError('Unit is required.');
        final index = _products.indexWhere((p) => p.name == name);
        if (index < 0) {
          _products.add(Product(
              name: name,
              quantity: quantity,
              unit: unit,
              unitPrice: unitPrice));
        } else {
          final product = _products[index];
          if (product.unit != unit) {
            throw ArgumentError('Use the existing stock unit.');
          }
          StockValidation.positive(product.quantity + quantity);
          product.quantity += quantity;
          product.unitPrice = unitPrice;
        }
      }, permission: 'warehouse');

  Future<void> sellProduct(String name, double quantity,
      {String customer = 'Walk-in customer',
      String currency = 'USD',
      int? unitPriceMinor,
      int paidMinor = 0,
      String reference = '',
      String? partyId,
      String? requestId}) async {
    final product = _products.firstWhere((p) => p.name == name,
        orElse: () => throw StateError('Product not found.'));
    return sellProducts([
      TradeInput(
          name: name,
          quantity: quantity,
          unitPriceMinor: unitPriceMinor ??
              Money.parse(product.unitPrice.toStringAsFixed(2)))
    ],
        customer: customer,
        currency: currency,
        paidMinor: paidMinor,
        reference: reference,
        partyId: partyId,
        requestId: requestId);
  }

  Future<void> sellProducts(List<TradeInput> items,
          {required String customer,
          required String currency,
          int paidMinor = 0,
          String reference = '',
          String? partyId,
          String? requestId}) =>
      _post(() {
        final token = requestId ?? RecordId.create();
        customer = StockValidation.name(customer);
        if (partyId != null &&
            !_parties.any(
                (p) => p.id == partyId && p.active && p.name == customer)) {
          throw StateError('Select an active customer and its current name.');
        }
        if (!Money.currencies.contains(currency) || items.isEmpty) {
          throw ArgumentError('Select currency and items.');
        }
        final lines = items.map((input) {
          final product = _products.firstWhere(
              (p) => p.name == input.name.trim(),
              orElse: () => throw StateError('Product not found.'));
          return TradeLine(
              itemId: product.id,
              itemName: product.name,
              unit: product.unit,
              quantity: input.quantity,
              unitPriceMinor: input.unitPriceMinor);
        }).toList();
        if (lines.map((l) => l.itemId).toSet().length != lines.length) {
          throw ArgumentError('Combine duplicate items into one line.');
        }
        final total = lines.fold(0, (sum, l) => sum + l.totalMinor);
        if (total > Money.maxMinor || paidMinor < 0 || paidMinor > total) {
          throw ArgumentError('Invalid total or payment.');
        }
        final previous = _sales.where((d) => d.requestId == token);
        if (previous.isNotEmpty) {
          final d = previous.single;
          if (d.party != customer ||
              d.partyId != partyId ||
              d.currency != currency ||
              d.paidMinor != paidMinor ||
              d.reference != reference.trim() ||
              jsonEncode(d.lines
                      .map((l) => l.toJson()..remove('lots'))
                      .toList()) !=
                  jsonEncode(
                      lines.map((l) => l.toJson()..remove('lots')).toList())) {
            throw StateError(
                'This request was already posted with different details.');
          }
          return;
        }
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final product = _products.firstWhere((p) => p.id == line.itemId);
          final expired = _transfers
              .where((t) =>
                  t.productId == product.id &&
                  t.reversalOf == null &&
                  t.expiry.isNotEmpty &&
                  t.expiry.compareTo(Accounting.today()) <= 0)
              .fold(0.0, (sum, t) => sum + lotRemaining(t.id));
          if (product.quantity - expired + 0.0000001 < line.quantity) {
            throw StateError(
                'Insufficient unexpired stock for ${line.itemName}.');
          }
          lines[i] = TradeLine(
              itemId: line.itemId,
              itemName: line.itemName,
              unit: line.unit,
              quantity: line.quantity,
              unitPriceMinor: line.unitPriceMinor,
              lots: _allocateLots(product.id, line.quantity));
          product.quantity -= line.quantity;
        }
        final first = lines.first;
        _sales.add(TradeDocument(
            number: 'SAL-${(_sales.length + 1).toString().padLeft(6, '0')}',
            type: 'sale',
            date: DateTime.now(),
            party: customer,
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
  Future<void> reverseSale(String id, String reason) => _post(() {
        reason = StockValidation.name(reason);
        final sale = _sales.firstWhere((s) => s.id == id,
            orElse: () => throw StateError('Sale not found.'));
        if (paidFor(sale) != 0) {
          throw StateError(
              'Record the actual refund of all payments before returning goods.');
        }
        if (sale.reversalOf != null || isSaleReversed(id)) {
          throw StateError('Sale has already been reversed.');
        }
        for (final line in sale.lines) {
          final product = _products.firstWhere((p) => p.id == line.itemId);
          StockValidation.positive(product.quantity + line.quantity);
          product.quantity += line.quantity;
        }
        _sales.add(TradeDocument(
            number: 'SAL-${(_sales.length + 1).toString().padLeft(6, '0')}',
            type: 'saleReturn',
            date: DateTime.now(),
            lines: sale.lines,
            party: sale.party,
            partyId: sale.partyId,
            currency: sale.currency,
            itemId: sale.itemId,
            itemName: sale.itemName,
            unit: sale.unit,
            quantity: sale.quantity,
            unitPriceMinor: sale.unitPriceMinor,
            totalMinor: sale.totalMinor,
            paidMinor: sale.paidMinor,
            reversalOf: id,
            reason: reason,
            requestId: RecordId.create()));
      });
  Future<void> resetSales() => Future.error(StateError(
      'Sales history cannot be reset. Use reversals or restore a backup.'));
}
