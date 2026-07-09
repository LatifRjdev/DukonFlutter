# Design — Spec K "Feature Completion"

**Date:** 2026-07-09
**Scope:** Three independent features that complete partially-wired capabilities: Excel data export, Telegram push notifications on loyalty points, and a loyalty analytics dashboard.

---

## Summary

Spec K closes three open flags/stubs left by previous specs:

| Feature | Prior stub | Closes |
|---|---|---|
| Excel export | `hasExport` flag on PREMIUM, no endpoint | D.2 backlog |
| Telegram push on loyalty | Spec J explicit defer | Spec J out-of-scope |
| Loyalty analytics | No analytics surface for loyalty data | Natural follow-on to J |

All three are additive — no breaking changes to existing endpoints, no migrations required except one nullable column on `Customer`.

**Tech stack:** NestJS + Prisma + Flutter. Architecture follows Approach A: extend existing modules (`ReportsModule`, `LoyaltyModule`, `CustomersModule`) rather than creating new top-level modules.

---

## Feature 1 — Excel Export

### Backend

**Module:** `ReportsModule` (extend existing)

**New files:**
- `api/src/modules/reports/export.service.ts` — data fetching + xlsx generation
- `api/src/modules/reports/dto/export-query.dto.ts` — `type: 'sales' | 'products' | 'customers'`

**Endpoint:**
```
GET /stores/:storeId/reports/export?type=sales|products|customers
```

Guards: `JwtAuthGuard`, `StoreAccessGuard`, `@RequiresFeature('hasExport')` (PREMIUM+).

Response: binary xlsx file, headers:
```
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="export-{type}-{YYYY-MM-DD}.xlsx"
```

**Columns per type:**

`sales`:
| дата | чек № | клиент | товары | итого | тип оплаты | скидка | баллы списано |

`products`:
| название | штрихкод | категория | цена продажи | себестоимость | остаток | единица |

`customers`:
| имя | телефон | баллы | потрачено всего | долг | дата регистрации |

**Implementation:** Use existing `xlsx` npm package (Community Edition, already installed). Will be migrated to `exceljs` in Spec L when the dependency audit runs. `ExportService` calls existing service/repository methods — no new DB queries beyond what reports already do. No pagination limit on export rows (merchant wants all data).

**Tests:** `export.service.spec.ts` — 3 tests: sales workbook has correct headers, products workbook has correct column count, customers workbook row count matches fake data.

### Flutter

**Modified:** `lib/presentation/pages/reports/reports_page.dart`

Add "Экспортировать" button (visible only if subscription has `hasExport`; check from existing `SubscriptionBloc`). On tap:
1. Show loading indicator
2. `GET /stores/:storeId/reports/export?type=sales` (default) with bottom sheet to pick type
3. Save bytes via `path_provider` + `open_file` package (already in pubspec)

No new bloc needed — one-shot async call directly in page, result handled with `AppSnackbar`.

---

## Feature 2 — Telegram Push on Loyalty Points

### Backend

**Schema change:**
```prisma
model Customer {
  // existing fields ...
  telegramChatId  String?   // nullable — only set when cashier links account
}
```
Migration: `ALTER TABLE customers ADD COLUMN "telegramChatId" TEXT`.

**New endpoint:**
```
PUT /stores/:storeId/customers/:customerId/telegram
Body: { "username": "@alisher" }
```

Logic:
1. Call Telegram Bot API: `GET https://api.telegram.org/bot{TOKEN}/getChat?chat_id=@{username}`
2. On success: save `chatId` (numeric string) to `customer.telegramChatId`
3. On Telegram 400 (user not found or privacy): throw `NotFoundException('Telegram user not found')`

Implemented in `CustomersService.linkTelegram()`, exposed via new method in `CustomersController`. Guard: `JwtAuthGuard` + `StoreAccessGuard`.

**Push hook in LoyaltyService:**

In `earnPoints()`, after committing the transaction, fire-and-forget:

```typescript
// Customer notification (if linked)
if (customer.telegramChatId) {
  this.telegramService.sendMessage(
    customer.telegramChatId,
    `Вам начислено +${points} баллов за покупку. Баланс: ${newBalance} баллов 🎉`,
  ).catch(() => {}); // fire-and-forget — never fails the sale
}

// Store owner notification
if (storeChatId) {
  this.telegramService.sendMessage(
    storeChatId,
    `Клиент ${customer.name} получил +${points} баллов (покупка: ${saleTotal} сом)`,
  ).catch(() => {});
}
```

`storeChatId` comes from `TelegramBotService.getStoreChatId(storeId)` — `TelegramModule` exports `TelegramBotService`, which is imported into `LoyaltyModule`. This is the same pattern used by `NotificationsModule`.

**Error handling:** Push failures are completely silent — catch and ignore. A Telegram outage must never fail a sale or loyalty transaction.

**Tests:** 2 tests in `loyalty.service.spec.ts`:
- `earnPoints` sends customer push when `telegramChatId` is set
- `earnPoints` does not throw when Telegram call rejects

### Flutter

**Modified files:**
- `lib/presentation/pages/customer/customer_form_page.dart` — add optional "Telegram username" text field (`@username` prefix). On save, if field non-empty, call link endpoint separately after main customer save (fire-and-forget; show snackbar on error, don't fail the customer save).
- `lib/presentation/pages/customer/customer_detail_page.dart` — show Telegram icon (blue) next to customer name if `customer.telegramChatId != null`.

**Customer entity:** Add `telegramChatId String?` field, map from API response.

---

## Feature 3 — Loyalty Analytics Dashboard

### Backend

**New endpoint:**
```
GET /stores/:storeId/loyalty/analytics?from=YYYY-MM-DD&to=YYYY-MM-DD
```

Guard: `@RequiresFeature('hasLoyalty')`, `JwtAuthGuard`, `StoreAccessGuard`.

Added to existing `LoyaltyController`. Logic in `LoyaltyService.getAnalytics()`.

**Response:**
```typescript
{
  period: { from: string, to: string },
  totalEarned: number,        // sum of points where type=EARN in period
  totalRedeemed: number,      // sum of abs(points) where type=REDEEM in period
  totalExpired: number,       // sum of abs(points) where type=EXPIRE in period
  discountValue: number,      // totalRedeemed × loyaltySettings.pointValue (in сом)
  activeParticipants: number, // count of customers with loyaltyPoints > 0
  topCustomers: Array<{
    customerId: string,
    name: string,
    balance: number,          // current Customer.loyaltyPoints
    totalEarned: number,      // lifetime EARN sum for this customer
  }>                          // top 10 by balance
}
```

Implementation: 3 Prisma aggregates (groupBy type for period totals, count for participants, findMany ordered by loyaltyPoints for top customers). All in one `LoyaltyService.getAnalytics()` call — no N+1.

**Tests:** `loyalty.service.spec.ts` — 2 tests:
- Returns correct aggregates for a period with mixed EARN/REDEEM/EXPIRE transactions
- Returns empty/zero values when no transactions exist in period

### Flutter

**New files:**
- `lib/presentation/blocs/loyalty/loyalty_analytics_event.dart`
- `lib/presentation/blocs/loyalty/loyalty_analytics_state.dart`
- `lib/presentation/blocs/loyalty/loyalty_analytics_bloc.dart`
- `lib/presentation/pages/settings/loyalty_analytics_page.dart`
- `lib/domain/entities/loyalty_analytics.dart`

**New route:** `RouteNames.loyaltyAnalytics = '/settings/loyalty/analytics'`

**Entry point:** Button "Аналитика →" at the top of `LoyaltySettingsPage`.

**Page layout:**
1. Period picker chip row: `Неделя | Месяц | Год | Свой` (default: текущий месяц)
2. 4 stat cards (2×2 grid):
   - Начислено: N баллов
   - Списано: N баллов
   - Сгорело: N баллов
   - Экономия: N сом
3. "Активных участников: N" — single text line
4. "Топ клиентов" list — 10 rows, each with name, balance, и LinearProgressIndicator relative to top-1 balance

**DI:** `LoyaltyAnalyticsBloc` registered in `injection.dart` + `app.dart` `MultiBlocProvider`.

**Tests:** `loyalty_analytics_bloc_test.dart` — 3 tests (Loaded, period change triggers reload, Error state on network failure).

---

## Data flow summary

```
Cashier links customer Telegram
  → PUT /customers/:id/telegram
  → TelegramService.getChat(@username) → chatId saved

Sale created with loyalty
  → SalesService → LoyaltyService.earnPoints()
  → TelegramService.sendMessage (customer + store, fire-and-forget)

Manager opens analytics
  → LoyaltyAnalyticsBloc → GET /loyalty/analytics?from=&to=
  → 4 stat cards + top-10 list

Manager exports data
  → GET /reports/export?type=sales
  → xlsx binary → save to device → open_file
```

---

## Testing summary

| File | New tests |
|---|---|
| `export.service.spec.ts` | 3 (headers, column count, row count) |
| `loyalty.service.spec.ts` | 4 (analytics aggregates ×2, push sent ×1, push fail silent ×1) |
| `customers.service.spec.ts` | 2 (linkTelegram success, linkTelegram not found) |
| `loyalty_analytics_bloc_test.dart` | 3 (Loaded, period change, Error) |

All existing 260 API tests and 453 Flutter tests must remain green.

---

## Out of scope

- Push notifications for REDEEM or EXPIRE events (earn only)
- Export filtering by date range (full data dump only — filter can be added in Spec L)
- Loyalty card / QR code generation
- Cross-store loyalty analytics
- `exceljs` migration (Spec L)
