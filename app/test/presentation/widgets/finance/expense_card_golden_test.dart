import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/domain/entities/expense.dart';
import 'package:dukonpro/presentation/widgets/finance/expense_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ExpenseCard goldens', () {
    Widget sample() => ExpenseCard(
          expense: Expense(
            id: 'e1',
            storeId: 's1',
            category: 'PURCHASE',
            amount: 12500.00,
            description: 'Закупка товаров у поставщика',
            date: DateTime(2026, 4, 19),
            createdAt: DateTime(2026, 4, 19),
          ),
          onTap: () {},
          onDelete: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'expense_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'expense_card_dark');
    });
  });
}
