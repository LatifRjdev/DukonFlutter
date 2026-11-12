import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/errors/app_message.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dukonpro/presentation/pages/settings/delete_account_page.dart';
import 'package:dukonpro/presentation/widgets/common/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// Account deletion is a Google Play requirement, and it is irreversible. What
// these tests pin down is the part a refactor can quietly break: that the
// screen cannot fire without a password, that it passes on the password the
// user actually typed, and that each of the two refusals the server can give
// is reported in words the user can act on.
//
// The last point is the regression guard for a decision made on the server:
// a wrong password returns 403, not 401, because the Dio interceptor treats
// any 401 as an expired token and would refresh and replay the DELETE. If
// someone "simplifies" the bloc's error mapping back to the generic
// mapErrorToAppMessage, these two tests fail — they assert the specific text
// and assert the generic text is absent.

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthInitial());
  });

  tearDown(() => authBloc.close());

  /// Pumps the page behind a real GoRouter, because a successful deletion
  /// navigates to the login route — a bare MaterialApp would throw there.
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/settings/delete-account',
      routes: [
        GoRoute(
          path: '/settings/delete-account',
          builder: (context, state) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const DeleteAccountPage(),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Login screen')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  AppButton confirmButton(WidgetTester tester) => tester.widget<AppButton>(
    find.widgetWithText(AppButton, 'Удалить аккаунт навсегда'),
  );

  testWidgets('should name what is destroyed when the screen opens', (
    tester,
  ) async {
    await pump(tester);

    // Play requires the consequences to be stated, not implied. The specific
    // nouns matter: an account-only warning would understate it.
    expect(find.textContaining('необратимо'), findsOneWidget);
    expect(find.textContaining('магазины'), findsOneWidget);
    expect(find.textContaining('продажи'), findsOneWidget);
  });

  testWidgets('should disable the confirm button when no password is typed', (
    tester,
  ) async {
    await pump(tester);

    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('should enable the confirm button when a password is typed', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField), 'hunter2');
    await tester.pump();

    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('should send the typed password when deletion is confirmed', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField), 'hunter2');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, 'Удалить аккаунт навсегда'));
    await tester.pump();

    verify(
      () => authBloc.add(const AuthAccountDeletionRequested('hunter2')),
    ).called(1);
  });

  testWidgets(
    'should say the password was wrong when the server refuses with 403',
    (tester) async {
      whenListen(
        authBloc,
        Stream.fromIterable([
          AuthLoading(),
          const AuthFailure(AppMessage.accountDeletionWrongPassword),
        ]),
        initialState: AuthInitial(),
      );

      await pump(tester);

      expect(find.text('Неверный пароль'), findsOneWidget);
      // The generic 403 text, which says nothing the user can act on.
      expect(find.text('Недостаточно прав'), findsNothing);
    },
  );

  testWidgets(
    'should say staff remain when the server refuses with 400',
    (tester) async {
      whenListen(
        authBloc,
        Stream.fromIterable([
          AuthLoading(),
          const AuthFailure(AppMessage.accountDeletionStaffRemain),
        ]),
        initialState: AuthInitial(),
      );

      await pump(tester);

      expect(find.textContaining('остались сотрудники'), findsOneWidget);
      // The generic 400 text.
      expect(find.text('Некорректные данные'), findsNothing);
    },
  );

  testWidgets('should return to login when the account was deleted', (
    tester,
  ) async {
    whenListen(
      authBloc,
      Stream.fromIterable([AuthLoading(), AuthAccountDeleted()]),
      initialState: AuthInitial(),
    );

    await pump(tester);

    expect(find.text('Login screen'), findsOneWidget);
  });
}
