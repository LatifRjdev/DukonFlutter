# Comprehensive Click Test Plan — 2026-05-11

After all 8 fix commits + plan execution, do a methodical click-test
covering every screen × button × role × subscription tier.

## Test Matrix

### Roles × Tiers

| Role       | START | BUSINESS | PREMIUM |
|------------|-------|----------|---------|
| OWNER      | ✓     | ✓        | ✓       |
| ADMIN      | —*    | ✓        | ✓       |
| CASHIER    | ✓     | ✓        | ✓       |
| WAREHOUSE  | —*    | ✓        | ✓       |

\* START tier `maxStaff=2` (owner + 1 cashier) — cannot host ADMIN or
WAREHOUSE. We accept the gap.

Total cells: **10**.

### Screens × Buttons (per role)

#### Главная (Dashboard)
- Bell → Уведомления
- Q avatar → Ещё tab
- Period filter chips (Сегодня / Неделя / Месяц / 📅)
- Hero revenue card
- 3 metric cards (Прибыль / Себестоимость / Расходы)
- "Остатки на складе" tile → **Товары tab with `Требует внимания` filter pre-selected** (NEW)
- "Вам должны" tile → /debts/customer (NEW: was crashing red, now opens debt list)
- "Вы должны" tile → /debts/supplier (same fix)
- "Инвентаризация" tile → /inventory-count
- "Новая продажа" FAB → Касса tab

#### Товары (Products)
- Search field
- Barcode scan icon
- Filter funnel icon
- Filter chips: Все / В наличии / Заканчивается / Нет в наличии / **Требует внимания** (NEW)
- + Add product button (top-right)
- Кебаб menu (top-right) — import/export
- Tap product → detail page
- Detail: Приход button, Продать button, edit pencil, delete kebab

#### Касса (POS)
- Search field
- Barcode scan icon
- Quick product chips (no overflow — Phase 1 fix #3)
- Tap chip → adds to cart
- Cart:
  - Item row: −, qty, +, delete
  - Подытог
  - Скидка % chip
  - ИТОГО
- Payment row: Наличные / Карта / В долг / Смешанная
- "Оформить продажу" button
- Cash payment flow:
  - Quick amount chips (500/1000/2000/5000/Без сдачи)
  - Получено от клиента field
  - Сдача card
  - Завершить и печатать чек
- Success page: shows correct total (Phase 1 fix #1), Печатать чек, Telegram, Новая продажа

#### Финансы (Finance dashboard)
- Period chips: День / Неделя / Месяц / 6 мес
- 4 metric cards:
  - **Общий доход** (clamped ≥ 0 — NEW)
  - **Общие расходы** (clamped ≥ 0 — NEW)
  - Валовая прибыль (can be negative)
  - Чистая прибыль (can be negative)
- Динамика chart
- 8 module tiles:
  - Баланс / Кредиты / Вложения / Закят / Валюты / Доставка / Отчёт / Расходы
- Top-right download icon → reports export (PREMIUM only)

#### Ещё (Side menu)
13 items in 5 sections:
- **Продажи и Финансы**: История продаж / Финансы / Расходы / Долги / Закят
- **Персонал**: Сотрудники / Смены / Зарплата / Роли и права
- **Контрагенты**: Клиенты / Поставщики
- **Магазин**: Мои магазины
- **Настройки**: Настройки

#### Настройки (settings page)
- Профиль (QA BUSINESS, role)
- Магазин: Мои магазины / Продавцы / Роли и доступы / Скидки / Шаблоны чеков
- Интеграции: Telegram-бот / ККМ / Принтер чеков / Сканер
- Приложение: Уведомления toggle, Язык, Тема, etc.

## Differences from previous click test (what should appear NEW)

| Item | Before | After |
|------|--------|-------|
| Финансы "Общий доход" | `-127 TJS` | `0 TJS` (clamped) |
| Финансы "Общие расходы" | `-X TJS` possible | `0 TJS` minimum |
| Финансы "Валовая прибыль" | red `-X TJS` | red `-X TJS` (unchanged — loss is real signal) |
| Финансы "Чистая прибыль" | red `-X TJS` | red `-X TJS` (unchanged) |
| Главная → "Вам должны" | red error screen | opens debt list page |
| Главная → "Вы должны" | red error screen | opens supplier debt list page |
| Главная → "Остатки на складе" | opens unfiltered Товары | opens Товары + "Требует внимания" chip pre-selected |
| Товары filter chips | 4 chips | 5 chips (added "Требует внимания") |
| История продаж with bad row | "Не удалось выполнить операцию" | row skipped + footer "X записей пропущено" |
| Sales API rejecting negative `total` | accepted | DB rejects with `sales_total_non_negative` |

## Per-tier feature differences (existing, verify still correct)

| Feature | START | BIZ | PREM |
|---------|-------|-----|------|
| `/reports/*` (hasReportsAll) | 403 | 200 | 200 |
| `/reports/export` (hasExport) | 403 | 403 | 200 |
| `/deliveries/*` (hasDelivery) | 403 | 200 | 200 |
| `/inventory-counts/*` (hasInventory) | 403 | 200 | 200 |
| `/telegram/send-receipt` (hasTelegram) | 403 | 200/400 | 200/400 |
| `/notifications/settings` (hasAllPush) | 403 | 200 | 200 |
| Plan limits — staff | 2 | 10 | ∞ |
| Plan limits — products | 500 | 2000 | ∞ |
| Plan limits — discounts | 0 | 5 | ∞ |

## Per-role permission differences (existing, verify still correct)

| Action | OWNER | ADMIN | CASHIER | WAREHOUSE |
|--------|-------|-------|---------|-----------|
| products.view (list, detail) | ✓ | ✓ | ✓ | ✓ |
| products.manage (create, edit) | ✓ | ✓ | ✗ | ✓ |
| products.delete | ✓ | ✓ | ✗ | ✗ |
| sales.manage (POS create) | ✓ | ✓ | ✓ | ✗ |
| sales.refund | ✓ | ✓ | ✗ | ✗ |
| staff.manage | ✓ | ✓ | ✗ | ✗ |
| roles.manage | ✓ | ✓ | ✗ | ✗ |
| expenses.write | ✓ | ✓ | ✗ | ✗ |
| discounts.write (after Bug #21 fix) | ✓ | ✓ | ✗ | ✗ |
| inventory.write (after Bug #22 fix) | ✓ | ✓ | ✗ | ✓ |
| reports.view (after Bug #23/#24 fix) | ✓ | ✓ | ✗ | ✗ |
| store.manage | ✓ | ✓ | ✗ | ✗ |

## Test approach

For each role × tier:
1. Login (skip if maxStaff blocks the seat)
2. Walk every tab, click every visible button
3. Capture 1 screenshot per screen + record any anomaly
4. Cross-check against the expected matrix above

Findings get logged in `qa/2026-05-11-final-clicktest/RESULTS.md`.
