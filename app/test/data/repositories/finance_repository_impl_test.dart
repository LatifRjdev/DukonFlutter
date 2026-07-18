import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/finance_remote_datasource.dart';
import 'package:dukonpro/data/repositories/finance_repository_impl.dart';
import 'package:dukonpro/domain/entities/finance_summary.dart';

class MockFinanceRemoteDatasource extends Mock
    implements FinanceRemoteDatasource {}

void main() {
  late MockFinanceRemoteDatasource remoteDatasource;
  late FinanceRepositoryImpl repo;

  const summary = FinanceSummary(
    totalIncome: 100,
    totalExpenses: 40,
    profit: 60,
    salesCount: 5,
    avgCheck: 20,
  );

  setUp(() {
    remoteDatasource = MockFinanceRemoteDatasource();
    repo = FinanceRepositoryImpl(remoteDatasource: remoteDatasource);
  });

  group('FinanceRepositoryImpl.getDashboard', () {
    test('delegates to remote datasource and returns its result', () async {
      when(() => remoteDatasource.getDashboard(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => summary);

      final result = await repo.getDashboard('store-1');

      expect(result, summary);
      verify(() => remoteDatasource.getDashboard(
            'store-1',
            startDate: null,
            endDate: null,
          )).called(1);
    });

    test('forwards startDate/endDate through to the remote datasource',
        () async {
      final start = DateTime.utc(2026, 1, 1);
      final end = DateTime.utc(2026, 1, 31);
      when(() => remoteDatasource.getDashboard(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => summary);

      await repo.getDashboard('store-1', startDate: start, endDate: end);

      verify(() => remoteDatasource.getDashboard(
            'store-1',
            startDate: start,
            endDate: end,
          )).called(1);
    });

    test('propagates exceptions thrown by the remote datasource', () async {
      when(() => remoteDatasource.getDashboard(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(const NetworkException());

      expect(
        () => repo.getDashboard('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('FinanceRepositoryImpl.getSummary', () {
    test('delegates to remote datasource with the given period', () async {
      when(() => remoteDatasource.getSummary(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => summary);

      final result = await repo.getSummary('store-1', period: 'week');

      expect(result, summary);
      verify(() => remoteDatasource.getSummary(
            'store-1',
            period: 'week',
            startDate: null,
            endDate: null,
          )).called(1);
    });

    test('propagates exceptions thrown by the remote datasource', () async {
      when(() => remoteDatasource.getSummary(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.getSummary('store-1', period: 'month'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
