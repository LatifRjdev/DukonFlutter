import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/payroll_period.dart';
import 'package:dukonpro/domain/repositories/payroll_repository.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_bloc.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_event.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_state.dart';

class MockPayrollRepository extends Mock implements PayrollRepository {}

void main() {
  late MockPayrollRepository repository;

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
    repository = MockPayrollRepository();
  });

  group('PayrollBloc', () {
    test('initial state is PayrollInitial', () {
      final bloc = PayrollBloc(payrollRepository: repository);
      expect(bloc.state, isA<PayrollInitial>());
    });

    group('LoadPayrollPeriods', () {
      blocTest<PayrollBloc, PayrollState>(
        'emits [PayrollLoading, PayrollPeriodsLoaded] on success',
        setUp: () {
          when(() => repository.getPayrollPeriods(any()))
              .thenAnswer((_) async => [period]);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const LoadPayrollPeriods(storeId: 'store-1')),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodsLoaded>()
              .having((s) => s.periods, 'periods', [period]),
        ],
        verify: (_) {
          verify(() => repository.getPayrollPeriods('store-1')).called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits [PayrollLoading, PayrollError] with offline message on NetworkException',
        setUp: () {
          when(() => repository.getPayrollPeriods(any()))
              .thenThrow(const NetworkException());
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const LoadPayrollPeriods(storeId: 'store-1')),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>().having(
            (s) => s.message,
            'message',
            'Нет подключения к интернету',
          ),
        ],
      );

      blocTest<PayrollBloc, PayrollState>(
        'never leaks raw exception text into the error message',
        setUp: () {
          when(() => repository.getPayrollPeriods(any())).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/x'),
          );
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const LoadPayrollPeriods(storeId: 'store-1')),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>().having(
            (s) => s.message,
            'message',
            predicate<String>((m) =>
                !m.contains('10.0.2.2') && !m.contains('DioException')),
          ),
        ],
      );
    });

    group('LoadPayrollPeriod', () {
      blocTest<PayrollBloc, PayrollState>(
        'emits [PayrollLoading, PayrollPeriodDetailLoaded] on success',
        setUp: () {
          when(() => repository.getPayrollPeriod(any(), any()))
              .thenAnswer((_) async => period);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const LoadPayrollPeriod(
          storeId: 'store-1',
          periodId: 'period-1',
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodDetailLoaded>()
              .having((s) => s.period, 'period', period),
        ],
        verify: (_) {
          verify(() => repository.getPayrollPeriod('store-1', 'period-1'))
              .called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits [PayrollLoading, PayrollError] on ServerException 404',
        setUp: () {
          when(() => repository.getPayrollPeriod(any(), any())).thenThrow(
            const ServerException('Not found', statusCode: 404),
          );
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const LoadPayrollPeriod(
          storeId: 'store-1',
          periodId: 'missing',
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>()
              .having((s) => s.message, 'message', 'Объект не найден'),
        ],
      );
    });

    group('CalculatePayroll', () {
      blocTest<PayrollBloc, PayrollState>(
        'calculates then chains into LoadPayrollPeriods, ending on PayrollPeriodsLoaded',
        setUp: () {
          when(() => repository.calculatePayroll(any(), any(), any()))
              .thenAnswer((_) async => period);
          when(() => repository.getPayrollPeriods(any()))
              .thenAnswer((_) async => [period]);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const CalculatePayroll(
          storeId: 'store-1',
          month: 5,
          year: 2026,
        )),
        // Both the CalculatePayroll and chained LoadPayrollPeriods handlers
        // emit PayrollLoading() first, but Bloc's emit() dedupes consecutive
        // equal states (PayrollLoading has no props), so only one
        // PayrollLoading reaches the state stream before the final result.
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodsLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.calculatePayroll('store-1', 5, 2026))
              .called(1);
          verify(() => repository.getPayrollPeriods('store-1')).called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits PayrollError and does not chain into LoadPayrollPeriods on failure',
        setUp: () {
          when(() => repository.calculatePayroll(any(), any(), any()))
              .thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const CalculatePayroll(
          storeId: 'store-1',
          month: 5,
          year: 2026,
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>().having(
            (s) => s.message,
            'message',
            'Ошибка сервера — попробуйте позже',
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getPayrollPeriods(any()));
        },
      );
    });

    group('AddAdjustment', () {
      blocTest<PayrollBloc, PayrollState>(
        'adds adjustment then reloads the period detail',
        setUp: () {
          when(() => repository.addAdjustment(any(), any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getPayrollPeriod(any(), any()))
              .thenAnswer((_) async => period);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const AddAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          data: {'type': 'BONUS', 'amount': 100, 'description': 'x'},
        )),
        // See CalculatePayroll's dedup comment above — the chained
        // LoadPayrollPeriod's PayrollLoading() is swallowed by Bloc's
        // equal-state dedup, so only 2 states reach the stream.
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodDetailLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.addAdjustment(
                'store-1',
                'period-1',
                {'type': 'BONUS', 'amount': 100, 'description': 'x'},
              )).called(1);
          verify(() => repository.getPayrollPeriod('store-1', 'period-1'))
              .called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'zero-amount adjustment is still forwarded to the repository as-is',
        setUp: () {
          when(() => repository.addAdjustment(any(), any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getPayrollPeriod(any(), any()))
              .thenAnswer((_) async => period);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const AddAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          data: {'type': 'DEDUCTION', 'amount': 0, 'description': 'no-op'},
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodDetailLoaded>(),
        ],
        verify: (_) {
          final captured = verify(() => repository.addAdjustment(
                'store-1',
                'period-1',
                captureAny(),
              )).captured;
          expect((captured.single as Map)['amount'], 0);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits PayrollError and does not reload the period on failure',
        setUp: () {
          when(() => repository.addAdjustment(any(), any(), any()))
              .thenThrow(const ServerException('Bad data', statusCode: 400));
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const AddAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          data: {'amount': -1},
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>()
              .having((s) => s.message, 'message', 'Некорректные данные'),
        ],
        verify: (_) {
          verifyNever(() => repository.getPayrollPeriod(any(), any()));
        },
      );
    });

    group('RemoveAdjustment', () {
      blocTest<PayrollBloc, PayrollState>(
        'removes adjustment then reloads the period detail',
        setUp: () {
          when(() => repository.removeAdjustment(any(), any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getPayrollPeriod(any(), any()))
              .thenAnswer((_) async => period);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const RemoveAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          adjustmentId: 'adj-1',
        )),
        // See CalculatePayroll's dedup comment above.
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodDetailLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.removeAdjustment(
                'store-1',
                'period-1',
                'adj-1',
              )).called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits PayrollError on failure',
        setUp: () {
          when(() => repository.removeAdjustment(any(), any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const RemoveAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          adjustmentId: 'adj-1',
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>().having(
            (s) => s.message,
            'message',
            'Нет подключения к интернету',
          ),
        ],
      );
    });

    group('PayIndividual', () {
      blocTest<PayrollBloc, PayrollState>(
        'pays an individual then reloads the period detail',
        setUp: () {
          when(() => repository.payIndividual(any(), any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getPayrollPeriod(any(), any()))
              .thenAnswer((_) async => period);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const PayIndividual(
          storeId: 'store-1',
          periodId: 'period-1',
          payrollId: 'payroll-1',
        )),
        // See CalculatePayroll's dedup comment above.
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodDetailLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.payIndividual(
                'store-1',
                'period-1',
                'payroll-1',
              )).called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits PayrollError on failure and does not reload',
        setUp: () {
          when(() => repository.payIndividual(any(), any(), any()))
              .thenThrow(const ServerException('Conflict', statusCode: 409));
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const PayIndividual(
          storeId: 'store-1',
          periodId: 'period-1',
          payrollId: 'payroll-1',
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>().having(
            (s) => s.message,
            'message',
            'Конфликт — объект уже существует',
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getPayrollPeriod(any(), any()));
        },
      );
    });

    group('PayAll', () {
      blocTest<PayrollBloc, PayrollState>(
        'pays all then reloads the period detail',
        setUp: () {
          when(() => repository.payAll(any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getPayrollPeriod(any(), any()))
              .thenAnswer((_) async => period);
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const PayAll(
          storeId: 'store-1',
          periodId: 'period-1',
        )),
        // See CalculatePayroll's dedup comment above.
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollPeriodDetailLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.payAll('store-1', 'period-1')).called(1);
        },
      );

      blocTest<PayrollBloc, PayrollState>(
        'emits PayrollError on failure',
        setUp: () {
          when(() => repository.payAll(any(), any()))
              .thenThrow(const UnauthorizedException());
        },
        build: () => PayrollBloc(payrollRepository: repository),
        act: (bloc) => bloc.add(const PayAll(
          storeId: 'store-1',
          periodId: 'period-1',
        )),
        expect: () => [
          isA<PayrollLoading>(),
          isA<PayrollError>().having(
            (s) => s.message,
            'message',
            'Сессия истекла. Войдите снова.',
          ),
        ],
      );
    });
  });
}
