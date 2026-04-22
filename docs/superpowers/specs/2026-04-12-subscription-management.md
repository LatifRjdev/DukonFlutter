# Subscription Management — Full Spec

**Date**: 2026-04-12
**Goal**: Manual subscription management with hybrid payment flow — user requests + admin confirms. Feature gating by plan.

---

## Plans & Pricing

| | START (200 сом./мес) | BUSINESS (400 сом./мес) | PREMIUM (600 сом./мес) |
|--|---|---|---|
| **Магазины** | 1 | 3 | 5 |
| **Товары** | 500 | 2 000 | Безлимит (-1) |
| **Сотрудники (суммарно)** | 2 | 10 | Безлимит (-1) |
| **Продажи** | Безлимит | Безлимит | Безлимит |
| **Отчёты** | Только продажи | Все 5 вкладок | Все + экспорт PDF/Excel |
| **Telegram-чеки** | Нет | Да | Да |
| **Push-уведомления** | Базовые (LOW_STOCK) | Все | Все |
| **Доставки** | Нет | Да | Да |
| **Инвентаризация** | Нет | Да | Да |
| **Скидки (правила)** | Нет | 5 правил | Безлимит (-1) |
| **Валюты** | Да | Да | Да |
| **Trial** | — | — | 7 дней бесплатно |
| **Админ-скидка** | Да | Да | Да |

## Architecture

### Prisma Schema Updates

**New model — SubscriptionPlanConfig:**
```prisma
model SubscriptionPlanConfig {
  plan          SubscriptionPlan @id
  price         Decimal          @db.Decimal(12,2)
  maxStores     Int
  maxProducts   Int              // -1 = unlimited
  maxStaff      Int              // -1 = unlimited
  maxDiscounts  Int              // -1 = unlimited
  hasReportsAll Boolean
  hasExport     Boolean
  hasTelegram   Boolean
  hasAllPush    Boolean
  hasDelivery   Boolean
  hasInventory  Boolean

  @@map("subscription_plan_configs")
}
```

**Modify existing Subscription model — add:**
```prisma
  adminDiscount  Decimal?  @db.Decimal(5,2)  // percentage discount set by admin
```

**Modify existing Payment model — add:**
```prisma
  receiptImage   String?          // URL of uploaded payment screenshot
  note           String?          // admin comment (rejection reason, etc.)
  reviewedAt     DateTime?
  reviewedBy     String?          // admin userId who reviewed
```

**PaymentStatus enum** (already exists, verify values):
```prisma
enum PaymentStatus {
  PENDING
  APPROVED
  REJECTED
}
```

### Backend — Subscription Module

**Controller**: `@Controller` with mixed routes

**User endpoints (JWT + StoreAccess):**
- `GET /subscription/plans` — list all plans with prices and features (public, no auth)
- `GET /stores/:storeId/subscription` — current subscription: plan, status, expiresAt, limits, discount, active features
- `POST /stores/:storeId/subscription/request-change` — body: `{plan: "BUSINESS", paymentMethod: "CARD"}` → creates Payment with status PENDING
- `POST /stores/:storeId/subscription/upload-receipt` — multipart file upload → saves image URL to Payment.receiptImage
- `GET /stores/:storeId/subscription/payments` — payment history for this store

**Admin endpoints (JWT + AdminGuard):**
- `GET /admin/subscriptions` — all subscriptions with filters (status, plan, search by store name)
- `GET /admin/subscriptions/pending-payments` — payments awaiting review
- `PUT /admin/subscriptions/:id/approve-payment/:paymentId` — approve → set Payment.status=APPROVED, activate subscription (set Subscription.status=ACTIVE, extend currentPeriodEnd by 30 days)
- `PUT /admin/subscriptions/:id/reject-payment/:paymentId` — body: `{reason}` → set Payment.status=REJECTED, note=reason
- `PUT /admin/subscriptions/:id/extend` — body: `{days}` → manually extend currentPeriodEnd
- `PUT /admin/subscriptions/:id/change-plan` — body: `{plan}` → manually change plan
- `PUT /admin/subscriptions/:id/set-discount` — body: `{percent}` → set adminDiscount (0 to remove)
- `PUT /admin/subscriptions/:id/cancel` — set status=CANCELLED

**AdminGuard**: New `isAdmin Boolean @default(false)` field on User model. AdminGuard checks `user.isAdmin === true`. Set manually in DB for the first admin user. Admin endpoints return 403 if `isAdmin` is false.

### Auto-Trial on Store Creation

When `POST /stores` creates a new store:
1. Auto-create Subscription: `plan=PREMIUM, status=TRIAL, trialEndsAt=now+7days, currentPeriodStart=now, currentPeriodEnd=now+7days`
2. No payment required during trial

### Cron Jobs (ScheduleModule)

In SubscriptionService:
- `@Cron('0 0 * * *')` — daily at midnight:
  - Find subscriptions where `currentPeriodEnd < now` AND status IN (ACTIVE, TRIAL) → set status=EXPIRED
  - Send push notification: "Подписка истекла. Продлите для продолжения работы"
- `@Cron('0 9 * * *')` — daily at 09:00:
  - Find subscriptions where `currentPeriodEnd` is within 3 days AND status=ACTIVE → send push: "Подписка заканчивается через X дней"

## Flutter — Subscription UI

### SubscriptionPage (replace existing read-only page)

**Top card — current plan:**
- Gradient card: plan name, status badge (green ACTIVE, blue TRIAL, red EXPIRED), expiry date
- Trial mode: "PREMIUM (пробный) — осталось X дней"
- Expired: red badge "Подписка истекла"
- If adminDiscount > 0: show "Скидка {percent}%: ~~{original}~~ → {discounted} сом."

**Plan cards — 3 selectable cards:**
- Each: name, price, feature checklist (checkmark/cross icons)
- Current plan highlighted with primary border
- "Выбрать" button on non-current plans

**"Выбрать" flow:**
1. Bottom sheet: payment method selection
   - "Перевод на карту" → shows card number, holder name, "Я перевёл" button
   - "Наличные" → shows contact info: "+992 XX XXX XXXX"
2. After "Я перевёл" → image picker (camera or gallery) to upload receipt screenshot
3. Upload via `POST /stores/:storeId/subscription/upload-receipt`
4. Show status: "⏳ Заявка отправлена, ожидайте подтверждения"

**Pending payment banner:**
If there's a PENDING payment → show yellow banner at top: "Ожидает подтверждения оплаты"

**Payment history section:**
- Scrollable list at bottom: date, amount, method, status badge (green/yellow/red)
- Tap → detail with receipt image thumbnail and admin note

### SubscriptionBloc

New BLoC to manage subscription state app-wide:
- `SubscriptionState`: plan, status, limits (maxProducts, maxStaff, etc.), features (hasTelegram, hasDelivery, etc.)
- Loaded at app start after login
- Refreshed when returning to SubscriptionPage
- Consumed by PlanGate widgets and feature checks

### Notifications
- Push on approval: "Подписка {plan} активирована до {date}"
- Push on rejection: "Платёж отклонён: {reason}"
- Push 3 days before expiry: "Подписка заканчивается через 3 дня"
- Push on expiry: "Подписка истекла. Продлите для продолжения работы"

## Feature Gating

### Backend — SubscriptionGuard

New guard `SubscriptionGuard` + decorator `@RequiresPlan(minPlan)` and `@RequiresFeature(feature)`.

Checks:
1. Subscription status is ACTIVE or TRIAL
2. Current plan meets minimum requirement (START < BUSINESS < PREMIUM)
3. Or specific feature flag is true for current plan

Returns 403 if blocked: `{code: "SUBSCRIPTION_REQUIRED", requiredPlan: "BUSINESS", feature: "delivery", currentPlan: "START"}`

**Endpoints gated:**

| Endpoint | Min Plan | Feature |
|----------|----------|---------|
| `POST /stores` (2nd+ store) | BUSINESS | maxStores check |
| `POST /deliveries` | BUSINESS | hasDelivery |
| `POST /inventory-counts` | BUSINESS | hasInventory |
| `POST /discounts` | BUSINESS | maxDiscounts check |
| `POST /telegram/send-receipt` | BUSINESS | hasTelegram |
| `GET /reports/profit` | BUSINESS | hasReportsAll |
| `GET /reports/products` | BUSINESS | hasReportsAll |
| `GET /reports/staff` | BUSINESS | hasReportsAll |
| Export PDF/Excel | PREMIUM | hasExport |
| `POST /products` | limit check | maxProducts |
| `POST /staff` | limit check | maxStaff |

### Flutter — PlanGate Widget

```dart
class PlanGate extends StatelessWidget {
  final String feature;          // feature key from SubscriptionBloc
  final Widget child;            // shown when feature available
  final Widget? lockedChild;     // shown when locked (default: lock overlay)
}
```

Reads from `SubscriptionBloc`. When locked: shows dimmed card with lock icon and "Доступно в {requiredPlan}" text. Tap → navigates to SubscriptionPage.

**UI integration points:**

| Screen | What gets gated |
|--------|----------------|
| Finance dashboard | "Доставка", "Инвентаризация" tiles → for START |
| ReportsPage | "Прибыль", "Товары", "Сотрудники" tabs → for START |
| ReportsPage | Export FAB → for START and BUSINESS |
| Settings | "Скидки", "Telegram-бот" tiles → for START |
| Product creation | Warning at 90% of limit (e.g. "450/500 товаров") |
| Staff creation | Warning at 90% of limit |
| POS Checkout | Blocked entirely if subscription EXPIRED → "Продлите подписку" |

### Expired Subscription Behavior

App does NOT lock completely. But:
- **Blocked**: new sales (POS checkout), creating new products/staff/sales
- **Allowed**: viewing existing data (products, reports, customers, history)
- **Banner**: persistent top banner on all screens: "Подписка истекла. Продлить →" with tap to SubscriptionPage

## Summary

| Component | New/Modified |
|-----------|-------------|
| Prisma | SubscriptionPlanConfig (new), Subscription (add adminDiscount), Payment (add receiptImage/note/reviewedAt/reviewedBy) |
| Backend | SubscriptionModule (new, ~8 user + ~8 admin endpoints), SubscriptionGuard + decorators, auto-trial on store create, 2 cron jobs |
| Flutter | SubscriptionPage (rewrite), SubscriptionBloc (new), PlanGate widget (new), payment upload flow, feature gating across ~6 screens |
| Admin | API-based admin endpoints (curl/Postman initially, web panel later) |
