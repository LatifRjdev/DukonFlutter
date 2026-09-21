import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_bloc.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_event.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_state.dart';
import 'package:dukonpro/presentation/pages/finance/add_investment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockInvestmentBloc extends MockBloc<InvestmentEvent, InvestmentState>
    implements InvestmentBloc {}

class _FakeInvestmentEvent extends Fake implements InvestmentEvent {}

void main() {
  late MockInvestmentBloc investmentBloc;

  setUpAll(() {
    registerFallbackValue(_FakeInvestmentEvent());
  });

  setUp(() {
    investmentBloc = MockInvestmentBloc();
    when(() => investmentBloc.state).thenReturn(InvestmentInitial());
    if (sl.isRegistered<InvestmentBloc>()) sl.unregister<InvestmentBloc>();
    sl.registerFactory<InvestmentBloc>(() => investmentBloc);
  });

  tearDown(() {
    if (sl.isRegistered<InvestmentBloc>()) sl.unregister<InvestmentBloc>();
  });

  final fixedNow = DateTime(2024, 3, 15, 10, 30);
  Widget page() =>
      AddInvestmentPage(storeId: 'test-store-id', now: () => fixedNow);

  // Regression test for a bug found during the 2026-09-21 manual QA pass:
  // tapping "Сохранить" with valid data silently did nothing on-device — no
  // network call, no snackbar, no navigation. Root cause (found via `flutter
  // run` + live exception log): _submit() read InvestmentBloc from the
  // State's own `context`, which sits *above* the BlocProvider the widget
  // declares in its own build() — Provider lookups only search ancestors, so
  // this threw ProviderNotFoundException synchronously inside the InkWell's
  // onTap handler. Flutter's gesture binding catches and logs exceptions
  // thrown from gesture callbacks rather than crashing, so nothing visible
  // happened at all. This test fills the form and taps Save, then asserts
  // the bloc actually received the event — the old code fails not by
  // assertion but by throwing ProviderNotFoundException during tap.
  testWidgets(
      'tapping Сохранить with valid data dispatches InvestmentCreateRequested '
      'without throwing (regression: used to throw ProviderNotFoundException, '
      'silently swallowed by the gesture binding)', (tester) async {
    await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

    await tester.enterText(find.byType(TextField).at(0), 'Test Investment');
    await tester.enterText(find.byType(TextField).at(2), '1000');
    await tester.enterText(find.byType(TextField).at(4), 'Test Investor');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final captured = verify(() => investmentBloc.add(captureAny())).captured;
    expect(captured, hasLength(1));
    final event = captured.single as InvestmentCreateRequested;
    expect(event.storeId, 'test-store-id');
    expect(event.data['name'], 'Test Investment');
    expect(event.data['amount'], 1000.0);
    expect(event.data['investorName'], 'Test Investor');
  });
}
