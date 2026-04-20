import 'package:dokonpro/domain/entities/sale.dart';
import 'package:dokonpro/presentation/pages/sales/transaction_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

Sale _fakeSale() => Sale(
      id: 'test-sale-id',
      storeId: 'test-store-id',
      receiptNo: '#0001',
      subtotal: 100.0,
      total: 100.0,
      paymentType: 'CASH',
      paidAmount: 100.0,
      status: 'COMPLETED',
      createdAt: DateTime(2026, 1, 15, 10, 30),
    );

void main() {
  Widget page() => TransactionDetailPage(sale: _fakeSale());

  group('TransactionDetailPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'transaction_detail_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'transaction_detail_dark');
    });
  });
}
