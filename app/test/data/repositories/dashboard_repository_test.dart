import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/dashboard_remote_datasource.dart';
import 'package:dukonpro/data/repositories/dashboard_repository_impl.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_state.dart';

class _MockDashboardRemoteDatasource extends Mock
    implements DashboardRemoteDatasource {}

void main() {
  late DashboardRepositoryImpl repo;
  late _MockDashboardRemoteDatasource remote;

  setUp(() {
    remote = _MockDashboardRemoteDatasource();
    repo = DashboardRepositoryImpl(remoteDatasource: remote);
  });

  group('DashboardRepositoryImpl.getOverview', () {
    test('delegates to remote datasource and returns its result', () async {
      const stats = DashboardStats(todayRevenue: 500, todaySalesCount: 3);
      when(() => remote.getOverview(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => stats);

      final result = await repo.getOverview('store-1');

      expect(result, stats);
    });

    test('passes storeId/period/startDate/endDate through unchanged',
        () async {
      const stats = DashboardStats();
      when(() => remote.getOverview(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => stats);
      final start = DateTime(2026, 2, 1);
      final end = DateTime(2026, 2, 28);

      await repo.getOverview('store-9',
          period: 'month', startDate: start, endDate: end);

      verify(() => remote.getOverview(
            'store-9',
            period: 'month',
            startDate: start,
            endDate: end,
          )).called(1);
    });

    test('defaults period to "today" when not supplied', () async {
      const stats = DashboardStats();
      when(() => remote.getOverview(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => stats);

      await repo.getOverview('store-1');

      verify(() => remote.getOverview(
            'store-1',
            period: 'today',
            startDate: null,
            endDate: null,
          )).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getOverview(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(const NetworkException());

      expect(
        () => repo.getOverview('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.getOverview(
            any(),
            period: any(named: 'period'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.getOverview('store-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
