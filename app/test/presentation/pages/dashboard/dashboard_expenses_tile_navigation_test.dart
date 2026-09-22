// Regression coverage for the "Расходы" metric tile on the home dashboard:
// previously _MetricTile (Прибыль / Себестоимость / Расходы) had no onTap at
// all, so none of the three were clickable. There IS a dedicated expenses
// screen with an "add expense" FAB (ExpenseListPage at RouteNames.expenses),
// so "Расходы" should be a shortcut to it. Прибыль/Себестоимость stay
// non-interactive — there's no dedicated screen for either to link to.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_bloc.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_event.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockDashboardBloc dashboardBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    dashboardBloc = MockDashboardBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => dashboardBloc.state)
        .thenReturn(const DashboardLoaded(DashboardStats(), period: 'today'));
  });

  Future<void> pumpApp(WidgetTester tester, GoRouter router) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<DashboardBloc>.value(value: dashboardBloc),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'tapping the "Расходы" metric tile navigates to the expenses screen '
      'with the current store id', (tester) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => DashboardPage(onTabChange: (_) {}),
        ),
        // Mirrors app_router.dart's real extraction logic for this route.
        GoRoute(
          path: RouteNames.expenses,
          builder: (context, state) {
            final storeId = state.extra as String? ?? '';
            return Scaffold(body: Text('Expenses for store=$storeId'));
          },
        ),
      ],
    );

    await pumpApp(tester, router);

    await tester.tap(find.text('Расходы'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Expenses for store=test-store-id'), findsOneWidget);
  });

  testWidgets('tapping "Прибыль" or "Себестоимость" does not navigate anywhere',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => DashboardPage(onTabChange: (_) {}),
        ),
        GoRoute(
          path: RouteNames.expenses,
          builder: (context, state) =>
              const Scaffold(body: Text('Expenses screen')),
        ),
      ],
    );

    await pumpApp(tester, router);

    await tester.tap(find.text('Прибыль'));
    await tester.pumpAndSettle();
    expect(find.text('Expenses screen'), findsNothing);

    await tester.tap(find.text('Себестоимость'));
    await tester.pumpAndSettle();
    expect(find.text('Expenses screen'), findsNothing);
  });
}
