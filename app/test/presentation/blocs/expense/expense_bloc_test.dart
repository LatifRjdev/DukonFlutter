import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/expense.dart';
import 'package:dukonpro/domain/repositories/expense_repository.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_bloc.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_event.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_state.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

void main() {
  late MockExpenseRepository repository;

  final expense = Expense(
    id: 'exp-1',
    storeId: 'store-1',
    category: 'RENT',
    amount: 500,
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockExpenseRepository();
  });

  group('ExpenseBloc', () {
    test('initial state is ExpenseInitial', () {
      final bloc = ExpenseBloc(expenseRepository: repository);
      expect(bloc.state, isA<ExpenseInitial>());
    });

    group('ExpenseListRequested', () {
      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, Loaded] on success',
        setUp: () {
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer(
              (_) async => (data: [expense], total: 1, totalPages: 1));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) =>
            bloc.add(const ExpenseListRequested(storeId: 'store-1')),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseLoaded>()
              .having((s) => s.expenses, 'expenses', [expense])
              .having((s) => s.total, 'total', 1)
              .having((s) => s.totalPages, 'totalPages', 1)
              .having((s) => s.currentPage, 'currentPage', 1),
        ],
      );

      blocTest<ExpenseBloc, ExpenseState>(
        'carries through the requested page and category into ExpenseLoaded',
        setUp: () {
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer(
              (_) async => (data: <Expense>[], total: 0, totalPages: 0));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseListRequested(
          storeId: 'store-1',
          page: 3,
          category: 'UTILITIES',
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseLoaded>()
              .having((s) => s.currentPage, 'currentPage', 3)
              .having((s) => s.selectedCategory, 'selectedCategory',
                  'UTILITIES'),
        ],
      );

      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, Error] with offline message on NetworkException',
        setUp: () {
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenThrow(const NetworkException());
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) =>
            bloc.add(const ExpenseListRequested(storeId: 'store-1')),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseError>().having(
              (s) => s.message, 'message', 'Нет подключения к интернету'),
        ],
      );

      blocTest<ExpenseBloc, ExpenseState>(
        'never leaks raw exception text into ExpenseError.message',
        setUp: () {
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenThrow(
              Exception('DioException [bad response]: http://10.0.2.2:4455'));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) =>
            bloc.add(const ExpenseListRequested(storeId: 'store-1')),
        expect: () => [
          isA<ExpenseLoading>(),
          predicate<ExpenseState>((s) {
            if (s is! ExpenseError) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('DioException') &&
                s.message.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });

    group('ExpenseCreateRequested', () {
      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, ActionSuccess] then reloads the list on success',
        setUp: () {
          when(() => repository.createExpense(any(), any()))
              .thenAnswer((_) async => expense);
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer(
              (_) async => (data: [expense], total: 1, totalPages: 1));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseCreateRequested(
          storeId: 'store-1',
          data: {'category': 'RENT', 'amount': 500},
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseActionSuccess>()
              .having((s) => s.message, 'message', 'Расход добавлен'),
          isA<ExpenseLoading>(),
          isA<ExpenseLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.createExpense(
                'store-1',
                {'category': 'RENT', 'amount': 500},
              )).called(1);
        },
      );

      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, Error] and does not reload the list on failure',
        setUp: () {
          when(() => repository.createExpense(any(), any()))
              .thenThrow(const ServerException('invalid', statusCode: 400));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseCreateRequested(
          storeId: 'store-1',
          data: {'amount': -1},
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseError>()
              .having((s) => s.message, 'message', 'Некорректные данные'),
        ],
        verify: (_) {
          verifyNever(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              ));
        },
      );
    });

    group('ExpenseUpdateRequested', () {
      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, ActionSuccess] then reloads the list on success',
        setUp: () {
          when(() => repository.updateExpense(any(), any(), any()))
              .thenAnswer((_) async => expense);
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer(
              (_) async => (data: [expense], total: 1, totalPages: 1));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseUpdateRequested(
          storeId: 'store-1',
          id: 'exp-1',
          data: {'amount': 600},
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseActionSuccess>()
              .having((s) => s.message, 'message', 'Расход обновлён'),
          isA<ExpenseLoading>(),
          isA<ExpenseLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.updateExpense(
                'store-1',
                'exp-1',
                {'amount': 600},
              )).called(1);
        },
      );

      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, Error] on failure',
        setUp: () {
          when(() => repository.updateExpense(any(), any(), any()))
              .thenThrow(const UnauthorizedException());
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseUpdateRequested(
          storeId: 'store-1',
          id: 'exp-1',
          data: {'amount': 600},
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseError>().having((s) => s.message, 'message',
              'Сессия истекла. Войдите снова.'),
        ],
      );
    });

    group('ExpenseDeleteRequested', () {
      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, ActionSuccess] then reloads the list on success',
        setUp: () {
          when(() => repository.deleteExpense(any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer(
              (_) async => (data: <Expense>[], total: 0, totalPages: 0));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseDeleteRequested(
          storeId: 'store-1',
          id: 'exp-1',
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseActionSuccess>()
              .having((s) => s.message, 'message', 'Расход удалён'),
          isA<ExpenseLoading>(),
          isA<ExpenseLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.deleteExpense('store-1', 'exp-1'))
              .called(1);
        },
      );

      blocTest<ExpenseBloc, ExpenseState>(
        'emits [Loading, Error] on failure and does not reload the list',
        setUp: () {
          when(() => repository.deleteExpense(any(), any()))
              .thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => ExpenseBloc(expenseRepository: repository),
        act: (bloc) => bloc.add(const ExpenseDeleteRequested(
          storeId: 'store-1',
          id: 'exp-1',
        )),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseError>().having(
              (s) => s.message, 'message', 'Ошибка сервера — попробуйте позже'),
        ],
        verify: (_) {
          verifyNever(() => repository.getExpenses(
                any(),
                page: any(named: 'page'),
                category: any(named: 'category'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              ));
        },
      );
    });
  });
}
