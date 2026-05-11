# Mobile Click-Test — 2026-05-11

Full-app manual click test on Android emulator (API 34). Logged in as
qa-business (BUSINESS tier, all features), clicked through every tab
and every visible button.

## Bugs found (4)

### 🔴 BUG #27 — `/debts/customer` & `/debts/supplier` red error screen (FIXED)

**Repro:** dashboard → "Вам должны" or "Вы должны" → red Flutter
"type 'String' is not a subtype of 'Map<String, dynamic>?' in type
cast" error. App effectively unusable until you tab away.

**Root cause:** `dashboard_page.dart:389,402` calls
`context.push(RouteNames.customerDebts, extra: _getStoreId())` —
passing a String. `app_router.dart:377` casts `state.extra as
Map<String, dynamic>?` — boom.

**Fix shipped this commit:** wrap in
`{'storeId': _getStoreId() ?? ''}` map for both customer and
supplier debt navigation.

### 🟠 BUG #26 — "Остатки на складе" semantic misroute

Dashboard "Остатки на складе" tile navigates to the regular Товары
tab. Name implies a stock-summary view; users expect a different
screen. Either rename to "Товары на складе" or build a dedicated
stock view.

Not user-facing breakage, but misleading. Logged for product
decision.

### 🟠 BUG #28 — История продаж shows "Не удалось выполнить операцию"

Going to Ещё → История продаж always shows the error icon + "Повторить"
button even though the API responds 200 OK with valid data
(`{"data":[...23 sales...], "totalPages":2}`).

**Suspected:** client-side parser fails on one of the historical
test-pollution rows that have `total: -95` (negative — from the
BUG #14 probe pollution) or null fields the model doesn't expect.

API works (`curl /sales?page=1&limit=20` → 200, 23 rows).
Needs Sale model parser audit. Logged for next pass.

### 🟡 BUG #29 — Aggregate finance shows negative income

Финансы dashboard shows "Общий доход -127 TJS" because historical
sales from yesterday's BUG #14 probe had total=-95 each. Real
customers won't have these, but if anyone re-pollutes via direct
DB the aggregate breaks.

The BUG #14 fix only protects forward (new sales clamped). A
data-cleanup script for legacy negative totals, OR a schema
constraint `CHECK (total >= 0)` would be belt-and-braces. Logged.

## What worked (verified by clicking through)

### Tabs
- ✅ Login + auto-login on warm start
- ✅ Bottom nav (5 tabs: Главная, Товары, Касса, Финансы, Ещё)
- ✅ Tab switching preserves state via IndexedStack

### Главная
- ✅ Period filters (Сегодня/Неделя/Месяц + Выбрать период)
- ✅ Revenue card
- ✅ 3 stat cards (Прибыль/Себестоимость/Расходы)
- ✅ Bell → Уведомления (empty state correct)
- ✅ Q avatar → Ещё tab (UX: surprising routing but not broken)
- ✅ Остатки на складе → Товары (BUG #26 misroute)
- 🔴 Вам должны → red error (BUG #27, fixed)
- 🔴 Вы должны → red error (BUG #27, fixed)
- ✅ Инвентаризация link
- ✅ Новая продажа FAB

### Ещё (13 menu items)
- ✅ История продаж (visible, but BUG #28 error overlay)
- ✅ Финансы
- ✅ Расходы (lists, FAB add, filter chips)
- ✅ Долги (combined Нам должны / Мы должны view, no params)
- ✅ Закят (calculator works; G.2 fix verified — under-nisab → no zakat)
- ✅ Сотрудники (list shows 5 staff with role chips)
- ✅ Смены (current shift card with Закрыть смену button)
- ✅ Зарплата (month selector + Рассчитать)
- ✅ Роли и права (4 role tabs with permission toggles)
- ✅ Клиенты
- ✅ Поставщики
- ✅ Мои магазины
- ✅ Настройки (deep settings page with 12+ items)

### Товары
- ✅ Product list + filter chips (Все/В наличии/Заканчивается/Нет)
- ✅ Search field
- ✅ Barcode scan + filter buttons
- ✅ Product detail (price/cost/profit/margin cards)
- ✅ Маржа shows "—" when costPrice=0 (no div-by-zero crash)
- ✅ Приход + Продать buttons

### Касса (POS)
- ✅ Product chip strip with no overflow (Phase 1 fix #3 verified)
- ✅ Product list refreshes on tab focus (Phase 1 fix #2 verified)
- ✅ Add to cart
- ✅ Cart total + ИТОГО line
- ✅ 4 payment methods visible
- ✅ Оплата наличными with quick-amount chips + Без сдачи
- 🎉 **Sale success shows "1 TJS" correctly** (Phase 1 fix #1 verified —
  was previously showing "0 TJS" unlabeled change!)

### Финансы (8 modules)
- ✅ Финансы dashboard (4 metric cards + bar chart)
- ✅ All 8 module navigations work:
  Баланс / Кредиты / Вложения / Закят / Валюты / Доставка / Отчёт / Расходы
- 🟡 Aggregate income shown as negative (BUG #29)

## Cumulative session totals

**32 bugs found** total over 2 days, **28 fixed**, 4 carry-forward:
- BUG #25 (thermal_printer encoder limitation — needs package swap)
- BUG #26 (semantic misroute — product decision needed)
- BUG #28 (sales history client-parse — needs Sale model audit)
- BUG #29 (aggregate finance — needs data cleanup OR CHECK constraint)

The 1 critical bug found by clicking (#27) is fixed in this commit.
The other 3 are documented for the next pass.

## Test results

- API: 184 unit + 6 e2e ✓
- App: 397 passed + 9 skipped (BUG #25 doc) + 0 failed ✓
- Dart analyze 0 issues, tsc 0 errors

The fixes ride on top of the existing build; an APK rebuild + reinstall
is needed to verify BUG #27 in the running app (current install was
built before the fix).
