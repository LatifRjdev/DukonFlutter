// Regression test for the 2026-09-21 manual QA finding: tapping "Добавить
// корректировку" on a payroll period detail crashed with "type
// '_Map<String, String>' is not a subtype of type 'String?' in type cast".
// Root cause: the IconButton passed `extra: {'storeId': ..., 'periodId':
// ...}` (a Map) to context.push, but the /payroll/:periodId/adjustment
// route in app_router.dart does `state.extra as String? ?? ''`, matching
// the convention every sibling route uses (extra is always a plain
// storeId string; periodId already comes from the path parameter). The
// mismatched Map extra threw inside the route builder — GoRoute builders
// have no error boundary, so this crashed to a bare red error screen.
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
      'tapping "Добавить корректировку" reaches the adjustment route '
      'without crashing on the extra payload', (tester) async {
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
        // Mirrors app_router.dart's real extraction logic exactly.
        GoRoute(
          path: '/payroll/:periodId/adjustment',
          builder: (context, state) {
            final periodId = state.pathParameters['periodId']!;
            final storeId = state.extra as String? ?? '';
            return Scaffold(
              body: Text('Adjustment for $periodId / store=$storeId'),
            );
          },
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

    expect(tester.takeException(), isNull);
    expect(find.text('Adjustment for period-1 / store=store-1'),
        findsOneWidget);
  });
}
