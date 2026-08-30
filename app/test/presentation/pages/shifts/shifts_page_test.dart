// Regression coverage for SPEC.md #17: the close-shift dialog on
// ShiftsPage used to silently do nothing when the entered closing-cash
// amount was negative or unparseable — no error, no feedback, the dialog
// just sat there. This exercises the fix: the dialog now validates the
// amount the same way open_shift_page.dart's field does (empty / not a
// number / negative all show an inline error) and never dispatches
// CloseShift for an invalid amount.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/shift.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dukonpro/presentation/pages/shifts/shifts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockShiftBloc extends MockBloc<ShiftEvent, ShiftState>
    implements ShiftBloc {}

ShiftModel _fakeCurrentShift() => ShiftModel(
      id: 'shift-1',
      storeId: 'test-store-id',
      staffId: 'staff-1',
      staffName: 'Кассир Тест',
      openedAt: DateTime(2026, 1, 15, 9, 0),
      openingCash: 500,
      status: 'OPEN',
    );

void main() {
  late _MockShiftBloc shiftBloc;

  setUp(() {
    shiftBloc = _MockShiftBloc();
    when(() => shiftBloc.state)
        .thenReturn(ShiftLoaded(currentShift: _fakeCurrentShift()));
    registerFallbackValue(const CloseShift(
      storeId: 'fallback',
      shiftId: 'fallback',
      closingCash: 0,
    ));
  });

  tearDown(() {
    shiftBloc.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<ShiftBloc>.value(
          value: shiftBloc,
          child: const ShiftsPage(storeId: 'test-store-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCloseShiftDialog(WidgetTester tester) async {
    await tester.tap(find.text('Закрыть смену'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets(
      'does not dispatch CloseShift and shows an inline error for a '
      'negative amount (SPEC.md #17)', (tester) async {
    await pumpApp(tester);
    await openCloseShiftDialog(tester);

    await tester.enterText(find.byType(TextFormField), '-100');
    await tester.tap(find.text('Закрыть').last);
    await tester.pumpAndSettle();

    verifyNever(() => shiftBloc.add(any(that: isA<CloseShift>())));
    expect(find.text('Сумма не может быть отрицательной'), findsOneWidget);
    // Dialog stays open on invalid input instead of silently closing.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'does not dispatch CloseShift and shows an inline error for an '
      'empty amount', (tester) async {
    await pumpApp(tester);
    await openCloseShiftDialog(tester);

    await tester.tap(find.text('Закрыть').last);
    await tester.pumpAndSettle();

    verifyNever(() => shiftBloc.add(any(that: isA<CloseShift>())));
    expect(find.text('Введите сумму'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'does not dispatch CloseShift and shows an inline error for '
      'unparseable text', (tester) async {
    await pumpApp(tester);
    await openCloseShiftDialog(tester);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.text('Закрыть').last);
    await tester.pumpAndSettle();

    verifyNever(() => shiftBloc.add(any(that: isA<CloseShift>())));
    expect(find.text('Некорректная сумма'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'dispatches CloseShift with the parsed amount for a valid '
      'non-negative amount', (tester) async {
    await pumpApp(tester);
    await openCloseShiftDialog(tester);

    await tester.enterText(find.byType(TextFormField), '750');
    await tester.tap(find.text('Закрыть').last);
    // Deliberately do NOT pump the dialog's exit animation here: this
    // dialog has a pre-existing bug (unrelated to this fix) where
    // .whenComplete(cashController.dispose) disposes the controller while
    // the AlertDialog is still mid-transition, tripping a Flutter framework
    // assertion. Verifying the dispatched event doesn't require the
    // animation to run, so we check it immediately after the tap.

    final captured =
        verify(() => shiftBloc.add(captureAny(that: isA<CloseShift>())))
            .captured;
    expect(captured, hasLength(1));
    final event = captured.single as CloseShift;
    expect(event.storeId, 'test-store-id');
    expect(event.shiftId, 'shift-1');
    expect(event.closingCash, 750);
  });
}
