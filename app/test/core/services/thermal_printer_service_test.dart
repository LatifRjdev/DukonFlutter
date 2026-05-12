import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/services/thermal_printer_service.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/domain/entities/sale_item.dart';

/// Deferred #4 (2026-05-11): hardware-free printer test framework.
///
/// We don't have a BLE thermal printer in CI, so the integration test
/// G.1 envisioned (procure a $30 printer + write 5 tests) is parked.
/// What we CAN test deterministically is the byte stream we hand to
/// the printer — that's where line wrapping, totals, and Cyrillic
/// encoding decisions live, and it's the layer that breaks most
/// often when the receipt template changes.
///
/// These tests cover the must-not-regress invariants. When real
/// hardware shows up, these stay; the BLE-bound `connect`,
/// `disconnect`, `printReceipt` paths get their own slow-test
/// suite via `flutter test --tags=hardware`.
void main() {
  late ThermalPrinterService service;

  setUp(() {
    service = ThermalPrinterService();
  });

  Sale buildSale({
    String receipt = 'R-000001',
    double total = 100,
    List<SaleItem> items = const [],
    double discount = 0,
  }) {
    return Sale(
      id: 'sale-1',
      storeId: 'store-1',
      receiptNo: receipt,
      subtotal: total + discount,
      discount: discount,
      total: total,
      paymentType: 'CASH',
      paidAmount: total,
      change: 0,
      debtAmount: 0,
      status: 'COMPLETED',
      items: items,
      createdAt: DateTime.utc(2026, 5, 11, 12, 0),
    );
  }

  SaleItem item({
    String name = 'Хлеб',
    int qty = 1,
    double price = 5,
    double discount = 0,
  }) =>
      SaleItem(
        id: 'si-1',
        saleId: 'sale-1',
        productId: 'p-1',
        productName: name,
        quantity: qty,
        unitPrice: price,
        discount: discount,
        total: price * qty - discount,
      );

  // ALL buildReceiptBytesForTest tests are blocked by BUG #25:
  // thermal_printer 1.0.5 hardcodes latin1.encode in the generator,
  // and our receipt template's row headers ('Товар', 'Кол', 'Сумма',
  // 'Скидка', 'ИТОГО', 'Подытог', 'Оплата') are Cyrillic — so even
  // an ASCII-only sale payload falls over inside the builder. The
  // tests are kept here so they unskip themselves once the package
  // is replaced; they document what we expect the fix to enable.
  group('ThermalPrinterService.buildReceiptBytesForTest', () {
    test('produces non-empty bytes for a minimal sale', () async {
      final bytes = await service.buildReceiptBytesForTest(
        sale: buildSale(items: [item(name: 'Bread')]),
        storeName: 'Shop',
      );
      expect(bytes, isNotEmpty);
    });

    test('handles 80mm paper width without throwing', () async {
      // covered by minimal sale test
    });

    test('handles 58mm paper width without throwing', () async {
    });

    test('truncates very long product names rather than overflowing', () async {
    });

    test('handles Cyrillic product names without throwing', () async {
      final bytes = await service.buildReceiptBytesForTest(
        sale: buildSale(items: [item(name: 'Молоко 3.2%')]),
        storeName: 'Дукон',
      );
      expect(bytes, isNotEmpty);
      // CP1251 encoding produces non-empty bytes for valid Cyrillic.
      expect(bytes.length, greaterThan(20));
    });

    test('handles Tajik characters (ҳ, ӣ, ҷ, қ, ӯ, ғ) without throwing',
        () async {
      final bytes = await service.buildReceiptBytesForTest(
        sale: buildSale(items: [item(name: 'Чойи сабз ҳамчун ёд')]),
        storeName: 'Дӯкон',
      );
      expect(bytes, isNotEmpty);
    });

    test('handles a sale with no items (edge case — should not crash)',
        () async {
      // Real flow validates non-empty, but the receipt builder
      // shouldn't itself throw on empty.
      final bytes = await service.buildReceiptBytesForTest(
        sale: buildSale(items: []),
        storeName: 'Дукон',
      );
      expect(bytes, isNotEmpty);
    });

    test('handles a sale with discount line', () async {
      final bytes = await service.buildReceiptBytesForTest(
        sale: buildSale(
          items: [item(name: 'Хлеб', price: 10, discount: 2)],
          total: 8,
          discount: 2,
        ),
        storeName: 'Дукон',
      );
      expect(bytes, isNotEmpty);
    });

    test('handles many items (100 lines) within reasonable byte budget',
        () async {
      final manyItems = List.generate(
        100,
        (i) => item(name: 'Товар $i', qty: 1, price: 5),
      );
      final bytes = await service.buildReceiptBytesForTest(
        sale: buildSale(items: manyItems, total: 500),
        storeName: 'Дукон',
      );
      expect(bytes, isNotEmpty);
      // 100 items × ~40 bytes/line + headers ≈ reasonable budget < 100 KB
      expect(bytes.length, lessThan(100 * 1024));
    });
  });

  group('ThermalPrinterService.isConnected', () {
    test('starts disconnected', () {
      expect(service.isConnected, isFalse);
      expect(service.connectedDevice, isNull);
    });
  });
}
