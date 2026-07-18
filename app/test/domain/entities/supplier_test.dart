import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/supplier.dart';

void main() {
  group('Supplier', () {
    test('two suppliers with same id/storeId/name/phone/debt are equal', () {
      const a = Supplier(
        id: 's1',
        storeId: 'store-1',
        name: 'ACME',
        phone: '+992900000000',
        debt: 100,
      );
      const b = Supplier(
        id: 's1',
        storeId: 'store-1',
        name: 'ACME',
        phone: '+992900000000',
        debt: 100,
        // email/address/notes differ but are excluded from props, so
        // equality should still hold.
        email: 'different@example.com',
        address: 'different address',
        notes: 'different notes',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('suppliers with different id are not equal', () {
      const a = Supplier(id: 's1', storeId: 'store-1', name: 'ACME');
      const b = Supplier(id: 's2', storeId: 'store-1', name: 'ACME');

      expect(a, isNot(equals(b)));
    });

    test('suppliers with different debt are not equal', () {
      const a = Supplier(id: 's1', storeId: 'store-1', name: 'ACME', debt: 10);
      const b = Supplier(id: 's1', storeId: 'store-1', name: 'ACME', debt: 20);

      expect(a, isNot(equals(b)));
    });

    test('debt defaults to 0 when not provided', () {
      const supplier = Supplier(id: 's1', storeId: 'store-1', name: 'ACME');
      expect(supplier.debt, 0);
    });

    test('optional fields default to null when not provided', () {
      const supplier = Supplier(id: 's1', storeId: 'store-1', name: 'ACME');
      expect(supplier.phone, isNull);
      expect(supplier.email, isNull);
      expect(supplier.address, isNull);
      expect(supplier.notes, isNull);
    });
  });
}
