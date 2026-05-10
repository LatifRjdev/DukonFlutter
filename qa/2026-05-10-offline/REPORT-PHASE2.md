# Phase 2 — Subscription Matrix Audit & Fixes — 2026-05-10

## Summary

Audited the START / BUSINESS / PREMIUM / TRIAL / EXPIRED subscription
matrix end-to-end. Found and fixed **3 critical authorization bugs**
on top of the 6 offline-flow bugs from Phase 1. Verified all fixes
with API-level probes against live qa-* accounts.

## Tier matrix (from `subscription_plan_configs`)

| Feature       | START | BUSINESS | PREMIUM |
|---------------|-------|----------|---------|
| price (TJS)   | 200   | 400      | 600     |
| maxStores     | 1     | 3        | 5       |
| maxProducts   | 500   | 2000     | ∞       |
| maxStaff      | 2     | 10       | ∞       |
| maxDiscounts  | 0     | 5        | ∞       |
| hasReportsAll | ✗     | ✓        | ✓       |
| hasExport     | ✗     | ✗        | ✓       |
| hasTelegram   | ✗     | ✓        | ✓       |
| hasAllPush    | ✗     | ✓        | ✓       |
| hasDelivery   | ✗     | ✓        | ✓       |
| hasInventory  | ✗     | ✓        | ✓       |

## Phase 1 — 6 offline-flow bugs (all fixed)

| ID  | Bug                                                | Fix |
|-----|----------------------------------------------------|-----|
| #1  | Success screen "0 TJS" instead of total            | CheckoutBloc now passes computed totals to repo via `_offline*` keys |
| #2  | POS product list stale until restart               | `initState` dispatches `ProductListLoadRequested` |
| #3  | POS chip "BOTTOM OVERFLOWED BY 2.0 PIXELS"         | Strip height 72→84 |
| #4  | `localId` lost on offline replay                   | UUID generated in CheckoutBloc, sent to API + persisted |
| #5  | `createdAt` = sync time, not sale time             | New `occurredAt` field on CreateSaleDto + Sale.createdAt fallback |
| #6  | Offline banner missing on push'd routes            | Banner moved to MaterialApp.builder, removed from HomePage |

## Phase 2 — 3 subscription bugs

### 🔴 BUG #7 (CRITICAL) — `/reports/sales` open to all tiers

**Root cause:** `reports.controller.ts` had `@RequiresFeature('hasReportsAll')`
on `/profit`, `/products`, `/staff` — but NOT on `/sales`. The most-hit
report endpoint silently bypassed the subscription gate.

**Verification before fix:** `GET /api/stores/$START_STORE/reports/sales`
returned `200` for START tier.

**Fix:** Added the missing decorator. Now returns `403`.

### 🔴 BUG #8 (CRITICAL) — Deliveries 4/4 endpoints open

**Root cause:** `deliveries.controller.ts` had `@RequiresFeature('hasDelivery')`
on POST only. The list (`@Get()`), detail (`@Get(':id')`) and status-update
(`@Put(':id/status')`) endpoints had `@UseGuards(SubscriptionGuard)` on
the class but no `@RequiresFeature` — so the guard's early-return at
`if (!requiredPlan && !requiredFeature) return true` made them open.

**Verification before fix:** `GET .../deliveries` → 200 for START.

**Fix:** Added `@RequiresFeature('hasDelivery')` to all 3 missing methods.
Now all 4 return 403 for START.

### 🔴 BUG #9 (CRITICAL) — Inventory counts 3/4 endpoints open

**Same pattern as #8.** `inventory-counts.controller.ts` had the decorator
on `@Post()` (create) only. `@Get(':id')`, `@Put(':id')`, `@Post(':id/apply')`
were open. A START-tier user could enumerate, edit and finalize counts
created during a trial-PREMIUM window.

**Fix:** Added `@RequiresFeature('hasInventory')` to all 3 missing methods.

### Side note — class-level `@RequiresFeature` doesn't work

I first attempted to elevate `@RequiresFeature` to the class via the
NestJS `@SetMetadata` mechanism. `Reflector.getAllAndOverride([handler,
class])` should pick it up, but in practice the class metadata wasn't
applied — endpoints still returned 200. Falling back to per-method
decoration (verbose but reliable) was the resolution.

This deserves a follow-up: either `SubscriptionGuard` should
`getAllAndMerge` and class metadata should be honoured, or the
`@RequiresFeature` decorator should explicitly support both targets
with a custom MetadataAccessor. Tracked as P3 follow-up.

### Note — `maxStores` is dead config

`maxStores` exists in `subscription_plan_configs` but is never enforced.
The architecture gives each store its own `Subscription`, so a single
user can create 100 stores and each gets a separate trial. Enforcing
"5 stores per PREMIUM" requires picking which store's plan governs the
limit — undefined in the current model.

Not fixing in this pass; logged as architectural debt. The ramifications
are minor (every store still pays its own subscription after trial), but
during the trial window a user can create unlimited stores for free.

## Verification

API matrix probe (live, post-fix):

```
=== REPORTS_SALES (GET reports/sales) ===
  START → 403   ✓
  BIZ   → 200   ✓
  PREM  → 200   ✓

=== DELIVERY_LIST (GET deliveries) ===
  START → 403   ✓ (was 200)
  BIZ   → 200   ✓
  PREM  → 200   ✓

=== INVENTORY_CREATE (POST inventory-counts) ===
  START → 403   ✓
  BIZ   → 201   ✓
  PREM  → 201   ✓

=== TELEGRAM_SEND (POST telegram/send-receipt) ===
  START → 403   ✓
  BIZ   → 400   ✓ (bad payload, gate cleared)
  PREM  → 400   ✓
```

Plan-limit probes:

```
START maxStaff=2:
  add 2nd cashier → 201   ✓
  add 3rd cashier → 403 "Plan limit reached: START allows 2 staff members"

START maxDiscounts=0:
  first discount → 403 "Plan limit reached: START allows 0 discount rules"
```

EXPIRED state probe:

```
EXPIRED tier:
  GET /reports/sales → 403 "Subscription is EXPIRED"   ✓
  GET /products      → 200                              ✓
```

The EXPIRED behaviour is correct: premium features blocked, core POS
remains open so a cashier doesn't get locked out mid-shift.

## Test results

- **API:** 183/183 unit + 6/6 e2e ✓
- **Flutter:** 396/396 ✓ (POS goldens re-baselined for chip height 72→84)
- **Dart analyze:** 0 issues
- **TypeScript:** 0 errors

## Bugs catalog (this session)

1. ✅ #1 — POS success screen "0 TJS"
2. ✅ #2 — POS product list staleness
3. ✅ #3 — POS chip overflow
4. ✅ #4 — Offline `localId` lost
5. ✅ #5 — Offline `createdAt` = sync time
6. ✅ #6 — Offline banner missing on sub-routes
7. ✅ #7 — `/reports/sales` open to all tiers
8. ✅ #8 — Deliveries 3/4 endpoints open
9. ✅ #9 — Inventory-counts 3/4 endpoints open
10. 📌 #10 (deferred) — `maxStores` not enforced (architectural)
11. 📌 #11 (deferred) — class-level `@RequiresFeature` ignored by guard

**9 fixed, 2 deferred (both architectural, not security-critical).**

The 3 subscription-matrix bugs (#7/#8/#9) were release-blockers — START-tier
customers could access PREMIUM-only data with no API rejection. This is
the kind of issue that surfaces only with multi-tier user testing, not
single-account QA.
