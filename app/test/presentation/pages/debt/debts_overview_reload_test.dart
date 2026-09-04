// Regression test for post-plan SPEC.md audit finding #1: DebtBloc is a
// single app-wide instance shared with CustomerDebtsPage/SupplierDebtsPage.
// context.push kept DebtsOverviewPage mounted underneath the pushed detail
// route rather than disposing it, so its initState never re-fired on
// return, and the bloc's state by then (whatever the child screen last
// emitted) fell through DebtsOverviewPage's builder to a permanent
// fallback spinner. The fix re-dispatches DebtsOverviewRequested once the
// pushed route returns.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_bloc.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_event.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/debt/debts_overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockDebtBloc extends MockBloc<DebtEvent, DebtState> implements DebtBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockDebtBloc debtBloc;

  final overviewLoaded = DebtsOverviewLoaded(
    customers: [
      {'id': 'c1', 'name': 'Иван', 'debt': 500, 'phone': '+992900000000'},
    ],
    suppliers: [
      {'id': 's1', 'name': 'Поставщик 1', 'debt': 300, 'phone': '+992900000001'},
    ],
    totalCustomerDebt: 500,
    totalSupplierDebt: 300,
  );

  setUp(() {
    storeBloc = MockStoreBloc();
    debtBloc = MockDebtBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => debtBloc.state).thenReturn(overviewLoaded);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/debts',
      routes: [
        GoRoute(
          path: '/debts',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<StoreBloc>.value(value: storeBloc),
              BlocProvider<DebtBloc>.value(value: debtBloc),
            ],
            child: const DebtsOverviewPage(storeId: 'test-store-id'),
          ),
        ),
        // Stub detail routes: after the visit, the shared DebtBloc is left
        // in whatever state the real CustomerDebtsPage/SupplierDebtsPage
        // would leave it in (simulated here by simply not touching it,
        // since the bug reproduces regardless of the exact left-behind
        // state — the point is DebtsOverviewPage's initState never re-fires
        // on return).
        GoRoute(
          path: '/debts/customer',
          builder: (context, state) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Text('Customer Debt Detail'),
          ),
        ),
        GoRoute(
          path: '/debts/supplier',
          builder: (context, state) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Text('Supplier Debt Detail'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'returning from a customer debt detail re-requests the overview so the '
    'page does not get stuck on the shared bloc leftover state',
    (tester) async {
      await pumpApp(tester);

      // initState fired once already.
      verify(() => debtBloc.add(const DebtsOverviewRequested(storeId: 'test-store-id')))
          .called(1);

      await tester.tap(find.text('Иван'));
      await tester.pumpAndSettle();
      expect(find.text('Customer Debt Detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(DebtsOverviewPage), findsOneWidget);
      // Re-requested on return, not just once at initial mount.
      verify(() => debtBloc.add(const DebtsOverviewRequested(storeId: 'test-store-id')))
          .called(1);
    },
  );

  testWidgets(
    'returning from a supplier debt detail re-requests the overview',
    (tester) async {
      await pumpApp(tester);
      verify(() => debtBloc.add(const DebtsOverviewRequested(storeId: 'test-store-id')))
          .called(1);

      await tester.tap(find.text('Поставщик 1'));
      await tester.pumpAndSettle();
      expect(find.text('Supplier Debt Detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(DebtsOverviewPage), findsOneWidget);
      verify(() => debtBloc.add(const DebtsOverviewRequested(storeId: 'test-store-id')))
          .called(1);
    },
  );
}
