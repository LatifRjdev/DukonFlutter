# Dukon — Full Audit Remediation Design Spec

**Date:** 2026-04-17
**Status:** Approved
**Scope:** 3 sub-projects executed sequentially

---

## Context

Full audit of the Dukon app revealed:
- 6 critical/high security and bug issues blocking production
- 10+ backend modules with no Flutter UI integration
- Missing production configuration

This spec covers all remediation work split into 3 sub-projects, each with its own plan and implementation cycle.

---

## Sub-project 1: Security & Bug Fixes (Deployment Blocker)

### 1.1 Secrets in Git (CRITICAL)

**Problem:** `api/.env` with Telegram bot token (`8794769552:AAH...`) and JWT secrets is tracked in git.

**Solution:**
- Create `api/.gitignore`: node_modules, dist, .env, *.log, coverage
- Remove `.env` from git tracking: `git rm --cached api/.env`
- Create `api/.env.example` with placeholder values for all required vars
- Document: rotate JWT_SECRET and Telegram token before production deploy

### 1.2 Error Exposure in ImportBloc (HIGH)

**Problem:** `app/lib/presentation/blocs/import/import_bloc.dart` uses `e.toString()` in 3 catch blocks, leaking raw Dio errors to UI.

**Solution:** Replace all `e.toString()` with `mapErrorToUserMessage(e)` from `core/errors/error_messages.dart`. This is the pattern used in all other BLoCs.

**Files:** `app/lib/presentation/blocs/import/import_bloc.dart`

### 1.3 Missing storeId in Navigation (HIGH)

**Problem:** Finance Dashboard navigates to `/finance/currencies` and `/deliveries` without passing `extra: storeId`.

**Solution:** Add `extra: storeId` to both `context.push()` calls in `finance_dashboard_page.dart`.

**Files:** `app/lib/presentation/pages/finance/finance_dashboard_page.dart`

### 1.4 CORS Configuration (HIGH)

**Problem:** `CORS_ORIGIN=` is empty in `.env`. Production will reject all cross-origin requests.

**Solution:**
- In `api/src/main.ts`, update CORS setup: if `CORS_ORIGIN` is empty and `NODE_ENV=production`, throw error on startup. In dev, default to `*`.
- Document `CORS_ORIGIN` in `.env.example`

**Files:** `api/src/main.ts`, `api/.env.example`

### 1.5 Auth Token Refresh Failure Handling (HIGH)

**Problem:** When refresh token expires, `api_interceptor.dart` returns the error but doesn't clear session — user is stuck on a broken screen.

**Solution:**
- In `api_interceptor.dart`, when `_refreshToken()` returns `false`:
  1. Clear tokens from `FlutterSecureStorage`
  2. Navigate to `/login` via a global navigator key or event bus
- Add a `SessionExpiredEvent` that `app.dart` listens to and redirects

**Files:**
- `app/lib/core/network/api_interceptor.dart`
- `app/lib/app.dart` (add listener)

### 1.6 Production Configuration Documentation (MEDIUM)

**Problem:** No documentation for production deployment.

**Solution:** Create `docs/deployment.md` covering:
- Required environment variables (API_BASE_URL, JWT_SECRET, DATABASE_URL, CORS_ORIGIN, etc.)
- Flutter build command: `flutter build apk --dart-define=API_BASE_URL=https://api.dukonpro.com/api`
- Android release signing setup
- HTTPS enforcement (already in main.dart for release mode)
- Database migration: `npx prisma migrate deploy`

---

## Sub-project 2: Core Business Modules

All modules follow the same architecture pattern (matching existing expenses module):
- `RemoteDatasource` (abstract + impl with DioClient)
- `Repository` (interface + impl delegating to datasource)
- `BLoC` (events, states, bloc with mapErrorToUserMessage)
- UI pages (list + add/edit forms)
- DI registration in `injection.dart`
- Route registration in `app_router.dart` + `route_names.dart`

### 2.1 Suppliers (Поставщики)

**Backend endpoints (8):**
- `POST /stores/:storeId/suppliers` — create
- `GET /stores/:storeId/suppliers` — list with pagination
- `GET /stores/:storeId/suppliers/:id` — detail
- `PUT /stores/:storeId/suppliers/:id` — update
- `DELETE /stores/:storeId/suppliers/:id` — delete
- `GET /stores/:storeId/suppliers/:id/debts` — supplier debts
- `POST /stores/:storeId/suppliers/:id/payments` — make payment
- `GET /stores/:storeId/suppliers/:id/payments` — payment history

**Flutter pages:**
- `SupplierListPage` — list with search, total debt amount at top
- `AddSupplierPage` — form: name, phone, company, address
- `SupplierDetailPage` — detail view + debt list + payment history + "Make Payment" button

### 2.2 Discounts (Скидки)

**Backend endpoints (5):**
- `POST /stores/:storeId/discounts` — create
- `GET /stores/:storeId/discounts` — list
- `GET /stores/:storeId/discounts/:id` — detail
- `PUT /stores/:storeId/discounts/:id` — update
- `DELETE /stores/:storeId/discounts/:id` — delete
- `GET /stores/:storeId/discounts/applicable` — get applicable discounts for cart

**Flutter pages:**
- `DiscountListPage` — list with type (PERCENTAGE/FIXED), active/inactive status
- `AddDiscountPage` — form: name, type, value, min amount, start/end dates, applicable categories
- POS integration: call `getApplicable` during checkout, show available discounts

### 2.3 Reports (Отчёты)

**Backend endpoints (4):**
- `GET /stores/:storeId/reports/sales` — sales report
- `GET /stores/:storeId/reports/profit` — profit report
- `GET /stores/:storeId/reports/products` — product performance
- `GET /stores/:storeId/reports/staff` — staff performance

**Flutter pages:**
- `ReportsPage` — TabBar with 4 tabs, each displaying tabular/chart data
- Date range filter at the top (shared across tabs)
- Connected to "Отчёт" tile in Finance Dashboard (already navigates to `/finance/reports`)

### 2.4 Deliveries (Доставки)

**Backend endpoints (4):**
- `POST /stores/:storeId/deliveries` — create
- `GET /stores/:storeId/deliveries` — list
- `GET /stores/:storeId/deliveries/:id` — detail
- `PUT /stores/:storeId/deliveries/:id` — update status

**Flutter pages:**
- `DeliveryListPage` — list with status filter chips (PENDING, IN_TRANSIT, DELIVERED, CANCELLED)
- `AddDeliveryPage` — form: customer, address, items, notes
- Status update via swipe or button

### 2.5 Inventory Counts (Инвентаризация)

**Backend endpoints (4):**
- `POST /stores/:storeId/inventory-counts` — create count session
- `GET /stores/:storeId/inventory-counts` — list sessions
- `GET /stores/:storeId/inventory-counts/:id` — session detail with items
- `POST /stores/:storeId/inventory-counts/:id/apply` — apply count results to stock

**Flutter pages:**
- `InventoryCountListPage` — list of count sessions with date and status
- `InventoryCountPage` — already exists, verify connection to datasource
- "Apply" action with confirmation dialog

---

## Sub-project 3: Platform Features

### 3.1 Subscriptions (Подписки)

**Backend endpoints:**
- `GET /subscription/plans` — list available plans
- `GET /stores/:storeId/subscription` — current subscription
- `POST /stores/:storeId/subscription` — subscribe/change plan

**Flutter:**
- `SubscriptionRemoteDatasource` — getPlans, getCurrent, subscribe
- `SubscriptionBloc` — LoadPlans, LoadCurrent, Subscribe
- `SubscriptionPage` already exists with UI for 3 tiers — wire to real API
- Show current plan + expiry in settings

### 3.2 Notifications (Уведомления)

**Backend endpoints:**
- `POST /users/me/fcm-token` — register device token
- `GET /stores/:storeId/notifications` — list notifications
- `PUT /stores/:storeId/notifications/:id/read` — mark as read

**Flutter:**
- `NotificationRemoteDatasource` — registerToken, getNotifications, markAsRead
- `NotificationBloc` — Load, MarkAsRead, RegisterToken
- `NotificationsPage` already exists — wire to API
- Register FCM token on app startup in `main.dart`
- Badge count on bell icon in dashboard header

### 3.3 Telegram — Receipt Sending

**Backend endpoint:**
- `POST /stores/:storeId/telegram/send-receipt`

**Flutter:**
- Add `sendReceipt(storeId, saleId, chatId)` method to Telegram datasource
- On SaleSuccessPage — show "Send receipt via Telegram" button if customer has Telegram chatId

### 3.4 Finance — Wire balance & credits-summary

**Backend endpoints:**
- `GET /stores/:storeId/finances/balance`
- `GET /stores/:storeId/finances/credits-summary`

**Flutter:**
- `BalancePage` and `CreditsPage` already exist
- Add `getBalance()` and `getCreditsSummary()` to `FinanceRemoteDatasource`
- Wire pages to real API calls

### 3.5 Stock Movements — Store-level view

**Backend endpoints:**
- `POST /stores/:storeId/stock-movements` — create
- `GET /stores/:storeId/stock-movements` — list all movements

**Flutter:**
- Verify existing integration via product-level endpoints
- If store-level view is needed: `StockMovementsPage` with filters by product/type/date

---

## Execution Order

1. **Sub-project 1: Security & Bug Fixes** — must complete before any deployment
2. **Sub-project 2: Core Business Modules** — 5 modules, each independent
3. **Sub-project 3: Platform Features** — 5 features, each independent

Each sub-project gets its own implementation plan via `writing-plans` skill.

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Git history contains secrets even after removal | Document: rotate all secrets before prod deploy |
| NBT currency scraper broken | Already have manual fetch endpoint + seeded data |
| 10 new modules = many new files | Follow exact expense module pattern — mechanical work |
| POS discount integration is complex | Start with discount CRUD, integrate into POS as separate task |
| FCM setup requires Firebase project | Document Firebase setup in deployment guide |
