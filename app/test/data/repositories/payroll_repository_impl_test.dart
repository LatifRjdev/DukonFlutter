import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/payroll_remote_datasource.dart';
import 'package:dukonpro/data/repositories/payroll_repository_impl.dart';
import 'package:dukonpro/domain/entities/payroll_period.dart';

class MockPayrollRemoteDatasource extends Mock
    implements PayrollRemoteDatasource {}

void main() {
  late MockPayrollRemoteDatasource remoteDatasource;
  late PayrollRepositoryImpl repo;

  const period = PayrollPeriod(
    id: 'period-1',
    month: 5,
    year: 2026,
    status: 'CALCULATED',
    totalAmount: 1000,
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    remoteDatasource = MockPayrollRemoteDatasource();
    repo = PayrollRepositoryImpl(remoteDatasource: remoteDatasource);
  });

  group('PayrollRepositoryImpl.calculatePayroll', () {
    test('delegates to remote datasource with storeId/month/year and returns its result',
        () async {
      when(() => remoteDatasource.calculatePayroll(any(), any(), any()))
          .thenAnswer((_) async => period);

      final result = await repo.calculatePayroll('store-1', 5, 2026);

      expect(result, period);
      verify(() => remoteDatasource.calculatePayroll('store-1', 5, 2026))
          .called(1);
    });

    test('propagates exceptions thrown by the remote datasource', () async {
      when(() => remoteDatasource.calculatePayroll(any(), any(), any()))
          .thenThrow(const NetworkException());

      expect(
        () => repo.calculatePayroll('store-1', 5, 2026),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('PayrollRepositoryImpl.getPayrollPeriods', () {
    test('delegates to remote datasource and returns the list', () async {
      when(() => remoteDatasource.getPayrollPeriods(any()))
          .thenAnswer((_) async => [period]);

      final result = await repo.getPayrollPeriods('store-1');

      expect(result, [period]);
      verify(() => remoteDatasource.getPayrollPeriods('store-1')).called(1);
    });

    test('propagates exceptions thrown by the remote datasource', () async {
      when(() => remoteDatasource.getPayrollPeriods(any()))
          .thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.getPayrollPeriods('store-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('PayrollRepositoryImpl.getPayrollPeriod', () {
    test('delegates to remote datasource with storeId/periodId', () async {
      when(() => remoteDatasource.getPayrollPeriod(any(), any()))
          .thenAnswer((_) async => period);

      final result = await repo.getPayrollPeriod('store-1', 'period-1');

      expect(result, period);
      verify(() => remoteDatasource.getPayrollPeriod('store-1', 'period-1'))
          .called(1);
    });
  });

  group('PayrollRepositoryImpl.addAdjustment', () {
    test('delegates to remote datasource with the raw data map', () async {
      when(() => remoteDatasource.addAdjustment(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.addAdjustment(
        'store-1',
        'period-1',
        {'type': 'BONUS', 'amount': 100},
      );

      verify(() => remoteDatasource.addAdjustment(
            'store-1',
            'period-1',
            {'type': 'BONUS', 'amount': 100},
          )).called(1);
    });

    test('propagates exceptions thrown by the remote datasource', () async {
      when(() => remoteDatasource.addAdjustment(any(), any(), any()))
          .thenThrow(const ServerException('bad', statusCode: 400));

      expect(
        () => repo.addAdjustment('store-1', 'period-1', {'amount': 1}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('PayrollRepositoryImpl.removeAdjustment', () {
    test('delegates to remote datasource with storeId/periodId/adjustmentId',
        () async {
      when(() => remoteDatasource.removeAdjustment(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.removeAdjustment('store-1', 'period-1', 'adj-1');

      verify(() => remoteDatasource.removeAdjustment(
            'store-1',
            'period-1',
            'adj-1',
          )).called(1);
    });
  });

  group('PayrollRepositoryImpl.payIndividual', () {
    test('delegates to remote datasource with storeId/periodId/payrollId',
        () async {
      when(() => remoteDatasource.payIndividual(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.payIndividual('store-1', 'period-1', 'payroll-1');

      verify(() => remoteDatasource.payIndividual(
            'store-1',
            'period-1',
            'payroll-1',
          )).called(1);
    });

    test('propagates exceptions thrown by the remote datasource', () async {
      when(() => remoteDatasource.payIndividual(any(), any(), any()))
          .thenThrow(const NetworkException());

      expect(
        () => repo.payIndividual('store-1', 'period-1', 'payroll-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('PayrollRepositoryImpl.payAll', () {
    test('delegates to remote datasource with storeId/periodId', () async {
      when(() => remoteDatasource.payAll(any(), any()))
          .thenAnswer((_) async {});

      await repo.payAll('store-1', 'period-1');

      verify(() => remoteDatasource.payAll('store-1', 'period-1')).called(1);
    });
  });
}
