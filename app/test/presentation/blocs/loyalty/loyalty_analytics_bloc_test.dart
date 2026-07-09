import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/domain/entities/loyalty_analytics.dart';
import 'package:dukonpro/domain/repositories/loyalty_repository.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_analytics_bloc.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_analytics_event.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_analytics_state.dart';

class MockLoyaltyRepository extends Mock implements LoyaltyRepository {}

void main() {
  late MockLoyaltyRepository repo;

  final from = DateTime(2026, 7, 1);
  final to = DateTime(2026, 7, 9);

  final stubAnalytics = LoyaltyAnalytics(
    from: from,
    to: to,
    totalEarned: 1000,
    totalRedeemed: 200,
    totalExpired: 50,
    discountValue: 20.0,
    activeParticipants: 5,
    topCustomers: [],
  );

  setUp(() {
    repo = MockLoyaltyRepository();
    registerFallbackValue(DateTime.now());
  });

  group('LoyaltyAnalyticsBloc', () {
    blocTest<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
      'should emit [Loading, Loaded] when getAnalytics succeeds',
      build: () {
        when(() => repo.getAnalytics(any(), any(), any()))
            .thenAnswer((_) async => stubAnalytics);
        return LoyaltyAnalyticsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(
        LoyaltyAnalyticsLoadRequested(
            storeId: 'store-1', from: from, to: to),
      ),
      expect: () => [
        const LoyaltyAnalyticsLoading(),
        LoyaltyAnalyticsLoaded(stubAnalytics),
      ],
    );

    blocTest<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
      'should emit [Loading, Error] when getAnalytics throws',
      build: () {
        when(() => repo.getAnalytics(any(), any(), any()))
            .thenThrow(Exception('network error'));
        return LoyaltyAnalyticsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(
        LoyaltyAnalyticsLoadRequested(
            storeId: 'store-1', from: from, to: to),
      ),
      expect: () => [
        const LoyaltyAnalyticsLoading(),
        isA<LoyaltyAnalyticsError>(),
      ],
    );

    blocTest<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
      'should call getAnalytics with correct storeId and date range',
      build: () {
        when(() => repo.getAnalytics(any(), any(), any()))
            .thenAnswer((_) async => stubAnalytics);
        return LoyaltyAnalyticsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(
        LoyaltyAnalyticsLoadRequested(
            storeId: 'store-99', from: from, to: to),
      ),
      verify: (_) {
        verify(() => repo.getAnalytics('store-99', from, to)).called(1);
      },
    );
  });
}
