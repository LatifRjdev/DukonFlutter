# Sprint 3 — Widget Theme Migration Implementation Plan

## Sprint 3 Complete — 2026-04-20

- **47 widgets migrated** across 12 folders (common, dashboard, product, pos, finance, debt, payroll, zakat, settings, shifts, staff, onboarding)
- **0** `AppColors.(light|dark)(Background|Surface|Border|Text)` refs remaining in `app/lib/presentation/widgets/`
- **Combined check:** 0 refs remaining in `app/lib/presentation/` (pages + widgets complete)
- **328/328 tests passing** (140 pre-sprint + ~188 new widget + regen page goldens)
- Commits: Task 0 setup → 13 folder tasks (one commit per folder) → goldens regen + import cleanup
- Follow-up: Sprint 4 — remove unused `AppColors.lightX/darkX` constants + integration tests for sheet/dialog chrome

---

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate 47 shared widgets in `lib/presentation/widgets/**` from hardcoded `AppColors.lightX` / `Colors.white` refs to theme-aware `context.X` getters, finishing dark-mode support app-wide.

**Architecture:** Manual prioritized migration across 4 phases — common widgets first (shared infrastructure), then feature widgets by tab visibility. After Phase 1, regenerate page goldens to absorb visual shifts from shared widget changes. One commit per folder/group.

**Tech Stack:** Flutter 3.10, `golden_toolkit`, `bloc_test`, `mocktail`. `ThemeColors` extension (23 tokens) from Sprint 1+2 already in place.

**Spec:** [docs/superpowers/specs/2026-04-20-ui-ux-sprint-3-widget-theme-migration-design.md](../specs/2026-04-20-ui-ux-sprint-3-widget-theme-migration-design.md)

---

## Audit Summary

### Per-folder reference counts

| Phase | Folder | Files | AppColors refs | Colors.white |
|---|---|---|---|---|
| 1 | common | 22 | 28 | 21 |
| 2 | dashboard | 3 | 7 | 0 |
| 2 | product | 2 | 9 | 0 |
| 2 | pos | 5 | 33 | 1 |
| 3 | finance | 4 | 7 | 1 |
| 3 | debt | 2 | 5 | 1 |
| 3 | payroll | 2 | 8 | 0 |
| 3 | zakat | 1 | 3 | 0 |
| 4 | settings | 1 | 2 | 0 |
| 4 | shifts | 2 | 7 | 0 |
| 4 | staff | 2 | 5 | 0 |
| 4 | onboarding | 1 | 2 | 0 |
| **Total** | **12** | **47** | **116** | **24** |

### Common/ file breakdown (22 files)

**Files WITH AppColors refs (migrate):**
- `glass_card.dart` (1 ref)
- `app_loading.dart` (1 ref)
- `quantity_selector.dart` (1 ref)
- `app_bottom_nav_bar.dart` (3 refs, 1 white)
- `otp_input.dart` (3 refs)
- `step_indicator.dart` (3 refs, 2 white)
- `app_dialog.dart` (5 refs, 1 white)
- `app_bottom_sheet.dart` (5 refs)
- `barcode_scanner_sheet.dart` (6 refs)

**Files WITH Colors.white only (keep white on brand gradients; no migration needed):**
- `app_button.dart` (1 white — on primary bg)
- `app_chip.dart` (2 whites — on primary bg)
- `app_snackbar.dart` (2 whites — on semantic bg)
- `gradient_header.dart` (5 whites — on brand gradient)
- `offline_banner.dart` (4 whites — on danger bg)
- `subscription_banner.dart` (3 whites — on brand gradient)

**Files with NO migratable refs (no code changes; goldens optional):**
- `app_card.dart`, `app_empty_state.dart`, `app_error_widget.dart`, `app_search_bar.dart`, `app_text_field.dart`, `phone_input_field.dart`, `plan_gate.dart`

---

## Canonical Widget Migration Procedure

Referenced by Tasks 1–13. Task 0 introduces the shared test helper.

1. **Audit folder:** `ls` + per-file `grep -cE "AppColors\.(light|dark)"` and `grep -c "Colors\.white"`.
2. **Bulk sed** AppColors mapping:
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
3. **`flutter analyze lib/presentation/widgets/<folder>/`** — fix `invalid_constant` errors surgically (remove `const` from offending widget). Don't remove `const` from widgets without errors.
4. **`Colors.white` per-site scan:** `grep -n "Colors\.white" <file>`. For each hit, inspect 2 lines of context:
   - On `AppColors.primary` / `context.primary` bg → replace with `context.onPrimary`
   - On `context.success/danger/warning/info` bg → replace with `context.onSuccess/onDanger/onWarning/onInfo`
   - On brand gradient (`AppColors.gradient*`) → **keep** `Colors.white`
5. **Verify:** `grep -rcE "AppColors\.(light|dark)" lib/presentation/widgets/<folder>/` → all 0.
6. **Write golden tests per widget** in `app/test/presentation/widgets/<folder>/<name>_golden_test.dart`. Use `pumpWidgetWithTheme` helper (added in Task 0). Two `testGoldens` per widget (light + dark). For sheets/dialogs, use `alignment: Alignment.bottomCenter` (sheet) or `alignment: Alignment.center` (dialog).
7. **Generate baselines:** `flutter test --update-goldens test/presentation/widgets/<folder>/`.
8. **Visually inspect** each new PNG.
9. **Re-run** `flutter test test/presentation/widgets/<folder>/` — all pass.
10. **Commit per folder:** `feat(theme): migrate <folder> widgets to theme-aware colors`

---

## Task 0: Add `pumpWidgetWithTheme` Helper

**Files:**
- Modify: `app/test/helpers/golden_pump_helper.dart` (append new function)

- [ ] **Step 1: Open the helper file**

Read current content:
```bash
cat /Users/latifrjdev/Downloads/Dukon/app/test/helpers/golden_pump_helper.dart
```
It currently exports `pumpPageWithTheme`. We append a widget-host variant.

- [ ] **Step 2: Append the new function**

Append this to `app/test/helpers/golden_pump_helper.dart`:

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
    tester,
    hosted,
    brightness: brightness,
    wrap: wrap,
    size: size,
  );
}
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze test/helpers/`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/test/helpers/golden_pump_helper.dart
git commit -m "$(cat <<'EOF'
test(theme): add pumpWidgetWithTheme helper for Sprint 3

Wraps standalone widgets in a Scaffold + Align + Padding host for
golden coverage. Reuses pumpPageWithTheme under the hood — no new
deps. Used by Sprint 3 widget golden tests.
EOF
)"
```

---

## Task 1: Phase 1A — common/ simple widgets

**Files (9 source + 9 test files):**
- Modify: `app/lib/presentation/widgets/common/glass_card.dart` (1 ref)
- Modify: `app/lib/presentation/widgets/common/app_loading.dart` (1 ref)
- Modify: `app/lib/presentation/widgets/common/quantity_selector.dart` (1 ref)
- Modify: `app/lib/presentation/widgets/common/app_bottom_nav_bar.dart` (3 refs, 1 white)
- Modify: `app/lib/presentation/widgets/common/otp_input.dart` (3 refs)
- Modify: `app/lib/presentation/widgets/common/step_indicator.dart` (3 refs, 2 white)
- Create: 6 `_golden_test.dart` files + goldens/

- [ ] **Step 1: Audit**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
for f in lib/presentation/widgets/common/{glass_card,app_loading,quantity_selector,app_bottom_nav_bar,otp_input,step_indicator}.dart; do
  echo "$f: $(grep -cE 'AppColors\.(light|dark)' "$f") refs, $(grep -c 'Colors\.white' "$f") white"
done
```
Expected: counts match the audit table above.

- [ ] **Step 2: Bulk sed migration on 6 files**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/widgets/common
for f in glass_card.dart app_loading.dart quantity_selector.dart app_bottom_nav_bar.dart otp_input.dart step_indicator.dart; do
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

- [ ] **Step 3: Analyze + fix const errors**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze lib/presentation/widgets/common/glass_card.dart lib/presentation/widgets/common/app_loading.dart lib/presentation/widgets/common/quantity_selector.dart lib/presentation/widgets/common/app_bottom_nav_bar.dart lib/presentation/widgets/common/otp_input.dart lib/presentation/widgets/common/step_indicator.dart`

For each `invalid_constant` error, remove `const` from the enclosing widget. Example:
```dart
// before
return const BoxDecoration(color: context.surface);

// after (const removed because context.surface is non-const)
return BoxDecoration(color: context.surface);
```

Re-run analyze until "No issues found!".

- [ ] **Step 4: Colors.white scan**

```bash
grep -n "Colors\.white" lib/presentation/widgets/common/{app_bottom_nav_bar,step_indicator}.dart
```

For each hit, inspect 2 lines of context:
- If on `AppColors.primary` / `context.primary` bg → replace with `context.onPrimary`
- If on `context.success` etc → replace with `context.onSuccess` etc
- If on gradient → keep

`app_bottom_nav_bar.dart` has 1 white, likely the "selected icon" on primary bg — replace with `context.onPrimary`.
`step_indicator.dart` has 2 whites — inspect: likely a completed-checkmark on success bg (→ `context.onSuccess`) and an active step text (→ `context.onPrimary`). Apply per context.

- [ ] **Step 5: Verify 0 refs**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -rcE "AppColors\.(light|dark)" lib/presentation/widgets/common/{glass_card,app_loading,quantity_selector,app_bottom_nav_bar,otp_input,step_indicator}.dart
```
Expected: all `:0`.

- [ ] **Step 6: Create `glass_card_golden_test.dart`**

Note: `app/test/presentation/widgets/common/glass_card_test.dart` already exists (non-golden widget test). We ADD a new `_golden_test.dart` alongside it — don't overwrite.

Create `app/test/presentation/widgets/common/glass_card_golden_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/glass_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('GlassCard goldens', () {
    Widget sample() => const SizedBox(
          width: 300,
          child: GlassCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sample content'),
            ),
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'glass_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'glass_card_dark');
    });
  });
}
```

- [ ] **Step 7: Create `app_loading_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/app_loading.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppLoading goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        const AppLoading(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_loading_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        const AppLoading(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_loading_dark');
    });
  });
}
```

> **If `AppLoading` has a spinner animation:** `pumpAndSettle` inside the helper will time out. If you see a timeout error at `screenMatchesGolden`, switch to `testWidgets` + 2 explicit `tester.pump()` calls + `matchesGoldenFile` directly (see Sprint 2 `subscription_page_golden_test.dart` pattern).

- [ ] **Step 8: Create `quantity_selector_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/quantity_selector.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('QuantitySelector goldens', () {
    Widget sample() => QuantitySelector(
          value: 3,
          onChanged: (_) {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'quantity_selector_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'quantity_selector_dark');
    });
  });
}
```

Check the actual `QuantitySelector` constructor if the sample above doesn't compile — inspect `lib/presentation/widgets/common/quantity_selector.dart` and adapt.

- [ ] **Step 9: Create `app_bottom_nav_bar_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/app_bottom_nav_bar.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppBottomNavBar goldens', () {
    Widget sample() => AppBottomNavBar(
          currentIndex: 0,
          onTap: (_) {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_bottom_nav_bar_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_bottom_nav_bar_dark');
    });
  });
}
```

Adapt constructor args to match the real `AppBottomNavBar` — inspect the file first.

- [ ] **Step 10: Create `otp_input_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/otp_input.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('OtpInput goldens', () {
    Widget sample() => OtpInput(
          length: 6,
          onCompleted: (_) {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'otp_input_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'otp_input_dark');
    });
  });
}
```

- [ ] **Step 11: Create `step_indicator_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/step_indicator.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('StepIndicator goldens', () {
    Widget sample() => const StepIndicator(currentStep: 2, totalSteps: 3);

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'step_indicator_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'step_indicator_dark');
    });
  });
}
```

- [ ] **Step 12: Generate baselines**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens test/presentation/widgets/common/glass_card_golden_test.dart test/presentation/widgets/common/app_loading_golden_test.dart test/presentation/widgets/common/quantity_selector_golden_test.dart test/presentation/widgets/common/app_bottom_nav_bar_golden_test.dart test/presentation/widgets/common/otp_input_golden_test.dart test/presentation/widgets/common/step_indicator_golden_test.dart
```

Expected: 12 new PNG files.

- [ ] **Step 13: Visually inspect** each PNG in `app/test/presentation/widgets/common/goldens/`. Confirm dark/light variants differ meaningfully (bg, text contrast, borders).

- [ ] **Step 14: Re-run without update-goldens**

```bash
flutter test test/presentation/widgets/common/glass_card_golden_test.dart test/presentation/widgets/common/app_loading_golden_test.dart test/presentation/widgets/common/quantity_selector_golden_test.dart test/presentation/widgets/common/app_bottom_nav_bar_golden_test.dart test/presentation/widgets/common/otp_input_golden_test.dart test/presentation/widgets/common/step_indicator_golden_test.dart
```

Expected: 12 tests pass.

- [ ] **Step 15: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/widgets/common/ app/test/presentation/widgets/common/
git commit -m "$(cat <<'EOF'
feat(theme): migrate common simple widgets to theme-aware colors

6 widgets migrated (glass_card, app_loading, quantity_selector,
app_bottom_nav_bar, otp_input, step_indicator) — 12 refs → 0 +
3 Colors.white resolved. 12 goldens added as regression baseline.

Part of Sprint 3 Phase 1 — shared infrastructure.
EOF
)"
```

---

## Task 2: Phase 1B — common/ complex widgets (dialog, sheets)

**Files (3 source + 3 test files):**
- Modify: `app/lib/presentation/widgets/common/app_dialog.dart` (5 refs, 1 white)
- Modify: `app/lib/presentation/widgets/common/app_bottom_sheet.dart` (5 refs)
- Modify: `app/lib/presentation/widgets/common/barcode_scanner_sheet.dart` (6 refs)
- Create: 3 `_golden_test.dart` files + goldens

Note: `barcode_scanner_sheet_test.dart` already exists (non-golden); our new `_golden_test.dart` is separate.

- [ ] **Step 1: Bulk sed migration**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/widgets/common
for f in app_dialog.dart app_bottom_sheet.dart barcode_scanner_sheet.dart; do
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

- [ ] **Step 2: Analyze + fix const errors**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze lib/presentation/widgets/common/app_dialog.dart lib/presentation/widgets/common/app_bottom_sheet.dart lib/presentation/widgets/common/barcode_scanner_sheet.dart
```

Fix `invalid_constant` errors surgically.

- [ ] **Step 3: Colors.white in app_dialog**

```bash
grep -n "Colors\.white" lib/presentation/widgets/common/app_dialog.dart
```

Inspect context and decide: `Colors.white` on primary button bg → `context.onPrimary`; on gradient → keep.

- [ ] **Step 4: Verify 0 refs**

```bash
grep -rcE "AppColors\.(light|dark)" lib/presentation/widgets/common/app_dialog.dart lib/presentation/widgets/common/app_bottom_sheet.dart lib/presentation/widgets/common/barcode_scanner_sheet.dart
```
All `:0`.

- [ ] **Step 5: Create `app_dialog_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/app_dialog.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppDialog goldens', () {
    Widget sample() => AppDialog(
          title: 'Подтверждение',
          message: 'Вы уверены, что хотите продолжить?',
          confirmLabel: 'Да',
          cancelLabel: 'Отмена',
          onConfirm: () {},
          onCancel: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'app_dialog_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'app_dialog_dark');
    });
  });
}
```

Adapt constructor args to real `AppDialog` API — inspect the source file first.

- [ ] **Step 6: Create `app_bottom_sheet_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/app_bottom_sheet.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppBottomSheet goldens', () {
    Widget sample() => AppBottomSheet(
          title: 'Пример заголовка',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ListTile(leading: Icon(Icons.star), title: Text('Пункт 1')),
              ListTile(leading: Icon(Icons.bookmark), title: Text('Пункт 2')),
            ],
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_bottom_sheet_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_bottom_sheet_dark');
    });
  });
}
```

- [ ] **Step 7: Create `barcode_scanner_sheet_golden_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/barcode_scanner_sheet.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('BarcodeScannerSheet goldens', () {
    Widget sample() => BarcodeScannerSheet(onScan: (_) {});

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'barcode_scanner_sheet_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'barcode_scanner_sheet_dark');
    });
  });
}
```

If `BarcodeScannerSheet` initializes a real camera (`mobile_scanner` plugin), the golden will crash. Fallback: stub or mock the scanner init; or wrap in a try/catch and accept the error state. Simpler — inspect the widget and if it requires camera, reduce test to pumping just the overlay/chrome part.

- [ ] **Step 8: Generate goldens**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens test/presentation/widgets/common/app_dialog_golden_test.dart test/presentation/widgets/common/app_bottom_sheet_golden_test.dart test/presentation/widgets/common/barcode_scanner_sheet_golden_test.dart
```

- [ ] **Step 9: Visually inspect** 6 new PNGs.

- [ ] **Step 10: Re-run**

```bash
flutter test test/presentation/widgets/common/app_dialog_golden_test.dart test/presentation/widgets/common/app_bottom_sheet_golden_test.dart test/presentation/widgets/common/barcode_scanner_sheet_golden_test.dart
```

Expected: 6 pass.

- [ ] **Step 11: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/widgets/common/ app/test/presentation/widgets/common/
git commit -m "$(cat <<'EOF'
feat(theme): migrate common complex widgets to theme-aware colors

3 widgets migrated (app_dialog, app_bottom_sheet,
barcode_scanner_sheet) — 16 refs → 0 + 1 Colors.white resolved.
6 goldens added.

Completes Sprint 3 Phase 1 — shared infrastructure.
EOF
)"
```

---

## Phase 1 Checkpoint — Regenerate Page Goldens

- [ ] **Step 1: Regenerate all page goldens**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens test/presentation/pages/
```

Expected: some goldens update (shared widgets appear on pages). Others unchanged.

- [ ] **Step 2: Re-run without `--update-goldens`**

```bash
flutter test test/presentation/pages/
```

Expected: 188 tests pass.

- [ ] **Step 3: Spot-check 5–10 dark goldens**

Pick 5–10 dark PNGs that contain nav bars, dialogs, or bottom sheets — e.g.:
- `test/presentation/pages/dashboard/goldens/home_dark.png` (contains `AppBottomNavBar`)
- `test/presentation/pages/dashboard/goldens/dashboard_dark.png`
- `test/presentation/pages/product/goldens/product_list_dark.png`
- `test/presentation/pages/pos/goldens/pos_checkout_dark.png`
- `test/presentation/pages/finance/goldens/finance_dashboard_dark.png`
- `test/presentation/pages/settings/goldens/settings_dark.png`
- `test/presentation/pages/settings/goldens/my_stores_dark.png`

Open each. Confirm:
- Dark bg is `#0F0A1A` (not white)
- Text is light, readable
- No visible regressions from shared widget changes (nav bar selection highlight, dialog borders, etc.)

If ANY golden looks worse than before:
- Check which shared widget caused it (`git diff` the specific golden area)
- Inspect the migrated widget source
- If a `Colors.white` should have been `context.onPrimary` (or vice versa), fix at source, re-run `--update-goldens` for that single test, repeat spot-check

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/test/presentation/pages/
git commit -m "$(cat <<'EOF'
test(theme): regen page goldens after common widget migration

Absorbs visual shifts from Sprint 3 Phase 1 common widget migration
(app_bottom_nav_bar, app_dialog, app_bottom_sheet, glass_card, etc.).
Spot-checked 5-10 dark goldens — no regressions.
EOF
)"
```

---

## Task 3: Phase 2 — dashboard/

**Files (3 source + 3 test):**
- Modify: `app/lib/presentation/widgets/dashboard/sale_list_item.dart`
- Modify: `app/lib/presentation/widgets/dashboard/quick_action_card.dart`
- Modify: `app/lib/presentation/widgets/dashboard/stat_card.dart`

- [ ] **Step 1: Audit**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
ls lib/presentation/widgets/dashboard/
for f in lib/presentation/widgets/dashboard/*.dart; do
  echo "$f: $(grep -cE 'AppColors\.(light|dark)' "$f") refs, $(grep -c 'Colors\.white' "$f") white"
done
```

- [ ] **Step 2: Bulk sed per folder**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/widgets/dashboard
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

- [ ] **Step 3: Analyze + fix const**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze lib/presentation/widgets/dashboard/
```

- [ ] **Step 4: Verify 0 refs**

```bash
grep -rcE "AppColors\.(light|dark)" lib/presentation/widgets/dashboard/
```

- [ ] **Step 5: Write golden tests**

For each `.dart` file in `lib/presentation/widgets/dashboard/`, create a matching `<name>_golden_test.dart` in `app/test/presentation/widgets/dashboard/`. Example for `SaleListItem` (takes a `Sale` entity):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/domain/entities/sale.dart';
import 'package:dokonpro/presentation/widgets/dashboard/sale_list_item.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  Sale fakeSale() => Sale(
        id: 'sale-1',
        storeId: 'store-1',
        total: 125000,
        status: 'COMPLETED',
        createdAt: DateTime(2024, 1, 1),
        // fill other required fields per real Sale entity
      );

  group('SaleListItem goldens', () {
    Widget sample() => SaleListItem(sale: fakeSale());

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'sale_list_item_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'sale_list_item_dark');
    });
  });
}
```

Read `app/lib/domain/entities/sale.dart` to confirm required field names.

For `QuickActionCard`, likely takes `icon, label, onTap, color`:

```dart
group('QuickActionCard goldens', () {
  Widget sample() => QuickActionCard(
        icon: Icons.shopping_cart,
        label: 'Новая продажа',
        onTap: () {},
      );
  // … 2 testGoldens as above
});
```

- [ ] **Step 6: Generate goldens**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens test/presentation/widgets/dashboard/
```

- [ ] **Step 7: Re-run**

```bash
flutter test test/presentation/widgets/dashboard/
```

Expected: 6 pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/widgets/dashboard/ app/test/presentation/widgets/dashboard/
git commit -m "feat(theme): migrate dashboard widgets to theme-aware colors

3 widgets, 7 refs → 0. 6 goldens added. Part of Sprint 3 Phase 2."
```

---

## Task 4: Phase 2 — product/

**Files:** 2 widgets (`product_card.dart`, `product_list_item.dart`) — 9 refs total.

- [ ] **Steps 1–8:** Follow the exact same pattern as Task 3. Bulk sed → analyze → verify 0 refs → golden tests → generate → re-run → commit.

Widget golden tests need a fake `Product` entity. Read `app/lib/domain/entities/product.dart` for field names. Example:

```dart
Product fakeProduct() => Product(
      id: 'product-1',
      storeId: 'store-1',
      name: 'Тестовый товар',
      price: 15000,
      currency: 'TJS',
      // fill other required fields
    );
```

Commit: `feat(theme): migrate product widgets to theme-aware colors

2 widgets, 9 refs → 0. 4 goldens added. Part of Sprint 3 Phase 2."`

---

## Task 5: Phase 2 — pos/ (heaviest)

**Files:** 5 widgets — `receipt_widget.dart` (15 refs), `cart_item_widget.dart` (6), `sales_filter_sheet.dart` (6), `payment_method_tile.dart` (6), `quick_product_chip.dart` (remainder).

- [ ] **Steps 1–8:** Same pattern as Task 3.

Notable:
- `receipt_widget` likely takes `Sale` + line items — construct fake
- `sales_filter_sheet` may use `alignment: Alignment.bottomCenter`
- `payment_method_tile` is simple; test both selected/unselected states if the widget has them (2 × 2 = 4 goldens)
- `cart_item_widget` takes a cart line item — construct fake

Commit: `feat(theme): migrate pos widgets to theme-aware colors

5 widgets, 33 refs → 0 + 1 Colors.white resolved. 10 goldens added.
Part of Sprint 3 Phase 2 — heaviest folder."`

---

## Phase 2 Checkpoint — Manual Emulator Smoke

- [ ] Hot restart emulator:
```bash
echo "R" > /tmp/flutter_stdin   # or relaunch flutter run
```

- [ ] Navigate to Главная, Товары, Касса in both light + dark — confirm no visible regressions from the migrated dashboard/product/pos widgets.

---

## Task 6: Phase 3 — finance/

**Files:** 4 widgets — `expense_card.dart`, `period_selector.dart`, `profit_summary_card.dart`, `stat_summary_row.dart`. Total 7 refs + 1 white.

- [ ] **Steps 1–8:** Same pattern as Task 3.

Commit: `feat(theme): migrate finance widgets to theme-aware colors"`

---

## Task 7: Phase 3 — debt/

**Files:** 2 widgets (`debt_card.dart`, `payment_form.dart`) — 5 refs + 1 white.

- [ ] **Steps 1–8:** Same pattern.

`payment_form` may be a sheet/dialog — use `alignment: Alignment.bottomCenter` if needed.

Commit: `feat(theme): migrate debt widgets to theme-aware colors"`

---

## Task 8: Phase 3 — payroll/

**Files:** 2 widgets — `month_selector.dart`, `payroll_staff_card.dart`. 8 refs total.

- [ ] **Steps 1–8:** Same pattern.

Commit: `feat(theme): migrate payroll widgets to theme-aware colors"`

---

## Task 9: Phase 3 — zakat/

**Files:** 1 widget — `zakat_breakdown_card.dart`. 3 refs.

- [ ] **Steps 1–8:** Same pattern.

Commit: `feat(theme): migrate zakat widgets to theme-aware colors"`

---

## Phase 3 Checkpoint — Smoke Test

- [ ] Emulator hot restart, navigate Финансы → Долги → Зарплата → Закят in both themes.

---

## Task 10: Phase 4 — settings/

**Files:** 1 widget (`settings_tile.dart`) — 2 refs.

- [ ] **Steps 1–8:** Same pattern.

Commit: `feat(theme): migrate settings widgets to theme-aware colors"`

---

## Task 11: Phase 4 — shifts/

**Files:** 2 widgets — `shift_card.dart`, `current_shift_card.dart`. 7 refs total.

- [ ] **Steps 1–8:** Same pattern.

Note: Both files have pre-existing `unnecessary_brace_in_string_interps` info lints (from Sprint 2 full analyze). Leave as-is — not in scope.

Commit: `feat(theme): migrate shifts widgets to theme-aware colors"`

---

## Task 12: Phase 4 — staff/

**Files:** 2 widgets — `staff_card.dart`, `permission_toggle_row.dart`. 5 refs total.

- [ ] **Steps 1–8:** Same pattern.

Commit: `feat(theme): migrate staff widgets to theme-aware colors"`

---

## Task 13: Phase 4 — onboarding/

**Files:** 1 widget — `onboarding_slide.dart`. 2 refs.

- [ ] **Steps 1–8:** Same pattern. If the onboarding widget sits on a brand gradient, keep `Colors.white` on gradient text.

Commit: `feat(theme): migrate onboarding widgets to theme-aware colors"`

---

## Phase 4 Checkpoint — Smoke Test

- [ ] Emulator: open Настройки → (sub-screens) → Смены → Сотрудники. Toggle theme. Confirm no regressions.

---

## Task 14: Sprint 3 Wrap-Up

**Files:**
- Modify: `docs/superpowers/plans/2026-04-20-ui-ux-sprint-3-widget-theme-migration.md` (mark complete)

- [ ] **Step 1: Sprint-level grep check (widgets only)**

```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" app/lib/presentation/widgets
```

Expected: 0 matches (exit code 1, no output).

- [ ] **Step 2: Combined presentation-layer check**

```bash
grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" app/lib/presentation
```

Expected: 0 matches.

- [ ] **Step 3: Full test suite**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test
```

Expected: all tests pass (~263–283 total). If any new widget golden fails due to pre-existing test state issues (GetIt / SharedPreferences pollution), run that test in isolation to confirm the issue is isolation-only, then proceed.

- [ ] **Step 4: Full `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors, 0 warnings (info-level pre-existing lints OK).

- [ ] **Step 5: Manual smoke on Android emulator**

Kill app, relaunch:
```bash
ps aux | grep -E "flutter.*run -d emulator" | grep -v grep | awk '{print $2}' | xargs -r kill 2>/dev/null
sleep 1
rm -f /tmp/flutter_stdin
mkfifo /tmp/flutter_stdin
(sleep infinity > /tmp/flutter_stdin &)
cd /Users/latifrjdev/Downloads/Dukon/app && flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4455/api < /tmp/flutter_stdin > /tmp/flutter_run.log 2>&1 &
disown
```

Once the app is up:
- **Light theme walkthrough:** navigate through all 5 bottom-nav tabs + 5 sub-screens each + open at least 3 modal/sheet widgets (customer select, payment method, barcode scanner). No visual regressions.
- **Switch to dark:** Настройки → Тёмная тема toggle ON.
- **Dark theme walkthrough:** repeat the walkthrough. Shared widgets (bottom sheets, nav bar, glass cards, dialogs) adapt correctly. Text readable. Borders visible.
- **Kill + relaunch:** app opens in dark (SettingsBloc persisted the toggle).
- **Back to light:** toggle OFF, kill, relaunch → opens in light.

- [ ] **Step 6: Update the plan file with completion note**

Prepend to the top of the plan file (below the header block):

```markdown
## Sprint 3 Complete — 2026-04-20

- 47 widgets migrated across 12 folders
- 0 `AppColors.(light|dark)(Background|Surface|Border|Text)` refs remaining in `app/lib/presentation/widgets/`
- Combined check: 0 refs remaining in `app/lib/presentation/` (pages + widgets complete)
- ~75–95 new widget goldens passing (total suite: 263–283)
- Emulator-verified: dark mode applies uniformly; persists across restarts
- Follow-up: Sprint 4 — cleanup (remove unused `AppColors.lightX/darkX` constants) + integration tests for sheet/dialog chrome
```

- [ ] **Step 7: Final commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/plans/2026-04-20-ui-ux-sprint-3-widget-theme-migration.md
git commit -m "$(cat <<'EOF'
docs(sprint-3): mark widget theme migration complete

All 47 widgets across 12 folders now use context.X theme-aware
getters. Combined presentation-layer check: 0 AppColors.(light|dark)
refs remaining. Dark mode applies app-wide and persists across
restarts.

Next: Sprint 4 — AppColors cleanup + sheet/dialog chrome integration
tests.
EOF
)"
```

---

## Execution Notes

- **Per-file audit is mandatory before migration.** Widgets have more varied constructors than pages; blindly sed'ing a file without inspecting it can leave `Colors.white` on brand gradient (correct) vs on primary bg (should be `context.onPrimary`).
- **Widget has `show()` static method or similar pattern:** e.g., `AppDialog.show(context, ...)`. The golden test doesn't call `show()` — it pumps the widget directly. The `show()` method lives inside the widget class but is called by pages; golden coverage is for the widget body only.
- **Widget depends on `mobile_scanner` plugin (`BarcodeScannerSheet`):** the plugin may fail to initialize in headless Flutter test. If the golden crashes, pump the widget inside a `try/catch` — `tester.takeException()` will absorb the plugin error, and the visible chrome (bottom sheet frame) still renders. Accept that golden for coverage.
- **`const` in widget tests:** `const SampleWidget(...)` is fine in the test if the widget has `const` constructor. Don't add/remove `const` in tests for aesthetic reasons — it can cause test-time invalid_constant errors.
- **Theme fonts and font metrics:** golden PNGs use `loadAppFonts()` from `flutter_test_config.dart` (bundled Plus Jakarta Sans). Don't rely on fallback fonts — tests must produce the real design font.
- **If a widget renders differently on first pump vs settled frame** (common for animated widgets like spinners): use `await tester.pump(const Duration(milliseconds: 100))` for one deterministic frame instead of `pumpAndSettle`. `pumpAndSettle` times out on infinite animations.
- **Chrome vs body:** for `AppBottomSheet`, the chrome (drag handle, rounded top corners) is defined in the widget itself — so pumping it directly DOES capture the chrome. What we're NOT testing is how it behaves when triggered by `showModalBottomSheet` (entry/exit animation, backdrop tap dismiss). Those are integration-level concerns deferred to Sprint 4.
- **Bulk sed regenerates `app_colors.dart` import?** No — our sed only INSERTS the `theme_extensions.dart` import if `app_colors.dart` is already imported. If both imports become orphan after migration (because the file no longer references `AppColors.anything`), the unused-import lint is info-level and safe to leave. For cleanliness, remove the `app_colors.dart` import when it becomes unused. Automated cleanup: `dart fix --apply lib/presentation/widgets/` (but verify diff before committing).
