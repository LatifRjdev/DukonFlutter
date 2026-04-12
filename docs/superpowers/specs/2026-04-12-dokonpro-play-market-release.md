# DokonPro Play Market Release — Full Spec

**Date**: 2026-04-12
**Goal**: Eliminate all 28 "coming soon" stubs, fix release blockers, ship to Google Play Store.
**Approach**: Vertical sprints (backend + Flutter + tests per feature group).

---

## Architecture Overview

- **Backend**: NestJS (api/src/modules/) — Prisma ORM, PostgreSQL
- **Frontend**: Flutter (app/lib/) — BLoC state management, Clean Architecture
- **API pattern**: `GET/POST/PUT/DELETE /stores/:storeId/<resource>`
- **Auth**: JWT access + refresh tokens, auto-refresh on 401

### New Prisma Models (6 total)

| Model | Sprint | Fields |
|-------|--------|--------|
| `Delivery` | 2 | id, saleId, storeId, address, courierId, status(NEW/IN_TRANSIT/DELIVERED), notes, createdAt, updatedAt |
| `InventoryCount` | 2 | id, storeId, status(IN_PROGRESS/COMPLETED/CANCELLED), createdAt, completedAt |
| `InventoryCountItem` | 2 | id, inventoryCountId, productId, expectedQty, actualQty |
| `CurrencyRate` | 3 | id, currency(USD/RUB/EUR/CNY), buyRate, sellRate, nbtRate, date, createdAt |
| `FcmToken` | 3 | id, userId, token, platform(ANDROID/IOS), createdAt |
| `Notification` | 3 | id, storeId, userId, type, title, body, read, createdAt |
| `Discount` | 4 | id, storeId, name, type(FIXED/PERCENTAGE), value, condition(CART/CATEGORY/PRODUCT), categoryId?, productId?, minTotal?, startDate, endDate?, active, createdAt |

### New API Endpoints (~22 total)

Listed per sprint below.

### New Flutter Packages

| Package | Purpose | Sprint |
|---------|---------|--------|
| `mobile_scanner` | Camera barcode scanning (EAN-13, EAN-8, QR, Code128) | 1 |
| `fl_chart` | Line/pie charts for finance & reports | 2 |
| `pdf` | PDF generation for reports and receipts | 2 |
| `excel` | Excel export for reports | 2 |
| `firebase_core` | Firebase initialization | 3 |
| `firebase_messaging` | FCM push notifications | 3 |
| `printing` | Bluetooth/system print dialog | 3 |
| `share_plus` | Share PDF via WhatsApp/Telegram/email | 3 |
| `esc_pos_utils` | ESC/POS receipt formatting | 4 |
| `flutter_blue_plus` | Bluetooth printer connection | 4 |

### New Backend Packages

| Package | Purpose | Sprint |
|---------|---------|--------|
| `cheerio` | HTML parsing for NBT currency scraping | 3 |
| `node-telegram-bot-api` | Telegram Bot API for receipt delivery | 3 |
| `firebase-admin` | FCM push notification sending | 3 |

---

## Sprint 1: Foundation

**Goal**: Fix release blockers, implement barcode scanner, complete existing UI gaps.
**New API endpoints: 0** (all exist already).
**New/changed screens: ~6**

### 1.1 Release Blockers

**Signing config:**
- Generate `upload-keystore.jks` via `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- Create `android/key.properties` (added to `.gitignore`):
  ```
  storePassword=<password>
  keyPassword=<password>
  keyAlias=upload
  storeFile=../upload-keystore.jks
  ```
- Update `build.gradle.kts`:
  - Load `key.properties`
  - Add `signingConfigs.register("release")` with keystore paths
  - Set `release { signingConfig = signingConfigs.getByName("release") }`

**ProGuard/R8:**
- Set `minifyEnabled = true`, `shrinkResources = true` in release buildType
- Create `android/app/proguard-rules.pro` with keep rules for:
  - Flutter engine classes
  - Dio/OkHttp (network)
  - JSON serialization model classes
  - Firebase messaging

**INTERNET permission:** Already present via plugin manifest merging + release-guard in `main.dart`. No changes needed.

### 1.2 Barcode Scanner

**Shared widget**: `BarcodeScannerSheet` — modal bottom sheet with camera preview and overlay frame.

Location: `app/lib/presentation/widgets/common/barcode_scanner_sheet.dart`

Callback: `onScanned(String barcode)` — returns the scanned barcode string.

**Integration points:**

| Location | File | Line | After scan action |
|----------|------|------|-------------------|
| POS Checkout | `pos_checkout_page.dart` | 288 | Find product via `GET /products/barcode/:barcode`, add to cart |
| Product List | `product_list_page.dart` | 142 | Navigate to product detail page |
| Add Product | `add_product_step1_page.dart` | 90 | Fill barcode text field |
| Stock Intake | `stock_intake_page.dart` | 116 | Add product to intake list |

Error handling: If barcode not found in DB, show SnackBar "Товар с штрихкодом XXX не найден" with option to create new product.

### 1.3 Customer Edit

Replace stub at `customer_detail_page.dart:271`.

**Refactor**: Merge `AddCustomerPage` and a new edit mode into a single `CustomerFormPage`:
- Constructor: `CustomerFormPage({Customer? existing})` — null = add mode, non-null = edit mode
- Fields: name (required), phone (+992 validation), notes
- Save: `POST /customers` (add) or `PUT /customers/:id` (edit)
- On success: pop back to detail page with updated data

### 1.4 Sales Filters

Replace stubs at `sales_history_page.dart:77,81`.

**Widget**: `SalesFilterSheet` — bottom sheet with:
- Period: chips (Today / Week / Month / Custom range with date pickers)
- Payment type: chips (All / Cash / Card / Debt)
- Status: chips (All / Completed / Returned / Cancelled)
- "Apply" button → updates `SalesBloc` query params
- "Reset" button → clears all filters

API: existing `GET /stores/:storeId/sales?from=&to=&paymentType=&status=`

### 1.5 Zakat Buttons

Replace stubs at `zakat_calculator_page.dart:271` and `zakat_settings_page.dart:183`.

- Calculator "Calculate" button: calls `GET /stores/:storeId/zakat/calculate`, displays result in a summary card (nisab threshold, total eligible, zakat amount at 2.5%)
- Settings "Save" button: calls `POST /stores/:storeId/zakat/settings` with form data, shows SnackBar on success

---

## Sprint 2: Finance

**Goal**: Implement all 5 finance dashboard tiles + inventory.
**New API endpoints: ~10**
**New Prisma models: Delivery, InventoryCount, InventoryCountItem**
**New screens: ~15**

### 2.1 Balance

**Screen**: `BalancePage`

- **Header card**: current balance (total income - total expenses), with colored indicator (green positive, red negative)
- **Period selector**: chips (Week / Month / Year)
- **Line chart** (`fl_chart`): X = dates, Y = amount. Two lines: income (green) and expenses (red)
- **Transaction list**: chronological, each row shows type icon, description, amount, date. Pull-to-refresh. Infinite scroll pagination.
- **Summary row**: total income | total expenses | net profit for selected period

**New API**: `GET /stores/:storeId/finances/balance?period=week|month|year&page=&limit=`

Response:
```json
{
  "balance": 125000.00,
  "income": 450000.00,
  "expenses": 325000.00,
  "profit": 125000.00,
  "chartData": [{"date": "2026-04-01", "income": 15000, "expenses": 8000}],
  "transactions": [{"id": "...", "type": "sale|expense", "amount": 500, "date": "...", "description": "..."}],
  "pagination": {"page": 1, "totalPages": 5}
}
```

### 2.2 Credits

**Screen**: `CreditsPage` with TabBar (2 tabs)

**Tab 1 — "Нам должны" (Receivables):**
- List of customers with outstanding debts
- Each card: customer name, phone, total debt amount, last payment date
- Tap → `CreditDetailPage` showing payment history + "Accept payment" button

**Tab 2 — "Мы должны" (Payables):**
- List of suppliers with outstanding debts
- Same card layout as receivables
- Tap → detail with "Make payment" button

**Payment modal**: amount field (pre-filled with total debt), payment method (cash/card), notes. Calls existing `POST /customers/:id/payments` or `POST /suppliers/:id/payments`.

**New API**: `GET /stores/:storeId/finances/credits-summary`

Response:
```json
{
  "receivables": {"total": 45000, "count": 12, "items": [{"id": "...", "name": "...", "phone": "...", "debt": 5000, "lastPayment": "..."}]},
  "payables": {"total": 28000, "count": 5, "items": [{"id": "...", "name": "...", "debt": 8000, "lastPayment": "..."}]}
}
```

### 2.3 Reports (Full)

**Screen**: `ReportsPage` with 5 tabs

**Tab: Sales**
- Table: date, sales count, total revenue, average check
- Top-5 products by revenue (bar chart)
- Period selector (date range picker)

**Tab: Expenses**
- Pie chart: expenses by category
- List below chart: category name, total, % of all expenses
- Trend line chart: expenses over time

**Tab: Profit**
- Income vs expenses bar chart (grouped by month)
- Margin percentage line
- Summary: gross revenue, total expenses, net profit, margin %

**Tab: Products**
- Top sellers (by quantity and by revenue)
- Dead stock (not sold in 30+ days)
- Stock value: total inventory cost

**Tab: Staff**
- Sales per cashier (bar chart)
- Average check per cashier
- Shift hours summary

**Export**: Floating action button "Download" → bottom sheet: PDF / Excel. Generated client-side using `pdf` and `excel` packages.

**New API endpoints:**
- `GET /stores/:storeId/reports/sales?from=&to=`
- `GET /stores/:storeId/reports/profit?from=&to=`
- `GET /stores/:storeId/reports/products?from=&to=`
- `GET /stores/:storeId/reports/staff?from=&to=`

Each returns aggregated data tailored to the tab's needs.

### 2.4 Delivery

**Screen**: `DeliveryListPage`

- Tab bar: All / New / In Transit / Delivered
- Each card: order #, customer name, address, amount, status badge, date
- FAB "+" → `CreateDeliveryPage`

**`CreateDeliveryPage`:**
- Select sale (from recent sales list)
- Address field (text input)
- Select courier (from staff list, filtered by role)
- Notes field
- Save → `POST /stores/:storeId/deliveries`

**`DeliveryDetailPage`:**
- Status tracker: Created → In Transit → Delivered (visual stepper)
- Order details: items, total, customer info
- Action buttons based on status:
  - NEW: "Pick up" → sets IN_TRANSIT
  - IN_TRANSIT: "Delivered" → sets DELIVERED
  - DELIVERED: read-only

**New API endpoints:**
- `POST /stores/:storeId/deliveries`
- `GET /stores/:storeId/deliveries?status=&from=&to=`
- `GET /stores/:storeId/deliveries/:id`
- `PUT /stores/:storeId/deliveries/:id/status` — body: `{status: "IN_TRANSIT"|"DELIVERED"}`

### 2.5 Inventory Count

**Screen**: `InventoryCountPage`

**Flow:**
1. "Start count" button → `POST /stores/:storeId/inventory-counts` → creates session, returns all products with expected quantities
2. Count screen: scrollable list of products. Each row: product name, expected qty (greyed), actual qty (editable text field). Barcode scanner button to jump to product.
3. "Finish" button → shows diff screen
4. Diff screen: table with columns (Product | Expected | Actual | Difference). Differences highlighted: red if negative (shortage), yellow if positive (surplus). Summary row at top: total items counted, items with discrepancies.
5. "Apply" button → `POST /stores/:storeId/inventory-counts/:id/apply` → updates product stock quantities in DB

**New API endpoints:**
- `POST /stores/:storeId/inventory-counts` — creates session
- `GET /stores/:storeId/inventory-counts/:id` — get session with items
- `PUT /stores/:storeId/inventory-counts/:id` — update counts (batch)
- `POST /stores/:storeId/inventory-counts/:id/apply` — finalize and update stock

---

## Sprint 3: Integrations

**Goal**: External service integrations — NBT currencies, Telegram, Firebase, Z-report print/share.
**New API endpoints: ~7 + Telegram webhook**
**New Prisma models: CurrencyRate, FcmToken, Notification**
**New screens: ~8**

### 3.1 Currencies (NBT Rates)

**Backend `CurrencyModule`:**
- `CurrencyService`: scrapes nbt.tj for exchange rates using `cheerio`
- Cron job (`@Cron('0 9 * * *')`) — runs daily at 09:00 to fetch fresh rates
- Stores rates in `CurrencyRate` table with history

**API endpoints:**
- `GET /currencies/rates` — latest rates for USD, RUB, EUR, CNY against TJS
- `GET /currencies/rates/history?currency=USD&days=30` — rate history for chart

**Flutter screen `CurrenciesPage`:**
- Currency cards: flag icon, currency code, NBT rate (buy/sell)
- Tap card → expands to show 30-day line chart (`fl_chart`)
- Converter section at bottom: input field with currency dropdown → shows converted amount in all other currencies
- Store currency setting: dropdown to select store's primary display currency (saved to store settings)

### 3.2 Telegram Receipt Delivery

**Backend `TelegramModule`:**
- `TelegramService`: uses `node-telegram-bot-api`
- Bot webhook at `POST /telegram/webhook`
- Bot flow:
  1. User sends `/start` → bot replies "Enter your phone number"
  2. User sends phone → bot saves `{phone, chatId}` mapping in Customer record
  3. Confirmation: "Your number +992XXXXXXXXX is linked to DokonPro"

**API endpoints:**
- `POST /stores/:storeId/telegram/send-receipt` — body: `{saleId}`. Looks up customer's chatId, formats receipt, sends via bot.
- `POST /telegram/webhook` — Telegram webhook handler
- Telegram status is derived from Customer.telegramChatId field (no separate endpoint needed)

**Receipt format in Telegram:**
```
Receipt #1234 | DokonPro
Date: 12.04.2026 14:30
---
Product x qty     total
---
Total:            XX.XX TJS
Payment: Cash
---
Thank you!
```
(In Russian with proper formatting)

**Customer model change:** Add `telegramChatId: String?` field to existing Customer Prisma model.

### 3.3 Firebase Push Notifications

**Firebase setup:**
- Create Firebase project "DokonPro"
- Download `google-services.json` → `android/app/` (in `.gitignore`)
- `flutterfire configure` for Flutter config generation

**Backend `NotificationModule`:**
- `NotificationService`: uses `firebase-admin` SDK
- Sends push on events:

| Type | Trigger | Recipients |
|------|---------|-----------|
| `LOW_STOCK` | Product quantity < minStock after sale | Owner, Manager |
| `NEW_SALE` | Sale completed (if owner not the cashier) | Owner |
| `SHIFT_CLOSED` | Shift closed | Owner |
| `DELIVERY_COMPLETED` | Delivery status → DELIVERED | Owner, Manager |
| `DEBT_REMINDER` | Daily cron: debts overdue > 7 days | Owner |

**API endpoints:**
- `POST /users/me/fcm-token` — body: `{token, platform}`. Saves/updates FCM token.
- `GET /stores/:storeId/notifications?page=&limit=` — notification history, paginated
- `PUT /stores/:storeId/notifications/settings` — body: `{lowStock: bool, newSale: bool, shiftClosed: bool, deliveryCompleted: bool, debtReminder: bool}`

**Flutter:**
- `NotificationsPage` replaces stub at `dashboard_page.dart:267`
- Badge counter on bell icon (unread count)
- List of notifications with read/unread state
- Tap notification → deep link to relevant screen (e.g., tap LOW_STOCK → product detail)
- `NotificationSettingsPage` in Settings: toggles for each notification type
- FCM token registration on app start and token refresh

### 3.4 Z-Report Print & Share

Replace stub at `z_report_page.dart:246`.

**Z-report data**: already served by `GET /stores/:storeId/shifts/:id/z-report`.

**PDF generation**: `pdf` package formats Z-report:
```
Z-REPORT | Shift #45
Store: DokonPro
Cashier: Name
Date: 12.04.2026
Open: 09:00 | Close: 21:00
---
Sales: 47        Returns: 2
Cash:       15,420.00
Card:        8,300.00
Debt:        2,150.00
---
TOTAL:      25,870.00 TJS
```

**Actions on Z-report page:**
- "Print" button → `printing` package → Bluetooth printer or system dialog
- "Share" button → `share_plus` → sends PDF via WhatsApp/Telegram/email/save to files

### 3.5 Sale Success — Receipt Sharing

Update `sale_success_page.dart` to replace Telegram stub and add full sharing:

**Layout after successful sale:**
```
  [Checkmark] Sale completed
       56.50 TJS

  [Print]         [Share]

       [Back to POS]
```

**"Share" bottom sheet options:**
- **Telegram** — active only if customer has linked chatId, calls `/telegram/send-receipt`
- **WhatsApp** — generates PDF receipt, opens WhatsApp share intent
- **SMS** — sends short text: "Receipt #1234, Total: 56.50 TJS. Thank you!"
- **Save PDF** — saves receipt PDF to device storage

All options work without a printer.

---

## Sprint 4: Settings + Release

**Goal**: Complete all settings stubs, privacy policy, Play Store release build.
**New API endpoints: ~5**
**New Prisma models: Discount**
**New screens: ~12**

### 4.1 My Stores

Replace stub at `settings_page.dart:148`.

**Screen `MyStoresPage`:**
- List of user's stores (from existing `GET /stores`)
- Active store highlighted with primary border
- Tap → `StoreEditPage` (reuse existing store form with edit mode)
- "Add store" FAB → same form in create mode (`POST /stores`)
- Switch active store → reloads all BLoCs with new storeId
- Store card: name, address, category icon, member count

**New API: 0** — all exist.

### 4.2 Discounts

Replace stub at `settings_page.dart:156`.

**Screen `DiscountsPage`:**
- List of discount rules: name, type badge (% or fixed), value, active toggle, validity period
- FAB → `DiscountFormPage`

**`DiscountFormPage` fields:**
- Name (text, required)
- Type: FIXED / PERCENTAGE (segmented control)
- Value (number field — amount or percentage)
- Condition: Entire cart / Specific category / Specific product (radio + picker)
- Min cart total (optional number field)
- Start date (required, date picker)
- End date (optional, date picker — null = indefinite)
- Active toggle

**POS integration:**
- In `PosCheckoutPage`, before completing sale, call `GET /discounts/applicable?total=X&categoryIds=...&productIds=...`
- If discounts available: show chip banner "Discount available: Friday Sale -10%"
- Cashier taps chip → discount applied to `CartState.discount`
- Multiple discounts: best single discount auto-selected (no stacking for v1)

**New API endpoints:**
- `POST /stores/:storeId/discounts`
- `GET /stores/:storeId/discounts`
- `GET /stores/:storeId/discounts/applicable?total=&categoryIds=&productIds=`
- `PUT /stores/:storeId/discounts/:id`
- `DELETE /stores/:storeId/discounts/:id`

### 4.3 Receipt Templates

Replace stub at `settings_page.dart:158`.

**Screen `ReceiptTemplatePage`:**
- Live preview: rendered receipt at top (scrollable), updates in real-time as settings change
- Settings below preview:
  - Header text (store name, address, phone) — text fields
  - Logo: image picker → stored as base64 in store settings
  - Footer text ("Thank you!" etc.) — text field
  - Font size: Small / Medium / Large (segmented control)
  - Paper width: 58mm / 80mm (segmented control)
  - Show/hide toggles: QR code, date, cashier name, discount line

**Storage**: JSON field in Store settings (no separate table). Fetched via:
- `GET /stores/:storeId/receipt-template`
- `PUT /stores/:storeId/receipt-template`

Extends existing store settings endpoint — adds `receiptTemplate` key to store's settings JSON.

**Used by**: `receipt_widget.dart` (on-screen preview), PDF generator (sharing), ESC/POS formatter (printing).

### 4.4 KKM (Receipt Printing)

Replace stub at `settings_page.dart:169`.

**Screen `KkmSettingsPage`:**
- **Bluetooth printer section:**
  - "Search printers" button → scans via `flutter_blue_plus`, lists found devices
  - Tap device → pair and save as default printer
  - Connected printer shown with name and status indicator
- **Print settings:**
  - Auto-print toggle: "Print receipt after every sale"
  - Number of copies: 1 / 2 (for customer + store copy)
- **Test print** button: sends test receipt to connected printer

**Print flow (ESC/POS):**
1. Sale completed → check auto-print setting
2. If enabled: format receipt using `esc_pos_utils` (reads receipt template settings from 4.3)
3. Send ESC/POS byte commands to Bluetooth printer via `flutter_blue_plus`
4. If printer not connected: show error with "Connect printer" action

### 4.5 Scanner Settings

Replace stub at `settings_page.dart:174`.

**Screen `ScannerSettingsPage`:**
- Camera: Front / Back (radio)
- Sound on scan: toggle
- Vibration on scan: toggle
- Auto-add to cart in POS: toggle (if off, shows product card first)
- Barcode formats: checkboxes for EAN-13, EAN-8, QR Code, Code128

**Storage**: `SharedPreferences` — local only, not synced to server.

Reads by `BarcodeScannerSheet` widget (from Sprint 1.2) to configure `MobileScanner` parameters.

### 4.6 Telegram Bot Settings

Replace stub at `settings_page.dart:167` (shows "Подключён" badge but no detail page).

**Screen `TelegramBotSettingsPage`:**
- Connection status: green/red indicator with bot username
- Bot token field: masked input, "Update" button (saved to backend env/store settings)
- Linked customers count: how many customers have chatId
- Test message button: sends a test message to owner's Telegram
- Instructions: how customers link their account (scan QR / find bot / send /start)

### 4.7 Language Settings

Replace stub at `settings_page.dart:207`.

**Screen `LanguageSettingsPage`:**
- Radio list: Русский (ru), Тоҷикӣ (tg), Ўзбекча (uz)
- Selection saves to `SharedPreferences`
- App rebuilds with new locale via `MaterialApp.locale`
- Current language shown as subtitle on settings tile

### 4.8 Offline Mode Settings

Replace stub at `settings_page.dart:219`.

**Screen `OfflineModePage`:**
- Sync status: last sync time, pending operations count
- Manual sync button: force sync now
- Data usage: how much local data is cached
- Auto-sync toggle: sync when connectivity returns (on by default)
- Clear cache button: with confirmation dialog

### 4.9 Subscription / Business Plan

Replace stub at `settings_page.dart:230` ("БИЗНЕС до 30.03.2026").

**Screen `SubscriptionPage`:**
- Current plan: name, expiry date, features included
- Plan comparison: Free vs Business (feature matrix)
- Renewal / upgrade button (deep link to payment page or in-app purchase)
- Payment history: list of past payments

Note: For v1, this can be a read-only info page showing current plan status. Payment integration is a separate scope.

### 4.7 Privacy Policy

- Create `docs/privacy-policy-ru.md` and `docs/privacy-policy-tg.md`
- Content: data collected (name, phone, store data), storage (encrypted, server-hosted), no third-party sharing, contact info for questions
- Host as static page (GitHub Pages from repo)
- Add link in Settings → About page
- Add URL to Play Console listing

### 4.8 Release Build

**Steps:**
1. Generate keystore (user does this locally)
2. Configure `key.properties` and `build.gradle.kts`
3. Enable ProGuard with `proguard-rules.pro`
4. Build: `flutter build appbundle --dart-define=API_BASE_URL=https://api.dokonpro.tj`
5. Test on Internal Testing track
6. Play Console listing: description (ru), screenshots (phone + tablet), feature graphic, category "Business"
7. Content rating questionnaire
8. Promote to Production

---

## Summary

| Sprint | New API | New Models | New Screens | New Packages |
|--------|---------|-----------|-------------|-------------|
| 1. Foundation | 0 | 0 | ~6 | mobile_scanner |
| 2. Finance | ~10 | 3 | ~15 | fl_chart, pdf, excel |
| 3. Integrations | ~7 | 3 | ~8 | firebase_*, printing, share_plus, cheerio, node-telegram-bot-api |
| 4. Settings + Release | ~5 | 1 | ~16 | esc_pos_utils, flutter_blue_plus |
| **Total** | **~22** | **7** | **~45** | **~12** |

### Stubs Eliminated (30 total)

| # | Stub | Sprint | Solution |
|---|------|--------|----------|
| 1 | Barcode scanner — POS checkout | 1 | BarcodeScannerSheet → add to cart |
| 2 | Barcode scanner — Product list | 1 | BarcodeScannerSheet → product detail |
| 3 | Barcode scanner — Add product | 1 | BarcodeScannerSheet → fill barcode field |
| 4 | Barcode scanner — Stock intake | 1 | BarcodeScannerSheet → add to intake |
| 5 | Customer edit | 1 | CustomerFormPage (add/edit mode) |
| 6 | Sales filter button 1 | 1 | SalesFilterSheet |
| 7 | Sales filter button 2 | 1 | SalesFilterSheet |
| 8 | Zakat calculate button | 1 | Call /zakat/calculate, show result |
| 9 | Zakat save settings button | 1 | Call POST /zakat/settings |
| 10 | Finance: Balance tile | 2 | BalancePage |
| 11 | Finance: Credits tile | 2 | CreditsPage (2 tabs) |
| 12 | Finance: Report tile | 2 | ReportsPage (5 tabs + export) |
| 13 | Finance: Delivery tile | 2 | DeliveryListPage + create + detail |
| 14 | Dashboard: Inventory tile | 2 | InventoryCountPage |
| 15 | Finance: Currencies tile | 3 | CurrenciesPage + converter |
| 16 | Dashboard: Notifications | 3 | NotificationsPage + FCM |
| 17 | Z-report print | 3 | PDF generation + print/share |
| 18 | Telegram receipt send | 3 | TelegramService + bot |
| 19 | Sale success: Telegram send | 3 | Share bottom sheet (Telegram/WhatsApp/SMS/PDF) |
| 20 | Settings: My stores | 4 | MyStoresPage |
| 21 | Settings: Discounts | 4 | DiscountsPage + POS integration |
| 22 | Settings: Receipt templates | 4 | ReceiptTemplatePage + live preview |
| 23 | Settings: KKM | 4 | KkmSettingsPage + Bluetooth printing |
| 24 | Settings: Scanner | 4 | ScannerSettingsPage |
| 25 | Settings: Telegram bot | 4 | TelegramBotSettingsPage |
| 26 | Settings: Language | 4 | LanguageSettingsPage (ru/tg/uz) |
| 27 | Settings: Offline mode | 4 | OfflineModePage (sync status + manual sync) |
| 28 | Settings: Subscription/Business | 4 | SubscriptionPage (read-only plan info) |
| 29 | Product list: filter button | 1 | SalesFilterSheet pattern reuse |
| 30 | Product import: "Скоро" badge | 1 | Wire up existing import flow |

### Release Blockers Resolved

| Blocker | Solution | Sprint |
|---------|----------|--------|
| Debug signing config | Release keystore + key.properties | 4 |
| No ProGuard/R8 | minifyEnabled + shrinkResources + proguard-rules.pro | 4 |
| No privacy policy | Static page hosted on GitHub Pages | 4 |
| No crash reporting | Firebase Crashlytics via firebase_core | 3 |
