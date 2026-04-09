import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/sale.dart';
import '../utils/formatters.dart';

enum PaperWidth {
  mm58(164.0),
  mm80(226.0);

  final double points;
  const PaperWidth(this.points);
}

class ReceiptPdfService {
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  Future<void> _loadFonts() async {
    if (_regularFont != null) return;
    final regularData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
  }

  Future<Uint8List> generateReceipt({
    required Sale sale,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    PaperWidth paperWidth = PaperWidth.mm80,
  }) async {
    await _loadFonts();

    final doc = pw.Document();
    final regular = pw.TextStyle(font: _regularFont, fontSize: 10);
    final smallRegular = pw.TextStyle(font: _regularFont, fontSize: 8);
    final smallBold = pw.TextStyle(font: _boldFont, fontSize: 8);
    final titleStyle = pw.TextStyle(font: _boldFont, fontSize: 14);
    final totalStyle = pw.TextStyle(font: _boldFont, fontSize: 13);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          paperWidth.points * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(storeName, style: titleStyle, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            if (storeAddress != null)
              pw.Text(storeAddress, style: smallRegular, textAlign: pw.TextAlign.center),
            if (storePhone != null)
              pw.Text(storePhone, style: smallRegular, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),
            pw.Text('#${sale.receiptNo}', style: regular, textAlign: pw.TextAlign.center),
            pw.Text(Formatters.dateTime(sale.createdAt), style: smallRegular, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),
            _dashedDivider(),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text('Товар', style: smallBold)),
              pw.Expanded(child: pw.Text('Кол.', style: smallBold, textAlign: pw.TextAlign.center)),
              pw.Expanded(flex: 2, child: pw.Text('Сумма', style: smallBold, textAlign: pw.TextAlign.right)),
            ]),
            pw.SizedBox(height: 3),
            pw.Divider(height: 0.5),
            pw.SizedBox(height: 3),
            ...sale.items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(children: [
                pw.Expanded(flex: 3, child: pw.Text(item.productName, style: smallRegular, maxLines: 1)),
                pw.Expanded(child: pw.Text('${item.quantity}', style: smallRegular, textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 2, child: pw.Text(Formatters.price(item.total), style: smallRegular, textAlign: pw.TextAlign.right)),
              ]),
            )),
            pw.SizedBox(height: 4),
            _dashedDivider(),
            pw.SizedBox(height: 4),
            _totalRow('Подытог', Formatters.price(sale.subtotal), regular),
            if (sale.discount > 0)
              _totalRow('Скидка', '- ${Formatters.price(sale.discount)}', regular),
            pw.SizedBox(height: 2),
            _totalRow('ИТОГО', Formatters.price(sale.total), totalStyle),
            pw.SizedBox(height: 4),
            _dashedDivider(),
            pw.SizedBox(height: 4),
            _totalRow('Оплата', _paymentTypeName(sale.paymentType), regular),
            _totalRow('Оплачено', Formatters.price(sale.paidAmount), regular),
            if (sale.change > 0)
              _totalRow('Сдача', Formatters.price(sale.change), regular),
            if (sale.debtAmount > 0)
              _totalRow('Долг', Formatters.price(sale.debtAmount), regular),
            pw.SizedBox(height: 10),
            pw.Text('Спасибо за покупку!', style: regular, textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _totalRow(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _dashedDivider() {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor(0.74, 0.74, 0.74), width: 0.5, style: pw.BorderStyle.dashed),
        ),
      ),
      height: 1,
    );
  }

  String _paymentTypeName(String type) {
    switch (type) {
      case 'CASH': return 'Наличные';
      case 'CARD': return 'Карта';
      case 'DEBT': return 'В долг';
      case 'MIXED': return 'Смешанная';
      default: return type;
    }
  }
}
