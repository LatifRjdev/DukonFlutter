import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_bloc.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_event.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_state.dart';
import 'package:dukonpro/presentation/pages/finance/add_expense_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockExpenseBloc extends MockBloc<ExpenseEvent, ExpenseState>
    implements ExpenseBloc {}

void main() {
  late MockExpenseBloc expenseBloc;

  setUp(() {
    expenseBloc = MockExpenseBloc();
    when(() => expenseBloc.state).thenReturn(ExpenseInitial());
  });

  // Frozen "now" → _date deterministic across runs.
  final fixedNow = DateTime(2024, 3, 15, 10, 30);
  Widget page() => AddExpensePage(storeId: 'test-store-id', now: () => fixedNow);

  Widget wrapWithBlocs(Widget child) => BlocProvider<ExpenseBloc>.value(
        value: expenseBloc,
        child: child,
      );

  group('AddExpensePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'add_expense_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'add_expense_dark');
    });
  });
}
