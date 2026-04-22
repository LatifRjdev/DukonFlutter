# Sprint 2 — Page Theme Migration Design

**Date:** 2026-04-19
**Status:** Approved — ready for plan
**Depends on:** Sprint 1 Theme Foundation (complete, commits `cbd0cce` → `c7d2f66`)
**Related spec:** [2026-04-18 UI/UX Redesign Design](2026-04-18-ui-ux-redesign-design.md)

---

## 1. Overview & Scope

### Goal
Migrate every page in `lib/presentation/pages/**/*.dart` from hardcoded `AppColors.light*` / `AppColors.dark*` references to theme-aware `context.*` getters, so that the app-wide dark mode toggle (wired in Sprint 1) visually applies to every screen — not just the few that happen to inherit the Theme.

### Problem statement
Sprint 1 shipped the theme infrastructure: `AppTheme.light` / `AppTheme.dark`, `ThemeColors` extension on `BuildContext`, `SettingsBloc` → `MaterialApp.themeMode` binding, and the cached-router fix. Verified on `MorePage`, which correctly flips to dark (`#0F0A1A` background, light text) when the user toggles dark mode.

However, **33 pages hardcode `Scaffold(backgroundColor: AppColors.lightBackground)`** and **70 files total** reference `AppColors.light*` / `AppColors.dark*` directly. These pages ignore the MaterialApp-level theme, so dark mode currently looks broken (e.g., Dashboard stays light while More goes dark).

Sprint 2 closes this gap for all pages.

### In scope
- All files in `lib/presentation/pages/**/*.dart` (~70 files across 21 feature folders)
- Mechanical substitutions of the form `AppColors.lightBackground` → `context.bg`, etc. (full mapping in §4)
- Removing `const` from `Scaffold` and its direct theme-dependent children where necessary
- Replacing `static const _color = AppColors.lightX` fields with helper methods taking `BuildContext`
- Golden tests per page (light + dark) — 140 goldens total
- Manual verification on emulator per migrated folder

### Out of scope (deferred)
- **Sprint 3:** `lib/presentation/widgets/**` (shared components)
- **Sprint 3:** theme-aware bottom sheets, dialogs, snackbars
- **Sprint 4:** new design tokens (if needed)
- **Separate sprint:** accessibility / contrast audit
- `lib/core/`, `lib/data/`, `lib/domain/` — no UI or already migrated

### Sprint-level acceptance
```
grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" lib/presentation/pages
# must return 0 matches
```

---

## 2. Migration Priority & Per-Folder Workflow

### Priority order (5 phases by user visibility)

| Phase | Folders | Rationale |
|---|---|---|
| **Phase 1 — Core nav** | `dashboard`, `product`, `pos`, `finance`, `settings` | Five bottom-nav tabs = 90% of user-facing surface |
| **Phase 2 — Sales ops** | `customer`, `supplier`, `sales`, `notifications` | Reached via clicks from main tabs |
| **Phase 3 — Finance ops** | `debt`, `payroll`, `zakat` | Sub-screens under Finance tab |
| **Phase 4 — Catalog ops** | `stock`, `inventory`, `delivery` | Operational screens under Product |
| **Phase 5 — Admin & edge** | `auth`, `onboarding`, `store`, `roles`, `shifts`, `staff` | Rarely opened; low-risk tail |

### Per-folder workflow

For each folder, apply this sequence:

1. Enumerate files: `ls lib/presentation/pages/<folder>/*.dart`
2. Audit scope per file: `grep -c "AppColors\.light" <file>` to estimate work
3. For each file, apply migration rules from §4:
   - Replace `AppColors.lightX` with `context.X`
   - Remove `const` from `Scaffold` if it blocks `context` access
   - Replace `static const _color` with a helper method taking `BuildContext`
   - Leave `const Icon(..., color: AppColors.primary)` alone (primary is theme-neutral)
4. Run `flutter analyze lib/presentation/pages/<folder>` — must be clean
5. Run existing golden tests for that folder — they will fail (expected; goldens predate migration)
6. Regenerate goldens: `flutter test --update-goldens test/presentation/pages/<folder>/`
7. Visually review the new goldens (diff vs old) — confirm dark mode renders correctly
8. Hot restart emulator; navigate to the folder's screens in both themes; eyeball sanity check
9. Commit: `feat(theme): migrate <folder> pages to theme-aware colors`

### Between phases
Merge or rebase `feat/sprint-2-theme-migration` branch often. Re-run `flutter analyze` and a smoke test of previously migrated phases to catch regressions.

---

## 3. Golden Test Infrastructure

### File layout

```
test/
├── helpers/
│   └── golden_pump_helper.dart       # shared pump harness
├── fixtures/
│   └── mock_blocs.dart                # centralized bloc mocks
└── presentation/
    └── pages/
        ├── dashboard/
        │   ├── dashboard_page_golden_test.dart
        │   └── goldens/
        │       ├── dashboard_light.png
        │       └── dashboard_dark.png
        ├── product/
        │   ├── product_list_page_golden_test.dart
        │   └── goldens/…
        └── …
```

### Shared pump helper (`test/helpers/golden_pump_helper.dart`)

```dart
Future<void> pumpPageWithTheme(
  WidgetTester tester,
  Widget page, {
  required Brightness brightness,
  List<SingleChildWidget> providers = const [],
  Size size = const Size(390, 844), // iPhone 13 logical size
}) async {
  await tester.binding.setSurfaceSize(size);
  await loadAppFonts(); // from golden_toolkit; loads bundled Plus Jakarta Sans
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: providers,
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

### Test template (one per page, both themes)

```dart
void main() {
  group('DashboardPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        const DashboardPage(),
        brightness: Brightness.light,
        providers: [mockStoreBloc(), mockDashboardBloc()],
      );
      await screenMatchesGolden(tester, 'dashboard_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        const DashboardPage(),
        brightness: Brightness.dark,
        providers: [mockStoreBloc(), mockDashboardBloc()],
      );
      await screenMatchesGolden(tester, 'dashboard_dark');
    });
  });
}
```

### Decisions

| Decision | Choice | Reason |
|---|---|---|
| Golden library | `golden_toolkit: ^0.15.0` | Industry standard, bundled-font support |
| Screen size | 390×844 (iPhone 13 logical) | Matches mobile-first design reference |
| Mock strategy | Centralized in `test/fixtures/mock_blocs.dart` | DRY; mocks reused across pages |
| Count | ~70 pages × 2 themes = 140 PNGs | Acceptable repo footprint (~5-7 MB) |
| CI behavior | Goldens fail the build on diff | That's the regression signal |
| Regen command | `flutter test --update-goldens <path>` | Standard flutter workflow |

### Edge case — async data
Pages loading from API: mocks return empty/loading state so goldens are deterministic. Avoid goldens that depend on a network-ready backend.

---

## 4. Migration Rules & Color Mapping

### Rule 1 — Scaffold level (strict)

```dart
// ❌ FORBIDDEN after Sprint 2
return const Scaffold(
  backgroundColor: AppColors.lightBackground,
  ...
);

// ✅ REQUIRED
return Scaffold(
  backgroundColor: context.bg,
  ...
);
```
Dropping `const` on `Scaffold` has negligible perf cost — it rebuilds on theme change anyway.

### Rule 2 — Deep widgets

```dart
// ⚠️ ACCEPTABLE — keeps const, loses slight dark-mode contrast
// (dark theme would ideally use AppColors.primaryDark for +1 shade lighter indigo)
const Icon(Icons.check, color: AppColors.primary)

// ✅ PREFERRED — theme-aware at Scaffold / AppBar / top-level children
Icon(Icons.check, color: context.primary)

// ❌ FORBIDDEN — lightTextPrimary varies by theme and has no const equivalent
const Icon(Icons.check, color: AppColors.lightTextPrimary)

// ✅ Post-migration
Icon(Icons.check, color: context.textPrimary)
```

**Policy:** at Scaffold / AppBar / top-level widgets, prefer `context.primary`. Deep inside a list item or a `const Icon`, `AppColors.primary` is acceptable — the contrast delta between `primary` (indigo-500) and `primaryDark` (indigo-400) is small enough that visual reviewers won't reject it.

### Rule 3 — `static const` color fields

```dart
// ❌ FORBIDDEN
class _MyPageState extends State<MyPage> {
  static const _cardColor = AppColors.lightSurface;
  ...
}

// ✅ Replace with a helper method
class _MyPageState extends State<MyPage> {
  Color _cardColor(BuildContext context) => context.surface;
  ...
}
```

### Rule 4 — Local `ThemeData` overrides

Rare. If a page constructs its own `ThemeData(...)`, remove the local override; inherit the MaterialApp theme instead.

### Rule 5 — Computed / conditional colors

```dart
// Example: progress bar color by value
final color = progress > 0.8
  ? AppColors.success
  : progress > 0.5
    ? AppColors.warning
    : AppColors.error;

// Post-migration (uses semantic tokens that adapt per theme)
final color = progress > 0.8
  ? context.success
  : progress > 0.5
    ? context.warning
    : context.danger;
```

### Color mapping table

| Old reference | New reference | Notes |
|---|---|---|
| `AppColors.lightBackground` | `context.bg` | |
| `AppColors.lightSurface` | `context.surface` | |
| `AppColors.lightSurfaceElevated` | `context.surfaceMuted` | |
| `AppColors.lightBorder` | `context.border` | |
| `AppColors.lightTextPrimary` | `context.textPrimary` | |
| `AppColors.lightTextSecondary` | `context.textSecondary` | |
| `AppColors.lightTextHint` | `context.textMuted` | |
| `AppColors.success` | `context.success` | When used as semantic foreground |
| `AppColors.error` | `context.danger` | |
| `AppColors.warning` | `context.warning` | |
| `AppColors.info` | `context.info` | |
| `AppColors.primary` | `context.primary` at Scaffold level; **acceptable to keep** in deep `const` widgets | `AppColors.primary` (indigo-500) vs `AppColors.primaryDark` (indigo-400) — small contrast delta; migrate where context is available, tolerate const |
| `AppColors.secondary` | `context.secondary` at Scaffold level; **acceptable to keep** in deep `const` widgets | Same principle as primary |
| `AppColors.successBg` / `errorBg` / `warningBg` / `infoBg` | **unchanged (for now)** | Tinted backgrounds need both variants; deferred to Sprint 3 |
| `AppColors.gradientStart` / `gradientMid` / `gradientEnd` | **unchanged** | Brand gradient; same in both themes |
| `Color(0xFF…)` literals | case-by-case | Brand-neutral → keep; semantic → migrate |

---

## 5. Acceptance Criteria, Risks, Effort

### Sprint 2 Done When

1. `grep -rE "AppColors\.(light|dark)(Background|Surface|Border|Text)" lib/presentation/pages` returns **0 matches**
2. `flutter analyze` is clean (0 errors, 0 warnings introduced by this sprint)
3. All golden tests pass: `flutter test test/presentation/pages/` — 140 goldens
4. Manual smoke test on Android emulator:
   - Open app → 5 main tabs in light theme → no visual regressions
   - Toggle to dark → all 5 tabs flip to dark (`#0F0A1A` bg, light text)
   - Hot restart → dark persists (SettingsBloc reads from storage)
   - Toggle to light → all 5 tabs flip back to light
5. One commit per folder: `feat(theme): migrate <folder> pages to theme-aware colors`
6. Final commit: `docs: mark Sprint 2 theme migration complete` updating the Sprint 2 plan

### Metrics

| Metric | Before | After |
|---|---|---|
| `AppColors.lightX` refs in `pages/` | 96 | 0 |
| `AppColors.darkX` refs in `pages/` | 0 | 0 (must not appear) |
| Golden PNGs in repo | 0 | ~140 |
| Repo size delta | — | ~5–7 MB |

### Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Golden tests flaky due to async data or font loading | Medium | `pumpAndSettle` + mocked blocs + `loadAppFonts()` from `golden_toolkit` |
| `const` removal triggers perf regression | Low | Profile on emulator after each phase; check FPS on scroll-heavy lists |
| `AppColors.error` ≠ `context.danger` visually somewhere | Low | Mapping table pre-approved; goldens catch any regression |
| Golden reference size doesn't match real Android device | Medium | Goldens run on fixed canvas in Linux CI, not a real device — acceptable tradeoff |
| Plus Jakarta Sans not rendering in golden tests | Medium | `loadAppFonts()` from `golden_toolkit` bundles fonts for test environment |
| Large pages (`settings_page.dart` ~500+ lines) break after const changes | Medium | File-by-file migration; `flutter analyze` after each file |
| Concurrent PRs conflict with migration | Medium | Sprint completed in 1–2 focused days on `feat/sprint-2-theme-migration`; frequent rebase |

### Estimated Effort

| Phase | Folders | Files (approx) | Effort |
|---|---|---|---|
| Phase 1 — Core nav | 5 | ~20 | 4–5 h + goldens |
| Phases 2–5 | 16 | ~50 | 6–8 h + goldens |
| **Total** | **21** | **~70** | **10–13 h focused work** |

### Dependencies

- Add `golden_toolkit: ^0.15.0` to `pubspec.yaml` dev_dependencies if not already present
- No new API surface in `theme_extensions.dart` — Sprint 1 covers all required getters

### Deferred Work (explicit)

- `lib/presentation/widgets/**` shared components → **Sprint 3**
- Theme-aware bottom sheets, dialogs, snackbars → **Sprint 3**
- New design tokens, if any surface during migration → **Sprint 4**
- Accessibility / contrast audit → separate sprint

---

## 6. Next Step

After this spec is approved by the user, invoke `superpowers:writing-plans` to generate the Sprint 2 implementation plan at `docs/superpowers/plans/2026-04-19-ui-ux-sprint-2-page-theme-migration.md`.
