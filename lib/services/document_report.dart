import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/trade_document.dart';
import '../models/document_payment.dart';
import 'money.dart';

class DocumentReport {
  static Future<Uint8List> build(
      TradeDocument document, List<DocumentPayment> payments,
      {required bool arabic}) async {
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
    final pdf = pw.Document();
    String t(String en, String ar) => arabic ? ar : en;
    final allocations =
        payments.where((p) => p.documentId == document.id).toList();
    final paid = document.paidMinor +
        allocations.fold<int>(
            0,
            (sum, p) =>
                sum + (p.kind == 'refund' ? -p.amountMinor : p.amountMinor));
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => [
              pw.Text(
                  t('Detergent Factory • Goods document',
                      'مصنع المنظفات • مستند بضاعة'),
                  style: pw.TextStyle(font: bold, fontSize: 20)),
              pw.Text('${document.number} • ${document.type}'),
              pw.Text(document.date.toLocal().toString().split('.').first),
              pw.Text('${t('Party', 'الطرف')}: ${document.party}'),
              if (document.reference.isNotEmpty)
                pw.Text('${t('Reference', 'المرجع')}: ${document.reference}'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                  headers: [
                    t('Item', 'الصنف'),
                    t('Quantity', 'الكمية'),
                    t('Unit', 'الوحدة'),
                    t('Price', 'السعر'),
                    t('Total', 'الإجمالي')
                  ],
                  data: document.lines
                      .map((l) => [
                            l.itemName,
                            l.quantity.toString(),
                            l.unit,
                            Money.format(l.unitPriceMinor),
                            Money.format(l.totalMinor)
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(font: bold),
                  cellStyle: pw.TextStyle(font: regular),
                  cellAlignment: pw.Alignment.center),
              pw.SizedBox(height: 16),
              pw.Text('${t('Total', 'الإجمالي')}: ${document.amount}'),
              pw.Text(
                  '${t('Paid at posting', 'المدفوع عند التسجيل')}: ${Money.format(document.paidMinor)} ${document.currency}'),
              if (document.reversalOf == null) ...[
                pw.Text(
                    '${t('Current paid', 'المدفوع الحالي')}: ${Money.format(paid)} ${document.currency}'),
                pw.Text(
                    '${t('Outstanding', 'المتبقي')}: ${Money.format(document.totalMinor - paid)} ${document.currency}')
              ],
              for (final p in allocations)
                pw.Text(
                    '${p.date.toLocal().toString().split('.').first} • ${p.kind} • ${Money.format(p.amountMinor)} ${document.currency} • ${p.reference} ${p.reason}'),
              if (document.reason.isNotEmpty) pw.Text(document.reason),
              pw.Text(
                  '${t('Posted by', 'سجل بواسطة')}: ${document.actor['name']}'),
              pw.SizedBox(height: 12),
              pw.Text(t(
                  'Tax configuration is not set. This document does not calculate tax.',
                  'إعداد الضرائب غير محدد. لا يحسب هذا المستند الضرائب.'))
            ]));
    return pdf.save();
  }
}
