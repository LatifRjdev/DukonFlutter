// Tests for lib/core/router/app_router.dart — the GoRouter configuration.
//
// Strategy: AppRouter.router is a process-wide singleton (`static final`)
// built once via `_buildRouter()`, and its `redirect` callback reads
// `sl<AuthLocalDatasource>()` / `sl<AuthRepository>()` (GetIt) fresh on every
// call rather than at construction time. That lets us register mocktail
// mocks into the real `sl` GetIt instance per-test and exercise the *actual*
// production redirect closure — no fork/reimplementation of the guard logic.
//
// To avoid instantiating full page widgets (which pull in their own blocs
// via GetIt and would require registering the app's entire DI graph), we
// drive routing through `AppRouter.router.configuration`: `findMatch()` to
// resolve a path against registered routes, and `redirect()` to run the
// same redirect pipeline GoRouter itself runs before building any page.
// This never builds LoginPage/HomePage/etc., so it works with only the two
// auth dependencies mocked.
//
// A BuildContext is required by GoRouter's redirect API (unused by this
// app's redirect logic itself, which only reads `state.uri.path`), so each
// test pumps a trivial throwaway widget purely to obtain one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/router/app_router.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/data/datasources/local/auth_local_datasource.dart';
import 'package:dukonpro/domain/repositories/auth_repository.dart';
import 'package:dukonpro/injection.dart' show sl;

class MockAuthLocalDatasource extends Mock implements AuthLocalDatasource {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthLocalDatasource authLocal;
  late MockAuthRepository authRepo;

  setUp(() {
    authLocal = MockAuthLocalDatasource();
    authRepo = MockAuthRepository();

    if (sl.isRegistered<AuthLocalDatasource>()) {
      sl.unregister<AuthLocalDatasource>();
    }
    if (sl.isRegistered<AuthRepository>()) {
      sl.unregister<AuthRepository>();
    }
    sl.registerLazySingleton<AuthLocalDatasource>(() => authLocal);
    sl.registerLazySingleton<AuthRepository>(() => authRepo);

    // Default: a token exists and is not expired. Individual tests override.
    when(() => authLocal.hasTokens()).thenAnswer((_) async => true);
    when(() => authLocal.isAccessTokenExpired()).thenAnswer((_) async => false);
  });

  tearDown(() {
    sl.reset();
  });

  /// Obtains a throwaway BuildContext — required by GoRouter's redirect
  /// API but not read by this app's redirect logic.
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    ));
    return ctx;
  }

  /// Runs the exact production redirect pipeline (route matching +
  /// AppRouter's `redirect` callback, chained until stable) for [path]
  /// and returns the resulting match list. Never builds a page widget.
  Future<RouteMatchList> resolve(BuildContext context, String path) async {
    final initial =
        AppRouter.router.configuration.findMatch(Uri.parse(path));
    return AppRouter.router.configuration.redirect(
      context,
      initial,
      redirectHistory: <RouteMatchList>[],
    );
  }

  group('route registration — critical paths exist', () {
    testWidgets('GET /notifications resolves to a registered route',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.notifications));
      expect(match.isError, isFalse);
    });

    testWidgets('GET /notifications/settings resolves to a registered route',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.notificationSettings));
      expect(match.isError, isFalse);
    });

    testWidgets('unknown path does not match any registered route',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/this-route-does-not-exist'));
      expect(match.isError, isTrue);
    });

    for (final path in <String>[
      RouteNames.splash,
      RouteNames.onboarding,
      RouteNames.login,
      RouteNames.register,
      RouteNames.otp,
      RouteNames.forgotPassword,
      RouteNames.createPassword,
      RouteNames.createStore,
      RouteNames.home,
      RouteNames.addProduct,
      RouteNames.categories,
      RouteNames.importProducts,
      RouteNames.cashPayment,
      RouteNames.creditSale,
      RouteNames.saleSuccess,
      RouteNames.receiptPreview,
      RouteNames.salesHistory,
      RouteNames.stockIntake,
      RouteNames.financeDashboard,
      RouteNames.expenses,
      RouteNames.addExpense,
      RouteNames.financeBalance,
      RouteNames.financeCredits,
      RouteNames.financeReports,
      RouteNames.financeCurrencies,
      RouteNames.investments,
      RouteNames.addInvestment,
      RouteNames.notifications,
      RouteNames.notificationSettings,
      RouteNames.debtsOverview,
      RouteNames.zakatCalculator,
      RouteNames.zakatSettings,
      RouteNames.zakatHistory,
      RouteNames.customerList,
      RouteNames.customerForm,
      RouteNames.supplierList,
      RouteNames.staffList,
      RouteNames.addStaff,
      RouteNames.roles,
      RouteNames.shifts,
      RouteNames.openShift,
      RouteNames.payroll,
      RouteNames.deliveryCreate,
      RouteNames.deliveryList,
      RouteNames.inventoryCount,
      RouteNames.settings,
      RouteNames.editProfile,
      RouteNames.changePassword,
      RouteNames.printerSettings,
      RouteNames.myStores,
      RouteNames.discounts,
      RouteNames.loyaltySettings,
      RouteNames.loyaltyAnalytics,
      RouteNames.receiptTemplate,
      RouteNames.kkmSettings,
      RouteNames.scannerSettings,
      RouteNames.telegramBot,
      RouteNames.languageSettings,
      RouteNames.offlineMode,
      RouteNames.subscription,
    ]) {
      testWidgets('static route "$path" is registered', (tester) async {
        final match =
            AppRouter.router.configuration.findMatch(Uri.parse(path));
        expect(match.isError, isFalse, reason: '$path should match a route');
      });
    }
  });

  group('deep-link path parameter parsing', () {
    testWidgets('/products/42 parses id path parameter', (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/products/42'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], '42');
    });

    testWidgets(
        '/products/add is matched by the static route, not the dynamic :id route',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.addProduct));
      expect(match.isError, isFalse);
      // Static route has no path parameters; dynamic :id route would have
      // captured "add" as the id if route ordering were wrong.
      expect(match.pathParameters.containsKey('id'), isFalse);
    });

    testWidgets(
        '/products/empty is matched by the static route, not the dynamic :id route',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/products/empty'));
      expect(match.isError, isFalse);
      expect(match.pathParameters.containsKey('id'), isFalse);
    });

    testWidgets('/customers/form is matched by the static customerForm route',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.customerForm));
      expect(match.isError, isFalse);
      expect(match.pathParameters.containsKey('id'), isFalse);
    });

    testWidgets('/customers/abc parses id path parameter', (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/customers/abc'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 'abc');
    });

    testWidgets('/suppliers/xyz parses id path parameter', (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/suppliers/xyz'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 'xyz');
    });

    testWidgets('/staff/add is matched by the static route, not :id',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.addStaff));
      expect(match.isError, isFalse);
      expect(match.pathParameters.containsKey('id'), isFalse);
    });

    testWidgets('/staff/s1 parses id path parameter', (tester) async {
      final match =
          AppRouter.router.configuration.findMatch(Uri.parse('/staff/s1'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 's1');
    });

    testWidgets('/deliveries/create is matched by the static route, not :id',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.deliveryCreate));
      expect(match.isError, isFalse);
      expect(match.pathParameters.containsKey('id'), isFalse);
    });

    testWidgets('/deliveries/d1 parses id path parameter', (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/deliveries/d1'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 'd1');
    });

    testWidgets('/shifts/sh1/z-report parses shift id path parameter',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/shifts/sh1/z-report'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 'sh1');
    });

    testWidgets('/payroll/p1/adjustment parses periodId path parameter',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/payroll/p1/adjustment'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['periodId'], 'p1');
    });

    testWidgets('/sales/s99 parses sale id path parameter', (tester) async {
      final match =
          AppRouter.router.configuration.findMatch(Uri.parse('/sales/s99'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 's99');
    });

    testWidgets('/sales/s99/refund parses sale id path parameter',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/sales/s99/refund'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], 's99');
    });

    testWidgets('/sales/history is matched by the static route, not :id',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse(RouteNames.salesHistory));
      expect(match.isError, isFalse);
      expect(match.pathParameters.containsKey('id'), isFalse);
    });

    // Regression test for a fixed bug: the static `/sales/empty` route was
    // registered AFTER the dynamic `/sales/:id` route, so GoRouter (which
    // matches in registration order) swallowed it as `/sales/:id` with
    // id="empty" — EmptySalesPage was unreachable via this path. Fixed by
    // reordering `/sales/empty` before `/sales/:id`, matching the
    // static-before-dynamic pattern used for products/customers/staff/
    // deliveries elsewhere in this file.
    testWidgets(
        '/sales/empty is matched by the static route, not swallowed by :id',
        (tester) async {
      final match = AppRouter.router.configuration
          .findMatch(Uri.parse('/sales/empty'));
      expect(match.isError, isFalse);
      expect(match.pathParameters.containsKey('id'), isFalse);
    });
  });

  group('auth guard — unauthenticated user', () {
    setUp(() {
      when(() => authLocal.hasTokens()).thenAnswer((_) async => false);
    });

    testWidgets('is redirected to /login when requesting /notifications',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notifications);
      expect(result.uri.path, RouteNames.login);
    });

    testWidgets(
        'is redirected to /login when requesting /notifications/settings',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notificationSettings);
      expect(result.uri.path, RouteNames.login);
    });

    testWidgets('is redirected to /login when requesting /home',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.home);
      expect(result.uri.path, RouteNames.login);
    });

    testWidgets('is redirected to /login when requesting /settings',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.settings);
      expect(result.uri.path, RouteNames.login);
    });

    testWidgets('is NOT redirected when already on /login', (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.login);
      expect(result.uri.path, RouteNames.login);
    });

    testWidgets('is NOT redirected when on /register (public path)',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.register);
      expect(result.uri.path, RouteNames.register);
    });

    testWidgets('is NOT redirected when on /otp (public path)',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.otp);
      expect(result.uri.path, RouteNames.otp);
    });

    testWidgets('is NOT redirected when on /forgot-password (public path)',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.forgotPassword);
      expect(result.uri.path, RouteNames.forgotPassword);
    });

    testWidgets('is NOT redirected when on /create-password (public path)',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.createPassword);
      expect(result.uri.path, RouteNames.createPassword);
    });

    testWidgets('is NOT redirected when on /onboarding (public path)',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.onboarding);
      expect(result.uri.path, RouteNames.onboarding);
    });

    testWidgets('splash path is never redirected, even when logged out',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.splash);
      expect(result.uri.path, RouteNames.splash);
    });
  });

  group('auth guard — authenticated user with a valid (non-expired) token',
      () {
    setUp(() {
      when(() => authLocal.hasTokens()).thenAnswer((_) async => true);
      when(() => authLocal.isAccessTokenExpired())
          .thenAnswer((_) async => false);
    });

    testWidgets('is redirected away from /login to /home', (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.login);
      expect(result.uri.path, RouteNames.home);
    });

    testWidgets('is redirected away from /register to /home', (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.register);
      expect(result.uri.path, RouteNames.home);
    });

    testWidgets('is NOT redirected when requesting /notifications',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notifications);
      expect(result.uri.path, RouteNames.notifications);
    });

    testWidgets('is NOT redirected when requesting /home', (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.home);
      expect(result.uri.path, RouteNames.home);
    });

    testWidgets('splash path is never redirected, even when logged in',
        (tester) async {
      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.splash);
      expect(result.uri.path, RouteNames.splash);
    });

    testWidgets('does not attempt a silent refresh when token is not expired',
        (tester) async {
      final ctx = await pumpContext(tester);
      await resolve(ctx, RouteNames.notifications);
      verifyNever(() => authLocal.getRefreshToken());
      verifyNever(() => authRepo.refreshToken(any()));
    });
  });

  group('auth guard — silent token refresh on expiry', () {
    testWidgets(
        'expired access token with a valid refresh token triggers a silent '
        'refresh and does NOT redirect to /login',
        (tester) async {
      when(() => authLocal.hasTokens()).thenAnswer((_) async => true);
      when(() => authLocal.isAccessTokenExpired())
          .thenAnswer((_) async => true);
      when(() => authLocal.getRefreshToken())
          .thenAnswer((_) async => 'valid-refresh-token');
      when(() => authRepo.refreshToken(any())).thenAnswer(
        (_) async => (accessToken: 'new-access', refreshToken: 'new-refresh'),
      );

      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notifications);

      expect(result.uri.path, RouteNames.notifications);
      verify(() => authRepo.refreshToken('valid-refresh-token')).called(1);
      verifyNever(() => authLocal.deleteTokens());
    });

    // Note on statefulness: GoRouter's redirect resolution re-invokes the
    // app-level redirect callback on the *new* location whenever it
    // returns one, to check whether further redirection is needed (see
    // go_router's RouteConfiguration.redirect). A mock that always answers
    // the same value regardless of prior calls therefore makes the
    // redirect-to-login branch run twice (once for the original path, once
    // more for /login), double-counting calls to getRefreshToken/
    // deleteTokens/refreshToken. These tests make hasTokens/isExpired
    // reflect the side effects deleteTokens()/refreshToken() would have on
    // the real datasource, so call counts match single-pass production
    // behavior.
    testWidgets(
        'expired access token with no refresh token deletes tokens and '
        'redirects to /login',
        (tester) async {
      var tokensPresent = true;
      when(() => authLocal.hasTokens())
          .thenAnswer((_) async => tokensPresent);
      when(() => authLocal.isAccessTokenExpired())
          .thenAnswer((_) async => tokensPresent);
      when(() => authLocal.getRefreshToken()).thenAnswer((_) async => null);
      when(() => authLocal.deleteTokens()).thenAnswer((_) async {
        tokensPresent = false;
      });

      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notifications);

      expect(result.uri.path, RouteNames.login);
      verify(() => authLocal.deleteTokens()).called(1);
      verifyNever(() => authRepo.refreshToken(any()));
    });

    testWidgets(
        'expired access token with an empty-string refresh token deletes '
        'tokens and redirects to /login',
        (tester) async {
      var tokensPresent = true;
      when(() => authLocal.hasTokens())
          .thenAnswer((_) async => tokensPresent);
      when(() => authLocal.isAccessTokenExpired())
          .thenAnswer((_) async => tokensPresent);
      when(() => authLocal.getRefreshToken()).thenAnswer((_) async => '');
      when(() => authLocal.deleteTokens()).thenAnswer((_) async {
        tokensPresent = false;
      });

      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notifications);

      expect(result.uri.path, RouteNames.login);
      verify(() => authLocal.deleteTokens()).called(1);
    });

    testWidgets(
        'expired access token where the refresh call throws deletes tokens '
        'and redirects to /login',
        (tester) async {
      var tokensPresent = true;
      when(() => authLocal.hasTokens())
          .thenAnswer((_) async => tokensPresent);
      when(() => authLocal.isAccessTokenExpired())
          .thenAnswer((_) async => tokensPresent);
      when(() => authLocal.getRefreshToken())
          .thenAnswer((_) async => 'stale-refresh-token');
      when(() => authRepo.refreshToken(any()))
          .thenThrow(Exception('refresh rejected by server'));
      when(() => authLocal.deleteTokens()).thenAnswer((_) async {
        tokensPresent = false;
      });

      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.notifications);

      expect(result.uri.path, RouteNames.login);
      verify(() => authLocal.deleteTokens()).called(1);
    });

    testWidgets(
        'expired access token while sitting on /login still triggers a '
        'silent refresh, and on success redirects to /home since hasTokens '
        'is now true — refresh is only skipped for the splash path',
        (tester) async {
      var isExpired = true;
      when(() => authLocal.hasTokens()).thenAnswer((_) async => true);
      when(() => authLocal.isAccessTokenExpired())
          .thenAnswer((_) async => isExpired);
      when(() => authLocal.getRefreshToken())
          .thenAnswer((_) async => 'valid-refresh-token');
      when(() => authRepo.refreshToken(any())).thenAnswer((_) async {
        isExpired = false;
        return (accessToken: 'new-access', refreshToken: 'new-refresh');
      });

      final ctx = await pumpContext(tester);
      final result = await resolve(ctx, RouteNames.login);

      expect(result.uri.path, RouteNames.home);
      verify(() => authRepo.refreshToken('valid-refresh-token')).called(1);
    });
  });
}
