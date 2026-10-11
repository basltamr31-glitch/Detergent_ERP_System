import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

abstract class PersistedDraft extends ChangeNotifier {
  PersistedDraft(this.storage, this.storageKey);
  final Box<String>? storage;
  final String storageKey;
  Future<void> _pending = Future.value();
  String? saveError;
  String? loadError;
  bool _disposed = false;
  Map<String, dynamic> toDraft();
  void loadDraft(Map<String, dynamic> data);

  void initializeDraft() {
    try {
      final saved = storage?.get(storageKey);
      if (saved != null) loadDraft(jsonDecode(saved) as Map<String, dynamic>);
      loadError = null;
    } catch (e) {
      loadError = e.toString();
    }
  }

  void draftChanged() {
    if (loadError != null) {
      throw StateError('Draft could not be loaded. Restore a valid backup.');
    }
    final value = jsonEncode(toDraft());
    if (storage != null) {
      _pending = _pending.then((_) async {
        try {
          await storage!.put(storageKey, value);
          await storage!.flush();
          saveError = null;
        } catch (e) {
          saveError = e.toString();
        }
        if (!_disposed) notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> flushDraft() async {
    if (loadError != null) throw StateError('Draft could not be loaded.');
    await _pending;
    if (storage != null) {
      await storage!.put(storageKey, jsonEncode(toDraft()));
      await storage!.flush();
      saveError = null;
    }
  }

  Future<void> waitForSaves() => _pending;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
