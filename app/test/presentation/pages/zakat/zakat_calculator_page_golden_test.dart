import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_event.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_state.dart';
import 'package:dukonpro/presentation/pages/zakat/zakat_calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockZakatBloc extends MockBloc<ZakatEvent, ZakatState>
    implements ZakatBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockZakatBloc zakatBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    zakatBloc = MockZakatBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => zakatBloc.state).thenReturn(ZakatInitial());
  });

  Widget page() => const ZakatCalculatorPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<ZakatBloc>.value(value: zakatBloc),
        ],
        child: child,
      );

  group('ZakatCalculatorPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'zakat_calculator_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'zakat_calculator_dark');
    });
  });
}
