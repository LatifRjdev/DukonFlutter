import 'package:flutter_test/flutter_test.dart';

import 'package:dokonpro/domain/entities/staff_member.dart';

// Regression tests for the FD-P0-002 crash chain: the backend returns
// staff rows with identity fields under `user.*` not flat top-level
// keys, and a prior version of this parser cast them to non-nullable
// String and crashed the whole list screen.

void main() {
  group('StaffMember.fromJson', () {
    test('accepts nested user.* shape from the backend', () {
      final row = StaffMember.fromJson({
        'id': 'staff-1',
        'storeId': 'store-1',
        'role': 'OWNER',
        'createdAt': '2026-04-11T10:00:00Z',
        'user': {
          'id': 'user-1',
          'name': 'Ali',
          'phone': '+992900000000',
          'avatar': null,
        },
      });

      expect(row.id, 'staff-1');
      expect(row.userId, 'user-1');
      expect(row.name, 'Ali');
      expect(row.phone, '+992900000000');
      expect(row.role, 'OWNER');
    });

    test('accepts flat shape (future backend flattening)', () {
      final row = StaffMember.fromJson({
        'id': 's2',
        'storeId': 'store-1',
        'userId': 'u2',
        'name': 'Bek',
        'phone': '+992911111111',
        'role': 'CASHIER',
        'createdAt': '2026-04-11T10:00:00Z',
      });

      expect(row.name, 'Bek');
      expect(row.role, 'CASHIER');
    });

    test('falls back to empty string for missing required fields (no crash)',
        () {
      final row = StaffMember.fromJson({
        'id': 's3',
        'storeId': 'store-1',
        'createdAt': '2026-04-11T10:00:00Z',
      });

      expect(row.name, isEmpty);
      expect(row.role, isEmpty);
      expect(row.phone, isNull);
      expect(row.avatar, isNull);
    });

    test('reads todaySalesTotal when todaySales is absent', () {
      final row = StaffMember.fromJson({
        'id': 's4',
        'storeId': 'store-1',
        'role': 'CASHIER',
        'createdAt': '2026-04-11T10:00:00Z',
        'user': {'id': 'u4', 'name': 'Gulnora'},
        'todaySalesTotal': 123.45,
      });

      expect(row.todaySales, 123.45);
    });

    test('isActive defaults to true when absent', () {
      final row = StaffMember.fromJson({
        'id': 's5',
        'storeId': 'store-1',
        'role': 'ADMIN',
        'createdAt': '2026-04-11T10:00:00Z',
        'user': {'id': 'u5', 'name': 'N'},
      });

      expect(row.isActive, isTrue);
    });
  });
}
