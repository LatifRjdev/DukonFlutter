# Flutter Static Audit Findings — 2026-04-10

## Summary
- Total findings: 16 (P0: 2, P1: 5, P2: 5, P3: 4)
- `flutter analyze`: 0 errors / 0 warnings / 33 infos
- i18n: 300 keys in ru / 300 in tg / 300 in uz (delta: 0 — ARBs are perfectly in sync)
- Test files: 1 (`app/test/widget_test.dart` — the default scaffold test)
- Hardcoded Cyrillic-containing Dart files: 89 total; 59 files contain Cyrillic inside `Text('...')` literals (288 occurrences)
- Router: 51 `GoRoute` entries in `lib/core/router/app_router.dart` (not 54 — discrepancy from the brief)
- Token storage: `flutter_secure_storage` with `encryptedSharedPreferences: true` on Android (GOOD, per `security.md`)

---

## P0 Findings

### [P0-FE-001] Hardcoded insecure HTTP base URL checked into source
- **Files:**
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/core/constants/api_endpoints.dart:4` — `static const String baseUrl = 'http://10.0.2.2:4455/api';`
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/core/network/api_interceptor.dart:44` — `'http://10.0.2.2:4455/api/auth/refresh'` (second, duplicated hardcoded URL inside the token refresh path)
- **Description:** The entire app ships with a single hardcoded Android-emulator loopback URL over plain HTTP. There is no environment switching (dev / staging / prod) and no HTTPS. The interceptor bypasses the central constant and hardcodes the URL a second time, so even if `ApiEndpoints.baseUrl` is fixed, token refresh will still hit plain HTTP.
- **Impact:** Violates `.claude/rules/api-integration.md` ("Base URL configurable per environment") and `.claude/rules/security.md` ("API calls always over HTTPS in production"). Any production build will silently fail (10.0.2.2 is an Android emulator alias, unreachable from iOS or real devices), and tokens/passwords will be transmitted in cleartext on every request. This is simultaneously a security leak and a ship-blocker.
- **Recommended fix:** Introduce an `AppConfig`/flavor (dart-define) with `DEV`/`STAGING`/`PROD` base URLs. Make `ApiInterceptor` read the base URL from the injected `Dio.options.baseUrl` instead of hardcoding, and remove the literal `http://10.0.2.2:4455/api/auth/refresh` entirely.

### [P0-FE-002] No test coverage — a single scaffold widget test
- **File:** `/Users/latifrjdev/Downloads/Dukon/app/test/widget_test.dart` (only file in `app/test/`)
- **Description:** The entire Flutter app has exactly one test file — and inspection of the directory listing shows it is the default Flutter counter-scaffold test. There are 0 bloc tests, 0 widget tests for real screens, 0 integration tests, 0 golden tests. 24 BLoCs, 58 pages, a sync engine, an auth interceptor with token-refresh logic — none tested.
- **Impact:** Violates `.claude/rules/testing.md` ("unit tests for every UseCase and Repository", "UI tests with Compose testing library for critical flows (POS checkout, product add)" — same expectation applies to the Flutter app). Any regression in checkout, token refresh, or sync goes undetected. This is a P0 rather than P1 because the POS is the money-handling path and has zero automated coverage.
- **Recommended fix:** At minimum, add bloc_test coverage for `CheckoutBloc`, `AuthBloc`, `DebtBloc`, `ShiftBloc`; widget test for the login form and POS checkout flow; and an integration test for the offline sync queue.

---

## P1 Findings

### [P1-FE-001] 288 hardcoded Russian strings across 59 user-facing screens
- **Files (top offenders by match count):**
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/finance/finance_dashboard_page.dart` (18)
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/zakat/zakat_calculator_page.dart` (18)
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/shifts/z_report_page.dart` (17)
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/settings/settings_page.dart` (17)
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/product/product_list_page.dart` (16)
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/product/add_product_step1_page.dart` (8)
  - …plus 53 more files, including every auth screen, every pos screen, every product, staff, debt, zakat, finance, settings screen.
- **Description:** ARB files are perfectly in sync (300 keys × 3 locales), but the app rarely uses them. Raw Russian strings appear inside `Text('…')`, `AppBar(title: Text('…'))`, dialog titles, validation messages, and snackbars. Tajik (tg) and Uzbek (uz) users will see Russian on most screens regardless of the locale they pick.
- **Impact:** i18n is effectively broken for the app's two stated non-Russian locales. Rule `.claude/rules/android-compose.md` and `.claude/rules/ios-swiftui.md` both mandate localization in `ru/tg/uz`; the Flutter app drifts from this.
- **Recommended fix:** Sweep every file in the list, extract literal strings to `app_ru.arb`, mirror in `app_tg.arb` and `app_uz.arb`, and replace with `AppLocalizations.of(context)!.keyName`. Add a lint rule or CI check that fails on any `Text('[\u0400-\u04FF]` match.

### [P1-FE-002] Error handling inconsistency — `AuthBloc` swallows exceptions as strings
- **File:** `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/blocs/auth/auth_bloc.dart:37-39,52-54`
- **Description:** On login / register failure, the bloc emits `AuthFailure(e.toString())` — a raw stringified Dart exception. `DioException` messages include URLs and stack fragments, and are not localized. There is no discrimination between `NetworkError`, `AuthError`, and `ServerError` (the sealed-class hierarchy the API integration rule mandates). Spot-check shows `CheckoutBloc._onProcessPayment` (`checkout_bloc.dart:78-80`) does the same.
- **Impact:** Users see raw English exception text like `DioException [connection timeout]: http://10.0.2.2:…` — which also leaks the internal API host to the UI. Violates `.claude/rules/api-integration.md` ("Error responses mapped to sealed class hierarchy").
- **Recommended fix:** Introduce a `Failure` sealed class (already hinted at by `lib/core/errors/failures.dart`), map `DioException` → `Failure` in the repository layer, and surface localized user-facing messages in BLoC states.

### [P1-FE-003] `BuildContext` used across async gaps (analyzer-flagged)
- **Files:**
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/customer/customer_list_page.dart:106` and `:110`
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/supplier/supplier_list_page.dart:105` and `:109`
- **Description:** `dart analyze` explicitly reports `use_build_context_synchronously` at these four lines — the existing `if (mounted)` check is "unrelated" per the analyzer, meaning the context is guarded by the wrong widget's mounted state (likely the dialog's stateful builder). Classic source of "Looking up a deactivated widget's ancestor" crashes.
- **Impact:** Runtime crash after add-customer / add-supplier flows when the user is slow or the network is slow. Reproducible bug, not theoretical.
- **Recommended fix:** Capture a `ScaffoldMessenger.of(context)` and `GoRouter.of(context)` *before* the await, or restructure so the context used after await belongs to the still-mounted parent.

### [P1-FE-004] Dialog-local `TextEditingController`s never disposed
- **Files / lines:**
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/product/categories_page.dart:31` — `final controller = TextEditingController(text: currentName);`
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/pos/pos_checkout_page.dart:682` — discount dialog `final controller = TextEditingController(...)`
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/pos/credit_sale_page.dart:95-96` — `nameController`, `phoneController` inside `_showCreateCustomerDialog`
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/shifts/shifts_page.dart:36` — `cashController` inside `_showCloseShiftDialog`
- **Description:** Each of these controllers is created inside a `showDialog` builder and never disposed — neither on dialog dismiss nor on parent `dispose()`. Flutter leaks the controller and its listeners per dialog open.
- **Impact:** Slow memory leak on high-volume screens (POS discount dialog, close-shift dialog). Not user-visible until the app is left open for a long session.
- **Recommended fix:** Convert each dialog to a small `StatefulWidget` whose `State.dispose()` disposes the controller, or use `HookWidget` / `flutter_hooks` / a wrapper that handles lifecycle.

### [P1-FE-005] No sync-engine wiring despite files existing
- **Files:** `/Users/latifrjdev/Downloads/Dukon/app/lib/data/sync/sync_engine.dart` (202 lines), `sync_queue.dart` (204 lines), `conflict_resolver.dart` (63 lines)
- **Description:** The sync engine files exist, but every repository in `lib/data/repositories/` delegates straight to the remote datasource — no local SQLDelight (or Drift) persistence is visible in `lib/data/`. The brief suggested "SQLDelight-free (uses remote-only currently)" and this is confirmed. That makes the sync engine code dead weight, and contradicts `.claude/rules/sync-engine.md` ("All writes go to local DB first, then queued for remote sync"), `.claude/rules/database.md`, and the top-level product promise of offline-first retail.
- **Impact:** Any network hiccup on the POS screen fails the sale; no offline catalog; "local DB is always source of truth" is currently false. If `data/sync/*` is called from anywhere, those code paths are unreachable.
- **Recommended fix:** Decide: (a) commit to offline-first, add Drift or SQLDelight FFI layer, wire `SyncEngine` into each repository; or (b) delete the unused `data/sync/` tree and update the architecture docs to state that Flutter app is online-only.

---

## P2 Findings

### [P2-FE-001] Router auth-guard leaks on splash
- **File:** `/Users/latifrjdev/Downloads/Dukon/app/lib/core/router/app_router.dart:82-83`
- **Description:** The `redirect` callback explicitly returns `null` for `/splash` so SplashPage can do its own navigation. That's fine, but it means an attacker who deep-links to `/splash` with a crafted extra can bypass the token check for one frame. More importantly: `hasTokens` is called on every single redirect — including for public routes — incurring a keystore read per navigation.
- **Impact:** Small perf cost (secure-storage reads are disk-hitting on Android). Theoretical bypass requires control of the app, so not exploitable remotely.
- **Recommended fix:** Short-circuit public paths before the `hasTokens()` await.

### [P2-FE-002] `SharedPreferences` used for non-secret but app-critical state
- **Files:**
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/core/services/thermal_printer_service.dart:191, 196, 201`
  - `/Users/latifrjdev/Downloads/Dukon/app/lib/presentation/blocs/settings/settings_bloc.dart:20, 33`
- **Description:** Printer configuration and settings state live in plain `SharedPreferences`. This is *not* a rule violation (rule only forbids secrets in SharedPreferences and tokens are correctly in secure storage), but it is worth flagging because it mixes persistence strategies. Verified the bloc does NOT store any token or password in SharedPreferences.
- **Impact:** None from a security standpoint. Architectural inconsistency only.
- **Recommended fix:** Accept as-is, or centralize settings into a `SettingsRepository` abstraction.

### [P2-FE-003] 17 remote datasources use `if (x != null) ...` spreads instead of null-aware
- **Files (from `flutter analyze` infos):** `auth_remote_datasource.dart:47`, `expense_remote_datasource.dart:46,49`, `product_remote_datasource.dart:56-60`, `sale_remote_datasource.dart:62-64`, `shift_remote_datasource.dart:83-85`, `staff_remote_datasource.dart:42-43`, `store_remote_datasource.dart:43-44`
- **Description:** 17 analyzer hits for `use_null_aware_elements`. Pure style, but it's >50% of the total analyzer output.
- **Recommended fix:** `dart fix --apply`.

### [P2-FE-004] Deprecated Flutter 3.33+ APIs in use
- **Files:**
  - `add_product_step3_page.dart:158` — `FormField.value` (now `initialValue`)
  - `zakat_settings_page.dart:133, 135, 142, 144` — `Radio.groupValue` / `onChanged` (replaced by `RadioGroup`)
- **Description:** Will break on next Flutter major. Analyzer already flags them.
- **Recommended fix:** Migrate to `RadioGroup` and `initialValue` per the deprecation messages.

### [P2-FE-005] 24 page files mix BLoC with local `setState` (49 occurrences)
- **Top files:** `zakat_settings_page.dart` (9), `pos_checkout_page.dart` (4), `product_list_page.dart` (4), `add_product_step1_page.dart` (3)
- **Description:** Rule `.claude/rules/android-compose.md` says "no business logic in Composables — only UI rendering". The analogous Flutter convention would be "pages are stateless where possible, state hoisted to Bloc". Several pages use `setState` for local UI toggles (tab index, form step) *and* also consume BLoC — acceptable for pure UI state, but `pos_checkout_page.dart` using `setState` 4 times during a money-handling flow is worth a review.
- **Recommended fix:** Audit `pos_checkout_page.dart` specifically; move any price/total/discount mutation into `CheckoutBloc`.

---

## P3 Findings

### [P3-FE-001] Minor style infos: unnecessary braces and underscores (6 hits)
- `current_shift_card.dart:44`, `shift_card.dart:23` — `unnecessary_brace_in_string_interps` x4
- `product_detail_page.dart:116` — `unnecessary_underscores` x2
- **Fix:** `dart fix --apply`.

### [P3-FE-002] 569 hardcoded `SizedBox`/`Container` width/height usages across 86 files
- **Description:** Grepped `SizedBox(width:`, `SizedBox(height:`, `Container(width:`. Most are legit spacing (8, 12, 16, 24 px), which is fine. Did not find obvious overflow risks in a spot-check, but any of these inside a Row/Column without Expanded could overflow on small screens. Too many to triage by grep alone — needs runtime inspection.
- **Recommended fix:** Informational. Consider adding golden tests at 320dp width as a regression net.

### [P3-FE-003] Duplicate base URL literal in `api_interceptor.dart`
- Already covered by P0-FE-001; flagging separately because it is also a code-duplication smell.

### [P3-FE-004] `flutter analyze` — no `prefer_const_constructors` enforcement
- The `analysis_options.yaml` does not enable `prefer_const_constructors`. Analyzer reports 0 missing-const hints *because the lint isn't on*, not because the code uses const everywhere. Low-priority perf improvement.
- **Recommended fix:** Add `prefer_const_constructors: warning` to `analysis_options.yaml` and run `dart fix --apply`.

---

## Informational

### Router config
- 51 `GoRoute` entries total (brief said 54 — three routes missing vs. spec; compare with `RouteNames` constants to find which). Auth guard present: `redirect` checks `AuthLocalDatasource.hasTokens()` and bounces un-authenticated users to `/login` unless they are on a whitelisted public path (`splash`, `onboarding`, `login`, `register`, `otp`, `forgotPassword`, `createPassword`). POS / home / all `/stores/*` scoped routes are correctly gated.
- `createStore` is NOT in the public allowlist but is also NOT protected by a dedicated post-login guard — acceptable because it is only reachable after auth via `HomePage`, but worth verifying.

### State management
- Every feature folder under `lib/presentation/pages/` has a matching folder under `lib/presentation/blocs/` (24 bloc groups). No Provider or Riverpod usage found. `setState` is used for local UI state only (49 occurrences across 24 files — typical).
- BLoCs are registered via `get_it` in `lib/injection.dart`. No obvious `.close()` leaks because the `GetIt` lifetimes default to factory for BLoCs.

### Token storage — CORRECT
- `lib/injection.dart:101` registers `FlutterSecureStorage` with `AndroidOptions(encryptedSharedPreferences: true)`.
- `ApiInterceptor` reads / writes `access_token` and `refresh_token` through the secure storage. **No violation of `security.md`.**

### i18n — ARBs in sync
- `app_ru.arb` = 300 keys + 150 `@metadata` entries; `app_tg.arb` = 300 keys; `app_uz.arb` = 300 keys. Zero key drift between the three locales. The problem is not the ARBs, it is that the UI ignores them (see P1-FE-001).

### Clean architecture layer separation — CLEAN
- Zero `import '...data/...'` statements anywhere under `lib/domain/`. The dependency rule (domain → no data) is respected.

### Logging
- Zero `print(`, `debugPrint(`, or `developer.log(` calls in `lib/`. No leak risk from logging.

### Form validation
- Spot-checked `login_page.dart` — uses `_formKey.currentState?.validate()` + field-level `validator:` callbacks. Form validation is in place on auth screens.
