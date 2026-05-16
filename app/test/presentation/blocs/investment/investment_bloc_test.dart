import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/domain/entities/investment.dart';
import 'package:dukonpro/domain/repositories/investment_repository.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_bloc.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_event.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_l10n_key.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_state.dart';

class _MockRepo extends Mock implements InvestmentRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Investment buildInv(String id) => Investment(
        id: id,
        storeId: 's1',
        name: 'Test $id',
        amount: 100,
        investorName: 'A',
        status: 'ACTIVE',
        startDate: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
      );

  group('InvestmentBloc — list', () {
    blocTest<InvestmentBloc, InvestmentState>(
      'cold start: emits Loading then Loaded(isRefreshing:false)',
      setUp: () {
        when(() => repo.getInvestments(
              any(),
              page: any(named: 'page'),
              status: any(named: 'status'),
            )).thenAnswer((_) async => (
              data: [buildInv('1')],
              total: 1,
              totalPages: 1,
            ));
      },
      build: () => InvestmentBloc(investmentRepository: repo),
      act: (b) => b.add(const InvestmentListRequested(storeId: 's1')),
      expect: () => [
        isA<InvestmentLoading>(),
        isA<InvestmentLoaded>()
            .having((s) => s.isRefreshing, 'isRefreshing', false)
            .having((s) => s.investments.length, 'investments.length', 1),
      ],
    );

    blocTest<InvestmentBloc, InvestmentState>(
      'refresh from Loaded: isRefreshing:true → isRefreshing:false (no Loading flicker)',
      setUp: () {
        when(() => repo.getInvestments(
              any(),
              page: any(named: 'page'),
              status: any(named: 'status'),
            )).thenAnswer((_) async => (
              data: [buildInv('2')],
              total: 1,
              totalPages: 1,
            ));
      },
      build: () => InvestmentBloc(investmentRepository: repo),
      seed: () => const InvestmentLoaded(
        investments: [],
        total: 0,
        totalPages: 1,
      ),
      act: (b) => b.add(const InvestmentListRequested(storeId: 's1')),
      expect: () => [
        predicate<InvestmentState>(
          (s) => s is InvestmentLoaded && s.isRefreshing == true,
          'Loaded with isRefreshing:true',
        ),
        predicate<InvestmentState>(
          (s) =>
              s is InvestmentLoaded &&
              s.isRefreshing == false &&
              s.investments.length == 1,
          'Loaded with isRefreshing:false and 1 investment',
        ),
      ],
    );

    blocTest<InvestmentBloc, InvestmentState>(
      'failure: emits Loading then Error',
      setUp: () {
        when(() => repo.getInvestments(
              any(),
              page: any(named: 'page'),
              status: any(named: 'status'),
            )).thenThrow(Exception('boom'));
      },
      build: () => InvestmentBloc(investmentRepository: repo),
      act: (b) => b.add(const InvestmentListRequested(storeId: 's1')),
      expect: () => [
        isA<InvestmentLoading>(),
        isA<InvestmentError>(),
      ],
    );

    blocTest<InvestmentBloc, InvestmentState>(
      'filter switch: passes selectedStatus to repo',
      setUp: () {
        when(() => repo.getInvestments(
              any(),
              page: any(named: 'page'),
              status: any(named: 'status'),
            )).thenAnswer((_) async => (
              data: <Investment>[],
              total: 0,
              totalPages: 1,
            ));
      },
      build: () => InvestmentBloc(investmentRepository: repo),
      act: (b) => b.add(
        const InvestmentListRequested(storeId: 's1', status: 'COMPLETED'),
      ),
      verify: (_) {
        verify(() => repo.getInvestments(
              's1',
              page: any(named: 'page'),
              status: 'COMPLETED',
            )).called(1);
      },
    );
  });

  group('InvestmentBloc — mutations', () {
    blocTest<InvestmentBloc, InvestmentState>(
      'create: emits Loading → ActionSuccess(created) → chained reload',
      setUp: () {
        when(() => repo.createInvestment(any(), any()))
            .thenAnswer((_) async => buildInv('new'));
        when(() => repo.getInvestments(
              any(),
              page: any(named: 'page'),
              status: any(named: 'status'),
            )).thenAnswer((_) async => (
              data: <Investment>[buildInv('new')],
              total: 1,
              totalPages: 1,
            ));
      },
      build: () => InvestmentBloc(investmentRepository: repo),
      act: (b) => b.add(const InvestmentCreateRequested(
        storeId: 's1',
        data: {'name': 'X', 'amount': 100},
      )),
      // wait long enough for the Future.delayed(Duration.zero) + chained reload
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<InvestmentLoading>(),
        isA<InvestmentActionSuccess>().having(
          (s) => s.key,
          'key',
          InvestmentL10nKey.created,
        ),
        // chained reload from initial state goes via the else branch (Loading)
        isA<InvestmentLoading>(),
        isA<InvestmentLoaded>(),
      ],
    );

    blocTest<InvestmentBloc, InvestmentState>(
      'delete failure: emits Loading then Error',
      setUp: () {
        when(() => repo.deleteInvestment(any(), any()))
            .thenThrow(Exception('boom'));
      },
      build: () => InvestmentBloc(investmentRepository: repo),
      act: (b) => b.add(const InvestmentDeleteRequested(
        storeId: 's1',
        id: 'i1',
      )),
      expect: () => [
        isA<InvestmentLoading>(),
        isA<InvestmentError>(),
      ],
    );
  });
}
