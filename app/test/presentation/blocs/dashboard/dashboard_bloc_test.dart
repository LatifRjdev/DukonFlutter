import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/repositories/dashboard_repository.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_bloc.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_event.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_state.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  late MockDashboardRepository repository;

  const stats = DashboardStats(todayRevenue: 100, todaySalesCount: 2);

  setUp(() {
    repository = MockDashboardRepository();
  });

  group('DashboardBloc', () {
    test('initial state is DashboardInitial', () {
      final bloc = DashboardBloc(dashboardRepository: repository);
      expect(bloc.state, isA<DashboardInitial>());
    });

    group('DashboardLoadRequested', () {
      blocTest<DashboardBloc, DashboardState>(
        'emits [Loading, Loaded] when repository call succeeds',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenAnswer((_) async => stats);
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(const DashboardLoadRequested('store-1')),
        expect: () => [
          isA<DashboardLoading>(),
          predicate<DashboardState>((s) =>
              s is DashboardLoaded &&
              s.stats == stats &&
              s.period == 'today'),
        ],
        verify: (_) {
          verify(() => repository.getOverview('store-1', period: 'today'))
              .called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [Loading, Error] with mapped message when repository throws '
        'NetworkException',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenThrow(const NetworkException());
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(const DashboardLoadRequested('store-1')),
        expect: () => [
          isA<DashboardLoading>(),
          const DashboardError('Нет подключения к интернету'),
        ],
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [Loading, Error] with generic message when repository throws '
        'an unknown exception',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenThrow(Exception('unexpected'));
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(const DashboardLoadRequested('store-1')),
        expect: () => [
          isA<DashboardLoading>(),
          const DashboardError('Не удалось выполнить операцию'),
        ],
      );

      blocTest<DashboardBloc, DashboardState>(
        'passes a non-default period through to the repository',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenAnswer((_) async => stats);
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc
            .add(const DashboardLoadRequested('store-1', period: 'week')),
        expect: () => [
          isA<DashboardLoading>(),
          predicate<DashboardState>(
              (s) => s is DashboardLoaded && s.period == 'week'),
        ],
        verify: (_) {
          verify(() => repository.getOverview('store-1', period: 'week'))
              .called(1);
        },
      );
    });

    group('DashboardRefreshRequested', () {
      blocTest<DashboardBloc, DashboardState>(
        'emits [Loaded] without an intermediate Loading state on success',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenAnswer((_) async => stats);
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(const DashboardRefreshRequested('store-1')),
        expect: () => [
          predicate<DashboardState>(
              (s) => s is DashboardLoaded && s.stats == stats),
        ],
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits DashboardRefreshFailure (not DashboardError) when refresh '
        'fails while already loaded, so the still-good stats are never '
        'replaced by an error view (SPEC.md #41)',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        seed: () => const DashboardLoaded(stats),
        act: (bloc) => bloc.add(const DashboardRefreshRequested('store-1')),
        expect: () => [
          const DashboardRefreshFailure('Ошибка сервера — попробуйте позже'),
        ],
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits Error when refresh fails and there was no prior Loaded state',
        setUp: () {
          when(() => repository.getOverview(any(),
                  period: any(named: 'period')))
              .thenThrow(const NetworkException());
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(const DashboardRefreshRequested('store-1')),
        expect: () => [
          const DashboardError('Нет подключения к интернету'),
        ],
      );
    });

    group('DashboardPeriodChanged', () {
      blocTest<DashboardBloc, DashboardState>(
        'emits [Loading, Loaded] and forwards period/startDate/endDate',
        setUp: () {
          when(() => repository.getOverview(
                any(),
                period: any(named: 'period'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenAnswer((_) async => stats);
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(DashboardPeriodChanged(
          'store-1',
          'custom',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
        )),
        expect: () => [
          isA<DashboardLoading>(),
          predicate<DashboardState>(
              (s) => s is DashboardLoaded && s.period == 'custom'),
        ],
        verify: (_) {
          verify(() => repository.getOverview(
                'store-1',
                period: 'custom',
                startDate: DateTime(2026, 1, 1),
                endDate: DateTime(2026, 1, 31),
              )).called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [Loading, Error] when repository throws',
        setUp: () {
          when(() => repository.getOverview(
                any(),
                period: any(named: 'period'),
                startDate: any(named: 'startDate'),
                endDate: any(named: 'endDate'),
              )).thenThrow(const UnauthorizedException());
        },
        build: () => DashboardBloc(dashboardRepository: repository),
        act: (bloc) => bloc.add(const DashboardPeriodChanged('store-1', 'week')),
        expect: () => [
          isA<DashboardLoading>(),
          const DashboardError('Сессия истекла. Войдите снова.'),
        ],
      );
    });
  });
}
