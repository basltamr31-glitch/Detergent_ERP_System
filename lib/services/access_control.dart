class AccessControl {
  // Production enables enforcement before constructing the application.
  // Domain tests that do not exercise authentication use the standalone mode.
  static bool enabled = false;
  static Map<String, String>? user;
  static const permissions = {
    'warehouse': ['owner', 'manager', 'warehouse'],
    'sales': ['owner', 'manager', 'cashier'],
    'finance': ['owner', 'manager', 'accountant'],
    'payments': ['owner', 'manager', 'accountant', 'cashier'],
    'partners': ['owner', 'manager', 'accountant', 'warehouse', 'cashier'],
    'backup': ['owner', 'manager', 'accountant'],
    'approve': ['owner', 'manager'],
    'admin': ['owner']
  };
  static bool allows(String permission) =>
      !enabled ||
      (user != null && (permissions[permission] ?? []).contains(user!['role']));
  static void require(String permission) {
    if (!allows(permission)) {
      throw StateError('Your role does not permit this action.');
    }
  }

  static Map<String, String> get actor => Map.unmodifiable(user ??
      {'id': 'legacy', 'name': 'Legacy / standalone', 'role': 'legacy'});
}
