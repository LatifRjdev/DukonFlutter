// app/integration_test/functional_smoke_test.dart
//
// FUNCTIONAL smoke test — boots the REAL compiled app and drives it against
// a REAL running dev API (http://localhost:4455/api by default, override
// with --dart-define=API_BASE_URL=...). This is NOT a mock/widget test: it
// exercises the actual HTTP client, actual flutter_secure_storage token
// persistence, and actual go_router redirect logic end-to-end.
//
// Flow covered:
//   1. Boot app.main(), settle the initial auth redirect.
//   2. Assert we land on /login while unauthenticated.
//   3. Fill in the real phone/password fields and tap the real "Войти"
//      button, using seeded QA credentials.
//   4. Assert a real redirect away from /login happens (proves: HTTP login
//      call succeeded, token got persisted, go_router redirect fired).
//   5. Best-effort: navigate into /pos and assert it renders without a
//      Flutter error screen (product list or empty-cart state, not a crash).
//   6. Any FlutterError.onError firings during the whole run are collected
//      and the test fails at the end if any occurred, printing them so
//      they show up in `flutter test` stdout.
//
// RUN:
//   Preferred (macOS desktop) — only works if this checkout has been
//   scaffolded for macOS (`flutter create --platforms=macos .`); at the
//   time this test was written the repo had no macos/ or web/ directory,
//   so `-d macos` / `-d chrome` both fail with "no <platform> project
//   configured" even though `flutter devices` lists them as available
//   devices (that just means the host toolchain supports them):
//     cd app
//     flutter test integration_test/functional_smoke_test.dart -d macos \
//       --dart-define=API_BASE_URL=http://localhost:4455/api
//
//   Fallback actually used — Android emulator, which the repo already has
//   scaffolded (android/ dir) and whose default API_BASE_URL loopback
//   (10.0.2.2) already targets the host's localhost:4455:
//     flutter emulators --launch <avd-id>          # e.g. `duckon`
//     flutter test integration_test/functional_smoke_test.dart \
//       -d <emulator-id> \
//       --dart-define=API_BASE_URL=http://10.0.2.2:4455/api
//
//   IMPORTANT Android gotcha: on first-ever launch the app requests the
//   POST_NOTIFICATIONS runtime permission (NotificationService.init() in
//   main.dart), which shows a native system dialog with no auto-dismiss —
//   `await requestPermission()` then hangs forever with no automation
//   driving that dialog. `flutter test -d <device>` also fully uninstalls
//   the app after every run (pass or fail), wiping any previously granted
//   permission, so before EVERY invocation pre-grant it:
//     adb install -r build/app/outputs/flutter-apk/app-debug.apk
//     adb shell pm grant com.itlsolutions.dukonpro \
//       android.permission.POST_NOTIFICATIONS
//   (build/app-debug.apk from a prior `flutter build apk --debug` /
//   `flutter test` run; the grant survives the subsequent `-r` reinstall
//   `flutter test` performs internally, since that's an upgrade not a
//   fresh install.)
//
// Requires the dev API to be up and reachable, and the seeded QA user
// (+992910001001 / qatest1234) to exist.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dukonpro/main.dart' as app;
import 'package:dukonpro/core/router/app_router.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dukonpro/presentation/widgets/common/app_button.dart';

// QA store ("qa-start-store", owned by +992910001001) has exactly one
// seeded product. Its stock was 0 before this test was extended to cover a
// real checkout; SalesService.createSale (api/src/modules/sales/
// sales.service.ts) rejects a sale when product.quantity < requested
// quantity, so ahead of running this test 100 units were added via a real
// PURCHASE stock-movement through the API (POST
// /stores/:storeId/products/:productId/stock-movements), tagged
// "QA-SMOKE-TEST" in its `notes` field for traceability/cleanup. This is
// test-data setup, not something the test itself performs.
const _qaProductName = 'qa-p-start-20979';

const _qaPhoneLocal = '910001001'; // +992 prefix is added by the login form.
const _qaPassword = 'qatest1234';

Future<void> _settle(WidgetTester tester) async {
  // Pump a few times to let go_router's async redirect (which checks
  // AuthLocalDatasource.hasTokens via flutter_secure_storage) resolve.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Polls (pumping real wall-clock frames) until [predicate] is true or
/// [timeout] elapses. Cold boot of the real app on a fresh emulator runs
/// through Firebase.initializeApp, full DI/get_it wiring, local DB
/// migrations, and notification-permission setup before the widget tree
/// stabilizes — this can take well beyond the few seconds a fixed
/// pumpAndSettle budget allows, so we poll generously instead of guessing
/// a fixed delay.
Future<bool> _waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 45),
  Duration step = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (predicate()) return true;
  }
  return predicate();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final capturedFlutterErrors = <String>[];
  late FlutterExceptionHandler? originalOnError;

  setUpAll(() {
    originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      capturedFlutterErrors.add(details.exceptionAsString());
      // Still forward to the original handler so errors also show up in
      // the normal test-runner console output.
      originalOnError?.call(details);
    };
  });

  tearDownAll(() {
    FlutterError.onError = originalOnError;
  });

  group('DukonPro functional smoke — real app + real dev API', () {
    testWidgets('login with seeded QA user redirects away from /login',
        (tester) async {
      app.main();
      await _settle(tester);

      // Best-effort: force to /login in case the redirect landed elsewhere
      // (e.g. stale tokens from a previous manual run on this machine).
      AppRouter.router.go(RouteNames.login);
      await _settle(tester);

      // Cold boot on a fresh emulator (Firebase init, full DI wiring, local
      // DB migrations, notification permission setup) can take well beyond
      // a fixed few-second settle budget. Poll for the login form instead
      // of assuming it's already there.
      final loginFormReady = await _waitUntil(
        tester,
        () =>
            find.byType(TextFormField).evaluate().length == 2 &&
            find.text('Войти').evaluate().isNotEmpty,
      );

      debugPrint('[functional_smoke_test] Route path after initial settle: '
          '"${AppRouter.router.routerDelegate.currentConfiguration.uri.path}" '
          '(informational only — see widget-based assertion below, '
          'GoRouterDelegate.currentConfiguration is not always populated '
          'synchronously in the integration_test harness).');

      if (!loginFormReady) {
        // DEBUG: dump all visible Text widget contents to diagnose which
        // screen actually rendered instead of login.
        final allTexts = find.byType(Text);
        debugPrint('[functional_smoke_test][DEBUG] visible Text widgets '
            '(${allTexts.evaluate().length}): '
            '${tester.widgetList<Text>(allTexts).map((t) => t.data).where((d) => d != null && d.isNotEmpty).toList()}');
      }

      // Assert we're on the login screen by widget content, not by route
      // string — more robust than currentConfiguration under the test
      // harness's frame-scheduling. Locate the phone field (first
      // TextFormField) and password field (second TextFormField) per
      // lib/presentation/pages/auth/login_page.dart.
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2),
          reason: 'Expected exactly phone + password fields on /login. If '
              'this fails because we are already authenticated, secure '
              'storage on this device already has tokens from a previous '
              'run — uninstall the app or clear app data and re-run.');
      expect(find.text('Войти'), findsOneWidget,
          reason: 'Expected the login submit button ("Войти") to be visible.');

      await tester.enterText(textFields.at(0), _qaPhoneLocal);
      await tester.enterText(textFields.at(1), _qaPassword);
      await tester.pumpAndSettle();

      final loginButton = find.text('Войти');
      expect(loginButton, findsOneWidget);

      await tester.tap(loginButton);

      // Give the real HTTP round-trip room to complete: poll for the login
      // form to disappear (successful redirect) or an error snackbar to
      // appear (failed login), rather than a fixed pump budget or a single
      // pumpAndSettle (which can time out waiting on the AppButton's
      // loading-spinner animation ticker).
      await _waitUntil(
        tester,
        () =>
            find.byType(TextFormField).evaluate().isEmpty ||
            find.byType(SnackBar).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20),
      );
      // The login->home navigation runs a page-transition animation during
      // which BOTH the outgoing LoginPage and incoming HomePage are briefly
      // mounted simultaneously (the outgoing route isn't removed from the
      // tree until its exit animation finishes) — settle fully so we don't
      // catch that overlap and misread it as "still on login".
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final currentPath =
          AppRouter.router.routerDelegate.currentConfiguration.uri.path;
      debugPrint('[functional_smoke_test] Route path after login attempt: '
          '"$currentPath" (informational only)');

      // Surface any inline auth-failure snackbar text directly in the
      // failure reason — much more actionable than a bare "still on login".
      final snackbarFinder = find.byType(SnackBar);
      final snackbarText = snackbarFinder.evaluate().isNotEmpty
          ? tester
              .widgetList<SnackBar>(snackbarFinder)
              .map((s) => (s.content is Text) ? (s.content as Text).data : s.content)
              .join('; ')
          : null;

      // Widget-based assertion: the login form (phone + password fields and
      // the "Войти" button) must be GONE — that's proof go_router redirected
      // us to a different page after a real, successful HTTP login + token
      // persistence. This is more robust than reading go_router's
      // currentConfiguration, which isn't reliably populated synchronously
      // under the integration_test harness.
      expect(
        find.text('Войти'),
        findsNothing,
        reason: 'Still seeing the login button after submitting credentials '
            '— login likely failed or did not redirect. Route path: '
            '"$currentPath".'
            '${snackbarText != null ? ' Snackbar shown: $snackbarText' : ''}',
      );
      expect(find.byType(TextFormField), findsNothing,
          reason: 'Login form fields still present after submit — did not '
              'navigate away from /login.');

      debugPrint('[functional_smoke_test] Login succeeded and redirected '
          'away from /login (login form no longer present).');

      // -----------------------------------------------------------------
      // Best-effort: navigate into POS and confirm it renders without a
      // Flutter error screen. Not asserting a full checkout — an empty
      // cart / product list is still a valid, useful signal.
      //
      // NOTE: RouteNames.pos ('/pos') is declared in route_names.dart but
      // is NOT registered as a standalone go_router GoRoute (confirmed: no
      // `path: RouteNames.pos` / `path: '/pos'` anywhere in app_router.dart,
      // and no other file in lib/ references RouteNames.pos either — it's
      // unused dead code). Calling AppRouter.router.go(RouteNames.pos)
      // lands on go_router's built-in "Page not found" error screen. In
      // the real app, POS is reached as tab index 2 of the bottom nav bar
      // inside HomePage's IndexedStack (see home_page.dart), so we tap the
      // real "Касса" nav item instead — this matches actual user behavior.
      // This is a minor code-hygiene finding (dead/misleading route
      // constant), not a user-facing crash, since nothing in the app ever
      // calls context.go(RouteNames.pos) — left unfixed per instructions
      // to only touch lib/ for real crashes.
      // -----------------------------------------------------------------
      final posTabFinder = find.byIcon(Icons.point_of_sale);
      if (posTabFinder.evaluate().isNotEmpty) {
        await tester.tap(posTabFinder.first);
        await _waitUntil(
          tester,
          () => find.text('Касса').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
      } else {
        debugPrint('[functional_smoke_test] POS bottom-nav tab icon not '
            'found — skipping POS check (bottom nav may not be visible on '
            'this screen).');
      }

      // A crashed build shows Flutter's built-in ErrorWidget (red screen).
      expect(find.byType(ErrorWidget), findsNothing,
          reason: 'POS screen rendered a Flutter ErrorWidget (red screen).');

      final posHeaderFound = find.text('Касса').evaluate().isNotEmpty;
      debugPrint('[functional_smoke_test] POS tab tapped. "Касса" header '
          'present: $posHeaderFound');

      if (posHeaderFound) {
        debugPrint('[functional_smoke_test] POS screen rendered '
            'successfully — proves it built against real store/product '
            'data from the API instead of crashing silently.');
      } else {
        final posTexts = find.byType(Text);
        debugPrint('[functional_smoke_test][DEBUG] "Касса" header not '
            'found after tapping POS tab. Visible Text widgets '
            '(${posTexts.evaluate().length}): '
            '${tester.widgetList<Text>(posTexts).map((t) => t.data).where((d) => d != null && d.isNotEmpty).toList()}. '
            'Not treated as a hard failure since login+redirect is the '
            'primary signal for this smoke test. No ErrorWidget was '
            'present, which is the main crash signal we check for here.');
      }

      // -----------------------------------------------------------------
      // FULL CASH-SALE CHECKOUT — extends the smoke test past "POS
      // renders" to prove the revenue-critical path works end-to-end
      // against the real dev API: add a real product to cart, proceed to
      // checkout, pay cash, and land on the real success screen backed by
      // the Sale object the API actually returned.
      // -----------------------------------------------------------------
      if (!posHeaderFound) {
        fail('Cannot proceed to checkout — POS screen ("Касса" header) '
            'never rendered. See debug output above for visible widgets.');
      }

      final productTileReady = await _waitUntil(
        tester,
        () => find.text(_qaProductName).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
      );
      if (!productTileReady) {
        final posTexts = find.byType(Text);
        debugPrint('[functional_smoke_test][DEBUG] QA product tile not '
            'found. Visible Text widgets: '
            '${tester.widgetList<Text>(posTexts).map((t) => t.data).where((d) => d != null && d.isNotEmpty).toList()}');
      }
      expect(productTileReady, isTrue,
          reason: 'QA product "$_qaProductName" tile never appeared in the '
              'POS quick-add strip — cannot proceed with checkout. Either '
              'the store has no active products or ProductListBloc failed '
              'to load them.');

      debugPrint('[functional_smoke_test] Tapping quick-add tile for '
          '"$_qaProductName" to add it to the cart.');
      await tester.tap(find.text(_qaProductName).first);
      await tester.pumpAndSettle();

      // Cart header reads "Корзина (N товаров)" once non-empty.
      final cartPopulated = await _waitUntil(
        tester,
        () => find.textContaining('Корзина (').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10),
      );
      expect(cartPopulated, isTrue,
          reason: 'Cart header never appeared after tapping the product '
              'tile — CartItemAdded may not have been processed by '
              'CartBloc.');

      // CASH is the default selected payment method
      // (_selectedPaymentMethod = 'CASH' in PosCheckoutPage), so no need
      // to tap a payment-method chip before hitting the checkout CTA.
      final checkoutCta = find.byType(AppButton);
      expect(checkoutCta, findsOneWidget,
          reason: 'Expected exactly one AppButton (the "Оформить продажу" '
              'CTA) visible once the cart is non-empty.');
      debugPrint('[functional_smoke_test] Tapping checkout CTA.');
      await tester.tap(checkoutCta);
      await tester.pumpAndSettle();

      final cashPaymentReady = await _waitUntil(
        tester,
        () => find.text('Оплата наличными').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10),
      );
      expect(cashPaymentReady, isTrue,
          reason: 'Did not navigate to the cash-payment screen '
              '("Оплата наличными") after tapping the checkout CTA.');

      // "Без сдачи" (exact change) auto-fills the received amount with
      // the cart total, which also satisfies the confirm button's
      // `_receivedAmount >= total` guard.
      final exactChangeChip = find.text('Без сдачи');
      expect(exactChangeChip, findsOneWidget);
      await tester.tap(exactChangeChip);
      await tester.pumpAndSettle();

      final confirmButton = find.text('Завершить и печатать чек');
      expect(confirmButton, findsOneWidget);
      debugPrint('[functional_smoke_test] Confirming cash payment — real '
          'POST /stores/:storeId/sales round-trip follows.');
      await tester.tap(confirmButton);

      // Real HTTP round-trip: poll for the success screen rather than a
      // fixed pump budget.
      await _waitUntil(
        tester,
        () => find.text('Продажа оформлена!').evaluate().isNotEmpty ||
            find.byType(SnackBar).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20),
      );

      final checkoutSnackbarFinder = find.byType(SnackBar);
      final checkoutSnackbarText = checkoutSnackbarFinder.evaluate().isNotEmpty
          ? tester
              .widgetList<SnackBar>(checkoutSnackbarFinder)
              .map((s) => (s.content is Text) ? (s.content as Text).data : s.content)
              .join('; ')
          : null;

      expect(
        find.text('Продажа оформлена!'),
        findsOneWidget,
        reason: 'Checkout did not reach the success screen after '
            'confirming cash payment — sale likely failed server-side.'
            '${checkoutSnackbarText != null ? ' Snackbar shown: $checkoutSnackbarText' : ''}',
      );

      // Pull the persisted Sale straight out of CheckoutBloc's state (the
      // same object SaleSuccessPage renders, returned by the real API
      // response to POST /sales) so its id/receiptNo can be reported for
      // cleanup, independent of any UI text formatting.
      final checkoutBloc =
          tester.element(find.byType(Scaffold).first).read<CheckoutBloc>();
      final createdSale = checkoutBloc.state.saleResult;
      expect(createdSale, isNotNull,
          reason: 'Reached the success screen but '
              'CheckoutBloc.state.saleResult is null — sale object was not '
              'captured.');

      debugPrint('[functional_smoke_test] SALE CREATED — id: '
          '${createdSale!.id}, receiptNo: ${createdSale.receiptNo}, '
          'total: ${createdSale.total}, storeId: ${createdSale.storeId}, '
          'paymentType: ${createdSale.paymentType}, status: '
          '${createdSale.status}. FOR MANUAL CLEANUP: DELETE FROM "Sale" '
          'WHERE id = \'${createdSale.id}\'; (mirrors k6 load-test cleanup '
          'convention — this row is real test data in the live dev DB).');

      if (capturedFlutterErrors.isNotEmpty) {
        fail('FlutterError.onError fired ${capturedFlutterErrors.length} '
            'time(s) during the run:\n'
            '${capturedFlutterErrors.map((e) => '- $e').join('\n')}');
      }
    });
  });
}
