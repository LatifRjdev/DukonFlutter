import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/investment_remote_datasource.dart';
import 'package:dukonpro/data/repositories/investment_repository_impl.dart';
import 'package:dukonpro/domain/entities/investment.dart';

class _MockInvestmentRemoteDatasource extends Mock
    implements InvestmentRemoteDatasource {}

void main() {
  late InvestmentRepositoryImpl repo;
  late _MockInvestmentRemoteDatasource remote;

  final investment = Investment(
    id: 'inv-1',
    storeId: 'store-1',
    name: 'New shop equipment',
    amount: 5000,
    investorName: 'Ali',
    status: 'ACTIVE',
    startDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );

  const summary = InvestmentSummary(
    totalAmount: 5000,
    totalCount: 1,
    activeAmount: 5000,
    activeCount: 1,
    completedAmount: 0,
    completedReturnAmount: 0,
    completedCount: 0,
  );

  setUp(() {
    remote = _MockInvestmentRemoteDatasource();
    repo = InvestmentRepositoryImpl(remoteDatasource: remote);
  });

  group('InvestmentRepositoryImpl.getInvestments', () {
    test('delegates to remote datasource and returns its result', () async {
      when(() => remote.getInvestments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            status: any(named: 'status'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer(
        (_) async => (data: [investment], total: 1, totalPages: 1),
      );

      final result = await repo.getInvestments('store-1');

      expect(result.data, [investment]);
      expect(result.total, 1);
      expect(result.totalPages, 1);
    });

    test('passes all filter params through unchanged', () async {
      when(() => remote.getInvestments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            status: any(named: 'status'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer(
        (_) async => (data: <Investment>[], total: 0, totalPages: 0),
      );
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      await repo.getInvestments(
        'store-9',
        page: 2,
        limit: 10,
        status: 'ACTIVE',
        startDate: start,
        endDate: end,
      );

      verify(() => remote.getInvestments(
            'store-9',
            page: 2,
            limit: 10,
            status: 'ACTIVE',
            startDate: start,
            endDate: end,
          )).called(1);
    });

    test('uses page:1 and limit:20 defaults when not provided', () async {
      when(() => remote.getInvestments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            status: any(named: 'status'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer(
        (_) async => (data: <Investment>[], total: 0, totalPages: 0),
      );

      await repo.getInvestments('store-1');

      verify(() => remote.getInvestments(
            'store-1',
            page: 1,
            limit: 20,
            status: null,
            startDate: null,
            endDate: null,
          )).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getInvestments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            status: any(named: 'status'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(const NetworkException());

      expect(
        () => repo.getInvestments('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.getInvestments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            status: any(named: 'status'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.getInvestments('store-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('InvestmentRepositoryImpl.getInvestment', () {
    test('delegates to remote datasource', () async {
      when(() => remote.getInvestment(any(), any()))
          .thenAnswer((_) async => investment);

      final result = await repo.getInvestment('store-1', 'inv-1');

      expect(result, investment);
      verify(() => remote.getInvestment('store-1', 'inv-1')).called(1);
    });

    test('propagates ServerException on 404', () async {
      when(() => remote.getInvestment(any(), any()))
          .thenThrow(const ServerException('not found', statusCode: 404));

      expect(
        () => repo.getInvestment('store-1', 'missing'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('InvestmentRepositoryImpl.createInvestment', () {
    test('delegates data through to remote datasource', () async {
      final data = {'name': 'New shop equipment', 'amount': 5000};
      when(() => remote.createInvestment(any(), any()))
          .thenAnswer((_) async => investment);

      final result = await repo.createInvestment('store-1', data);

      expect(result, investment);
      verify(() => remote.createInvestment('store-1', data)).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.createInvestment(any(), any()))
          .thenThrow(const ServerException('invalid', statusCode: 400));

      expect(
        () => repo.createInvestment('store-1', {'amount': -1}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('InvestmentRepositoryImpl.updateInvestment', () {
    test('delegates data through to remote datasource', () async {
      final data = {'status': 'COMPLETED'};
      when(() => remote.updateInvestment(any(), any(), any()))
          .thenAnswer((_) async => investment);

      final result = await repo.updateInvestment('store-1', 'inv-1', data);

      expect(result, investment);
      verify(() => remote.updateInvestment('store-1', 'inv-1', data))
          .called(1);
    });

    test('propagates UnauthorizedException from the remote datasource',
        () async {
      when(() => remote.updateInvestment(any(), any(), any()))
          .thenThrow(const UnauthorizedException());

      expect(
        () => repo.updateInvestment('store-1', 'inv-1', {'status': 'X'}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('InvestmentRepositoryImpl.deleteInvestment', () {
    test('delegates to remote datasource', () async {
      when(() => remote.deleteInvestment(any(), any()))
          .thenAnswer((_) async {});

      await repo.deleteInvestment('store-1', 'inv-1');

      verify(() => remote.deleteInvestment('store-1', 'inv-1')).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.deleteInvestment(any(), any()))
          .thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.deleteInvestment('store-1', 'inv-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('InvestmentRepositoryImpl.getSummary', () {
    test('delegates to remote datasource and returns its result', () async {
      when(() => remote.getSummary(any())).thenAnswer((_) async => summary);

      final result = await repo.getSummary('store-1');

      expect(result, summary);
      verify(() => remote.getSummary('store-1')).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getSummary(any()))
          .thenThrow(const NetworkException());

      expect(
        () => repo.getSummary('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
