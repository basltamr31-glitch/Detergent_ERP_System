import 'package:flutter/material.dart';

class StorageStatus extends StatelessWidget {
  const StorageStatus({super.key, required this.error, required this.onRetry});
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    if (error == null) return const Center(child: CircularProgressIndicator());
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 40),
        const SizedBox(height: 12),
        Text(arabic
            ? 'تعذر تحميل المخزون. أعد المحاولة.'
            : 'Unable to load inventory. Please retry.'),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: onRetry,
            child: Text(arabic ? 'إعادة المحاولة' : 'Retry')),
      ]),
    ));
  }
}
