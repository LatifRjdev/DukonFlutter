# Tier × Feature matrix QA — 2026-05-10

End-to-end verification that the 3 subscription tiers (START / BUSINESS /
PREMIUM) actually gate the right features, after the F2.1+F2.2 fixes
landed in Sprint A.

## Setup

| Tier     | User                        | Store ID prefix | Subscription |
|----------|-----------------------------|-----------------|--------------|
| START    | `+992910001001 / qatest1234`| `1823aa90`      | START / TRIAL |
| BUSINESS | `+992910001002 / qatest1234`| `d169d2e8`      | BUSINESS / TRIAL |
| PREMIUM  | `+992910001003 / qatest1234`| `c64ec2dc`      | PREMIUM / TRIAL |

3 users seeded directly via `api/scripts/seed-3-tier-users.ts` (bypasses
register throttler). 3 stores created via `POST /stores`. Plans assigned
via `PUT /api/proxy/admin/subscriptions/:id/change-plan` from the admin
panel as the seed-admin user — all 3 returned HTTP 200 with the
expected `plan` field.

⚠️ **Note on status**: change-plan switches the `plan` field but leaves
`status=TRIAL`. The plan-limit / plan-flag gates read `subscription.plan`
(not `status`) so they apply correctly during trial. To test post-trial
ACTIVE behavior, would need to approve a payment.

## 🚨 P1 found and fixed during this run

**F-Sprint-A-2 — `SubscriptionGuard` not attached.** Sprint A added
`@RequiresFeature('hasTelegram')` and `@RequiresFeature('hasAllPush')`
metadata decorators to `telegram.controller.ts` and
`notifications.controller.ts`, but neither controller had
`SubscriptionGuard` in its `@UseGuards(...)` list. The metadata was
written but never read.

Effect (verified live before fix): START-tier user could:
- POST `/telegram/send-receipt` — got past the gate, returned 404
  "Sale not found" instead of 403
- PUT `/notifications/settings` — got past the gate, returned 204
  (settings actually saved)

Fix (this commit): added `SubscriptionGuard` to both `@UseGuards(...)`
arrays. Live retest after API restart:
```
START telegram → 403 "This feature (hasTelegram) is not available on your current plan"
START notifications → 403 "This feature (hasAllPush) is not available on your current plan"
```

✅ Both gates now fire correctly.

## Tier × Feature matrix (after fix)

Status code returned per probe. ✅ = expected for tier; 🚨 = wrong.

| Feature / endpoint                                | START  | BUSINESS | PREMIUM | Notes |
|---------------------------------------------------|--------|----------|---------|-------|
| **Plan-flag gates (`@RequiresFeature`)**          |        |          |         |       |
| POST `/telegram/send-receipt` (hasTelegram)       | **403** ✅ | 404 ✅ | 404 ✅  | 404 = past gate, "sale not found" with garbage UUID |
| POST `/inventory-counts` (hasInventory)           | **403** ✅ | 400 ✅ | 400 ✅  | 400 = past gate, "no active products" |
| POST `/deliveries` (hasDelivery)                  | **403** ✅ | 404 ✅ | 404 ✅  | 404 = past gate, "sale not found" |
| GET `/reports/profit` (hasReportsAll)             | **403** ✅ | 200 ✅ | 200 ✅  | full payload returned on BUSINESS+ |
| GET `/reports/products` (hasReportsAll)           | **403** ✅ | 200 ✅ | 200 ✅  |  |
| PUT `/notifications/settings` (hasAllPush)        | **403** ✅ | 204 ✅ | 204 ✅  |  |
| **Plan-limit gates (`assertWithinPlanLimit`)**    |        |          |         |       |
| POST `/discounts` (maxDiscounts)                  | **403** ✅ | 201 ✅ | 201 ✅  | START=0, BUSINESS=5, PREMIUM=∞ |
| **Basic CRUD (no plan gating)**                   |        |          |         |       |
| POST `/categories`                                | 201 ✅ | 201 ✅  | 201 ✅  |  |
| POST `/products`                                  | 201 ✅ | 201 ✅  | 201 ✅  |  |
| POST `/customers`                                 | 201 ✅ | 201 ✅  | 201 ✅  |  |
| POST `/suppliers`                                 | 201 ✅ | 201 ✅  | 201 ✅  |  |
| POST `/expenses`                                  | 201 ✅ | 201 ✅  | 201 ✅  |  |
| GET `/finances/dashboard`                         | 200 ✅ | 200 ✅  | 200 ✅  |  |
| GET `/reports/sales`                              | 200 ✅ | 200 ✅  | 200 ✅  | basic sales report not under hasReportsAll |
| **Cross-tier isolation**                          |        |          |         |       |
| START user → BUSINESS store products              | 403 ✅ | —        | —       |  |
| BUSINESS user → PREMIUM store products            | —      | 403 ✅  | —       |  |
| PREMIUM user → START store products               | —      | —        | 403 ✅ |  |

## Summary by tier

### START (200 TJS / month)
- ✅ All 6 boolean plan flags correctly block (3 of which only became
  effective in this commit's SubscriptionGuard fix).
- ✅ `maxDiscounts=0` enforced (POST returns 403 with the upgrade hint).
- ✅ Basic CRUD (categories/products/customers/suppliers/expenses)
  works — no gating where there shouldn't be.
- ✅ `reports/sales` (basic daily report) is open; only `reports/profit`,
  `/products`, `/staff` are gated by hasReportsAll.

### BUSINESS (400 TJS / month)
- ✅ All 6 boolean flags pass (telegram/inventory/delivery/reportsAll/allPush).
  Past-the-gate behavior is correct (saleId-not-found returned, etc.)
- ✅ Discounts up to maxDiscounts=5 allowed.
- ✅ Same CRUD passes as START.

### PREMIUM (600 TJS / month)
- Same as BUSINESS for the 6 flags exposed in this matrix.
- Difference would be `hasExport` (PDF/Excel — server-side gate not
  implemented; lives on mobile client) and unlimited
  maxStores/Products/Staff/Discounts.

## Findings

### 🟢 Sprint A+B fixes verified working
- F2.1 plan-limit (maxDiscounts on START → 403). Other limits not
  stress-tested past the throttler this run.
- F2.2 plan-flag for `hasReportsAll`, `hasInventory`, `hasDelivery`
  (already worked from earlier Sprint A).
- F2.2 plan-flag for `hasTelegram`, `hasAllPush` — **fixed this commit**
  (SubscriptionGuard was missing from `@UseGuards` despite the
  decorator being added in Sprint A).
- F1.2 RU validation messages working ("Поле «chatId» не разрешено в
  этом запросе" surfaced earlier).
- Cross-store isolation 100% intact across tiers.

### 🚨 New finding F-T1.1 (this commit)
**Severity: P1.** `SubscriptionGuard` was attached only to 3 of 5
controllers that should use it. Telegram + notifications metadata
was decorative until this commit. Audit recommended for any future
`@RequiresFeature` decorator additions: also touch the controller
class-level `@UseGuards(...)` to register `SubscriptionGuard`.

### 🟡 Carried forward — not new
- Plan-change endpoint leaves `status=TRIAL` after `change-plan`
  (from earlier QA). Acceptable since gates use `plan` field.
- Throttler still aggressive on auth/register/login.

## Test artifacts

Test users + stores left in DB for further inspection:
- `qa-start-store` (1823aa90...) on START
- `qa-business-store` (d169d2e8...) on BUSINESS
- `qa-premium-store` (c64ec2dc...) on PREMIUM

Cleanup: delete the 3 stores from admin panel (cascades).
Seed script: `api/scripts/seed-3-tier-users.ts`.
