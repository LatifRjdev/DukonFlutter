import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/dashboard/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  const page = MorePage();

  Widget wrapWithBlocs(Widget child) => BlocProvider<StoreBloc>.value(
        value: storeBloc,
        child: child,
      );

  group('MorePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page,
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'more_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page,
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'more_dark');
    });
  });
}
