import 'package:flutter_test/flutter_test.dart';

import 'package:dokonpro/domain/entities/payroll_entry.dart';

// Regression tests for FD-P0-003 — the payroll detail response returns
// staff identity under `staff.user.*` but the original parser cast
// `staffName` as non-nullable String and crashed the whole screen after
// the Рассчитать button.

void main() {
  group('PayrollEntry.fromJson', () {
    test('accepts nested staff.user.* shape from the backend', () {
      final row = PayrollEntry.fromJson({
        'id': 'p1',
        'staff': {
          'id': 'staff-1',
          'role': 'CASHIER',
          'user': {'name': 'Ali', 'avatar': null},
        },
      });

      expect(row.id, 'p1');
      expect(row.staffId, 'staff-1');
      expect(row.staffName, 'Ali');
      expect(row.staffRole, 'CASHIER');
      expect(row.baseSalary, 0);
      expect(row.isPaid, isFalse);
    });

    test('accepts flat shape (future backend flattening)', () {
      final row = PayrollEntry.fromJson({
        'id': 'p2',
        'staffId': 's2',
        'staffName': 'Bek',
        'staffRole': 'ADMIN',
        'staffAvatar': 'https://example.com/a.png',
        'baseSalary': 2000,
        'totalAmount': 2500,
        'isPaid': true,
      });

      expect(row.staffName, 'Bek');
      expect(row.staffRole, 'ADMIN');
      expect(row.staffAvatar, 'https://example.com/a.png');
      expect(row.baseSalary, 2000);
      expect(row.totalAmount, 2500);
      expect(row.isPaid, isTrue);
    });

    test('staffName falls back to empty string, not a crash', () {
      final row = PayrollEntry.fromJson({
        'id': 'p3',
      });

      expect(row.id, 'p3');
      expect(row.staffName, '');
      expect(row.staffRole, isNull);
    });

    test('parses adjustments list when present', () {
      final row = PayrollEntry.fromJson({
        'id': 'p4',
        'staff': {'id': 's4', 'user': {'name': 'Gulnora'}},
        'adjustments': [
          {
            'id': 'a1',
            'type': 'BONUS',
            'amount': 100,
            'description': 'Extra hours',
          },
        ],
      });

      expect(row.adjustments, hasLength(1));
      expect(row.adjustments.first.type, 'BONUS');
      expect(row.adjustments.first.amount, 100);
    });
  });
}
