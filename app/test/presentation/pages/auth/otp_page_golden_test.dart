import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dokonpro/presentation/pages/auth/otp_page.dart';
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

  Widget page() => const OtpPage(phone: '+992901234567');

  Widget wrapWithBlocs(Widget child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: child,
      );

  group('OtpPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'otp_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'otp_dark');
    });
  });
}
