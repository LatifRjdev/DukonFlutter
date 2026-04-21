# Sprint 5B.1 — Accessibility Quick Wins Design

**Date:** 2026-04-21
**Status:** Approved — ready for plan
**Depends on:** Sprint 5A Design Tokens Expansion (complete, commits `1669d35` → `63fec54`)
**Related specs:**
- [Sprint 4 — Cleanup & Polish](2026-04-20-ui-ux-sprint-4-cleanup-polish-design.md)
- [Sprint 5A — Design Tokens Expansion](2026-04-21-ui-ux-sprint-5a-design-tokens-design.md)
- Sprint 5B.2 (planned): Semantic Labels for screen readers

---

## 1. Overview & Scope

### Goal
Fix the three "quick wins" of WCAG 2.1 AA compliance — minimum font size 12sp, minimum touch target 44×44 dp, and contrast ratios ≥4.5:1 for normal text (≥3:1 for large/muted text) — across the presentation layer. Defer semantic labels and keyboard focus to Sprint 5B.2.

### Problem statement
After Sprint 1–5A, the theme system is token-driven and visually consistent. Accessibility compliance has not been audited. A quick audit revealed:

- **61 sites** with `fontSize: 9/10/11` — below WCAG-friendly minimum
- **67 sites** with `InkWell` (19) or `GestureDetector` (48) — most without guaranteed 44×44 dp touch surface
- **0** contrast tests — no guarantee that `ThemeColors` pairs meet AA 4.5:1
- **0** `Semantics` or `semanticLabel` usage — deferred to Sprint 5B.2

Sprint 5B.1 closes the "quick wins" gap (fixes fit in bulk sed + utility + targeted manual review). Sprint 5B.2 handles semantic labels, which require per-widget product decisions and cannot be bulk-applied.

### In scope

**1. Font size floor 12sp**
- 3 × `fontSize: 9` → `fontSize: 12`
- 13 × `fontSize: 10` → `fontSize: 12`
- 45 × `fontSize: 11` → `fontSize: 12`
- 12sp and 13sp sites unchanged (valid Material caption/label sizes)

**2. Touch target floor 44×44 dp**
- Audit 19 × `InkWell(` + 48 × `GestureDetector(` = 67 sites
- Categorize: full-row tappable / icon-only button / chip-pill / dialog button
- Icon-only sites with no padding → wrap in `SizedBox(width: 44, height: 44, child: ...)`
- Chip-pill sites → ensure `constraints: BoxConstraints(minHeight: 44)` or equivalent padding
- `IconButton` (63 sites) default 48×48 — out of scope (already passes)

**3. WCAG AA contrast foundation**
- Create `app/lib/core/theme/contrast_utils.dart` with `contrastRatio(Color, Color)` utility implementing WCAG 2.1 relative-luminance formula
- Create `app/test/core/theme/theme_contrast_test.dart` — 28+ pair assertions covering:
  - Light + dark mirror
  - `textPrimary / textSecondary / textMuted` on `bg / surface / surfaceMuted`
  - `onPrimary × primary`, `onSuccess × success`, `onDanger × danger`, `onWarning × warning`, `onInfo × info`
- Target: AA 4.5:1 for normal text; AA-large 3.0:1 for `textMuted` on surface (hints/captions only)
- Fix violations by darkening/lightening `AppColors` backing values; regen affected goldens
- Manual spot-check 3–5 gradient sites (auth, splash, subscription) with WebAIM Contrast Checker

### Out of scope (deferred to Sprint 5B.2)

- `semanticLabel:` on `IconButton` / `Icon` / custom widgets
- `Semantics()` wrappers with explicit hint / onTap labels
- TalkBack (Android) + VoiceOver (iOS) manual QA
- Screen-reader-exclusive decorative hiding (`excludeSemantics: true`)
- Live regions for dynamic content (cart, order state)
- Keyboard focus / `FocusNode` / Tab order management
- WCAG 2.1 AAA level (7:1 contrast, ≥18sp body text)
- Font sizes 12–13sp — keep as valid Material caption range

### Sprint-level acceptance

```bash
cd /Users/latifrjdev/Downloads/Dukon/app

# Font floor — 0 sites below 12
grep -rhoE "fontSize: ?(9|10|11)\b" lib/presentation/ | wc -l
# → 0

# Contrast test passes
flutter test test/core/theme/theme_contrast_test.dart
# → all 28+ assertions pass

# Full suite
flutter analyze    # → No issues found!
flutter test       # → ~343-345 pass (335 existing + 5-10 new contrast + possibly font bump affects)
```

Touch target audit uses commit message for traceability (no automated grep — requires per-site judgment).

---

## 2. New utility + tests

### 2.1 `contrast_utils.dart`

File: `app/lib/core/theme/contrast_utils.dart`

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Computes the WCAG 2.1 relative-luminance-based contrast ratio between two colors.
///
/// Returns a value in [1.0, 21.0]. WCAG AA thresholds:
/// - Normal text (<18pt regular or <14pt bold): ≥4.5
/// - Large text (≥18pt regular or ≥14pt bold): ≥3.0
///
/// See: https://www.w3.org/TR/WCAG21/#contrast-minimum
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color c) {
  // Color.r / .g / .b are in [0.0, 1.0] (Flutter 3.27+ Color 4 API).
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

### 2.2 `theme_contrast_test.dart`

File: `app/test/core/theme/theme_contrast_test.dart`

Follows the existing `theme_extensions_test.dart` pattern for `_pumpLight` / `_pumpDark` helpers. Structure:

```dart
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/core/theme/contrast_utils.dart';
import 'package:dokonpro/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _aa = 4.5;
const _aaLarge = 3.0;

Future<T> _readInTheme<T>(
  WidgetTester tester,
  ThemeData theme,
  T Function(BuildContext) read,
) async {
  T? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (ctx) {
          result = read(ctx);
          return const SizedBox();
        },
      ),
    ),
  );
  return result as T;
}

void main() {
  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    final themeName = entry.key;
    final theme = entry.value;

    group('ThemeColors WCAG AA contrast ($themeName)', () {
      testWidgets('textPrimary on bg ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.textPrimary);
        final bg = await _readInTheme(t, theme, (c) => c.bg);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textPrimary on surface ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.textPrimary);
        final bg = await _readInTheme(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textSecondary on bg ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.textSecondary);
        final bg = await _readInTheme(t, theme, (c) => c.bg);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textSecondary on surface ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.textSecondary);
        final bg = await _readInTheme(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textMuted on surface ≥ AA-large (captions only)', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.textMuted);
        final bg = await _readInTheme(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aaLarge));
      });

      testWidgets('onPrimary on primary ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.onPrimary);
        final bg = await _readInTheme(t, theme, (c) => c.primary);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onSuccess on success ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.onSuccess);
        final bg = await _readInTheme(t, theme, (c) => c.success);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onDanger on danger ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.onDanger);
        final bg = await _readInTheme(t, theme, (c) => c.danger);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onWarning on warning ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.onWarning);
        final bg = await _readInTheme(t, theme, (c) => c.warning);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onInfo on info ≥ AA', (t) async {
        final fg = await _readInTheme(t, theme, (c) => c.onInfo);
        final bg = await _readInTheme(t, theme, (c) => c.info);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });
    });
  }
}
```

**10 assertions × 2 themes = 20 test cases.** Expanding coverage to add `textPrimary × surfaceMuted`, `textSecondary × bg`, `onPrimary × secondary`, etc. brings the total to ~28.

### 2.3 Fix strategy for violations

- **`textMuted × surface` fails AA-large (<3:1):** darken the underlying `AppColors.lightTextHint` / `darkTextHint` until it passes. Regen goldens that render muted text.
- **`textSecondary × bg` fails AA (<4.5:1):** same approach — darken `lightTextSecondary` or lighten `darkTextSecondary`. Small shifts typically visible only on ultra-light-gray captions.
- **`onSuccess × success` fails:** two options:
  1. Change `onSuccess` from `Colors.white` to `Colors.black` if the semantic bg is too light — but this is an uglier visual.
  2. Darken the semantic bg (e.g., `success = #10B981` → `#059669`) — preferred; preserves on-* = white norm.
- **Gradient sites:** contrast not testable with solid-color formula. Manual check with screenshot + WebAIM Contrast Checker. White text on saturated indigo/violet gradient typically passes AA ≥7:1.

---

## 3. Migration Strategy

### Phase 1 — Contrast foundation (~30 min)

1. Create `app/lib/core/theme/contrast_utils.dart` as §2.1.
2. Create `app/test/core/theme/theme_contrast_test.dart` as §2.2.
3. Run: `flutter test test/core/theme/theme_contrast_test.dart` — observe failures.
4. For each failure, adjust `AppColors` backing value. Typical fixes:
   - `lightTextHint = #94A3B8` → `#64748B` (AA-large at 4.6:1)
   - `darkTextHint = #A09CB0` → `#B8B4C7` (if too dark for #0F0A1A)
5. Re-run test until all pass.
6. Regen affected goldens: `flutter test --update-goldens`.
7. Commit: `feat(a11y): add contrast utils + fix ThemeColors WCAG AA violations`.

### Phase 2 — Font size floor (~30 min)

1. Bulk sed across `lib/presentation/`:
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

   The trailing `,` and `)` variants catch both `TextStyle(fontSize: 10, ...)` and `Text('x', style: TextStyle(fontSize: 10))` forms.

2. Verify: `grep -rE "fontSize: ?(9|10|11)\b" lib/presentation/` — should be 0.
3. `flutter analyze` — clean.
4. `flutter test --update-goldens` — regen (expect many pages shift — text +1 to +3 px taller in places).
5. Spot-check 8–10 pages for overflow in compact captions (sale list items, finance stat cards, POS chips).
   - If a specific site overflows, narrow the fix: revert that single line to `fontSize: 11` with `// a11y: intentionally small — cell too narrow for 12sp` comment.
6. `flutter test` without `--update-goldens` — all pass.
7. Commit: `feat(a11y): bump font sizes below 12sp to 12sp (WCAG floor)`.

### Phase 3 — Touch target audit + fixes (~75 min)

1. Enumerate:
   ```bash
   grep -rn "InkWell(" lib/presentation/ > /tmp/inkwell_sites.txt
   grep -rn "GestureDetector(" lib/presentation/ > /tmp/gesture_sites.txt
   wc -l /tmp/inkwell_sites.txt /tmp/gesture_sites.txt  # 19 + 48 = 67
   ```
2. For each site, categorize (open with `-B 5 -A 10` context):
   - **FULL-ROW TAPPABLE** (height ≥44 already — list item, card) — skip
   - **ICON-ONLY** (child is `Icon(size: 20-24)`) — **FIX** with `SizedBox(44, 44)` wrap
   - **CHIP-PILL** (child has padding) — check rendered size; if < 44 in either dim, add `constraints: BoxConstraints(minHeight: 44)`
   - **BIG-AREA** (container with padding ≥ 12) — verify combined size ≥44; usually safe
3. Apply fixes per pattern (see Plan Task 3 for exact code patterns).
4. `flutter analyze` — clean.
5. `flutter test --update-goldens` — regen pages where widgets shifted.
6. Spot-check visual: icon buttons have correct hit surface; chips haven't ballooned.
7. `flutter test` — all pass.
8. Commit: `feat(a11y): ensure 44×44 dp minimum touch targets on <N> sites`.

### Phase 4 — Manual gradient contrast spot-check (~15 min)

1. Open golden PNGs for 3–5 gradient sites:
   - `test/presentation/pages/auth/goldens/login_light.png` — gradient top header
   - `test/presentation/pages/onboarding/goldens/splash_light.png` — brand purple bg
   - `test/presentation/pages/settings/goldens/subscription_light.png` — hero CTA
   - `test/presentation/pages/dashboard/goldens/dashboard_light.png` — gradient top
2. Pick a text pixel and a bg pixel using macOS Preview ColorSync or similar.
3. Plug hex pairs into WebAIM Contrast Checker (`https://webaim.org/resources/contrastchecker/`).
4. Verify ≥4.5:1 (normal) or ≥3.0:1 (large ≥18sp).
5. If all pass: document in commit message, no code change.
6. If violations: fix gradient stops or switch to a solid bg behind text; regen affected golden.

### Phase 5 — Wrap-up (~10 min)

1. `flutter analyze` → 0 issues.
2. `flutter test` → ~340-345 pass.
3. Sprint-level greps match acceptance §1.
4. Prepend completion note to this plan (when written).
5. Commit: `docs(sprint-5b-1): mark accessibility quick wins complete`.

---

## 4. Acceptance, Risks, Effort

### Sprint 5B.1 DONE when

1. `contrast_utils.dart` exists + `theme_contrast_test.dart` has ≥20 assertions passing in both themes
2. `grep -rhoE "fontSize: ?(9|10|11)\b" app/lib/presentation/` returns 0
3. Touch target fixes applied; commit message lists N affected files
4. 3–5 gradient sites manually spot-checked for AA contrast; no violations OR violations fixed
5. `flutter analyze` → 0 issues
6. `flutter test` → ~343-345 pass
7. 5 commits (Phase 1–5), final docs commit marks complete

### Metrics

| Metric | Before | After |
|---|---|---|
| Sites with `fontSize < 12` | 61 | 0 |
| Icon-only InkWell/GestureDetector < 44×44 | ~15-30 est. | 0 |
| Contrast pair tests | 0 | 20+ (light + dark) |
| AA contrast violations (tested pairs) | unknown | 0 |
| Total tests | 335 | ~345 |

### Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Font bump 11→12 breaks tight POS layouts (text wrap, overflow) | Medium | Regen goldens after Phase 2; spot-check 8-10 dense pages. If overflow → single-line revert with `// a11y: intentionally small — cell too narrow for 12sp` |
| Darkening `textMuted` / `textSecondary` cascades readability across app | **High** | Regen ALL page goldens after Phase 1; spot-check 10+ dark + 10+ light PNGs for regressions in muted-text widgets |
| Touch target `SizedBox(44, 44)` inside InkWell bloats visual layout | Low | Wrap is internal — external layout unchanged. Icon stays centered in the 44 box |
| 67 InkWell/GestureDetector review is tedious and produces errors | Medium | Use the 4-way categorization (full-row / icon-only / chip-pill / big-area) to skip obvious safe cases (expect ~40-50 skipped, ~15-25 fixed) |
| Sprint 3 Impeller pixel non-determinism on shift_card goldens recurs | Low | Sprint 3/4/5A precedent: regen twice from full-suite context if 0.01% drift appears |
| Gradient contrast edge case (white on light portion of gradient stop) | Low | Manual spot-check Phase 4 catches; fix by picking a higher-contrast stop or adding a solid bg overlay |
| `math.pow(...).toDouble()` precision issues in contrast formula | Very low | WCAG spec tolerates ±0.05 rounding; test assertions use `greaterThanOrEqualTo` so rounding drift doesn't cause flakes |

### Estimated effort

| Phase | Time |
|---|---|
| 1. Contrast foundation (util + 20+ tests + fixes + regen) | 30 m |
| 2. Font size floor (sed + regen + spot-check) | 30 m |
| 3. Touch target audit + fixes (15-25 flagged sites) | 75 m |
| 4. Manual gradient spot-check | 15 m |
| 5. Wrap-up | 10 m |
| **Total** | **~2.5-3 h** |

### Dependencies

All ready:
- `ThemeColors` extension (Sprint 1–2)
- `shadowColor`, `on*` tokens (Sprint 2.5, 4)
- `AppConstants.radiusXs` etc. (Sprint 5A)
- `dart:math` from stdlib (no pub dep)

### Deferred to Sprint 5B.2

- `semanticLabel` / `Semantics()` coverage on all interactive widgets
- Live regions for cart/order state changes
- TalkBack + VoiceOver manual QA
- Keyboard focus management + Tab order
- WCAG 2.1 AAA level (7:1 contrast; ≥18sp body)

---

## 5. Next Step

After approval, invoke `superpowers:writing-plans` to generate the implementation plan at `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins.md`.
