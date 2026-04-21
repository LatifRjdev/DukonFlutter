# Sprint 4 — Cleanup & Polish Implementation Plan

## Sprint 4 Complete — 2026-04-21

- **flutter analyze: 0 issues** (was 44 info + 1 warning before Sprint 4)
- **flutter test: 332/332 passing** (328 existing + 4 new chrome tests)
- `AppColors.primaryDark` (1 ref) → `context.primary`; `AppColors.overlay` (1 ref) → `context.shadowColor`. `AppColors.overlay` removed from `app_colors.dart` (0 refs).
- `context.mounted` replaces `mounted` in `settings_page.dart` error handler
- `_SectionItem.stub` unused param removed from `finance_dashboard_page.dart`
- `AppButton` Row uses `Flexible` + ellipsis for narrow constraints; `receipt_preview` test renders at default 390×844 (no more `Size(412, 900)` override)
- `RadioListTile` migrated to `RadioGroup<T>` ancestor (Flutter 3.32+ API) — 2 files, 8 sites
- 4 × multi-underscore wildcards → single `_` (Dart 3.7+)
- 2 × Cyrillic string interp false-positives suppressed with `// ignore:`
- 2 new chrome smoke tests: `AppBottomSheet`, `AppDialog` — 4 `testWidgets` cases exercise real `showModalBottomSheet` / `showDialog` with Navigator
- Follow-up: Sprint 5 — design system expansion (elevations, motion, radii) + accessibility / WCAG AA audit

---

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Sprint 1–3 technical debt — remove last `AppColors.light/dark` external refs, zero out `flutter analyze`, fix `AppButton` overflow, migrate deprecated `RadioListTile` API, add 2 chrome smoke tests.

**Architecture:** 8 sequential cleanup tasks, one commit per task, low-risk first. Relies entirely on existing infrastructure: 23 `ThemeColors` tokens, `golden_toolkit`, `bloc_test`, `mocktail`.

**Tech Stack:** Flutter 3.10+ with `RadioGroup` support (post-3.32.0), `dart fix` CLI for auto-cleanup.

**Spec:** [docs/superpowers/specs/2026-04-20-ui-ux-sprint-4-cleanup-polish-design.md](../specs/2026-04-20-ui-ux-sprint-4-cleanup-polish-design.md)

---

## Pre-Task Audit Summary

From spec-time `flutter analyze`:

| Lint type | Count | Source |
|---|---|---|
| `use_null_aware_elements` | 22 | `lib/data/datasources/remote/*.dart` |
| `deprecated_member_use` | 11 | `lib/presentation/pages/settings/scanner_settings_page.dart` (4) + `lib/presentation/pages/zakat/zakat_settings_page.dart` (2) + misc (5) |
| `unnecessary_underscores` | 5 | test files |
| `unnecessary_brace_in_string_interps` | 4 | `lib/presentation/widgets/shifts/*.dart` |
| `use_build_context_synchronously` | 1 | `lib/presentation/pages/settings/settings_page.dart:203:56` |
| `unused_element_parameter` | 1 | `lib/presentation/pages/finance/finance_dashboard_page.dart:397` — `_SectionItem.stub` |
| `unnecessary_import` | 1 | TBD — reveal via `dart fix --dry-run` |
| **Total** | **45** | |

External `AppColors` refs to migrate:
- `AppColors.primaryDark` at `lib/presentation/widgets/pos/quick_product_chip.dart:55`
- `AppColors.overlay` at `lib/presentation/pages/shifts/z_report_page.dart:315`

---

## Task 1: `dart fix --apply` Auto-Cleanup

**Files:** auto-detected by `dart fix` — expected modifications in `lib/data/datasources/remote/*.dart`, test files, `lib/presentation/widgets/shifts/*.dart`, various import statements.

- [ ] **Step 1: Preview changes**

Run from `/Users/latifrjdev/Downloads/Dukon/app`:
```bash
dart fix --dry-run
```
Expected: table listing "X fixes will be applied across Y files" — should include `use_null_aware_elements`, `unnecessary_underscores`, `unnecessary_brace_in_string_interps`, `unnecessary_import`. Note which fixes ARE NOT auto-fixable (some `deprecated_member_use` may need manual work).

- [ ] **Step 2: Apply fixes**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
dart fix --apply
```

Expected: "X fixes made in Y files" summary. Exit code 0.

- [ ] **Step 3: Run analyze — note what's left**

```bash
flutter analyze 2>&1 | grep -E "error|warning|info" | wc -l
flutter analyze 2>&1 | grep -oE "• [a-z_]+ *$" | sort | uniq -c | sort -rn
```

Expected: reduced from 45 down to ~11–14 remaining (mostly `deprecated_member_use`, `use_build_context_synchronously`, `unused_element_parameter`, possibly others that `dart fix` can't auto-handle).

- [ ] **Step 4: Run tests**

```bash
flutter test 2>&1 | tail -3
```

Expected: "All tests passed!" at 328. `dart fix` should only change syntax, not behavior.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib app/test
git commit -m "$(cat <<'EOF'
chore(lint): apply dart fix auto-cleanup

Removes 22 use_null_aware_elements in data layer remote datasources,
5 unnecessary_underscores in tests, 4 unnecessary_brace_in_string_interps
in shifts widgets, and 1 unnecessary_import. All 328 tests still pass.
EOF
)"
```

---

## Task 2: `use_build_context_synchronously` Manual Fix

**Files:**
- Modify: `app/lib/presentation/pages/settings/settings_page.dart:203`

Location and current code (around line 195–210):
```dart
try {
  await sl<DioClient>().put(
    '/stores/${_getStoreId()}/notification-settings',
    data: {'enabled': v},
  );
} catch (e) {
  if (mounted) {
    setState(() => _notificationsEnabled = !v);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось сохранить настройку')),
    );
  }
}
```

Flutter warns because `mounted` is a `State` field, which doesn't tie to the `context` being used. The fix is to use `context.mounted` (introduced in Flutter 3.7+) which ties the check directly to the BuildContext.

- [ ] **Step 1: Apply fix**

Edit `app/lib/presentation/pages/settings/settings_page.dart` — replace `if (mounted) {` on line ~201 with `if (!context.mounted) return;` earlier, and remove the wrapping `if`. Or more surgically: change `if (mounted)` to `if (context.mounted)`.

```dart
// BEFORE
} catch (e) {
  if (mounted) {
    setState(() => _notificationsEnabled = !v);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось сохранить настройку')),
    );
  }
}

// AFTER
} catch (e) {
  if (!context.mounted) return;
  setState(() => _notificationsEnabled = !v);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Не удалось сохранить настройку')),
  );
}
```

- [ ] **Step 2: Verify analyze is clean for this file**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/settings/settings_page.dart
```

Expected: "No issues found!" (for this file).

- [ ] **Step 3: Run tests**

```bash
flutter test test/presentation/pages/settings/settings_page_golden_test.dart
```

Expected: 2/2 pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/settings/settings_page.dart
git commit -m "$(cat <<'EOF'
fix(lint): guard async context use with context.mounted

Replaces State.mounted check with context.mounted in settings_page
error handler — ties the mounted check directly to the BuildContext
being used for ScaffoldMessenger, silencing the
use_build_context_synchronously info lint.
EOF
)"
```

---

## Task 3: Migrate Last `AppColors` External Refs

**Files:**
- Modify: `app/lib/presentation/widgets/pos/quick_product_chip.dart:55`
- Modify: `app/lib/presentation/pages/shifts/z_report_page.dart:315`
- Possibly Modify: `app/lib/core/constants/app_colors.dart` (if dead constants fully unused)

### Step 1: Migrate `quick_product_chip.dart:55`

Current code around line 55:
```dart
style: const TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: AppColors.primaryDark,
  fontFamily: 'Inter',
  ...
),
```

- [ ] **Edit `quick_product_chip.dart:55`** — change `AppColors.primaryDark` to `context.primary` and drop `const` from the `TextStyle`:

```dart
style: TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: context.primary,
  fontFamily: 'Inter',
  ...
),
```

Verify `import '../../../core/theme/theme_extensions.dart';` exists at top of the file; add if missing.

### Step 2: Migrate `z_report_page.dart:315`

Current code around line 310–318:
```dart
padding: const EdgeInsets.all(AppConstants.spacingMd),
decoration: BoxDecoration(
  color: context.surface,
  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
  boxShadow: const [
    BoxShadow(color: AppColors.overlay, blurRadius: 4, offset: Offset(0, 2)),
  ],
),
```

- [ ] **Edit `z_report_page.dart:315`** — change `AppColors.overlay` to `context.shadowColor` and drop `const` from the outer `[...]`:

```dart
boxShadow: [
  BoxShadow(color: context.shadowColor, blurRadius: 4, offset: const Offset(0, 2)),
],
```

Verify `theme_extensions.dart` import exists; add if missing.

### Step 3: Verify + regen goldens

- [ ] Run:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/widgets/pos/quick_product_chip.dart lib/presentation/pages/shifts/z_report_page.dart
```
Expected: clean.

- [ ] Regen affected goldens:
```bash
flutter test --update-goldens \
  test/presentation/widgets/pos/quick_product_chip_golden_test.dart \
  test/presentation/pages/shifts/z_report_page_golden_test.dart
```

- [ ] Re-run without --update-goldens:
```bash
flutter test \
  test/presentation/widgets/pos/quick_product_chip_golden_test.dart \
  test/presentation/pages/shifts/z_report_page_golden_test.dart
```
Expected: tests pass.

### Step 4: Audit dead `AppColors` constants

- [ ] Run:
```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rn "AppColors\.primaryDark\|AppColors\.overlay" app/lib/
```

If ANY line inside `app/lib/core/theme/` or `app/lib/core/constants/` references these constants, KEEP them in `app_colors.dart` (they back the theme tokens).

If 0 lines reference them across the entire `app/lib/`, remove the constants from `app_colors.dart`:

```dart
// Delete these lines from app/lib/core/constants/app_colors.dart:
//   static const Color primaryDark = Color(0xFF818CF8);
//   static const Color overlay = Color(0x80000000);
```

Re-run `flutter analyze` — should still be clean.

### Step 5: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/widgets/pos/quick_product_chip.dart \
        app/lib/presentation/pages/shifts/z_report_page.dart \
        app/test/presentation/widgets/pos/goldens/ \
        app/test/presentation/pages/shifts/goldens/
# if app_colors.dart was modified:
git add app/lib/core/constants/app_colors.dart
git commit -m "$(cat <<'EOF'
refactor(theme): migrate last AppColors external refs

quick_product_chip.dart:55: AppColors.primaryDark → context.primary
z_report_page.dart:315: AppColors.overlay → context.shadowColor

After migration, 0 external refs remain to these constants; they are
removed from app_colors.dart if fully unused, or kept as backing
values for ThemeColors tokens.
EOF
)"
```

---

## Task 4: `_SectionItem.stub` Decision

**Files:**
- Modify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart:390–400`

Current code at lines 390–400:
```dart
class _SectionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  /// True when the tile is a placeholder — used by _buildSectionsGrid to
  /// render the icon/label in a dimmed style.
  final bool stub;
  _SectionItem(this.label, this.icon, this.onTap, {this.stub = false});
}
```

- [ ] **Step 1: Check for stub usage**

```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -n "stub:" app/lib/presentation/pages/finance/finance_dashboard_page.dart
grep -n "\.stub" app/lib/presentation/pages/finance/finance_dashboard_page.dart
```

Expected: zero call sites use `stub: true` or read `.stub`. If 0 hits → remove the parameter (Step 2a). If hits exist but `_buildSectionsGrid` ignores them → implement the dimming (Step 2b).

- [ ] **Step 2a (DEFAULT if no callers): Remove the parameter**

Edit `finance_dashboard_page.dart` — replace the `_SectionItem` class:

```dart
// BEFORE
class _SectionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  /// True when the tile is a placeholder — used by _buildSectionsGrid to
  /// render the icon/label in a dimmed style.
  final bool stub;
  _SectionItem(this.label, this.icon, this.onTap, {this.stub = false});
}

// AFTER
class _SectionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _SectionItem(this.label, this.icon, this.onTap);
}
```

Verify no callers passed `stub:` explicitly — if any did, fix those call sites.

- [ ] **Step 2b (ALTERNATIVE if callers exist and dimming is wanted): Wire stub rendering**

Find `_buildSectionsGrid` (or the widget that renders `_SectionItem`). Add conditional opacity:

```dart
// In the _SectionItem tile widget's build:
return Opacity(
  opacity: item.stub ? 0.4 : 1.0,
  child: <existing tile widget>,
);
```

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/finance/finance_dashboard_page.dart
```

Expected: "No issues found!" (the `unused_element_parameter` warning is gone).

- [ ] **Step 4: Regen affected goldens (only if visual changed)**

Only run if Step 2b was used (dimming). Otherwise skip — removing an unused parameter doesn't change rendering.

```bash
flutter test --update-goldens test/presentation/pages/finance/finance_dashboard_page_golden_test.dart
flutter test test/presentation/pages/finance/finance_dashboard_page_golden_test.dart
```

- [ ] **Step 5: Commit**

If Step 2a was used:
```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/finance/finance_dashboard_page.dart
git commit -m "refactor(finance): remove unused _SectionItem.stub param

No callers set stub: true and no consumer reads .stub. Remove the
dead parameter to satisfy the unused_element_parameter lint."
```

If Step 2b was used:
```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/finance/finance_dashboard_page.dart \
        app/test/presentation/pages/finance/goldens/
git commit -m "feat(finance): render stub section tiles dimmed

Wires _SectionItem.stub to an Opacity(0.4) wrapper in
_buildSectionsGrid. Resolves the unused_element_parameter lint."
```

---

## Task 5: AppButton Overflow Fix + Receipt Preview Test Cleanup

**Files:**
- Modify: `app/lib/presentation/widgets/common/app_button.dart:106`
- Modify: `app/test/presentation/pages/pos/receipt_preview_page_golden_test.dart`

### Step 1: Fix AppButton Row overflow

Current code at lines 105–115:
```dart
if (icon != null) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}
```

- [ ] **Edit `app_button.dart:106`** — wrap `Text` in `Flexible` with ellipsis:

```dart
if (icon != null) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
```

Verify analyze:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/widgets/common/app_button.dart
```
Expected: clean.

### Step 2: Remove receipt_preview workarounds

- [ ] Open `app/test/presentation/pages/pos/receipt_preview_page_golden_test.dart`. Find both `testGoldens` blocks (light + dark). In EACH, remove:
  - `size: const Size(412, 900),` — delete this line
  - `tester.takeException();` — delete this line (only if it was absorbing overflow; if it catches other errors, keep)

Example diff per test:
```dart
// BEFORE
await pumpPageWithTheme(
  tester,
  page(),
  brightness: Brightness.light,
  wrap: wrapWithBlocs,
  size: const Size(412, 900),
);
tester.takeException();
await screenMatchesGolden(tester, 'receipt_preview_light');

// AFTER
await pumpPageWithTheme(
  tester,
  page(),
  brightness: Brightness.light,
  wrap: wrapWithBlocs,
);
await screenMatchesGolden(tester, 'receipt_preview_light');
```

### Step 3: Regen receipt_preview goldens at default 390×844

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens test/presentation/pages/pos/receipt_preview_page_golden_test.dart
```

- [ ] Visually inspect the 2 regenerated PNGs (`receipt_preview_light.png`, `receipt_preview_dark.png`). Confirm:
  - The action buttons at the bottom render WITHOUT yellow/black overflow stripes
  - Text truncates with ellipsis if needed (should not happen at 390 width if buttons are compact)
  - Dark mode still has `#0F0A1A` bg

### Step 4: Re-run

```bash
flutter test test/presentation/pages/pos/receipt_preview_page_golden_test.dart
```
Expected: 2/2 pass.

### Step 5: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/widgets/common/app_button.dart \
        app/test/presentation/pages/pos/receipt_preview_page_golden_test.dart \
        app/test/presentation/pages/pos/goldens/receipt_preview_light.png \
        app/test/presentation/pages/pos/goldens/receipt_preview_dark.png
git commit -m "$(cat <<'EOF'
fix(widgets): AppButton Row fits narrow constraints with Flexible text

Wraps Text in Flexible(overflow: ellipsis) so the icon+text Row
cannot overflow its parent when constrained to ~125 px. Also
removes the Size(412, 900) and tester.takeException() workarounds
from receipt_preview_page_golden_test — the page now renders
cleanly at default 390×844.
EOF
)"
```

---

## Task 6: RadioListTile → RadioGroup Migration

**Files:**
- Modify: `app/lib/presentation/pages/settings/scanner_settings_page.dart` (around lines 110–145)
- Modify: `app/lib/presentation/pages/zakat/zakat_settings_page.dart` (around line 143)

### Step 1: Migrate `scanner_settings_page.dart`

- [ ] Read the file:
```bash
sed -n '100,150p' /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/settings/scanner_settings_page.dart
```

The typical structure:
```dart
// BEFORE (old API, deprecated)
Column(
  children: [
    RadioListTile<String>(
      value: 'camera',
      groupValue: _selected,
      onChanged: (v) => setState(() => _selected = v!),
      title: const Text('Камера'),
    ),
    RadioListTile<String>(
      value: 'external',
      groupValue: _selected,
      onChanged: (v) => setState(() => _selected = v!),
      title: const Text('Внешний сканер'),
    ),
  ],
)
```

Migrate to `RadioGroup` ancestor:
```dart
// AFTER (new API)
RadioGroup<String>(
  groupValue: _selected,
  onChanged: (v) => setState(() => _selected = v!),
  child: const Column(
    children: [
      RadioListTile<String>(
        value: 'camera',
        title: Text('Камера'),
      ),
      RadioListTile<String>(
        value: 'external',
        title: Text('Внешний сканер'),
      ),
    ],
  ),
)
```

Note: once `RadioListTile` no longer receives `groupValue`/`onChanged`, it can become `const`.

- [ ] Verify:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/settings/scanner_settings_page.dart
```
Expected: clean, no `deprecated_member_use` on lines 116/117/137/138.

### Step 2: Migrate `zakat_settings_page.dart`

- [ ] Read file around line 143:
```bash
sed -n '130,170p' /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/pages/zakat/zakat_settings_page.dart
```

Apply the same transformation — wrap the group in `RadioGroup<T>`, remove `groupValue`/`onChanged` from each `RadioListTile`.

- [ ] Verify:
```bash
flutter analyze lib/presentation/pages/zakat/zakat_settings_page.dart
```
Expected: clean.

### Step 3: Regen affected goldens

The radio tiles may render slightly differently (no internal `onChanged` state), which can cause a 1-pixel shift.

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens \
  test/presentation/pages/settings/scanner_settings_page_golden_test.dart \
  test/presentation/pages/zakat/zakat_settings_page_golden_test.dart
```

- [ ] Visually inspect the 4 regenerated PNGs. Confirm:
  - Radio buttons still visually grouped
  - Selection indicator visible
  - No overflow or layout shifts

### Step 4: Re-run

```bash
flutter test \
  test/presentation/pages/settings/scanner_settings_page_golden_test.dart \
  test/presentation/pages/zakat/zakat_settings_page_golden_test.dart
```
Expected: 4/4 pass.

### Step 5: Check for other deprecated_member_use

```bash
flutter analyze 2>&1 | grep deprecated_member_use
```

Expected: 0 or a few unrelated deprecations. If any REMAIN, inspect each — fix if trivial, leave and note in the commit message if blocking on external package updates.

### Step 6: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/settings/scanner_settings_page.dart \
        app/lib/presentation/pages/zakat/zakat_settings_page.dart \
        app/test/presentation/pages/settings/goldens/ \
        app/test/presentation/pages/zakat/goldens/
git commit -m "$(cat <<'EOF'
refactor: migrate RadioListTile to RadioGroup ancestor pattern

Flutter 3.32+ deprecated RadioListTile.groupValue / .onChanged in
favor of a RadioGroup<T> ancestor that manages state for all child
RadioListTile widgets. Migration:
- scanner_settings_page.dart: 4 deprecated sites
- zakat_settings_page.dart: 2 deprecated sites

Goldens regenerated — no visual regression.
EOF
)"
```

---

## Task 7: Integration Smoke Tests for Chrome

**Files:**
- Create: `app/test/presentation/widgets/common/app_bottom_sheet_chrome_test.dart`
- Create: `app/test/presentation/widgets/common/app_dialog_chrome_test.dart`

### Step 1: Read real `AppBottomSheet` + `AppDialog` constructors

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -A 20 "^class AppBottomSheet" lib/presentation/widgets/common/app_bottom_sheet.dart
grep -A 30 "^class AppDialog" lib/presentation/widgets/common/app_dialog.dart
```

Note the required parameters (may differ from the spec's template). Typical minimal call:
- `AppBottomSheet(title:, child:)` or `AppBottomSheet(child:)`
- `AppDialog(title:, message:, confirmLabel:, cancelLabel:, onConfirm:, onCancel:)` or similar

Adapt the test code in Steps 2–3 accordingly.

### Step 2: Create `app_bottom_sheet_chrome_test.dart`

```dart
// app/test/presentation/widgets/common/app_bottom_sheet_chrome_test.dart
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

      // Tap near the top — that's the scrim/backdrop region
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(find.text('Sheet body'), findsNothing);
    });
  });
}
```

If `AppBottomSheet` doesn't accept `title` or `child` named parameters, adapt the constructor call. If it requires additional required parameters, provide them with minimal values (empty list, no-op callbacks, etc.).

- [ ] Run:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test test/presentation/widgets/common/app_bottom_sheet_chrome_test.dart
```
Expected: 2/2 pass.

If `pumpAndSettle` hangs (animation issue):
- Replace with `await tester.pump(const Duration(milliseconds: 300))` for the first `pumpAndSettle` after `tap`
- If that still fails, use `tester.ensureVisible(find.text('Sheet body'))` as the assertion instead

### Step 3: Create `app_dialog_chrome_test.dart`

```dart
// app/test/presentation/widgets/common/app_dialog_chrome_test.dart
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

    testWidgets('confirm callback fires and dismisses', (tester) async {
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

Adapt constructor args to real `AppDialog` API (if `onConfirm`/`onCancel` are named differently, e.g., `onPrimary`/`onSecondary`, update accordingly).

- [ ] Run:
```bash
flutter test test/presentation/widgets/common/app_dialog_chrome_test.dart
```
Expected: 2/2 pass.

### Step 4: Verify analyze

```bash
flutter analyze test/presentation/widgets/common/app_bottom_sheet_chrome_test.dart \
                 test/presentation/widgets/common/app_dialog_chrome_test.dart
```
Expected: clean.

### Step 5: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/test/presentation/widgets/common/app_bottom_sheet_chrome_test.dart \
        app/test/presentation/widgets/common/app_dialog_chrome_test.dart
git commit -m "$(cat <<'EOF'
test(widgets): add chrome smoke tests for AppBottomSheet and AppDialog

Exercises real showModalBottomSheet and showDialog calls with a
Navigator. Verifies sheet opens, shows title/body, dismisses on
backdrop tap. Dialog verifies confirm callback fires and dialog
closes. Closes the last Sprint 3 coverage gap for chrome behavior.

4 new testWidgets cases, no goldens.
EOF
)"
```

---

## Task 8: Final Acceptance + Wrap-Up

**Files:**
- Modify: `docs/superpowers/plans/2026-04-20-ui-ux-sprint-4-cleanup-polish.md` (prepend completion note)

- [ ] **Step 1: Sprint-level analyze**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze
```
Expected: **"No issues found!"**

If ANY issues remain:
- Identify the type (error/warning/info)
- Fix if trivial (1–2 min)
- If blocking on external package updates → leave, document in final commit message

- [ ] **Step 2: Sprint-level test**

```bash
flutter test
```
Expected: all tests pass (~332 = 328 existing + 4 new chrome tests).

If any flaky tests — run `flutter test --update-goldens` once more from the full-suite context (Sprint 3 precedent for resolving order-dependent pixel diffs).

- [ ] **Step 3: Combined presentation grep**

```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rE "AppColors\.(light|dark)" app/lib/ \
  | grep -v "core/theme\|core/constants/app_colors.dart\|core/constants/app_gradients.dart"
```
Expected: 0 matches.

- [ ] **Step 4: Update plan with completion note**

Prepend to the plan file (right after the header block), matching the Sprint 2 and 3 style:

```markdown
## Sprint 4 Complete — 2026-04-20

- All 44 info lints + 1 warning → 0. `flutter analyze` reports "No issues found!"
- 2 external `AppColors` refs migrated (quick_product_chip → `context.primary`; z_report_page → `context.shadowColor`). Dead constants cleaned if unused.
- `AppButton` Row no longer overflows narrow constraints; `receipt_preview` test renders at default 390×844.
- `RadioListTile` migrated to `RadioGroup` ancestor (Flutter 3.32+ API).
- `_SectionItem.stub` unused parameter resolved.
- 2 chrome integration smoke tests added for `AppBottomSheet` and `AppDialog` — 4 new testWidgets cases.
- Total tests: 332 passing.
- Next: Sprint 5 — design system expansion (elevations, motion, radii) + accessibility / WCAG AA audit.
```

- [ ] **Step 5: Final commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/plans/2026-04-20-ui-ux-sprint-4-cleanup-polish.md
git commit -m "$(cat <<'EOF'
docs(sprint-4): mark cleanup complete

flutter analyze: 0 issues. flutter test: 332 passing. 0 external
AppColors.light/dark refs. RadioGroup migration, AppButton overflow
fix, chrome smoke tests — all shipped.

Next: Sprint 5 — design system expansion + accessibility audit.
EOF
)"
```

---

## Execution Notes

- **`dart fix` edge case:** if the auto-fix modifies a file in a way that breaks existing tests (rare), revert that specific file and apply the fix manually. `dart fix` is conservative but not bulletproof.
- **`RadioGroup` availability:** requires Flutter SDK >= 3.32.0. Check with `flutter --version` before Task 6; if SDK is older, migrate to `RadioGroup` would fail. Fallback: pin `// ignore: deprecated_member_use` on each site with a TODO — but this only lands if SDK upgrade is blocked by product.
- **`AppButton` callers:** the `Flexible` fix is a pure visual improvement — it doesn't change the public API. However, any golden test capturing the button at narrower-than-expected widths may show slight text-width differences. Run full `flutter test` after Task 5 to catch any unexpected pixel shifts; regen if needed.
- **Chrome tests vs animation timing:** `showModalBottomSheet`/`showDialog` use a ~250ms entry animation. `pumpAndSettle` handles this correctly in most cases. If a specific test hangs on a spinner or repeating animation inside the sheet/dialog body, use `tester.pump(Duration(milliseconds: 300))` for a single deterministic frame.
- **Sprint 3 failures/ artifact cleanup:** before commits, ensure no `app/test/presentation/**/failures/` directories exist (leftover from a failed golden comparison). `rm -rf app/test/presentation/**/failures/` before each commit if paranoid.
- **Sprint 2/3 precedent for full-suite pixel diffs:** if final `flutter test` in Task 8 fails with 0.01% pixel diffs on 2–4 goldens, regen from full-suite context: `flutter test --update-goldens` then re-run. Covered in Sprint 3 wrap-up.
