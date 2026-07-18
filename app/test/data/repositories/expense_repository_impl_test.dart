import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/expense_remote_datasource.dart';
import 'package:dukonpro/data/repositories/expense_repository_impl.dart';
import 'package:dukonpro/domain/entities/expense.dart';

class _MockExpenseRemoteDatasource extends Mock
    implements ExpenseRemoteDatasource {}

void main() {
  late ExpenseRepositoryImpl repo;
  late _MockExpenseRemoteDatasource remote;

  final expense = Expense(
    id: 'exp-1',
    storeId: 'store-1',
    category: 'RENT',
    amount: 500,
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    remote = _MockExpenseRemoteDatasource();
    repo = ExpenseRepositoryImpl(remoteDatasource: remote);
  });

  group('ExpenseRepositoryImpl.getExpenses', () {
    test('delegates to remote datasource and returns its result', () async {
      when(() => remote.getExpenses(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            category: any(named: 'category'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            search: any(named: 'search'),
          )).thenAnswer((_) async => (data: [expense], total: 1, totalPages: 1));

      final result = await repo.getExpenses('store-1');

      expect(result.data, [expense]);
      expect(result.total, 1);
      expect(result.totalPages, 1);
    });

    test('passes all filter params through unchanged', () async {
      when(() => remote.getExpenses(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            category: any(named: 'category'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            search: any(named: 'search'),
          )).thenAnswer((_) async => (data: <Expense>[], total: 0, totalPages: 0));
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      await repo.getExpenses(
        'store-9',
        page: 2,
        limit: 10,
        category: 'RENT',
        startDate: start,
        endDate: end,
        search: 'office',
      );

      verify(() => remote.getExpenses(
            'store-9',
            page: 2,
            limit: 10,
            category: 'RENT',
            startDate: start,
            endDate: end,
            search: 'office',
          )).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getExpenses(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            category: any(named: 'category'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            search: any(named: 'search'),
          )).thenThrow(const NetworkException());

      expect(
        () => repo.getExpenses('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.getExpenses(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            category: any(named: 'category'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            search: any(named: 'search'),
          )).thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.getExpenses('store-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ExpenseRepositoryImpl.getExpense', () {
    test('delegates to remote datasource', () async {
      when(() => remote.getExpense(any(), any()))
          .thenAnswer((_) async => expense);

      final result = await repo.getExpense('store-1', 'exp-1');

      expect(result, expense);
      verify(() => remote.getExpense('store-1', 'exp-1')).called(1);
    });

    test('propagates ServerException on 404', () async {
      when(() => remote.getExpense(any(), any()))
          .thenThrow(const ServerException('not found', statusCode: 404));

      expect(
        () => repo.getExpense('store-1', 'missing'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ExpenseRepositoryImpl.createExpense', () {
    test('delegates data through to remote datasource', () async {
      final data = {'category': 'RENT', 'amount': 500};
      when(() => remote.createExpense(any(), any()))
          .thenAnswer((_) async => expense);

      final result = await repo.createExpense('store-1', data);

      expect(result, expense);
      verify(() => remote.createExpense('store-1', data)).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.createExpense(any(), any()))
          .thenThrow(const ServerException('invalid', statusCode: 400));

      expect(
        () => repo.createExpense('store-1', {'amount': -1}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ExpenseRepositoryImpl.updateExpense', () {
    test('delegates data through to remote datasource', () async {
      final data = {'amount': 600};
      when(() => remote.updateExpense(any(), any(), any()))
          .thenAnswer((_) async => expense);

      final result = await repo.updateExpense('store-1', 'exp-1', data);

      expect(result, expense);
      verify(() => remote.updateExpense('store-1', 'exp-1', data)).called(1);
    });

    test('propagates UnauthorizedException from the remote datasource',
        () async {
      when(() => remote.updateExpense(any(), any(), any()))
          .thenThrow(const UnauthorizedException());

      expect(
        () => repo.updateExpense('store-1', 'exp-1', {'amount': 1}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('ExpenseRepositoryImpl.deleteExpense', () {
    test('delegates to remote datasource', () async {
      when(() => remote.deleteExpense(any(), any()))
          .thenAnswer((_) async {});

      await repo.deleteExpense('store-1', 'exp-1');

      verify(() => remote.deleteExpense('store-1', 'exp-1')).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.deleteExpense(any(), any()))
          .thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.deleteExpense('store-1', 'exp-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
