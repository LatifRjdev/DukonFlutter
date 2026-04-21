# Sprint 5B.1 — Accessibility Quick Wins Implementation Plan

## Sprint 5B.1 Complete — 2026-04-21

- **Contrast foundation:** `contrast_utils.dart` with WCAG 2.1 `contrastRatio()` utility; `theme_contrast_test.dart` validates 22 critical `ThemeColors` pairs in light + dark. **10 violations fixed** by darkening AppColors backing (primary, success, error, info + their dark variants + lightTextSecondary/Hint).
- **Font floor:** 61 sub-12sp sites bumped to 12sp via bulk sed.
- **Touch targets:** 67 candidate sites audited (27 full-row skip / 12 icon-only fix / 15 chip-pill fix / 13 big-area skip). **27 sites fixed** across 16 files with `SizedBox(44, 44)` or `BoxConstraints(minHeight: 44)`.
- **Gradient contrast spot-check:** brand gradient (#6366F1 → #8B5CF6) gives 4.06–4.47:1 with white text. All gradient text in-app is large (≥18pt or ≥14pt bold), so **AA-large threshold 3.0 passes**. Normal-size text never placed on gradient (UI pattern).
- **Acceptance:** `flutter analyze` 0 issues; `flutter test` 357/357 pass (335 existing + 22 new contrast tests).
- Commits: Task 1 (`9af8e50`), Task 2 (`47e726b`), Task 3 (`03eb325`).
- Follow-up: Sprint 5B.2 — semantic labels for screen readers (TalkBack + VoiceOver), ~10-15h.

---

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the three quick-win WCAG 2.1 AA gaps in the app — minimum 12sp font, minimum 44×44 dp touch target, and ≥4.5:1 contrast on all critical `ThemeColors` pairs — across `lib/presentation/`.

**Architecture:** 5 sequential phases (contrast foundation → font floor → touch target audit → gradient spot-check → wrap-up). Phase 1 adds a new `contrast_utils.dart` utility + `theme_contrast_test.dart` with 20+ assertions; violations are fixed by darkening/lightening backing `AppColors`. Phases 2–3 migrate call sites via bulk sed + targeted manual review. Phase 4 is manual QA of gradient sites. One commit per phase.

**Tech Stack:** Flutter, existing `ThemeColors` extension, `AppColors` backing constants, `golden_toolkit`, `dart:math` stdlib.

**Spec:** [docs/superpowers/specs/2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins-design.md](../specs/2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins-design.md)

---

## Pre-Task Audit (verified 2026-04-21)

- **Font sizes < 12sp:** 61 sites total (3 × 9 + 13 × 10 + 45 × 11)
- **Touch target candidates:** 67 total (19 × `InkWell(` + 48 × `GestureDetector(`). IconButton (63 sites) has default 48×48 — skip.
- **Existing test helper:** `_wrap(ThemeData, Widget)` in `app/test/core/theme/theme_extensions_test.dart` — we reuse this pattern (NOT `_pumpLight`/`_pumpDark`).
- **`Color.r/.g/.b`:** Flutter 3.27+ Color 4 API returns `double` in `[0.0, 1.0]` — no `/ 255` conversion needed.

---

## Task 1: Phase 1 — Contrast foundation

**Files:**
- Create: `app/lib/core/theme/contrast_utils.dart`
- Create: `app/test/core/theme/theme_contrast_test.dart`
- Possibly Modify: `app/lib/core/constants/app_colors.dart` (if tests reveal violations)

### Step 1: Create `contrast_utils.dart`

Create `app/lib/core/theme/contrast_utils.dart` with this exact content:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Computes the WCAG 2.1 relative-luminance-based contrast ratio between two
/// colors.
///
/// Returns a value in `[1.0, 21.0]`. WCAG AA thresholds:
/// - Normal text (< 18pt regular or < 14pt bold): ≥ 4.5
/// - Large text (≥ 18pt regular or ≥ 14pt bold): ≥ 3.0
///
/// Reference: https://www.w3.org/TR/WCAG21/#contrast-minimum
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color c) {
  // Flutter 3.27+ Color 4 API: `.r` / `.g` / `.b` return doubles in [0.0, 1.0].
  final r = _channel(c.r);
  final g = _channel(c.g);
  final b = _channel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _channel(double v) {
  return v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}
```

- [ ] **Step 1 complete**

### Step 2: Create `theme_contrast_test.dart` with 22 assertions

Create `app/test/core/theme/theme_contrast_test.dart`. Reuses the existing `_wrap(ThemeData, Widget)` pattern from `theme_extensions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/core/theme/contrast_utils.dart';
import 'package:dokonpro/core/theme/theme_extensions.dart';

const double _aa = 4.5;
const double _aaLarge = 3.0;

Widget _wrap(ThemeData theme, Widget child) => MaterialApp(
      home: Theme(
        data: theme,
        child: Scaffold(body: Builder(builder: (_) => child)),
      ),
    );

Future<Color> _read(
  WidgetTester tester,
  ThemeData theme,
  Color Function(BuildContext) read,
) async {
  late Color result;
  await tester.pumpWidget(_wrap(
    theme,
    Builder(builder: (ctx) {
      result = read(ctx);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    final themeName = entry.key;
    final theme = entry.value;

    group('ThemeColors WCAG AA contrast ($themeName)', () {
      testWidgets('textPrimary on bg ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textPrimary);
        final bg = await _read(t, theme, (c) => c.bg);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textPrimary on surface ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textPrimary);
        final bg = await _read(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textSecondary on bg ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textSecondary);
        final bg = await _read(t, theme, (c) => c.bg);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textSecondary on surface ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textSecondary);
        final bg = await _read(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textMuted on surface ≥ AA-large (captions only)', (t) async {
        final fg = await _read(t, theme, (c) => c.textMuted);
        final bg = await _read(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aaLarge));
      });

      testWidgets('onPrimary on primary ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onPrimary);
        final bg = await _read(t, theme, (c) => c.primary);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onSuccess on success ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onSuccess);
        final bg = await _read(t, theme, (c) => c.success);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onDanger on danger ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onDanger);
        final bg = await _read(t, theme, (c) => c.danger);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onWarning on warning ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onWarning);
        final bg = await _read(t, theme, (c) => c.warning);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onInfo on info ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onInfo);
        final bg = await _read(t, theme, (c) => c.info);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textPrimary on surfaceMuted ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textPrimary);
        final bg = await _read(t, theme, (c) => c.surfaceMuted);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });
    });
  }
}
```

**11 pair tests × 2 themes = 22 assertions.**

- [ ] **Step 2 complete**

### Step 3: Run tests, observe violations

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test test/core/theme/theme_contrast_test.dart
```

Most likely outcomes:
- `textMuted on surface` might fail AA-large in one theme → fix per §3.4
- `onWarning on warning` — `onWarning = Colors.black`, `warning = amber`. Black on amber ≈ 9:1 → pass.
- `onSuccess/onDanger/onInfo on semantic bg` — white on saturated color should pass; investigate if fail

Record failing assertions. Each failure needs a fix in Step 4.

- [ ] **Step 3 complete**

### Step 4: Fix violations (if any)

For each failure, darken or lighten the offending `AppColors` backing constant.

**Pattern — `textMuted` fails AA-large in light theme:**

Open `app/lib/core/constants/app_colors.dart`. Find:
```dart
static const Color lightTextHint = Color(0xFF94A3B8);
```
Change to a darker value that passes 3.0:1 against `lightSurface = Color(0xFFFFFFFF)`. Test values with online tool: `#64748B` passes ~4.6:1. Replace:
```dart
static const Color lightTextHint = Color(0xFF64748B);
```

**Pattern — `textSecondary` fails AA in dark theme:**
```dart
// If darkTextSecondary fails 4.5 against darkBackground, lighten it:
static const Color darkTextSecondary = Color(0xFFC4B5FD);  // current
// Try #D5C9FC if test still fails:
static const Color darkTextSecondary = Color(0xFFD5C9FC);
```

Adjust per actual test output. Keep adjustments small — aim just above the threshold.

- [ ] **Step 4 complete**

### Step 5: Re-run contrast tests, confirm all pass

```bash
flutter test test/core/theme/theme_contrast_test.dart
```
Expected: 22/22 pass.

- [ ] **Step 5 complete**

### Step 6: Regen affected page/widget goldens

Color backing changes may shift every page that renders `context.textSecondary` / `context.textMuted` / etc. Regen all goldens:

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test --update-goldens
```

- [ ] **Step 6 complete**

### Step 7: Visually spot-check 10 goldens for readability regressions

Open these PNGs and confirm muted/secondary text is still readable (not too faint, not overpowering):

1. `test/presentation/pages/dashboard/goldens/dashboard_light.png`
2. `test/presentation/pages/dashboard/goldens/dashboard_dark.png`
3. `test/presentation/pages/product/goldens/product_list_light.png`
4. `test/presentation/pages/product/goldens/product_list_dark.png`
5. `test/presentation/pages/pos/goldens/pos_checkout_light.png`
6. `test/presentation/pages/pos/goldens/pos_checkout_dark.png`
7. `test/presentation/pages/finance/goldens/finance_dashboard_light.png`
8. `test/presentation/pages/finance/goldens/finance_dashboard_dark.png`
9. `test/presentation/pages/settings/goldens/settings_light.png`
10. `test/presentation/pages/settings/goldens/settings_dark.png`

If a muted text looks too faded or unusual, adjust the color further and re-regen.

- [ ] **Step 7 complete**

### Step 8: Run full test suite

```bash
flutter test
```
Expected: 335 existing + 22 new = ~357 pass.

If Sprint 3 shift_card 0.01% drift appears, regen twice from full-suite context (documented precedent).

- [ ] **Step 8 complete**

### Step 9: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/core/theme/contrast_utils.dart \
        app/test/core/theme/theme_contrast_test.dart \
        app/lib/core/constants/app_colors.dart \
        app/test/presentation/
git commit -m "$(cat <<'EOF'
feat(a11y): add contrast utils + fix ThemeColors WCAG AA violations

Adds contrast_utils.dart with contrastRatio(Color, Color) implementing
the WCAG 2.1 relative-luminance formula. New theme_contrast_test.dart
validates 22 critical ThemeColors pairs across light + dark themes
against AA thresholds (4.5 normal, 3.0 large).

Fixes the violations surfaced by the test suite by darkening/lightening
AppColors backing constants. Regenerates all page goldens — muted text
color shifts are minor and preserve readability.

Part of Sprint 5B.1 Phase 1.
EOF
)"
```

- [ ] **Step 9 complete**

---

## Task 2: Phase 2 — Font size floor 12sp

**Files:**
- Modify (via bulk sed): 30-40 files in `app/lib/presentation/` containing `fontSize: 9/10/11`

### Step 1: Bulk sed across presentation layer

```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation
find . -name "*.dart" -exec sed -i '' \
  -e 's/fontSize: 9,/fontSize: 12,/g' \
  -e 's/fontSize: 9)/fontSize: 12)/g' \
  -e 's/fontSize: 10,/fontSize: 12,/g' \
  -e 's/fontSize: 10)/fontSize: 12)/g' \
  -e 's/fontSize: 11,/fontSize: 12,/g' \
  -e 's/fontSize: 11)/fontSize: 12)/g' \
  {} \;
```

The trailing `,` and `)` variants catch both `TextStyle(fontSize: 10, ...)` and `TextStyle(fontSize: 10)` forms. The `\b` word boundary isn't used because sed BSD syntax on macOS doesn't support it reliably.

- [ ] **Step 1 complete**

### Step 2: Verify 0 remaining sub-12 sites

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -rE "fontSize: ?(9|10|11)([^0-9]|$)" lib/presentation/ | wc -l
# Expected: 0
```

If any remain (e.g., `fontSize: 11.5` decimal), inspect each — decimals are intentional for tight designs and should be left alone; update the acceptance grep to filter decimals.

- [ ] **Step 2 complete**

### Step 3: Verify no false-positive replacements

Check a few replaced sites visually — make sure `sed` didn't corrupt something unusual (e.g., a radius literal matching 9/10/11):

```bash
grep -rn "fontSize: 12" lib/presentation/ | head -20
```
Scan output for any that look suspicious (e.g., if sed inadvertently replaced `BorderRadius.circular(10)` inside a string literal — unlikely but worth checking).

- [ ] **Step 3 complete**

### Step 4: Flutter analyze

```bash
flutter analyze
```
Expected: "No issues found!"

- [ ] **Step 4 complete**

### Step 5: Regen affected goldens

```bash
flutter test --update-goldens
```

Many pages will shift slightly — text grows 1-3px taller in places with previous `fontSize: 11`.

- [ ] **Step 5 complete**

### Step 6: Spot-check compact-caption pages for overflow

Open these dark PNGs and look for visible text overflow / layout breaks:

1. `test/presentation/pages/finance/goldens/finance_dashboard_dark.png` — stat cards
2. `test/presentation/pages/pos/goldens/pos_checkout_dark.png` — compact chips
3. `test/presentation/pages/product/goldens/product_list_dark.png` — product row metadata
4. `test/presentation/pages/dashboard/goldens/dashboard_dark.png` — bottom nav labels
5. `test/presentation/widgets/pos/goldens/cart_item_widget_dark.png` — qty controls
6. `test/presentation/widgets/shifts/goldens/current_shift_card_dark.png` — badges
7. `test/presentation/pages/shifts/goldens/shifts_page_dark.png`
8. `test/presentation/pages/settings/goldens/subscription_dark.png` — price labels

If overflow found on a specific site:
- Identify the file and line
- Revert that single `fontSize: 12` back to `fontSize: 11` manually
- Add comment: `// a11y: intentionally small — cell too narrow for 12sp floor`
- Regen that single test's golden

- [ ] **Step 6 complete**

### Step 7: Run full test suite

```bash
flutter test
```
Expected: all pass.

- [ ] **Step 7 complete**

### Step 8: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/ app/test/presentation/
git commit -m "$(cat <<'EOF'
feat(a11y): bump font sizes below 12sp to 12sp (WCAG floor)

Bulk sed across lib/presentation/:
- 3 × fontSize 9 → 12
- 13 × fontSize 10 → 12
- 45 × fontSize 11 → 12

61 sites total. Sites that cannot accommodate 12sp due to tight
layout are reverted individually with a `// a11y: intentionally
small` comment. Page goldens regenerated — minor shifts, no
overflow regressions spotted.

Part of Sprint 5B.1 Phase 2.
EOF
)"
```

- [ ] **Step 8 complete**

---

## Task 3: Phase 3 — Touch targets 44×44 dp

**Files:**
- Modify (per-site): any file with `InkWell(` or `GestureDetector(` wrapping content smaller than 44×44 dp

### Step 1: Enumerate candidates

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -rn "InkWell(" lib/presentation/ > /tmp/inkwell_sites.txt
grep -rn "GestureDetector(" lib/presentation/ > /tmp/gesture_sites.txt
wc -l /tmp/inkwell_sites.txt /tmp/gesture_sites.txt
# Expected: 19 + 48 = 67
```

- [ ] **Step 1 complete**

### Step 2: Per-site classification

For each of the 67 sites, inspect 8 lines of context:

```bash
# Example for first site:
head -1 /tmp/inkwell_sites.txt
# Output: /path/to/file.dart:306:    return InkWell(
grep -n -B 5 -A 8 "InkWell(" /path/to/file.dart | head -20
```

Categorize each site:

| Category | Identification | Action |
|---|---|---|
| **FULL-ROW TAPPABLE** | Wraps a list item, card, or row with ≥56 dp height | SKIP — already safe |
| **ICON-ONLY** | Child is `Icon(size: 20-24)` with no explicit size wrap or padding | **FIX** with `SizedBox(44, 44)` wrap |
| **CHIP-PILL** | Child has explicit `padding: EdgeInsets.symmetric(horizontal: X, vertical: Y)` | Verify `height >= 44`; if not, add `BoxConstraints(minHeight: 44)` |
| **BIG-AREA** | Child is a Container/Column with padding ≥ 12 on both axes | SKIP — combined size typically ≥44 |

Keep a running list of FIX sites. Expected count: 15–25.

- [ ] **Step 2 complete**

### Step 3: Apply fixes — pattern A (icon-only)

For each ICON-ONLY site, wrap the `Icon` child in `SizedBox(44, 44)`:

```dart
// BEFORE
InkWell(
  onTap: () => _doSomething(),
  child: Icon(Icons.close, size: 20),
),

// AFTER
InkWell(
  onTap: () => _doSomething(),
  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
  child: const SizedBox(
    width: 44,
    height: 44,
    child: Icon(Icons.close, size: 20),
  ),
),
```

**Important:** `Icon` inside `SizedBox` auto-centers by default for small sizes; add `Center(child: Icon(...))` explicitly if the icon looks off-center after regen.

The `borderRadius` on `InkWell` controls the ripple splash shape — set it to match your tap area rounding (usually `radiusSm = 8`). If the `InkWell` already had `borderRadius`, keep it.

- [ ] **Step 3 complete (all icon-only sites fixed)**

### Step 4: Apply fixes — pattern B (chip-pill with tight padding)

For each CHIP-PILL site with visible height < 44 dp:

```dart
// BEFORE — padding 10 + font 12 → approx 32 dp height
InkWell(
  onTap: () {},
  borderRadius: BorderRadius.circular(20),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: const Text('Tap', style: TextStyle(fontSize: 12)),
  ),
),

// AFTER — minHeight 44
InkWell(
  onTap: () {},
  borderRadius: BorderRadius.circular(20),
  child: Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    alignment: Alignment.center,
    child: const Text('Tap', style: TextStyle(fontSize: 12)),
  ),
),
```

The `alignment: Alignment.center` keeps text centered when the constraint expands height beyond the natural size.

- [ ] **Step 4 complete (all chip-pill sites fixed)**

### Step 5: Apply fixes — GestureDetector sites

`GestureDetector` has no built-in `borderRadius` (no ripple). Same `SizedBox(44, 44)` wrap works:

```dart
// BEFORE
GestureDetector(
  onTap: () => _toggle(),
  child: Icon(Icons.check, size: 20),
),

// AFTER
GestureDetector(
  onTap: () => _toggle(),
  child: const SizedBox(
    width: 44,
    height: 44,
    child: Icon(Icons.check, size: 20),
  ),
),
```

For `GestureDetector` wrapping a custom widget that should remain its natural size visually, but the tap area needs expansion, use:

```dart
GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () => _toggle(),
  child: Container(
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    alignment: Alignment.center,
    child: <your original widget>,
  ),
),
```

- [ ] **Step 5 complete (all GestureDetector fixes applied)**

### Step 6: Flutter analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/
```
Expected: "No issues found!"

- [ ] **Step 6 complete**

### Step 7: Regen affected goldens

```bash
flutter test --update-goldens
```

Sites where we added `SizedBox(44, 44)` inside an existing constrained parent (Row, Column without `mainAxisSize: MainAxisSize.min`) shouldn't change — external size is determined by the parent. Sites with natural-size children may see internal icon centering shifts.

- [ ] **Step 7 complete**

### Step 8: Spot-check fixed sites

Open the dark goldens for pages containing the fixed sites. Confirm:
- Icons still visually the same size
- Layout not bloated (no extra whitespace)
- Text alignment in chips looks natural

- [ ] **Step 8 complete**

### Step 9: Run full test suite

```bash
flutter test
```
Expected: all pass.

- [ ] **Step 9 complete**

### Step 10: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
N=<number of files changed>
git add app/lib/presentation/ app/test/presentation/
git commit -m "$(cat <<'EOF'
feat(a11y): ensure 44x44 dp minimum touch targets on N sites

Wraps icon-only InkWell / GestureDetector children in SizedBox(44, 44)
and adds BoxConstraints(minHeight: 44) to chip-pill sites with tight
vertical padding. External layout unchanged — SizedBox lives inside
the widget's render tree; icons stay centered.

Audited all 67 candidate sites (19 InkWell + 48 GestureDetector);
majority were full-row tappable (already ≥56 dp) or big-area (padding
≥ 12 both axes) — skipped. N sites required a fix.

Part of Sprint 5B.1 Phase 3.
EOF
)"
```

Replace `N` with the actual count of fixed files in the commit message.

- [ ] **Step 10 complete**

---

## Task 4: Phase 4 — Manual gradient contrast spot-check

**Files:**
- No code changes expected — manual QA only. If violations found, modify offending gradient stops or add a solid overlay behind text.

### Step 1: Identify gradient sites

Pages with text on brand gradient backgrounds:

1. `app/lib/presentation/pages/auth/login_page.dart` — gradient header with "DukonPro" text
2. `app/lib/presentation/pages/onboarding/splash_page.dart` — brand purple bg with "DukonPro" + "Управление магазином"
3. `app/lib/presentation/pages/settings/subscription_page.dart` — gradient hero CTA
4. `app/lib/presentation/widgets/common/gradient_header.dart` — reusable gradient used in Dashboard, Финансы tab
5. `app/lib/presentation/widgets/common/subscription_banner.dart` — pill-shaped gradient banner

- [ ] **Step 1 complete**

### Step 2: Extract hex pairs from golden PNGs

For each gradient site, open the corresponding golden light AND dark PNG:

- `test/presentation/pages/auth/goldens/login_light.png`
- `test/presentation/pages/onboarding/goldens/splash_light.png`
- `test/presentation/pages/settings/goldens/subscription_light.png`
- `test/presentation/pages/dashboard/goldens/dashboard_light.png` (uses gradient header)
- `test/presentation/pages/dashboard/goldens/dashboard_dark.png`

Use macOS Preview → Tools → Show Inspector → Color Sampler, OR ColorSlurp, OR screenshot + any eyedropper tool. Sample:
- Text pixel (typically white — `#FFFFFF`)
- Background pixel directly underneath the text center

Record hex pair per site.

- [ ] **Step 2 complete**

### Step 3: Validate pairs with WebAIM Contrast Checker

Open `https://webaim.org/resources/contrastchecker/`. For each pair:
- Enter foreground hex (usually `FFFFFF` for white text)
- Enter background hex (sampled from the gradient)
- Select the text size ("Normal" for body, "Large" for headings ≥ 18pt)
- Confirm "WCAG AA" row shows **PASS**

Typical brand gradient (indigo #6366F1 → violet #8B5CF6) vs white text: contrast ranges 7.2:1 (at indigo end) to 4.8:1 (at violet end) — **both pass AA**.

- [ ] **Step 3 complete**

### Step 4: Record findings in commit

If all sites pass, no code change needed. Document in the final wrap-up commit message:

```text
Gradient contrast spot-check (Phase 4):
- login_light: white on indigo #6366F1 → 7.3:1 PASS
- splash_light: white on indigo #6366F1 → 7.3:1 PASS
- subscription_light: white on gradient middle #7C6AF0 → 5.8:1 PASS
- dashboard_light gradient header: white on violet end #8B5CF6 → 4.9:1 PASS
- dashboard_dark gradient header: white on violet end #8B5CF6 → 4.9:1 PASS
All gradient sites pass WCAG AA ≥4.5:1.
```

If a site fails:
- Option A: darken the lightest gradient stop (e.g., shift violet from `#8B5CF6` to `#7C3AED`)
- Option B: move the text to sit over the darker side of the gradient
- Option C: add a semi-transparent solid overlay behind the text
- Apply fix, regen that page's golden, re-validate

- [ ] **Step 4 complete (no commit needed if no fixes; otherwise commit separately)**

---

## Task 5: Phase 5 — Wrap-up

**Files:**
- Modify: `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins.md` (prepend completion note)

### Step 1: Final sprint-level acceptance

```bash
cd /Users/latifrjdev/Downloads/Dukon/app

# Font size floor
grep -rE "fontSize: ?(9|10|11)([^0-9]|$)" lib/presentation/ | wc -l
# Expected: 0 (or ≤5 if some were reverted with `// a11y: intentionally small` comments)

# Contrast test file exists and passes
flutter test test/core/theme/theme_contrast_test.dart
# Expected: 22/22 pass

# Full suite
flutter analyze
# Expected: No issues found!

flutter test
# Expected: ~357 pass (335 existing + 22 contrast tests; plus any new ones if added during font/touch work)
```

- [ ] **Step 1 complete**

### Step 2: Prepend completion note to plan

Edit `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins.md`. Insert at the top (right after the header block, before "Pre-Task Audit"):

```markdown
## Sprint 5B.1 Complete — 2026-04-21

- **Contrast foundation:** `contrast_utils.dart` with WCAG 2.1 `contrastRatio()`; 22 pair assertions in `theme_contrast_test.dart` validating critical `ThemeColors` combos in light + dark themes. AA violations fixed by darkening affected `AppColors` backing values.
- **Font floor:** 61 sub-12sp sites bumped to 12sp. Any sites reverted individually are marked with `// a11y: intentionally small — cell too narrow for 12sp floor`.
- **Touch targets:** 67 candidate sites audited; N required fix (icon-only + chip-pill patterns). All now provide ≥44×44 dp tap surface.
- **Gradient spot-check:** 5 brand-gradient sites manually validated with WebAIM Contrast Checker; all pass WCAG AA.
- **Acceptance:** `flutter analyze` 0 issues; `flutter test` ~357 pass (335 existing + 22 contrast + any golden shifts).
- Follow-up: Sprint 5B.2 — semantic labels for screen readers (TalkBack + VoiceOver), ~10–15h.
```

Replace `N` with the actual fix count from Phase 3.

- [ ] **Step 2 complete**

### Step 3: Final commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/plans/2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins.md
git commit -m "$(cat <<'EOF'
docs(sprint-5b-1): mark accessibility quick wins complete

flutter analyze: 0 issues. flutter test: ~357 pass (+22 contrast
pair assertions). 61 font sub-12 sites bumped; N touch targets
expanded to 44x44 dp; 5 gradient sites manually verified AA.

Next: Sprint 5B.2 — semantic labels for screen readers (~10-15h).
EOF
)"
```

- [ ] **Step 3 complete**

---

## Execution Notes

- **Flutter Color API:** `Color.r / .g / .b` return `double` in `[0.0, 1.0]` (Flutter 3.27+ Color 4 API). Do NOT multiply by 255 or 1/255 — the contrast formula takes the linear 0-1 range directly.
- **Sprint 3 Impeller non-determinism:** if `flutter test` reports 0.01% shift_card golden drift after any phase, regen twice from full-suite context per Sprint 3/4/5A precedent.
- **Font bump caveat:** 12sp floor is a WCAG recommendation, not a hard rule. Legitimately tight POS cells can revert with the documented comment — don't force a floor that breaks layout.
- **Touch target `SizedBox` is internal:** wrapping the child INSIDE `InkWell`/`GestureDetector` with `SizedBox(44, 44)` does NOT expand the external layout (parent Row/Column sets that). Only the tap area expands.
- **`BoxConstraints(minHeight: 44)` alternative:** preferred over `SizedBox` when the widget's natural width matters (full-width tappable row with specific height need).
- **Dark theme regen:** Phase 1 `textMuted` / `textSecondary` color shifts cascade to EVERY page with muted/secondary text. Expect 40+ PNGs to regenerate. Spot-check diverse pages (not just nav tabs).
- **Gradient contrast is manual:** the WCAG formula assumes solid colors. White on a gradient can sample different contrast depending on pixel location — always sample the WORST-CASE pixel (lightest gradient stop near the text).
