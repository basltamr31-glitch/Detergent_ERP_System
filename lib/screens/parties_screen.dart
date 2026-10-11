import '../services/money.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_party.dart';
import '../providers/shop_provider.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/storage_status.dart';

class PartiesScreen extends StatelessWidget {
  const PartiesScreen({super.key, this.initialTab = 0});
  final int initialTab;
  String t(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  Future<void> _edit(
      BuildContext context, bool supplier, BusinessParty? party) async {
    String name = party?.name ?? '',
        phone = party?.phone ?? '',
        address = party?.address ?? '';
    bool active = party?.active ?? true, saving = false;
    String? error;
    final form = GlobalKey<FormState>();
    final shop = context.read<ShopProvider>();
    final warehouse = context.read<WarehouseProvider>();
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(t(
                        context,
                        party == null ? 'New record' : 'Edit record',
                        party == null ? 'سجل جديد' : 'تعديل السجل')),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Form(
                                key: form,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                          initialValue: name,
                                          enabled: !saving,
                                          onChanged: (v) => name = v,
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? t(
                                                      context,
                                                      'Name is required',
                                                      'الاسم مطلوب')
                                                  : null,
                                          decoration: InputDecoration(
                                              labelText:
                                                  t(context, 'Name', 'الاسم'))),
                                      TextFormField(
                                          initialValue: phone,
                                          enabled: !saving,
                                          onChanged: (v) => phone = v,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                              labelText: t(
                                                  context, 'Phone', 'الهاتف'))),
                                      TextFormField(
                                          initialValue: address,
                                          enabled: !saving,
                                          onChanged: (v) => address = v,
                                          maxLines: 2,
                                          decoration: InputDecoration(
                                              labelText: t(context, 'Address',
                                                  'العنوان'))),
                                      SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title:
                                              Text(t(context, 'Active', 'نشط')),
                                          value: active,
                                          onChanged: saving
                                              ? null
                                              : (v) =>
                                                  update(() => active = v)),
                                      if (error != null) Text(error!),
                                      if (saving)
                                        const LinearProgressIndicator()
                                    ])))),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t(context, 'Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    if (supplier) {
                                      await warehouse.saveParty(
                                          id: party?.id,
                                          name: name,
                                          phone: phone,
                                          address: address,
                                          active: active);
                                    } else {
                                      await shop.saveParty(
                                          id: party?.id,
                                          name: name,
                                          phone: phone,
                                          address: address,
                                          active: active);
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: Text(t(context, 'Save record', 'حفظ السجل')))
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final warehouse = context.watch<WarehouseProvider>();
    return DefaultTabController(
        length: 2,
        initialIndex: initialTab,
        child: Scaffold(
            appBar: AppBar(
                title: Text(
                    t(context, 'Customers & suppliers', 'العملاء والموردون')),
                bottom: TabBar(tabs: [
                  Tab(text: t(context, 'Customers', 'العملاء')),
                  Tab(text: t(context, 'Suppliers', 'الموردون'))
                ])),
            body: !shop.isLoaded
                ? StorageStatus(error: shop.loadError, onRetry: shop.initialize)
                : !warehouse.isLoaded
                    ? StorageStatus(
                        error: warehouse.loadError,
                        onRetry: warehouse.initialize)
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: TabBarView(children: [
                              _list(
                                  context, shop.parties, false, shop.isSaving),
                              _list(context, warehouse.parties, true,
                                  warehouse.isSaving)
                            ])))));
  }

  Widget _list(BuildContext context, List<BusinessParty> parties, bool supplier,
          bool busy) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton.icon(
            onPressed: busy ? null : () => _edit(context, supplier, null),
            icon: const Icon(Icons.person_add_alt),
            label: Text(t(context, 'New record', 'سجل جديد'))),
        const SizedBox(height: 16),
        if (parties.isEmpty)
          Text(t(context, 'No records yet', 'لا توجد سجلات بعد')),
        ...parties.map((party) => Card(
            child: ListTile(
                title: Text(party.name),
                subtitle: Text([
                  if (party.phone.isNotEmpty) party.phone,
                  if (party.address.isNotEmpty) party.address,
                  if (!party.active) t(context, 'Inactive', 'غير نشط'),
                  ...(supplier
                          ? context
                              .read<WarehouseProvider>()
                              .outstandingForParty(party.id)
                          : context
                              .read<ShopProvider>()
                              .outstandingForParty(party.id))
                      .entries
                      .map((e) =>
                          '${t(context, 'Outstanding', 'المتبقي')}: ${Money.format(e.value)} ${e.key}')
                ].join('\n')),
                isThreeLine: false,
                trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: t(context, 'Edit record', 'تعديل السجل'),
                    onPressed:
                        busy ? null : () => _edit(context, supplier, party)))))
      ]);
}
