import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/customer.dart';

void main() {
  group('Customer', () {
    test('applies default values for optional financial/status fields', () {
      const customer = Customer(id: 'c1', storeId: 'store-1', name: 'Ali');

      expect(customer.phone, isNull);
      expect(customer.email, isNull);
      expect(customer.birthday, isNull);
      expect(customer.notes, isNull);
      expect(customer.loyaltyPoints, 0);
      expect(customer.totalSpent, 0);
      expect(customer.debt, 0);
      expect(customer.isActive, isTrue);
      expect(customer.telegramChatId, isNull);
    });

    test(
        'two customers are equal when id/storeId/name/phone/debt match, '
        'even if other fields differ (Equatable props are a narrow subset)',
        () {
      const a = Customer(
        id: 'c1',
        storeId: 'store-1',
        name: 'Ali',
        phone: '+992900000000',
        debt: 100,
        email: 'ali@example.com',
        notes: 'VIP',
        loyaltyPoints: 50,
        totalSpent: 999,
        isActive: false,
        telegramChatId: 'tg-1',
      );
      const b = Customer(
        id: 'c1',
        storeId: 'store-1',
        name: 'Ali',
        phone: '+992900000000',
        debt: 100,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should not be equal when debt differs', () {
      const a = Customer(id: 'c1', storeId: 'store-1', name: 'Ali', debt: 100);
      const b = Customer(id: 'c1', storeId: 'store-1', name: 'Ali', debt: 50);

      expect(a, isNot(b));
    });

    test('should not be equal when id differs', () {
      const a = Customer(id: 'c1', storeId: 'store-1', name: 'Ali');
      const b = Customer(id: 'c2', storeId: 'store-1', name: 'Ali');

      expect(a, isNot(b));
    });
  });
}
