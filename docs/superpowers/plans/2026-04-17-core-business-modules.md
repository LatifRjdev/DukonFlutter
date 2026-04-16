# Sub-project 2: Core Business Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure all 5 core business modules (Suppliers, Discounts, Reports, Deliveries, Inventory Counts) are fully connected frontend-to-backend.

**Architecture:** Audit revealed that 4 of 5 modules already have working UI pages that call the API directly via DioClient. Only Reports needs wiring. Suppliers has full data layer. Focus is on verifying existing integrations work and wiring the Reports page.

**Tech Stack:** Flutter (DioClient, BLoC), NestJS (Prisma)

---

## Audit Summary

| Module | UI Page | Calls API? | Data Layer (DS/Repo/BLoC) | Action Needed |
|--------|---------|-----------|---------------------------|---------------|
| Suppliers | ✅ supplier_list/detail | ✅ Yes | ✅ Full (BLoC + Repo) | None — verify only |
| Discounts | ✅ discounts_page | ✅ Yes (DioClient direct) | ❌ No BLoC | None — works as-is |
| Reports | ✅ reports_page (1800 lines) | ❌ DioClient injected but unused | ❌ No BLoC | Wire API calls |
| Deliveries | ✅ delivery_list/detail/create | ✅ Yes (Cubit) | ✅ Has Cubit | None — verify only |
| Inventory | ✅ inventory_count_page | ✅ Yes (Cubit) | ✅ Has Cubit | None — verify only |

---

### Task 1: Wire Reports Page to Backend API

**Files:**
- Modify: `app/lib/presentation/pages/finance/reports_page.dart`

- [ ] **Step 1: Read the reports page fully**

Read `app/lib/presentation/pages/finance/reports_page.dart` (1800 lines). Understand:
- What data models exist (`_SalesRow`, `_TopProduct`, etc.)
- Where `_dio` (DioClient) is declared
- What methods load data (look for `_loadData`, `_fetchReport`, `initState`, etc.)
- What the 4 tabs display: sales, profit, products, staff

- [ ] **Step 2: Identify the data loading gaps**

The page has `final DioClient _dio = sl<DioClient>()` but doesn't call it. Find where data should be loaded and add API calls:

Backend endpoints:
- `GET /stores/:storeId/reports/sales` — query params: startDate, endDate, period
- `GET /stores/:storeId/reports/profit` — query params: startDate, endDate, period
- `GET /stores/:storeId/reports/products` — query params: startDate, endDate, limit
- `GET /stores/:storeId/reports/staff` — query params: startDate, endDate

For each tab, add a `_loadXxxReport()` method that calls the endpoint and maps response to the existing data models. Follow the pattern used by the delivery and inventory pages (direct DioClient calls in a state management method).

- [ ] **Step 3: Connect tab switches to data loading**

Ensure each tab triggers its respective data load when selected. If tabs use `TabController`, add listener to load data on tab change.

- [ ] **Step 4: Handle loading and error states**

Add loading indicators and error handling following the pattern in the page. Use try/catch with user-friendly error messages.

- [ ] **Step 5: Verify**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/pages/finance/reports_page.dart
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/pages/finance/reports_page.dart
git commit -m "feat: wire reports page to backend API endpoints"
```

---

### Task 2: Verify Suppliers Module Works End-to-End

**Files:**
- Verify: `app/lib/presentation/pages/supplier/supplier_list_page.dart`
- Verify: `app/lib/presentation/pages/supplier/supplier_detail_page.dart`

- [ ] **Step 1: Read supplier list page**

Check that it loads data from the API and displays correctly. Verify the endpoint URL matches backend: `GET /stores/:storeId/suppliers`.

Note: Backend controller uses `@Controller('suppliers')` with global prefix `/api`, so the full path is `/api/suppliers`. But store-scoped endpoints use `/stores/:storeId/suppliers` pattern. Verify which pattern the frontend uses.

- [ ] **Step 2: Check supplier CRUD operations**

Verify that create, update, delete, and payment operations call correct endpoints.

- [ ] **Step 3: Fix any mismatches found**

If endpoint URLs don't match, fix them. If storeId isn't passed, fix navigation.

- [ ] **Step 4: Commit only if changes were needed**

```bash
git add app/lib/presentation/pages/supplier/
git commit -m "fix: verify and fix supplier module API integration"
```

---

### Task 3: Verify Discounts Module Works

**Files:**
- Verify: `app/lib/presentation/pages/settings/discounts_page.dart`

- [ ] **Step 1: Read discounts page**

Check that CRUD operations match backend endpoints. Backend uses `@Controller('discounts')` — verify the URL pattern.

- [ ] **Step 2: Fix any mismatches**

- [ ] **Step 3: Commit only if changes were needed**

```bash
git add app/lib/presentation/pages/settings/discounts_page.dart
git commit -m "fix: verify and fix discounts module API integration"
```

---

### Task 4: Verify Deliveries Module Works

**Files:**
- Verify: `app/lib/presentation/pages/delivery/delivery_list_page.dart`
- Verify: `app/lib/presentation/pages/delivery/delivery_detail_page.dart`
- Verify: `app/lib/presentation/pages/delivery/create_delivery_page.dart`

- [ ] **Step 1: Read delivery pages and cubit**

Check that API calls match backend endpoints. Backend uses `@Controller('deliveries')`.

- [ ] **Step 2: Fix any mismatches**

- [ ] **Step 3: Commit only if changes were needed**

```bash
git add app/lib/presentation/pages/delivery/
git commit -m "fix: verify and fix deliveries module API integration"
```

---

### Task 5: Verify Inventory Counts Module Works

**Files:**
- Verify: `app/lib/presentation/pages/inventory/inventory_count_page.dart`

- [ ] **Step 1: Read inventory count page and cubit**

Check that API calls match backend endpoints. Backend uses `@Controller('inventory-counts')`.

- [ ] **Step 2: Fix any mismatches**

- [ ] **Step 3: Commit only if changes were needed**

```bash
git add app/lib/presentation/pages/inventory/
git commit -m "fix: verify and fix inventory counts module API integration"
```
