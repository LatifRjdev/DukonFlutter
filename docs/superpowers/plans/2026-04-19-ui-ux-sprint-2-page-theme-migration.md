# Sprint 2 — Page Theme Migration Implementation Plan

## Sprint 2 Complete — 2026-04-19/20

- **77 files migrated** across 21 feature folders + meta-task extending `ThemeColors` with 10 on-semantic/shadow/tinted-bg tokens
- **0** `AppColors.(light|dark)(Background|Surface|Border|Text)` refs remaining in `app/lib/presentation/pages/`
- **188 tests passing** (golden + unit), 0 flutter analyze errors, 0 warnings (only pre-existing info-level lints)
- Every page covered with light + dark golden baselines
- Commits: Task 0 → Task 5 (Phase 1), Phase 2–5 one commit per folder, plus meta-task "extend ThemeColors" (`e23e9a8`, `d325a9d`) and goldens regeneration (`ec8b8b7`)
- Follow-up: Sprint 3 will migrate `lib/presentation/widgets/**` (shared components)

---

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate 77 Flutter page files in `lib/presentation/pages/**` from hardcoded `AppColors.lightX` references to theme-aware `context.X` getters, so that dark mode applies app-wide.

**Architecture:** Manual, prioritized migration across 5 phases (21 feature folders). One commit per folder. Each page gets golden tests in both themes to lock in visual correctness.

**Tech Stack:** Flutter 3.10, bloc/flutter_bloc, go_router, `golden_toolkit` for visual regression tests.

**Spec:** [docs/superpowers/specs/2026-04-19-ui-ux-sprint-2-page-theme-migration-design.md](../specs/2026-04-19-ui-ux-sprint-2-page-theme-migration-design.md)

---

## Audit Summary

Pre-flight `AppColors.(light|dark)` reference count per folder:

| Phase | Folder | Files | Refs |
|---|---|---|---|
| 1 | dashboard | 3 | 17 |
| 1 | product | 8 | 51 |
| 1 | pos | 5 | 39 |
| 1 | finance | 9 | 92 |
| 1 | settings | 13 | 92 |
| 2 | customer | 3 | 22 |
| 2 | supplier | 2 | 12 |
| 2 | sales | 4 | 22 |
| 2 | notifications | 2 | 15 |
| 3 | debt | 3 | 11 |
| 3 | payroll | 2 | 13 |
| 3 | zakat | 3 | 27 |
| 4 | stock | 1 | 11 |
| 4 | inventory | 1 | 15 |
| 4 | delivery | 3 | 27 |
| 5 | auth | 5 | 5 |
| 5 | onboarding | 2 | 3 |
| 5 | store | 1 | 0 |
| 5 | roles | 1 | 1 |
| 5 | shifts | 3 | 19 |
| 5 | staff | 3 | 18 |
| **Total** | **21 folders** | **77 files** | **512 refs** |

---

## Canonical Folder Migration Procedure

This procedure is referenced by Tasks 2–21. Task 1 shows it in full detail with code.

1. **Audit** — enumerate files and per-file `AppColors.light` references.
2. **Migrate each file** — apply the mapping table from the spec (§4):
   - `AppColors.lightBackground` → `context.bg`
   - `AppColors.lightSurface` → `context.surface`
   - `AppColors.lightSurfaceElevated` → `context.surfaceMuted`
   - `AppColors.lightBorder` → `context.border`
   - `AppColors.lightTextPrimary` → `context.textPrimary`
   - `AppColors.lightTextSecondary` → `context.textSecondary`
   - `AppColors.lightTextHint` → `context.textMuted`
   - `AppColors.success` (semantic fg) → `context.success`
   - `AppColors.error` (semantic fg) → `context.danger`
   - `AppColors.warning` (semantic fg) → `context.warning`
   - `AppColors.info` (semantic fg) → `context.info`
   - `AppColors.primary` → `context.primary` **at Scaffold level**; may stay as `AppColors.primary` inside deep `const` widgets
   - Add `import '../../../core/theme/theme_extensions.dart';` if not already present
   - Remove `const` from `Scaffold` or a parent that blocks `context` access
   - Replace `static const _color = AppColors.lightX` with a helper method taking `BuildContext`
3. **Run `flutter analyze`** for the folder — must be clean.
4. **Add/update golden tests** per page: one file per page, two `testGoldens` blocks (light + dark).
5. **Generate goldens**: `flutter test --update-goldens test/presentation/pages/<folder>/`.
6. **Visually inspect new goldens** (open the PNGs in the IDE diff viewer).
7. **Smoke test on emulator** — hot restart, toggle theme in Settings, open each screen in the folder in both themes.
8. **Commit** per folder: `feat(theme): migrate <folder> pages to theme-aware colors`.

---

## Task 0: Setup — Dependency & Test Infrastructure

**Files:**
- Modify: `app/pubspec.yaml` (add `golden_toolkit` dev dependency)
- Create: `app/test/helpers/golden_pump_helper.dart`
- Create: `app/test/fixtures/mock_blocs.dart`
- Create: `app/test/flutter_test_config.dart`

- [ ] **Step 1: Add `golden_toolkit` to `app/pubspec.yaml`**

Locate the `dev_dependencies:` block in `app/pubspec.yaml`. Add:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  golden_toolkit: ^0.15.0
  # ... existing dev deps
```

- [ ] **Step 2: Install dependency**

Run: `cd app && flutter pub get`
Expected: `Got dependencies!` (or equivalent success message).

- [ ] **Step 3: Create `test/flutter_test_config.dart`**

This is picked up automatically by Flutter test runner. It loads fonts for every golden test.

```dart
// app/test/flutter_test_config.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      enableRealShadows: true,
      defaultDevices: const [Device.iphone11],
    ),
  );
}
```

- [ ] **Step 4: Create shared pump helper**

```dart
// app/test/helpers/golden_pump_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';

/// Wrap [page] in a themed MaterialApp. Pass [wrap] to inject BlocProviders
/// or any other InheritedWidget tree above the page.
Future<void> pumpPageWithTheme(
  WidgetTester tester,
  Widget page, {
  required Brightness brightness,
  Widget Function(Widget child)? wrap,
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  final content = wrap != null ? wrap(page) : page;
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: content,
    ),
  );
  await tester.pumpAndSettle();
}
```

> **Why `wrap` instead of `List<SingleChildWidget>`:** `MultiBlocProvider` accepts `List<SingleChildWidget>` from the `provider` package. Rather than add `provider` as a direct dep (it's transitive via `flutter_bloc`), we let callers pass a closure that wraps the page in whatever BlocProviders they need.

- [ ] **Step 5: Create centralized bloc mocks**

Create `app/test/fixtures/mock_blocs.dart` with mocks stubbed out. Start with a single mock — we'll add more as each task needs them.

```dart
// app/test/fixtures/mock_blocs.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/store/store_state.dart';
import 'package:dukonpro/domain/entities/store.dart';

class MockStoreBloc extends MockBloc<StoreEvent, StoreState> implements StoreBloc {}

StoreState fakeStoreLoaded() => StoreLoaded(
  stores: [
    Store(
      id: 'store-1',
      name: 'AltAuditStore',
      ownerId: 'user-1',
      address: 'Test address',
      phone: '+992000000000',
      createdAt: DateTime(2026, 1, 1),
    ),
  ],
  selectedStore: Store(
    id: 'store-1',
    name: 'AltAuditStore',
    ownerId: 'user-1',
    address: 'Test address',
    phone: '+992000000000',
    createdAt: DateTime(2026, 1, 1),
  ),
);
```

> **Note:** adjust fields to match the real `Store` entity (open `app/lib/domain/entities/store.dart` to confirm field names).

- [ ] **Step 6: Add `bloc_test` and `mocktail` dev dependencies if missing**

Check `app/pubspec.yaml` for `bloc_test:` and `mocktail:`. Add any that are missing:

```yaml
dev_dependencies:
  # …
  bloc_test: ^9.1.7
  mocktail: ^1.0.3
```

Run `cd app && flutter pub get`.

> **Note:** `bloc_test` transitively depends on `mocktail`, but since golden-test files `import 'package:mocktail/mocktail.dart'` directly, it must be declared as a direct dev_dependency too (Dart doesn't allow importing from transitive deps).

- [ ] **Step 7: Verify scaffolding compiles**

Run: `cd app && flutter analyze test/helpers test/fixtures test/flutter_test_config.dart`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/pubspec.yaml app/pubspec.lock app/test/flutter_test_config.dart app/test/helpers/ app/test/fixtures/
git commit -m "$(cat <<'EOF'
test(theme): scaffold golden_toolkit infra for Sprint 2

Adds golden_toolkit + bloc_test dev deps, test/flutter_test_config.dart
bootstrap, golden_pump_helper with theme-aware MaterialApp wrapper,
and a starter mock_blocs.dart for centralized bloc fakes.

Part of Sprint 2 setup — no production code changes.
EOF
)"
```

---

## Task 1: Migrate `dashboard` folder (Phase 1 — Core nav)

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart`
- Modify: `app/lib/presentation/pages/dashboard/home_page.dart`
- Modify: `app/lib/presentation/pages/dashboard/more_page.dart`
- Create: `app/test/presentation/pages/dashboard/dashboard_page_golden_test.dart`
- Create: `app/test/presentation/pages/dashboard/home_page_golden_test.dart`
- Create: `app/test/presentation/pages/dashboard/more_page_golden_test.dart`

- [ ] **Step 1: Audit per-file refs**

Run:
```bash
cd /Users/latifrjdev/Downloads/Dukon
for f in app/lib/presentation/pages/dashboard/*.dart; do
  echo "$f: $(grep -c 'AppColors\.light' "$f") light refs"
done
```

Expected output similar to:
```
app/lib/presentation/pages/dashboard/dashboard_page.dart: 12 light refs
app/lib/presentation/pages/dashboard/home_page.dart: 0 light refs
app/lib/presentation/pages/dashboard/more_page.dart: 5 light refs
```

- [ ] **Step 2: Migrate `dashboard_page.dart`**

Open `app/lib/presentation/pages/dashboard/dashboard_page.dart`. Apply these changes:

Add the theme extension import near the top of the imports block:
```dart
import '../../../core/theme/theme_extensions.dart';
```

At line 91 (or wherever `Scaffold(` is called), replace:
```dart
child: Scaffold(
  backgroundColor: AppColors.lightBackground,
  ...
```
with:
```dart
child: Scaffold(
  backgroundColor: context.bg,
  ...
```

For every other occurrence of `AppColors.light*` in the file, apply the mapping table from the "Canonical Folder Migration Procedure" above.

If any `const` modifier prevents `context` access, remove `const`.

- [ ] **Step 3: Migrate `home_page.dart`**

Open `app/lib/presentation/pages/dashboard/home_page.dart`. The audit showed 0 light refs, but verify with grep:
```bash
grep -n "AppColors\." app/lib/presentation/pages/dashboard/home_page.dart
```

If any `AppColors.lightX` refs appear, migrate per the procedure. Otherwise, no code changes are needed — only golden tests.

- [ ] **Step 4: Migrate `more_page.dart`**

Open `app/lib/presentation/pages/dashboard/more_page.dart`. Add the import:
```dart
import '../../../core/theme/theme_extensions.dart';
```

Replace each of the 5 `AppColors.lightTextSecondary` occurrences with `context.textSecondary`. Example line at ~113:
```dart
// BEFORE
color: AppColors.lightTextSecondary,
// AFTER
color: context.textSecondary,
```

Similar for lines ~136 and ~170.

Since `more_page.dart` currently uses `_MenuItem` as a helper widget that receives `color` as a parameter, those colors are passed from the parent — no change needed inside the widget class, only at the call sites where colors originate.

- [ ] **Step 5: Run `flutter analyze` for dashboard folder**

Run: `cd app && flutter analyze lib/presentation/pages/dashboard/`
Expected: "No issues found!"

If errors appear (typically `Instance member 'bg' can't be accessed on a const expression`), it means a `const` parent is blocking `context` — remove `const` and re-run.

- [ ] **Step 6: Write golden test for `DashboardPage`**

Create `app/test/presentation/pages/dashboard/dashboard_page_golden_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/presentation/blocs/dashboard/dashboard_bloc.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/dashboard/dashboard_page.dart';

import '../../../helpers/golden_pump_helper.dart';
import '../../../fixtures/mock_blocs.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockDashboardBloc dashboardBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    dashboardBloc = MockDashboardBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => dashboardBloc.state).thenReturn(DashboardInitial());
  });

  Widget build() => DashboardPage(onTabChange: (_) {});

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<DashboardBloc>.value(value: dashboardBloc),
        ],
        child: child,
      );

  group('DashboardPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        build(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'dashboard_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        build(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'dashboard_dark');
    });
  });
}
```

> **Dependency note:** uses `mocktail` (already a dep via `bloc_test`). If you see a "mocktail not found" error, add `mocktail: ^1.0.3` to `dev_dependencies` in `app/pubspec.yaml` and run `flutter pub get`.

- [ ] **Step 7: Write golden test for `HomePage`**

Create `app/test/presentation/pages/dashboard/home_page_golden_test.dart` following the same pattern as Step 6. `HomePage` requires `StoreBloc` + `CartBloc` + `DashboardBloc` + `ProductListBloc` + `FinanceBloc`. Provide `MockXxxBloc` for each; initial states are fine.

> **Tip:** if writing all 5 mocks is overwhelming, use a `Bloc.observer`-free test strategy: mock just `StoreBloc` + `DashboardBloc`, wrap `HomePage` in a `MultiBlocProvider` that also supplies **real** instances of the other blocs with empty datasources. The goldens only need the first-frame layout, not real data.

- [ ] **Step 8: Write golden test for `MorePage`**

Create `app/test/presentation/pages/dashboard/more_page_golden_test.dart`. `MorePage` needs `StoreBloc` only (and reads the store id from it).

- [ ] **Step 9: Run golden tests — expect failure (no baseline PNGs yet)**

Run: `cd app && flutter test test/presentation/pages/dashboard/`
Expected: 3 test files × 2 tests each = 6 failures, each complaining "Golden file not found".

- [ ] **Step 10: Generate baseline goldens**

Run: `cd app && flutter test --update-goldens test/presentation/pages/dashboard/`
Expected: 6 new PNG files under `app/test/presentation/pages/dashboard/goldens/`.

- [ ] **Step 11: Visually inspect generated PNGs**

Open the 6 new PNG files. Verify:
- `dashboard_light.png` / `dashboard_dark.png` show the correct theme
- Dark variants have `#0F0A1A` background, light text, purple accents
- Light variants look identical to the pre-migration screenshots

If a golden looks wrong (e.g., font not loaded, overflow), fix the test helper or the page, regenerate, and re-inspect.

- [ ] **Step 12: Re-run tests, confirm they now pass**

Run: `cd app && flutter test test/presentation/pages/dashboard/`
Expected: all 6 tests pass.

- [ ] **Step 13: Smoke test on emulator**

Run the app (`flutter run` should already be running from the Sprint 1 session). Toggle dark mode in Settings → Ещё → navigate to Главная (DashboardPage). Verify dark background, light text. Toggle back to light, verify.

- [ ] **Step 14: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/dashboard/ app/test/presentation/pages/dashboard/
git commit -m "$(cat <<'EOF'
feat(theme): migrate dashboard pages to theme-aware colors

Replaces hardcoded AppColors.lightX refs with context.X getters in
dashboard_page, home_page, more_page. Adds golden tests (light +
dark) for each screen. Smoke-tested on Android emulator.

Part of Sprint 2 Phase 1 — core navigation tabs.
EOF
)"
```

---

## Task 2: Migrate `product` folder (Phase 1)

**Files:**
- Modify: all 8 files in `app/lib/presentation/pages/product/`
- Create: 8 corresponding golden tests in `app/test/presentation/pages/product/`

- [ ] **Step 1: List files and audit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
ls app/lib/presentation/pages/product/
for f in app/lib/presentation/pages/product/*.dart; do
  echo "$f: $(grep -c 'AppColors\.light' "$f") light refs"
done
```

- [ ] **Step 2: Migrate each file following the Canonical Procedure**

Open each file in order:
- `product_list_page.dart`
- `product_detail_page.dart`
- `add_product_step1_page.dart`
- `add_product_step2_page.dart`
- `add_product_step3_page.dart`
- `categories_page.dart`
- `import_products_page.dart`
- `empty_products_page.dart` (verify real filename)

For each: add `import '../../../core/theme/theme_extensions.dart';` (use the correct number of `../` for that file's depth — dashboard files use 3, sub-step files may use 4). Apply the color mapping table. Remove `const` from Scaffold where required.

> **Worked example (`product_list_page.dart`):** lines containing `AppColors.lightBackground` → `context.bg`; `AppColors.lightSurface` → `context.surface`; `AppColors.lightTextPrimary` → `context.textPrimary`. Exact line numbers vary by file — use your editor's Find+Replace within the file.

- [ ] **Step 3: Run `flutter analyze` for the folder**

Run: `cd app && flutter analyze lib/presentation/pages/product/`
Expected: "No issues found!"

- [ ] **Step 4: Write golden tests for all 8 pages**

Create `app/test/presentation/pages/product/<page>_golden_test.dart` following the Task 1 Step 6 template. Each file has two `testGoldens` blocks (light + dark). Mock `ProductListBloc` and `StoreBloc`; add any additional blocs per page needs (e.g., `CategoryBloc` for category page).

> **DRY tip:** if several product pages share the same bloc requirements, consider a shared `_buildProductPage(Widget page)` helper in the test file. But keep it inside each test file — don't extract into `test/helpers/` unless 5+ tests use it.

- [ ] **Step 5: Generate baselines**

```bash
cd app && flutter test --update-goldens test/presentation/pages/product/
```

- [ ] **Step 6: Visually inspect all 16 PNGs**

- [ ] **Step 7: Smoke test** — hot restart emulator; navigate Product list → Detail → Add steps 1/2/3 → Categories → Import, in both light and dark.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/product/ app/test/presentation/pages/product/
git commit -m "feat(theme): migrate product pages to theme-aware colors

Part of Sprint 2 Phase 1 — product catalog screens (8 files, 51 refs)."
```

---

## Task 3: Migrate `pos` folder (Phase 1)

**Files:** 5 files in `app/lib/presentation/pages/pos/`; 5 corresponding golden tests.

- [ ] **Step 1: Audit**

```bash
ls app/lib/presentation/pages/pos/
for f in app/lib/presentation/pages/pos/*.dart; do
  echo "$f: $(grep -c 'AppColors\.light' "$f") light refs"
done
```

- [ ] **Step 2: Migrate each file** — apply Canonical Procedure. Files include `pos_checkout_page.dart`, `cash_payment_page.dart`, `credit_sale_page.dart`, `sale_success_page.dart`, `receipt_preview_page.dart`.

- [ ] **Step 3: `flutter analyze lib/presentation/pages/pos/`** — must be clean.

- [ ] **Step 4: Write 5 golden tests** — mock `CheckoutBloc`, `CartBloc`, `StoreBloc`. For `sale_success_page` and `receipt_preview_page`, pass a fake `Sale` entity as the route extra.

- [ ] **Step 5: Generate baselines** — `flutter test --update-goldens test/presentation/pages/pos/`.

- [ ] **Step 6: Inspect PNGs** — 10 files.

- [ ] **Step 7: Smoke test** — POS checkout flow in both themes.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/pos/ app/test/presentation/pages/pos/
git commit -m "feat(theme): migrate pos pages to theme-aware colors

Part of Sprint 2 Phase 1 — POS checkout flow (5 files, 39 refs)."
```

---

## Task 4: Migrate `finance` folder (Phase 1)

**Files:** 9 files in `app/lib/presentation/pages/finance/`; 9 golden tests.

This is the largest Phase 1 folder (92 refs). Likely files: `finance_dashboard_page.dart`, `balance_page.dart`, `credits_page.dart`, `investments_page.dart`, `currencies_page.dart`, `expenses_page.dart`, `add_expense_page.dart`, `delivery_page.dart` (if routed here), `report_page.dart`.

- [ ] **Step 1: Audit per-file refs** — see command in Task 1 Step 1.

- [ ] **Step 2: Migrate each file** following the Canonical Procedure. Watch out for `_StatCard`, `_PeriodButton`, and other private widgets inside these files — they also need `context.X` getters, which means passing `BuildContext` through if they don't already have it.

- [ ] **Step 3: `flutter analyze lib/presentation/pages/finance/`** — must be clean.

- [ ] **Step 4: Write 9 golden tests** — mock `FinanceBloc`, `ExpenseBloc`, `DebtBloc` (investments page uses it), `CurrencyBloc`, `StoreBloc`.

- [ ] **Step 5: Generate baselines** — `flutter test --update-goldens test/presentation/pages/finance/`.

- [ ] **Step 6: Inspect PNGs** — 18 files.

- [ ] **Step 7: Smoke test** — navigate all finance sub-screens in both themes.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/finance/ app/test/presentation/pages/finance/
git commit -m "feat(theme): migrate finance pages to theme-aware colors

Part of Sprint 2 Phase 1 — finance dashboard and sub-screens
(9 files, 92 refs)."
```

---

## Task 5: Migrate `settings` folder (Phase 1)

**Files:** 13 files in `app/lib/presentation/pages/settings/`; 13 golden tests.

Tied with `finance` for most refs (92). Files include `settings_page.dart`, `edit_profile_page.dart`, `subscription_page.dart`, `receipt_template_page.dart`, `printer_settings_page.dart`, `my_stores_page.dart`, `telegram_bot_settings_page.dart`, `kkm_settings_page.dart`, `language_settings_page.dart`, `scanner_settings_page.dart`, `discounts_page.dart`, `offline_mode_page.dart`, `notification_settings_page.dart`.

- [ ] **Step 1: Audit per-file refs**.

- [ ] **Step 2: Migrate each file**. `subscription_page.dart` is the longest (~800+ lines); take it in sections. `edit_profile_page.dart` contains an avatar widget with its own color logic — watch for hex literals that should also migrate.

- [ ] **Step 3: `flutter analyze lib/presentation/pages/settings/`** — must be clean.

- [ ] **Step 4: Write 13 golden tests**. Mock `SettingsBloc`, `StoreBloc`, `PrinterBloc`, `SubscriptionBloc` (if exists), plus any feature-specific blocs.

> **Special case — `subscription_page.dart`:** includes gradient CTAs and tinted backgrounds that should stay on brand gradients. Don't replace `AppColors.gradientStart/Mid/End` — those are brand.

- [ ] **Step 5: Generate baselines** — 26 files.

- [ ] **Step 6: Inspect PNGs**.

- [ ] **Step 7: Smoke test** — especially the theme toggle on `settings_page` itself (meta-test: toggle dark mode, watch the current page flip).

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/settings/ app/test/presentation/pages/settings/
git commit -m "feat(theme): migrate settings pages to theme-aware colors

Part of Sprint 2 Phase 1 — all 13 settings sub-pages (92 refs).
Includes subscription, printer, telegram bot, my-stores, and theme
toggle meta-case verified on emulator."
```

---

## Phase 1 Checkpoint

- [ ] **Phase 1 regression smoke** — kill and relaunch the app (`q` in flutter run, then `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4455/api`). Navigate through all 5 main tabs in light theme → no regressions. Switch to dark → all 5 tabs now render dark correctly. Switch back to light.

- [ ] **Record progress** — append to `docs/superpowers/plans/2026-04-19-ui-ux-sprint-2-page-theme-migration.md`:

```
- 2026-04-19: Phase 1 complete — dashboard, product, pos, finance, settings migrated. 38 files, 291 refs → 0.
```

(Or if you prefer a separate progress log, create `docs/superpowers/progress/2026-04-sprint-2.md`.)

---

## Task 6: Migrate `customer` folder (Phase 2)

**Files:** 3 files in `app/lib/presentation/pages/customer/`; 3 golden tests.

Likely: `customer_list_page.dart`, `customer_detail_page.dart`, `add_customer_page.dart`.

- [ ] **Step 1: Audit**

```bash
for f in app/lib/presentation/pages/customer/*.dart; do
  echo "$f: $(grep -c 'AppColors\.light' "$f")"
done
```

- [ ] **Step 2: Migrate each file** per Canonical Procedure.

- [ ] **Step 3: `flutter analyze lib/presentation/pages/customer/`** — clean.

- [ ] **Step 4: Write 3 golden tests** — mock `CustomerListBloc`, `CustomerDetailBloc`, `StoreBloc`.

- [ ] **Step 5: Generate baselines.**

- [ ] **Step 6: Inspect 6 PNGs.**

- [ ] **Step 7: Smoke test** — open Customers → Detail → Add from emulator.

- [ ] **Step 8: Commit**

```bash
git add app/lib/presentation/pages/customer/ app/test/presentation/pages/customer/
git commit -m "feat(theme): migrate customer pages to theme-aware colors"
```

---

## Task 7: Migrate `supplier` folder (Phase 2)

**Files:** 2 files in `app/lib/presentation/pages/supplier/`; 2 golden tests.

- [ ] **Steps 1–8:** same as Task 6, but for `supplier_list_page.dart`, `supplier_detail_page.dart` (or similar). Mock `SupplierListBloc`, `StoreBloc`.

Commit: `git commit -m "feat(theme): migrate supplier pages to theme-aware colors"`

---

## Task 8: Migrate `sales` folder (Phase 2)

**Files:** 4 files in `app/lib/presentation/pages/sales/`; 4 golden tests.

Likely: `sales_history_page.dart`, `sale_detail_page.dart`, `sale_refund_page.dart`, `empty_sales_page.dart`.

- [ ] **Steps 1–8:** same as Task 6, but for sales. Mock `SalesHistoryBloc`, `StoreBloc`. `sale_detail_page` and `sale_refund_page` may take a `Sale` entity as route extra — use the same fake sale pattern as in Task 3 (pos).

Commit: `git commit -m "feat(theme): migrate sales pages to theme-aware colors"`

---

## Task 9: Migrate `notifications` folder (Phase 2)

**Files:** 2 files; 2 golden tests.

- [ ] **Steps 1–8:** same as Task 6. Mock a `NotificationsBloc` if it exists; otherwise mock whatever the page currently watches.

Commit: `git commit -m "feat(theme): migrate notifications pages to theme-aware colors"`

---

## Phase 2 Checkpoint

- [ ] **Phase 2 regression smoke** — from Dashboard, navigate to Customers / Suppliers / Sales History / Notifications in both themes. Verify no visual regressions on Phase 1 screens.

---

## Task 10: Migrate `debt` folder (Phase 3)

**Files:** 3 files; 3 golden tests. Mock `DebtBloc`, `StoreBloc`.

- [ ] **Steps 1–8** per Canonical Procedure.

Commit: `git commit -m "feat(theme): migrate debt pages to theme-aware colors"`

---

## Task 11: Migrate `payroll` folder (Phase 3)

**Files:** 2 files; 2 golden tests. Mock `PayrollBloc`, `StoreBloc`. `add_adjustment_page.dart` takes a staff member ID — pass a fake.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate payroll pages to theme-aware colors"`

---

## Task 12: Migrate `zakat` folder (Phase 3)

**Files:** 3 files; 3 golden tests. Mock `ZakatBloc`, `StoreBloc`.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate zakat pages to theme-aware colors"`

---

## Phase 3 Checkpoint

- [ ] **Phase 3 regression smoke** — navigate Finance → Debts, Finance → Payroll, Finance → Zakat. Verify in both themes.

---

## Task 13: Migrate `stock` folder (Phase 4)

**Files:** 1 file (`stock_intake_page.dart`); 1 golden test. Mock `StockIntakeBloc`, `ProductListBloc`, `StoreBloc`.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate stock pages to theme-aware colors"`

---

## Task 14: Migrate `inventory` folder (Phase 4)

**Files:** 1 file (`inventory_count_page.dart`); 1 golden test.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate inventory pages to theme-aware colors"`

---

## Task 15: Migrate `delivery` folder (Phase 4)

**Files:** 3 files; 3 golden tests. Mock `DeliveryBloc` (or equivalent), `StoreBloc`.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate delivery pages to theme-aware colors"`

---

## Phase 4 Checkpoint

- [ ] **Phase 4 regression smoke** — stock intake → inventory count → delivery flow. Both themes.

---

## Task 16: Migrate `auth` folder (Phase 5)

**Files:** 5 files; 5 golden tests. Mock `AuthBloc`.

- [ ] **Steps 1–8** — note that auth pages (login, register, OTP, forgot, create password) have the brand gradient background. Don't replace `AppColors.gradientStart/Mid/End`.

Commit: `git commit -m "feat(theme): migrate auth pages to theme-aware colors"`

---

## Task 17: Migrate `onboarding` folder (Phase 5)

**Files:** 2 files (`splash_page.dart`, `onboarding_page.dart`); 2 golden tests.

- [ ] **Steps 1–8** — `splash_page.dart` has only brand purple bg; likely needs no migration except adding the golden test. `onboarding_page.dart` may have more refs.

Commit: `git commit -m "feat(theme): migrate onboarding pages to theme-aware colors"`

---

## Task 18: Migrate `store` folder (Phase 5)

**Files:** 1 file (`create_store_page.dart`); 1 golden test.

Audit shows **0 refs** — code migration is a no-op; just write the golden test.

- [ ] **Step 1: Confirm 0 refs**

```bash
grep -c "AppColors\.light" app/lib/presentation/pages/store/create_store_page.dart
```
Expected: `0`

- [ ] **Step 2: Skip migration** — no code changes.

- [ ] **Step 3: Write golden test** — mock `StoreBloc`.

- [ ] **Step 4: Generate baselines.**

- [ ] **Step 5: Inspect PNGs — confirm both themes render correctly** (this page may already be theme-aware).

- [ ] **Step 6: Commit**

```bash
git add app/test/presentation/pages/store/
git commit -m "test(theme): add golden tests for store/create_store_page (already theme-aware)"
```

---

## Task 19: Migrate `roles` folder (Phase 5)

**Files:** 1 file; 1 golden test. Mock `RolesBloc`.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate roles pages to theme-aware colors"`

---

## Task 20: Migrate `shifts` folder (Phase 5)

**Files:** 3 files; 3 golden tests. Mock `ShiftBloc`, `StoreBloc`.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate shifts pages to theme-aware colors"`

---

## Task 21: Migrate `staff` folder (Phase 5)

**Files:** 3 files; 3 golden tests. Mock `StaffBloc`, `StaffFormBloc`, `RolesBloc`, `StoreBloc`.

- [ ] **Steps 1–8**.

Commit: `git commit -m "feat(theme): migrate staff pages to theme-aware colors"`

---

## Phase 5 Checkpoint

- [ ] **Phase 5 regression smoke** — auth flow (logout and log back in), shifts, staff, roles.

---

## Task 22: Sprint 2 Wrap-Up

**Files:**
- Modify: `docs/superpowers/plans/2026-04-19-ui-ux-sprint-2-page-theme-migration.md` (mark complete)

- [ ] **Step 1: Sprint-level grep check**

Run:
```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" app/lib/presentation/pages
```
Expected: **0 matches** (exit code 1, no output).

If ANY match appears, identify the folder and return to the relevant task to finish the migration.

- [ ] **Step 2: Full test suite**

Run: `cd app && flutter test`
Expected: all golden tests pass. If any fail on a Phase-N page, inspect the diff PNG and decide: fix the page, or regenerate if the change is intentional.

- [ ] **Step 3: Full `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Final smoke test**

Kill the app, relaunch with `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4455/api`. In **light** theme, walk through all 21 feature areas (use bottom nav + Ещё → deeper screens) and confirm no regressions. Toggle to **dark** theme — repeat the walkthrough. Toggle back to light.

- [ ] **Step 5: Persistence test**

With dark mode ON, kill the app (`q` in `flutter run`, then relaunch). Confirm the app reopens in dark theme. Toggle back to light, kill again, relaunch — should open in light.

- [ ] **Step 6: Update Sprint 2 plan with completion note**

Append to the top of this plan file:

```markdown
## Sprint 2 Complete — 2026-04-XX

- 77 files migrated across 21 folders
- 0 `AppColors.(light|dark)(Background|Surface|Border|Text)` refs remaining in pages
- 140+ golden tests (light + dark) passing
- Emulator verified: dark mode applies to all screens; persists across app restarts
- Follow-up: Sprint 3 will migrate `lib/presentation/widgets/**`
```

- [ ] **Step 7: Final commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/plans/2026-04-19-ui-ux-sprint-2-page-theme-migration.md
git commit -m "$(cat <<'EOF'
docs(sprint-2): mark page theme migration complete

All 77 pages across 21 folders now use context.X theme-aware getters.
140+ golden tests (light + dark) in place. Emulator-verified dark
mode persists across restarts.

Next: Sprint 3 — migrate shared widgets.
EOF
)"
```

---

## Execution Notes

- **Dependency discovery:** the `mocktail` / `bloc_test` dep may not be in the current `pubspec.yaml`. Task 0 Step 6 handles it, but if you hit a missing-package error mid-task, pause and add the dep before continuing.
- **Real bloc fallback:** if mocking a bloc (e.g., `FinanceBloc`) is too tedious because of its many events, you can provide a real instance with mocked data sources. The goldens need only the first-frame rendered state — no real navigation.
- **Private widgets inside page files:** if a page defines `class _FooCard extends StatelessWidget` internally and it uses `AppColors.lightX`, the migration applies the same mapping to those classes. They already have `BuildContext` in `build`, so `context.X` works directly.
- **Gradient / brand colors to KEEP (never migrate):** `AppColors.gradientStart`, `gradientMid`, `gradientEnd`, and raw bundle colors like `Color(0xFF6366F1)` where they represent fixed brand marks (logo tint, app icon inside SplashPage).
- **If a page breaks visually after migration:** inspect the diff between the old golden (you can temporarily `git stash` to restore the pre-migration version) and the new one. Common issues: (1) a `Color.withOpacity(0.05)` looked fine on light but invisible on dark; swap to `context.surface.withOpacity(0.1)` or similar. (2) a border color that was `AppColors.lightBorder` is now too bright in dark — verify `context.border` has enough contrast in `theme_extensions.dart`; if not, file a theme-token fix.
