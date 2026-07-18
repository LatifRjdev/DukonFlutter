import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/finance_summary.dart';

void main() {
  group('FinanceSummary', () {
    test('defaults topProducts to an empty list when not provided', () {
      const summary = FinanceSummary(
        totalIncome: 100,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 20,
      );

      expect(summary.topProducts, isEmpty);
    });

    test('two instances with the same core fields are equal (Equatable)', () {
      const a = FinanceSummary(
        totalIncome: 100,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 20,
      );
      const b = FinanceSummary(
        totalIncome: 100,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 20,
      );

      expect(a, equals(b));
    });

    test('instances differing only by avgCheck or topProducts still compare '
        'equal (both fields excluded from props)', () {
      const a = FinanceSummary(
        totalIncome: 100,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 20,
      );
      const b = FinanceSummary(
        totalIncome: 100,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 999,
        topProducts: [
          TopProduct(id: 'p1', name: 'Bread', quantity: 1, revenue: 10),
        ],
      );

      // NOTE: FinanceSummary.props omits avgCheck and topProducts, so this
      // equality holds even though the two instances are visibly different.
      // Flagged in report as a possible bug — not fixed per task scope.
      expect(a, equals(b));
    });

    test('instances differing by totalIncome are not equal', () {
      const a = FinanceSummary(
        totalIncome: 100,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 20,
      );
      const b = FinanceSummary(
        totalIncome: 200,
        totalExpenses: 40,
        profit: 60,
        salesCount: 5,
        avgCheck: 20,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('TopProduct', () {
    test('two instances with the same fields are equal (Equatable)', () {
      const a = TopProduct(id: 'p1', name: 'Bread', quantity: 3, revenue: 30);
      const b = TopProduct(id: 'p1', name: 'Bread', quantity: 3, revenue: 30);

      expect(a, equals(b));
    });

    test('instances differing by id are not equal', () {
      const a = TopProduct(id: 'p1', name: 'Bread', quantity: 3, revenue: 30);
      const b = TopProduct(id: 'p2', name: 'Bread', quantity: 3, revenue: 30);

      expect(a, isNot(equals(b)));
    });
  });
}
