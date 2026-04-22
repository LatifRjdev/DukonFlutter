import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/expense/expense_bloc.dart';
import 'package:dokonpro/presentation/blocs/expense/expense_event.dart';
import 'package:dokonpro/presentation/blocs/expense/expense_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/finance/expense_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockExpenseBloc extends MockBloc<ExpenseEvent, ExpenseState>
    implements ExpenseBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockExpenseBloc expenseBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    expenseBloc = MockExpenseBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => expenseBloc.state).thenReturn(ExpenseInitial());
  });

  Widget page() => const ExpenseListPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<ExpenseBloc>.value(value: expenseBloc),
        ],
        child: child,
      );

  group('ExpenseListPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'expense_list_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'expense_list_dark');
    });
  });
}
