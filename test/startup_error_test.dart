import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:detergent_factory/services/startup_error.dart';

void main() {
  test('Windows sharing and lock violations get actionable startup guidance',
      () {
    expect(
        isDatabaseLocked(const FileSystemException(
            'lock failed', 'db.lock', OSError('locked', 33))),
        isTrue);
    expect(
        isDatabaseLocked(const FileSystemException(
            'sharing violation', 'db.lock', OSError('shared', 32))),
        isTrue);
    expect(
        isDatabaseLocked(const FileSystemException(
            'access denied', 'db', OSError('denied', 5))),
        isFalse);
    expect(isDatabaseLocked(StateError('bad data')), isFalse);
  });
}
