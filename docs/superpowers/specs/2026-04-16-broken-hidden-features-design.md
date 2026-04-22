# Dukon — Broken/Hidden/Incomplete Features: Design Spec

**Date:** 2026-04-16
**Status:** Approved
**Approach:** C — "Critical Path" (balance security + UX)

---

## Context

Full audit of the Dukon Flutter app revealed 8 non-functional, hidden, or incomplete features. The app is approaching launch, so the plan balances foundational security (auth) with user-visible improvements (finance, import).

## Problem Inventory

| # | Problem | Severity | Current State |
|---|---------|----------|---------------|
| 1 | OTP / Forgot password — stubs | Critical | Comments say "backend endpoint not yet available" |
| 2 | Profile button — empty onTap | Critical | `onProfileTap: () {}` does nothing |
| 3 | Investments — completely missing | High | `stub: true`, `comingSoon('Вложения')` — no model, no API, no page |
| 4 | Currency — no backend integration | High | Frontend works on mock data, backend has only 2 GET endpoints |
| 5 | Excel import — no backend | High | UI ready, DTO exists, no controller/parser |
| 6 | Import button in product list not wired | Medium | Only accessible from empty products page |
| 7 | Calendar date range not persisted | Low | Custom range resets to 'month' |
| 8 | Notification toggle in settings not wired | Low | UI toggle exists but not connected to bloc |

---

## Sprint 1 — Auth & Quick Fixes

### 1.1 Profile Button Fix (Quick Fix)

Replace `onProfileTap: () {}` in `dashboard_page.dart` with navigation to `RouteNames.settings`.

One line change. Settings page is fully implemented.

### 1.2 OTP Verification & Password Recovery

**Backend (NestJS):**

New Prisma model:
```
OtpCode {
  id        String   @id @default(uuid())
  phone     String
  code      String   // 6 digits
  type      OtpType  // VERIFY | RESET
  expiresAt DateTime // 60 seconds from creation
  used      Boolean  @default(false)
  createdAt DateTime @default(now())
}
```

New endpoints in `auth` module:
- `POST /auth/send-otp` — generate 6-digit code, send via SMS provider
- `POST /auth/verify-otp` — validate code, issue token
- `POST /auth/forgot-password` — send OTP to phone
- `POST /auth/reset-password` — change password using OTP code

SMS provider: abstract `SmsProvider` interface. Start with console logging, plug in real provider later.

Rate limiting: max 3 OTP requests per minute per phone number.

**Frontend (Flutter):**

- Replace stub comments in `otp_page.dart` with API calls via `AuthRemoteDatasource`
- Add methods to `AuthBloc`: `sendOtp()`, `verifyOtp()`, `forgotPassword()`, `resetPassword()`
- New `ForgotPasswordPage` → enter phone → send OTP → `ResetPasswordPage`

### 1.3 Calendar Date Range Fix

In `dashboard_page.dart`, persist selected date range in state instead of resetting to 'month' after date picker closes.

---

## Sprint 2 — Finance Module

### 2.1 Investments (Full Stack)

**Prisma model:**
```
Investment {
  id           String           @id @default(uuid())
  storeId      String
  store        Store            @relation(fields: [storeId], references: [id])
  name         String
  description  String?
  amount       Decimal
  returnAmount Decimal?
  investorName String
  investorPhone String?
  status       InvestmentStatus // ACTIVE | COMPLETED | CANCELLED
  startDate    DateTime
  endDate      DateTime?
  createdAt    DateTime         @default(now())
  updatedAt    DateTime         @updatedAt
}
```

**Backend (NestJS):**
- New module `investments` in `api/src/modules/`
- CRUD endpoints: `POST / GET / GET:id / PUT:id / DELETE:id` — all scoped by storeId
- DTOs: `CreateInvestmentDto`, `UpdateInvestmentDto` with class-validator
- Filtering by status, date range, pagination
- Summary: `GET /stores/:storeId/investments/summary` — total amount, active count, completed count

**Frontend (Flutter):**
- `InvestmentRemoteDatasource` — CRUD + summary
- `InvestmentBloc` — events: List, Create, Update, Delete, LoadSummary
- `InvestmentListPage` — list with status filters, total amount at top
- `AddInvestmentPage` / `EditInvestmentPage` — form
- Remove `stub: true` and `comingSoon('Вложения')` from `finance_dashboard_page.dart`
- Navigation: "Вложения" tile → `/investments`

### 2.2 Currency — Backend Integration

**Backend:**
- Extend `currencies` module: add `POST /rates` and `PUT /rates/:id` for manual rate management
- Add `CurrencyRate` model to Prisma if not present

**Frontend:**
- Replace mock data in `currencies_page.dart` with calls to `CurrencyRemoteDatasource`
- Add `CurrencyBloc` for state management
- Connect charts to real historical data from `GET /rates/history`

### 2.3 Notification Toggle in Settings

Wire notification toggle to `SettingsBloc` → save via API `/notification-settings`.

---

## Sprint 3 — Excel Product Import

### 3.1 Backend — Parsing & Template

New endpoints in `products` module:

- `GET /stores/:storeId/products/import/template` — download .xlsx template
  - Columns: Name, Barcode, Category, Purchase Price, Sale Price, Quantity, Unit, Description
- `POST /stores/:storeId/products/import/preview` — parse file, return preview of first 20 rows without saving
- `POST /stores/:storeId/products/import` — upload file (multipart), create products
  - Accepts .xlsx and .csv
  - Parsing via `exceljs` library
  - Validation: required fields (name, sale price), barcode uniqueness
  - Response: `{ created: number, skipped: number, errors: [{row, field, message}] }`

Logic:
- Transaction: rollback all on critical error
- Category mapping by name: auto-create if not found
- Limit: 1000 products per import

### 3.2 Frontend — Full Flow

**Data layer:**
- Methods in `ProductRemoteDatasource`: `downloadTemplate()`, `importPreview(file)`, `importProducts(file, options)`
- `ImportBloc` — states: Initial → FileSelected → Previewing → Importing → Success/Error

**UI flow (enhance existing ImportProductsPage):**
1. Pick file (file_picker) or download template
2. Preview screen — table with first rows, validation errors highlighted
3. "Import" button → progress indicator → result (created X, skipped Y, errors Z)

**Wire import button in ProductListPage:**
- Add "Импорт из Excel" to popup menu → navigate to `/products/import`

---

## Sprint 4 — Polish & Stabilization

### 4.1 Sync Verification
- Test `/sync/status` and `/sync/trigger` backend endpoints
- If non-functional, implement minimal versions

### 4.2 Finance Dashboard Tiles
- Verify all 8 tiles navigate to working pages
- Remove any remaining empty `onTap` handlers

### 4.3 Final Testing
- Full auth flow: register → OTP → login → forgot password → reset
- Finance: expenses, investments, currency
- Import: template → fill → upload → preview → import
- All navigation elements from home screen

---

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| SMS provider not ready for launch | Abstract SmsProvider — start with console logging, swap in real provider later |
| Investment model complexity | Start with simple CRUD, add analytics in future version |
| Excel parsing edge cases | Strict template + preview step lets user catch errors before import |
| Currency rates data source | Manual entry first, auto-fetch from CBT API can be added later |
