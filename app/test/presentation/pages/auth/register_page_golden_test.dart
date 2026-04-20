import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dokonpro/presentation/pages/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthInitial());
  });

  tearDown(() {
    authBloc.close();
  });

  Widget page() => const RegisterPage();

  Widget wrapWithBlocs(Widget child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: child,
      );

  group('RegisterPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'register_light');
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
      await screenMatchesGolden(tester, 'register_dark');
    });
  });
}
