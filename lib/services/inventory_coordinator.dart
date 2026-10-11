/// Gates all writes during a transaction spanning the warehouse and shop.
class InventoryCoordinator {
  static bool busy = false;
  static void check() {
    if (busy) {
      throw StateError(
          'Complete the pending stock transfer before another operation.');
    }
  }
}
