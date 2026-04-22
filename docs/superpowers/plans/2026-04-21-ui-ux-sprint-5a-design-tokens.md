# Sprint 5A — Design Tokens Expansion Implementation Plan

## Sprint 5A Complete — 2026-04-21

- **Design tokens expanded:** `AppConstants` gains `radiusXs=4`, `radiusXl=20` (new value), `radiusXxl=24` (renamed from old `radiusXl`), `motionFast=150ms`, `motionMedium=250ms`, `motionSlow=400ms`. `ThemeColors` gains `elevationSm/Md/Lg` (theme-aware via `shadowColor`).
- **234 hardcoded sites migrated** to tokens: 93 `BorderRadius.circular` + 9 `BoxShadow` + 1 `Duration` (200ms) + 91 `cardRadius` + 50 `buttonRadius`. `cardRadius` and `buttonRadius` constants removed. 1 `Duration(600ms)` kept as literal (intentional elastic reveal).
- **Acceptance:** `flutter analyze` 0 issues; `flutter test` 335/335 pass (332 + 3 new elevation tests). `grep BoxShadow` returns 0 in `lib/presentation/`; `grep BorderRadius.circular([0-9])` returns 9 (only 1px and 2px literals); `grep cardRadius/buttonRadius` returns 0.
- **2 sticky footer shadows** mapped to `elevationMd` — downward cast (was upward). Minor visual regression on product_list and import_products sticky bottom bars, revisit if product feedback requests.
- Commits: Task 1 (`1669d35`), Task 2 (`1c595f0`), Task 3 (`0e9e3bc`), Task 4 (`f278677`).
- Follow-up: Sprint 5B — WCAG AA accessibility audit (contrast, touch targets, semantic labels).

---

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand design token palette — add radii (xs/xl/xxl), motion (fast/medium/slow), elevations (sm/md/lg) — and migrate 241 hardcoded call sites (93 `BorderRadius.circular` + 9 `BoxShadow` + 2 `Duration` + 91 `cardRadius` + 50 `buttonRadius`) to the new scale.

**Architecture:** 5 phases executed sequentially, low-risk first. Phase 1 extends `AppConstants` + `ThemeColors` with new tokens. Phases 2–4 migrate call sites via bulk sed + targeted manual review for `BoxShadow` (9 manual). Phase 5 removes deprecated `cardRadius`/`buttonRadius` constants and validates sprint acceptance. One commit per phase.

**Tech Stack:** Flutter, existing `AppConstants` scale pattern, existing `ThemeColors` extension, existing `shadowColor` token from Sprint 2.5.

**Spec:** [docs/superpowers/specs/2026-04-21-ui-ux-sprint-5a-design-tokens-design.md](../specs/2026-04-21-ui-ux-sprint-5a-design-tokens-design.md)

---

## Pre-Task Audit (verified 2026-04-21)

| Hardcode | Count | Target token | Rounding |
|---|---|---|---|
| `BorderRadius.circular(1)` | 1 | keep literal | too thin for scale |
| `BorderRadius.circular(2)` | 8 | keep literal | too thin for scale |
| `BorderRadius.circular(4)` | 5 | `radiusXs` (4) | 0 |
| `BorderRadius.circular(6)` | 6 | `radiusSm` (8) | +2 |
| `BorderRadius.circular(8)` | 13 | `radiusSm` (8) | 0 |
| `BorderRadius.circular(10)` | 27 | `radiusMd` (12) | +2 |
| `BorderRadius.circular(12)` | 16 | `radiusMd` (12) | 0 |
| `BorderRadius.circular(16)` | 7 | `radiusLg` (16) | 0 |
| `BorderRadius.circular(18)` | 1 | `radiusXl` (20) | +2 |
| `BorderRadius.circular(20)` | 9 | `radiusXl` (20) | 0 |
| **BorderRadius total** | **93** | | |
| `BoxShadow(...)` (manual review) | 9 | `context.elevationSm/Md/Lg` | heuristic mapping |
| `Duration(milliseconds: 200)` | 1 | `AppConstants.motionMedium` | +50ms |
| `Duration(milliseconds: 600)` | 1 | keep literal (intentionally slow) or `motionSlow` | — |
| `AppConstants.radiusXl` existing refs | 5 | rename to `radiusXxl` | 0 |
| `AppConstants.cardRadius` | 91 | `AppConstants.radiusLg` | 0 (16 = 16) |
| `AppConstants.buttonRadius` | 50 | `AppConstants.radiusLg` | +2 (14 → 16) |

**Total migration sites:** 241 (across 5 categories). 141 are constant renames with 0 visual shift; 50 are `buttonRadius` → `radiusLg` with +2 px; 40 are `BorderRadius.circular` literals with +2 px.

---

## Task 1: Phase 1 — Add tokens + rename `radiusXl`

**Files:**
- Modify: `app/lib/core/constants/app_constants.dart`
- Modify: `app/lib/core/theme/theme_extensions.dart`
- Modify: `app/test/core/theme/theme_extensions_test.dart`
- Modify (via sed): any file referencing `AppConstants.radiusXl` (5 files)

### Step 1: Rename existing `AppConstants.radiusXl` → `radiusXxl` in all call sites

Order matters — rename BEFORE redefining the constant.

```bash
cd /Users/latifrjdev/Downloads/Dukon
# Find all refs first to confirm count
grep -rn "AppConstants\.radiusXl\b" app/lib/ | wc -l
# Expected: 5

# Apply sed
find app/lib -name "*.dart" -exec sed -i '' 's/AppConstants\.radiusXl\b/AppConstants.radiusXxl/g' {} \;

# Verify 0 refs to old name remain
grep -rn "AppConstants\.radiusXl\b" app/lib/
# Expected: no output (0 refs)

# Verify 5 refs now use new name
grep -rn "AppConstants\.radiusXxl\b" app/lib/ | wc -l
# Expected: 5
```

- [ ] **Step 1 complete**

### Step 2: Update `app_constants.dart` constant declarations

Edit `app/lib/core/constants/app_constants.dart`. Find the existing radii block:

```dart
// BEFORE (existing)
static const double radiusSm = 8.0;
static const double radiusMd = 12.0;
static const double radiusLg = 16.0;
static const double radiusXl = 24.0;
static const double radiusRound = 100.0;
// ... and elsewhere in the file:
static const double buttonRadius = 14.0;
static const double cardRadius = 16.0;
```

Replace with:

```dart
// AFTER
// Border radii — 4-based scale
static const double radiusXs = 4.0;          // NEW
static const double radiusSm = 8.0;          // existing
static const double radiusMd = 12.0;         // existing
static const double radiusLg = 16.0;         // existing
static const double radiusXl = 20.0;         // NEW VALUE (was 24, renamed to radiusXxl)
static const double radiusXxl = 24.0;        // NEW (takes old radiusXl value)
static const double radiusRound = 100.0;     // existing
// Do NOT delete buttonRadius/cardRadius here — Phase 4 handles them

// Motion durations
static const Duration motionFast = Duration(milliseconds: 150);
static const Duration motionMedium = Duration(milliseconds: 250);
static const Duration motionSlow = Duration(milliseconds: 400);
```

Keep `buttonRadius = 14.0` and `cardRadius = 16.0` temporarily — they're removed in Phase 4 after migration.

- [ ] **Step 2 complete**

### Step 3: Add elevation getters to `ThemeColors`

Edit `app/lib/core/theme/theme_extensions.dart`. Append at the end of the `ThemeColors` extension (after `infoBg` getter):

```dart
  /// Small elevation — list items, low-prominence cards.
  List<BoxShadow> get elevationSm => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Medium elevation — floating cards, sticky bars.
  List<BoxShadow> get elevationMd => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Large elevation — modals, popovers, FABs.
  List<BoxShadow> get elevationLg => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
```

`shadowColor` is already in `ThemeColors` (from Sprint 2.5). No new imports needed — `BoxShadow`, `Offset` come from `package:flutter/material.dart` which is already imported.

- [ ] **Step 3 complete**

### Step 4: Add elevation tests

Edit `app/test/core/theme/theme_extensions_test.dart`. Find the existing test file — it has `_pumpLight` / `_pumpDark` test helpers. Append 3 new test cases after the last existing test:

```dart
  testWidgets('elevationSm returns single shadow with blur 4 and offset (0,2)', (tester) async {
    List<BoxShadow>? val;
    await _pumpLight(tester, (ctx) => val = ctx.elevationSm);
    expect(val, isNotNull);
    expect(val!.length, 1);
    expect(val!.first.blurRadius, 4);
    expect(val!.first.offset, const Offset(0, 2));
  });

  testWidgets('elevationMd returns single shadow with blur 8 and offset (0,4)', (tester) async {
    List<BoxShadow>? val;
    await _pumpLight(tester, (ctx) => val = ctx.elevationMd);
    expect(val, isNotNull);
    expect(val!.length, 1);
    expect(val!.first.blurRadius, 8);
    expect(val!.first.offset, const Offset(0, 4));
  });

  testWidgets('elevationLg returns single shadow with blur 16 and offset (0,8)', (tester) async {
    List<BoxShadow>? val;
    await _pumpLight(tester, (ctx) => val = ctx.elevationLg);
    expect(val, isNotNull);
    expect(val!.length, 1);
    expect(val!.first.blurRadius, 16);
    expect(val!.first.offset, const Offset(0, 8));
  });
```

- [ ] **Step 4 complete**

### Step 5: Verify analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze
```
Expected: "No issues found!"

If errors appear (most likely: some file tries to use old `AppConstants.radiusXl = 24` and gets 20 instead) — investigate. The rename in Step 1 should have caught all 5 existing refs.

- [ ] **Step 5 complete**

### Step 6: Run tests

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test
```
Expected: 335 tests pass (332 existing + 3 new elevation tests).

If any golden test fails with pixel diffs — it's because the old `radiusXl = 24` now resolves to 20 in 5 renamed call sites. They should have been renamed to `radiusXxl` to preserve 24. Re-verify Step 1.

- [ ] **Step 6 complete**

### Step 7: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/core/constants/app_constants.dart \
        app/lib/core/theme/theme_extensions.dart \
        app/test/core/theme/theme_extensions_test.dart \
        app/lib/  # for the sed'd radiusXl→radiusXxl renames
git commit -m "$(cat <<'EOF'
feat(theme): add radii xs/xl/xxl, motion, and elevation tokens

Extends AppConstants with 4-based radii scale (radiusXs=4,
radiusXl=20 new value, radiusXxl=24 renamed from old radiusXl) and
motion durations (motionFast=150, motionMedium=250, motionSlow=400).
Adds elevation getters to ThemeColors (elevationSm/Md/Lg) returning
List<BoxShadow> using existing shadowColor — theme-aware out of the
box.

5 existing refs to AppConstants.radiusXl renamed to radiusXxl to
preserve the 24px value. 3 new tests for elevation getters. Kept
cardRadius/buttonRadius temporarily — removed in Phase 4.

Part of Sprint 5A Phase 1 — token scaffolding.
EOF
)"
```

- [ ] **Step 7 complete**

---

## Task 2: Phase 2 — Migrate 9 `BoxShadow` sites

**Files:**
- Modify (manual per-site review): 8 files containing `BoxShadow(` across `app/lib/presentation/`

### Step 1: List all `BoxShadow` sites

```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rn "BoxShadow(" app/lib/presentation/
```

Expected output: 9 lines with file:line references. Typical examples:
- `app/lib/presentation/pages/pos/receipt_preview_page.dart:...`
- `app/lib/presentation/widgets/...`
- etc.

Expected: 9 sites across ~8 files.

### Step 2: Classify each site

For each site, open the file and read the `BoxShadow(color:, blurRadius:, offset:)` parameters. Apply heuristic mapping:

| blur | offset.dy | → token |
|---|---|---|
| ≤ 5 | ≤ 3 | `elevationSm` |
| 6–12 | 4–6 | `elevationMd` |
| ≥ 13 | ≥ 7 | `elevationLg` |

Ambiguous cases (e.g., blur 5 + offset 5, or multi-layer `[BoxShadow(...), BoxShadow(...)]`): default to `elevationMd` and note in commit.

### Step 3: Per-site migration

For each file:

1. Read the site with 5 lines of context: `grep -n -B 5 -A 3 "BoxShadow(" app/lib/presentation/<folder>/<file>.dart`
2. Identify the enclosing `BoxDecoration(...)` or `decoration: BoxDecoration(...)` wrapper.
3. Replace the `boxShadow:` value:

```dart
// BEFORE (generic example)
decoration: BoxDecoration(
  color: context.surface,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ],
),

// AFTER
decoration: BoxDecoration(
  color: context.surface,
  borderRadius: BorderRadius.circular(16),
  boxShadow: context.elevationSm,
),
```

For multi-layer shadow (rare):
```dart
// BEFORE
boxShadow: [
  BoxShadow(color: ..., blurRadius: 4, offset: Offset(0, 2)),
  BoxShadow(color: ..., blurRadius: 8, offset: Offset(0, 4)),
],
// AFTER — collapse to single token matching the dominant (taller) shadow
boxShadow: context.elevationMd,
```

Verify `theme_extensions.dart` import exists in the file; add if missing (3 `../` for `pages/<folder>/`, also 3 for `widgets/<folder>/`).

### Step 4: Verify grep = 0

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -rE "BoxShadow\(" lib/presentation/ | wc -l
```
Expected: `0`

### Step 5: Flutter analyze

```bash
flutter analyze lib/presentation/
```
Expected: "No issues found!"

### Step 6: Regen affected goldens

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens
```

Most pages containing migrated shadow sites will have slightly different rendering (blur/offset may differ from originals). Spot-check 3–5 dark PNGs to confirm shadows look clean (soft, not harsh black).

### Step 7: Run tests without --update-goldens

```bash
flutter test
```
Expected: all tests pass.

If Sprint 3 pattern of 0.01% pixel drift occurs (~4 shift_card tests): re-run `flutter test --update-goldens` once more, commit updated goldens.

### Step 8: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/ app/test/presentation/
git commit -m "$(cat <<'EOF'
refactor(theme): migrate 9 BoxShadow sites to context.elevationX

All 9 hardcoded BoxShadow instances in lib/presentation/ now use
context.elevationSm / Md / Lg from ThemeColors — shadows adapt to
dark mode via context.shadowColor backing. Ambiguous blur/offset
cases default to elevationMd.

grep BoxShadow in lib/presentation/ = 0.
Part of Sprint 5A Phase 2.
EOF
)"
```

- [ ] **Step 8 complete**

---

## Task 3: Phase 3 — Migrate 2 `Duration` sites

**Files:**
- Modify: 2 files containing `Duration(milliseconds: 200)` or `Duration(milliseconds: 600)` in `app/lib/presentation/`

### Step 1: List Duration sites

```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rn "Duration(milliseconds:" app/lib/presentation/
```
Expected: 2 lines.

### Step 2: Migrate `200ms` → `motionMedium`

Sed across presentation:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation
find . -name "*.dart" -exec sed -i '' \
  's/const Duration(milliseconds: 200)/AppConstants.motionMedium/g' {} \;
# Also handle non-const form if present:
find . -name "*.dart" -exec sed -i '' \
  's/Duration(milliseconds: 200)/AppConstants.motionMedium/g' {} \;
```

Verify the affected file imports `AppConstants`:
```bash
cd /Users/latifrjdev/Downloads/Dukon
grep -rln "AppConstants\.motionMedium" app/lib/presentation/
# For each file: verify `import '../../../core/constants/app_constants.dart';` is present.
```

If a file uses `AppConstants.motionMedium` but doesn't import `AppConstants` — add the import. Adjust `../` depth based on file location.

### Step 3: Decide on `600ms` site

```bash
grep -rn "Duration(milliseconds: 600)" app/lib/presentation/
```

Open the file and inspect context (what animation is this for?). Two options:

- **If the 600ms is intentional (e.g., splash fade, hero transition)**: keep as literal, add a comment:
  ```dart
  // Sprint 5A: kept literal — intentionally slower than motionSlow (400ms) for hero transition
  duration: const Duration(milliseconds: 600),
  ```
- **If 600ms is an accidental long duration**: replace with `AppConstants.motionSlow` (400ms shift down).

Default: keep literal with comment if context is unclear — easier to revisit later.

### Step 4: Verify grep

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -rE "Duration\(milliseconds:" lib/presentation/ | grep -v "AppConstants\."
```
Expected: ≤ 1 line (only the 600ms site if kept literal).

### Step 5: Flutter analyze + test

```bash
flutter analyze lib/presentation/
flutter test
```
Expected: clean + all pass. `Duration` doesn't affect goldens (doesn't render).

### Step 6: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/
git commit -m "$(cat <<'EOF'
refactor(theme): migrate Duration sites to AppConstants.motionX

1 × Duration(milliseconds: 200) → AppConstants.motionMedium.
1 × Duration(milliseconds: 600) kept literal with explanatory
comment (intentional long animation).

Part of Sprint 5A Phase 3.
EOF
)"
```

- [ ] **Step 6 complete**

---

## Task 4: Phase 4 — Migrate 93 `BorderRadius.circular(N)` + `cardRadius` + `buttonRadius`

**Files:**
- Modify (via bulk sed): all `.dart` files in `app/lib/presentation/` and `app/lib/**` containing hardcoded radius literals
- Modify: `app/lib/core/constants/app_constants.dart` (remove `buttonRadius`, `cardRadius`)

### Step 1: Bulk sed for numeric `BorderRadius.circular(N)`

Apply in the exact order shown (largest-matching values first to avoid `circular(16)` being partially matched by `circular(1)` — but since sed matches full tokens with `\(N\)`, order doesn't actually matter for numbers; still written in descending order for clarity):

```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation
find . -name "*.dart" -exec sed -i '' \
  -e 's/BorderRadius\.circular(20)/BorderRadius.circular(AppConstants.radiusXl)/g' \
  -e 's/BorderRadius\.circular(18)/BorderRadius.circular(AppConstants.radiusXl)/g' \
  -e 's/BorderRadius\.circular(16)/BorderRadius.circular(AppConstants.radiusLg)/g' \
  -e 's/BorderRadius\.circular(12)/BorderRadius.circular(AppConstants.radiusMd)/g' \
  -e 's/BorderRadius\.circular(10)/BorderRadius.circular(AppConstants.radiusMd)/g' \
  -e 's/BorderRadius\.circular(8)/BorderRadius.circular(AppConstants.radiusSm)/g' \
  -e 's/BorderRadius\.circular(6)/BorderRadius.circular(AppConstants.radiusSm)/g' \
  -e 's/BorderRadius\.circular(4)/BorderRadius.circular(AppConstants.radiusXs)/g' \
  {} \;
```

**Do NOT sed `circular(1)` or `circular(2)`** — those are thin borders, kept literal.

### Step 2: Migrate `AppConstants.cardRadius` and `AppConstants.buttonRadius`

```bash
cd /Users/latifrjdev/Downloads/Dukon
find app/lib -name "*.dart" -exec sed -i '' \
  -e 's/AppConstants\.cardRadius\b/AppConstants.radiusLg/g' \
  -e 's/AppConstants\.buttonRadius\b/AppConstants.radiusLg/g' \
  {} \;
```

Also check for usage in golden tests and other test files:
```bash
find app/test -name "*.dart" -exec sed -i '' \
  -e 's/AppConstants\.cardRadius\b/AppConstants.radiusLg/g' \
  -e 's/AppConstants\.buttonRadius\b/AppConstants.radiusLg/g' \
  {} \;
```

### Step 3: Remove deprecated constants from `app_constants.dart`

Edit `app/lib/core/constants/app_constants.dart`. Find and DELETE these two lines:

```dart
// DELETE these two lines:
  static const double buttonRadius = 14.0;
  static const double cardRadius = 16.0;
```

### Step 4: Verify greps

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
# Hardcoded BorderRadius.circular with numeric arg
grep -rE "BorderRadius\.circular\([0-9]" lib/presentation/ | grep -v "AppConstants\."
# Expected: only BorderRadius.circular(1) and BorderRadius.circular(2) sites — ≤ 9 total

# No more cardRadius/buttonRadius anywhere
grep -rE "cardRadius|buttonRadius" app/
# Expected: no output (0 refs)
```

### Step 5: Flutter analyze

```bash
flutter analyze
```
Expected: "No issues found!"

If errors appear (most likely: a file now uses `AppConstants.radiusXl/Md/Sm/Xs/Lg` but doesn't import `AppConstants`) — add the missing import.

Common fix pattern:
```bash
# Find files that use AppConstants but might not import it
grep -rl "AppConstants\.radius" app/lib/presentation/ | while read f; do
  if ! grep -q "core/constants/app_constants.dart" "$f"; then
    echo "MISSING IMPORT: $f"
  fi
done
```
For each flagged file, add the import at the top:
```dart
import '../../../core/constants/app_constants.dart';  // adjust ../ depth
```

### Step 6: Regen all goldens

The 40+ sites with +2 px shift + the 141 cardRadius/buttonRadius renames (cardRadius = 0 shift, buttonRadius = +2 shift) — lots of pages will have minor pixel differences.

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens
```

### Step 7: Visually spot-check 5–10 dark goldens

Open the following dark PNGs to confirm no unintended layout breaks:
- `test/presentation/pages/dashboard/goldens/dashboard_dark.png`
- `test/presentation/pages/product/goldens/product_list_dark.png`
- `test/presentation/pages/pos/goldens/pos_checkout_dark.png`
- `test/presentation/pages/finance/goldens/finance_dashboard_dark.png`
- `test/presentation/pages/settings/goldens/settings_dark.png`
- `test/presentation/widgets/common/goldens/app_dialog_dark.png`
- `test/presentation/widgets/common/goldens/app_bottom_sheet_dark.png`
- `test/presentation/widgets/common/goldens/app_bottom_nav_bar_dark.png`

Confirm:
- Card corners look consistent (no mixed radii on same card)
- Buttons appear correctly rounded (16 px should feel correct on mobile)
- No overlapping/overflow from 2px shifts

If a specific widget looks worse:
- Inspect which radius tokenit uses
- Option: swap to a different token (e.g., `radiusMd` instead of `radiusLg`)
- Re-regen just that file's goldens

### Step 8: Run tests without --update-goldens

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test
```
Expected: all tests pass (~335).

If 0.01% pixel drift occurs on shift_card tests (Sprint 3 pattern): regen once more from full-suite context:
```bash
flutter test --update-goldens
flutter test
```

### Step 9: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/core/constants/app_constants.dart \
        app/lib/presentation/ \
        app/lib/ \
        app/test/presentation/
git commit -m "$(cat <<'EOF'
refactor(theme): migrate 93 BorderRadius hardcodes to radii scale + deprecate cardRadius/buttonRadius

Replaces 93 hardcoded BorderRadius.circular(N) calls with
AppConstants.radiusXs/Sm/Md/Lg/Xl tokens per 4-based scale. Values
(1) and (2) kept as literals (too thin for scale).

Migrates 91 AppConstants.cardRadius and 50 AppConstants.buttonRadius
refs to AppConstants.radiusLg (cardRadius 16→16 zero shift;
buttonRadius 14→16 +2 px). Removes the two deprecated constants
from app_constants.dart.

~40 sites shift by +2 px — goldens regenerated; spot-checked dark
mode on 8 reference PNGs, no unintended regressions.

Part of Sprint 5A Phase 4.
EOF
)"
```

- [ ] **Step 9 complete**

---

## Task 5: Phase 5 — Wrap-Up

**Files:**
- Modify: `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5a-design-tokens.md` (prepend completion note)

### Step 1: Sprint-level acceptance greps

```bash
cd /Users/latifrjdev/Downloads/Dukon/app

# Hardcoded BorderRadius
grep -rE "BorderRadius\.circular\([0-9]" lib/presentation/ | grep -v "AppConstants\." | wc -l
# Expected: ≤ 9 (only BorderRadius.circular(1) = 1 site and (2) = 8 sites)

# Hardcoded BoxShadow
grep -rE "BoxShadow\(" lib/presentation/ | wc -l
# Expected: 0

# Hardcoded Duration(milliseconds:)
grep -rE "Duration\(milliseconds:" lib/presentation/ | grep -v "AppConstants\." | wc -l
# Expected: ≤ 1 (only the 600ms site if kept literal)

# Removed constants
grep -rE "cardRadius|buttonRadius" app/
# Expected: 0 matches

# Renamed radiusXl preservation
grep -rn "AppConstants\.radiusXxl" app/lib/ | wc -l
# Expected: 5+ (at least the renamed 5 sites from Phase 1)
```

### Step 2: Sprint-level analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze
```
Expected: "No issues found!"

### Step 3: Sprint-level tests

```bash
flutter test
```
Expected: ~335 tests pass (332 existing + 3 new elevation tests).

### Step 4: Update plan with completion note

Edit `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5a-design-tokens.md`. Prepend to the top of the file (right after the header block, before "Pre-Task Audit"):

```markdown
## Sprint 5A Complete — 2026-04-21

- **Design tokens expanded:** `AppConstants` gains `radiusXs`, `radiusXl` (new value), `radiusXxl`, `motionFast`, `motionMedium`, `motionSlow`. `ThemeColors` gains `elevationSm/Md/Lg` (theme-aware via `shadowColor`).
- **241 hardcoded sites migrated** to tokens: 93 `BorderRadius.circular` + 9 `BoxShadow` + 2 `Duration` + 91 `cardRadius` + 50 `buttonRadius`. `cardRadius` / `buttonRadius` constants removed.
- **Acceptance:** `flutter analyze` 0 issues; `flutter test` 335 pass (332 + 3 new). `grep BoxShadow\|Duration\|cardRadius\|buttonRadius` in `app/lib/presentation/` returns 0 matches outside `AppConstants.` references.
- Follow-up: Sprint 5B — accessibility audit (WCAG AA, contrast, touch targets, semantic labels).
```

### Step 5: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/plans/2026-04-21-ui-ux-sprint-5a-design-tokens.md
git commit -m "$(cat <<'EOF'
docs(sprint-5a): mark design tokens expansion complete

flutter analyze: 0 issues. flutter test: 335 pass (+3 elevation
tests). 241 hardcoded sites migrated to tokens (radii + motion +
elevation). cardRadius and buttonRadius constants removed.

Next: Sprint 5B — accessibility audit.
EOF
)"
```

- [ ] **Step 5 complete**

---

## Execution Notes

- **Phase 1 order is critical.** Rename `AppConstants.radiusXl` to `radiusXxl` BEFORE introducing the new `radiusXl = 20`. If order is inverted, the 5 existing refs silently shift from 24 px to 20 px, potentially breaking layouts.
- **`cardRadius` is a 0-shift rename** (both are 16 px), so 91 refs migrate cleanly. `buttonRadius` 14→16 is +2 px — visual delta appears on all buttons; confirm on emulator post-Phase 4.
- **`BoxShadow` heuristic is a judgment call.** If blur/offset doesn't fit cleanly in one tier, default to `elevationMd` — it's the middle ground. Comment the commit message if multiple ambiguous sites.
- **`Duration(milliseconds: 600)` is edge-case.** The spec allows keeping literal with comment; default to that unless the animation is clearly a bug.
- **Avoid cross-folder sed for `buttonRadius`/`cardRadius`.** The sed applies across ALL `.dart` files including tests — make sure tests compile after.
- **Sprint 3 pixel non-determinism pattern:** if the full `flutter test` reports 0.01% diffs on shift_card tests after Phase 4, regen from full-suite context once more. This is a known Impeller anti-aliasing drift, not a real regression.
- **IMPORTANT: `import` statements for `AppConstants`.** After the bulk sed, some files may now reference `AppConstants.radiusXX` but not import the class. `flutter analyze` catches this. Add the import with the correct `../` depth (3 for `pages/<folder>/`, 3 for `widgets/<folder>/`).
