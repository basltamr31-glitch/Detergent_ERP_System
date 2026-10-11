import 'dart:io';

bool isDatabaseLocked(Object error) =>
    error is FileSystemException &&
    (error.osError?.errorCode == 33 || error.osError?.errorCode == 32);
