// Regression test for the 2026-09-21 manual QA finding: PayrollBloc is a
// single instance shared between PayrollPage and AddAdjustmentPage. A bare
// context.push to the adjustment route left PayrollPage mounted underneath
// without ever re-requesting the period, so if AddAdjustment failed (bloc
// left in PayrollError after AddAdjustmentPage's own snackbar) and the user
// then navigated back, PayrollPage's BlocBuilder rendered that stale
// PayrollError as a full-page "Некорректные данные" replacement of the
// period detail the user was already looking at — even though nothing was
// wrong with it. Fix: explicitly reload the period detail once the pushed
// adjustment route returns, so PayrollPage never renders whatever state a
// child route left the shared bloc in. Same root-cause class and fix
// pattern as staff_list_reload_test.dart / debts_overview_reload_test.dart.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/payroll_entry.dart';
import 'package:dukonpro/domain/entities/payroll_period.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_bloc.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_event.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_state.dart';
import 'package:dukonpro/presentation/pages/payroll/payroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayrollBloc extends MockBloc<PayrollEvent, PayrollState>
    implements PayrollBloc {}

void main() {
  late _MockPayrollBloc payrollBloc;

  final entry = const PayrollEntry(
    id: 'e1',
    staffId: 'staff-1',
    staffName: 'Test_Cashier_1',
    totalAmount: 1000,
    isPaid: false,
  );
  final period = PayrollPeriod(
    id: 'period-1',
    month: 9,
    year: 2026,
    status: 'CALCULATED',
    totalAmount: 1000,
    staffCount: 1,
    payrolls: [entry],
  );

  setUp(() {
    payrollBloc = _MockPayrollBloc();
    when(() => payrollBloc.state)
        .thenReturn(PayrollPeriodDetailLoaded(period: period));
  });

  tearDown(() {
    payrollBloc.close();
  });

  testWidgets(
      'returning from the adjustment screen re-requests the period so a '
      'failed add-adjustment left in the shared bloc does not surface as a '
      'full-page error on the period detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/payroll',
      routes: [
        GoRoute(
          path: '/payroll',
          builder: (context, state) => BlocProvider<PayrollBloc>.value(
            value: payrollBloc,
            child: const PayrollPage(storeId: 'store-1'),
          ),
        ),
        GoRoute(
          path: '/payroll/:periodId/adjustment',
          builder: (context, state) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Text('Adjustment Stub'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Adjustment Stub'), findsOneWidget);

    // Simulate the shared bloc having been left in PayrollError by a failed
    // AddAdjustment while the user was on the (stubbed) adjustment screen.
    when(() => payrollBloc.state).thenReturn(const PayrollError('Некорректные данные'));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(PayrollPage), findsOneWidget);
    verify(() => payrollBloc.add(const LoadPayrollPeriod(
          storeId: 'store-1',
          periodId: 'period-1',
        ))).called(1);
  });
}
