import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/dashboard/sale_list_item.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/domain/entities/sale_item.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('SaleListItem goldens', () {
    Widget sample() => SaleListItem(
          sale: Sale(
            id: 'sale-1',
            storeId: 'store-1',
            receiptNo: 'R-00042',
            subtotal: 125000,
            discount: 0,
            total: 125000,
            paymentType: 'CASH',
            paidAmount: 125000,
            change: 0,
            items: const [
              SaleItem(
                id: 'si-1',
                saleId: 'sale-1',
                productId: 'p-1',
                productName: 'Молоко 1л',
                quantity: 2,
                unitPrice: 6000,
                total: 12000,
              ),
            ],
            createdAt: DateTime(2024, 1, 15, 10, 30),
          ),
          onTap: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'sale_list_item_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'sale_list_item_dark');
    });
  });
}
