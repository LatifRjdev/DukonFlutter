// Behavioral coverage for SPEC.md #40 — the dashboard's calendar icon
// correctly opened showDateRangePicker and stored the picked range in
// _customDateRange, but dispatched DashboardPeriodChanged(storeId, 'custom')
// without the picked startDate/endDate — even though the event and the bloc
// already supported those fields (DashboardBloc._onPeriodChanged already
// forwarded them to the repository; see dashboard_bloc_test.dart's
// pre-existing DashboardPeriodChanged tests). So picking a custom range
// visually selected the "custom" chip but silently queried with no date
// bounds at all. This test drives the real Material date-range picker
// (via its "switch to manual input" mode, which is deterministic — unlike
// tapping calendar day cells, which shifts with today's date) and proves
// the picked dates now reach the dispatched event.
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

  setUpAll(() {
    registerFallbackValue(const DashboardPeriodChanged('fallback', 'today'));
  });

  setUp(() {
    storeBloc = MockStoreBloc();
    dashboardBloc = MockDashboardBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => dashboardBloc.state).thenReturn(
      const DashboardLoaded(DashboardStats(), period: 'today'),
    );
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
      'picking a custom date range dispatches DashboardPeriodChanged with '
      'the exact picked startDate/endDate', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
    );

    // Open the date-range picker via the calendar chip.
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    // The dialog opens in calendar mode by default; switch to manual input
    // — deterministic text entry, unlike tapping calendar day cells (whose
    // grid position shifts relative to `DateTime.now()`, the picker's
    // `lastDate`).
    await tester.tap(find.byTooltip('Переключиться на ручной ввод'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.first, '01.01.2026');
    await tester.enterText(textFields.last, '31.01.2026');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => dashboardBloc.add(captureAny(that: isA<DashboardPeriodChanged>())),
    ).captured;
    expect(captured, hasLength(1));
    final event = captured.single as DashboardPeriodChanged;
    expect(event.period, 'custom');
    expect(event.startDate, DateTime(2026, 1, 1));
    expect(event.endDate, DateTime(2026, 1, 31));
  });
}
