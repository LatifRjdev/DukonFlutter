# Sprint 3 — Widget Theme Migration Design

**Date:** 2026-04-20
**Status:** Approved — ready for plan
**Depends on:** Sprint 2 Page Theme Migration (complete, commits `85dd52c` → `a7dbf4d`)
**Related specs:**
- [2026-04-18 UI/UX Redesign Design](2026-04-18-ui-ux-redesign-design.md)
- [2026-04-19 Sprint 2 Page Theme Migration Design](2026-04-19-ui-ux-sprint-2-page-theme-migration-design.md)

---

## 1. Overview & Scope

### Goal
Migrate every shared widget in `lib/presentation/widgets/**/*.dart` from hardcoded `AppColors.light*` / `AppColors.dark*` references to theme-aware `context.*` getters. After Sprint 3, dark mode applies uniformly across the entire app (pages + widgets), and `AppColors.light*` / `AppColors.dark*` is referenced only inside `theme_extensions.dart` and `app_theme.dart`.

### Problem statement
Sprint 2 migrated all 77 pages; Phase 1 common widgets (bottom sheets, dialogs, nav bar, glass card) were deferred. Sprint 3 closes that gap. Sprint 1 (theme infrastructure) and Sprint 2 (page migration) give us 23 `ThemeColors` tokens, `golden_toolkit` test infra, and a proven mechanical migration pattern — Sprint 3 applies them to 47 widget files.

### In scope
- All files under `lib/presentation/widgets/**/*.dart` (47 files across 12 folders)
- ~30 files with migratable hardcoded refs (**116 AppColors.light/dark + 12 Colors.white** sites)
- Same mapping table from Sprint 2 (see §4)
- Golden tests per widget (light + dark), ~75–95 new PNGs
- Public widget API is preserved — parameter signatures don't change
- Regeneration of existing page goldens after Phase 1 (common/) because shared widgets affect page snapshots

### Out of scope (deferred)
- **Sprint 4:** Cleanup pass — remove unused `AppColors.lightX` / `darkX` constants that no callers reference
- **Sprint 4:** Integration tests for bottom sheet / dialog chrome behavior (dismiss backdrop, handle bar drag)
- **Sprint 5+:** New design tokens (elevations, motion curves, additional radii)
- Separate sprint: accessibility / contrast audit

### Sprint-level acceptance

```bash
# Sprint 3 check
grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" lib/presentation/widgets
# → 0 matches

# Combined presentation-layer check (pages + widgets)
grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" lib/presentation
# → 0 matches
```

---

## 2. Priority & Per-Folder Workflow

### Priority order (4 phases)

**Phase 1 — common/ (critical path, all pages depend on it):**
1. `glass_card.dart` (1 leftover ref from Sprint 1)
2. `app_loading.dart`, `quantity_selector.dart` (1 ref each — warm-up)
3. `app_bottom_nav_bar.dart` (3 refs)
4. `otp_input.dart`, `step_indicator.dart` (3 refs each)
5. `app_dialog.dart` (5 refs — every dialog in the app)
6. `app_bottom_sheet.dart` (5 refs — every sheet in the app)
7. `barcode_scanner_sheet.dart` (6 refs)
8. Remaining common widgets (audit at start of phase)

**Phase 1 checkpoint:** `flutter test --update-goldens test/presentation/pages/` + spot-check 5–10 dark PNGs → commit `test(theme): regen page goldens after common widget migration` if no visual regression.

**Phase 2 — core nav feature widgets:**
1. `dashboard/` (sale_list_item, quick_action_card — 7 refs)
2. `product/` (product_card, product_list_item — 9 refs)
3. `pos/` (receipt_widget 15 refs, cart_item_widget, sales_filter_sheet, payment_method_tile — 33 refs; pos is heaviest)

**Phase 3 — finance cluster:**
4. `finance/`
5. `debt/` (debt_card, payment_form — 5 refs)
6. `payroll/`
7. `zakat/`

**Phase 4 — admin & edge:**
8. `settings/` (settings_tile — 2 refs)
9. `shifts/`
10. `staff/`
11. `onboarding/`

### Per-folder workflow

For each folder:

1. **Audit** — `ls` + per-file `grep -cE "AppColors\.(light|dark)"`
2. **Bulk sed migration** (same script as Sprint 2, see §4)
3. **`flutter analyze lib/presentation/widgets/<folder>`** — fix `invalid_constant` errors surgically
4. **`Colors.white` scan** — decide per site (on primary/semantic bg → `context.onX`; on gradient → keep)
5. **Write golden tests** per widget — Scaffold-host wrapper (see §3)
6. **`flutter test --update-goldens test/presentation/widgets/<folder>/`**
7. **Visually inspect** new goldens
8. **`flutter test`** without `--update-goldens` — all pass
9. **Commit:** `feat(theme): migrate <folder> widgets to theme-aware colors`

### Between phases

- **End of Phase 1:** regen page goldens + commit (see checkpoint above)
- **End of Phases 2–4:** manual emulator smoke — navigate to pages containing the migrated widgets in both themes, confirm no visual regressions

---

## 3. Golden Test Infrastructure for Widgets

### New helper (added in Phase 1, Task 0)

`app/test/helpers/golden_pump_helper.dart` gains one function:

```dart
/// Wraps a standalone widget in a Scaffold for golden coverage.
/// Use for any widget that does NOT have its own Scaffold (most shared components).
Future<void> pumpWidgetWithTheme(
  WidgetTester tester,
  Widget widget, {
  required Brightness brightness,
  Widget Function(Widget child)? wrap,
  Size size = const Size(390, 844),
  EdgeInsets padding = const EdgeInsets.all(16),
  Alignment alignment = Alignment.center,
}) async {
  final hosted = Scaffold(
    body: SafeArea(
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: widget),
      ),
    ),
  );
  await pumpPageWithTheme(
    tester, hosted,
    brightness: brightness, wrap: wrap, size: size,
  );
}
```

This reuses the existing `pumpPageWithTheme` — only adds the Scaffold wrapper. No new imports or dependencies.

### Test file layout

```
test/presentation/widgets/
├── common/
│   ├── app_bottom_sheet_golden_test.dart
│   ├── app_dialog_golden_test.dart
│   ├── app_bottom_nav_bar_golden_test.dart
│   ├── glass_card_golden_test.dart
│   ├── … (one _golden_test.dart per widget source file)
│   └── goldens/
│       ├── app_bottom_sheet_light.png
│       ├── app_bottom_sheet_dark.png
│       └── …
├── dashboard/
├── finance/
├── pos/
└── … (mirror src/ structure)
```

### Template — regular widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/glass_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('GlassCard goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        const SizedBox(
          width: 300,
          child: GlassCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sample content'),
            ),
          ),
        ),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'glass_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        const SizedBox(
          width: 300,
          child: GlassCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sample content'),
            ),
          ),
        ),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'glass_card_dark');
    });
  });
}
```

### Template — bottom sheet / dialog (direct widget host per clarification Q2)

```dart
group('AppBottomSheet goldens', () {
  testGoldens('light theme', (tester) async {
    await pumpWidgetWithTheme(
      tester,
      AppBottomSheet(
        title: 'Sample title',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Item 1'),
            Text('Item 2'),
          ],
        ),
      ),
      brightness: Brightness.light,
      alignment: Alignment.bottomCenter, // sheet sticks to bottom
    );
    tester.takeException();
    await screenMatchesGolden(tester, 'app_bottom_sheet_light');
  });
  // …dark theme…
});
```

We host the sheet widget directly instead of going through `showModalBottomSheet`. Chrome behavior (dismiss backdrop, handle bar drag) is covered by manual smoke tests on the emulator — not by goldens.

### Widgets with variants

Some widgets expose multiple visual states (e.g., `GradientButton` has primary/secondary/outlined). One test file per widget source file, with `testGoldens('<variant> light/dark'…)` pairs per variant. Each variant = 2 PNGs (light + dark).

### Widgets requiring bloc state or route args

- Widget takes an entity parameter (e.g., `SaleListItem(sale: ...)`): construct a deterministic fake inline
- Widget reads a bloc via `context.read<X>()`: pass `wrap: wrapWithBlocs` like in page tests (same pattern as Sprint 2)
- Widget uses `sl<X>()` directly: register mock/fake via GetIt in `setUp`, unregister in `tearDown` (Sprint 2 pos/finance precedent)

### Decisions

| Decision | Choice | Reason |
|---|---|---|
| Host pattern | `Scaffold(body: …)` wrapper, centered | Simple single template; full-screen bg not a diff burden |
| Bottom sheets / dialogs | Direct widget host, not `showModalBottomSheet` | Chrome bugs are rare; content regressions are what goldens catch |
| Surface size | 390×844 logical (iPhone 13) | Matches Sprint 2 page goldens |
| Goldens count | ~75–95 new PNGs | ~3–5 MB repo delta; acceptable |

---

## 4. Migration Rules & Color Mapping

Same rules as Sprint 2 — the 23 `ThemeColors` tokens introduced in Task 2.5 of that sprint cover every legitimate migration path.

### Mapping table

| Old reference | New reference | Notes |
|---|---|---|
| `AppColors.lightBackground` | `context.bg` | |
| `AppColors.lightSurface` | `context.surface` | |
| `AppColors.lightSurfaceElevated` | `context.surfaceMuted` | |
| `AppColors.lightBorder` | `context.border` | |
| `AppColors.lightTextPrimary` | `context.textPrimary` | |
| `AppColors.lightTextSecondary` | `context.textSecondary` | |
| `AppColors.lightTextHint` | `context.textMuted` | |
| `AppColors.successBg` / `errorBg` / `warningBg` / `infoBg` | `context.successBg` / `dangerBg` / `warningBg` / `infoBg` | Tokens added in Sprint 2 Task 2.5 |
| `AppColors.success` / `error` / `warning` / `info` (semantic fg) | `context.success` / `danger` / `warning` / `info` | |
| `AppColors.overlay` as `BoxShadow.color` | `context.shadowColor` | |
| `Colors.white` as `foregroundColor` on primary btn | `context.onPrimary` | |
| `Colors.white` as icon on semantic bg | `context.onSuccess` / `onDanger` / `onWarning` / `onInfo` | `onWarning` = black (WCAG) |
| `AppColors.primary` / `secondary` | **unchanged** | Brand-neutral, accepted per Sprint 2 |
| `AppColors.gradientStart/Mid/End` | **unchanged** | Brand |
| `AppColors.onPrimary` | **unchanged** | Constant = `Colors.white`, used by theme |

### const policy (widget-specific)

**Rule 1 — Widget `build` method:**
If `build()` uses `context.X`, the widget or its parent cannot be `const` at call sites where that color-carrying sub-tree renders. Remove `const` surgically from `invalid_constant` offenders.

**Rule 2 — Widget parameters:**
The widget class itself MAY remain `const`. Only inner widgets that contain `context.X` must drop `const`:

```dart
// ✅ OK — GlassCard is const, Text child drops const because TextStyle uses context
GlassCard(
  child: Text('x', style: TextStyle(color: context.textPrimary)),
)

// ❌ invalid_constant — can't const-construct with a non-const color value
const GlassCard(accentColor: context.primary, ...)
```

**Rule 3 — Public API preservation:**
A widget's constructor signature does NOT change during Sprint 3. If a widget accepts `Color` parameters from callers, those parameters stay — we only migrate internal constants. This prevents the migration from cascading into unmigrated code.

**Rule 4 — static methods without `BuildContext`:**
If a widget has a `static Color typeColor(...)` helper that uses `AppColors.lightX`, add a `BuildContext context` parameter and thread it through from callers. Precedent: `transaction_detail_page._statusColor(context, status)` in Sprint 2.

### Bulk sed script (same as Sprint 2)

```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/widgets/<folder>
for f in *.dart; do
  sed -i '' \
    -e 's/AppColors\.lightBackground/context.bg/g' \
    -e 's/AppColors\.lightSurfaceElevated/context.surfaceMuted/g' \
    -e 's/AppColors\.lightSurface/context.surface/g' \
    -e 's/AppColors\.lightBorder/context.border/g' \
    -e 's/AppColors\.lightTextPrimary/context.textPrimary/g' \
    -e 's/AppColors\.lightTextSecondary/context.textSecondary/g' \
    -e 's/AppColors\.lightTextHint/context.textMuted/g' \
    -e 's/AppColors\.successBg/context.successBg/g' \
    -e 's/AppColors\.errorBg/context.dangerBg/g' \
    -e 's/AppColors\.warningBg/context.warningBg/g' \
    -e 's/AppColors\.infoBg/context.infoBg/g' \
    "$f"
  if grep -q "context\." "$f" && ! grep -q "theme_extensions.dart" "$f"; then
    sed -i '' -e "/import '..\/..\/..\/core\/constants\/app_colors.dart';/a\\
import '../../../core/theme/theme_extensions.dart';
" "$f"
  fi
done
```

Three `../` = correct depth from `widgets/<folder>/` to `core/theme/`.

---

## 5. Acceptance Criteria, Risks, Effort

### Sprint 3 DONE when

1. `grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" lib/presentation/widgets` → **0 matches**
2. Combined check: `grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" lib/presentation` → **0 matches**
3. `flutter analyze` — 0 errors, 0 warnings (info-level pre-existing lints OK)
4. `flutter test` — full suite passes (~263–283 total, roughly 75–95 new widget goldens on top of Sprint 2's 188)
5. Phase 1 checkpoint done: page goldens regenerated, 5–10 dark PNGs spot-checked for visual regression
6. Manual smoke test on Android emulator:
   - Open app in light theme → no visual regressions on any tab
   - Switch to dark → shared widgets (bottom sheets, nav bar, glass cards) adapt correctly
   - Open at least 3 modal/sheet widgets — dark bg, light text, visible borders
   - Hot restart → dark persists
7. One commit per folder + one phase-boundary commit (regen page goldens after Phase 1)
8. Final commit: `docs: mark Sprint 3 widget migration complete` with the plan file updated

### Metrics

| Metric | Before Sprint 3 | After |
|---|---|---|
| `AppColors.(light\|dark)` refs in `widgets/` | 116 | 0 |
| `AppColors.(light\|dark)` refs in `presentation/` total | 116 (widgets only) | 0 |
| Widget golden PNGs | 0 | ~75–95 |
| Total tests | 188 | ~263–283 |
| Repo size delta | — | +3–5 MB |

### Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Page goldens regress after `common/` migration | **High** | Phase 1 ends with `flutter test --update-goldens test/presentation/pages/` + spot-check 5–10 dark PNGs |
| Widget signature changes cascade into page callers | Medium | Rule 3 — public API preserved. If a signature MUST change, fix callers in the same commit |
| Bottom sheet direct-host misses chrome bugs | Low | Manual modal smoke test on emulator at Phase 1 checkpoint |
| GetIt / SharedPreferences leaks between widget tests | Medium | Per-test register/unregister pattern (Sprint 2 pos/finance precedent) |
| `showModalBottomSheet` / `showDialog` goldens fail without Navigator context | Low | Direct host approach (Q2 Rule B) bypasses `Navigator` by pumping the sheet body directly |
| Widgets with async data (e.g., `receipt_widget` builds from `Sale`) | Medium | Construct fake `Sale` inline; accept loading/empty rendering (Sprint 2 precedent) |
| Widget const-removals break unrelated callers | Low | Rule 2 — keep widget class `const` where possible; only inner children drop const |

### Estimated effort

| Phase | Folders | Files (approx) | Effort |
|---|---|---|---|
| Phase 1 — common | 1 | ~10 files | 3–4 h (incl. phase-end page goldens regen) |
| Phase 2 — core nav | 3 (dashboard, product, pos) | ~10 files (pos heaviest at 33 refs) | 3–4 h |
| Phase 3 — finance cluster | 4 (finance, debt, payroll, zakat) | ~10 files | 2–3 h |
| Phase 4 — admin & edge | 4 (settings, shifts, staff, onboarding) | ~8 files | 2 h |
| **Total** | **12 folders** | **~38 files with refs + 9 without** | **10–13 h** |

Comparable to Sprint 2's effort — fewer files (47 vs 77), but widgets are more varied and need host-wrappers for testing.

### Dependencies

All infrastructure is in place from Sprint 1 + Sprint 2:
- `golden_toolkit: ^0.15.0`, `bloc_test`, `mocktail` — installed
- `ThemeColors` extension with 23 tokens — ready
- `pumpPageWithTheme` helper — ready
- `pumpWidgetWithTheme` helper — added in Phase 1 Task 0 (new code, 1 function, ~10 lines)
- `MockStoreBloc` + `fakeStoreLoaded()` fixtures — ready

### Deferred work (explicit)

- **Sprint 4:** remove unused `AppColors.lightX` / `darkX` constants that no callers reference
- **Sprint 4:** integration tests for bottom sheet / dialog chrome (dismiss, handle bar drag)
- **Sprint 5+:** new design tokens (elevations, motion curves, additional radii)
- Separate sprint: accessibility / contrast audit

---

## 6. Next Step

After this spec is approved, invoke `superpowers:writing-plans` to generate the Sprint 3 implementation plan at `docs/superpowers/plans/2026-04-20-ui-ux-sprint-3-widget-theme-migration.md`.
