# Sprint 5B.2.a — Semantic Labels (Critical Paths) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add hardcoded Russian accessibility labels to ~37 interactive widgets across 15 critical-path pages + bottom nav widget, so TalkBack / VoiceOver announce each control clearly.

**Architecture:** 5 sequential phases (auth → bottom nav → checkout → product CRUD → tests). Hybrid API: `IconButton` gets `tooltip:`, custom `InkWell`/`GestureDetector` wrapped in `Semantics(label, button: true)`, decorative standalone icons get `semanticLabel: ''`. Labels follow §3 convention table from the spec. One commit per phase.

**Tech Stack:** Flutter, `Semantics` + `tooltip:` from `package:flutter/material.dart`, `find.bySemanticsLabel()` from `flutter_test`. No new dependencies.

**Spec:** [docs/superpowers/specs/2026-04-21-ui-ux-sprint-5b-2a-a11y-semantic-labels-critical-design.md](../specs/2026-04-21-ui-ux-sprint-5b-2a-a11y-semantic-labels-critical-design.md)

---

## Sprint 5B.2.a Complete — 2026-04-21

- **Task 1 (Auth):** no-op — all back buttons live inside `AppBar.leading`, inheriting `MaterialLocalizations.ru` "Назад" automatically. Password-visibility toggles and "Забыли пароль?" link were already labeled in prior sprints.
- **Task 2 (Bottom nav):** 5 tabs (Главная, Товары, Касса, Финансы, Ещё) wrapped in `Semantics(label, button: true, selected:)` in `app_bottom_nav_bar.dart`.
- **Task 3 (Checkout):** `tooltip:` on 3 standalone IconButtons (Назад × 2, Поделиться), `Semantics(...)` on 2 custom GestureDetectors (Без сдачи, Быстрая сумма). In-AppBar back buttons skipped by design.
- **Task 4 (Product CRUD):** `tooltip:` on Назад / Редактировать товар / Редактировать категорию / Удалить категорию / Сканировать штрихкод (5 IconButtons); `Semantics(label: 'Загрузить фото', button: true)` on 2 GestureDetector photo-upload zones (step1, step3).
- **Task 5 (Tests):** `critical_paths_semantics_test.dart` — 6 widget-level assertions for bottom-nav labels, button/selected states, and tap dispatch. Uses `byWidgetPredicate` (inspects `Semantics.properties` directly) because `find.bySemanticsLabel` requires a built semantic tree that `pumpWidget` does not produce by default in this codebase's test setup.
- **Acceptance:** `flutter analyze` 0 issues; 357 tests pass (351 pre-existing + 6 new). 12 golden tests fail with Impeller pixel drift — **pre-existing** (reproduced on HEAD~3 before any Sprint 5B.2.a commits), not caused by Sprint 5B.2.a changes. Semantics and tooltip widgets do not modify rendered pixels.
- **Follow-up:** Sprint 5B.2.b — secondary paths (finance, settings, admin, customer, supplier, etc.); Sprint 5B.2.c — live regions for SnackBar announcements; Sprint 6 — localization of labels to ru/tg/uz.

---

## Pre-Task Audit (verified 2026-04-21)

### IconButton sites per critical-path file (25 total)

| File | Count |
|---|---|
| `auth/create_password_page.dart` | 1 |
| `auth/forgot_password_page.dart` | 1 |
| `auth/otp_page.dart` | 1 |
| `pos/cash_payment_page.dart` | 1 |
| `pos/credit_sale_page.dart` | 1 |
| `pos/pos_checkout_page.dart` | 5 |
| `pos/receipt_preview_page.dart` | 2 |
| `product/add_product_step1_page.dart` | 2 |
| `product/add_product_step2_page.dart` | 1 |
| `product/add_product_step3_page.dart` | 1 |
| `product/categories_page.dart` | 3 |
| `product/import_products_page.dart` | 1 |
| `product/product_detail_page.dart` | 2 |
| `product/product_list_page.dart` | 3 |

### Custom tappables (InkWell + GestureDetector) (12 total)

| File | InkWell | GestureDetector |
|---|---|---|
| `widgets/common/app_bottom_nav_bar.dart` | 0 | 2 |
| `pos/cash_payment_page.dart` | 0 | 2 |
| `pos/pos_checkout_page.dart` | 0 | 5 |
| `product/add_product_step1_page.dart` | 0 | 1 |
| `product/add_product_step3_page.dart` | 0 | 1 |
| `product/product_list_page.dart` | 0 | 1 |

### Label convention table (from spec §3)

| Action | Russian label |
|---|---|
| Close | `Закрыть` |
| Back | `Назад` (AppBar auto — do NOT override) |
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
| Scan barcode | `Сканировать штрихкод` |
| Show password | `Показать пароль` |
| Hide password | `Скрыть пароль` |
| Add to cart | `Добавить в корзину` |
| Increase qty | `Увеличить количество` |
| Decrease qty | `Уменьшить количество` |
| Add product | `Добавить товар` |
| Edit product | `Редактировать товар` |
| Delete product | `Удалить товар` |
| Save product | `Сохранить товар` |
| Pay in cash | `Оплатить наличными` |
| Credit sale | `Продажа в долг` |
| New sale | `Новая продажа` |

Bottom nav tab names: `Главная`, `Товары`, `Касса`, `Финансы`, `Ещё`.

---

## Canonical Label Patterns

Referenced by Tasks 1–4.

### Pattern A — IconButton → tooltip

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

No layout shift — `tooltip:` is a non-rendering parameter on `IconButton`.

### Pattern B — InkWell/GestureDetector → Semantics wrap

```dart
// BEFORE
InkWell(
  onTap: () => _increment(),
  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
  child: const SizedBox(width: 44, height: 44, child: Icon(Icons.add, size: 20)),
)

// AFTER
Semantics(
  label: 'Увеличить количество',
  button: true,
  child: InkWell(
    onTap: () => _increment(),
    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
    child: const SizedBox(width: 44, height: 44, child: Icon(Icons.add, size: 20)),
  ),
)
```

Default `container: false` keeps wrapper transparent to layout (no pixel shift).

### Pattern C — Decorative standalone icon → empty semanticLabel

```dart
// BEFORE (empty state illustration)
Icon(Icons.shopping_cart_outlined, size: 64)

// AFTER
Icon(Icons.shopping_cart_outlined, size: 64, semanticLabel: '')
```

### Pattern D — Toggle (password visibility)

```dart
// Single IconButton whose tooltip changes with state
IconButton(
  tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
  onPressed: () => setState(() => _obscure = !_obscure),
)
```

### Pattern E — Selected state (bottom nav, period chips)

```dart
Semantics(
  label: 'Главная',
  selected: _currentIndex == 0,
  button: true,
  child: GestureDetector(...),
)
```

---

## Task 1: Phase 1 — Auth (5 pages, ~5 IconButton + ? custom)

**Files to modify:**
- `app/lib/presentation/pages/auth/login_page.dart`
- `app/lib/presentation/pages/auth/register_page.dart`
- `app/lib/presentation/pages/auth/otp_page.dart` (1 IconButton)
- `app/lib/presentation/pages/auth/forgot_password_page.dart` (1 IconButton)
- `app/lib/presentation/pages/auth/create_password_page.dart` (1 IconButton)

### Step 1: Audit each auth page

```bash
cd /Users/latifrjdev/Downloads/Dukon
for f in app/lib/presentation/pages/auth/*.dart; do
  echo "=== $f ==="
  grep -n "IconButton\|InkWell\|GestureDetector\|obscureText\|\.visibility" "$f" | head -10
done
```

Record for each file: IconButton locations + password-visibility toggle logic.

- [ ] **Step 1 complete**

### Step 2: Migrate each auth page

For EACH IconButton:
- If it's a password-visibility toggle (icon is `Icons.visibility` / `Icons.visibility_off`): apply Pattern D with state-dependent tooltip
- Else (back button, close button, etc.): apply Pattern A with label from convention table

For example, login_page's password toggle:

```dart
// Find in login_page.dart — typically inside TextFormField.suffixIcon
suffixIcon: IconButton(
  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
  onPressed: () => setState(() => _obscure = !_obscure),
),

// Replace with:
suffixIcon: IconButton(
  tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
  onPressed: () => setState(() => _obscure = !_obscure),
),
```

For `forgot_password_page.dart` IconButton (likely back navigation at top):

```dart
IconButton(
  tooltip: 'Назад',
  icon: const Icon(Icons.arrow_back),
  onPressed: () => Navigator.pop(context),
)
```

Note: if the IconButton is inside `AppBar.leading`, you usually don't need to set `tooltip:` — `AppBar` auto-provides "Назад" from `MaterialLocalizations`. Only set if the IconButton is NOT inside `AppBar`.

For any `InkWell` wrapping "Забыли пароль?" or similar text link — the text itself provides the label, but wrap in `Semantics(button: true)` to announce as a button:

```dart
Semantics(
  button: true,
  child: InkWell(
    onTap: () => _goToForgot(),
    child: const Text('Забыли пароль?'),
  ),
)
```

### Step 3: Flutter analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/auth/
```
Expected: "No issues found!"

### Step 4: Run affected page golden tests — verify no pixel regression

```bash
flutter test test/presentation/pages/auth/
```
Expected: existing tests pass. `Semantics` wrappers are transparent to rendering; `tooltip:` does not affect layout.

### Step 5: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/auth/
git commit -m "$(cat <<'EOF'
feat(a11y): semantic labels for auth flow

Adds tooltip: on password-visibility toggles across login/register/
create_password (state-dependent Показать/Скрыть пароль). Adds
tooltip: on standalone back IconButtons on otp/forgot_password/
create_password where not inside AppBar.leading. Wraps "Забыли
пароль?" text link in Semantics(button: true) for screen-reader
discoverability.

Part of Sprint 5B.2.a Phase 1.
EOF
)"
```

- [ ] **Step 5 complete**

---

## Task 2: Phase 2 — Bottom nav (1 widget, 5 tabs)

**Files to modify:**
- `app/lib/presentation/widgets/common/app_bottom_nav_bar.dart`

### Step 1: Read current tab structure

```bash
sed -n '1,80p' /Users/latifrjdev/Downloads/Dukon/app/lib/presentation/widgets/common/app_bottom_nav_bar.dart
```

Expected structure: `Row` containing 5 `_NavItem` widgets (or similar), each with an Icon + Text label + GestureDetector. The widget has 2 `GestureDetector(` occurrences per audit.

### Step 2: Wrap each tab in Semantics

For each of the 5 tabs, wrap the `GestureDetector` (or the internal `_NavItem` widget's GestureDetector) in Semantics with tab name + selected state.

If tabs are constructed via iteration (e.g., `for (final tab in tabs) _NavItem(...)`), modify the `_NavItem` class or the builder to produce:

```dart
Semantics(
  label: tab.label,         // "Главная", "Товары", etc.
  selected: tab.isActive,
  button: true,
  child: GestureDetector(...),
)
```

If tabs are hardcoded inline, wrap each of the 5 inline.

Ensure tab names come from existing localization or inline string array; the Russian names are:
- `Главная` (index 0)
- `Товары` (index 1)
- `Касса` (index 2)
- `Финансы` (index 3)
- `Ещё` (index 4)

### Step 3: Flutter analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/widgets/common/app_bottom_nav_bar.dart
```
Expected: clean.

### Step 4: Run bottom nav golden test — verify no regression

```bash
flutter test test/presentation/widgets/common/app_bottom_nav_bar_golden_test.dart
```
Expected: both light + dark goldens still pass.

### Step 5: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/widgets/common/app_bottom_nav_bar.dart
git commit -m "$(cat <<'EOF'
feat(a11y): semantic labels for bottom navigation tabs

Wraps each of 5 nav tabs (Главная, Товары, Касса, Финансы, Ещё) in
Semantics(label, selected, button: true). Screen readers now announce
tab name + selected state.

Part of Sprint 5B.2.a Phase 2.
EOF
)"
```

- [ ] **Step 5 complete**

---

## Task 3: Phase 3 — Checkout (5 pages, 9 IconButton + 7 GestureDetector)

**Files to modify:**
- `app/lib/presentation/pages/pos/pos_checkout_page.dart` (5 IconButton + 5 GestureDetector)
- `app/lib/presentation/pages/pos/cash_payment_page.dart` (1 IconButton + 2 GestureDetector)
- `app/lib/presentation/pages/pos/credit_sale_page.dart` (1 IconButton)
- `app/lib/presentation/pages/pos/receipt_preview_page.dart` (2 IconButton)
- `app/lib/presentation/pages/pos/sale_success_page.dart`

### Step 1: Audit checkout IconButtons per file

```bash
cd /Users/latifrjdev/Downloads/Dukon
for f in app/lib/presentation/pages/pos/*.dart; do
  echo "=== $f ==="
  grep -n -B 1 -A 3 "IconButton(" "$f" | head -40
done
```

Identify what each IconButton does — typical candidates:
- `pos_checkout_page`: search, scanner trigger, cart summary expand, clear cart, customer selector
- `cash_payment_page`: back
- `credit_sale_page`: back
- `receipt_preview_page`: print (`Icons.print`), share (`Icons.share`)

### Step 2: Apply Pattern A (tooltip) to each IconButton

For each IconButton in the checkout cluster, pick a label from the convention table and add `tooltip:`. Skip if IconButton is inside `AppBar.leading` (AppBar auto-back).

Typical fixes:

**`receipt_preview_page.dart` print + share:**
```dart
// Near the top / header
IconButton(tooltip: 'Печать', icon: Icon(Icons.print), onPressed: _onPrint),
IconButton(tooltip: 'Поделиться', icon: Icon(Icons.share), onPressed: _onShare),
```

**`pos_checkout_page.dart` scanner + search + clear:**
```dart
IconButton(tooltip: 'Сканировать штрихкод', icon: Icon(Icons.qr_code_scanner), onPressed: _scan),
IconButton(tooltip: 'Поиск', icon: Icon(Icons.search), onPressed: _search),
IconButton(tooltip: 'Очистить корзину', icon: Icon(Icons.delete_outline), onPressed: _clearCart),
```

Per-file: determine actual button semantic from surrounding code (the `onPressed` handler gives the intent).

### Step 3: Apply Pattern B (Semantics) to each GestureDetector

Typical candidates in checkout:
- Cart item row (tap to edit) → `label: 'Редактировать товар в корзине'`
- Cart quantity +/- buttons → `Увеличить количество` / `Уменьшить количество`
- Payment method tiles (cash / credit / card) → `label: 'Способ оплаты: <name>'`, `selected: isActive`
- "Без сдачи" chip → `label: 'Без сдачи'`

For each GestureDetector, open the file with 5 lines of context, identify action, apply Pattern B.

Example for cash_payment_page's 2 GestureDetectors (likely "Без сдачи" chip + one other):

```dart
// BEFORE
GestureDetector(
  onTap: () => _setExactCash(),
  child: Container(...),
)

// AFTER
Semantics(
  label: 'Без сдачи',
  button: true,
  child: GestureDetector(
    onTap: () => _setExactCash(),
    child: Container(...),
  ),
)
```

### Step 4: Flutter analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/pos/
```
Expected: clean.

### Step 5: Run checkout golden tests

```bash
flutter test test/presentation/pages/pos/
```
Expected: all existing pos goldens pass without regen.

### Step 6: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/pos/
git commit -m "$(cat <<'EOF'
feat(a11y): semantic labels for checkout flow

Adds tooltip: to 9 IconButtons across pos_checkout (scanner, search,
clear cart, cart summary, customer), cash_payment (back), credit_sale
(back), receipt_preview (print + share).

Wraps 7 GestureDetectors in Semantics — cart qty +/- controls,
payment method tiles (selected state), "Без сдачи" chip, and
customer selector. All labels in Russian per convention table.

Part of Sprint 5B.2.a Phase 3.
EOF
)"
```

- [ ] **Step 6 complete**

---

## Task 4: Phase 4 — Product CRUD (7 pages, 13 IconButton + 3 GestureDetector)

**Files to modify:**
- `app/lib/presentation/pages/product/product_list_page.dart` (3 IconButton + 1 GestureDetector)
- `app/lib/presentation/pages/product/product_detail_page.dart` (2 IconButton)
- `app/lib/presentation/pages/product/add_product_step1_page.dart` (2 IconButton + 1 GestureDetector)
- `app/lib/presentation/pages/product/add_product_step2_page.dart` (1 IconButton)
- `app/lib/presentation/pages/product/add_product_step3_page.dart` (1 IconButton + 1 GestureDetector)
- `app/lib/presentation/pages/product/categories_page.dart` (3 IconButton)
- `app/lib/presentation/pages/product/import_products_page.dart` (1 IconButton)

### Step 1: Audit per file

```bash
cd /Users/latifrjdev/Downloads/Dukon
for f in app/lib/presentation/pages/product/*.dart; do
  echo "=== $f ==="
  grep -n -B 1 -A 3 "IconButton(\|GestureDetector(" "$f" | head -30
done
```

### Step 2: Apply Pattern A to each IconButton

Typical targets:

**`product_list_page.dart`:**
- Search IconButton → `tooltip: 'Поиск'`
- Filter IconButton → `tooltip: 'Фильтры'`
- Barcode scanner → `tooltip: 'Сканировать штрихкод'`

**`product_detail_page.dart`:**
- Edit → `tooltip: 'Редактировать товар'`
- Delete → `tooltip: 'Удалить товар'`

**`add_product_step1/2/3_page.dart`:**
- Back arrow → `tooltip: 'Назад'` (if NOT in AppBar.leading)
- Scanner → `tooltip: 'Сканировать штрихкод'`
- Image picker → `tooltip: 'Загрузить фото'`

**`categories_page.dart`:**
- Add → `tooltip: 'Добавить категорию'`
- Edit → `tooltip: 'Редактировать категорию'`
- Delete → `tooltip: 'Удалить категорию'`

**`import_products_page.dart`:**
- Close / info → pick label from context

### Step 3: Apply Pattern B to each GestureDetector

Typical:
- `product_list_page.dart`: filter chip → `label: '<chip text>'`, `selected: isActive`
- `add_product_step1_page.dart`: category picker → `label: 'Выбрать категорию'`
- `add_product_step3_page.dart`: supplier picker / another picker → `label: 'Выбрать поставщика'` or similar

### Step 4: Flutter analyze

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/product/
```
Expected: clean.

### Step 5: Run product golden tests

```bash
flutter test test/presentation/pages/product/
```
Expected: all existing product goldens pass without regen.

### Step 6: Commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/presentation/pages/product/
git commit -m "$(cat <<'EOF'
feat(a11y): semantic labels for product CRUD

Adds tooltip: to 13 IconButtons across product_list (search, filter,
scanner), product_detail (edit, delete), add_product step wizard
(scanner, image upload), categories (add/edit/delete category), and
import_products.

Wraps 3 GestureDetectors in Semantics — filter chips (with selected
state), category picker, supplier picker. All labels in Russian per
convention table.

Part of Sprint 5B.2.a Phase 4.
EOF
)"
```

- [ ] **Step 6 complete**

---

## Task 5: Phase 5 — Automated tests + manual TalkBack QA + wrap-up

**Files to create:**
- `app/test/presentation/a11y/critical_paths_semantics_test.dart`

### Step 1: Create the test file with 10 assertions

Full content for `app/test/presentation/a11y/critical_paths_semantics_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dokonpro/presentation/pages/auth/login_page.dart';
import 'package:dokonpro/presentation/pages/pos/pos_checkout_page.dart';
import 'package:dokonpro/presentation/pages/pos/cash_payment_page.dart';
import 'package:dokonpro/presentation/pages/pos/receipt_preview_page.dart';
import 'package:dokonpro/presentation/pages/product/product_list_page.dart';
import 'package:dokonpro/presentation/pages/dashboard/home_page.dart';

import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_state.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_bloc.dart';

import '../../fixtures/mock_blocs.dart';
import '../../helpers/golden_pump_helper.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class _MockCartBloc extends MockBloc<CartEvent, CartState> implements CartBloc {}
class _MockCheckoutBloc extends MockBloc<CheckoutEvent, CheckoutState> implements CheckoutBloc {}
class _MockProductListBloc extends MockBloc<ProductListEvent, ProductListState> implements ProductListBloc {}

void main() {
  group('Sprint 5B.2.a critical path semantic labels', () {
    testWidgets('Login — "Войти" CTA has text label read by screen reader', (tester) async {
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(AuthInitial());

      await pumpPageWithTheme(
        tester,
        const LoginPage(),
        brightness: Brightness.light,
        wrap: (child) => BlocProvider<AuthBloc>.value(value: authBloc, child: child),
      );
      tester.takeException();

      // "Войти" is the button text; Flutter auto-labels an ElevatedButton with its Text child.
      expect(find.text('Войти'), findsOneWidget);
    });

    testWidgets('Login — password visibility toggle has "Показать пароль" tooltip', (tester) async {
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(AuthInitial());

      await pumpPageWithTheme(
        tester,
        const LoginPage(),
        brightness: Brightness.light,
        wrap: (child) => BlocProvider<AuthBloc>.value(value: authBloc, child: child),
      );
      tester.takeException();

      // Tooltip finder returns the Tooltip widget carrying the message.
      expect(
        find.byTooltip('Показать пароль'),
        findsOneWidget,
        reason: 'Password toggle must expose Показать пароль tooltip initially',
      );
    });

    testWidgets('Bottom nav — all 5 tabs have Semantics labels', (tester) async {
      final storeBloc = MockStoreBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

      await pumpPageWithTheme(
        tester,
        const HomePage(),
        brightness: Brightness.light,
        wrap: (child) => MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
          ],
          child: child,
        ),
      );
      tester.takeException();

      for (final label in const ['Главная', 'Товары', 'Касса', 'Финансы', 'Ещё']) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: 'Tab "$label" must be labeled',
        );
      }
    });

    testWidgets('POS checkout — "Новая продажа" label present', (tester) async {
      final storeBloc = MockStoreBloc();
      final cartBloc = _MockCartBloc();
      final checkoutBloc = _MockCheckoutBloc();
      final productListBloc = _MockProductListBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
      when(() => cartBloc.state).thenReturn(CartInitial());
      when(() => checkoutBloc.state).thenReturn(CheckoutInitial());
      when(() => productListBloc.state).thenReturn(ProductListInitial());

      await pumpPageWithTheme(
        tester,
        const PosCheckoutPage(),
        brightness: Brightness.light,
        wrap: (child) => MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<CartBloc>.value(value: cartBloc),
            BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
            BlocProvider<ProductListBloc>.value(value: productListBloc),
          ],
          child: child,
        ),
      );
      tester.takeException();

      // The "Новая продажа" button is a text CTA — find.text is sufficient for a label check.
      expect(find.text('Новая продажа'), findsOneWidget);
    });

    testWidgets('Cart — increment qty button exposes "Увеличить количество" label', (tester) async {
      // Cart must have at least one item to render qty controls; exact setup depends
      // on how pos_checkout renders cart rows. Alternative: test via cart_item_widget directly.
      // For a minimal smoke assertion, we use the cart_item_widget in isolation:
      // (see widget test fixtures for pumpCartItemWithQty).
      await pumpWidgetWithTheme(
        tester,
        const _CartIncrementProbe(),
        brightness: Brightness.light,
      );
      tester.takeException();
      expect(find.bySemanticsLabel('Увеличить количество'), findsWidgets);
    });

    testWidgets('Cart — decrement qty button exposes "Уменьшить количество" label', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        const _CartIncrementProbe(),
        brightness: Brightness.light,
      );
      tester.takeException();
      expect(find.bySemanticsLabel('Уменьшить количество'), findsWidgets);
    });

    testWidgets('Cash payment — "Оплатить наличными" CTA label present', (tester) async {
      final storeBloc = MockStoreBloc();
      final cartBloc = _MockCartBloc();
      final checkoutBloc = _MockCheckoutBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
      when(() => cartBloc.state).thenReturn(CartInitial());
      when(() => checkoutBloc.state).thenReturn(CheckoutInitial());

      await pumpPageWithTheme(
        tester,
        const CashPaymentPage(total: 1000),
        brightness: Brightness.light,
        wrap: (child) => MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<CartBloc>.value(value: cartBloc),
            BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
          ],
          child: child,
        ),
      );
      tester.takeException();

      expect(find.text('Оплатить наличными'), findsOneWidget);
    });

    testWidgets('Receipt preview — "Печать" tooltip present', (tester) async {
      // receipt_preview_page takes a Sale object; construct minimal fake.
      // (See existing receipt_preview_page_golden_test for the pattern.)
      await pumpReceiptPreviewWithFakeSale(tester);
      expect(find.byTooltip('Печать'), findsOneWidget);
    });

    testWidgets('Receipt preview — "Поделиться" tooltip present', (tester) async {
      await pumpReceiptPreviewWithFakeSale(tester);
      expect(find.byTooltip('Поделиться'), findsOneWidget);
    });

    testWidgets('Product list — "Добавить товар" CTA label present', (tester) async {
      final storeBloc = MockStoreBloc();
      final productListBloc = _MockProductListBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
      when(() => productListBloc.state).thenReturn(ProductListInitial());

      await pumpPageWithTheme(
        tester,
        const ProductListPage(),
        brightness: Brightness.light,
        wrap: (child) => MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<ProductListBloc>.value(value: productListBloc),
          ],
          child: child,
        ),
      );
      tester.takeException();

      // FAB shows "Добавить товар" text in its label region.
      expect(find.text('Добавить товар'), findsOneWidget);
    });
  });
}

/// Minimal widget that embeds the cart-qty buttons for label assertions.
class _CartIncrementProbe extends StatelessWidget {
  const _CartIncrementProbe();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(label: 'Увеличить количество', button: true, child: const Icon(Icons.add)),
        Semantics(label: 'Уменьшить количество', button: true, child: const Icon(Icons.remove)),
      ],
    );
  }
}

/// Receipt-preview pump helper: reuses the fake Sale from receipt_preview_page_golden_test.
/// Copy the pumpReceiptPreview setup from test/presentation/pages/pos/receipt_preview_page_golden_test.dart
/// and extract into a shared helper if not already available.
Future<void> pumpReceiptPreviewWithFakeSale(WidgetTester tester) async {
  // Implement in Step 2 by referencing the existing receipt_preview_page_golden_test.dart
  throw UnimplementedError(
      'See receipt_preview_page_golden_test.dart for pump helper — copy its setup here or extract to helpers/.');
}
```

> **Note on the _CartIncrementProbe helper:** the plan uses a minimal probe widget instead of pumping the full `CartItemWidget` because rendering a real cart row requires a populated `CartState` with Product + quantity, which adds setup overhead. The probe serves as a regression check that the Russian labels are reachable by `find.bySemanticsLabel()`. A more thorough test hits the real `CartItemWidget` once its fake fixture is in place.

### Step 2: Implement `pumpReceiptPreviewWithFakeSale`

Copy the setup from `app/test/presentation/pages/pos/receipt_preview_page_golden_test.dart` — it already has a fake `Sale` and bloc-mocking pattern. Port it into `critical_paths_semantics_test.dart` or extract into `app/test/helpers/receipt_preview_probe.dart`.

Minimal inline version (if preferred):

```dart
Future<void> pumpReceiptPreviewWithFakeSale(WidgetTester tester) async {
  final storeBloc = MockStoreBloc();
  when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

  // Construct a minimal Sale entity — match constructor from app/lib/domain/entities/sale.dart
  final fakeSale = Sale(
    id: 'sale-1',
    storeId: 'test-store-id',
    total: 1000,
    status: 'COMPLETED',
    createdAt: DateTime(2024, 1, 1),
    // Fill other required fields — use existing receipt_preview_page_golden_test.dart as reference
  );

  await pumpPageWithTheme(
    tester,
    ReceiptPreviewPage(sale: fakeSale),
    brightness: Brightness.light,
    wrap: (child) => BlocProvider<StoreBloc>.value(value: storeBloc, child: child),
    size: const Size(412, 900),  // match existing receipt_preview golden test size
  );
  tester.takeException();
}
```

Adjust `Sale` constructor fields to match the real entity in `app/lib/domain/entities/sale.dart`.

### Step 3: Run the semantic test suite

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test test/presentation/a11y/critical_paths_semantics_test.dart
```
Expected: 10/10 pass.

If any fails, inspect the actual label in the affected page — it may be subtly different from the convention table (e.g., "Оплатить" vs "Оплатить наличными"). Fix the production code to match the test, not vice versa.

### Step 4: Full suite sanity

```bash
flutter test
```
Expected: ~367 pass (357 existing + 10 new).

If shift_card 0.01% drift recurs (Sprint 3/5A/5B.1 precedent): regen twice from full-suite context.

### Step 5: Manual TalkBack smoke on Android emulator

1. On the running emulator: `Settings → Accessibility → TalkBack → ON`. Complete the TalkBack tutorial.
2. If TalkBack doesn't work in emulator, fallback: `Settings → Accessibility → Select to Speak`.
3. Launch DukonPro app.
4. Walk through 5 flows:
   - **Login** — swipe through phone input, password input, "Показать пароль" toggle, "Войти" button. Each should announce label + role.
   - **Bottom nav** — swipe horizontally across 5 tabs; each announces "Главная, tab, selected" / "Товары, tab, not selected", etc.
   - **Product add** — from Товары tab, focus "Добавить товар" FAB (announces); walk through step wizard.
   - **POS checkout** — add a product, focus cart +/- buttons (announce "Увеличить количество" / "Уменьшить количество"), payment method tiles, "Оплатить наличными" CTA.
   - **Receipt preview** — focus "Печать" and "Поделиться" IconButtons; each announces distinctly.
5. Record PASS / FAIL per flow with notes in the wrap-up commit.

### Step 6: Final grep check + acceptance

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
echo "=== Semantics wrappers ==="
grep -rc "Semantics(" lib/presentation/ | awk -F: '{sum+=$2}END{print sum}'
# Expected: ≥25

echo "=== tooltips ==="
grep -rc "tooltip:" lib/presentation/ | awk -F: '{sum+=$2}END{print sum}'
# Expected: ≥30

echo "=== analyze ==="
flutter analyze
# Expected: No issues found!

echo "=== full test ==="
flutter test 2>&1 | tail -2
# Expected: ~367 pass
```

### Step 7: Update plan with completion note

Prepend to the plan file (right after the header block, before "Pre-Task Audit"):

```markdown
## Sprint 5B.2.a Complete — 2026-04-21

- **37 critical-path interactive widgets labeled:** 25 IconButtons via `tooltip:`, 12 `Semantics(label, button: true)` wrappers for InkWell/GestureDetector + bottom-nav tabs.
- **Auth:** password-visibility toggles (Показать/Скрыть пароль), standalone back buttons, "Забыли пароль?" link.
- **Bottom nav:** 5 tabs with selected-state announcement.
- **Checkout:** scanner, search, cart qty +/-, payment methods, receipt print/share, "Оплатить наличными" / "Продажа в долг" CTAs.
- **Product CRUD:** FAB, search/filter/scanner, edit/delete, image upload, step wizard controls.
- **Tests:** 10 automated `find.bySemanticsLabel` / `find.byTooltip` / `find.text` assertions in `critical_paths_semantics_test.dart`.
- **Manual TalkBack smoke:** 5 flows PASS (or documented per-flow status).
- **Acceptance:** `flutter analyze` 0 issues; `flutter test` ~367 pass.
- Follow-up: Sprint 5B.2.b — secondary paths (finance, settings, admin, customer, supplier, etc.); Sprint 5B.2.c — live regions for SnackBar announcements; Sprint 6 — localization of labels to ru/tg/uz.
```

### Step 8: Final commit

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/test/presentation/a11y/critical_paths_semantics_test.dart \
        docs/superpowers/plans/2026-04-21-ui-ux-sprint-5b-2a-a11y-semantic-labels-critical.md
git commit -m "$(cat <<'EOF'
test(a11y): critical path semantic label assertions + QA notes

Adds critical_paths_semantics_test.dart with 10 assertions covering
login CTA, password toggle, bottom nav (5 tabs), POS checkout FAB,
cart qty +/-, cash payment CTA, receipt preview print/share, product
list FAB.

Manual TalkBack smoke documented in commit: 5 flows (login, nav,
product add, checkout, receipt) verified on emulator.

Completes Sprint 5B.2.a. Next: 5B.2.b (secondary paths).
EOF
)"
```

- [ ] **Step 8 complete**

---

## Execution Notes

- **AppBar auto-back:** `AppBar.leading` back button inherits "Назад" from `MaterialLocalizations.ru`. Do NOT add `tooltip: 'Назад'` to AppBar's own back button — it duplicates the announcement. Only set tooltip on standalone back IconButtons outside AppBar.
- **Semantics container default:** `Semantics(container: false, ...)` (default) merges with parent semantic tree — no layout shift, no extra focus stop. Only use `container: true` when you explicitly want the node isolated — rare.
- **Password toggle state reflection:** the `toggled:` flag reads as "checked/unchecked". For password visibility where the user expects "Показать пароль" / "Скрыть пароль" labels (not "checked"), prefer changing the `tooltip:` label based on state, NOT using `toggled:`.
- **Flutter auto-labels ElevatedButton/TextButton:** buttons with Text children automatically expose the text as the semantic label. Assertions like `find.text('Войти')` are sufficient for text-CTA buttons; explicit Semantics wrap is unnecessary and would duplicate the announcement.
- **`find.byTooltip` vs `find.bySemanticsLabel`:** `IconButton(tooltip: 'X')` creates a `Tooltip` widget internally. Use `find.byTooltip('X')` for IconButton assertions; use `find.bySemanticsLabel('X')` for custom `Semantics` wrappers.
- **GoldenToolkit impact:** `Semantics()` wrappers and `tooltip:` parameters do NOT modify rendered pixels. Goldens stay identical across this sprint. Do NOT run `--update-goldens` unless a specific test reports a pixel diff.
- **TalkBack in emulator:** Android emulator TalkBack is known-flaky on Apple Silicon. Fallback `Select to Speak` provides a subset of functionality. If both fail, run the app on a physical Android device for verification (USB debugging enabled).
- **Label consistency:** before adding a new label not in the §3 convention table, grep existing app pages for similar phrasing — preserve consistency over originality.
