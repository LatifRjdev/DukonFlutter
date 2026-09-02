// Regression coverage for SPEC.md #41: when pull-to-refresh failed after an
// initial successful load, DashboardBloc silently swallowed the error (see
// the old `if (state is DashboardLoaded) return;` in _onRefreshRequested) —
// no snackbar, no signal at all, and the user had no way to know their
// refresh didn't actually happen. The fix emits a distinct
// DashboardRefreshFailure state that the page treats as listener-only (show
// a snackbar) while skipping the rebuild, so the already-rendered stats are
// never replaced by an error view underneath the silent failure.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_bloc.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_event.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockDashboardBloc dashboardBloc;
  late StreamController<DashboardState> stateController;

  const loadedStats = DashboardStats(todayRevenue: 12345, todaySalesCount: 3);
  const loaded = DashboardLoaded(loadedStats, period: 'today');

  setUp(() {
    storeBloc = MockStoreBloc();
    dashboardBloc = MockDashboardBloc();
    stateController = StreamController<DashboardState>.broadcast();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    whenListen(dashboardBloc, stateController.stream, initialState: loaded);
  });

  tearDown(() async {
    await stateController.close();
    await dashboardBloc.close();
  });

  Widget page() => DashboardPage(onTabChange: (_) {});

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<DashboardBloc>.value(value: dashboardBloc),
        ],
        child: child,
      );

  testWidgets(
      'shows an error snackbar and keeps the stats on screen when a '
      'refresh fails after a successful load (SPEC.md #41)', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
    );

    // Sanity check: the revenue figure from the successful load is on
    // screen before the failed refresh.
    expect(find.textContaining(RegExp('12.345')), findsOneWidget);

    stateController.add(const DashboardRefreshFailure('Нет подключения к интернету'));
    await tester.pump();
    // Let the snackbar's entrance animation settle so its text is mounted.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Нет подключения к интернету'), findsOneWidget);
    // The failure must not have wiped the stats off screen.
    expect(find.textContaining(RegExp('12.345')), findsOneWidget);
  });
}
