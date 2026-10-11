import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/production_provider.dart';
import '../providers/packaging_provider.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _path = TextEditingController();
  final _paste = TextEditingController();
  bool _busy = false;
  bool _recoveryRequired = false;
  String? _message;
  String? _export;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String ar) => _ar ? ar : en;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _capture() async {
    final warehouse = context.read<WarehouseProvider>();
    final shop = context.read<ShopProvider>();
    final production = context.read<ProductionProvider>();
    final packaging = context.read<PackagingProvider>();
    await warehouse.ready;
    await shop.ready;
    await production.flushDraft();
    await packaging.flushDraft();
    return {
      'warehouse': jsonDecode(warehouse.exportState()),
      'shop': jsonDecode(shop.exportState()),
      'production': production.toDraft(),
      'packaging': packaging.toDraft()
    };
  }

  Future<String> _automaticPath(String prefix) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory =
        Directory('${documents.path}${Platform.pathSeparator}ERP Backups');
    await directory.create(recursive: true);
    return '${directory.path}${Platform.pathSeparator}$prefix-${DateTime.now().microsecondsSinceEpoch}.json';
  }

  Future<void> _backup() => _run(() async {
        final payload = await _capture();
        final path = _path.text.trim().isEmpty
            ? await _automaticPath('backup')
            : _path.text.trim();
        await BackupService.write(path, payload);
        if (mounted) {
          setState(() {
            _export = BackupService.encode(payload);
            _message = t('Backup verified and saved: ',
                    'تم التحقق من النسخة وحفظها: ') +
                path;
          });
        }
      });

  Future<void> _restore() => _run(() async {
        final warehouse = context.read<WarehouseProvider>();
        final shop = context.read<ShopProvider>();
        final production = context.read<ProductionProvider>();
        final packaging = context.read<PackagingProvider>();
        final payload = _paste.text.trim().isNotEmpty
            ? BackupService.decode(_paste.text.trim())
            : await BackupService.read(_path.text.trim());
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: Text(
                        t('Restore backup?', 'استعادة النسخة الاحتياطية؟')),
                    content: Text(t(
                        'This replaces current inventory and costing drafts. A verified safety backup will be saved first.',
                        'سيتم استبدال المخزون ومسودات التكلفة الحالية. ستُحفظ نسخة أمان أولاً.')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(t('Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(t('Restore', 'استعادة')))
                    ]));
        if (confirmed != true) return;
        final safety = await _automaticPath('before-restore');
        await warehouse.ready;
        await shop.ready;
        if (warehouse.isSaving || shop.isSaving) {
          throw StateError('Inventory is busy.');
        }
        await production.waitForSaves();
        await packaging.waitForSaves();
        if (warehouse.isLoaded &&
            shop.isLoaded &&
            production.loadError == null &&
            packaging.loadError == null) {
          await BackupService.write(safety, await _capture());
        } else {
          await BackupService.preserveRaw(safety);
        }
        _recoveryRequired = true;
        await BackupService.restore(payload);
        await warehouse.reloadState();
        await shop.reloadState();
        production.loadDraft(Map<String, dynamic>.from(payload['production']));
        packaging.loadDraft(Map<String, dynamic>.from(payload['packaging']));
        _recoveryRequired = false;
        if (mounted) {
          setState(() => _message = t('Restore complete. Safety backup: ',
                  'اكتملت الاستعادة. نسخة الأمان: ') +
              safety);
        }
      });

  Future<void> _finishRestore() => _run(() async {
        final warehouse = context.read<WarehouseProvider>();
        final shop = context.read<ShopProvider>();
        final production = context.read<ProductionProvider>();
        final packaging = context.read<PackagingProvider>();
        await BackupService.recover();
        await warehouse.reloadState();
        await shop.reloadState();
        final drafts = Hive.box<String>('costing_drafts_v1');
        production.loadDraft(
            Map<String, dynamic>.from(jsonDecode(drafts.get('production')!)));
        packaging.loadDraft(
            Map<String, dynamic>.from(jsonDecode(drafts.get('packaging')!)));
        if (mounted) {
          setState(() {
            _recoveryRequired = false;
            _message = t('Restore complete.', 'اكتملت الاستعادة.');
          });
        }
      });

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy && !_recoveryRequired,
      child: Scaffold(
        appBar: AppBar(
            title: Text(t('Backup & restore', 'النسخ الاحتياطي والاستعادة')),
            automaticallyImplyLeading: !_busy && !_recoveryRequired),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text(t(
                      'Back up warehouse, shop stock and costing drafts. Keep a copy outside this device.',
                      'انسخ المخزون والمتجر ومسودات التكلفة. احتفظ بنسخة خارج هذا الجهاز.')),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _path,
                      enabled: !_busy,
                      decoration: InputDecoration(
                          labelText: t(
                              'Backup file path (optional when saving)',
                              'مسار ملف النسخة (اختياري للحفظ)'))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _busy || _recoveryRequired ? null : _backup,
                      icon: const Icon(Icons.backup_outlined),
                      label: Text(t('Create verified backup',
                          'إنشاء نسخة والتحقق منها'))),
                  const SizedBox(height: 12),
                  if (_export != null)
                    OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: _export!));
                                if (mounted) {
                                  setState(() => _message = t(
                                      'Backup text copied. Save it on another device.',
                                      'تم نسخ نص النسخة. احفظه على جهاز آخر.'));
                                }
                              },
                        icon: const Icon(Icons.copy),
                        label: Text(
                            t('Copy backup text', 'نسخ نص النسخة الاحتياطية'))),
                  const Divider(height: 36),
                  TextField(
                      controller: _paste,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                          labelText: t(
                              'Paste backup text, or use a file path above',
                              'الصق نص النسخة أو أدخل مسار الملف أعلاه'))),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: _busy || _recoveryRequired ? null : _restore,
                      icon: const Icon(Icons.restore),
                      label:
                          Text(t('Validate and restore', 'التحقق والاستعادة'))),
                  if (_busy)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: LinearProgressIndicator()),
                  if (_recoveryRequired && !_busy)
                    FilledButton(
                      onPressed: _finishRestore,
                      child: Text(t('Retry interrupted restore',
                          'إكمال الاستعادة المتوقفة')),
                    ),
                  if (_message != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: SelectableText(_message!)),
                ]))),
      ));
  @override
  void dispose() {
    _path.dispose();
    _paste.dispose();
    super.dispose();
  }
}
