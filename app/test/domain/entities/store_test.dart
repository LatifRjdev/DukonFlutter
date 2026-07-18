import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/store.dart';

void main() {
  group('Store', () {
    test('applies default values for currency, settings and isActive', () {
      final store = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(store.currency, 'TJS');
      expect(store.settings, isEmpty);
      expect(store.isActive, isTrue);
      expect(store.address, isNull);
      expect(store.phone, isNull);
      expect(store.logoUrl, isNull);
    });

    test('retains explicitly provided values instead of defaults', () {
      final store = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        currency: 'USD',
        address: 'Main St 1',
        phone: '+992900000000',
        logoUrl: 'https://example.com/logo.png',
        settings: const {'receiptFooter': 'Thanks!'},
        isActive: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(store.currency, 'USD');
      expect(store.address, 'Main St 1');
      expect(store.phone, '+992900000000');
      expect(store.logoUrl, 'https://example.com/logo.png');
      expect(store.settings, {'receiptFooter': 'Thanks!'});
      expect(store.isActive, isFalse);
    });

    test('two stores are equal when all props fields match', () {
      final a = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );
      final b = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(a, equals(b));
    });

    test(
        'stores with different createdAt/settings are still equal — '
        'those fields are excluded from props (documents current entity '
        'equality behavior)', () {
      final a = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        settings: const {'a': 1},
        createdAt: DateTime(2026, 1, 1),
      );
      final b = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        settings: const {'a': 2},
        createdAt: DateTime(2026, 6, 1),
      );

      expect(a, equals(b));
    });

    test('stores with different id are not equal', () {
      final a = Store(
        id: 's1',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );
      final b = Store(
        id: 's2',
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(a, isNot(equals(b)));
    });
  });
}
