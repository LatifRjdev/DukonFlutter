# Sprint 5B.2.a — Semantic Labels (Critical Paths) Design

**Date:** 2026-04-21
**Status:** Approved — ready for plan
**Depends on:** Sprint 5B.1 Accessibility Quick Wins (complete, commits `9af8e50` → `cff5452`)
**Related specs:**
- [Sprint 5B.1 — Quick Wins](2026-04-21-ui-ux-sprint-5b-1-a11y-quick-wins-design.md)
- Sprint 5B.2.b (planned): Semantic labels for secondary paths
- Sprint 5B.2.c (planned): Live regions + SnackBar announcements

---

## 1. Overview & Scope

### Goal
Add accessibility labels to interactive widgets on the app's four critical user paths — authentication, bottom navigation, checkout, and product CRUD — so that TalkBack (Android) and VoiceOver (iOS) announce each control correctly. Labels are hardcoded Russian strings; localization to `ru/tg/uz` is deferred to Sprint 6.

### Problem statement
Sprint 5B.1 closed the visual-accessibility gaps (contrast, font size, touch targets). Screen reader coverage is still zero:

- `grep -rc "Semantics(" app/lib/presentation/` → **0**
- `grep -rc "semanticLabel:" app/lib/presentation/` → **0**
- Only 6 of 63 `IconButton` sites have `tooltip:` (which also provides a screen-reader label)

Without labels, a user with TalkBack hears "button" or "image" for every icon-only control. Sprint 5B.2.a fixes this for the 15 critical-path pages first (~55 widgets, hardcoded Russian). Sprint 5B.2.b extends to secondary paths; Sprint 5B.2.c handles live regions for dynamic state.

### In scope — 4 critical path clusters (16 files, ~55 labels)

**Auth (5 pages)**
- `app/lib/presentation/pages/auth/login_page.dart`
- `app/lib/presentation/pages/auth/register_page.dart`
- `app/lib/presentation/pages/auth/otp_page.dart`
- `app/lib/presentation/pages/auth/forgot_password_page.dart`
- `app/lib/presentation/pages/auth/create_password_page.dart`

Targets: password-visibility toggle buttons, "Забыли пароль?" link, close / back icons where present. AppBar auto-back button inherits "Назад" from `MaterialLocalizations` — no change needed.

**Bottom nav (1 widget)**
- `app/lib/presentation/widgets/common/app_bottom_nav_bar.dart`

Each of 5 tabs gets `Semantics(label, selected, button: true)`.

**Checkout (5 pages)**
- `app/lib/presentation/pages/pos/pos_checkout_page.dart`
- `app/lib/presentation/pages/pos/cash_payment_page.dart`
- `app/lib/presentation/pages/pos/credit_sale_page.dart`
- `app/lib/presentation/pages/pos/receipt_preview_page.dart`
- `app/lib/presentation/pages/pos/sale_success_page.dart`

Targets: cart quantity +/- buttons, payment method tiles, primary "Оплатить наличными" / "Продажа в долг" CTAs, receipt "Поделиться" / "Печать" actions, "Новая продажа" FAB.

**Product CRUD (5 pages)**
- `app/lib/presentation/pages/product/product_list_page.dart`
- `app/lib/presentation/pages/product/product_detail_page.dart`
- `app/lib/presentation/pages/product/add_product_step1_page.dart`
- `app/lib/presentation/pages/product/add_product_step2_page.dart`
- `app/lib/presentation/pages/product/add_product_step3_page.dart`

Targets: "Добавить товар" FAB, search / filter / barcode scanner triggers, edit/delete IconButtons, image upload, category picker, wizard step controls, "Сохранить" CTA.

### Out of scope (later sprints)

- **Sprint 5B.2.b:** secondary paths — finance, settings, admin, customer, supplier, shifts, staff, notifications, zakat, delivery (~55 more widgets)
- **Sprint 5B.2.c:** live regions for SnackBar announcements (95 existing sites), dynamic state changes (cart total updates, order state)
- **Sprint 6:** localization — move hardcoded Russian labels to `AppLocalizations` `.arb` files across ru/tg/uz
- Form field labels — already auto-provided by Material's `InputDecoration(labelText:)` and `TextFormField` — no fix needed
- AppBar auto-back button — already handled by Flutter; no fix needed

### Sprint-level acceptance

```bash
cd /Users/latifrjdev/Downloads/Dukon/app

# Baseline was 0 both
grep -rc "Semantics(" lib/presentation/ | awk -F: '{sum+=$2}END{print sum}'
# Expected: ≥25 (new wrappers for custom tappables in critical paths)

grep -rc "tooltip:" lib/presentation/ | awk -F: '{sum+=$2}END{print sum}'
# Expected: ≥30 (6 existing + 24+ new IconButton tooltips across 15 pages + 1 widget)

# Critical-path test file exists and passes
flutter test test/presentation/a11y/critical_paths_semantics_test.dart
# Expected: 10/10 pass

# Full suite
flutter analyze     # 0 issues
flutter test        # ~367 pass (357 existing + 10 new semantic tests)
```

Touch target acceptance from Sprint 5B.1 must still hold (44×44 dp not regressed).

---

## 2. Label API Patterns

Three patterns cover all ~55 sites. No new packages needed — `Semantics`, `ExcludeSemantics`, `tooltip:` all come from `package:flutter/material.dart` already imported.

### 2.1 `IconButton` → `tooltip:` parameter

```dart
// BEFORE
IconButton(
  icon: const Icon(Icons.close),
  onPressed: () => Navigator.pop(context),
)

// AFTER
IconButton(
  tooltip: 'Закрыть',
  icon: const Icon(Icons.close),
  onPressed: () => Navigator.pop(context),
)
```

Flutter's `tooltip:` serves dual purpose: visual long-press hint + screen-reader label. Idiomatic Material.

### 2.2 Custom tappables → `Semantics()` wrapper

```dart
// BEFORE (Sprint 5B.1 Task 3 provided SizedBox 44×44 already)
InkWell(
  onTap: () => _increment(),
  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
  child: const SizedBox(
    width: 44,
    height: 44,
    child: Icon(Icons.add, size: 20),
  ),
)

// AFTER — add Semantics wrapper
Semantics(
  label: 'Увеличить количество',
  button: true,
  child: InkWell(
    onTap: () => _increment(),
    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
    child: const SizedBox(
      width: 44,
      height: 44,
      child: Icon(Icons.add, size: 20),
    ),
  ),
)
```

For chip/pill with text content:

```dart
Semantics(
  label: 'Период: месяц',
  selected: _selectedPeriod == 'month',
  button: true,
  child: InkWell(
    onTap: () => _setPeriod('month'),
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: const Text('Месяц'),
    ),
  ),
)
```

For `GestureDetector`: same pattern. For toggles, use `toggled: bool` flag.

### 2.3 Decorative standalone icons → `semanticLabel: ''`

```dart
// Empty state / illustration icons
Column(
  children: [
    Icon(Icons.shopping_cart_outlined, size: 64, semanticLabel: ''),
    const SizedBox(height: 16),
    Text('Корзина пуста'),  // text is read; icon now silent
  ],
)
```

Using empty string `''` is explicit; `ExcludeSemantics` wrapper is an alternative but heavier.

### 2.4 Icon with adjacent text (Row / Column) — no fix needed

```dart
// Screen reader auto-reads the Text; Icon is ignored
Row(
  children: [
    Icon(Icons.receipt_long),
    const SizedBox(width: 8),
    Text('История продаж'),
  ],
)
```

Flutter's default semantic merging handles this. No explicit change.

### 2.5 Toggle state patterns

```dart
// Password visibility toggle
IconButton(
  tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
  onPressed: () => setState(() => _obscure = !_obscure),
)
```

For custom Semantics toggles, use the `toggled:` flag:

```dart
Semantics(
  toggled: _isExpanded,
  label: 'Развернуть',
  button: true,
  child: InkWell(...),
)
```

---

## 3. Russian Label Conventions

Consistent phrasing → consistent screen-reader experience.

### 3.1 Action verbs (imperative / infinitive)

| Semantic | Russian |
|---|---|
| Close | `Закрыть` |
| Back | `Назад` (AppBar auto) |
| Edit | `Редактировать` |
| Delete | `Удалить` |
| Add | `Добавить` |
| Save | `Сохранить` |
| Share | `Поделиться` |
| Print | `Печать` |
| Copy | `Копировать` |
| Search | `Поиск` |
| Filter | `Фильтры` |
| Refresh | `Обновить` |
| Settings | `Настройки` |
| Scan barcode | `Сканировать штрихкод` |

### 3.2 Context-specific (verb + object)

| Action | Russian |
|---|---|
| Add to cart | `Добавить в корзину` |
| Remove from cart | `Убрать из корзины` |
| Increase quantity | `Увеличить количество` |
| Decrease quantity | `Уменьшить количество` |
| Add product | `Добавить товар` |
| Edit product | `Редактировать товар` |
| Delete product | `Удалить товар` |
| Save product | `Сохранить товар` |
| Pay in cash | `Оплатить наличными` |
| Credit sale | `Продажа в долг` |
| New sale | `Новая продажа` |
| Show password | `Показать пароль` |
| Hide password | `Скрыть пароль` |

### 3.3 Bottom nav tabs

Label = tab name. No verb:
- `Главная`, `Товары`, `Касса`, `Финансы`, `Ещё`

### 3.4 State-dependent labels

Include dynamic value when state matters:

```dart
// Period selector
Semantics(
  label: 'Период: $periodName',
  selected: _selectedPeriod == key,
  button: true,
  child: ...,
)

// Cart count display (announce to screen reader)
Semantics(
  label: 'Количество: $quantity',
  child: Text('$quantity'),
)
```

### 3.5 Anti-patterns

- ❌ Don't append "кнопка" — `button: true` flag already announces "button"
- ❌ Don't duplicate AppBar's auto-labeled back button
- ❌ Don't write full sentences — short phrase ≈ 1-3 words
- ❌ Don't test in English locale — labels only work with `Locale('ru')` set (already app default)

---

## 4. Testing + Manual QA

### 4.1 Automated widget tests (10 key assertions)

Create `app/test/presentation/a11y/critical_paths_semantics_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// + imports per page (mock blocs, helpers reused from golden tests)

void main() {
  group('Critical path semantic labels', () {
    testWidgets('Login page — "Войти" CTA labeled', (tester) async {
      await pumpLoginPage(tester);
      expect(find.bySemanticsLabel('Войти'), findsOneWidget);
    });

    testWidgets('Login page — password visibility toggle labeled', (tester) async {
      await pumpLoginPage(tester);
      // Initial state: obscured
      expect(find.bySemanticsLabel('Показать пароль'), findsOneWidget);
    });

    testWidgets('Bottom nav — 5 tabs labeled', (tester) async {
      await pumpHomePage(tester);
      for (final label in ['Главная', 'Товары', 'Касса', 'Финансы', 'Ещё']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
    });

    testWidgets('POS checkout — "Новая продажа" FAB labeled', (tester) async {
      await pumpPosCheckoutPage(tester);
      expect(find.bySemanticsLabel('Новая продажа'), findsOneWidget);
    });

    testWidgets('Cart — quantity increment labeled', (tester) async {
      await pumpCartWithItem(tester);
      expect(find.bySemanticsLabel('Увеличить количество'), findsOneWidget);
    });

    testWidgets('Cart — quantity decrement labeled', (tester) async {
      await pumpCartWithItem(tester);
      expect(find.bySemanticsLabel('Уменьшить количество'), findsOneWidget);
    });

    testWidgets('Cash payment — "Оплатить наличными" CTA labeled', (tester) async {
      await pumpCashPaymentPage(tester);
      expect(find.bySemanticsLabel('Оплатить наличными'), findsOneWidget);
    });

    testWidgets('Receipt preview — "Поделиться" action labeled', (tester) async {
      await pumpReceiptPreview(tester);
      expect(find.bySemanticsLabel('Поделиться'), findsOneWidget);
    });

    testWidgets('Receipt preview — "Печать" action labeled', (tester) async {
      await pumpReceiptPreview(tester);
      expect(find.bySemanticsLabel('Печать'), findsOneWidget);
    });

    testWidgets('Product list — "Добавить товар" FAB labeled', (tester) async {
      await pumpProductListPage(tester);
      expect(find.bySemanticsLabel('Добавить товар'), findsOneWidget);
    });
  });
}
```

**10 assertions**. Helper `pumpXxx` functions reuse existing golden-test helpers (`pumpPageWithTheme`, bloc-wrap patterns from Sprint 2/3).

### 4.2 Manual TalkBack / VoiceOver smoke

Run after all 4 implementation phases complete.

**Setup on Android emulator:**
1. `Settings → Accessibility → TalkBack → ON`
2. Swipe right to navigate, double-tap to activate
3. Fallback if TalkBack non-functional in emulator: `Settings → Accessibility → Select to Speak`

**5-flow smoke script:**
1. **Login** — announcements for phone, password, "Показать пароль", "Войти".
2. **Bottom nav** — each of 5 tabs announced by name as focus moves.
3. **Product add** — "Добавить товар" FAB announced; step wizard announces forward / back controls.
4. **POS checkout** — cart item product names announced; "Увеличить/Уменьшить количество" announced; payment method tiles announced; "Оплатить наличными" CTA announced.
5. **Receipt** — "Поделиться" and "Печать" each announced distinctly.

Document results in final commit message (`PASS` / `FAIL:<detail>` per flow).

### 4.3 Golden test impact

`Semantics()` wrappers and `tooltip:` parameters do **NOT** change rendered pixels. Goldens stay identical. No regen expected.

Exception: if a `Semantics(container: true)` wrapper is accidentally used, it may cause a layout shift. Always leave `container:` at default (`false`).

### 4.4 Acceptance checklist

- ✅ 10 automated label tests pass
- ✅ `flutter analyze` → 0 issues
- ✅ `flutter test` → ~367 pass
- ✅ Manual TalkBack smoke: 5 flows PASS (or documented failure per flow)
- ✅ No golden regressions

---

## 5. Migration Strategy + Risks + Effort

### 5.1 Execution phases

**Phase 1 — Auth (≈45 min)**
- 5 pages: login, register, otp, forgot_password, create_password
- ~15 labels: password toggles, "Забыли пароль?" link, standalone decorative icons (if any)
- AppBar auto-back inherits "Назад" — no fix
- Commit: `feat(a11y): semantic labels for auth flow`

**Phase 2 — Bottom nav (≈15 min)**
- Single widget: `app_bottom_nav_bar.dart`
- Wrap each of 5 tab items in `Semantics(label, selected, button: true)`
- Commit: `feat(a11y): semantic labels for bottom navigation tabs`

**Phase 3 — Checkout (≈75 min)**
- 5 pages: pos_checkout, cash_payment, credit_sale, receipt_preview, sale_success
- ~22 labels: search, cart +/-, payment method tiles, CTAs, receipt share/print, FABs
- Commit: `feat(a11y): semantic labels for checkout flow`

**Phase 4 — Product CRUD (≈60 min)**
- 5 pages: product_list, product_detail, add_product_step1/2/3
- ~13 labels: FAB, search / filter / scanner triggers, edit / delete, image upload, category picker, step wizard, Save CTA
- Commit: `feat(a11y): semantic labels for product CRUD`

**Phase 5 — Tests + manual QA + wrap-up (≈30 min)**
- Create `critical_paths_semantics_test.dart` with 10 assertions
- Run full suite — 367 pass
- Manual TalkBack smoke on emulator; document in commit
- Final commit: `test(a11y): critical path semantic label assertions + QA notes`

### 5.2 Per-site workflow

For each page:
1. Read file; locate `IconButton(` / `InkWell(` / `GestureDetector(` sites
2. Categorize:
   - IconButton → `tooltip:` param (one-liner)
   - Custom tappable → wrap in `Semantics(label, button)`
   - Decorative standalone Icon → `semanticLabel: ''`
3. Pick label from §3 convention table
4. Save + `flutter analyze <file>` (clean expected; no new imports needed)

### 5.3 Acceptance greps

```bash
cd /Users/latifrjdev/Downloads/Dukon/app

grep -rc "Semantics(" lib/presentation/ | awk -F: '{sum+=$2}END{print sum}'
# Expected: ≥25

grep -rc "tooltip:" lib/presentation/ | awk -F: '{sum+=$2}END{print sum}'
# Expected: ≥30

flutter analyze                                                          # 0 issues
flutter test test/presentation/a11y/critical_paths_semantics_test.dart   # 10/10 pass
flutter test                                                             # ~367 pass
```

### 5.4 Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Labels sound unnatural in Russian | Medium | §3 convention table approved; manual TalkBack smoke catches awkward phrasing |
| `Semantics()` wrap introduces layout shift | Low | Default `container: false` is inert; goldens catch any regression |
| Toggle labels inconsistent | Medium | §3.5 explicit ternary pattern: `_obscure ? 'Показать пароль' : 'Скрыть пароль'` |
| Screen-reader merging (Row icon + text) behaves unexpectedly | Low | Flutter auto-merges; fallback `MergeSemantics()` if needed |
| TalkBack non-functional in emulator | Medium | Documented fallback: `Select to Speak` or iOS Simulator VoiceOver |
| Deferred 5B.2.c SnackBar announcements leave error-path UX gaps | Medium | Flagged in spec; standard `ScaffoldMessenger.showSnackBar` DOES announce content by default via OS — only polished live regions deferred |
| Label test helpers overlap with golden pump helpers | Low | Reuse `pumpPageWithTheme` pattern; no new infrastructure |

### 5.5 Estimated effort

| Phase | Time |
|---|---|
| 1. Auth (5 pages, ~15 labels) | 45 m |
| 2. Bottom nav (5 tabs) | 15 m |
| 3. Checkout (5 pages, ~22 labels) | 75 m |
| 4. Product CRUD (5 pages, ~13 labels) | 60 m |
| 5. Tests + TalkBack QA + docs | 30 m |
| **Total** | **~3.5-4 h** |

### 5.6 Dependencies

- Sprint 5B.1 touch targets (27 sites wrapped in `SizedBox(44, 44)`) — Semantics wrapping goes cleanly on top
- No new packages
- `find.bySemanticsLabel()` from `flutter_test` — stdlib

### 5.7 Deferred

- **Sprint 5B.2.b:** secondary paths — finance, settings, admin, customer, supplier, shifts, staff, notifications, zakat, delivery (~55 more widgets)
- **Sprint 5B.2.c:** live regions + SnackBar polished announcements (~95 sites)
- **Sprint 6:** localization — move hardcoded Russian labels to `AppLocalizations` `.arb` files across ru/tg/uz

---

## 6. Next Step

After approval, invoke `superpowers:writing-plans` to generate the implementation plan at `docs/superpowers/plans/2026-04-21-ui-ux-sprint-5b-2a-a11y-semantic-labels-critical.md`.
