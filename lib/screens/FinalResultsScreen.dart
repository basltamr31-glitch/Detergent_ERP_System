import 'dart:typed_data';
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

  Future<void> _generatePdf(BuildContext context, ProductionProvider prod, PackagingProvider pack, AppLocalizations loc) async {
    final pdf = pw.Document();

    final ByteData fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final pw.Font arabicFont = pw.Font.ttf(fontData);
    final ByteData fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final pw.Font arabicFontBold = pw.Font.ttf(fontBoldData);

    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pw.TextDirection direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: direction,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Center(child: pw.Text('${loc.tabReports}: ${prod.productName}', style: pw.TextStyle(fontSize: 22, color: PdfColors.blue800)))),
            pw.SizedBox(height: 20),

            pw.Text(loc.summaryGeneral, style: pw.TextStyle(fontSize: 16, font: arabicFontBold)),
            pw.Divider(),
            _pdfRow(loc.finalProductName, prod.productName),
            _pdfRow(loc.totalProducedQuantity, '${prod.producedQuantity} كغ'),
            _pdfRow(loc.approvedExchangeRate, '${prod.exchangeRate}'),
            _pdfRow('Cost (\$)', '${prod.totalCostUSD.toStringAsFixed(2)} \$'),
            _pdfRow('Cost (SYP)', '${prod.totalCostSYP.toStringAsFixed(0)}'),
            _pdfRow(loc.costPerKgUSD, '${prod.totalCostUSDKG.toStringAsFixed(2)} \$'),
            _pdfRow(loc.costPerKgSYP, '${prod.totalCostSYPKG.toStringAsFixed(0)}'),
            _pdfRow(loc.activeIngredientsPercentage, '% ${prod.activeIngredientsPercentage.toStringAsFixed(2)}'),

            pw.SizedBox(height: 20),

            if (prod.rawMaterials.isNotEmpty) ...[
              pw.Text(loc.usedRawMaterials, style: pw.TextStyle(fontSize: 14, font: arabicFontBold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: [loc.materialName, loc.weightLabel, loc.priceUSDLabel, loc.priceSYPLabel],
                data: prod.rawMaterials.map((m) => [m.name, '${m.quantity}', '${m.priceUSD * m.quantity}', '${m.priceSYP * m.quantity}']).toList(),
                headerStyle: pw.TextStyle(font: arabicFontBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(font: arabicFont),
              ),
              pw.SizedBox(height: 20),
            ],

            if (pack.packagingItems.isNotEmpty) ...[
              pw.Text(loc.packagingDetailsTitle, style: pw.TextStyle(fontSize: 14, font: arabicFontBold)),
              pw.SizedBox(height: 10),
              ...pack.packagingItems.map((item) {
                final unitCostUSD = pack.calculateUnitCostUSD(item.size, item.price, prod.totalCostUSDKG);
                final unitCostSYP = unitCostUSD * prod.exchangeRate;

                List<pw.Widget> packageDetails = [
                  pw.Text(loc.packageSizeTitle(item.size.toString()), style: pw.TextStyle(fontSize: 12, font: arabicFontBold, color: PdfColors.blueGrey700)),
                  _pdfRow(loc.packagePriceUSD, '${unitCostUSD.toStringAsFixed(2)} \$'),
                  _pdfRow(loc.packagePriceSYP, '${unitCostSYP.toStringAsFixed(0)}'),
                ];

                if (item.hasCarton) {
                  final cartonCostUSD = pack.calculateTotalCartonCostUSD(item.size, item.price, prod.totalCostUSDKG);
                  final cartonCostSYP = cartonCostUSD * prod.exchangeRate;
                  packageDetails.addAll([
                    _pdfRow(loc.cartonPriceUSD, '${cartonCostUSD.toStringAsFixed(2)} \$'),
                    _pdfRow(loc.cartonPriceSYP, '${cartonCostSYP.toStringAsFixed(0)}'),
                  ]);
                }

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: packageDetails),
                );
              }).toList(),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
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
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  textAlign: TextAlign.center),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSectionCard(localizations.summaryGeneral, [
                      _resultItem(localizations.finalProductName, productionProvider.productName),
                      _resultItem(localizations.totalProducedQuantity, '${productionProvider.producedQuantity}'),
                      _resultItem(localizations.approvedExchangeRate, '${productionProvider.exchangeRate}'),
                      _resultItem(localizations.costPerKgUSD, '${productionProvider.totalCostUSDKG.toStringAsFixed(2)} \$'),
                      _resultItem(localizations.costPerKgSYP, '${productionProvider.totalCostSYPKG.toStringAsFixed(0)}'),
                      _resultItem(localizations.activeIngredientsPercentage, '% ${productionProvider.activeIngredientsPercentage.toStringAsFixed(2)}'),
                    ]),

                    const SizedBox(height: 15),

                    if (productionProvider.rawMaterials.isNotEmpty)
                      _buildSectionCard(localizations.usedRawMaterials, [
                        ...productionProvider.rawMaterials.map((m) {
                           return _resultItem('${m.name} (${m.quantity})', '${(m.priceUSD * m.quantity).toStringAsFixed(2)} \$ / ${(m.priceSYP * m.quantity).toStringAsFixed(0)}');
                        }),
                      ]),

                    const SizedBox(height: 15),

                    if (packagingProvider.packagingItems.isNotEmpty)
                      _buildSectionCard(localizations.packagingDetailsTitle, [
                        ...packagingProvider.packagingItems.map((item) {
                          final unitCostUSD = packagingProvider.calculateUnitCostUSD(item.size, item.price, productionProvider.totalCostUSDKG);
                          final unitCostSYP = unitCostUSD * productionProvider.exchangeRate;

                          List<Widget> content = [
                                Text(localizations.packageSizeTitle(item.size.toString()), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16, fontFamily: 'Cairo')),
                                const Divider(),
                                _resultItem(localizations.packagePriceUSD, '${unitCostUSD.toStringAsFixed(2)} \$'),
                                _resultItem(localizations.packagePriceSYP, '${unitCostSYP.toStringAsFixed(0)}'),
                          ];

                          if (item.hasCarton) {
                              final cartonCostUSD = packagingProvider.calculateTotalCartonCostUSD(item.size, item.price, productionProvider.totalCostUSDKG);
                              final cartonCostSYP = cartonCostUSD * productionProvider.exchangeRate;
                              content.addAll([
                                  _resultItem(localizations.cartonPriceUSD, '${cartonCostUSD.toStringAsFixed(2)} \$'),
                                  _resultItem(localizations.cartonPriceSYP, '${cartonCostSYP.toStringAsFixed(0)}'),
                              ]);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue[100]!)),
                            child: Column(
                              children: content,
                            ),
                          );
                        }),
                      ]),

                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      onPressed: () => _generatePdf(context, productionProvider, packagingProvider, localizations),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text(localizations.generatePDFBtn, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue, fontFamily: 'Cairo')),
        const Divider(thickness: 1.5),
        const SizedBox(height: 10),
        ...children,
      ]),
    ),
  );

  Widget _resultItem(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
    ]),
  );
}