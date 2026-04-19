import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/domain/entities/user.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dokonpro/presentation/pages/settings/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

User _fakeUser() => User(
      id: 'test-user-id',
      phone: '+992900000000',
      name: 'Test User',
      email: 'test@example.com',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  late _MockSettingsBloc settingsBloc;

  setUp(() {
    settingsBloc = _MockSettingsBloc();
    when(() => settingsBloc.state)
        .thenReturn(SettingsLoaded(_fakeUser()));
  });

  tearDown(() {
    settingsBloc.close();
  });

  Widget page() => const EditProfilePage();

  Widget wrapWithBloc(Widget child) => BlocProvider<SettingsBloc>.value(
        value: settingsBloc,
        child: child,
      );

  group('EditProfilePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'edit_profile_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'edit_profile_dark');
    });
  });
}
