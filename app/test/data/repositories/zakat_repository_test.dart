import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/zakat_remote_datasource.dart';
import 'package:dukonpro/data/repositories/zakat_repository_impl.dart';
import 'package:dukonpro/domain/entities/zakat_calculation.dart';
import 'package:dukonpro/domain/entities/zakat_payment.dart';
import 'package:dukonpro/domain/entities/zakat_settings.dart';

// ZakatRepositoryImpl has no offline/sync-queue behavior — it is a thin
// pass-through to ZakatRemoteDatasource. Per the "remove client zakatDue
// validation" fix, the repository must never re-validate or recompute the
// server-calculated amounts; these tests assert values and payloads flow
// through unmodified in both directions.
class _MockZakatRemoteDatasource extends Mock implements ZakatRemoteDatasource {}

void main() {
  late _MockZakatRemoteDatasource datasource;
  late ZakatRepositoryImpl repo;

  setUp(() {
    datasource = _MockZakatRemoteDatasource();
    repo = ZakatRepositoryImpl(remoteDatasource: datasource);
  });

  const calculation = ZakatCalculation(
    stockValue: 5000,
    receivables: 300,
    payables: 100,
    netAssets: 5200,
    nisabAmount: 4000,
    zakatDue: 130.5,
    isAboveNisab: true,
  );

  final settings = ZakatSettings(
    id: 'zs-1',
    storeId: 'store-1',
    nisabAmount: 4000,
    cashOnHand: 200,
  );

  final payment = ZakatPayment(
    id: 'zp-1',
    storeId: 'store-1',
    amount: 130.5,
    totalAssets: 5200,
    zakatDue: 130.5,
    breakdown: const {},
    paidAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  group('ZakatRepositoryImpl.calculate', () {
    test('returns the datasource result unmodified, including zakatDue',
        () async {
      when(() => datasource.calculate('store-1'))
          .thenAnswer((_) async => calculation);

      final result = await repo.calculate('store-1');

      expect(result, same(calculation));
      expect(result.zakatDue, 130.5);
      verify(() => datasource.calculate('store-1')).called(1);
    });

    test('propagates exceptions thrown by the datasource unchanged',
        () async {
      when(() => datasource.calculate('store-1'))
          .thenThrow(const NetworkException());

      expect(
        () => repo.calculate('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('ZakatRepositoryImpl.getSettings', () {
    test('returns the datasource result unmodified', () async {
      when(() => datasource.getSettings('store-1'))
          .thenAnswer((_) async => settings);

      final result = await repo.getSettings('store-1');

      expect(result, same(settings));
    });

    test('returns null when the datasource returns null', () async {
      when(() => datasource.getSettings('store-1'))
          .thenAnswer((_) async => null);

      final result = await repo.getSettings('store-1');

      expect(result, isNull);
    });
  });

  group('ZakatRepositoryImpl.upsertSettings', () {
    test('forwards the caller-supplied data unmodified', () async {
      final input = {'cashOnHand': 50};
      when(() => datasource.upsertSettings('store-1', input))
          .thenAnswer((_) async => settings);

      final result = await repo.upsertSettings('store-1', input);

      expect(result, same(settings));
      final captured = verify(() => datasource.upsertSettings(
            'store-1',
            captureAny(),
          )).captured;
      expect(captured.single, same(input));
    });

    test('propagates a ServerException from the datasource', () async {
      when(() => datasource.upsertSettings('store-1', any()))
          .thenThrow(const ServerException('bad', statusCode: 400));

      expect(
        () => repo.upsertSettings('store-1', {'cashOnHand': -1}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ZakatRepositoryImpl.getPayments', () {
    test('forwards page and limit, defaulting when not provided', () async {
      final page = (
        data: <ZakatPayment>[payment],
        total: 1,
        totalPages: 1,
        currentPage: 1,
      );
      when(() => datasource.getPayments(
            'store-1',
            page: 1,
            limit: 20,
          )).thenAnswer((_) async => page);

      final result = await repo.getPayments('store-1');

      expect(result.data.single, same(payment));
      verify(() => datasource.getPayments('store-1', page: 1, limit: 20))
          .called(1);
    });

    test('forwards explicit page and limit values', () async {
      final page = (
        data: <ZakatPayment>[],
        total: 0,
        totalPages: 1,
        currentPage: 3,
      );
      when(() => datasource.getPayments(
            'store-1',
            page: 3,
            limit: 5,
          )).thenAnswer((_) async => page);

      await repo.getPayments('store-1', page: 3, limit: 5);

      verify(() => datasource.getPayments('store-1', page: 3, limit: 5))
          .called(1);
    });
  });

  group('ZakatRepositoryImpl.createPayment', () {
    test(
        'forwards the caller-supplied data unmodified and returns the '
        'server-calculated payment untouched', () async {
      final input = {'amount': 130.5};
      when(() => datasource.createPayment('store-1', input))
          .thenAnswer((_) async => payment);

      final result = await repo.createPayment('store-1', input);

      expect(result, same(payment));
      expect(result.zakatDue, 130.5);
      final captured = verify(() => datasource.createPayment(
            'store-1',
            captureAny(),
          )).captured;
      expect(captured.single, same(input));
    });

    test('propagates exceptions thrown by the datasource unchanged',
        () async {
      when(() => datasource.createPayment('store-1', any()))
          .thenThrow(const NetworkException());

      expect(
        () => repo.createPayment('store-1', {'amount': 10}),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
