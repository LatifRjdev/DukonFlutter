// app/integration_test/screenshots_test.dart
//
// App Store / Play Store screenshot harness for DukonPro.
//
// HOW IT WORKS (Path A — integration_test + takeScreenshot):
//   1. Boots the real app via `app.main()`.
//   2. Waits for go_router redirects to settle.
//   3. Calls `binding.takeScreenshot('NN-name')` at each marketable screen.
//   4. The driver (`test_driver/integration_driver.dart`) writes each PNG to
//      `integration_test/screenshots/<device>/NN-name.png`.
//
// Screenshots are captured at the device's logical resolution. They look great
// on real iPhone Pro Max / iPad / Pixel hardware, and store reviewers accept
// them as long as quality is good.
//
// FOLLOW-UP (Path B — pixel-exact store sizes):
//   For App Store 6.7" (1290 x 2796), 6.5" (1242 x 2688), or Play Store
//   exact dimensions, post-process the captured PNGs:
//
//       brew install imagemagick
//       cd integration_test/screenshots/iphone-15-pro-max
//       for f in *.png; do
//         magick "$f" -resize 1290x2796^ -gravity center -extent 1290x2796 \
//                "../app-store-6.7/$f"
//       done
//
//   Or use a Dart script with `package:image` for programmatic resize.
//
// AUTH BYPASS NOTES:
//   The app gates routes behind `AuthLocalDatasource.hasTokens()` via
//   `flutter_secure_storage`. We do NOT modify production code, so this
//   test captures the unauthenticated flow (splash → login → register →
//   forgot-password → OTP). To capture authenticated screens (POS,
//   dashboard, products, customers, reports, shifts), the user has two
//   options:
//
//     1. Run the test on a device/sim where you've already signed in
//        manually — `flutter_secure_storage` persists across runs, so the
//        redirect will land on /home instead of /login. Then add navigation
//        steps in `_authenticatedScreens()` below.
//
//     2. Use Flutter's golden test infrastructure (`test/presentation/pages/`
//        already has examples) to render individual pages with mocked Blocs
//        and `screenMatchesGolden(...)`. Those PNGs go in
//        `test/goldens/` and can be promoted to store assets.
//
// RUNNING:
//   See integration_test/README.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dukonpro/main.dart' as app;
import 'package:dukonpro/core/router/app_router.dart';
import 'package:dukonpro/core/router/route_names.dart';

Future<void> _settle(WidgetTester tester) async {
  // Pump a few times to let go_router's async redirect (which checks
  // AuthLocalDatasource.hasTokens via flutter_secure_storage) resolve.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _shoot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  // takeScreenshot is async on the driver side; we await before continuing.
  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Required so screenshots actually persist on Android — see
  // package:integration_test docs.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('DukonPro store screenshots', () {
    testWidgets('01 - splash + 02 - login (unauthenticated)',
        (tester) async {
      app.main();
      await _settle(tester);

      // After splash redirect, an unauthenticated build should land on /login.
      // If the app is already authenticated on this device, the user can
      // re-run after wiping Secure Storage / Keychain.
      await _shoot(binding, tester, '01-splash-or-login');

      // Best-effort: navigate explicitly to login if we're somewhere else.
      AppRouter.router.go(RouteNames.login);
      await _settle(tester);
      await _shoot(binding, tester, '02-login');
    });

    testWidgets('03 - register', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.register);
      await _settle(tester);
      await _shoot(binding, tester, '03-register');
    });

    testWidgets('04 - forgot password', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.forgotPassword);
      await _settle(tester);
      await _shoot(binding, tester, '04-forgot-password');
    });

    testWidgets('05 - onboarding', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.onboarding);
      await _settle(tester);
      await _shoot(binding, tester, '05-onboarding');
    });

    // -----------------------------------------------------------------
    // Authenticated screens — these require a signed-in device. The router
    // redirect will bounce back to /login if AuthLocalDatasource.hasTokens()
    // is false. We still attempt the navigation so a logged-in tester gets
    // the screenshots automatically.
    // -----------------------------------------------------------------

    testWidgets('06 - home / dashboard (auth required)', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.home);
      await _settle(tester);
      await _shoot(binding, tester, '06-home-dashboard');
    });

    testWidgets('07 - product catalog (auth required)', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.products);
      await _settle(tester);
      await _shoot(binding, tester, '07-products');
    });

    testWidgets('08 - customer list (auth required)', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.customerList);
      await _settle(tester);
      await _shoot(binding, tester, '08-customers');
    });

    testWidgets('09 - finance reports (auth required)', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.financeReports);
      await _settle(tester);
      await _shoot(binding, tester, '09-reports');
    });

    testWidgets('10 - shifts (auth required)', (tester) async {
      app.main();
      await _settle(tester);
      AppRouter.router.go(RouteNames.shifts);
      await _settle(tester);
      await _shoot(binding, tester, '10-shifts');
    });
  });
}
