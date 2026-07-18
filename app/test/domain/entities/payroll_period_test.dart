import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/payroll_period.dart';

void main() {
  group('PayrollPeriod.fromJson', () {
    test('parses a fully populated period with nested payrolls', () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-1',
        'month': 5,
        'year': 2026,
        'status': 'CALCULATED',
        'totalAmount': 5000,
        'paidAmount': 2000,
        'staffCount': 3,
        'payrolls': [
          {
            'id': 'p1',
            'staffId': 's1',
            'staffName': 'Ali',
            'totalAmount': 1500,
          },
        ],
      });

      expect(period.id, 'period-1');
      expect(period.month, 5);
      expect(period.year, 2026);
      expect(period.status, 'CALCULATED');
      expect(period.totalAmount, 5000.0);
      expect(period.paidAmount, 2000.0);
      expect(period.staffCount, 3);
      expect(period.payrolls, hasLength(1));
      expect(period.payrolls.first.staffName, 'Ali');
    });

    test('required fields only: defaults totalAmount/paidAmount/staffCount to 0 and payrolls to empty',
        () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-2',
        'month': 6,
        'year': 2026,
        'status': 'PENDING',
      });

      expect(period.totalAmount, 0);
      expect(period.paidAmount, 0);
      expect(period.staffCount, 0);
      expect(period.payrolls, isEmpty);
    });

    test('payrolls key explicitly null falls back to an empty list', () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-3',
        'month': 1,
        'year': 2026,
        'status': 'PENDING',
        'payrolls': null,
      });

      expect(period.payrolls, isEmpty);
    });

    test('totalAmount can be zero for a freshly-calculated empty period', () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-4',
        'month': 2,
        'year': 2026,
        'status': 'CALCULATED',
        'totalAmount': 0,
        'paidAmount': 0,
      });

      expect(period.totalAmount, 0.0);
      expect(period.paidAmount, 0.0);
    });

    test('coerces integer totalAmount/paidAmount JSON values to double', () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-5',
        'month': 3,
        'year': 2026,
        'status': 'PAID',
        'totalAmount': 10000,
        'paidAmount': 10000,
      });

      expect(period.totalAmount, isA<double>());
      expect(period.totalAmount, 10000.0);
      expect(period.paidAmount, 10000.0);
    });

    test('preserves fractional precision on totalAmount/paidAmount', () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-6',
        'month': 4,
        'year': 2026,
        'status': 'PAID',
        'totalAmount': 1234.56,
        'paidAmount': 1234.56,
      });

      expect(period.totalAmount, 1234.56);
      expect(period.paidAmount, 1234.56);
    });

    test('parses multiple payroll entries and keeps their order', () {
      final period = PayrollPeriod.fromJson({
        'id': 'period-7',
        'month': 5,
        'year': 2026,
        'status': 'CALCULATED',
        'payrolls': [
          {'id': 'p1', 'staffName': 'Ali', 'totalAmount': 100},
          {'id': 'p2', 'staffName': 'Bek', 'totalAmount': 200},
        ],
      });

      expect(period.payrolls.map((p) => p.staffName), ['Ali', 'Bek']);
    });

    test('equatable props consider two periods with identical core fields equal',
        () {
      final a = PayrollPeriod.fromJson({
        'id': 'period-8',
        'month': 5,
        'year': 2026,
        'status': 'PAID',
        'totalAmount': 100,
      });
      final b = PayrollPeriod.fromJson({
        'id': 'period-8',
        'month': 5,
        'year': 2026,
        'status': 'PAID',
        'totalAmount': 100,
      });

      expect(a, b);
    });
  });
}
