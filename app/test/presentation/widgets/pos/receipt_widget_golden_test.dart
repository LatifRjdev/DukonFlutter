import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/pos/receipt_widget.dart';
import 'package:dokonpro/domain/entities/sale.dart';
import 'package:dokonpro/domain/entities/sale_item.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ReceiptWidget goldens', () {
    Widget sample() => ReceiptWidget(
          storeName: 'Магазин "Дастёрхон"',
          sale: Sale(
            id: 'sale-1',
            storeId: 'store-1',
            receiptNo: 'R-00101',
            subtotal: 28900,
            discount: 0,
            total: 28900,
            paymentType: 'CASH',
            paidAmount: 30000,
            change: 1100,
            items: const [
              SaleItem(
                id: 'si-1',
                saleId: 'sale-1',
                productId: 'p-1',
                productName: 'Молоко 1л',
                quantity: 2,
                unitPrice: 8500,
                total: 17000,
              ),
              SaleItem(
                id: 'si-2',
                saleId: 'sale-1',
                productId: 'p-2',
                productName: 'Хлеб пшеничный',
                quantity: 3,
                unitPrice: 3900,
                total: 11700,
              ),
            ],
            createdAt: DateTime(2024, 1, 15, 14, 30),
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        size: const Size(390, 844),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'receipt_widget_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        size: const Size(390, 844),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'receipt_widget_dark');
    });
  });
}
