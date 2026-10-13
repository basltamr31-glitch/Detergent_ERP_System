import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../providers/shop_provider.dart';
import '../services/access_control.dart';
import '../services/auth_service.dart';
import '../services/finance_summary.dart';
import '../services/inventory_coordinator.dart';
import '../services/money.dart';
import '../models/trade_document.dart';
import '../widgets/storage_status.dart';
import 'auth_screen.dart';
import 'app_shell.dart';
import 'warehouse_screen.dart';
import 'shop_screen.dart';
import 'language_selection_screen.dart';
import 'backup_screen.dart';
import 'business_documents_screen.dart';
import 'parties_screen.dart';
import 'transfers_screen.dart';
import 'finance_screen.dart';
import 'operations_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  String _currency = 'USD';
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  void open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  Widget surface({required Widget child}) => Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xffdfe5ee)),
        ),
        child: child,
      );
  Widget heading(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
  Widget metric(String label, String value, IconData icon, Color color,
          {String? detail}) =>
      surface(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(label))
              ]),
              const SizedBox(height: 12),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (detail != null)
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ])),
      );
  Widget module(String id, String title, String subtitle, IconData icon,
          Color color, Widget page) =>
      surface(
        child: InkWell(
          key: ValueKey('module-$id'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => open(page),
          child: Padding(
              padding: const EdgeInsets.all(18),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 18),
              ])),
        ),
      );
  Widget tiles(List<Widget> children, {int desktopColumns = 3}) =>
      LayoutBuilder(builder: (_, size) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 21;
        final columns = size.maxWidth >= 1000 && !largeText
            ? desktopColumns
            : size.maxWidth >= 600
                ? 2
                : 1;
        final width = (size.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final child in children) SizedBox(width: width, child: child)
        ]);
      });
  @override
  Widget build(BuildContext context) {
    final wh = context.watch<WarehouseProvider>(),
        shop = context.watch<ShopProvider>();
    final ready = wh.isLoaded && shop.isLoaded && !InventoryCoordinator.busy;
    final sales = shop.sales
        .where((d) =>
            d.reversalOf == null &&
            !shop.isSaleReversed(d.id) &&
            d.currency == _currency)
        .toList();
    final purchases = wh.purchases
        .where((d) =>
            d.reversalOf == null &&
            !wh.isPurchaseReversed(d.id) &&
            d.currency == _currency)
        .toList();
    final receivables =
        sales.fold<int>(0, (sum, d) => sum + d.totalMinor - shop.paidFor(d));
    final payables =
        purchases.fold<int>(0, (sum, d) => sum + d.totalMinor - wh.paidFor(d));
    final summary = FinanceSummary(
        [...wh.journals, ...shop.journals], _currency,
        documentReceivables: receivables, documentPayables: payables);
    final recent = <TradeDocument>[...wh.purchases, ...shop.sales]
      ..sort((a, b) => b.date.compareTo(a.date));
    final pending = wh.orders.where((o) => o['status'] == 'draft').length;
    final quality = wh.orders.where((o) => o['status'] == 'approved').length;
    final name = AccessControl.user?['name'];
    return Scaffold(
      backgroundColor: const Color(0xfff4f6fa),
      appBar: AppBar(
          title: Text(t('Factory workspace', 'مساحة عمل المصنع')),
          actions: [
            IconButton(
                tooltip: t('Language', 'اللغة'),
                icon: const Icon(Icons.language),
                onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LanguageSelectionScreen()),
                    (_) => false)),
            if (AccessControl.enabled)
              IconButton(
                  tooltip: t('Sign out', 'تسجيل الخروج'),
                  icon: const Icon(Icons.logout),
                  onPressed: () => context.read<AuthService>().logout()),
          ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  heading(
                      name == null
                          ? t('Your factory at a glance', 'نظرة على مصنعك')
                          : t('Welcome, $name', 'مرحباً، $name'),
                      t('Stock, production and finance in one workspace.',
                          'المخزون والإنتاج والمالية في مساحة عمل واحدة.')),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            key: const ValueKey('dashboard-currency'),
                            initialValue: _currency,
                            decoration: InputDecoration(
                                labelText:
                                    t('Overview currency', 'عملة الملخص')),
                            items: Money.currencies
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _currency = value!),
                          ))),
                  const SizedBox(height: 16),
                  if (!wh.isLoaded)
                    StorageStatus(error: wh.loadError, onRetry: wh.initialize)
                  else if (!shop.isLoaded)
                    StorageStatus(
                        error: shop.loadError, onRetry: shop.initialize)
                  else if (!ready)
                    const LinearProgressIndicator()
                  else ...[
                    tiles([
                      metric(
                          t('Posted sales', 'المبيعات المسجلة'),
                          '${Money.format(sales.fold<int>(0, (sum, d) => sum + d.totalMinor))} $_currency',
                          Icons.receipt_long_outlined,
                          Colors.green,
                          detail: t('Active documents · all dates',
                              'مستندات سارية · جميع التواريخ')),
                      metric(
                          t('Customer balances', 'أرصدة العملاء'),
                          '${Money.format(receivables)} $_currency',
                          Icons.account_balance_wallet_outlined,
                          Colors.blue),
                      metric(
                          t('Supplier balances', 'أرصدة الموردين'),
                          '${Money.format(payables)} $_currency',
                          Icons.payments_outlined,
                          Colors.orange),
                      metric(
                          t('Ledger cash', 'النقد في الدفتر'),
                          '${Money.format(summary.cash)} $_currency',
                          Icons.account_balance_outlined,
                          Colors.indigo,
                          detail: t('Includes recorded opening balances',
                              'يشمل الأرصدة الافتتاحية المسجلة')),
                    ], desktopColumns: 4),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 8, children: [
                      ActionChip(
                          avatar: const Icon(Icons.pending_actions_outlined),
                          label: Text(t('$pending orders awaiting approval',
                              '$pending أوامر بانتظار الاعتماد')),
                          onPressed: () => open(const OperationsScreen())),
                      ActionChip(
                          avatar: const Icon(Icons.fact_check_outlined),
                          label: Text(t(
                              '$quality orders awaiting quality release',
                              '$quality أوامر بانتظار الإفراج النوعي')),
                          onPressed: () => open(const OperationsScreen())),
                      Chip(
                          avatar: Icon(summary.reconciled
                              ? Icons.check_circle_outline
                              : Icons.info_outline),
                          label: Text(summary.reconciled
                              ? t('Document balances agree with ledger',
                                  'أرصدة المستندات مطابقة للدفتر')
                              : t('Finance reconciliation needs review',
                                  'مطابقة المالية تحتاج مراجعة'))),
                      if (wh.closedThrough != null)
                        Chip(
                            avatar: const Icon(Icons.lock_outline),
                            label: Text(t(
                                'Period closed through ${wh.closedThrough}',
                                'الفترة مغلقة حتى ${wh.closedThrough}'))),
                    ]),
                  ],
                  heading(
                      t('Daily operations', 'العمليات اليومية'),
                      t('Receive materials, manufacture and sell.',
                          'استلام المواد والتصنيع والبيع.')),
                  tiles([
                    module(
                        'warehouse',
                        t('Warehouse', 'المستودع'),
                        t('Raw stock and supplier receipts',
                            'المواد الخام واستلام المشتريات'),
                        Icons.warehouse_outlined,
                        Colors.orange,
                        const WarehouseScreen()),
                    module(
                        'operations',
                        t('Production & stock counts', 'الإنتاج والجرد'),
                        t('Recipes, approvals and quality release',
                            'الوصفات والاعتماد والإفراج النوعي'),
                        Icons.assignment_outlined,
                        Colors.deepPurple,
                        const OperationsScreen()),
                    module(
                        'transfers',
                        t('Finished-goods transfers', 'نقل المنتجات الجاهزة'),
                        t('Move approved output into sale units',
                            'نقل الإنتاج المعتمد إلى وحدات البيع'),
                        Icons.swap_horiz_outlined,
                        Colors.teal,
                        const TransfersScreen()),
                    module(
                        'sales',
                        t('Sales shop', 'المبيعات'),
                        t('Sell products and track customers',
                            'بيع المنتجات ومتابعة العملاء'),
                        Icons.storefront_outlined,
                        Colors.green,
                        const ShopScreen()),
                    module(
                        'partners',
                        t('Customers & suppliers', 'العملاء والموردون'),
                        t('Contacts and outstanding balances',
                            'جهات الاتصال والأرصدة المستحقة'),
                        Icons.people_outline,
                        Colors.blueGrey,
                        const PartiesScreen()),
                    module(
                        'costing',
                        t('Production costing', 'حساب تكلفة الإنتاج'),
                        t('Ingredients, fill units and packaging',
                            'المكونات ووحدات التعبئة والتغليف'),
                        Icons.calculate_outlined,
                        Colors.blue,
                        const AppShell()),
                  ]),
                  heading(
                      t('Reports & controls', 'التقارير والرقابة'),
                      t('Review records and protect your business data.',
                          'مراجعة السجلات وحماية بيانات العمل.')),
                  tiles([
                    module(
                        'documents',
                        t('Business documents', 'المستندات التجارية'),
                        t('Search, payments, returns and PDFs',
                            'البحث والدفعات والمرتجعات والتقارير'),
                        Icons.description_outlined,
                        Colors.blueGrey,
                        const BusinessDocumentsScreen()),
                    module(
                        'finance',
                        t('Finance', 'المالية'),
                        t('Journals, reconciliation and period locks',
                            'القيود والمطابقة وإغلاق الفترات'),
                        Icons.account_balance_outlined,
                        Colors.indigo,
                        const FinanceScreen()),
                    if (AccessControl.allows('backup'))
                      module(
                          'backup',
                          t('Backup & restore', 'النسخ الاحتياطي والاستعادة'),
                          t('Export and recover business data',
                              'تصدير بيانات العمل واستعادتها'),
                          Icons.backup_outlined,
                          Colors.teal,
                          const BackupScreen()),
                    if (AccessControl.enabled && AccessControl.allows('admin'))
                      module(
                          'users',
                          t('Users & roles', 'المستخدمون والصلاحيات'),
                          t('Manage local account access',
                              'إدارة صلاحيات الحسابات المحلية'),
                          Icons.manage_accounts_outlined,
                          Colors.deepPurple,
                          const UsersScreen()),
                  ]),
                  if (ready) ...[
                    heading(
                        t('Recent documents', 'المستندات الأخيرة'),
                        t('Most recent purchases and sales across currencies.',
                            'آخر المشتريات والمبيعات بجميع العملات.')),
                    if (recent.isEmpty)
                      surface(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(children: [
                                const Icon(Icons.description_outlined,
                                    size: 40, color: Colors.blueGrey),
                                const SizedBox(height: 12),
                                Text(
                                    t('Your first business document starts here',
                                        'ابدأ بمستند العمل الأول'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(t(
                                    'Receive a purchase in Warehouse, then review it in Business documents.',
                                    'سجل استلام مشتريات في المستودع ثم راجعه في المستندات التجارية.')),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                    onPressed: () =>
                                        open(const WarehouseScreen()),
                                    child: Text(
                                        t('Open warehouse', 'فتح المستودع'))),
                              ])))
                    else
                      for (final doc in recent.take(5))
                        surface(
                            child: ListTile(
                          onTap: () => open(BusinessDocumentsScreen(
                              initialTab:
                                  doc.type.startsWith('purchase') ? 1 : 2)),
                          leading: Icon(doc.type.startsWith('purchase')
                              ? Icons.inventory_2_outlined
                              : Icons.receipt_long_outlined),
                          title: Text('${doc.number} · ${doc.party}'),
                          subtitle: Text(
                              '${Money.format(doc.totalMinor)} ${doc.currency} · ${doc.date.toLocal().toString().split(' ').first}${doc.reversalOf != null ? t(' · Return', ' · مرتجع') : ''}'),
                          trailing: const Icon(Icons.chevron_right),
                        )),
                  ],
                ],
              ))),
    );
  }
}
