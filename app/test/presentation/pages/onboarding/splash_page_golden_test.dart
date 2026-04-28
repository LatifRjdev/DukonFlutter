import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dukonpro/presentation/pages/onboarding/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// Pump the splash page — avoids pumpAndSettle timeout caused
/// by the unbounded CircularProgressIndicator animation.
Future<void> _pumpSplash(
  WidgetTester tester,
  Widget page,
  Brightness brightness,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: page,
    ),
  );
  // Use pump(Duration.zero) twice to render one frame without waiting for
  // the CircularProgressIndicator to settle (it never would).
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthInitial());
  });

  tearDown(() {
    authBloc.close();
  });

  Widget page() => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const SplashPage(),
      );

  // Use a no-op customPump to avoid pumpAndSettle timeout caused by the
  // unbounded CircularProgressIndicator animation on the splash screen.
  Future<void> noPump(WidgetTester t) async {}

  group('SplashPage goldens', () {
    testGoldens('light theme', (tester) async {
      await _pumpSplash(tester, page(), Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'splash_light', customPump: noPump);
    });

    testGoldens('dark theme', (tester) async {
      await _pumpSplash(tester, page(), Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'splash_dark', customPump: noPump);
    });
  });
}
