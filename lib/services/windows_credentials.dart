import 'package:flutter/services.dart';

class WindowsCredentials {
  static const channel = MethodChannel('erp/windows_credentials');
  static Future<Map<String, String>?> prompt({required bool setup}) async {
    final value = await channel
        .invokeMapMethod<String, String>('prompt', {'setup': setup});
    return value;
  }
}
