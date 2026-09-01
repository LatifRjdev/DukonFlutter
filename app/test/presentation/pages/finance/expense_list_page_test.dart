// Regression coverage for SPEC.md #31 and #32:
// - #31: tapping delete on an expense used to delete it immediately with no
//   confirmation step — a single accidental tap permanently destroyed data.
// - #32: a failed expense deletion used to be silently swallowed — no error
//   shown, and the whole list would go blank while the delete was pending
//   (ExpenseLoading replaced the already-loaded list, so a failure had no
//   list to fall back to).
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/expense.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_bloc.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_event.dart';
import 'package:dukonpro/presentation/blocs/expense/expense_state.dart';
import 'package:dukonpro/presentation/pages/finance/expense_list_page.dart';
import 'package:dukonpro/presentation/widgets/finance/expense_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExpenseBloc extends MockBloc<ExpenseEvent, ExpenseState>
    implements ExpenseBloc {}

void main() {
  late _MockExpenseBloc expenseBloc;
  late StreamController<ExpenseState> stateController;

  final expense = Expense(
    id: 'exp-1',
    storeId: 'test-store-id',
    category: 'RENT',
    amount: 500,
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );

  final loaded = ExpenseLoaded(expenses: [expense], total: 1, totalPages: 1);

  setUpAll(() {
    registerFallbackValue(const ExpenseListRequested(storeId: 'fallback'));
  });

  setUp(() {
    expenseBloc = _MockExpenseBloc();
    stateController = StreamController<ExpenseState>.broadcast();
    whenListen(expenseBloc, stateController.stream, initialState: loaded);
  });

  tearDown(() async {
    await stateController.close();
    await expenseBloc.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<ExpenseBloc>.value(
          value: expenseBloc,
          child: const ExpenseListPage(storeId: 'test-store-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'does not dispatch ExpenseDeleteRequested until the confirm dialog\'s '
      'destructive button is tapped (SPEC.md #31)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Удалить расход?'), findsOneWidget);
    verifyNever(
        () => expenseBloc.add(any(that: isA<ExpenseDeleteRequested>())));
  });

  testWidgets(
      'dispatches ExpenseDeleteRequested with the right id after the '
      'destructive button is tapped (SPEC.md #31)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    final captured = verify(() => expenseBloc.add(
        captureAny(that: isA<ExpenseDeleteRequested>()))).captured;
    expect(captured, hasLength(1));
    final event = captured.single as ExpenseDeleteRequested;
    expect(event.storeId, 'test-store-id');
    expect(event.id, 'exp-1');
  });

  testWidgets(
      'cancelling the confirm dialog closes it and dispatches nothing '
      '(SPEC.md #31)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(
        () => expenseBloc.add(any(that: isA<ExpenseDeleteRequested>())));
  });

  testWidgets(
      'shows an error snackbar and keeps the expense in the list when '
      'deletion fails (SPEC.md #32)', (tester) async {
    await pumpApp(tester);

    // Sanity check: the expense is on screen before the failed delete.
    expect(find.byType(ExpenseCard), findsOneWidget);

    stateController
        .add(const ExpenseDeleteFailure('Ошибка сервера — попробуйте позже'));
    await tester.pump();
    // Let the snackbar's entrance animation settle so its text is mounted.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ошибка сервера — попробуйте позже'), findsOneWidget);
    // The failure must not have wiped the list off screen: the expense
    // that failed to delete is still visible.
    expect(find.byType(ExpenseCard), findsOneWidget);
  });
}
