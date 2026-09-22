// Regression coverage for the 2026-09-21 manual QA finding: deleting a
// payroll adjustment had no UI trigger. This covers PayrollPage's half:
// tapping the delete icon opens a confirmation dialog, "Отмена" dispatches
// nothing, "Удалить" dispatches RemoveAdjustment with the correct ids and
// closes the dialog.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/payroll_adjustment.dart';
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
import 'package:mocktail/mocktail.dart';

class _MockPayrollBloc extends MockBloc<PayrollEvent, PayrollState>
    implements PayrollBloc {}

void main() {
  late _MockPayrollBloc payrollBloc;

  const adjustment = PayrollAdjustment(
    id: 'adj-1',
    type: 'BONUS',
    amount: 200,
    description: 'Премия за план',
  );
  final entry = const PayrollEntry(
    id: 'e1',
    staffId: 'staff-1',
    staffName: 'Ali Valiev',
    totalAmount: 1200,
    adjustments: [adjustment],
  );
  final period = PayrollPeriod(
    id: 'period-1',
    month: 4,
    year: 2026,
    status: 'CALCULATED',
    totalAmount: 1200,
    staffCount: 1,
    payrolls: [entry],
  );

  setUpAll(() {
    registerFallbackValue(const LoadPayrollPeriods(storeId: ''));
  });

  setUp(() {
    payrollBloc = _MockPayrollBloc();
    when(() => payrollBloc.state)
        .thenReturn(PayrollPeriodDetailLoaded(period: period));
  });

  tearDown(() {
    payrollBloc.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<PayrollBloc>.value(
          value: payrollBloc,
          child: const PayrollPage(storeId: 'store-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'tapping the delete icon opens a confirmation dialog showing the '
      'adjustment description and amount', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(AlertDialog);
    expect(dialogFinder, findsOneWidget);
    expect(find.text('Удалить корректировку?'), findsOneWidget);
    // The underlying PayrollStaffCard stays mounted beneath the dialog
    // barrier and already renders the same description/amount in its
    // adjustment row, so a bare find.textContaining would match twice —
    // scope to the dialog to assert on its content specifically.
    expect(
      find.descendant(
          of: dialogFinder, matching: find.textContaining('Премия за план')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: dialogFinder, matching: find.textContaining('+200')),
      findsOneWidget,
    );
  });

  testWidgets('tapping "Отмена" closes the dialog without dispatching anything',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => payrollBloc.add(any(that: isA<RemoveAdjustment>())));
  });

  testWidgets(
      'tapping "Удалить" dispatches RemoveAdjustment with the correct ids '
      'and closes the dialog', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => payrollBloc.add(const RemoveAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          adjustmentId: 'adj-1',
        ))).called(1);
  });
}
