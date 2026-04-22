# Sprint 4 — Cleanup & Polish Design

**Date:** 2026-04-20
**Status:** Approved — ready for plan
**Depends on:** Sprint 3 Widget Theme Migration (complete, commits `094dd26` → `2411d25`)
**Related specs:**
- [Sprint 2 — Page Theme Migration](2026-04-19-ui-ux-sprint-2-page-theme-migration-design.md)
- [Sprint 3 — Widget Theme Migration](2026-04-20-ui-ux-sprint-3-widget-theme-migration-design.md)

---

## 1. Overview & Scope

### Goal
Close the technical debt backlog accumulated during Sprint 1–3: remove the last `AppColors.light/dark` external references, fix pre-existing lint issues, migrate deprecated APIs, and add minimal integration-test coverage for bottom-sheet and dialog chrome.

### Problem statement
After Sprint 3, the app compiles clean in terms of behavior, but `flutter analyze` reports 44 info-level lints + 1 warning. Two `AppColors` constants still have exactly one external reference each (`primaryDark` in `quick_product_chip.dart:55`, `overlay` in `z_report_page.dart:315`). The `AppButton` widget overflows narrow constraints, forcing `Size(412, 900)` workarounds in the `receipt_preview_page` golden test. `RadioListTile` uses deprecated `groupValue`/`onChanged` APIs. The `_SectionItem.stub` parameter in `finance_dashboard_page.dart` is accepted but never supplied — dead code. Finally, Sprint 3 direct-host pattern for sheet/dialog goldens did not cover chrome behavior (backdrop dismiss, callbacks) — integration tests are the right coverage level for that.

Sprint 4 closes all of the above in one focused pass (~2–2.5 h).

### In scope

**5 cleanup tasks:**

1. **Remove last external `AppColors.light/dark` refs**
   - `lib/presentation/widgets/pos/quick_product_chip.dart:55` — `AppColors.primaryDark` → `context.primary`
   - `lib/presentation/pages/shifts/z_report_page.dart:315` — `AppColors.overlay` → `context.shadowColor`
   - Audit resulting `AppColors` usage: if any `light*`/`dark*` constant has 0 refs even inside `core/theme/`, remove it from `app_colors.dart`
2. **AppButton overflow fix**
   - `lib/presentation/widgets/common/app_button.dart:106` — Row with Icon+SizedBox+Text overflows narrow constraints (~125 px)
   - Fix: wrap `Text` in `Flexible` with `overflow: TextOverflow.ellipsis`
   - Remove `size: const Size(412, 900)` workaround + both `tester.takeException()` calls in `receipt_preview_page_golden_test.dart`
3. **RadioListTile deprecation**
   - `lib/presentation/pages/settings/scanner_settings_page.dart` — 4 deprecated `groupValue`/`onChanged` sites
   - `lib/presentation/pages/zakat/zakat_settings_page.dart` — 2 deprecated sites
   - Migrate to `RadioGroup<T>(groupValue:, onChanged:, child: Column(children: [RadioListTile(value:, …), …]))`
4. **`_SectionItem.stub` unused parameter**
   - `lib/presentation/pages/finance/finance_dashboard_page.dart:397`
   - Decision tree:
     - If stub/disabled UX is wanted → wire it in `_buildSectionsGrid` (dimmed icon/label)
     - If no product plan for it → remove the parameter entirely
   - Prefer removal unless there's a clear product intent in nearby comments/TODOs
5. **2 integration smoke tests** for chrome behavior (see §3)

**Green analyze pass (auto + manual):**

- `dart fix --apply` on the app package:
  - 22 × `use_null_aware_elements` (data-layer remote datasources)
  - 5 × `unnecessary_underscores` (test files)
  - 4 × `unnecessary_brace_in_string_interps` (widgets/shifts)
  - 1 × `unnecessary_import`
  - Some `deprecated_member_use` items `dart fix` can auto-resolve
- Manual patch:
  - 1 × `use_build_context_synchronously` — add `if (!context.mounted) return;` after the await
  - 1 × `unused_element_parameter` — resolved by Task 4 above
- Sprint-level acceptance: `flutter analyze` reports **0 issues** (errors/warnings/info all clean)

### Out of scope (deferred)

- **Sprint 5:** new design tokens (elevations, motion curves, radii)
- **Sprint 5:** accessibility / contrast audit, WCAG AA compliance check
- **Sprint 5+:** comprehensive integration tests (auth flow, checkout flow, navigation flow)
- Dark-mode `context.onWarning = Colors.black` verification on real UI (Sprint 5 accessibility pass)
- Renaming `AppColors` constants or changing `ThemeColors` API surface

### Sprint-level acceptance

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze
# → No issues found!

flutter test
# → all tests pass (~332 = 328 existing + 4 new chrome tests)

grep -rE "AppColors\.(light|dark)" lib/ \
  | grep -v "core/theme\|core/constants/app_colors.dart\|core/constants/app_gradients.dart"
# → 0 matches

grep -rn "AppColors\.primaryDark\|AppColors\.overlay" lib/
# → only hits inside core/theme/ or core/constants/app_colors.dart (or removed entirely)
```

---

## 2. Task Breakdown & Execution Order

Order is low-risk → high-risk. One commit per task (8 total).

### Task 1 — `dart fix --apply` auto-cleanup (~15 min)

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
dart fix --dry-run     # preview the changes
dart fix --apply       # apply
flutter analyze        # observe remaining issues
flutter test           # nothing should break
```

Most targets:
- `use_null_aware_elements` — e.g., `if (x != null) foo(x)` → `foo(x?)`
- `unnecessary_underscores` — e.g., `final __ = ...` → `final _ = ...`
- `unnecessary_brace_in_string_interps` — e.g., `"${foo}"` → `"$foo"`
- `unnecessary_import` — removes stale imports

**Commit:** `chore(lint): apply dart fix auto-cleanup`

### Task 2 — `use_build_context_synchronously` manual fix (~5 min)

Located via: `flutter analyze 2>&1 | grep use_build_context_synchronously`.

Pattern fix:
```dart
// before
await doSomething();
Navigator.of(context).pop();

// after
await doSomething();
if (!context.mounted) return;
Navigator.of(context).pop();
```

**Commit:** `fix(lint): guard async context use with mounted check`

### Task 3 — Migrate last `AppColors` external refs (~10 min)

- `lib/presentation/widgets/pos/quick_product_chip.dart:55` — `AppColors.primaryDark` → `context.primary`. Requires a `BuildContext` in scope; already inside `build`. If the widget is `const`, remove `const`.
- `lib/presentation/pages/shifts/z_report_page.dart:315` — `AppColors.overlay` → `context.shadowColor`. Same remove-const handling if needed.
- Audit: `grep -rnE "AppColors\.(primaryDark|overlay)" lib/` — if 0 refs anywhere (including theme), remove the constants from `app_colors.dart`. Run `dart fix` after to tidy any orphan imports.
- Regen goldens for `pos/quick_product_chip` and `shifts/z_report_page` (there's likely a page golden for z_report).

**Commit:** `refactor(theme): migrate last AppColors external refs`

### Task 4 — `_SectionItem.stub` decision (~10 min)

File: `lib/presentation/pages/finance/finance_dashboard_page.dart` around lines 390–400.

Read the surrounding code (`_buildSectionsGrid` and `_SectionItem` usages). Decision:

- **If `stub` should render dimmed tiles** → wire `Opacity(opacity: 0.4)` or `foregroundColor: context.textMuted` in `_buildSectionsGrid` when `item.stub == true`, and mark a few tiles (e.g., "Доставка", "Валюты") as stub so the feature is exercised.
- **If no product decision exists** → remove `stub` from `_SectionItem` constructor and field.

Default to remove unless there's clear product intent.

**Commit:** `refactor(finance): remove unused _SectionItem.stub param` (OR `feat(finance): render stub tiles dimmed`)

### Task 5 — AppButton overflow fix (~15 min)

File: `lib/presentation/widgets/common/app_button.dart:106`.

Current:
```dart
return Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 20, color: color),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(...)),
  ],
);
```

Fix:
```dart
return Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 20, color: color),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        text,
        style: TextStyle(...),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
);
```

Then revert workarounds in `app/test/presentation/pages/pos/receipt_preview_page_golden_test.dart`:
- Remove `size: const Size(412, 900),` from both `testGoldens` calls
- Remove both `tester.takeException();` lines (if they were only absorbing the overflow)

Regen `receipt_preview_light.png` and `receipt_preview_dark.png` at default 390 × 844. Visually confirm the button text truncates gracefully (no yellow/black overflow stripes).

**Commit:** `fix(widgets): AppButton Row fits narrow constraints with Flexible text`

### Task 6 — RadioListTile → RadioGroup migration (~30–40 min)

Files:
- `lib/presentation/pages/settings/scanner_settings_page.dart` (4 sites, lines ~116, 117, 137, 138)
- `lib/presentation/pages/zakat/zakat_settings_page.dart` (2 sites, around line 143)

Old API:
```dart
RadioListTile<String>(
  value: 'opt1',
  groupValue: _selected,
  onChanged: (v) => setState(() => _selected = v),
  title: Text('Option 1'),
),
RadioListTile<String>(
  value: 'opt2',
  groupValue: _selected,
  onChanged: (v) => setState(() => _selected = v),
  title: Text('Option 2'),
),
```

New API:
```dart
RadioGroup<String>(
  groupValue: _selected,
  onChanged: (v) => setState(() => _selected = v),
  child: Column(
    children: const [
      RadioListTile<String>(value: 'opt1', title: Text('Option 1')),
      RadioListTile<String>(value: 'opt2', title: Text('Option 2')),
    ],
  ),
),
```

Regen goldens for `scanner_settings`, `zakat_settings`, and `zakat_breakdown_card` (widget test may include a radio tile).

**Commit:** `refactor: migrate RadioListTile to RadioGroup ancestor pattern`

### Task 7 — 2 integration smoke tests (~30–45 min)

See §3 for full test code.

**Commit:** `test(widgets): add chrome smoke tests for AppBottomSheet and AppDialog`

### Task 8 — Final acceptance + wrap-up (~5 min)

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze            # 0 issues expected
flutter test               # all pass
```

Update the plan file with a "Sprint 4 Complete" note at the top.

**Commit:** `docs(sprint-4): mark cleanup complete`

---

## 3. Integration Smoke Test Design

Two new test files in `app/test/presentation/widgets/common/`. These use `testWidgets` (not `testGoldens`) and exercise real `showModalBottomSheet` / `showDialog` calls to verify chrome behavior. No golden PNGs produced.

### 3.1 `app_bottom_sheet_chrome_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/widgets/common/app_bottom_sheet.dart';

void main() {
  Widget buildHost() => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => const AppBottomSheet(
                  title: 'Test title',
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sheet body'),
                  ),
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      );

  group('AppBottomSheet chrome', () {
    testWidgets('shows title and body when opened', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Test title'), findsOneWidget);
      expect(find.text('Sheet body'), findsOneWidget);
    });

    testWidgets('dismisses when tapping backdrop', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);

      // Tap well above the sheet — that's the scrim/backdrop
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(find.text('Sheet body'), findsNothing);
    });
  });
}
```

### 3.2 `app_dialog_chrome_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/widgets/common/app_dialog.dart';

void main() {
  late int confirmCount;
  late int cancelCount;

  Widget buildHost() {
    confirmCount = 0;
    cancelCount = 0;
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: ctx,
              builder: (dctx) => AppDialog(
                title: 'Confirm',
                message: 'Are you sure?',
                confirmLabel: 'Yes',
                cancelLabel: 'No',
                onConfirm: () {
                  confirmCount++;
                  Navigator.of(dctx).pop();
                },
                onCancel: () {
                  cancelCount++;
                  Navigator.of(dctx).pop();
                },
              ),
            ),
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );
  }

  group('AppDialog chrome', () {
    testWidgets('shows title, message, and both buttons', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('confirm callback fires and dismisses dialog', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(confirmCount, 1);
      expect(cancelCount, 0);
      expect(find.text('Are you sure?'), findsNothing);
    });
  });
}
```

### Notes

- Constructor args (`title`, `child`, `confirmLabel`, `cancelLabel`, etc.) must match real `AppBottomSheet` and `AppDialog` public API — read the source before writing. If the real widget takes different parameter names, adapt the test calls; don't modify the widget to fit the test.
- If either widget already provides a `static show(...)` helper, use that in the host builder — it's a better smoke test of the real call site.
- Use `pumpAndSettle` after each user action (tap, etc.). Default 10-second timeout is fine.
- Do NOT add golden assertions — these tests focus on chrome behavior, not pixels. Goldens for the widget body are already in Sprint 3 tests.

---

## 4. Acceptance, Risks, Effort

### Sprint 4 DONE when

1. `flutter analyze` → **0 issues** (errors, warnings, info — all clean)
2. `flutter test` → all pass (~332 = 328 existing + 4 new chrome tests)
3. `grep -rE "AppColors\.(light|dark)" lib/ | grep -v "core/theme\|core/constants/app_colors.dart\|core/constants/app_gradients.dart"` → 0 matches
4. `grep -rn "AppColors\.primaryDark\|AppColors\.overlay" lib/` → only inside `core/theme/` or `app_colors.dart` (or removed entirely)
5. `receipt_preview_page_golden_test.dart` — no `Size(412, 900)` override, no `tester.takeException()` workarounds
6. Zero `deprecated_member_use` lints; `RadioListTile` migrated to `RadioGroup`
7. 2 new chrome test files, 4 new `testWidgets` cases
8. 8 commits (one per task); final commit updates the plan with "Sprint 4 Complete" note

### Metrics

| Metric | Before Sprint 4 | After |
|---|---|---|
| `flutter analyze` issues | 44 info + 1 warning | 0 |
| `AppColors` external refs | 2 | 0 |
| Integration chrome tests | 0 | 4 (2 files × 2 cases) |
| Total tests | 328 | ~332 |
| Repo size delta | — | +minor (2 test files, no PNGs) |

### Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| `dart fix --apply` regresses behavior | Low | `--dry-run` first; `flutter test` after apply |
| RadioGroup migration changes layout pixels | Medium | Regen scanner_settings + zakat_settings goldens; visual spot-check |
| `AppButton` `Flexible` fix breaks other callers | Low | Full `flutter test` — goldens cover every call site |
| `_SectionItem.stub` removal hides an intended feature | Low | Default to remove only if no intent signal; flag to user post-task |
| `showModalBottomSheet` test flaky on animation | Medium | `pumpAndSettle` consistently; fallback `tester.pump(Duration(milliseconds: 200))` if needed |
| Dead-constant removal orphans imports | Low | `flutter analyze` catches; `dart fix` cleans orphans |
| `RadioGroup` import path differs by Flutter version | Low | Verify in `flutter/material.dart` before migration; fall back to leaving lints as-is and noting in Concerns |

### Estimated effort

| Task | Time |
|---|---|
| 1. `dart fix --apply` | 15 m |
| 2. `use_build_context_synchronously` manual | 5 m |
| 3. `AppColors` external refs + dead-const cleanup | 10 m |
| 4. `_SectionItem.stub` decision | 10 m |
| 5. `AppButton` overflow + test cleanup | 15 m |
| 6. RadioListTile → RadioGroup | 30–40 m |
| 7. 2 chrome smoke tests | 30–45 m |
| 8. Final analyze + test + docs | 5 m |
| **Total** | **~2–2.5 h** |

### Dependencies

All ready:
- Flutter 3.10+ SDK (supports `RadioGroup` after 3.32.0)
- `dart fix` CLI
- `golden_toolkit`, `bloc_test`, `mocktail` — unchanged
- `ThemeColors` extension — 23 tokens, no changes needed

### Deferred to Sprint 5+

- New design tokens (elevations, motion curves, radii)
- Accessibility audit, contrast ratios, touch target sizes, WCAG AA check
- Comprehensive integration tests (auth flow, checkout flow, navigation flow)
- `context.onWarning = Colors.black` real-UI verification

---

## 5. Next Step

After approval, invoke `superpowers:writing-plans` to generate the Sprint 4 implementation plan at `docs/superpowers/plans/2026-04-20-ui-ux-sprint-4-cleanup-polish.md`.
