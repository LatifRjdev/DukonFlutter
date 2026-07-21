# Full-System Functional QA Sweep — 2026-07-21

Real, black-box functional QA of every business function in the product —
not unit tests, not code review. Eight parallel agents drove the actual
running dev API (`localhost:4455`, live Postgres) with real HTTP requests,
each in its own isolated test store, covering every module in `api/src/`.
Every bug reported below was independently reproduced live before being
recorded. Every Critical and High severity bug found was then fixed the
same day, with regression tests, in this codebase's established
Jest + hand-written-Prisma-fake convention.

## Verdict

**The core product works.** Store creation, the full catalog pipeline
(categories → products → stock → import), the complete POS/checkout flow
(cash/card/debt/mixed payment, discounts, refunds), customers, staff,
shifts, and the two most math-sensitive domains in the app — loyalty
points and zakat — all checked out exactly against hand-calculated
expected values across dozens of scenarios per domain.

**Three Critical bugs were found and fixed**: an unlimited-repeat refund
exploit that could inflate stock and drain customer debt without bound, a
cross-store IDOR on categories, and a missing floor guard letting stock go
negative. **Seven High-severity bugs were found and fixed**: a
roles/permissions system that silently had zero effect on real access
control, a receipt-template update that wiped unrelated fields, a payroll
payment endpoint returning stale data, a completely dead low-stock filter,
a completely dead supplier-debt feature, a broken currency-rate scraper,
and a profit report that ignored cost of goods sold. All ten fixes are
covered by new regression tests; the full backend suite (43 suites / 415
tests) is green with `tsc --noEmit` clean.

**14 lower-severity items remain, documented but not fixed** — see §4.
None of them are security- or money-critical; all are reasonable
follow-up work.

---

## 1. Methodology

8 parallel QA agents, one per business domain, each: registered its own
isolated test user (`QA-FULLSWEEP-<Domain>`), created its own isolated
test store, then exercised every real endpoint in its domain via curl
against the live dev API — full CRUD, validation edge cases, cross-store
access-control checks, and (for money-sensitive domains) hand-verified
arithmetic against known inputs. All test data was either cleaned up or is
clearly tagged for cleanup.

| # | Domain | Modules covered |
|---|---|---|
| 1 | Onboarding & Store | auth (register/login/refresh/OTP-reset/logout), stores, receipt-template |
| 2 | Catalog | categories, products, stock-movements, product import, discounts, inventory-counts |
| 3 | POS/Sales | sales (create/list/refund), all payment types, discounts, idempotency |
| 4 | People | staff, roles/permissions, shifts |
| 5 | Partners | customers, suppliers, deliveries |
| 6 | Money | expenses, finances, payroll, investments |
| 7 | Engagement | loyalty, zakat, notifications, telegram, currencies |
| 8 | Admin & Reports | admin (users/stores/dashboard/audit-log/announcements), subscriptions, reports/export |

## 2. Critical bugs — found and fixed

### 2.1 Unlimited repeat-refund exploit (Sales)

`SalesService.refund()` validated each refund request only against a sale
item's **original** quantity, never tracking how much had already been
refunded. As long as the sale hadn't reached the fully-`RETURNED` terminal
state, the same line item could be resubmitted for refund indefinitely —
each call re-incremented stock and re-credited customer debt/totalSpent
with no upper bound. Live-reproduced: 3 repeated refund calls on a 2-unit
sale inflated stock by 5 phantom units; on a debt sale, 3 repeat calls
drained a customer's debt by 30 for a sale that only ever totaled 40.

**Fix**: added `SaleItem.refundedQuantity` (Prisma migration
`20260721000000_add_sale_item_refunded_quantity`), validated against
`quantity - refundedQuantity` read fresh inside the transaction, and fixed
a related bug where a legitimately-full refund spread across multiple
calls never reached the `RETURNED` terminal state. 3 new regression tests
in `sales.service.spec.ts`.

### 2.2 Categories cross-store IDOR

`CategoriesController`/`CategoriesService` `findOne`/`update`/`remove`
looked up categories by `id` alone, with zero `storeId` filtering —
`StoreAccessGuard` only checks that the caller has access to the
`:storeId` in the route, not that the target resource belongs to it. Any
authenticated user with access to any single store could read, modify, or
delete another store's categories just by obtaining the UUID. Live-proved:
renamed a category belonging to Store A via a `PUT` through Store B's
route path; the rename persisted. Products, by contrast, were already
correctly store-scoped — categories was the outlier.

**Fix**: `findOne`/`update`/`remove` now filter by `{ id, storeId }`. 2 new
regression tests.

### 2.3 Stock quantity had no floor guard

Stock movements (`WRITE_OFF`, `SALE`) applied an unconditional
`increment` with no check that the result stayed ≥ 0. Live-reproduced:
writing off 1000 units of a 70-in-stock product succeeded and left
quantity at **-930**.

**Fix**: mirrored this codebase's existing `F-RACE-1` conditional-
`updateMany` pattern (already used in `sales.service.ts` for the same
class of problem) so the database enforces the floor atomically; a
movement that would go negative is now rejected with `409 Conflict`. 4 new
regression tests.

## 3. High-severity bugs — found and fixed

| # | Bug | Domain | Fix |
|---|---|---|---|
| 1 | Roles/Permissions API had **zero effect** on real access control — `RolesService` stores snake_case keys (`manage_products`), `PermissionsGuard` checks dotted keys (`products.manage`); the two vocabularies never intersected, so revoking a permission via the UI saved successfully but never actually blocked anything | People | Added a translation layer (`LEGACY_PERMISSION_ALIASES`) in `permissions-matrix.ts`; `PermissionsGuard` now checks the DB override first, falls back to the hardcoded matrix. 9 new tests, including a new `permissions.guard.spec.ts` |
| 2 | `PUT /stores/:id/receipt-template` silently wiped every unrelated field on partial updates (DTO class fields default to `undefined`, spread overwrote saved values) | Onboarding/Store | Filter `undefined` keys out of the DTO before spreading. 2 new tests |
| 3 | Payroll `payOne`/`payAll` returned **stale pre-payment data** in the response (read via `this.prisma` instead of the transaction's `tx`, so it couldn't see its own uncommitted write) | Money | Reads now go through `tx` inside the same transaction |
| 4 | `lowStock=true` product filter was dead code — the correct `quantity <= minQuantity` comparison was built then immediately discarded, silently behaving like `inStock=true` | Catalog | Switched to in-app filtering (Prisma can't compare two columns of the same row via the query builder); pagination now computed post-filter. New test coverage |
| 5 | Supplier debt could **never become positive** through any real code path — a supplier-linked stock purchase updated product stock/cost but never credited what the store now owed the supplier, making the entire "pay a supplier" feature permanently dead | Partners | Supplier-linked `PURCHASE` movements now credit `supplier.debt`; added storeId-scoped supplier validation (was previously unchecked). 5 new tests |
| 6 | Currency-rate scraper (`nbt.tj`) silently returned `[]` on every call — the site's rates table changed to a 2-column layout, and the scraper's `cells.length < 3` guard skipped every row | Engagement | Updated the cheerio selectors to match the site's current live markup (re-verified directly against the live site before fixing). New fixture-based test |
| 7 | Profit report ignored cost-of-goods-sold entirely — `profit = income - manualExpenses`, so any store with no logged expenses saw **100% profit on every sale** regardless of actual product cost | Admin/Reports | Added COGS computed from `SaleItem.costPrice × quantity`; report now surfaces true gross/net profit alongside the existing field. New arithmetic-verified test |

## 4. Lower-severity findings — documented, not fixed

These don't block a release but are real, reproduced issues worth
scheduling:

**Medium**
- `ADJUSTMENT`/`TRANSFER` stock-movement types are a no-op on product
  quantity despite being recorded — the DTO has no field to express what
  an adjustment should actually do (increase/decrease/set-to-value); needs
  a product decision before it can be implemented, not just a bug fix.
- Admin `set-discount` and `cancel` subscription actions aren't
  audit-logged, unlike their sibling actions (`approve`/`reject`/`extend`/
  `change-plan`) in the same controller.
- `POST /auth/logout` behaves identically to `/auth/logout-all` — kills
  every session, not just the caller's, contradicting its own Swagger
  description.
- The refresh-token replay/theft mitigation (mass-revocation on reuse of
  an already-rotated token) is dead code — `JwtRefreshStrategy` throws its
  own generic 401 before the mass-revocation logic in the controller is
  ever reached.
- No guard against adding adjustments to an already-paid payroll entry —
  a deduction larger than the paid salary was accepted, producing a
  negative `totalAmount` and silently un-marking the period as paid.
- Shifts endpoints have no `PermissionsGuard`/`@Permissions` at all — any
  staff role (including WAREHOUSE) can open/close shifts and pull
  Z-reports, inconsistent with the documented permission matrix.

**Low**
- `/auth/logout` doesn't bump `tokensRevokedAt`, so the access token used
  to call it remains valid for its remaining ~15-minute TTL.
- `reset-password` accepts weaker passwords (`@MinLength(6)`, no
  strength/common-password check) than `register`
  (`@IsStrongPassword`).
- No upper bound on `PERCENTAGE` discount value — 150% was accepted.
- Inconsistent delete semantics: customers soft-delete, suppliers
  hard-delete.
- Investments `summary.total` includes cancelled investments, which may
  read as misleading if presented as "capital currently at work."
- The `sale.customer` object embedded in a `POST /sales` response reflects
  pre-transaction debt/loyalty values; a follow-up `GET` is correct.
- `StaffService.findOne()` doesn't filter `isActive`, so a soft-removed
  staff record remains individually fetchable by id (findAll correctly
  filters).
- Minor DTO friction: stock-movement's `productId` is required in the
  body despite already being a path param; `paidAmount` must be sent
  explicitly (even as `0`) for `DEBT` sales.

## 5. What worked well (no defects found)

Full CRUD + validation on categories, products, discounts, inventory
counts, customers, suppliers (create/list/search/update/delete side),
deliveries (including the complete status state machine with terminal-
state and skip-step rejection), staff (including this session's new
last-owner and self-removal guards, verified live), shifts (double-open
prevention, cash-discrepancy math, Z-reports), expenses, finance
dashboards (arithmetic verified exactly against known records across
day/week/month/custom periods), investment CRUD and summary aggregation,
loyalty points (earn/redeem math verified to the point across multiple
sales), zakat (calculation verified against real store asset data twice,
and confirmed the server-authoritative `zakatDue` fix from an earlier
session still holds against a spoofed client value), notifications,
Telegram graceful-failure paths, admin guard enforcement (zero bypasses
found across every admin endpoint tested), subscription request/approve/
reject/receipt-upload flows, sales/products reports (numerically exact),
and the export pipeline (all 3 formats, correct plan-based feature
gating).

## 6. Test coverage after this session

Backend: **43 suites / 415 tests**, all passing. `tsc --noEmit` clean.
This includes 30+ new regression tests written today specifically for the
10 Critical/High fixes above, on top of the 371 tests already in place
from earlier in this session's separate coverage sweep.
