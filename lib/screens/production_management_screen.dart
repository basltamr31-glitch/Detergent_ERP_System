import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/production_provider.dart';
import '../models/raw_material.dart';
import '../widgets/custom_numeric_widgets.dart';
import '../providers/packaging_provider.dart';
import '../l10n/app_localizations.dart';

class ProductionManagementScreen extends StatelessWidget {
  const ProductionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductionProvider>(context);
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(
                localizations.productionHeader, localizations, context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildMainCard(context, provider, localizations),
                    const SizedBox(height: 16),
                    _buildBatchCosts(context, provider),
                    const SizedBox(height: 15),
                    _buildMaterialsList(context, provider, localizations),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
          String title, AppLocalizations loc, BuildContext context) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(color: Colors.blue),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: loc.backToMainMenuBtn,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo')),
          ],
        ),
      );

  Widget _buildMainCard(BuildContext context, ProductionProvider provider,
          AppLocalizations loc) =>
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('costing-product-name'),
                initialValue: provider.productName,
                onChanged: provider.setProductName,
                decoration: InputDecoration(
                    labelText: loc.productNameLabel,
                    border: const OutlineInputBorder()),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                      child: CustomNumericField(
                          label: loc.producedQuantityLabel,
                          initialValue: provider.producedQuantity,
                          onChanged: provider.setProducedQuantity)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: CustomNumericField(
                          label: loc.exchangeRateLabel,
                          initialValue: provider.exchangeRate,
                          onChanged: (v) {
                            provider.setExchangeRate(v);
                            context
                                .read<PackagingProvider>()
                                .syncPricesWithExchangeRate(v);
                          })),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildBatchCosts(BuildContext context, ProductionProvider provider) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String ar) => arabic ? ar : en;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Batch labor & overhead', 'عمالة ومصاريف الدفعة'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(t(
                    'Enter total estimates for this batch, not per bottle. They contribute to the cost estimate without posting a financial journal.',
                    'أدخل تقديرات إجمالية لهذه الدفعة، وليس لكل عبوة. تدخل في تقدير التكلفة دون تسجيل قيد مالي.')),
                const SizedBox(height: 12),
                CustomNumericField(
                    key: const ValueKey('batch-labor'),
                    label: t('Batch labor (USD)', 'عمالة الدفعة (USD)'),
                    initialValue: provider.laborUSD,
                    onChanged: provider.setLaborUSD),
                const SizedBox(height: 12),
                CustomNumericField(
                    key: const ValueKey('batch-overhead'),
                    label: t('Batch overhead (USD)', 'مصاريف الدفعة (USD)'),
                    initialValue: provider.overheadUSD,
                    onChanged: provider.setOverheadUSD),
              ],
            )));
  }

  Widget _buildMaterialsList(BuildContext context, ProductionProvider provider,
          AppLocalizations loc) =>
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.rawMaterialsTitle,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                    Text(loc.rawMaterialsHelper,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                            fontFamily: 'Cairo')),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: provider.addRawMaterial,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(loc.addMaterial,
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...provider.rawMaterials
              .asMap()
              .entries
              .map((e) => _buildMaterialRow(provider, e.key, e.value, loc)),
        ],
      );

  Widget _buildMaterialRow(ProductionProvider p, int index, RawMaterial m,
          AppLocalizations loc) =>
      Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          onChanged: (v) =>
                              p.updateRawMaterial(index, m.copyWith(name: v)),
                          decoration:
                              InputDecoration(hintText: loc.materialName))),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => p.removeRawMaterial(index)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: CustomNumericField(
                          label: loc.weightLabel,
                          initialValue: m.quantity,
                          onChanged: (v) => p.updateRawMaterial(
                              index, m.copyWith(quantity: v)))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: CustomNumericField(
                          label: loc.priceUSDLabel,
                          initialValue: m.priceUSD,
                          onChanged: (v) => p.updateRawMaterial(
                              index,
                              m.copyWith(
                                  priceUSD: v,
                                  priceSYP: p.exchangeRate > 0
                                      ? v * p.exchangeRate
                                      : 0)))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: CustomNumericField(
                          label: loc.priceSYPLabel,
                          enabled: p.exchangeRate > 0,
                          initialValue: m.priceSYP,
                          onChanged: (v) => p.updateRawMaterial(
                              index,
                              m.copyWith(
                                  priceSYP: v,
                                  priceUSD: p.exchangeRate > 0
                                      ? v / p.exchangeRate
                                      : 0)))),
                  Tooltip(
                    message: loc.coreMaterialTooltip,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.blue),
                        Checkbox(
                            value: m.isActive,
                            onChanged: (v) => p.updateRawMaterial(
                                index, m.copyWith(isActive: v))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
