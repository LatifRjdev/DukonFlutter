import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/payroll_adjustment.dart';

void main() {
  group('PayrollAdjustment.fromJson', () {
    test('parses a BONUS adjustment with all fields present', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a1',
        'type': 'BONUS',
        'amount': 150.5,
        'description': 'Overtime bonus',
        'date': '2026-05-11T00:00:00.000Z',
      });

      expect(adj.id, 'a1');
      expect(adj.type, 'BONUS');
      expect(adj.amount, 150.5);
      expect(adj.description, 'Overtime bonus');
      expect(adj.date, DateTime.parse('2026-05-11T00:00:00.000Z'));
    });

    test('parses a DEDUCTION adjustment with a negative amount', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a2',
        'type': 'DEDUCTION',
        'amount': -75,
        'description': 'Late penalty',
      });

      expect(adj.type, 'DEDUCTION');
      expect(adj.amount, -75.0);
    });

    test('treats a zero amount as a valid double, not a missing value', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a3',
        'type': 'BONUS',
        'amount': 0,
        'description': 'No-op adjustment',
      });

      expect(adj.amount, 0.0);
    });

    test('coerces an integer JSON amount to double without rounding', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a4',
        'type': 'BONUS',
        'amount': 1500,
        'description': 'Round number bonus',
      });

      expect(adj.amount, isA<double>());
      expect(adj.amount, 1500.0);
    });

    test('preserves fractional precision for a decimal amount', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a5',
        'type': 'DEDUCTION',
        'amount': -99.99,
        'description': 'Equipment fee',
      });

      expect(adj.amount, -99.99);
    });

    test('date is null when the date key is absent', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a6',
        'type': 'BONUS',
        'amount': 50,
        'description': 'No date bonus',
      });

      expect(adj.date, isNull);
    });

    test('date is null when the date key is explicitly null', () {
      final adj = PayrollAdjustment.fromJson({
        'id': 'a7',
        'type': 'BONUS',
        'amount': 50,
        'description': 'Explicit null date',
        'date': null,
      });

      expect(adj.date, isNull);
    });

    test('equatable props consider two adjustments with identical fields equal', () {
      final a = PayrollAdjustment.fromJson({
        'id': 'a8',
        'type': 'BONUS',
        'amount': 10,
        'description': 'x',
      });
      final b = PayrollAdjustment.fromJson({
        'id': 'a8',
        'type': 'BONUS',
        'amount': 10,
        'description': 'x',
      });

      expect(a, b);
    });
  });
}
