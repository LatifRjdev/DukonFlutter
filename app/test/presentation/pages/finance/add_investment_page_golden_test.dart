import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/blocs/investment/investment_bloc.dart';
import 'package:dokonpro/presentation/blocs/investment/investment_event.dart';
import 'package:dokonpro/presentation/blocs/investment/investment_state.dart';
import 'package:dokonpro/presentation/pages/finance/add_investment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockInvestmentBloc extends MockBloc<InvestmentEvent, InvestmentState>
    implements InvestmentBloc {}

void main() {
  late MockInvestmentBloc investmentBloc;

  setUp(() {
    investmentBloc = MockInvestmentBloc();
    when(() => investmentBloc.state).thenReturn(InvestmentInitial());
    // Register mock in GetIt so AddInvestmentPage's internal BlocProvider
    // create: returns the mock without touching any real datasources.
    if (sl.isRegistered<InvestmentBloc>()) sl.unregister<InvestmentBloc>();
    sl.registerFactory<InvestmentBloc>(() => investmentBloc);
  });

  tearDown(() {
    if (sl.isRegistered<InvestmentBloc>()) sl.unregister<InvestmentBloc>();
  });

  Widget page() => const AddInvestmentPage(storeId: 'test-store-id');

  group('AddInvestmentPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'add_investment_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'add_investment_dark');
    });
  });
}
