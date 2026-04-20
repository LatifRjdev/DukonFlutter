import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/blocs/zakat/zakat_bloc.dart';
import 'package:dokonpro/presentation/blocs/zakat/zakat_event.dart';
import 'package:dokonpro/presentation/blocs/zakat/zakat_state.dart';
import 'package:dokonpro/presentation/pages/zakat/zakat_settings_page.dart';
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

  Widget page() => const ZakatSettingsPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<ZakatBloc>.value(value: zakatBloc),
        ],
        child: child,
      );

  group('ZakatSettingsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'zakat_settings_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'zakat_settings_dark');
    });
  });
}
