import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/finance_summary.dart';

void main() {
  // Guards two defects found by seeding known data:
  //  - «Чистая прибыль» was `profit - totalExpenses`, where profit was already
  //    income - expenses, so expenses were deducted twice: 575-420-420 = -265.
  //    The screen reported a loss on a store that is not making one.
  //  - «Валовая прибыль» rendered that same `profit`, i.e. revenue - expenses,
  //    under a label that means revenue - cost of goods.
  const s = FinanceSummary(
    totalIncome: 575,
    totalCost: 230,
    totalExpenses: 420,
    profit: -75,
    salesCount: 3,
    avgCheck: 575 / 3,
  );

  test('gross profit is revenue minus cost of goods', () {
    expect(s.grossProfit, 345);
  });

  test('net profit subtracts expenses exactly once', () {
    expect(s.netProfit, -75);
    expect(s.netProfit, s.grossProfit - s.totalExpenses);
  });
}
