# Design — Spec J "Loyalty Program"

**Date:** 2026-07-06
**Scope:** Implement a full loyalty points program for BIZ+ stores — settings CRUD, points accrual on sale, redemption at POS, birthday discount, welcome points, and daily expiry cron. Schema changes: one new table (`LoyaltyTransaction`), one new plan flag (`hasLoyalty`). No existing endpoint contracts changed.

---

## Summary

The schema already has `LoyaltySettings` and `loyaltyPoints Int` on `Customer`. This spec wires them into a working system:

1. **Backend** — `loyalty/` module (settings CRUD + customer balance + expiry cron), `SalesService` changes for accrual/redemption/birthday discount, schema migration.
2. **Flutter** — Loyalty settings page, POS redemption UI, customer detail transaction history, receipt line.

All loyalty logic is gated behind `@RequiresFeature('hasLoyalty')` which is enabled on BIZ and PREMIUM plans only.

---

## Data model

### Migration: add `LoyaltyTransaction`

```sql
CREATE TABLE loyalty_transactions (
  id           TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id  TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  store_id     TEXT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  type         TEXT NOT NULL,          -- EARN | REDEEM | EXPIRE | ADJUST
  points       INTEGER NOT NULL,       -- positive for EARN, negative for REDEEM/EXPIRE
  sale_id      TEXT REFERENCES sales(id) ON DELETE SET NULL,
  expires_at   TIMESTAMPTZ,            -- set only on EARN; = now + pointsExpireDays
  note         TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_loyalty_tx_customer ON loyalty_transactions(customer_id, created_at DESC);
CREATE INDEX idx_loyalty_tx_expires  ON loyalty_transactions(expires_at)
  WHERE type = 'EARN';
```

Prisma model:

```prisma
enum LoyaltyTxType {
  EARN
  REDEEM
  EXPIRE
  ADJUST
}

model LoyaltyTransaction {
  id            String        @id @default(uuid())
  customerId    String
  customer      Customer      @relation(fields: [customerId], references: [id], onDelete: Cascade)
  storeId       String
  store         Store         @relation(fields: [storeId], references: [id], onDelete: Cascade)
  type          LoyaltyTxType
  points        Int
  saleId        String?
  sale          Sale?         @relation(fields: [saleId], references: [id], onDelete: SetNull)
  expiresAt     DateTime?     // set only on EARN
  sourceEarnId  String?       // set only on EXPIRE — points to the EARN tx being expired
  note          String?
  createdAt     DateTime      @default(now())

  @@index([customerId, createdAt(sort: Desc)])
  @@index([expiresAt])        // for cron query: WHERE type='EARN' AND expiresAt < now
  @@map("loyalty_transactions")
}
```

### Plan config: add `hasLoyalty`

```prisma
model SubscriptionPlanConfig {
  // existing fields ...
  hasLoyalty   Boolean @default(false)
}
```

Set `hasLoyalty = true` for BIZ and PREMIUM in the seed/migration. START remains `false`.

### `LoyaltySettings` — no schema change needed

Already in schema:
```
isEnabled        Boolean  @default(false)
pointsPerAmount  Int      @default(1)        -- X points per threshold
amountForPoints  Decimal                     -- earn per this many currency units
pointValue       Decimal                     -- 1 point = N currency units
welcomePoints    Int      @default(0)
birthdayDiscount Decimal?                    -- % discount on birthday
pointsExpireDays Int?                        -- null = never expire
```

---

## Backend

### New module: `api/src/modules/loyalty/`

**Files:**
- `loyalty.module.ts`
- `loyalty.service.ts`
- `loyalty.controller.ts`
- `dto/update-loyalty-settings.dto.ts`
- `dto/loyalty-balance-response.dto.ts`

**Endpoints:**

```
GET  /stores/:storeId/loyalty-settings
  → LoyaltySettings (upsert default if not exists)
  Guard: JwtAuthGuard, StoreAccessGuard, RequiresFeature('hasLoyalty')

PUT  /stores/:storeId/loyalty-settings
  body: UpdateLoyaltySettingsDto (all fields optional)
  → LoyaltySettings
  Guard: same + MANAGER/OWNER role

GET  /stores/:storeId/customers/:customerId/loyalty
  → { points: number, transactions: LoyaltyTransaction[] (last 20, desc) }
  Guard: JwtAuthGuard, StoreAccessGuard, RequiresFeature('hasLoyalty')
```

**`LoyaltyService` methods:**

```ts
getSettings(storeId: string): Promise<LoyaltySettings>
updateSettings(storeId: string, dto: UpdateLoyaltySettingsDto): Promise<LoyaltySettings>
getCustomerBalance(storeId: string, customerId: string): Promise<LoyaltyBalanceResponse>

// Called inside SalesService.$transaction — NOT exported as endpoint
earnPoints(tx: PrismaTx, opts: {
  customerId: string;
  storeId: string;
  saleId: string;
  points: number;
  expiresAt: Date | null;
}): Promise<void>

redeemPoints(tx: PrismaTx, opts: {
  customerId: string;
  storeId: string;
  saleId: string;
  points: number;
}): Promise<void>

// Called by cron
expireOverduePoints(): Promise<{ expired: number; customersAffected: number }>
```

### Changes to `SalesService.create`

Inside the existing `$transaction`, after the sale row is created:

```ts
if (loyaltySettings?.isEnabled && dto.customerId && planHasLoyalty) {

  // 1. Birthday discount (applied BEFORE points calculation)
  const customer = await tx.customer.findUnique({ where: { id: dto.customerId } });
  let effectiveTotal = total; // Prisma.Decimal
  if (
    loyaltySettings.birthdayDiscount &&
    customer?.birthday &&
    isBirthday(customer.birthday)  // day+month match UTC today
  ) {
    const discountFactor = new Prisma.Decimal(1).sub(
      loyaltySettings.birthdayDiscount.div(100)
    );
    effectiveTotal = effectiveTotal.mul(discountFactor).toDecimalPlaces(2);
    birthdayDiscountApplied = true;
  }

  // 2. Redemption (dto.redemptionPoints validated ≤ customer.loyaltyPoints)
  if (dto.redemptionPoints && dto.redemptionPoints > 0) {
    const pointValueDecimal = new Prisma.Decimal(loyaltySettings.pointValue);
    const redemptionValue = pointValueDecimal.mul(dto.redemptionPoints);
    effectiveTotal = Prisma.Decimal.max(effectiveTotal.sub(redemptionValue), new Prisma.Decimal(0));
    await loyaltyService.redeemPoints(tx, { customerId: dto.customerId, storeId, saleId: sale.id, points: dto.redemptionPoints });
  }

  // 3. Earn
  const isFirstSale = customer.totalSpent.eq(0);
  const earned = Math.floor(
    effectiveTotal.div(loyaltySettings.amountForPoints).toNumber()
  ) * loyaltySettings.pointsPerAmount + (isFirstSale ? loyaltySettings.welcomePoints : 0);

  if (earned > 0) {
    const expiresAt = loyaltySettings.pointsExpireDays
      ? addDays(new Date(), loyaltySettings.pointsExpireDays)
      : null;
    await loyaltyService.earnPoints(tx, { customerId: dto.customerId, storeId, saleId: sale.id, points: earned, expiresAt });
  }

  // Return birthday flag so Flutter can render it
  saleResponse.birthdayDiscountApplied = birthdayDiscountApplied;
  saleResponse.pointsEarned = earned;
}
```

`CreateSaleDto` additions:
```ts
@IsOptional()
@IsInt()
@Min(0)
redemptionPoints?: number;
```

`CreateSaleResponse` additions:
```ts
birthdayDiscountApplied: boolean;
pointsEarned: number;
pointsBalance: number; // customer's balance after this sale
```

### Expiry cron

In `LoyaltyService`, decorated with `@Cron('0 2 * * *')` (02:00 daily, server time):

```ts
async expireOverduePoints(): Promise<void> {
  const now = new Date();
  // Find EARN transactions that are expired and have no matching EXPIRE tx
  const overdue = await this.prisma.loyaltyTransaction.findMany({
    where: {
      type: 'EARN',
      expiresAt: { lt: now },
      customer: {
        // has no EXPIRE tx for this earn tx — tracked by noting saleId link
        // simpler: find customers where sum of EARN expires_at<now > sum of EXPIRE
      },
    },
    // Batch: take 100 at a time to avoid lock contention
    take: 100,
  });
  // For each, create EXPIRE tx and decrement customer.loyaltyPoints in $transaction
}
```

Cron query:
```ts
// Find EARN txs that are expired and have no matching EXPIRE tx (via sourceEarnId)
const overdueEarns = await prisma.loyaltyTransaction.findMany({
  where: {
    type: 'EARN',
    expiresAt: { lt: now },
    // no EXPIRE row references this EARN
    NOT: { id: { in: alreadyExpiredEarnIds } }, // pre-fetched
  },
  take: 100, // process in batches to avoid lock contention
});
// For each: create EXPIRE tx with sourceEarnId = earn.id, decrement customer.loyaltyPoints
```
`alreadyExpiredEarnIds` = distinct `sourceEarnId` values from existing EXPIRE rows (fetched once per cron run).

---

## Flutter

### New: `LoyaltySettingsPage`

Path: `app/lib/presentation/pages/settings/loyalty_settings_page.dart`

- Navigated from `SettingsPage` only when plan is BIZ+ (checked via `SubscriptionBloc` state)
- Loads settings on init via `LoyaltySettingsBloc`
- Form fields:
  - Toggle: "Программа лояльности активна"
  - "За каждые __ сом начислять __ баллов" (two fields)
  - "1 балл = __ сом" (`pointValue`)
  - "Приветственные баллы" (`welcomePoints`)
  - "Скидка в день рождения, %" (`birthdayDiscount`, nullable)
  - "Срок действия баллов, дней" (`pointsExpireDays`, nullable — пустое поле = не истекают)
- Save button → `LoyaltySettingsBloc.add(LoyaltySettingsSaved(dto))`

**New files:**
- `app/lib/presentation/blocs/loyalty/loyalty_settings_bloc.dart`
- `app/lib/data/datasources/remote/loyalty_remote_datasource.dart`
- `app/lib/data/repositories/loyalty_repository_impl.dart`
- `app/lib/domain/repositories/loyalty_repository.dart`

### Modified: `CartBloc` + `PosCheckoutPage`

**`CartBloc` state** gets two new fields:
```dart
final int customerLoyaltyPoints;   // loaded when customer selected
final int redemptionPoints;        // 0 by default
```

**New events:**
- `LoyaltyBalanceLoaded(int points)` — fired after customer selected
- `RedemptionPointsChanged(int points)` — fired from redemption dialog

**`PosCheckoutPage`** — above "Оформить" button, if `customerLoyaltyPoints > 0`:

```
┌─────────────────────────────────────────┐
│ 🎁  1 250 баллов = 125 сом   [Списать] │
└─────────────────────────────────────────┘
```

Tap "Списать" → `BottomSheet`:
- Slider 0 … min(customerLoyaltyPoints, maxRedeemable)
  - `maxRedeemable = floor(cartTotal / pointValue)`
- Shows "Скидка: −X сом" live
- "Применить" → `CartBloc.add(RedemptionPointsChanged(points))`

`CreateSaleDto` on checkout includes `redemptionPoints` from bloc state.

### Modified: `CustomerDetailPage`

Below the existing loyalty points chip — collapsible section "История баллов":
- Last 10 transactions, each row: `[EARN/REDEEM/EXPIRE] +/− N баллов  дата`
- "EARN" → green, "REDEEM" → blue, "EXPIRE" → grey
- Data fetched from `GET /stores/:id/customers/:cid/loyalty`

### Modified: Receipt (thermal + on-screen)

Add at the bottom of receipt template:

```
Начислено баллов:  +125
Ваш баланс:       1 375 баллов
Действует до:     15.07.2026
```

Fields sourced from `CreateSaleResponse.pointsEarned` and `pointsBalance`.

---

## Testing

### Backend — `api/src/modules/loyalty/loyalty.service.spec.ts` (new)

```
should return default settings when none exist for store
should earn correct points on sale
should add welcomePoints on first sale (totalSpent === 0)
should not add welcomePoints on subsequent sales
should redeem points and create REDEEM transaction
should reject redemption exceeding customer balance
should apply birthdayDiscount when customer birthday matches today (day+month)
should not apply birthdayDiscount when birthday is tomorrow
should not earn points when loyalty isEnabled = false
should not earn points when plan is START (no hasLoyalty)
should expire overdue EARN transactions and decrement loyaltyPoints
should not double-expire already-expired transactions
```

### Backend — `api/src/modules/loyalty/loyalty.controller.spec.ts` (new)

```
should return 403 for START plan on GET /loyalty-settings
should upsert settings for BIZ store
should return customer balance and last 20 transactions
```

### Flutter — `app/test/presentation/blocs/loyalty/loyalty_settings_bloc_test.dart` (new)

```
should emit LoyaltySettingsLoaded when settings are fetched
should emit LoyaltySettingsSaved when save succeeds
should emit LoyaltySettingsError when save fails
```

### Flutter — `app/test/presentation/blocs/pos/cart_bloc_loyalty_test.dart` (new)

```
should load loyalty balance when customer is selected
should apply redemption and reduce displayed total
should clear redemption points when customer is removed
should cap redemption at floor(cartTotal / pointValue)
```

---

## Files touched

**Create:**
- `api/prisma/migrations/YYYYMMDD_add_loyalty_transactions/migration.sql`
- `api/src/modules/loyalty/loyalty.module.ts`
- `api/src/modules/loyalty/loyalty.service.ts`
- `api/src/modules/loyalty/loyalty.controller.ts`
- `api/src/modules/loyalty/dto/update-loyalty-settings.dto.ts`
- `api/src/modules/loyalty/dto/loyalty-balance-response.dto.ts`
- `api/src/modules/loyalty/loyalty.service.spec.ts`
- `api/src/modules/loyalty/loyalty.controller.spec.ts`
- `app/lib/presentation/pages/settings/loyalty_settings_page.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_settings_bloc.dart`
- `app/lib/data/datasources/remote/loyalty_remote_datasource.dart`
- `app/lib/data/repositories/loyalty_repository_impl.dart`
- `app/lib/domain/repositories/loyalty_repository.dart`
- `app/test/presentation/blocs/loyalty/loyalty_settings_bloc_test.dart`
- `app/test/presentation/blocs/pos/cart_bloc_loyalty_test.dart`

**Modify:**
- `api/prisma/schema.prisma` — add `LoyaltyTransaction` model + `hasLoyalty` flag
- `api/src/modules/sales/sales.service.ts` — accrual/redemption/birthday logic
- `api/src/modules/sales/dto/create-sale.dto.ts` — add `redemptionPoints`
- `api/src/app.module.ts` — register `LoyaltyModule`
- `app/lib/presentation/blocs/pos/cart_bloc.dart` — loyalty balance + redemption state
- `app/lib/presentation/pages/pos/pos_checkout_page.dart` — redemption UI
- `app/lib/presentation/pages/customer/customer_detail_page.dart` — transaction history
- `app/lib/core/services/thermal_printer_service.dart` — points line on receipt
- `app/lib/presentation/pages/settings/settings_page.dart` — add Loyalty Settings tile

---

## Acceptance

- `npm test` ≥ 254 (241 + 13 new)
- `flutter test` ≥ 447 (444 + 3+ new)
- `npx tsc --noEmit` — 0 errors
- `dart analyze lib/` — 0 issues
- `GET /stores/:id/loyalty-settings` returns 403 for START plan
- `POST /stores/:id/sales` with `redemptionPoints: 50` → customer.loyaltyPoints decremented, REDEEM transaction created
- Expiry cron: EARN tx with `expiresAt` in past → EXPIRE tx created, balance decremented
- BIZ store: loyalty settings tile visible in Flutter settings
- START store: loyalty settings tile hidden

## Out of scope

- Cross-store loyalty (points are per-store, not global)
- Points transfer between customers
- Loyalty card / QR code generation
- Push notification on points earned (can be added in Spec K)
- Admin panel loyalty dashboard
- Shariah compliance review of `birthdayDiscount` (product decision)
