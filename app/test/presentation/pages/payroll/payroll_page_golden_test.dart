import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/payroll/payroll_bloc.dart';
import 'package:dokonpro/presentation/blocs/payroll/payroll_event.dart';
import 'package:dokonpro/presentation/blocs/payroll/payroll_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/payroll/payroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockPayrollBloc extends MockBloc<PayrollEvent, PayrollState>
    implements PayrollBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockPayrollBloc payrollBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    payrollBloc = MockPayrollBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => payrollBloc.state).thenReturn(PayrollInitial());
  });

  Widget page() => const PayrollPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<PayrollBloc>.value(value: payrollBloc),
        ],
        child: child,
      );

  group('PayrollPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'payroll_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'payroll_dark');
    });
  });
}
