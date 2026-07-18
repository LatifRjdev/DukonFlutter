import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/investment.dart';

void main() {
  Investment buildInvestment({
    String id = 'inv-1',
    String storeId = 'store-1',
    String name = 'New shop equipment',
    String? description,
    double amount = 5000,
    double? returnAmount,
    String investorName = 'Ali',
    String? investorPhone,
    String status = 'ACTIVE',
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) =>
      Investment(
        id: id,
        storeId: storeId,
        name: name,
        description: description,
        amount: amount,
        returnAmount: returnAmount,
        investorName: investorName,
        investorPhone: investorPhone,
        status: status,
        startDate: startDate ?? DateTime.utc(2026, 1, 1),
        endDate: endDate,
        createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      );

  group('Investment', () {
    test('exposes all constructor fields', () {
      final startDate = DateTime.utc(2026, 1, 1);
      final endDate = DateTime.utc(2026, 6, 1);
      final createdAt = DateTime.utc(2026, 1, 2);
      final investment = Investment(
        id: 'inv-1',
        storeId: 'store-1',
        name: 'New shop equipment',
        description: 'Refrigeration unit',
        amount: 5000,
        returnAmount: 5500,
        investorName: 'Ali',
        investorPhone: '+992900000000',
        status: 'ACTIVE',
        startDate: startDate,
        endDate: endDate,
        createdAt: createdAt,
      );

      expect(investment.id, 'inv-1');
      expect(investment.storeId, 'store-1');
      expect(investment.name, 'New shop equipment');
      expect(investment.description, 'Refrigeration unit');
      expect(investment.amount, 5000);
      expect(investment.returnAmount, 5500);
      expect(investment.investorName, 'Ali');
      expect(investment.investorPhone, '+992900000000');
      expect(investment.status, 'ACTIVE');
      expect(investment.startDate, startDate);
      expect(investment.endDate, endDate);
      expect(investment.createdAt, createdAt);
    });

    test('optional fields default to null when not provided', () {
      final investment = Investment(
        id: 'inv-1',
        storeId: 'store-1',
        name: 'New shop equipment',
        amount: 5000,
        investorName: 'Ali',
        status: 'ACTIVE',
        startDate: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(investment.description, isNull);
      expect(investment.returnAmount, isNull);
      expect(investment.investorPhone, isNull);
      expect(investment.endDate, isNull);
    });

    test('two instances with identical id/storeId/name/amount/status are '
        'equal (Equatable compares props only)', () {
      final a = buildInvestment();
      final b = buildInvestment();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing only in fields outside props are still '
        'considered equal — description/investorName/investorPhone/'
        'returnAmount/dates are NOT part of equality', () {
      final a = buildInvestment(
        description: 'Refrigeration unit',
        investorName: 'Ali',
        investorPhone: '+992900000000',
        returnAmount: 5500,
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final b = buildInvestment(
        description: 'Completely different description',
        investorName: 'Bek',
        investorPhone: '+992911111111',
        returnAmount: 9999,
        startDate: DateTime.utc(2020, 5, 5),
        endDate: DateTime.utc(2021, 5, 5),
        createdAt: DateTime.utc(2020, 5, 5),
      );

      expect(a, equals(b));
    });

    test('instances differ when id differs', () {
      final a = buildInvestment(id: 'inv-1');
      final b = buildInvestment(id: 'inv-2');

      expect(a, isNot(equals(b)));
    });

    test('instances differ when storeId differs', () {
      final a = buildInvestment(storeId: 'store-1');
      final b = buildInvestment(storeId: 'store-2');

      expect(a, isNot(equals(b)));
    });

    test('instances differ when name differs', () {
      final a = buildInvestment(name: 'Equipment A');
      final b = buildInvestment(name: 'Equipment B');

      expect(a, isNot(equals(b)));
    });

    test('instances differ when amount differs', () {
      final a = buildInvestment(amount: 100);
      final b = buildInvestment(amount: 200);

      expect(a, isNot(equals(b)));
    });

    test('instances differ when status differs', () {
      final a = buildInvestment(status: 'ACTIVE');
      final b = buildInvestment(status: 'COMPLETED');

      expect(a, isNot(equals(b)));
    });

    test('props contains exactly id, storeId, name, amount, status', () {
      final investment = buildInvestment();

      expect(investment.props, [
        investment.id,
        investment.storeId,
        investment.name,
        investment.amount,
        investment.status,
      ]);
      expect(investment.props.length, 5);
    });
  });

  group('InvestmentSummary', () {
    const summary = InvestmentSummary(
      totalAmount: 6200,
      totalCount: 2,
      activeAmount: 5000,
      activeCount: 1,
      completedAmount: 1200,
      completedReturnAmount: 1400,
      completedCount: 1,
    );

    test('exposes all constructor fields', () {
      expect(summary.totalAmount, 6200);
      expect(summary.totalCount, 2);
      expect(summary.activeAmount, 5000);
      expect(summary.activeCount, 1);
      expect(summary.completedAmount, 1200);
      expect(summary.completedReturnAmount, 1400);
      expect(summary.completedCount, 1);
    });

    test('two instances with identical totalAmount/totalCount/activeCount '
        'are equal (Equatable compares props only)', () {
      const a = InvestmentSummary(
        totalAmount: 6200,
        totalCount: 2,
        activeAmount: 5000,
        activeCount: 1,
        completedAmount: 1200,
        completedReturnAmount: 1400,
        completedCount: 1,
      );
      const b = InvestmentSummary(
        totalAmount: 6200,
        totalCount: 2,
        // Deliberately different values for fields NOT in props.
        activeAmount: 999,
        activeCount: 1,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );

      expect(a, equals(b));
    });

    test('instances differ when totalAmount differs', () {
      const a = InvestmentSummary(
        totalAmount: 100,
        totalCount: 1,
        activeAmount: 0,
        activeCount: 0,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );
      const b = InvestmentSummary(
        totalAmount: 200,
        totalCount: 1,
        activeAmount: 0,
        activeCount: 0,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );

      expect(a, isNot(equals(b)));
    });

    test('instances differ when totalCount differs', () {
      const a = InvestmentSummary(
        totalAmount: 100,
        totalCount: 1,
        activeAmount: 0,
        activeCount: 0,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );
      const b = InvestmentSummary(
        totalAmount: 100,
        totalCount: 2,
        activeAmount: 0,
        activeCount: 0,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );

      expect(a, isNot(equals(b)));
    });

    test('instances differ when activeCount differs', () {
      const a = InvestmentSummary(
        totalAmount: 100,
        totalCount: 1,
        activeAmount: 0,
        activeCount: 0,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );
      const b = InvestmentSummary(
        totalAmount: 100,
        totalCount: 1,
        activeAmount: 0,
        activeCount: 1,
        completedAmount: 0,
        completedReturnAmount: 0,
        completedCount: 0,
      );

      expect(a, isNot(equals(b)));
    });

    test('props contains exactly totalAmount, totalCount, activeCount', () {
      expect(summary.props, [
        summary.totalAmount,
        summary.totalCount,
        summary.activeCount,
      ]);
      expect(summary.props.length, 3);
    });
  });
}
