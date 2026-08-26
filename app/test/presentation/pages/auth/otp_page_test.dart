// Regression coverage for SPEC.md #3: verifying an OTP code on the
// forgot-password flow must route to CreatePasswordPage, NOT dispatch
// AuthVerifyOtpRequested (which logs the user into their OLD account and
// redirects to /home instead of letting them set a new password).
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dukonpro/presentation/pages/auth/create_password_page.dart';
import 'package:dukonpro/presentation/pages/auth/otp_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  const phone = '+992901234567';
  late _MockAuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(AuthCheckRequested());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthInitial());
  });

  tearDown(() => authBloc.close());

  // Mirrors the real /otp and /create-password route builders in
  // app_router.dart so navigation + extra-passing is exercised faithfully.
  Future<void> pumpOtpPage(WidgetTester tester, {required String purpose}) async {
    final router = GoRouter(
      initialLocation: '/otp',
      routes: [
        GoRoute(
          path: '/otp',
          builder: (_, _) => OtpPage(phone: phone, purpose: purpose),
        ),
        GoRoute(
          path: '/create-password',
          builder: (_, state) {
            final extra = state.extra as Map<String, String>? ?? {};
            return CreatePasswordPage(
              phone: extra['phone'] ?? '',
              otp: extra['otp'] ?? '',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterOtp(WidgetTester tester, String code) async {
    final fields = find.byType(TextFormField);
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(fields.at(i), code[i]);
    }
    await tester.pumpAndSettle();
  }

  test('default purpose is login (preserves current behavior)', () {
    expect(const OtpPage(phone: phone).purpose, OtpPage.purposeLogin);
  });

  group('OtpPage purpose=login (default) — existing OTP-login behavior', () {
    testWidgets(
        'dispatches AuthVerifyOtpRequested with phone+code and does not '
        'navigate to create-password', (tester) async {
      await pumpOtpPage(tester, purpose: OtpPage.purposeLogin);

      await enterOtp(tester, '123456');

      final captured = verify(() => authBloc.add(captureAny(
            that: isA<AuthVerifyOtpRequested>(),
          ))).captured;
      expect(captured, hasLength(1));
      final event = captured.single as AuthVerifyOtpRequested;
      expect(event.phone, phone);
      expect(event.code, '123456');

      expect(find.byType(CreatePasswordPage), findsNothing);
    });
  });

  group('OtpPage purpose=passwordReset — SPEC.md #3 fix', () {
    testWidgets(
        'navigates to /create-password with phone+otp instead of logging '
        'the user in via AuthVerifyOtpRequested', (tester) async {
      await pumpOtpPage(tester, purpose: OtpPage.purposePasswordReset);

      await enterOtp(tester, '654321');

      verifyNever(
          () => authBloc.add(any(that: isA<AuthVerifyOtpRequested>())));

      expect(find.byType(CreatePasswordPage), findsOneWidget);
      final createPasswordPage =
          tester.widget<CreatePasswordPage>(find.byType(CreatePasswordPage));
      expect(createPasswordPage.phone, phone);
      expect(createPasswordPage.otp, '654321');
    });
  });
}
