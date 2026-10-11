import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../l10n/app_localizations.dart';

import '../providers/packaging_provider.dart';
import '../providers/production_provider.dart';

class FinalResultScreen extends StatelessWidget {
  const FinalResultScreen({super.key});

  String _syp(double value, double rate) =>
      rate > 0 ? value.toStringAsFixed(0) : '—';

  Future<void> _generatePdf(BuildContext context, ProductionProvider prod,
      PackagingProvider pack, AppLocalizations loc) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pdf = pw.Document();

    final ByteData fontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final pw.Font arabicFont = pw.Font.ttf(fontData);
    final ByteData fontBoldData =
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final pw.Font arabicFontBold = pw.Font.ttf(fontBoldData);

    final pw.TextDirection direction =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: direction,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Center(
                    child: pw.Text('${loc.tabReports}: ${prod.productName}',
                        style: const pw.TextStyle(
                            fontSize: 22, color: PdfColors.blue800)))),
            pw.SizedBox(height: 20),
            pw.Text(loc.summaryGeneral,
                style: pw.TextStyle(fontSize: 16, font: arabicFontBold)),
            pw.Divider(),
            _pdfRow(loc.finalProductName, prod.productName),
            _pdfRow(loc.totalProducedQuantity, '${prod.producedQuantity} kg'),
            _pdfRow(loc.approvedExchangeRate, '${prod.exchangeRate}'),
            _pdfRow('Cost (\$)', '${prod.totalCostUSD.toStringAsFixed(2)} \$'),
            _pdfRow('Cost (SYP)', _syp(prod.totalCostSYP, prod.exchangeRate)),
            _pdfRow(loc.costPerKgUSD,
                '${prod.totalCostUSDKG.toStringAsFixed(2)} \$'),
            _pdfRow(
                loc.costPerKgSYP, _syp(prod.totalCostSYPKG, prod.exchangeRate)),
            _pdfRow(loc.activeIngredientsPercentage,
                '% ${prod.activeIngredientsPercentage.toStringAsFixed(2)}'),
            pw.Text(isArabic
                ? 'تقدير تكلفة فقط؛ ليس تقييماً للمخزون أو قيداً محاسبياً.'
                : 'Cost estimate only; not inventory valuation or an accounting entry.'),
            if (prod.exchangeRate <= 0)
              pw.Text(isArabic
                  ? 'سعر الصرف غير محدد؛ إجماليات SYP غير متاحة.'
                  : 'Exchange rate is unset; SYP totals are unavailable.'),
            if (pack.packagingItems
                .any((item) => item.unit == 'ml' || item.unit == 'L'))
              _pdfRow(
                  isArabic
                      ? 'الكثافة المقاسة (kg/L)'
                      : 'Measured density (kg/L)',
                  pack.densityKgPerLiter.toString()),
            pw.SizedBox(height: 20),
            if (prod.rawMaterials.isNotEmpty) ...[
              pw.Text(loc.usedRawMaterials,
                  style: pw.TextStyle(fontSize: 14, font: arabicFontBold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: [
                  loc.materialName,
                  loc.weightLabel,
                  loc.priceUSDLabel,
                  loc.priceSYPLabel
                ],
                data: prod.rawMaterials
                    .map((m) => [
                          m.name,
                          '${m.quantity}',
                          '${m.priceUSD * m.quantity}',
                          _syp(m.priceSYP * m.quantity, prod.exchangeRate)
                        ])
                    .toList(),
                headerStyle:
                    pw.TextStyle(font: arabicFontBold, color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(font: arabicFont),
              ),
              pw.SizedBox(height: 20),
            ],
            if (pack.packagingItems.isNotEmpty) ...[
              pw.Text(loc.packagingDetailsTitle,
                  style: pw.TextStyle(fontSize: 14, font: arabicFontBold)),
              pw.SizedBox(height: 10),
              ...pack.packagingItems.map((item) {
                final unitCostUSD = pack.calculateUnitCostUSD(
                    item.size, item.price, prod.totalCostUSDKG,
                    unit: item.unit);
                final unitCostSYP = unitCostUSD * prod.exchangeRate;

                List<pw.Widget> packageDetails = [
                  pw.Text(
                      '${isArabic ? 'مقاس التعبئة' : 'Fill size'}: ${item.size} ${item.unit}',
                      style: pw.TextStyle(
                          fontSize: 12,
                          font: arabicFontBold,
                          color: PdfColors.blueGrey700)),
                  _pdfRow(isArabic ? 'وزن التعبئة (kg)' : 'Fill mass (kg)',
                      pack.fillMassKg(item).toStringAsFixed(6)),
                  _pdfRow(
                      isArabic ? 'تكلفة السائل USD' : 'Liquid cost USD',
                      (pack.fillMassKg(item) * prod.totalCostUSDKG)
                          .toStringAsFixed(2)),
                  _pdfRow(
                      isArabic ? 'العبوة الفارغة USD' : 'Empty container USD',
                      item.price.toStringAsFixed(2)),
                  _pdfRow(isArabic ? 'الملصق USD' : 'Label USD',
                      pack.labelPrice.toStringAsFixed(2)),
                  _pdfRow(loc.packagePriceUSD,
                      '${unitCostUSD.toStringAsFixed(2)} \$'),
                  _pdfRow(loc.packagePriceSYP,
                      _syp(unitCostSYP, prod.exchangeRate)),
                ];

                if (item.hasCarton) {
                  final cartonCostUSD = pack.calculateTotalCartonCostUSD(
                      item.size, item.price, prod.totalCostUSDKG,
                      unit: item.unit);
                  final cartonCostSYP = cartonCostUSD * prod.exchangeRate;
                  packageDetails.addAll([
                    _pdfRow(loc.cartonPriceUSD,
                        '${cartonCostUSD.toStringAsFixed(2)} \$'),
                    _pdfRow(loc.cartonPriceSYP,
                        _syp(cartonCostSYP, prod.exchangeRate)),
                  ]);
                }

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: packageDetails),
                );
              }),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label),
            pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final packagingProvider = context.watch<PackagingProvider>();
    final productionProvider = context.watch<ProductionProvider>();
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return const SizedBox();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String ar) => arabic ? ar : en;
    final issues = <String>[];
    if (productionProvider.productName.trim().isEmpty ||
        productionProvider.producedQuantity <= 0 ||
        productionProvider.rawMaterials.isEmpty) {
      issues.add(t(
          'Enter a product name, positive output in kilograms and ingredients before calculating costs.',
          'أدخل اسم المنتج وكمية إنتاج موجبة بالكيلوغرام والمكونات قبل حساب التكلفة.'));
    }
    if (productionProvider.rawMaterials
        .any((m) => m.name.trim().isEmpty || m.quantity <= 0)) {
      issues.add(t('Complete ingredient names and positive quantities.',
          'أكمل أسماء المكونات والكميات الموجبة.'));
    }
    for (final item in packagingProvider.packagingItems) {
      if (!item.unitConfirmed ||
          item.size <= 0 ||
          ((item.unit == 'ml' || item.unit == 'L') &&
              packagingProvider.densityKgPerLiter <= 0)) {
        issues.add(t(
            'Confirm each fill unit and positive size. Volume fills require measured density in kg/L.',
            'أكد وحدة التعبئة والمقاس الموجب لكل عبوة. التعبئة بالحجم تحتاج كثافة مقاسة بوحدة kg/L.'));
        break;
      }
    }
    if (issues.isEmpty) {
      try {
        if (!productionProvider.totalCostUSD.isFinite ||
            !productionProvider.totalCostUSDKG.isFinite ||
            !productionProvider.totalCostSYP.isFinite) {
          throw ArgumentError('Cost out of range.');
        }
        for (final item in packagingProvider.packagingItems) {
          final cost = packagingProvider.calculateUnitCostUSD(
              item.size, item.price, productionProvider.totalCostUSDKG,
              unit: item.unit);
          if (!(cost * productionProvider.exchangeRate).isFinite) {
            throw ArgumentError('Cost out of range.');
          }
          if (item.hasCarton) {
            final carton = packagingProvider.calculateTotalCartonCostUSD(
                item.size, item.price, productionProvider.totalCostUSDKG,
                unit: item.unit);
            if (!(carton * productionProvider.exchangeRate).isFinite) {
              throw ArgumentError('Cost out of range.');
            }
          }
        }
      } on ArgumentError {
        issues.add(t(
            'Cost exceeds the supported range; review quantities, prices and exchange rate.',
            'التكلفة تتجاوز المجال المدعوم؛ راجع الكميات والأسعار وسعر الصرف.'));
      }
    }
    if (issues.isNotEmpty) {
      return Scaffold(
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(t('Complete costing inputs', 'أكمل بيانات التكلفة'),
            style: Theme.of(context).textTheme.headlineSmall),
        for (final issue in issues)
          Padding(padding: const EdgeInsets.only(top: 16), child: Text(issue)),
      ])));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text(localizations.finalResultsHeader,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo'),
                  textAlign: TextAlign.center),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(t(
                        'Cost estimate only: not inventory valuation or a posted accounting entry.',
                        'تقدير تكلفة فقط: ليس تقييماً للمخزون أو قيداً محاسبياً.')),
                    if (productionProvider.exchangeRate <= 0)
                      Text(t(
                          'Set a positive exchange rate to calculate SYP totals.',
                          'حدد سعر صرف موجباً لحساب الإجماليات بالليرة السورية.')),
                    _buildSectionCard(localizations.summaryGeneral, [
                      _resultItem(localizations.finalProductName,
                          productionProvider.productName),
                      _resultItem(localizations.totalProducedQuantity,
                          '${productionProvider.producedQuantity}'),
                      _resultItem(localizations.approvedExchangeRate,
                          '${productionProvider.exchangeRate}'),
                      _resultItem(localizations.costPerKgUSD,
                          '${productionProvider.totalCostUSDKG.toStringAsFixed(2)} \$'),
                      _resultItem(
                          localizations.costPerKgSYP,
                          _syp(productionProvider.totalCostSYPKG,
                              productionProvider.exchangeRate)),
                      _resultItem(localizations.activeIngredientsPercentage,
                          '% ${productionProvider.activeIngredientsPercentage.toStringAsFixed(2)}'),
                    ]),
                    const SizedBox(height: 15),
                    if (productionProvider.rawMaterials.isNotEmpty)
                      _buildSectionCard(localizations.usedRawMaterials, [
                        ...productionProvider.rawMaterials.map((m) {
                          return _resultItem('${m.name} (${m.quantity})',
                              '${(m.priceUSD * m.quantity).toStringAsFixed(2)} \$ / ${_syp(m.priceSYP * m.quantity, productionProvider.exchangeRate)}');
                        }),
                      ]),
                    const SizedBox(height: 15),
                    if (packagingProvider.packagingItems.isNotEmpty)
                      _buildSectionCard(localizations.packagingDetailsTitle, [
                        ...packagingProvider.packagingItems.map((item) {
                          final unitCostUSD =
                              packagingProvider.calculateUnitCostUSD(item.size,
                                  item.price, productionProvider.totalCostUSDKG,
                                  unit: item.unit);
                          final unitCostSYP =
                              unitCostUSD * productionProvider.exchangeRate;

                          List<Widget> content = [
                            Text(
                                '${t('Fill size', 'مقاس التعبئة')}: ${item.size} ${item.unit}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 16,
                                    fontFamily: 'Cairo')),
                            const Divider(),
                            _resultItem(
                                t('Fill mass (kg)', 'وزن التعبئة (kg)'),
                                packagingProvider
                                    .fillMassKg(item)
                                    .toStringAsFixed(6)),
                            _resultItem(
                                t('Liquid cost USD', 'تكلفة السائل USD'),
                                (packagingProvider.fillMassKg(item) *
                                        productionProvider.totalCostUSDKG)
                                    .toStringAsFixed(2)),
                            _resultItem(
                                t('Empty container USD', 'العبوة الفارغة USD'),
                                item.price.toStringAsFixed(2)),
                            _resultItem(
                                t('Label USD', 'الملصق USD'),
                                packagingProvider.labelPrice
                                    .toStringAsFixed(2)),
                            _resultItem(localizations.packagePriceUSD,
                                '${unitCostUSD.toStringAsFixed(2)} \$'),
                            _resultItem(
                                localizations.packagePriceSYP,
                                _syp(unitCostSYP,
                                    productionProvider.exchangeRate)),
                          ];

                          if (item.hasCarton) {
                            final cartonCostUSD =
                                packagingProvider.calculateTotalCartonCostUSD(
                                    item.size,
                                    item.price,
                                    productionProvider.totalCostUSDKG,
                                    unit: item.unit);
                            final cartonCostSYP =
                                cartonCostUSD * productionProvider.exchangeRate;
                            content.addAll([
                              _resultItem(localizations.cartonPriceUSD,
                                  '${cartonCostUSD.toStringAsFixed(2)} \$'),
                              _resultItem(
                                  localizations.cartonPriceSYP,
                                  _syp(cartonCostSYP,
                                      productionProvider.exchangeRate)),
                            ]);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue[100]!)),
                            child: Column(
                              children: content,
                            ),
                          );
                        }),
                      ]),
                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _generatePdf(context, productionProvider,
                              packagingProvider, localizations);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(t(
                                    'Unable to generate or print the cost report. Please retry.',
                                    'تعذر إنشاء أو طباعة تقرير التكلفة. أعد المحاولة.'))));
                          }
                        }
                      },
                      icon:
                          const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text(localizations.generatePDFBtn,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
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

  Widget _buildSectionCard(String title, List<Widget> children) => Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontFamily: 'Cairo')),
            const Divider(thickness: 1.5),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _resultItem(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87))),
        ]),
      );
}
