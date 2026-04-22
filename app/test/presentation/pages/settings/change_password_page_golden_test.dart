import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dokonpro/presentation/pages/settings/change_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

void main() {
  late _MockSettingsBloc settingsBloc;

  setUp(() {
    settingsBloc = _MockSettingsBloc();
    when(() => settingsBloc.state).thenReturn(SettingsInitial());
  });

  tearDown(() {
    settingsBloc.close();
  });

  Widget page() => const ChangePasswordPage();

  Widget wrapWithBloc(Widget child) => BlocProvider<SettingsBloc>.value(
        value: settingsBloc,
        child: child,
      );

  group('ChangePasswordPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBloc,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'change_password_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBloc,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'change_password_dark');
    });
  });
}
