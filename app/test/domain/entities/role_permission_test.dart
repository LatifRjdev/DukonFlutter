import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/role_permission.dart';

void main() {
  group('RolePermission.fromJson', () {
    test('parses role and permissions map from a well-formed payload', () {
      final role = RolePermission.fromJson({
        'role': 'CASHIER',
        'permissions': {
          'canViewSales': true,
          'canEditProducts': false,
        },
      });

      expect(role.role, 'CASHIER');
      expect(role.permissions, {
        'canViewSales': true,
        'canEditProducts': false,
      });
    });

    test('parses an empty permissions map without crashing', () {
      final role = RolePermission.fromJson({
        'role': 'OWNER',
        'permissions': <String, dynamic>{},
      });

      expect(role.role, 'OWNER');
      expect(role.permissions, isEmpty);
    });

    test('throws a TypeError when role is missing', () {
      expect(
        () => RolePermission.fromJson({
          'permissions': {'canViewSales': true},
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws a TypeError when permissions is missing', () {
      expect(
        () => RolePermission.fromJson({'role': 'ADMIN'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws a TypeError when a permission value is not a bool', () {
      // Backend occasionally serializes booleans as 0/1 or strings — this
      // parser does a direct `as bool` cast per entry, so anything else
      // should surface as a TypeError rather than silently coercing.
      expect(
        () => RolePermission.fromJson({
          'role': 'ADMIN',
          'permissions': {'canViewSales': 1},
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('RolePermission equality', () {
    test('two instances with the same role and permissions are equal', () {
      const a = RolePermission(
        role: 'CASHIER',
        permissions: {'canViewSales': true},
      );
      const b = RolePermission(
        role: 'CASHIER',
        permissions: {'canViewSales': true},
      );

      expect(a, equals(b));
    });

    test('instances with different permission values are not equal', () {
      const a = RolePermission(
        role: 'CASHIER',
        permissions: {'canViewSales': true},
      );
      const b = RolePermission(
        role: 'CASHIER',
        permissions: {'canViewSales': false},
      );

      expect(a, isNot(equals(b)));
    });

    test('instances with different roles are not equal', () {
      const a = RolePermission(role: 'CASHIER', permissions: {});
      const b = RolePermission(role: 'ADMIN', permissions: {});

      expect(a, isNot(equals(b)));
    });
  });
}
