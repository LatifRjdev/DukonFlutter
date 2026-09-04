// Regression test for post-plan SPEC.md audit finding #2: every payroll
// action (pay individual/all, add/remove adjustment, calculate) re-emits
// PayrollLoading while it runs, which used to tear down whichever view
// (periods list or period detail) was on screen down to a bare spinner.
// Also, AppErrorWidget's Retry button always reloaded the periods list
// (LoadPayrollPeriods) even when the error happened while viewing a period
// detail, silently dropping the user back to the list instead of retrying
// what actually failed.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/payroll_entry.dart';
import 'package:dukonpro/domain/entities/payroll_period.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_bloc.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_event.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_state.dart';
import 'package:dukonpro/presentation/pages/payroll/payroll_page.dart';
import 'package:dukonpro/presentation/widgets/common/app_error_widget.dart';
import 'package:dukonpro/presentation/widgets/payroll/payroll_staff_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayrollBloc extends MockBloc<PayrollEvent, PayrollState>
    implements PayrollBloc {}

void main() {
  late _MockPayrollBloc payrollBloc;
  late StreamController<PayrollState> stateController;

  final entry = const PayrollEntry(
    id: 'e1',
    staffId: 'staff-1',
    staffName: 'Ali Valiev',
    totalAmount: 1000,
    isPaid: false,
  );
  final period = PayrollPeriod(
    id: 'period-1',
    month: 4,
    year: 2026,
    status: 'CALCULATED',
    totalAmount: 1000,
    staffCount: 1,
    payrolls: [entry],
  );

  setUpAll(() {
    registerFallbackValue(const LoadPayrollPeriods(storeId: ''));
  });

  setUp(() {
    payrollBloc = _MockPayrollBloc();
    stateController = StreamController<PayrollState>.broadcast();
  });

  tearDown(() async {
    await stateController.close();
    await payrollBloc.close();
  });

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<PayrollBloc>.value(value: payrollBloc, child: child),
      );

  testWidgets(
      'keeps the period detail visible (not a bare full-page spinner) when '
      'paying an entry triggers PayrollLoading, and hides its Pay action '
      'while busy', (tester) async {
    final loaded = PayrollPeriodDetailLoaded(period: period);
    whenListen<PayrollState>(
      payrollBloc,
      stateController.stream,
      initialState: loaded,
    );

    await tester.pumpWidget(wrap(const PayrollPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PayrollStaffCard), findsOneWidget);
    expect(find.text('Выплатить'), findsOneWidget);

    // Simulate PayrollBloc._onPayIndividual's own PayrollLoading emission.
    stateController.add(PayrollLoading());
    await tester.pump();
    await tester.pump();

    // The fix: since the period detail already loaded once, this
    // PayrollLoading must NOT unmount it into a bare full-page spinner —
    // the detail view (and its total/back/adjustment header) stays mounted.
    expect(find.byType(PayrollStaffCard), findsOneWidget);
    expect(find.textContaining('Итого:'), findsOneWidget);
    // The per-entry "Выплатить" action is hidden while busy (PayrollStaffCard
    // only renders it when onPay != null).
    expect(find.text('Выплатить'), findsNothing);
    // The period-detail header's back and add-adjustment actions are
    // disabled while busy too (MonthSelector's own prev/next-month
    // IconButtons are unrelated and stay active, so target these two by
    // icon rather than asserting on every IconButton on screen).
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back)).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add_circle_outline)).onPressed,
      isNull,
    );
  });

  testWidgets(
      'shows the full-page spinner for the very first PayrollLoading, '
      'before anything has ever loaded', (tester) async {
    whenListen<PayrollState>(
      payrollBloc,
      stateController.stream,
      initialState: PayrollLoading(),
    );

    await tester.pumpWidget(wrap(const PayrollPage(storeId: 'store-1')));
    await tester.pump();

    expect(find.byType(PayrollStaffCard), findsNothing);
    // The full-page spinner plus the "Рассчитать" button's own (inactive)
    // state — assert at least one spinner is present.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets(
      'retrying after an error while viewing a period detail reloads that '
      'period, not the periods list', (tester) async {
    final loaded = PayrollPeriodDetailLoaded(period: period);
    whenListen<PayrollState>(
      payrollBloc,
      stateController.stream,
      initialState: loaded,
    );

    await tester.pumpWidget(wrap(const PayrollPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    // Simulate the pay action failing.
    stateController.add(const PayrollError('Network error'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppErrorWidget),
        matching: find.text('Network error'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Повторить'));
    await tester.pump();

    // initState unconditionally dispatches LoadPayrollPeriods on mount, so
    // only capture the LoadPayrollPeriod (singular — period detail) calls
    // to isolate what the retry itself dispatched.
    final captured = verify(() => payrollBloc.add(
          captureAny(that: isA<LoadPayrollPeriod>()),
        )).captured;
    expect(captured, hasLength(1));
    final dispatched = captured.single as LoadPayrollPeriod;
    expect(dispatched.periodId, 'period-1');
    expect(dispatched.storeId, 'store-1');
  });

  testWidgets(
      'retrying after an error while viewing the periods list reloads the '
      'periods list', (tester) async {
    const loaded = PayrollPeriodsLoaded(periods: []);
    whenListen<PayrollState>(
      payrollBloc,
      stateController.stream,
      initialState: loaded,
    );

    await tester.pumpWidget(wrap(const PayrollPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    stateController.add(const PayrollError('Network error'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppErrorWidget),
        matching: find.text('Network error'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Повторить'));
    await tester.pump();

    final captured = verify(() => payrollBloc.add(captureAny())).captured;
    // The initial LoadPayrollPeriods from initState plus the retry.
    expect(captured, hasLength(2));
    expect(captured.every((e) => e is LoadPayrollPeriods), isTrue);
  });
}
