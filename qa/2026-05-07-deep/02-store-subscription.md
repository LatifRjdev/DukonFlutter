# Phase 2 — Store & subscription

**Date:** 2026-05-07
**Test users:** `+992909000001/qatest1234` (U1), `+992909000002/qatest1234` (U2)
**Resources created:** qa-store-A, qa-store-B (both U1), 99 products on store-A.

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Create first store via UI | 🟢 PASS | — | qa-store-A created. Got own subscription: PREMIUM/TRIAL, trial=+7d, currentPeriodEnd=+7d. |
| Create second store via API | 🟢 PASS | — | qa-store-B created with its own independent PREMIUM/TRIAL subscription. |
| Cross-store isolation (U2 reads U1 store) | 🟢 PASS | — | All 4 endpoints (`/store`, `/categories`, `/products`, `/subscription`) return 403 with "You do not have access to this store". |
| Subscription view via API | 🟢 PASS | — | All fields present, planConfig embedded with limits. |
| Request plan change (TRIAL → BUSINESS) | 🟢 PASS | — | 201 + payment row created (amount=400 TJS, currency=TJS, status=PENDING, method=CARD, note="Plan change request to BUSINESS"). |
| Admin approve payment | 🟢 PASS | — | 200 + plan=BUSINESS + status=ACTIVE + currentPeriodEnd extended +30d from trialEnd. |
| Approve idempotency | 🟢 PASS | — | Re-calling approve on APPROVED payment is no-op (currentPeriodEnd unchanged). The fix from earlier sprint holds. |
| Admin reject payment | 🟢 PASS | — | 200 + status=REJECTED + note overwritten to reason. Subscription unchanged (stays on prior plan). |
| Approve a previously REJECTED payment | 🟢 PASS | — | 400 "Cannot approve a payment that was previously rejected" — guard from earlier fix works. |
| Admin change-plan to START (downgrade) | 🟢 PASS | — | Subscription transitions to START with the correct planConfig (maxStores=1, maxProducts=500, maxStaff=2). |
| **Plan limits — server-side enforcement** | 🔴 **FAIL** | **P0** | See F2.1 below. **Limits are decorative.** |
| **Plan boolean flags — gating** | 🔴 **FAIL** | **P0** | See F2.2 below. **`hasTelegram`, `hasExport`, `hasReportsAll`, `hasInventory`, `hasDelivery`, `hasAllPush` are never checked anywhere.** |
| Request-change DTO field name | 🟡 NIT | P3 | DTO expects `paymentMethod` not `method`. The schema-generated payment record itself stores `method`. Inconsistency between request DTO and response shape. |
| Reject preserves original note | 🟡 NIT | P3 | Rejecting overwrites the original `Plan change request to BUSINESS` note with the rejection reason — the audit trail loses what plan the user wanted. |

## Findings

### F2.1 — P0: Server-side plan limits never enforced

**Repro:**
```bash
# Downgrade store-A to START (maxProducts=500)
curl -X PUT $ADMIN/api/proxy/admin/subscriptions/$SUB/change-plan -d '{"plan":"START"}'
# Try creating products beyond the limit
for i in $(seq 1 600); do
  curl -X POST $API/api/stores/$STORE/products -d '{"name":"limit-test-$i","sellPrice":1,"unit":"PCS"}'
done
```

**Expected:** 500 succeed, 501st returns 4xx with "Plan limit reached" or similar.

**Observed:** 99 products created before the rate limiter (throttler) kicked in at ~100 req/window. Server rejected the 100+ with HTTP 429 *ThrottlerException*, not a plan-limit error. After throttler resets, more would create freely.

**Root cause (verified by grep):**
```bash
grep -rn "maxProducts\|maxStores\|maxStaff\|maxDiscounts" api/src \
  | grep -v spec.ts
```
Returns matches **only** in:
- `admin/dto/update-plan.dto.ts` — admin can edit the config
- `admin/admin.service.ts` — admin writes the config
- `subscriptions/subscriptions.service.ts:44` — defaults seed
- **Zero matches in `products.service.ts`, `stores.service.ts`, `staff/users service`, `discounts.service.ts`, etc.**

**Effect:** A user on START plan (200 TJS/mo) gets the same product/store/staff/discount headroom as PREMIUM (600 TJS/mo). The "plan tier" is purely cosmetic. There's no revenue-protection mechanism.

**Fix path:** add a `SubscriptionGuard` (or service-level call) to every resource-create endpoint that:
1. Reads the active subscription's planConfig.
2. Counts existing resources for the storeId.
3. Throws `ForbiddenException` with "Plan limit reached: <plan> allows <N>" on overflow.

Suggested touchpoints: `ProductsService.create`, `StoresService.create`, `StaffService.create`, `DiscountsService.create`. Same idea applies to a per-store-on-user limit.

### F2.2 — P0: Plan boolean feature flags never checked

**Repro:**
```bash
grep -rn "hasReportsAll\|hasExport\|hasTelegram\|hasAllPush\|hasDelivery\|hasInventory" api/src \
  | grep -v spec.ts
```

Returns matches **only** in `admin/dto/update-plan.dto.ts`, `admin/admin.service.ts`, and the seed defaults — same pattern as F2.1.

**Mobile side:** decoded into `SubscriptionState` (subscription_state.dart) but **never consumed** to gate UI:
```bash
grep -rn "limits\.\|hasTelegram\|hasExport\|hasReportsAll" app/lib/presentation
```
Only matches the bloc data class, no `if (state.hasTelegram)` checks in any page or widget.

**Effect:** START-plan users can:
- Send Telegram receipts (despite `hasTelegram=false`)
- Export reports to PDF/Excel (despite `hasExport=false`)
- Use inventory module (despite `hasInventory=false`)
- See full reports vs limited ones (despite `hasReportsAll=false`)

The plan tiers offer literally no functional differences today.

**Fix path:** decision needed —
- (a) Wire the flags into both API guards AND UI gates, OR
- (b) Drop the flags entirely if no plan differentiation is intended,
- (c) Re-design plans around hard limits (storage, sales/month) instead.

Either way, the schema currently lies to the user.

### F2.3 — P3: Per-store subscription model

Each new store gets its own independent 7-day PREMIUM trial. So a user
who creates 5 stores gets 5 independent trials. Combined with F2.1
(no maxStores enforcement), this means a user could in theory create
thousands of stores, each on its own free PREMIUM trial, indefinitely.

Already covered by F2.1 mitigation (enforce maxStores per user across
all owned stores), but worth flagging that the policy is "trial per
store, not per user".

### F2.4 — P3: `paymentMethod` vs `method` field naming

`POST /api/stores/:id/subscription/request-change` DTO requires
`paymentMethod`. The persisted Payment row exposes the same value as
`method` on read. Either align the DTO field name to `method` or
rename the DB column to `paymentMethod`. Minor but causes confusion
when reading API logs vs writing client code.

### F2.5 — P3: Reject overwrites original request note

`note` field is reused for both "what plan did the user request" (set
on request-change) and "why was this rejected" (set on admin reject).
Result: after rejection, the audit trail has no record of which plan
the user wanted. Add a separate `rejectionReason` column or store
both in JSON.

## Phase 2 summary

11 PASS / **2 P0** (the big ones — plan limits + plan flags decorative
only) / 0 P1 / 0 P2 / 3 P3 nits.

The two P0s mean the entire subscription monetization story is broken
before launch. Either gates need to be wired in, or pricing needs to be
re-thought, or both. This is the most important finding of the audit.

Screenshots: `screenshots/02-store/` (4 captured: store-name-filled,
after-create, login-filled-from-phase-1, after-login).
