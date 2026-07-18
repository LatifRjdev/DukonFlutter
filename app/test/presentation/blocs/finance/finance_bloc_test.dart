import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/finance_summary.dart';
import 'package:dukonpro/domain/repositories/finance_repository.dart';
import 'package:dukonpro/presentation/blocs/finance/finance_bloc.dart';
import 'package:dukonpro/presentation/blocs/finance/finance_event.dart';
import 'package:dukonpro/presentation/blocs/finance/finance_state.dart';

class MockFinanceRepository extends Mock implements FinanceRepository {}

void main() {
  late MockFinanceRepository repository;

  const summary = FinanceSummary(
    totalIncome: 100,
    totalExpenses: 40,
    profit: 60,
    salesCount: 5,
    avgCheck: 20,
  );

  setUp(() {
    repository = MockFinanceRepository();
  });

  group('FinanceBloc', () {
    test('initial state is FinanceInitial', () {
      final bloc = FinanceBloc(financeRepository: repository);
      expect(bloc.state, isA<FinanceInitial>());
    });

    group('FinanceDashboardRequested', () {
      blocTest<FinanceBloc, FinanceState>(
        'emits [FinanceLoading, FinanceLoaded] on success',
        setUp: () {
          when(() => repository.getDashboard(
                any(),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer((_) async => summary);
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) =>
            bloc.add(const FinanceDashboardRequested(storeId: 'store-1')),
        expect: () => [
          isA<FinanceLoading>(),
          const FinanceLoaded(summary: summary),
        ],
        verify: (_) {
          verify(() => repository.getDashboard(
                'store-1',
                startDate: null,
                endDate: null,
              )).called(1);
        },
      );

      blocTest<FinanceBloc, FinanceState>(
        'forwards startDate/endDate from the event to the repository',
        setUp: () {
          when(() => repository.getDashboard(
                any(),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer((_) async => summary);
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) => bloc.add(FinanceDashboardRequested(
          storeId: 'store-1',
          startDate: DateTime.utc(2026, 1, 1),
          endDate: DateTime.utc(2026, 1, 31),
        )),
        expect: () => [
          isA<FinanceLoading>(),
          const FinanceLoaded(summary: summary),
        ],
        verify: (_) {
          verify(() => repository.getDashboard(
                'store-1',
                startDate: DateTime.utc(2026, 1, 1),
                endDate: DateTime.utc(2026, 1, 31),
              )).called(1);
        },
      );

      blocTest<FinanceBloc, FinanceState>(
        'emits [FinanceLoading, FinanceError] with offline message on '
        'NetworkException',
        setUp: () {
          when(() => repository.getDashboard(
                any(),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenThrow(const NetworkException());
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) =>
            bloc.add(const FinanceDashboardRequested(storeId: 'store-1')),
        expect: () => [
          isA<FinanceLoading>(),
          const FinanceError('Нет подключения к интернету'),
        ],
      );

      blocTest<FinanceBloc, FinanceState>(
        'emits [FinanceLoading, FinanceError] and never leaks raw exception '
        'text on unknown errors',
        setUp: () {
          when(() => repository.getDashboard(
                any(),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenThrow(Exception('DioException [bad response]: boom'));
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) =>
            bloc.add(const FinanceDashboardRequested(storeId: 'store-1')),
        expect: () => [
          isA<FinanceLoading>(),
          predicate<FinanceState>((s) {
            if (s is! FinanceError) return false;
            return !s.message.contains('DioException') && s.message.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });

    group('FinancePeriodChanged', () {
      blocTest<FinanceBloc, FinanceState>(
        'emits [FinanceLoading, FinanceLoaded] with the requested period '
        'on success',
        setUp: () {
          when(() => repository.getSummary(
                any(),
                period: any(named: 'period'),
              )).thenAnswer((_) async => summary);
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) => bloc.add(
          const FinancePeriodChanged(storeId: 'store-1', period: 'week'),
        ),
        expect: () => [
          isA<FinanceLoading>(),
          const FinanceLoaded(summary: summary, period: 'week'),
        ],
        verify: (_) {
          verify(() => repository.getSummary('store-1', period: 'week'))
              .called(1);
        },
      );

      blocTest<FinanceBloc, FinanceState>(
        'emits [FinanceLoading, FinanceError] with server message on '
        'ServerException',
        setUp: () {
          when(() => repository.getSummary(
                any(),
                period: any(named: 'period'),
              )).thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) => bloc.add(
          const FinancePeriodChanged(storeId: 'store-1', period: 'month'),
        ),
        expect: () => [
          isA<FinanceLoading>(),
          const FinanceError('Ошибка сервера — попробуйте позже'),
        ],
      );

      blocTest<FinanceBloc, FinanceState>(
        'emits [FinanceLoading, FinanceError] with session-expired message '
        'on UnauthorizedException',
        setUp: () {
          when(() => repository.getSummary(
                any(),
                period: any(named: 'period'),
              )).thenThrow(const UnauthorizedException());
        },
        build: () => FinanceBloc(financeRepository: repository),
        act: (bloc) => bloc.add(
          const FinancePeriodChanged(storeId: 'store-1', period: 'month'),
        ),
        expect: () => [
          isA<FinanceLoading>(),
          const FinanceError('Сессия истекла. Войдите снова.'),
        ],
      );
    });
  });
}
