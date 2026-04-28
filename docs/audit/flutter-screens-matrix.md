# Flutter Screens Dynamic Audit — 2026-04-10

**Device:** Android emulator-5554 (Pixel ~6.0" screen, 1080x2400)
**App version:** com.itlsolutions.dukonpro (debug build)
**Locale during audit:** ru (Russian) — tg/uz switch NOT tested (deferred to next pass)
**User logged in:** `+992901234567` / Latif Test (OWNER role)
**Backend:** http://localhost:4455/api (NestJS, local)
**Sessions combined:** 2026-04-10 evening + 2026-04-11 morning

## Legend

- ✓ = works as expected
- ⚠ = works but with issues (P2/P3)
- ✗ = broken (P0/P1)
- ⊘ = unwired / stubbed (tile has no onTap or route missing)
- ? = couldn't reach / not tested

## Navigation Tree Walked

| # | Route | Screen | Loads? | Interactive elements tested | Issues |
|---|-------|--------|--------|------------------------------|--------|
| 0 | — | Native Android splash | ⚠ | n/a | FD-001 default Flutter logo instead of brand splash |
| 1 | `/onboarding` | Onboarding slides | ✓ | Next/Skip | FD-002 skip button small target (<48dp) |
| 2 | `/login` | Phone login | ✓ | Phone input, password, submit | FD-003 rate limiter triggers on 2nd failed attempt (too aggressive for real users) |
| 3 | `/store/create` | First store creation | ✗ | Form fields, submit | FD-004 accepts `'; DROP TABLE users; --` as store AND user name — no sanitization (stored XSS vector) |
| 4 | `/` (Главная tab) | Dashboard | ⚠ | Period tabs (Сегодня/Неделя/Месяц/6мес), sync banner, store picker, quick action grid | FD-005 stored XSS payload rendered verbatim in header + store dropdown; FD-006 duplicate "Чистая прибыль" card shown twice; FD-007 sync banner switches red on zakat/settings 200-empty; FD-008 splash-to-ready >10s on warm launch; cold start ≈6s |
| 5 | `/products` (Товары tab) | Product list | ✓ | Search, list, tap item | FD-009 loads empty but UI works; pull-to-refresh OK |
| 6 | `/products/add` | Add product wizard | ⚠ | 3 steps, validation, save | FD-010 step-1 validation reported; FD-011 save returned to list but "1 операция в очереди" hung (sync failure silent) |
| 7 | `/pos` (Касса tab) | POS screen | ✓ | Product select, cart, amount | Works; already documented in matrix session 1 |
| 8 | `/pos/checkout` | Checkout | ✓ | Cash confirm, receipt | Works |
| 9 | `/sales/history` (Ещё → История продаж) | Sales history | ✓ | List, filter | Loads; appears functional |
| 10 | `/finance` (Финансы tab) | Finance dashboard | ⚠ | 8-tile grid, period filter, "Динамика" chart, 4 KPI cards | FD-012 only 2/8 tiles wired: Закят (→ crashes), Расходы (→ works). 6/8 have empty `() {}` onTap: **Баланс, Кредиты, Вложения, Валюты, Доставка, Отчёт**. Pages do NOT exist in codebase (no `finance/balance_page.dart`, etc). Dead UI. |
| 11 | `/finance/balance` | Balance | ⊘ | — | FD-013 tile unwired; no page file |
| 12 | `/finance/credits` | Credits | ⊘ | — | FD-014 tile unwired; no page file (only POS `credit_sale_page.dart` exists, unrelated) |
| 13 | `/finance/investments` | Investments | ⊘ | — | FD-015 tile unwired; no page file |
| 14 | `/finance/currencies` | Currencies | ⊘ | — | FD-016 tile unwired; no page file |
| 15 | `/finance/delivery` | Delivery | ⊘ | — | FD-017 tile unwired; no page file |
| 16 | `/finance/reports` | Financial report | ⊘ | — | FD-018 tile unwired; `z_report_page.dart` exists in shifts but not linked |
| 17 | `/expenses` | Expenses | ✓ | Back works, appears to load | Not deeply tested; screenshot captured |
| 18 | `/debts` | Debts overview | ✓ | Tabs (долги/покупатели/поставщики) | Not deeply tested; loads |
| 19 | `/zakat` (Финансы → Закят OR Ещё → Закят) | Zakat calculator | ✗ | Loaded then error banner | **FD-019 P0 CRASH**: red inline error `type 'String' is not a subtype of type 'Map<String, dynamic>' in type cast`. Root cause: `GET /api/stores/:id/zakat/settings` returns **HTTP 200 with 0-byte body + no content-type** when no ZakatSettings row exists. Backend bug: `zakat.service.ts:68-72 getSettings()` does `findUnique` → returns `null` → NestJS serializes as empty body instead of `{}` or 404. Flutter DTO parser fails cast. **Two bugs — backend AND frontend null-safety missing.** |
| 20 | `/staff` (Ещё → Сотрудники) | Staff list | ✗ | Header, + FAB | **FD-020 P0 CRASH**: `type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast`. Backend returns bare `[{...}]` array for `GET /stores/:id/staff`, parser expects wrapped object. Inline red error mid-screen. FAB still visible (can add) but list never renders. |
| 21 | `/shifts` (Ещё → Смены) | Shifts list | ⚠ | — | Works, empty state "Нет смен". FD-021 P2: no CTA to open a shift (no FAB, no button). Users cannot start a shift from this screen. |
| 22 | `/payroll` (Ещё → Зарплата) | Payroll | ⚠/✗ | Month selector, Рассчитать button | Page loads OK with empty state. **FD-022 P0 CRASH**: tapping "Рассчитать" triggers snackbar + inline red `type 'Null' is not a subtype of type 'String' in type cast`. Nullable field mapped as non-nullable in DTO. |
| 23 | `/roles` (Ещё → Роли и права) | Roles & permissions | ✓ | 4 role tabs (Владелец/Админ/Кассир/Складовщик), ~13 permission toggles per role, scroll | Works visually. FD-023 P2: toggles appear greyed — could not verify write-through (write-through not tested). |
| 24 | `/customers` (Ещё → Клиенты) | Customer list | ✗ | Search, filter chips (Все/С долгом/VIP/Новые), + FAB | **FD-024 P0 CRASH**: same `List → Map` cast error. Same root cause class as staff. |
| 25 | `/suppliers` (Ещё → Поставщики) | Supplier list | ✗ | Tap tile | **FD-026 P0 CONFIRMED (crash-only)**: on fresh `flutter clean && flutter build apk --debug && adb install -r`, tapping the real "Поставщики" tile routes correctly to `/suppliers` (logcat: `GET .../suppliers?page=1&limit=20`), title renders as "Поставщики" with "Поиск поставщика" placeholder. **BUT** the screen then crashes with the same `type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast` error as staff and customers. Same root cause class: backend returns bare `[...]` array, Flutter parser expects wrapped object. |
| 26 | `/settings` (Ещё → Настройки) | Settings root | ? | — | Could not tap (adb hit miss at y≈1931 on bottom of menu; unconfirmed whether tile is hit-test-blocked by bottom nav overlay). Route wired in `more_page.dart:106` and `app_router.dart`. Manual verification deferred. |
| 27 | Bottom nav "Ещё" | More menu | ✓ | 12 items (5 Продажи/Финансы + 4 Персонал + 2 Контрагенты + 1 Настройки) | Works; scroll works; items labeled correctly. FD-025 P3: "Поставщики" label + icon correct but items at 81px tall (~38dp) — below 48dp touch target minimum |

## Groups NOT reached / NOT tested

| Feature group | Reason | Impact |
|---|---|---|
| `/stock` (Inventory adjustments) | No entry found in bottom nav or Ещё menu within 15min walk | Medium — feature exists in `lib/presentation/pages/stock/` but looks orphaned from nav |
| `/sales/:id` (Sale detail) | Did not drill from history list | Low — visual-only |
| `/customers/:id`, `/suppliers/:id` | Gated by list crashes (FD-024) | Blocked by upstream |
| `/store/edit`, store picker modal | Briefly seen on dashboard header; not drilled | Low |
| `/profile`, profile edit | Not found in nav | Medium — if unreachable, users can't edit own name/phone |
| i18n: tg, uz | Deferred to next pass | High — locale coverage is a P1 quality gate for Tajikistan market |
| Airplane mode / offline sync queue behavior | Deferred to Pass 5 | High — core product promise |
| Accessibility (TalkBack, contrast, touch targets systematic) | Deferred to Pass 6 | Medium |
| Performance (jank, startup, memory, bundle size) | Deferred to Pass 6 | Medium |

## Cross-cutting findings summary

| ID | Severity | Title | Affected screens |
|----|----------|-------|---------------------|
| FD-004/FD-005 | **P0** | Stored input not sanitized; dangerous string rendered verbatim in UI | store create, dashboard header, every API response using user/store name |
| FD-019 | **P0** | Zakat screen crash — backend returns 200-empty, frontend cast fails | /zakat |
| FD-020 | **P0** | Staff list crash — List → Map cast mismatch | /staff |
| FD-022 | **P0** | Payroll "Рассчитать" crash — Null → String cast | /payroll |
| FD-024 | **P0** | Customers list crash — same List → Map pattern as staff | /customers |
| FD-026 | **P0** | Suppliers list crashes with same List→Map cast as staff/customers (routing is correct) | /suppliers |
| FD-012 | **P1** | 6/8 finance tiles have empty onTap, pages never built | /finance |
| FD-006 | **P1** | Duplicate "Чистая прибыль" KPI card on dashboard | / |
| FD-011 | **P1** | Add product "success" path silently leaves orphan sync queue | /products/add |
| FD-008 | **P1** | Cold start ≈6s, warm launch >10s — above P1 perf budget | app-wide |
| FD-003 | **P2** | Rate limiter too aggressive (trips on 2nd failed login) | /login |
| FD-021 | **P2** | No CTA to open shift from empty Shifts screen | /shifts |
| FD-007 | **P2** | Sync banner flips to red on zakat empty-200 (false positive) | all screens |
| FD-001, FD-002, FD-025, FD-023 | P3 | Polish: default Flutter splash, small hit targets, unverified toggle state | various |

## Crash pattern — root cause analysis

Four out of five observed crashes share the same class: **Flutter DTO parser casts `dynamic` API response into `Map<String, dynamic>` without null/shape checking**. Backend returns:

1. bare array `[...]` (staff, customers, likely suppliers) — parser expects `{ data: [...] }` wrapper
2. empty body / null (zakat/settings) — parser expects `{}`
3. object with nullable fields present but `null` (payroll) — parser treats field as `String`

**Recommended fix (frontend):** introduce `ApiResponse<T>` decoder that
- accepts both raw and wrapped responses,
- treats empty-body 200 as empty object,
- uses nullable types in DTOs matching Prisma schema nullability.

**Recommended fix (backend):** `ZakatService.getSettings()` should return `{}` (or 404 with structured body) instead of `null` so NestJS serializer does not produce empty body. Same pattern check needed in every `findUnique` handler across modules.
