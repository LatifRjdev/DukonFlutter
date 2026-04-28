import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_bloc.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_event.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/debt/customer_debts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockDebtBloc extends MockBloc<DebtEvent, DebtState> implements DebtBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockDebtBloc debtBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    debtBloc = MockDebtBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => debtBloc.state).thenReturn(DebtInitial());
  });

  Widget page() => const CustomerDebtsPage(
        storeId: 'test-store-id',
        customerId: 'test-customer-id',
        customerName: 'Test Customer',
      );

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<DebtBloc>.value(value: debtBloc),
        ],
        child: child,
      );

  group('CustomerDebtsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'customer_debts_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'customer_debts_dark');
    });
  });
}
