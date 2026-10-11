import 'access_control.dart';
import 'dart:convert';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import 'accounting.dart';
import 'record_id.dart';
import 'state_schema.dart';
import 'stock_validation.dart';
import 'transfer_service.dart';

class FinanceService {
  static Future<void> setPeriod(WarehouseProvider warehouse, ShopProvider shop,
      String? through, String reason) async {
    AccessControl.require(through == null ? 'admin' : 'finance');
    reason = StockValidation.name(reason);
    if (through != null &&
        (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(through) ||
            DateTime.parse(through).toIso8601String().substring(0, 10) !=
                through ||
            through.compareTo(Accounting.today()) > 0)) {
      throw ArgumentError('Use a valid date through today.');
    }
    final wh = StateSchema.object(jsonDecode(warehouse.exportState()));
    final sh = StateSchema.object(jsonDecode(shop.exportState()));
    final event = {
      'id': RecordId.create(),
      'date': DateTime.now().toUtc().toIso8601String(),
      'actor': AccessControl.actor,
      'kind': through == null ? 'reopen' : 'close',
      'through': through,
      'reason': reason
    };
    for (final data in [wh, sh]) {
      data['closedThrough'] = through;
      data['periodEvents'].add(event);
    }
    await TransferService.commitStates(warehouse, shop, wh, sh);
  }
}
