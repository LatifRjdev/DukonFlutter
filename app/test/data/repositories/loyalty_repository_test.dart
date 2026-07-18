import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/data/datasources/remote/loyalty_remote_datasource.dart';
import 'package:dukonpro/data/repositories/loyalty_repository_impl.dart';
import 'package:dukonpro/domain/entities/loyalty_analytics.dart';
import 'package:dukonpro/domain/entities/loyalty_transaction.dart';

class MockLoyaltyRemoteDatasource extends Mock
    implements LoyaltyRemoteDatasource {}

void main() {
  late MockLoyaltyRemoteDatasource remote;
  late LoyaltyRepositoryImpl repo;

  setUp(() {
    remote = MockLoyaltyRemoteDatasource();
    repo = LoyaltyRepositoryImpl(remote: remote);
  });

  group('LoyaltyRepositoryImpl.getSettings', () {
    test('delegates to the remote datasource and returns its result',
        () async {
      when(() => remote.getSettings('store-1'))
          .thenAnswer((_) async => {'enabled': true});

      final result = await repo.getSettings('store-1');

      expect(result, {'enabled': true});
      verify(() => remote.getSettings('store-1')).called(1);
    });

    test('propagates exceptions thrown by the datasource', () async {
      when(() => remote.getSettings('store-1'))
          .thenThrow(Exception('boom'));

      expect(() => repo.getSettings('store-1'), throwsA(isA<Exception>()));
    });
  });

  group('LoyaltyRepositoryImpl.updateSettings', () {
    test('forwards storeId and data to the remote datasource', () async {
      when(() => remote.updateSettings('store-1', {'enabled': false}))
          .thenAnswer((_) async => {'enabled': false});

      final result =
          await repo.updateSettings('store-1', {'enabled': false});

      expect(result, {'enabled': false});
      verify(() => remote.updateSettings('store-1', {'enabled': false}))
          .called(1);
    });

    test('propagates exceptions thrown by the datasource', () async {
      when(() => remote.updateSettings(any(), any()))
          .thenThrow(Exception('boom'));

      expect(
        () => repo.updateSettings('store-1', {'enabled': false}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('LoyaltyRepositoryImpl.getCustomerBalance', () {
    test('forwards storeId and customerId and returns the balance record',
        () async {
      final tx = LoyaltyTransaction(
        id: 'tx-1',
        customerId: 'cust-1',
        storeId: 'store-1',
        type: 'EARN',
        points: 10,
        createdAt: DateTime(2026, 7, 1),
      );
      when(() => remote.getCustomerBalance('store-1', 'cust-1'))
          .thenAnswer((_) async => (points: 10, transactions: [tx]));

      final result = await repo.getCustomerBalance('store-1', 'cust-1');

      expect(result.points, 10);
      expect(result.transactions, [tx]);
      verify(() => remote.getCustomerBalance('store-1', 'cust-1')).called(1);
    });

    test('propagates exceptions thrown by the datasource', () async {
      when(() => remote.getCustomerBalance(any(), any()))
          .thenThrow(Exception('boom'));

      expect(
        () => repo.getCustomerBalance('store-1', 'cust-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('LoyaltyRepositoryImpl.getAnalytics', () {
    test('forwards storeId, from and to and returns the analytics',
        () async {
      final from = DateTime(2026, 7, 1);
      final to = DateTime(2026, 7, 9);
      final analytics = LoyaltyAnalytics(
        from: from,
        to: to,
        totalEarned: 1000,
        totalRedeemed: 200,
        totalExpired: 50,
        discountValue: 20.0,
        activeParticipants: 5,
        topCustomers: const [],
      );
      when(() => remote.getAnalytics('store-1', from, to))
          .thenAnswer((_) async => analytics);

      final result = await repo.getAnalytics('store-1', from, to);

      expect(result, analytics);
      verify(() => remote.getAnalytics('store-1', from, to)).called(1);
    });

    test('propagates exceptions thrown by the datasource', () async {
      final from = DateTime(2026, 7, 1);
      final to = DateTime(2026, 7, 9);
      when(() => remote.getAnalytics(any(), any(), any()))
          .thenThrow(Exception('boom'));

      expect(
        () => repo.getAnalytics('store-1', from, to),
        throwsA(isA<Exception>()),
      );
    });
  });
}
