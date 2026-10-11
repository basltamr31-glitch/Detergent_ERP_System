import 'dart:math';

class RecordId {
  static final _random = Random.secure();
  static String create() => List.generate(16, (_) => _random.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
