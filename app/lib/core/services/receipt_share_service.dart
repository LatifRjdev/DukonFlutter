import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../domain/entities/sale.dart';
import 'receipt_pdf_service.dart';

class ReceiptShareService {
  final ReceiptPdfService _pdfService;

  ReceiptShareService({required ReceiptPdfService pdfService})
      : _pdfService = pdfService;

  Future<void> shareReceipt({
    required Sale sale,
    required String storeName,
    required AppLocalizations l10n,
    String? storeAddress,
    String? storePhone,
  }) async {
    final pdfBytes = await _pdfService.generateReceipt(
      sale: sale,
      storeName: storeName,
      l10n: l10n,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = 'receipt_${sale.receiptNo}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: l10n.transactionDetailReceiptTitle(sale.receiptNo.toString()),
    );
  }
}
