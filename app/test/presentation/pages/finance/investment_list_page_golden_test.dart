import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_bloc.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_event.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_state.dart';
import 'package:dukonpro/presentation/pages/finance/investment_list_page.dart';
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
    // Register mock in GetIt so InvestmentListPage's internal BlocProvider
    // create: returns the mock without touching any real datasources.
    if (sl.isRegistered<InvestmentBloc>()) sl.unregister<InvestmentBloc>();
    sl.registerFactory<InvestmentBloc>(() => investmentBloc);
  });

  tearDown(() {
    if (sl.isRegistered<InvestmentBloc>()) sl.unregister<InvestmentBloc>();
  });

  Widget page() => const InvestmentListPage(storeId: 'test-store-id');

  group('InvestmentListPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'investment_list_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'investment_list_dark');
    });
  });
}
