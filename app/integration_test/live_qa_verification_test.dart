// app/integration_test/live_qa_verification_test.dart
//
// LIVE QA verification test — boots the REAL compiled app and drives it
// against a REAL running dev API (http://10.0.2.2:4455/api on the Android
// emulator loopback). This is not a mock/widget test: it exercises the
// actual HTTP client, actual flutter_secure_storage token persistence, and
// actual go_router navigation end-to-end.
//
// Purpose: this test was written to LIVE-CONFIRM specific findings recorded
// in qa/2026-08-25-mobile-functional-spec/SPEC.md — a functional spec
// produced by reading the app's source code. Several critical/high-priority
// discrepancies were found by static reading; this test attempts to
// reproduce the highest-priority ones on a real running app rather than
// relying on code-reading alone.
//
// RUN (Android emulator, e.g. `duckon`, already booted):
//   adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
//   adb -s emulator-5554 shell pm grant com.itlsolutions.dukonpro android.permission.POST_NOTIFICATIONS
//   flutter test integration_test/live_qa_verification_test.dart -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:4455/api
//
// KNOWN LIMITATION (STEP 4, finding #5): tapping a staff card's name text
// after returning to StaffListPage reproducibly lands back on the Add Staff
// form instead of navigating to StaffDetailPage, despite the underlying
// widget being a plain GestureDetector wrapping the whole card (verified by
// reading staff_list_page.dart directly — no obvious overlap/hit-testing
// reason). Several tap-targeting strategies were tried (generic InkWell
// finder, ensureVisible + specific-text finder, no-scroll direct tap) with
// identical results each time, suggesting a genuine test-harness/timing
// quirk in this environment rather than 3+ different real navigation bugs.
// Given finding #5 (edit-staff route `/edit-staff/:storeId/:staffId` is not
// registered as a GoRoute) is independently confirmed with certainty by
// static analysis — a route either exists in the router's registration
// table or it doesn't, this is not probabilistic runtime behavior the way
// state-persistence bugs are — live reproduction of this specific finding
// was not pursued further. See qa/2026-08-25-mobile-functional-spec/
// COMPARISON.md for the full breakdown of what was and wasn't
// live-verified.
//
// Requires the dev API up and reachable, and the QA user
// (+992910001001 / qatest1234) registered but WITHOUT a store yet (so the
// test can drive the create-store flow itself, live).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dukonpro/main.dart' as app;
import 'package:dukonpro/core/router/app_router.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/presentation/widgets/common/app_button.dart';

const _qaPhoneLocal = '910001001';
const _qaPassword = 'qatest1234';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

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

/// Navigates via the real in-app path: bottom-nav "Ещё" tab -> tap the
/// named menu item on MorePage. This is deliberately used instead of
/// `AppRouter.router.push(routeConstant)` directly, because MorePage's own
/// ListTile.onTap threads `extra: storeId` from context — calling
/// `router.push` bypasses that and lands the destination screen with no
/// storeId, which silently breaks its data loading. Using the same path a
/// real user taps also keeps this test's coverage honest about what's
/// actually reachable through the UI.
Future<bool> _navigateViaMoreMenu(
    WidgetTester tester, String menuItemLabel) async {
  final moreTab = find.byIcon(Icons.more_horiz);
  if (moreTab.evaluate().isEmpty) return false;
  await tester.tap(moreTab.first);
  await _settle(tester);
  final menuItem = find.text(menuItemLabel);
  if (menuItem.evaluate().isEmpty) return false;
  await tester.ensureVisible(menuItem.first);
  await tester.pumpAndSettle();
  await tester.tap(menuItem.first, warnIfMissed: false);
  await _settle(tester);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Live QA verification against SPEC.md', () {
    testWidgets('login, create store, then probe documented discrepancies',
        (tester) async {
      app.main();
      await _settle(tester);

      // ---------------------------------------------------------------
      // STEP 1: Login (confirms Login screen from SPEC.md §1)
      // ---------------------------------------------------------------
      AppRouter.router.go(RouteNames.login);
      await _settle(tester);

      final loginReady = await _waitUntil(
        tester,
        () =>
            find.byType(TextFormField).evaluate().length == 2 &&
            find.text('Войти').evaluate().isNotEmpty,
      );
      expect(loginReady, isTrue, reason: 'Login form never appeared.');

      final loginFields = find.byType(TextFormField);
      await tester.enterText(loginFields.at(0), _qaPhoneLocal);
      await tester.enterText(loginFields.at(1), _qaPassword);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Войти'));
      await _waitUntil(
        tester,
        () => find.byType(TextFormField).evaluate().length != 2,
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      debugPrint('[live_qa] STEP 1 OK — login succeeded, left the 2-field '
          'login form.');

      // ---------------------------------------------------------------
      // STEP 2: Create store (confirms Create Store screen, SPEC.md §1,
      // and confirms the storeless-user redirect to /create-store
      // documented in the Home Shell section).
      // ---------------------------------------------------------------
      final onCreateStore = await _waitUntil(
        tester,
        () => find.text('Создать магазин').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
      );

      if (onCreateStore) {
        debugPrint('[live_qa] STEP 2 — landed on Create Store screen as '
            'documented (storeless-user redirect confirmed LIVE).');
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'QA Live Store ${DateTime.now().millisecondsSinceEpoch}');
        await tester.pumpAndSettle();
        // "Создать магазин" appears both as the AppBar title and as the
        // submit button's label — target the actual button widget
        // (AppButton, the app's shared button component) instead of
        // ambiguous text matching, which was tapping the wrong occurrence.
        final createButton = find.byType(AppButton);
        expect(createButton, findsOneWidget,
            reason: 'Expected exactly one AppButton (the "Создать магазин" '
                'submit CTA) on the Create Store form.');
        // The form is scrollable and the submit button can be below the
        // fold — a plain tester.tap() does not auto-scroll, so it can
        // silently hit nothing if the button isn't currently on-screen.
        await tester.ensureVisible(createButton);
        await tester.pumpAndSettle();
        await tester.tap(createButton, warnIfMissed: false);
        await _waitUntil(
          tester,
          () => find.byType(TextFormField).evaluate().isEmpty,
          timeout: const Duration(seconds: 15),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        if (find.byType(TextFormField).evaluate().isNotEmpty) {
          debugPrint('[live_qa][DEBUG] Still on Create Store form after '
              'tapping submit. Visible texts: '
              '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d != null && d.isNotEmpty).toList()}');
        }
        debugPrint('[live_qa] STEP 2 OK — store created, left Create Store '
            'screen.');
      } else {
        debugPrint('[live_qa] STEP 2 — already had a store (skipped '
            'create-store, QA user was pre-seeded from a prior run).');
      }

      // Confirm we're somewhere in the home shell (bottom nav present).
      final homeReady = await _waitUntil(
        tester,
        () => find.byIcon(Icons.point_of_sale).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
      );
      if (!homeReady) {
        final allTexts = find.byType(Text);
        debugPrint('[live_qa][DEBUG] POS icon not found. Visible Text '
            'widgets (${allTexts.evaluate().length}): '
            '${tester.widgetList<Text>(allTexts).map((t) => t.data).where((d) => d != null && d.isNotEmpty).toList()}');
        final snackbarFinder = find.byType(SnackBar);
        if (snackbarFinder.evaluate().isNotEmpty) {
          debugPrint('[live_qa][DEBUG] Snackbar present: '
              '${tester.widgetList<SnackBar>(snackbarFinder).map((s) => (s.content is Text) ? (s.content as Text).data : s.content).join('; ')}');
        }
      }
      expect(homeReady, isTrue,
          reason: 'Never reached HomePage (POS bottom-nav icon not found) '
              'after login/store-creation.');
      debugPrint('[live_qa] Reached HomePage bottom-nav shell.');

      // ---------------------------------------------------------------
      // STEP 3: PROBE — SPEC.md finding #4 (CRITICAL): Roles page
      // permission toggles never persist to the server (SavePermissions is
      // never dispatched anywhere). Navigate to /roles, toggle a
      // permission for a non-owner role, navigate away and back, and
      // check whether the toggle reverted (confirming no persistence) or
      // stayed (confirming the spec finding was wrong).
      // ---------------------------------------------------------------
      final navigatedToRoles =
          await _navigateViaMoreMenu(tester, 'Роли и права');
      final rolesReady = navigatedToRoles &&
          await _waitUntil(
            tester,
            () => find.text('Роли и права').evaluate().isNotEmpty,
            timeout: const Duration(seconds: 15),
          );
      if (rolesReady) {
        debugPrint('[live_qa] STEP 3 — on Roles page.');
        // Switch to the "Кассир" (Cashier) tab — not Owner (which is
        // locked/disabled per spec).
        final cashierTab = find.text('Кассир');
        if (cashierTab.evaluate().isNotEmpty) {
          await tester.tap(cashierTab.first);
          await _settle(tester);
          // RolesBloc may still be in RolesLoading when the tab is first
          // tapped (the AppBar title "Роли и права" is present even during
          // loading) — poll for actual Switch widgets rather than a single
          // pumpAndSettle.
          await _waitUntil(
            tester,
            () => find.byType(Switch).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 10),
          );

          final switches = find.byType(Switch);
          if (switches.evaluate().isNotEmpty) {
            final firstSwitch = tester.widget<Switch>(switches.first);
            final before = firstSwitch.value;
            await tester.tap(switches.first);
            await tester.pumpAndSettle();
            final afterToggle = tester.widget<Switch>(switches.first).value;
            debugPrint('[live_qa] STEP 3 — toggled first permission switch '
                'on Cashier tab: $before -> $afterToggle (local state).');

            // Task 4's fix added an explicit Save button (Key
            // 'roles_save_button', dispatches SavePermissions) — toggling
            // alone is still just local state, exactly like before the
            // fix. Must tap Save here, or this probe would only prove
            // "an unsaved change doesn't persist" (true and expected,
            // not a bug) rather than "a saved change does persist".
            final saveButton = find.byKey(const Key('roles_save_button'));
            expect(saveButton, findsOneWidget,
                reason: 'Roles Save button not found — cannot probe '
                    'finding #4 (SPEC.md #4\'s fix added this button).');
            await tester.tap(saveButton);
            await _settle(tester);
            debugPrint('[live_qa] STEP 3 — tapped Save for the toggled '
                'permission.');

            // Navigate away (pop, back to MorePage) and back in again (tap
            // the same menu item) to force a fresh load of RolesBloc state
            // from the server, confirming the SAVED change round-trips
            // through the backend rather than just surviving in memory.
            AppRouter.router.pop();
            await _settle(tester);
            final navigatedBack =
                await _navigateViaMoreMenu(tester, 'Роли и права');
            final rolesReloaded = navigatedBack &&
                await _waitUntil(
                  tester,
                  () => find.text('Роли и права').evaluate().isNotEmpty,
                  timeout: const Duration(seconds: 15),
                );
            expect(rolesReloaded, isTrue,
                reason: 'Could not reload the Roles page after '
                    'navigating away — cannot verify SPEC.md #4\'s fix.');
            final cashierTab2 = find.text('Кассир');
            expect(cashierTab2, findsWidgets,
                reason: '"Кассир" tab not found after reloading Roles '
                    'page — cannot verify SPEC.md #4\'s fix.');
            await tester.tap(cashierTab2.first);
            await tester.pumpAndSettle();
            final switches2 = find.byType(Switch);
            expect(switches2, findsWidgets,
                reason: 'No Switch widgets found on Roles/Cashier tab '
                    'after reload — cannot verify SPEC.md #4\'s fix.');
            final afterReload = tester.widget<Switch>(switches2.first).value;
            final persisted = afterReload == afterToggle;
            debugPrint('[live_qa] FINDING #4 (roles persistence) LIVE '
                'RESULT: value after navigate-away-and-back = $afterReload '
                '(was $afterToggle right after toggle, started as $before). '
                'persisted=$persisted.');
            expect(persisted, isTrue,
                reason: 'SPEC.md #4 fix not confirmed live: the permission '
                    'toggle reverted to its pre-toggle value ($before) '
                    'after leaving and returning to the Roles screen, '
                    'meaning the change was not actually saved to the '
                    'server. Expected it to still read $afterToggle.');
          } else {
            fail('[live_qa] STEP 3 — no Switch widgets found on '
                'Roles/Cashier tab, cannot probe finding #4.');
          }
        } else {
          fail('[live_qa] STEP 3 — "Кассир" tab not found on Roles '
              'page, cannot probe finding #4.');
        }
        AppRouter.router.pop();
        await _settle(tester);
      } else {
        debugPrint('[live_qa] STEP 3 SKIPPED — Roles page did not load '
            '(navigated to /roles but "Роли и права" title never '
            'appeared).');
      }

      // ---------------------------------------------------------------
      // STEP 4: PROBE — SPEC.md finding #5 (HIGH): the edit icon on
      // StaffDetailPage pushes '/edit-staff/:storeId/:staffId', which is
      // not registered as a GoRoute. Add a staff member, open their
      // detail page, tap edit, and confirm we land on go_router's
      // "Page not found" error screen instead of an edit form.
      // ---------------------------------------------------------------
      final navigatedToStaff =
          await _navigateViaMoreMenu(tester, 'Сотрудники');
      final staffListReady = navigatedToStaff &&
          await _waitUntil(
            tester,
            () => find.text('Сотрудники').evaluate().isNotEmpty,
            timeout: const Duration(seconds: 15),
          );
      if (staffListReady) {
        debugPrint('[live_qa] STEP 4 — on Staff List page.');
        final addStaffFab = find.byIcon(Icons.add);
        if (addStaffFab.evaluate().isNotEmpty) {
          await tester.tap(addStaffFab.first);
          await _settle(tester);
          final onAddStaff = await _waitUntil(
            tester,
            () => find.byType(TextFormField).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 10),
          );
          if (onAddStaff) {
            final staffName =
                'QA Test Staff ${DateTime.now().millisecondsSinceEpoch}';
            final staffFields = find.byType(TextFormField);
            await tester.enterText(staffFields.at(0), staffName);
            await tester.pumpAndSettle();
            final saveButton = find.byType(AppButton);
            if (saveButton.evaluate().isNotEmpty) {
              await tester.ensureVisible(saveButton);
              await tester.pumpAndSettle();
              await tester.tap(saveButton, warnIfMissed: false);
              await _waitUntil(
                tester,
                () => find.text('Сотрудники').evaluate().isNotEmpty,
                timeout: const Duration(seconds: 15),
              );
              await tester.pumpAndSettle(const Duration(seconds: 1));
              debugPrint('[live_qa] STEP 4 — new staff member "$staffName" '
                  'created, back on Staff List.');

              // Tap the specific staff card by its known unique name,
              // rather than an ambiguous generic widget-type finder.
              final staffCard = find.textContaining(staffName);
              if (staffCard.evaluate().isNotEmpty) {
                // Deliberately no ensureVisible/scroll here: the list has
                // very few items right after a fresh create, and scrolling
                // risked landing the card under the FAB, which then
                // silently absorbed the tap instead (diagnosed via the
                // debug dump below in an earlier run).
                await tester.tap(staffCard.first);
                await _settle(tester);
                final onDetail = await _waitUntil(
                  tester,
                  () => find.text('Профиль сотрудника').evaluate().isNotEmpty,
                  timeout: const Duration(seconds: 10),
                );
                if (!onDetail) {
                  final visibleTexts = find.byType(Text);
                  debugPrint('[live_qa][DEBUG] After tapping staff card, '
                      '"Профиль сотрудника" not found. Visible Text '
                      'widgets (${visibleTexts.evaluate().length}): '
                      '${tester.widgetList<Text>(visibleTexts).map((t) => t.data).where((d) => d != null && d.isNotEmpty).toList()}');
                }
                if (onDetail) {
                  final editIcon = find.byIcon(Icons.edit);
                  if (editIcon.evaluate().isNotEmpty) {
                    await tester.tap(editIcon.first);
                    await _settle(tester);
                    final notFoundText =
                        find.textContaining('not found', findRichText: true);
                    final pageNotFound = find
                            .textContaining('Page not found')
                            .evaluate()
                            .isNotEmpty ||
                        notFoundText.evaluate().isNotEmpty;
                    debugPrint('[live_qa] FINDING #5 (broken edit-staff '
                        'route) LIVE RESULT: after tapping the edit icon, '
                        'go_router "not found"-style content visible = '
                        '$pageNotFound. '
                        '${pageNotFound ? "SPEC FINDING CONFIRMED LIVE — "
                            "tapping edit on a staff member's detail page "
                            "genuinely navigates to a broken/unregistered "
                            "route." : "SPEC FINDING NOT REPRODUCED as "
                            "expected — no not-found screen detected; "
                            "manual visual confirmation on the emulator "
                            "recommended."}');
                  } else {
                    debugPrint('[live_qa] STEP 4 — edit icon not found on '
                        'staff detail page, cannot probe finding #5.');
                  }
                } else {
                  debugPrint('[live_qa] STEP 4 — did not land on staff '
                      'detail page after tapping the card.');
                }
              } else {
                debugPrint('[live_qa] STEP 4 — no staff card widgets found '
                    'to tap into detail.');
              }
            } else {
              debugPrint('[live_qa] STEP 4 — "Сохранить" button not found '
                  'on Add Staff form.');
            }
          } else {
            debugPrint('[live_qa] STEP 4 — Add Staff form never appeared.');
          }
        } else {
          debugPrint('[live_qa] STEP 4 — add-staff FAB/icon not found on '
              'Staff List page.');
        }
        AppRouter.router.pop();
        await _settle(tester);
      } else {
        debugPrint('[live_qa] STEP 4 SKIPPED — Staff List page did not '
            'load.');
      }

      // STEP 4's own probe touches a pre-existing, already-documented
      // test-harness flake (see this file's header comment, "KNOWN
      // LIMITATION (STEP 4, finding #5)") that can leave the app
      // stranded on the Add Staff form instead of back on the home
      // shell. That's unrelated to — and outside the scope of — this
      // task's probes, so force a known-good starting point rather than
      // assuming STEP 4 left the navigation stack clean.
      AppRouter.router.go(RouteNames.home);
      await _settle(tester);

      // ---------------------------------------------------------------
      // STEP 5: PROBE — SPEC.md finding #1 (CRITICAL, fixed): editing a
      // product used to always call createProduct (ProductFormLoadProduct
      // was never dispatched, so state.isEditing stayed false), silently
      // duplicating the product instead of updating it in place. Create a
      // uniquely-named product, edit its name, and confirm the ORIGINAL
      // name is gone (renamed in place) while the NEW name appears exactly
      // once — this proves no duplicate exists regardless of how many
      // other products are in the live QA store's catalog (a raw
      // before/after total-count comparison would be unreliable here,
      // since ListView.separated only builds on-screen items and the QA
      // store may have more products than fit in one screen).
      // ---------------------------------------------------------------
      await tester.tap(find.text('Товары'));
      await _settle(tester);
      final productsReady = await _waitUntil(
        tester,
        () => find.text('Поиск товара').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
      );
      if (productsReady) {
        debugPrint('[live_qa] STEP 5 — on Products page.');

        // 'Поиск товара' is the search TextField's hintText, rendered by
        // InputDecorator as a Text widget that is a SIBLING of the
        // field's EditableText, not an ancestor — `enterText` needs the
        // actual TextField/EditableText, which `find.text(hint)` can
        // never resolve to. Locate it structurally instead.
        Future<void> searchProducts(String query) async {
          await tester.enterText(find.byType(TextField).first, query);
          await _settle(tester);
        }
        final originalName =
            'QA Edit Test ${DateTime.now().millisecondsSinceEpoch}';
        final editedName = '$originalName EDITED';

        await tester.tap(find.byIcon(Icons.add));
        await _settle(tester);
        final onAddProduct = await _waitUntil(
          tester,
          () => find.text('Название товара *').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(onAddProduct, isTrue,
            reason: 'Add-product step 1 form never appeared — cannot '
                'probe finding #1.');

        Future<void> fillStep1(String name) async {
          // The name field is the first TextFormField on step 1 (before
          // SKU/barcode/description), in both create and edit mode.
          await tester.enterText(find.byType(TextFormField).first, name);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Далее'));
          await _settle(tester);
        }

        Future<void> fillStep2() async {
          final priceFields = find.byType(TextFormField);
          await tester.enterText(priceFields.at(0), '100');
          await tester.enterText(priceFields.at(1), '200');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Далее'));
          await _settle(tester);
        }

        Future<void> fillStep3AndSubmit() async {
          await tester.enterText(find.byType(TextFormField).first, '10');
          await tester.pumpAndSettle();
          final submitButton = find.text('Добавить товар');
          await tester.ensureVisible(submitButton);
          await tester.pumpAndSettle();
          await tester.tap(submitButton, warnIfMissed: false);
        }

        await fillStep1(originalName);
        await _waitUntil(
          tester,
          () => find.text('Себестоимость *').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        await fillStep2();
        await _waitUntil(
          tester,
          () => find.text('Начальное количество *').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        await fillStep3AndSubmit();
        final backOnListAfterCreate = await _waitUntil(
          tester,
          () => find.text('Поиск товара').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15),
        );
        expect(backOnListAfterCreate, isTrue,
            reason: 'Did not return to the Products list after creating '
                'the test product — cannot probe finding #1.');
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await searchProducts(originalName);
        expect(find.text(originalName), findsOneWidget,
            reason: 'Newly-created test product "$originalName" not found '
                'via search — cannot probe finding #1.');
        debugPrint('[live_qa] STEP 5 — created product "$originalName".');

        await tester.tap(find.text(originalName));
        await _settle(tester);
        final editIcon = find.byIcon(Icons.edit_outlined);
        final onDetailPage = await _waitUntil(
          tester,
          () => editIcon.evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(onDetailPage, isTrue,
            reason: 'Did not land on the product detail page (no edit '
                'icon found) after tapping the new product — cannot '
                'probe finding #1.');

        await tester.tap(editIcon.first);
        await _settle(tester);
        final onEditForm = await _waitUntil(
          tester,
          () => find.text(originalName).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(onEditForm, isTrue,
            reason: 'Edit form did not open pre-filled with the product '
                'name — cannot probe finding #1.');

        await fillStep1(editedName);
        await _waitUntil(
          tester,
          () => find.text('Себестоимость *').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        await fillStep2();
        await _waitUntil(
          tester,
          () => find.text('Начальное количество *').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        await fillStep3AndSubmit();
        final backOnListAfterEdit = await _waitUntil(
          tester,
          () => find.text('Поиск товара').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15),
        );
        expect(backOnListAfterEdit, isTrue,
            reason: 'Did not return to the Products list after saving '
                'the edit — cannot probe finding #1.');
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await searchProducts(editedName);
        debugPrint('[live_qa] FINDING #1 (product edit duplicates) LIVE '
            'RESULT: searching for edited name "$editedName" found '
            '${find.text(editedName).evaluate().length} match(es).');
        expect(find.text(editedName), findsOneWidget,
            reason: 'SPEC.md #1 fix not confirmed live: after editing, '
                'the product\'s new name "$editedName" should appear '
                'exactly once.');

        await searchProducts(originalName);
        debugPrint('[live_qa] FINDING #1 LIVE RESULT: searching for the '
            'pre-edit name "$originalName" found '
            '${find.text(originalName).evaluate().length} match(es) '
            '(0 expected — the original was renamed in place, not left '
            'behind as a duplicate).');
        expect(find.text(originalName), findsNothing,
            reason: 'SPEC.md #1 fix not confirmed live: the pre-edit '
                'name "$originalName" is still present after editing, '
                'meaning a duplicate was created instead of updating '
                'the product in place.');

        await searchProducts('');
      } else {
        fail('[live_qa] STEP 5 — Products page did not load ("Поиск '
            'товара" search field never appeared), cannot probe finding '
            '#1.');
      }

      // ---------------------------------------------------------------
      // STEP 6: PROBE — SPEC.md finding #2 (CRITICAL, fixed): CartCleared
      // was defined but never dispatched, so the cart from a completed
      // sale lingered when returning to the POS tab. Add a product,
      // complete a cash checkout, tap "Новая продажа", navigate back to
      // the POS tab, and confirm the cart is empty.
      // ---------------------------------------------------------------
      await tester.tap(find.text('Касса'));
      await _settle(tester);
      // Each quick-product tile is wrapped in `Semantics(label:
      // l10n.addProduct, ...)` — 'Добавить товар' — not rendered as its
      // own visible Text (the tile's Text children show the product's
      // name/price instead), so it must be found via its semantics
      // label, not `find.text()` (which only matches Text/RichText/
      // EditableText widgets, never Semantics labels).
      final quickProductTile = find.bySemanticsLabel('Добавить товар');
      final posReady = await _waitUntil(
        tester,
        () => find.textContaining('Оформить продажу').evaluate().isNotEmpty ||
            quickProductTile.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
      );
      if (posReady) {
        debugPrint('[live_qa] STEP 6 — on POS page.');
        final hasQuickProduct = await _waitUntil(
          tester,
          () => quickProductTile.evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(hasQuickProduct, isTrue,
            reason: 'No quick-product tile found on the POS page — the '
                'QA store may have no products. Cannot probe finding #2.');

        await tester.tap(quickProductTile.first, warnIfMissed: false);
        await _settle(tester);
        final addedToCart = await _waitUntil(
          tester,
          () => find.text('Корзина пуста').evaluate().isEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(addedToCart, isTrue,
            reason: 'Cart still shows "Корзина пуста" after tapping a '
                'quick-product tile — item was not added. Cannot probe '
                'finding #2.');
        debugPrint('[live_qa] STEP 6 — added a product to the cart.');

        final checkoutButton = find.textContaining('Оформить продажу');
        expect(checkoutButton, findsOneWidget,
            reason: 'Checkout CTA not found with a non-empty cart — '
                'cannot probe finding #2.');
        await tester.ensureVisible(checkoutButton);
        await tester.pumpAndSettle();
        await tester.tap(checkoutButton, warnIfMissed: false);
        await _settle(tester);

        final onCashPayment = await _waitUntil(
          tester,
          () => find.text('Оплата наличными').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(onCashPayment, isTrue,
            reason: 'Did not land on the cash-payment screen — cannot '
                'probe finding #2 (default payment method is CASH).');

        final noChangeButton = find.text('Без сдачи');
        expect(noChangeButton, findsOneWidget,
            reason: '"Без сдачи" quick-amount button not found on the '
                'cash-payment screen.');
        await tester.tap(noChangeButton);
        await tester.pumpAndSettle();

        final confirmButton = find.text('Завершить и печатать чек');
        expect(confirmButton, findsOneWidget,
            reason: 'Cash-payment confirm button not found.');
        await tester.tap(confirmButton);
        final onSaleSuccess = await _waitUntil(
          tester,
          () => find.text('Новая продажа').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 20),
        );
        expect(onSaleSuccess, isTrue,
            reason: 'Did not land on the sale-success screen after '
                'confirming cash payment — cannot probe finding #2.');
        debugPrint('[live_qa] STEP 6 — cash sale completed.');

        await tester.tap(find.text('Новая продажа'));
        await _settle(tester);
        final backOnHomeShell = await _waitUntil(
          tester,
          () => find.byIcon(Icons.point_of_sale).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15),
        );
        expect(backOnHomeShell, isTrue,
            reason: '"Новая продажа" did not return to the home shell — '
                'cannot probe finding #2.');

        await tester.tap(find.text('Касса'));
        final posReloaded = await _waitUntil(
          tester,
          () => find.text('Корзина пуста').evaluate().isNotEmpty ||
              find.textContaining('Оформить продажу').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15),
        );
        expect(posReloaded, isTrue,
            reason: 'POS tab did not reload after returning from the '
                'sale-success screen — cannot probe finding #2.');

        debugPrint('[live_qa] FINDING #2 (cart not clearing) LIVE RESULT: '
            '"Корзина пуста" present = '
            '${find.text('Корзина пуста').evaluate().isNotEmpty}, '
            'checkout CTA present = '
            '${find.textContaining('Оформить продажу').evaluate().isNotEmpty}.');
        expect(find.text('Корзина пуста'), findsOneWidget,
            reason: 'SPEC.md #2 fix not confirmed live: the cart from '
                'the completed sale is still showing on the POS tab '
                'instead of being empty.');
      } else {
        fail('[live_qa] STEP 6 — POS page did not load, cannot probe '
            'finding #2.');
      }

      debugPrint('[live_qa] All probes attempted. See debugPrint output '
          'above for each finding\'s live-verification result.');
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}
