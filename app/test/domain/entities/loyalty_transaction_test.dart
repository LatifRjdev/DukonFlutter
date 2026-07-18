import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/loyalty_transaction.dart';

void main() {
  group('LoyaltyTransaction.fromJson', () {
    test('parses a full EARN transaction with all fields present', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-1',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'EARN',
        'points': 50,
        'saleId': 'sale-1',
        'expiresAt': '2026-12-31T00:00:00.000Z',
        'createdAt': '2026-07-01T10:00:00.000Z',
      });

      expect(tx.id, 'tx-1');
      expect(tx.customerId, 'cust-1');
      expect(tx.storeId, 'store-1');
      expect(tx.type, 'EARN');
      expect(tx.points, 50);
      expect(tx.saleId, 'sale-1');
      expect(tx.expiresAt, DateTime.parse('2026-12-31T00:00:00.000Z'));
      expect(tx.createdAt, DateTime.parse('2026-07-01T10:00:00.000Z'));
    });

    test('parses a REDEEM transaction with negative points', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-2',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'REDEEM',
        'points': -30,
        'createdAt': '2026-07-02T10:00:00.000Z',
      });

      expect(tx.type, 'REDEEM');
      expect(tx.points, -30);
    });

    test('defaults saleId to null when absent', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-3',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'ADJUST',
        'points': 10,
        'createdAt': '2026-07-03T10:00:00.000Z',
      });

      expect(tx.saleId, isNull);
    });

    test('defaults saleId to null when explicitly null in JSON', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-4',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'EXPIRE',
        'points': -5,
        'saleId': null,
        'createdAt': '2026-07-04T10:00:00.000Z',
      });

      expect(tx.saleId, isNull);
    });

    test('defaults expiresAt to null when absent', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-5',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'EARN',
        'points': 20,
        'createdAt': '2026-07-05T10:00:00.000Z',
      });

      expect(tx.expiresAt, isNull);
    });

    test('defaults expiresAt to null when explicitly null in JSON', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-6',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'EARN',
        'points': 20,
        'expiresAt': null,
        'createdAt': '2026-07-06T10:00:00.000Z',
      });

      expect(tx.expiresAt, isNull);
    });

    test('parses an EXPIRE transaction', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-7',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'EXPIRE',
        'points': -15,
        'createdAt': '2026-07-07T10:00:00.000Z',
      });

      expect(tx.type, 'EXPIRE');
      expect(tx.points, -15);
    });

    test('parses an ADJUST transaction', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-8',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'ADJUST',
        'points': 100,
        'createdAt': '2026-07-08T10:00:00.000Z',
      });

      expect(tx.type, 'ADJUST');
      expect(tx.points, 100);
    });

    test('converts points expressed as a double to an int', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-9',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'EARN',
        'points': 12.0,
        'createdAt': '2026-07-09T10:00:00.000Z',
      });

      expect(tx.points, 12);
      expect(tx.points, isA<int>());
    });

    test('handles zero points', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-10',
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': 'ADJUST',
        'points': 0,
        'createdAt': '2026-07-10T10:00:00.000Z',
      });

      expect(tx.points, 0);
    });
  });
}
