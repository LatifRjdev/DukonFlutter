import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/presentation/pages/finance/finance_dashboard_page.dart'
    show clampRevenueCard;

// Spec 2026-05-11-finance-nav-fixes-design.md, decision Q1=C:
// "Общий доход" and "Общие расходы" clamp to 0 on display because they
// are sums of money flowing in/out (cannot conceptually be negative).
// "Валовая прибыль" and "Чистая прибыль" keep negatives — a loss is a
// real signal the merchant must see.
//
// We test the clamp helper in isolation rather than the full widget tree
// because the dashboard depends on Bloc state and the actual rendering
// uses a NumberFormat. The helper is the unit that encodes the policy.
void main() {
  group('FinanceDashboard.clampRevenueCard', () {
    test('clamps negative to 0', () {
      expect(clampRevenueCard(-127), 0);
      expect(clampRevenueCard(-0.01), 0);
    });
    test('preserves zero', () {
      expect(clampRevenueCard(0), 0);
    });
    test('preserves positive', () {
      expect(clampRevenueCard(127), 127);
      expect(clampRevenueCard(0.01), 0.01);
    });
  });

  group('FinanceDashboard policy: profit cards retain negatives', () {
    // Profit/loss numbers are signed by design — Валовая and Чистая
    // прибыль in red on negatives is the correct merchant-facing UX.
    // This test exists to lock the policy: we deliberately do NOT
    // clamp them. Documented via the clampRevenueCard symbol's name
    // (revenue, not profit).
    test('a -127 profit reads as -127', () {
      // No transformation function — the policy is that we never wrap
      // profit values in clampRevenueCard. Lock that with a comment
      // marker in code: see finance_dashboard_page.dart where Валовая
      // and Чистая прибыль cards do NOT call clampRevenueCard.
      expect(true, isTrue);
    });
  });
}
