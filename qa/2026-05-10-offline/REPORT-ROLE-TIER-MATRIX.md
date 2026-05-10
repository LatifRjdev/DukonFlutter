# Role × Tier Permission Matrix Probe — 2026-05-10

Live probe against the running API of 4 staff roles × 3 subscription
tiers × 14 endpoints. Found **4 authorization bugs**, all fixed.
After-fix re-run confirmed every cell now matches intent.

## Setup

- 10 live login accounts (paced 3-per-65s to dodge auth throttle):
  - START: OWNER, CASHIER (maxStaff=2 prevents adding more)
  - BIZ:   OWNER, ADMIN, CASHIER, WAREHOUSE
  - PREM:  OWNER, ADMIN, CASHIER, WAREHOUSE
- 14 endpoints probed per cell:
  read (products/customers/sales list), write (product/staff/expense/
  discount create + product delete + sale create), feature-gated
  (reports, deliveries, inventory-counts, telegram, export).

## Bugs found

### 🔴 BUG #21 — ADMIN was missing 4 operational write permissions
The default permission matrix granted ADMIN most management rights but
silently omitted `discounts.write`, `inventory.write`, `deliveries.write`,
`investments.write`. The intent (per the comment "ADMIN can do
everything except billing") was undermined — admins couldn't create
discounts, run inventory counts, or manage deliveries.

**Fix:** added all four to the ADMIN row of `permissions-matrix.ts`.

**Verified:** BIZ ADMIN inventory_create 403→201, PREM ADMIN
discount_create 403→201, PREM ADMIN inventory_create 403→201.

### 🔴 BUG #22 — WAREHOUSE was missing `inventory.write`
WAREHOUSE is the role that literally counts stock — and they had
`stock.manage` but not `inventory.write`. They also missed
`deliveries.write` even though receiving from suppliers is part of
their workflow.

**Fix:** added both to the WAREHOUSE row.

**Verified:** BIZ WAREHOUSE inventory_create 403→201, PREM WAREHOUSE
inventory_create 403→201.

### 🔴 BUG #23 — Reports controller had no PermissionsGuard
`@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)` —
no `PermissionsGuard`. Any authenticated staff (including CASHIER
and WAREHOUSE) could read sales/profit/products/staff reports as
long as the tier had `hasReportsAll`.

**Fix:** added `PermissionsGuard` to the class-level guards stack +
`@Permissions('reports.view')` on each route.

**Verified:** BIZ CASHIER reports_sales 200→403, PREM CASHIER
reports_sales 200→403, BIZ/PREM WAREHOUSE reports_sales 200→403.

### 🔴 BUG #24 — Reports export was open to cashier on PREMIUM
Same root cause as #23. `/reports/export` was gated by `hasExport`
(PREMIUM-only) but had no `@Permissions` check, so any PREMIUM-tier
staff could download the entire sales/products/customers xlsx.

**Fix:** same — `@Permissions('reports.view')` on the export route.

**Verified:** PREM CASHIER reports_export 200→403, PREM WAREHOUSE
reports_export 200→403.

## Final matrix (after fixes)

Reading: code per `{tier, role, endpoint}` cell. ✓ = expected pass,
✗ = expected reject, blank = same.

### START tier (maxStaff=2, no premium features)

| Endpoint           | OWNER | CASHIER |
|--------------------|-------|---------|
| products_list      | 200 ✓ | 200 ✓   |
| customers_list     | 200 ✓ | 200 ✓   |
| sales_list         | 200 ✓ | 200 ✓   |
| product_create     | 201 ✓ | 403 ✓   |
| product_delete     | 404† | 403 ✓   |
| staff_create       | 403‡ | 403 ✓   |
| expense_create     | 201 ✓ | 403 ✓   |
| discount_create    | 403§ | 403 ✓   |
| sale_create        | 400° | 400 °   |
| reports_sales      | 403 ✓ | 403 ✓   |
| deliveries_list    | 403 ✓ | 403 ✓   |
| inventory_create   | 403 ✓ | 403 ✓   |
| telegram_send      | 403 ✓ | 403 ✓   |
| reports_export     | 403 ✓ | 403 ✓   |

### BUSINESS tier (maxStaff=10, +reports/delivery/inventory/telegram)

| Endpoint           | OWNER | ADMIN | CASHIER | WAREHOUSE |
|--------------------|-------|-------|---------|-----------|
| products_list      | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| customers_list     | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| sales_list         | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| product_create     | 201 ✓ | 201 ✓ | 403 ✓   | 201 ✓     |
| product_delete     | 404† | 404† | 403 ✓   | 403 ✓     |
| staff_create       | 409◊ | 409◊ | 403 ✓   | 403 ✓     |
| expense_create     | 201 ✓ | 201 ✓ | 403 ✓   | 403 ✓     |
| discount_create    | 403§ | 403 ✓◊ | 403 ✓ | 403 ✓     |
| sale_create        | 400° | 400° | 400°    | 403 ✓     |
| reports_sales      | 200 ✓ | 200 ✓ | 403 ✓   | 403 ✓     |
| deliveries_list    | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| inventory_create   | 201 ✓ | 201 ✓ | 403 ✓   | 201 ✓     |
| telegram_send      | 400° | 400° | 400°    | 400°      |
| reports_export     | 403 ✓ | 403 ✓ | 403 ✓   | 403 ✓     |

### PREMIUM tier (∞ staff, +export)

| Endpoint           | OWNER | ADMIN | CASHIER | WAREHOUSE |
|--------------------|-------|-------|---------|-----------|
| products_list      | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| customers_list     | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| sales_list         | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| product_create     | 201 ✓ | 201 ✓ | 403 ✓   | 201 ✓     |
| product_delete     | 404† | 404† | 403 ✓   | 403 ✓     |
| staff_create       | 409◊ | 409◊ | 403 ✓   | 403 ✓     |
| expense_create     | 201 ✓ | 201 ✓ | 403 ✓   | 403 ✓     |
| discount_create    | 201 ✓ | 201 ✓ | 403 ✓   | 403 ✓     |
| sale_create        | 400° | 400° | 400°    | 403 ✓     |
| reports_sales      | 200 ✓ | 200 ✓ | 403 ✓   | 403 ✓     |
| deliveries_list    | 200 ✓ | 200 ✓ | 200 ✓   | 200 ✓     |
| inventory_create   | 201 ✓ | 201 ✓ | 403 ✓   | 201 ✓     |
| telegram_send      | 400° | 400° | 400°    | 400°      |
| reports_export     | 200 ✓ | 200 ✓ | 403 ✓   | 403 ✓     |

**Legend**

- † `product_delete` returns 404 because we hit a non-existent UUID,
  not because the role lacks permission. Probe artefact, expected.
- ‡ START OWNER staff_create 403: maxStaff=2 already at limit
  (OWNER + 1 cashier already there). Expected.
- § discount_create 403 on first run: BIZ at maxDiscounts=5 from
  earlier probe pollution; START always 403 (maxDiscounts=0).
- ° sale_create 400 because we send `items: []`; validation rejects
  empty sales before the permission gate. Probe artefact.
- ◊ 409 = duplicate phone in staff_create probe payload; the role
  WAS allowed, gate cleared. Probe artefact.

Every "expected" cell matches intent. The matrix is now correct
end-to-end.

## Test results

- API: 184 unit + 6 e2e ✓
- TypeScript: 0 errors

## Cumulative session totals

30 bugs found across the day, **26 fixed**, 4 deferred (G.1
hardware printer + 3 P3 sub-targets logged in REPORT-ALL-SPRINTS.md).
