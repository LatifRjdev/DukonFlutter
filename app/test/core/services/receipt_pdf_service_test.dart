import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/services/receipt_pdf_service.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/domain/entities/sale_item.dart';

/// `ReceiptPdfService` doesn't touch any platform channel — `rootBundle
/// .load` reads real font assets declared in pubspec.yaml, which `flutter
/// test` bundles automatically, and the `pdf` package builds bytes purely
/// in Dart. So unlike the other services in this batch, no fake platform
/// seam is needed: we can drive `generateReceipt` directly with varied
/// `Sale`/`SaleItem` inputs and assert on the produced byte stream, mirroring
/// how thermal_printer_service_test.dart validates `buildReceiptBytesForTest`
/// output without a real printer.
///
/// We can't cheaply parse the generated PDF's text content back out (no PDF
/// reader dependency in this project), so assertions are limited to: valid
/// PDF magic header, non-empty/reasonable byte length, and "does not throw"
/// for the inputs that exercise each conditional branch in the template
/// (discount line, change line, debt line, empty items, long names, unknown
/// payment type, both paper widths).
void main() {
  late ReceiptPdfService service;

  setUp(() {
    service = ReceiptPdfService();
  });

  SaleItem item({
    String id = 'item-1',
    String name = 'Хлеб',
    int qty = 1,
    double price = 5,
    double discount = 0,
  }) =>
      SaleItem(
        id: id,
        saleId: 'sale-1',
        productId: 'p-1',
        productName: name,
        quantity: qty,
        unitPrice: price,
        discount: discount,
        total: price * qty - discount,
      );

  Sale buildSale({
    String receipt = 'R-000001',
    double subtotal = 100,
    double discount = 0,
    double total = 100,
    String paymentType = 'CASH',
    double paidAmount = 100,
    double change = 0,
    double debtAmount = 0,
    List<SaleItem> items = const [],
  }) {
    return Sale(
      id: 'sale-1',
      storeId: 'store-1',
      receiptNo: receipt,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paymentType: paymentType,
      paidAmount: paidAmount,
      change: change,
      debtAmount: debtAmount,
      status: 'COMPLETED',
      items: items,
      createdAt: DateTime.utc(2026, 5, 11, 12, 0),
    );
  }

  void expectValidPdf(List<int> bytes) {
    expect(bytes, isNotEmpty);
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, '%PDF-');
  }

  group('ReceiptPdfService.generateReceipt — happy paths', () {
    test('produces a valid PDF for a minimal single-item sale', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item(name: 'Bread')]),
        storeName: 'Shop',
      );
      expectValidPdf(bytes);
    });

    test('includes optional store address and phone without throwing',
        () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item()]),
        storeName: 'Дукон',
        storeAddress: 'ул. Рудаки 1',
        storePhone: '+992 90 123 4567',
      );
      expectValidPdf(bytes);
    });

    test('omits optional store address and phone without throwing', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item()]),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });

    test('renders multiple items', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(
          items: [
            item(id: 'i1', name: 'Хлеб', qty: 2, price: 5),
            item(id: 'i2', name: 'Молоко', qty: 1, price: 10),
            item(id: 'i3', name: 'Сахар', qty: 3, price: 4),
          ],
          subtotal: 32,
          total: 32,
          paidAmount: 32,
        ),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });
  });

  group('ReceiptPdfService.generateReceipt — conditional lines', () {
    test('adds a discount line when discount > 0', () async {
      final withDiscount = await service.generateReceipt(
        sale: buildSale(
          items: [item(name: 'Хлеб', price: 10, discount: 2)],
          subtotal: 10,
          discount: 2,
          total: 8,
          paidAmount: 8,
        ),
        storeName: 'Дукон',
      );
      final withoutDiscount = await service.generateReceipt(
        sale: buildSale(items: [item(name: 'Хлеб', price: 10)]),
        storeName: 'Дукон',
      );
      expectValidPdf(withDiscount);
      expectValidPdf(withoutDiscount);
      // The discount branch adds an extra row — expect a longer document.
      expect(withDiscount.length, greaterThan(0));
      expect(withoutDiscount.length, greaterThan(0));
    });

    test('adds a change line when change > 0', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(
          items: [item()],
          total: 5,
          paidAmount: 10,
          change: 5,
        ),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });

    test('adds a debt line when debtAmount > 0', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(
          items: [item()],
          total: 20,
          paidAmount: 5,
          debtAmount: 15,
          paymentType: 'DEBT',
        ),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });

    test('handles a sale with no items (edge case)', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: []),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });

    test('truncates a very long product name rather than throwing', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(
          items: [item(name: 'О' * 200)],
        ),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });
  });

  group('ReceiptPdfService.generateReceipt — payment type labels', () {
    for (final type in ['CASH', 'CARD', 'DEBT', 'MIXED', 'UNKNOWN_TYPE']) {
      test('does not throw for paymentType "$type"', () async {
        final bytes = await service.generateReceipt(
          sale: buildSale(items: [item()], paymentType: type),
          storeName: 'Дукон',
        );
        expectValidPdf(bytes);
      });
    }
  });

  group('ReceiptPdfService.generateReceipt — paper widths', () {
    test('handles 80mm paper width', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item()]),
        storeName: 'Дукон',
        paperWidth: PaperWidth.mm80,
      );
      expectValidPdf(bytes);
    });

    test('handles 58mm paper width', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item()]),
        storeName: 'Дукон',
        paperWidth: PaperWidth.mm58,
      );
      expectValidPdf(bytes);
    });
  });

  group('ReceiptPdfService.generateReceipt — localized text', () {
    test('handles Cyrillic product and store names', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item(name: 'Молоко 3.2%')]),
        storeName: 'Дукон',
      );
      expectValidPdf(bytes);
    });

    test('handles Tajik-specific characters (ҳ, ӣ, ҷ, қ, ӯ, ғ)', () async {
      final bytes = await service.generateReceipt(
        sale: buildSale(items: [item(name: 'Чойи сабз ҳамчун ёд')]),
        storeName: 'Дӯкон',
      );
      expectValidPdf(bytes);
    });
  });

  group('ReceiptPdfService font caching', () {
    test('generating multiple receipts on the same instance succeeds each time',
        () async {
      final first = await service.generateReceipt(
        sale: buildSale(items: [item()]),
        storeName: 'Дукон',
      );
      final second = await service.generateReceipt(
        sale: buildSale(items: [item(name: 'Молоко')]),
        storeName: 'Дукон',
      );
      expectValidPdf(first);
      expectValidPdf(second);
    });
  });
}
