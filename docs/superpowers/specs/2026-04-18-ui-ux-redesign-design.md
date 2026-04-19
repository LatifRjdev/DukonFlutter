# Dukon UI/UX Redesign — Design Spec

**Date:** 2026-04-18
**Status:** Approved
**Preview mockups:** `.superpowers/brainstorm/*/content/`

---

## Context

Real-device screenshots revealed a broken visual state: partially applied dark mode, unreadable grey-on-grey text, inconsistent theme application across screens. Root cause audit found:

1. `app.dart:68` hardcodes `ThemeMode.light` — SettingsBloc theme preference is ignored
2. 102 files reference light-only color tokens (`AppColors.lightBackground`, `lightTextSecondary`) — won't adapt to dark mode
3. `GlassCard` renders dark glassmorphism even in light mode → dark cards on light scaffold = unreadable

This spec defines a complete visual overhaul: fix theme infrastructure, establish a unified design system, apply the new language to all screens.

## Design Decisions (approved via visual companion)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Theme strategy | Both light + dark fully work | Infrastructure exists; user picks in settings |
| Light card style | **Accent Borders** — white cards, colored `border-left: 3px`, soft shadow | Sbalanced: readable, energetic, not noisy |
| Dark card style | **Glass only** — `backdrop-blur` + purple tint + white border | Glass is premium in dark, becomes dirty in light |
| Typography | **Plus Jakarta Sans** (Display/Title/Body/Label/Caption/Tabular) | UI/UX Pro Max recommendation for B2B productivity mobile |
| Section headers | Label + "Все ›" link — uppercase 11pt `primary` + right-aligned link | Modern, compact, discoverable navigation |
| Bottom nav | 5 tabs with FAB-like Касса in center (gradient + glow) | Highlights primary POS action (like Revolut Pay) |
| Dark base | Deep purple-black `#0F0A1A` (NOT pure `#000000`) + 2-3 ambient violet blobs | Prevents OLED smear; adds atmosphere (Modern Dark Cinema) |

## Design Tokens

### Light Theme

```
/* Brand */
--color-primary:        #6366F1  /* indigo-500 */
--color-primary-hover:  #5A5EEB
--color-secondary:      #8B5CF6  /* violet-500, gradient partner */
--color-gradient:       linear-gradient(135deg, #6366F1, #8B5CF6)

/* Semantic accents */
--color-success:        #10B981  /* emerald-500 — income, OK */
--color-danger:         #EF4444  /* red-500 — expenses, delete */
--color-warning:        #F59E0B  /* amber-500 — attention */
--color-info:           #3B82F6  /* blue-500 — neutral info */

/* Surfaces */
--color-background:     #F4F0FA  /* lilac tint scaffold */
--color-surface:        #FFFFFF  /* card background */
--color-muted:          #F9F5FC  /* secondary surface */
--color-border:         #E8E0F0  /* thin dividers */

/* Text */
--color-text-primary:   #1E1B4B  /* slate-900 w/ violet tint */
--color-text-secondary: #64748B  /* slate-500 */
--color-text-muted:     #94A3B8  /* slate-400 */

/* Accent tints (for icon backgrounds) */
--color-primary-tint:   #EDE9FE  /* violet-100 */
--color-success-tint:   #D1FAE5  /* emerald-100 */
--color-danger-tint:    #FEE2E2  /* red-100 */
--color-warning-tint:   #FEF3C7  /* amber-100 */
--color-info-tint:      #DBEAFE  /* blue-100 */

/* Elevation */
--shadow-sm:  0 2px 8px rgba(99, 102, 241, 0.06)
--shadow-md:  0 4px 14px rgba(99, 102, 241, 0.10)
--shadow-fab: 0 6px 16px rgba(99, 102, 241, 0.35)
```

### Dark Theme (Glass)

```
/* Brand — lighter for dark contrast */
--color-primary:        #818CF8  /* indigo-400 */
--color-secondary:      #A78BFA  /* violet-400 */
--color-gradient:       linear-gradient(135deg, #818CF8, #A78BFA)

/* Semantic accents */
--color-success:        #34D399  /* emerald-400 */
--color-danger:         #F87171  /* red-400 */
--color-warning:        #FBBF24  /* amber-400 */
--color-info:           #60A5FA  /* blue-400 */

/* Surfaces */
--color-background:     #0F0A1A  /* deep purple-black, NOT #000 */
--color-surface:        #1A1128  /* solid card base */
--color-glass-surface:  rgba(139, 92, 246, 0.08)  /* glass tint */
--color-glass-border:   rgba(255, 255, 255, 0.12) /* glass edge */
--backdrop-blur:        blur(10px)

/* Text */
--color-text-primary:   #F0ECF8
--color-text-secondary: #C4B5FD  /* violet-300 for softer hierarchy */
--color-text-muted:     #A09CB0

/* Ambient decoration */
--ambient-blob-1:       rgba(139, 92, 246, 0.25)  /* violet */
--ambient-blob-2:       rgba(99, 102, 241, 0.20)  /* indigo */
/* 2-3 blobs, 240-260px, filter: blur(40px), positioned absolute */
```

### Typography (Plus Jakarta Sans)

| Role | Size | Weight | Usage |
|------|------|--------|-------|
| Display | 28pt | 800 | Screen title hero |
| Title | 20pt | 700 | Section titles |
| Body L | 16pt | 500 | Primary text, button labels |
| Body | 14pt | 400 | Secondary text, descriptions |
| **Label** | **11pt** | **700, uppercase, +1px letter-spacing** | **Section headers ("БЫСТРЫЕ ДЕЙСТВИЯ")** |
| Caption | 12pt | 500 | Metadata, timestamps |
| Tabular | any | 700 + `fontFeatures: 'tnum'` | Money amounts (prevents shift) |

Line height: 1.4 for titles, 1.5 for body, 1.3 for labels.

### Shape & Spacing

```
/* Radius */
--radius-xs:  8px   /* chips, tiny elements */
--radius-sm:  10px  /* icon backgrounds */
--radius-md:  14px  /* default cards */
--radius-lg:  18px  /* hero cards */
--radius-xl:  24px  /* header bottom corners */

/* Spacing scale (4pt base) */
--space-1: 4px
--space-2: 8px
--space-3: 12px
--space-4: 16px  /* default gap */
--space-5: 20px
--space-6: 24px
--space-8: 32px
```

## Component Specifications

### 1. KPI Card (dashboard metrics)

```
Structure:
  Container (surface, radius-md, padding 14px, shadow-sm)
  Border-left: 3px solid [accent-color]
    ├── Value: 20pt Bold (800), text-primary — tabular-nums for money
    └── Label: 12pt Medium (500), text-secondary

Accent colors by metric:
  primary  → Продажи (main income)
  success  → Чистая прибыль, positive deltas
  neutral  → Себестоимость (slate)
  danger   → Расходы (prefix with ↓ arrow)
  warning  → Alerts, low stock
```

Dark mode: same structure, but container uses `glass-surface` background + `backdrop-blur` + `glass-border`.

### 2. Quick Action Card (home screen, finance sections)

```
Structure:
  Container (surface, radius-md, padding 14px, shadow-sm)
    ├── Icon container (36×36, radius-sm, tinted background)
    │     └── Icon (SVG from Lucide, matches tint color)
    ├── Label: 11pt Bold (700), text-primary
    └── Sub-label: 10pt Regular (500), text-secondary (optional)
```

Tint + icon color mapping:
- `primary-tint` + `primary` → inventory, configuration
- `danger-tint` + `danger` → debts owed (vendor), expenses
- `success-tint` + `success` → customer debts, income
- `warning-tint` + `warning` → alerts, credits
- `info-tint` + `info` → currencies, reports

### 3. Section Header

```
Structure:
  Row (space-between, baseline)
    ├── Label: 11pt Bold (700), uppercase, letter-spacing 1px, color primary
    └── Link: 12pt Semibold (600), color primary, content "Все ›" (optional)
```

Used above lists. If the section has no "see more" destination, omit the link.

### 4. Gradient Header (top of home/finance)

```
Structure:
  Container (gradient, padding 40/20/16, bottom-radius 24)
    ├── Row (top, space-between)
    │     ├── Left
    │     │     ├── Greeting: 12pt, opacity 0.85 ("Салом 👋")
    │     │     └── Store name: 17pt Bold, white
    │     └── Right actions (8px gap)
    │           ├── Notification button: 38×38, rgba(255,255,255,0.2), radius 12
    │           └── Avatar: 38×38, rgba(255,255,255,0.25), initials bold
    └── Store selector: 12px marginTop
          rgba(255,255,255,0.15) background, radius 12, padding 11/14
          ├── Icon + store name (13pt)
          └── Chevron down
```

Dark mode: same colors (gradient remains), opacity adjusted to 0.2/0.25 already works on dark.

### 5. Bottom Navigation

```
Structure:
  Row (surface, border-top, padding 6/4/18, space-around)
    5 items:
      [Главная] [Товары] [КАССА-FAB] [Финансы] [Ещё]

  Regular item:
    Column, centered, gap 2
    ├── Icon: 20pt, color text-muted (default) or primary (active)
    └── Label: 9pt, weight 600, same color

  FAB (Касса):
    52×52, radius 16, gradient, shadow-fab
    margin-top: -20 (floats above nav)
    Icon: 22pt white
    Dark mode: adds 0 0 30px glow effect
```

### 6. Empty State

```
Structure:
  Container (surface, radius-md, padding 30/20, shadow-sm, centered)
    ├── Icon: 32pt emoji or outline SVG, opacity 0.4
    └── Text: 13pt, color text-muted
```

### 7. Product List Item

```
Structure:
  Card (surface, radius-md, padding 12, shadow-sm, flex row, gap 12)
    ├── Image (48×48, radius-sm, gradient bg for emoji fallback)
    ├── Info (flex-1, min-width 0)
    │     ├── Name: 14pt Bold, ellipsis overflow
    │     └── Meta: 11pt, text-secondary ("barcode · category")
    └── Price column (right-aligned)
          ├── Price: 14pt Bold, tabular-nums
          └── Stock: 11pt Bold, colored by availability
                • ok (green), • low (amber), • out (red) prefixed with bullet dot
```

### 8. POS Cart Item

Same as product list item but with:
- Quantity stepper on right instead of price column
- Stepper: pill container (muted bg, radius 8, padding 2)
- ± buttons: 24×24, white, radius 6, color primary
- Quantity value: 13pt Bold, 8px horizontal padding

Footer (sticky bottom):
- "Итого" label + big total (24pt Bold, tabular-nums)
- Gradient CTA button (full width, radius 14, shadow-fab)

### 9. Sale Success Hero

```
Container (gradient success→success-dark, radius-lg, padding 24, centered)
  ├── Icon circle: 64×64, white/20 bg, radius 50%, ✓ 32pt
  ├── Title: 20pt Bold ("Продажа завершена")
  └── Sub: 13pt, opacity 0.9 (receipt #, date, time)
```

## Screen-Level Applications

### Home Dashboard

Layout top-to-bottom:
1. Gradient header (greeting, actions, store selector)
2. Period tabs (Сегодня / Неделя / Месяц / calendar icon)
3. KPI grid 2×2 (Продажи / Прибыль / Себестоимость / Расходы — with accent borders)
4. Section: "БЫСТРЫЕ ДЕЙСТВИЯ" label → 3-column quick action cards (Остатки / Долги пост. / Долги клиен.)
5. Section: "ПОСЛЕДНИЕ ПРОДАЖИ" label + "Все ›" link → sale rows OR empty state
6. Bottom nav with FAB

### Products List

1. Simple app bar (back button, "Товары", menu action)
2. Search bar with scan icon right
3. Filter chips (Все / В наличии / Заканчивается / Нет)
4. Product list items
5. FAB (+) above bottom nav
6. Bottom nav

### POS Checkout

1. Header: search bar with scan icon + "КОРЗИНА · N ТОВАРОВ" label
2. Scrollable cart item list
3. Sticky bottom total + gradient CTA

### Finance Dashboard

1. Simple app bar
2. Finance hero card (gradient, "Баланс магазина" label + value + today delta)
3. Section "РАЗДЕЛЫ"
4. 2×3 grid of finance tiles (Баланс / Кредиты / Вложения / Валюты / Расходы / Отчёты)
   - Each tile: icon-left + 2-line text
   - Icon tint matches semantic (primary/warning/success/info/danger/neutral)

### Sale Success

1. Simple app bar (no back, close X on right)
2. Green gradient success hero
3. Receipt card: section label "СОСТАВ ЧЕКА" + item rows + dashed-border total row
4. Payment card: type / received / change (change in green)
5. Action buttons: [Telegram secondary] [Печать primary gradient]

## Architecture

### Theme Infrastructure Fix

**Root cause:** `app.dart:68` hardcodes `themeMode: ThemeMode.light`.

**Fix:**
```dart
// BEFORE:
return MaterialApp.router(
  ...
  themeMode: ThemeMode.light,
);

// AFTER (inside BlocBuilder<SettingsBloc, SettingsState> with buildWhen for theme):
return MaterialApp.router(
  ...
  themeMode: state is SettingsLoaded ? state.themeMode : ThemeMode.system,
);
```

The `BlocBuilder` already exists (from previous fix) but currently always returns `ThemeMode.system` fallback — connect it to `state.themeMode`.

### GlassCard Fix

**File:** `app/lib/presentation/widgets/common/glass_card.dart`

Currently always renders dark glassmorphism. Fix: check `Theme.of(context).brightness` and render:
- Light: solid white surface + shadow-sm + optional border-left accent (new prop `accentColor`)
- Dark: glass surface with backdrop-blur + white border

Add `accentColor` optional parameter to support KPI card border-left pattern.

### Color Token Migration

**Problem:** 102 files use `AppColors.lightBackground`, `lightSurface`, `lightTextSecondary` directly.

**Solution:** Introduce theme-aware extension methods.

Add `app/lib/core/theme/theme_extensions.dart`:
```dart
extension ThemeColors on BuildContext {
  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  Color get surface => Theme.of(this).cardColor;
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).textTheme.bodyMedium!.color!;
  Color get primary => Theme.of(this).colorScheme.primary;
  Color get success => Theme.of(this).brightness == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF10B981);
  Color get danger => Theme.of(this).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
  // ... etc
}
```

Then migration: `AppColors.lightBackground` → `context.bg`, `AppColors.lightTextSecondary` → `context.textSecondary`, etc.

`AppTheme.light` and `AppTheme.dark` already define the correct colors in `ThemeData` — so `Theme.of(context)` returns correct values. We just need widgets to ask the theme, not hardcoded AppColors.

Keep `AppColors` as raw design tokens (useful for gradients, specific accent usage), but remove direct usage of `light*` / `dark*` variants in widgets.

### New Shared Widgets

1. `KpiCard` — accent-border metric card (replaces inline KPI code)
2. `QuickActionCard` — standardized quick action with icon tint
3. `SectionHeader` — label + optional "Все ›" link
4. `EmptyStateCard` — icon + message centered card
5. `GradientCta` — primary button with gradient + shadow-fab

Put them in `app/lib/presentation/widgets/common/`.

## Scope Decomposition

This is a large refactor (102 files touched). Split into 3 implementation plans, each a working increment:

### Sprint 1: Theme Foundation (blocks everything)
- Fix `app.dart` to read SettingsBloc theme state
- Fix `GlassCard` to branch by brightness, add `accentColor` prop
- Add `theme_extensions.dart` with context getters
- Update `AppTheme.light` / `AppTheme.dark` to include new semantic colors
- Add Plus Jakarta Sans font to pubspec and register in ThemeData
- Outcome: theme toggle works, existing screens don't visually change yet

### Sprint 2: Core Screens Redesign
- Create `KpiCard`, `QuickActionCard`, `SectionHeader`, `EmptyStateCard`, `GradientCta` widgets
- Rebuild: `dashboard_page.dart`, `finance_dashboard_page.dart`, `product_list_page.dart`, `pos_checkout_page.dart`, `sale_success_page.dart`, `more_page.dart`, `settings_page.dart`
- Migrate hardcoded colors in these screens to `context.xxx` getters
- Outcome: main user-facing screens look like mockups

### Sprint 3: Full Migration
- Remaining ~95 files: replace `AppColors.lightBackground` → `context.bg` etc.
- Audit every screen for readable contrast in both themes
- Run full app in both light + dark on real device for visual QA
- Outcome: entire app is consistent, dark mode is readable everywhere

## Acceptance Criteria

### Sprint 1
- [ ] Toggle dark mode in Settings → entire app switches themes
- [ ] Light mode: no dark glass cards on light screens
- [ ] Dark mode: no light surfaces on dark screens
- [ ] Plus Jakarta Sans loads and is default font

### Sprint 2
- [ ] Home dashboard matches `full-design-preview.html` mockup
- [ ] Products list matches `screens-showcase.html` mockup
- [ ] POS checkout matches mockup
- [ ] Finance dashboard matches mockup
- [ ] Sale success matches mockup
- [ ] All section headers use uppercase label + optional "Все ›" pattern
- [ ] Касса tab in bottom nav is a FAB with gradient + shadow

### Sprint 3
- [ ] `grep -r "AppColors.light" app/lib/presentation` returns 0 hits (except intentional gradient definitions)
- [ ] All text meets WCAG AA contrast (4.5:1) in both themes
- [ ] No "coming soon" placeholders or unreadable grey-on-grey text
- [ ] Visual QA pass on real Android device in both light + dark

## Out of Scope

- New features (only visual refresh + theme fix)
- Changes to navigation structure (5 tabs stay)
- Icon library swap (continue with current icons; can revisit later)
- Animation overhaul (micro-interactions stay as-is, can polish in a later sprint)
- Tablet-specific layouts (app is phone-only for now)

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Plus Jakarta Sans download fails offline | Bundle fonts via `flutter_fonts` assets, not Google Fonts CDN |
| Widgets using `AppColors.light*` miss migration → dark mode leaks white | Sprint 3 grep audit + full-screen QA on device |
| `context.textPrimary` throws if used above MaterialApp | Use only inside widget `build` method with valid theme in context |
| Glass backdrop-blur performance on low-end Android | Test on 2020-era device; fall back to solid `color-surface` if FPS drops |
| User preference lost between session restarts | Confirm `SettingsBloc` persists `theme_mode` to SharedPreferences on every change |
