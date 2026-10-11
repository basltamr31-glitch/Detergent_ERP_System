class Money {
  static const currencies = ['USD', 'SYP'];
  static const maxMinor = 9000000000000000;
  static String normalize(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var normalized = value.trim().replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      normalized = normalized.replaceAll(arabic[i], '$i');
    }
    return normalized;
  }

  static double quantity(String value) {
    final result = double.parse(normalize(value));
    total(result, 0);
    return result;
  }

  static int parse(String value) {
    final normalized = normalize(value);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) {
      throw ArgumentError(
          'Enter a nonnegative amount with at most two decimal places.');
    }
    final parts = normalized.split('.');
    final amount = BigInt.parse(parts[0]) * BigInt.from(100) +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (amount > BigInt.from(maxMinor)) {
      throw ArgumentError('Amount is too large.');
    }
    return amount.toInt();
  }

  static int total(double quantity, int unitPriceMinor) {
    if (!quantity.isFinite ||
        quantity <= 0 ||
        quantity > 1000000000 ||
        unitPriceMinor < 0 ||
        unitPriceMinor > maxMinor) {
      throw ArgumentError('Invalid document quantity or price.');
    }
    final rounded = double.parse(quantity.toStringAsFixed(6));
    if ((quantity - rounded).abs() > 1e-12 || rounded <= 0) {
      throw ArgumentError('Quantity supports up to six decimal places.');
    }
    final micro = BigInt.parse(quantity.toStringAsFixed(6).replaceAll('.', ''));
    final result =
        (micro * BigInt.from(unitPriceMinor) + BigInt.from(500000)) ~/
            BigInt.from(1000000);
    if (result > BigInt.from(maxMinor)) {
      throw ArgumentError('Document total is too large.');
    }
    return result.toInt();
  }

  static String format(int minor) =>
      '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';
}
