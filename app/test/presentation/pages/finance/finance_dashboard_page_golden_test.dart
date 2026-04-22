import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/finance/finance_bloc.dart';
import 'package:dokonpro/presentation/blocs/finance/finance_event.dart';
import 'package:dokonpro/presentation/blocs/finance/finance_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/finance/finance_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockFinanceBloc extends MockBloc<FinanceEvent, FinanceState>
    implements FinanceBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockFinanceBloc financeBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    financeBloc = MockFinanceBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => financeBloc.state).thenReturn(FinanceInitial());
  });

  // Pass storeId explicitly to avoid StoreBloc lazy-load path during golden render.
  Widget page() =>
      const FinanceDashboardPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<FinanceBloc>.value(value: financeBloc),
        ],
        child: child,
      );

  group('FinanceDashboardPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'finance_dashboard_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'finance_dashboard_dark');
    });
  });
}
