# Sprint 5A — Design Tokens Expansion Design

**Date:** 2026-04-21
**Status:** Approved — ready for plan
**Depends on:** Sprint 4 Cleanup & Polish (complete, commits `d9300cb` → `795558b`)
**Related specs:**
- [Sprint 2 — Page Theme Migration](2026-04-19-ui-ux-sprint-2-page-theme-migration-design.md)
- [Sprint 3 — Widget Theme Migration](2026-04-20-ui-ux-sprint-3-widget-theme-migration-design.md)
- [Sprint 4 — Cleanup & Polish](2026-04-20-ui-ux-sprint-4-cleanup-polish-design.md)
- Sprint 5B (planned): Accessibility Audit & Fixes

---

## 1. Overview & Scope

### Goal
Expand the design token palette beyond colors: add a coherent radii scale (xs/xl/xxl), a motion scale (fast/medium/slow), and a theme-aware elevation scale (sm/md/lg). Migrate all 109 hardcoded instances (93 `BorderRadius.circular`, 9 `BoxShadow`, 7 `Duration`) to the new tokens.

### Problem statement
After Sprint 1–4, color tokens are fully migrated (23 `ThemeColors` getters + 0 external `AppColors.light/dark` refs). The next consistency layer is scale-based design values:

- 93 hardcoded `BorderRadius.circular(N)` across the presentation layer, with 6 different values, 4 of which aren't in the existing `radiusSm/Md/Lg/Xl` scale (most common: `10` in 27 sites).
- 9 hardcoded `BoxShadow` with magic `blurRadius` / `offset` values — no theme-awareness; dark-mode elevation looks flat.
- 7 hardcoded `Duration` with 2 unique values (200ms, 600ms) — no motion standard.

Sprint 5A closes this gap by adding scale tokens and migrating every call site.

### In scope

**New tokens in `AppConstants`** (design-values, not theme-aware):
- `radiusXs = 4.0` (new)
- `radiusSm = 8.0` (existing, unchanged)
- `radiusMd = 12.0` (existing, unchanged)
- `radiusLg = 16.0` (existing, unchanged)
- `radiusXl = 20.0` (new value — replaces old `radiusXl = 24`)
- `radiusXxl = 24.0` (renamed from old `radiusXl`)
- `radiusRound = 100.0` (existing, unchanged)
- `motionFast = Duration(milliseconds: 150)` (new)
- `motionMedium = Duration(milliseconds: 250)` (new)
- `motionSlow = Duration(milliseconds: 400)` (new)

**New getters in `ThemeColors` extension** (theme-aware, use existing `context.shadowColor`):
- `List<BoxShadow> get elevationSm` — blur 4, offset (0, 2)
- `List<BoxShadow> get elevationMd` — blur 8, offset (0, 4)
- `List<BoxShadow> get elevationLg` — blur 16, offset (0, 8)

**Deprecations** (removed in Sprint 5A):
- `AppConstants.cardRadius = 16` → replace all refs with `radiusLg`
- `AppConstants.buttonRadius = 14` → replace all refs with `radiusLg` (round up 14→16; visual delta acceptable)

**Migrations** (total: 109 sites):
- 93 × `BorderRadius.circular(N)` → `BorderRadius.circular(AppConstants.radiusXxx)` per rounding table in §3
- 9 × `BoxShadow(...)` → `context.elevationSm/Md/Lg` (per-site blur/offset heuristic mapping)
- 7 × `Duration(milliseconds: N)` → `AppConstants.motionFast/Medium/Slow`

### Out of scope (deferred)

- **Sprint 5B:** Accessibility audit (contrast ratios, touch targets, WCAG AA, semantic labels)
- **Sprint 6+:** Typography scale tokens (only if Sprint 5A surfaces need)
- **Sprint 6+:** Migration of `spacing*` call sites (already well-used and consistent)

### Sprint-level acceptance

```bash
cd /Users/latifrjdev/Downloads/Dukon/app

# Hardcoded radii (only 1px and 2px literals allowed)
grep -rE "BorderRadius\.circular\([0-9]+(\.[0-9]+)?\)" lib/presentation/ | grep -v "AppConstants\." | wc -l
# → ≤ 2

# Hardcoded BoxShadow
grep -rE "BoxShadow\(" lib/presentation/ | wc -l
# → 0

# Hardcoded Duration with milliseconds
grep -rE "Duration\(milliseconds: ?[0-9]" lib/presentation/ | grep -v "AppConstants\." | wc -l
# → ≤ 2 (only 600ms+ outliers)

flutter analyze
# → No issues found!

flutter test
# → all tests pass (~335 = 332 existing + 3 new elevation tests)
```

---

## 2. Tokens Implementation

### 2.1 `AppConstants` additions

File: `app/lib/core/constants/app_constants.dart`

```dart
class AppConstants {
  // ... existing spacings unchanged ...

  // Border radii — clean 4-based scale
  static const double radiusXs = 4.0;         // NEW
  static const double radiusSm = 8.0;         // existing
  static const double radiusMd = 12.0;        // existing
  static const double radiusLg = 16.0;        // existing
  static const double radiusXl = 20.0;        // NEW VALUE — renamed old radiusXl
  static const double radiusXxl = 24.0;       // NEW — was old radiusXl
  static const double radiusRound = 100.0;    // existing

  // Motion durations
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionMedium = Duration(milliseconds: 250);
  static const Duration motionSlow = Duration(milliseconds: 400);

  // ... existing buttonHeight, buttonHeightSmall, cardElevation unchanged ...

  // REMOVED in Sprint 5A migration:
  //   - cardRadius (=16) — use radiusLg
  //   - buttonRadius (=14) — use radiusLg
}
```

Important constraint: the new `radiusXl = 20.0` shifts the old `radiusXl = 24.0`'s value. All existing call sites of `AppConstants.radiusXl` must be renamed to `AppConstants.radiusXxl` **before** the new value is introduced. See §3 Phase 1 order.

### 2.2 `ThemeColors` extension additions

File: `app/lib/core/theme/theme_extensions.dart`

Append to the `ThemeColors` extension:

```dart
/// Light elevation — small cards, list items. Soft on light, stronger on dark.
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

All three use the existing `shadowColor` getter, which already branches on brightness (`alpha: 0.08` in light, `alpha: 0.4` in dark). No new backing color constants needed.

### 2.3 Tests

File: `app/test/core/theme/theme_extensions_test.dart`

Append three test cases (follow the existing `_pumpLight` / `_pumpDark` helper pattern):

```dart
testWidgets('elevationSm has one shadow with blur 4 and offset (0,2)', (tester) async {
  List<BoxShadow>? val;
  await _pumpLight(tester, (ctx) => val = ctx.elevationSm);
  expect(val, isNotNull);
  expect(val!.length, 1);
  expect(val!.first.blurRadius, 4);
  expect(val!.first.offset, const Offset(0, 2));
});

testWidgets('elevationMd has one shadow with blur 8 and offset (0,4)', (tester) async {
  List<BoxShadow>? val;
  await _pumpLight(tester, (ctx) => val = ctx.elevationMd);
  expect(val, isNotNull);
  expect(val!.length, 1);
  expect(val!.first.blurRadius, 8);
  expect(val!.first.offset, const Offset(0, 4));
});

testWidgets('elevationLg has one shadow with blur 16 and offset (0,8)', (tester) async {
  List<BoxShadow>? val;
  await _pumpLight(tester, (ctx) => val = ctx.elevationLg);
  expect(val, isNotNull);
  expect(val!.length, 1);
  expect(val!.first.blurRadius, 16);
  expect(val!.first.offset, const Offset(0, 8));
});
```

`AppConstants` radii and motion tokens are plain `const` — no tests (compile-time checked).

---

## 3. Migration Strategy

### 3.1 Execution phases (low-risk → high-risk)

**Phase 1 — Add new tokens + rename existing radiusXl** (~15 min)

Order is critical to avoid `20 vs 24` ambiguity:

1. Read current `AppConstants.radiusXl` (=24).
2. `grep -rn "AppConstants\.radiusXl" app/lib/` — count references.
3. Sed-rename all refs to `AppConstants.radiusXxl`:
   ```bash
   find app/lib -name "*.dart" -exec sed -i '' 's/AppConstants\.radiusXl\b/AppConstants.radiusXxl/g' {} \;
   ```
4. In `app_constants.dart`, rename the constant declaration: `radiusXl = 24.0` → `radiusXxl = 24.0`.
5. Add new constants: `radiusXs = 4.0`, `radiusXl = 20.0` (new value), motion trio.
6. Add `elevationSm/Md/Lg` getters to `ThemeColors`.
7. Add 3 new tests for elevations.
8. `flutter analyze` → clean. `flutter test` → 335 tests pass.
9. Commit: `feat(theme): add radii xs/xl/xxl, motion, and elevation tokens`

**Phase 2 — Migrate `BoxShadow` → elevations** (9 sites, ~20 min)

Manual per-site migration. Mapping heuristic:

| blur | offset.dy | → |
|---|---|---|
| ≤ 5 | ≤ 3 | `elevationSm` |
| 6–12 | 4–6 | `elevationMd` |
| ≥ 13 | ≥ 7 | `elevationLg` |

Workflow per site:
```bash
# list sites
grep -rn "BoxShadow(" app/lib/presentation/
```
Open file, inspect the `BoxShadow(color:, blurRadius:, offset:)` call, replace with `boxShadow: context.elevationSm` (or Md/Lg). The enclosing `BoxDecoration` already has `boxShadow` — swap the `List<BoxShadow>` contents.

If a site uses multiple `BoxShadow` layers (Material "umbra + penumbra + ambient" pattern), pick the dominant one; note in commit message that we collapsed multi-layer shadow.

After all 9 sites migrated:
```bash
grep -rE "BoxShadow\(" app/lib/presentation/ | wc -l
# → 0
```
Regen goldens for files that changed — usually all pages containing the migrated widget show shadow shift in dark mode. Visually spot-check 3–5 dark PNGs.

Commit: `refactor(theme): migrate 9 BoxShadow sites to context.elevationX`

**Phase 3 — Migrate `Duration(milliseconds:)` → motion** (7 sites, ~10 min)

Sed for the two known unique values:
```bash
find app/lib/presentation -name "*.dart" -exec sed -i '' \
  -e 's/Duration(milliseconds: 200)/AppConstants.motionMedium/g' \
  {} \;
```

For `600ms` (1 site): inspect manually. If the 600ms is a deliberately long animation (e.g., page transition, dramatic reveal), keep as literal and add a `// Sprint 5A: kept literal — intentionally slower than motionSlow` comment. Otherwise migrate to `AppConstants.motionSlow` if 400ms looks acceptable on emulator.

Verify:
```bash
grep -rE "Duration\(milliseconds:" app/lib/presentation/ | grep -v "AppConstants\." | wc -l
# → ≤ 2
```

No golden regen needed (Duration doesn't render). Run `flutter analyze` + `flutter test`.

Commit: `refactor(theme): migrate Duration sites to AppConstants.motionX`

**Phase 4 — Migrate `BorderRadius.circular(N)` → radii** (93 sites, ~40 min)

Bulk sed per exact value:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app/lib/presentation
find . -name "*.dart" -exec sed -i '' \
  -e 's/BorderRadius\.circular(4)/BorderRadius.circular(AppConstants.radiusXs)/g' \
  -e 's/BorderRadius\.circular(6)/BorderRadius.circular(AppConstants.radiusSm)/g' \
  -e 's/BorderRadius\.circular(8)/BorderRadius.circular(AppConstants.radiusSm)/g' \
  -e 's/BorderRadius\.circular(10)/BorderRadius.circular(AppConstants.radiusMd)/g' \
  -e 's/BorderRadius\.circular(12)/BorderRadius.circular(AppConstants.radiusMd)/g' \
  -e 's/BorderRadius\.circular(16)/BorderRadius.circular(AppConstants.radiusLg)/g' \
  -e 's/BorderRadius\.circular(18)/BorderRadius.circular(AppConstants.radiusXl)/g' \
  -e 's/BorderRadius\.circular(20)/BorderRadius.circular(AppConstants.radiusXl)/g' \
  {} \;
```

**Do NOT sed `circular(1)` or `circular(2)`** — those are intentional near-zero radii (thin borders), keep as literals.

Rounding policy table (approved in brainstorm):

| Hardcode | Count | → Token | Shift |
|---|---|---|---|
| 2 | 8 | keep literal | — |
| 4 | 5 | `radiusXs` | 0 |
| 6 | 6 | `radiusSm` | +2 |
| 8 | 13 | `radiusSm` | 0 |
| 10 | 27 | `radiusMd` | +2 |
| 12 | 16 | `radiusMd` | 0 |
| 16 | 7 | `radiusLg` | 0 |
| 18 | 1 | `radiusXl` | +2 |
| 20 | 9 | `radiusXl` | 0 |
| 1 | 1 | keep literal | — |

Migrate `cardRadius` and `buttonRadius` deprecations:
```bash
find app/lib -name "*.dart" -exec sed -i '' \
  -e 's/AppConstants\.cardRadius\b/AppConstants.radiusLg/g' \
  -e 's/AppConstants\.buttonRadius\b/AppConstants.radiusLg/g' \
  {} \;
```

Remove the two constants from `app_constants.dart`:
```dart
// DELETE these two lines:
//   static const double buttonRadius = 14.0;
//   static const double cardRadius = 16.0;
```

Verify:
```bash
grep -rE "BorderRadius\.circular\([0-9]" app/lib/presentation/ | grep -v "AppConstants\." | wc -l
# → ≤ 2
grep -rE "cardRadius|buttonRadius" app/lib/
# → 0 matches
```

Regen all goldens (expect many pages to shift by 2px — visually imperceptible on mobile).

```bash
cd app && flutter test --update-goldens
flutter test  # all pass
```

Spot-check 5–10 dark goldens: confirm no visible layout breaks from the 2px shifts.

Commit: `refactor(theme): migrate 93 BorderRadius hardcodes to radii scale + deprecate cardRadius/buttonRadius`

**Phase 5 — Wrap-up** (~10 min)

- Final acceptance greps (see §1 acceptance block)
- Final `flutter analyze` → 0 issues
- Final `flutter test` → ~335 pass
- Append completion note to the plan file
- Commit: `docs(sprint-5a): mark design tokens expansion complete`

### 3.2 Golden regeneration strategy

Per phase:

| Phase | Expected visual change | Goldens action |
|---|---|---|
| 1 | None (only adding tokens) | none |
| 2 | BoxShadow blur/offset changes visible in dark mode | regen pages containing migrated shadow sites |
| 3 | None (Duration doesn't render) | none |
| 4 | ~40 sites shift by 2px | full regen after sed; spot-check 5–10 dark |
| 5 | None | none |

After Phase 4, use the Sprint 2/3 precedent for pixel non-determinism: if `flutter test` reports 0.01% diffs, regen from full-suite context once more.

---

## 4. Acceptance, Risks, Effort

### Sprint 5A DONE when

1. `AppConstants` has `radiusXs = 4`, `radiusXl = 20`, `radiusXxl = 24`, `motionFast`, `motionMedium`, `motionSlow`
2. `ThemeColors` has `elevationSm`, `elevationMd`, `elevationLg` + 3 new tests
3. `AppConstants.cardRadius` and `AppConstants.buttonRadius` are removed
4. `grep BorderRadius.circular([0-9]` in `lib/presentation/` returns ≤ 2 matches (1px, 2px literals)
5. `grep BoxShadow(` in `lib/presentation/` returns 0 matches
6. `grep Duration(milliseconds:` in `lib/presentation/` (outside `AppConstants.`) returns ≤ 2 matches
7. `flutter analyze` → 0 issues
8. `flutter test` → ~335 pass (332 existing + 3 new elevation tests)
9. 5 commits (one per phase) + final docs commit

### Metrics

| Metric | Before | After |
|---|---|---|
| Hardcoded `BorderRadius.circular(N)` in `lib/presentation/` | 93 | ≤ 2 |
| Hardcoded `BoxShadow` in `lib/presentation/` | 9 | 0 |
| Hardcoded `Duration(milliseconds:)` in `lib/presentation/` | 7 | ≤ 2 |
| Design tokens in `AppConstants` / `ThemeColors` | ~15 | ~24 (+9) |
| Total tests | 332 | ~335 |

### Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| `radiusXl` rename breaks code (24 → 20 shift) | **High** | Phase 1 renames ALL `radiusXl` → `radiusXxl` via sed FIRST, verifies 0 refs remain to old value, THEN adds new `radiusXl = 20` |
| 40 sites shift by 2px — visible regression | Low | 2px on mobile is imperceptible; golden review catches unintended cases |
| `buttonRadius = 14` → `radiusLg = 16` makes buttons look more rounded | Medium | Emulator spot-check after Phase 4; if regression → swap specific button to `radiusMd = 12` (2px less round) |
| `BoxShadow` heuristic (blur/offset → elevation) produces wrong tier | Medium | Per-site manual review of 9 sites; ambiguous cases default to `elevationMd` and flag in commit |
| Bulk sed corrupts unrelated strings containing `circular(N)` | Low | sed regex is specific to `BorderRadius.circular(N)` — no false positives expected |
| Golden regen triggers widespread pixel diffs | Medium | Regen per phase; commit goldens in same commit as code; use Sprint 2/3 precedent for non-determinism retry |
| `600ms` Duration is intentional (e.g., splash) — migrating breaks UX | Low | Phase 3 requires manual inspection of 600ms site; keep as literal with comment if intentional |

### Estimated effort

| Phase | Time |
|---|---|
| 1. Add tokens + rename `radiusXl` → `radiusXxl` | 15 m |
| 2. `BoxShadow` → elevations (9 sites, manual) | 20 m |
| 3. `Duration` → motion (7 sites) | 10 m |
| 4. `BorderRadius.circular` migration (93 sites) | 40 m |
| 5. Wrap-up | 10 m |
| **Total** | **~1.5 h** |

### Dependencies

Everything in place:
- `ThemeColors` extension (Sprint 1)
- `shadowColor` getter (Sprint 2.5)
- `AppConstants` scale pattern (pre-existing)
- `golden_toolkit` infra

### Deferred work

- **Sprint 5B:** WCAG AA accessibility audit (contrast, touch targets, semantic labels)
- **Sprint 6+:** Typography scale tokens (only if surfaced during 5A)
- **Sprint 6+:** `spacing*` token migration (already consistent — low priority)

---

## 5. Next Step

After approval, invoke `superpowers:writing-plans` to generate the implementation plan at `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5a-design-tokens.md`.
