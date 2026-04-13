import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/packaging_provider.dart';
import '../models/packaging_item.dart';
import '../widgets/custom_numeric_widgets.dart';
import '../providers/production_provider.dart';
import '../l10n/app_localizations.dart';

class PackagingFillingScreen extends StatelessWidget {
  const PackagingFillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PackagingProvider>();
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(localizations.packagingHeader),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildPackagingSection(context, provider, localizations),
                    const SizedBox(height: 20),
                    if (provider.packagingItems.any((item) => item.hasCarton))
                      _buildCartonSection(context, provider, localizations),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String t) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: const BoxDecoration(color: Colors.blue),
    child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
  );

  Widget _buildPackagingSection(BuildContext context, PackagingProvider p, AppLocalizations loc) {
    final exchangeRate = context.read<ProductionProvider>().exchangeRate;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(loc.packagingTypesTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 30), onPressed: p.addPackagingItem),
          ],
        ),
        ...p.packagingItems.asMap().entries.map((e) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: CustomNumericField(label: loc.sizeLabel, initialValue: e.value.size, onChanged: (v) => p.updatePackagingItem(e.key, e.value.copyWith(size: v)))),
                    const SizedBox(width: 10),
                    Expanded(child: CustomNumericField(label: loc.priceUSDLabel, initialValue: e.value.price, onChanged: (v) => p.updatePackagingItem(e.key, e.value.copyWith(price: v, priceSYP: exchangeRate > 0 ? v * exchangeRate : 0)))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: CustomNumericField(label: loc.priceSYPLabel, initialValue: e.value.priceSYP, onChanged: (v) => p.updatePackagingItem(e.key, e.value.copyWith(priceSYP: v, price: exchangeRate > 0 ? v / exchangeRate : 0)))),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        Text(loc.hasCartonLabel, style: const TextStyle(fontFamily: 'Cairo')),
                        Switch(value: e.value.hasCarton, onChanged: (v) => p.updatePackagingItem(e.key, e.value.copyWith(hasCarton: v))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => p.removePackagingItem(e.key)),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildCartonSection(BuildContext context, PackagingProvider p, AppLocalizations loc) {
    final exchangeRate = context.read<ProductionProvider>().exchangeRate;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(loc.cartonDetailsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: p.decrementPackagesPerCarton),
                Text('${loc.cartonCountLabel}: ${p.packagesPerCarton}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: p.incrementPackagesPerCarton),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: CustomNumericField(label: loc.cartonPriceEmpty, initialValue: p.cartonPrice, onChanged: (v) => p.setCartonPriceUSD(v, exchangeRate))),
                const SizedBox(width: 10),
                Expanded(child: CustomNumericField(label: loc.cartonPriceEmptySYP, initialValue: p.cartonPriceSYP, onChanged: (v) => p.setCartonPriceSYP(v, exchangeRate))),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: CustomNumericField(label: loc.labelPrice, initialValue: p.labelPrice, onChanged: (v) => p.setLabelPriceUSD(v, exchangeRate))),
                const SizedBox(width: 10),
                Expanded(child: CustomNumericField(label: loc.labelPriceSYP, initialValue: p.labelPriceSYP, onChanged: (v) => p.setLabelPriceSYP(v, exchangeRate))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}