# Subscription lifecycle live test — 2026-05-12

## Setup

Driven by `run.sh` against the live API at `http://localhost:4455` and the
`dukonpro-db` Postgres container.

- **Admin**: `+992000000000` / `admin123` (`isAdmin=true`)
- **qa-business owner**: `+992910001002` / `qatest1234` → store `qa-business-store` (`d169d2e8-…`), sub starts TRIAL/BUSINESS
- **qa-premium owner**: `+992910001003` / `qatest1234` → store `qa-premium-store` (`c64ec2dc-…`), sub starts TRIAL/PREMIUM

Each scenario seeds prereq state via SQL, calls the real API, then verifies via
SELECT. The script is repeatable and restores both subs to a clean
`TRIAL/+5d` state at the end.

## Endpoints discovered

Source: `api/src/modules/subscriptions/subscriptions.controller.ts` and DTOs in
`api/src/modules/subscriptions/dto/`.

| Action | Path | DTO |
|--------|------|-----|
| Owner: request plan change (creates PENDING payment) | `POST /api/stores/:storeId/subscription/request-change` | `{plan: START\|BUSINESS\|PREMIUM, paymentMethod: CARD\|MOBILE_TRANSFER\|CASH}` |
| Owner: upload receipt | `POST /api/stores/:storeId/subscription/upload-receipt/:paymentId` (multipart `file`) | — |
| Owner: get payment history | `GET /api/stores/:storeId/subscription/payments` | — |
| Admin: list pending payments | `GET /api/admin/subscriptions/pending-payments` | — |
| **Admin: approve payment → activates sub** | `PUT /api/admin/subscriptions/:id/approve-payment/:paymentId` | (no body) |
| Admin: reject payment | `PUT /api/admin/subscriptions/:id/reject-payment/:paymentId` | `{reason: string}` |
| **Admin: extend by N days** | `PUT /api/admin/subscriptions/:id/extend` | `{days: int ≥ 1}` |
| **Admin: change plan** | `PUT /api/admin/subscriptions/:id/change-plan` | `{plan: START\|BUSINESS\|PREMIUM}` |
| Admin: set discount | `PUT /api/admin/subscriptions/:id/set-discount` | `SetDiscountDto` |
| Admin: cancel | `PUT /api/admin/subscriptions/:id/cancel` | (no body) |

Schema notes (`prisma/schema.prisma`):
- `Subscription` columns are camelCase via `@@map("subscriptions")` — raw SQL uses double-quoted `"currentPeriodEnd"`, `"storeId"`.
- `Payment` write-side DTO field is `paymentMethod`; persisted column is `method` (asymmetry preserved for backwards compatibility — see comment at `request-change.dto.ts:23-27`).
- `PaymentStatus` enum: `PENDING / APPROVED / REJECTED / COMPLETED / FAILED / REFUNDED`.
- `SubscriptionStatus` enum: `TRIAL / ACTIVE / PAST_DUE / CANCELLED / EXPIRED`.

## Scenario results

| # | Scenario | Expected | Actual | Status |
|---|----------|----------|--------|--------|
| 1 | TRIAL → ACTIVE via admin approve-payment | sub.status=ACTIVE, payment.status=APPROVED | sub.status=ACTIVE, payment.status=APPROVED | ✓ |
| 2 | ACTIVE renewal extends currentPeriodEnd | new periodEnd > old | 2026-05-22 → 2026-06-21 (+30d, extended from currentPeriodEnd as designed) | ✓ |
| 3 | Admin extend +7 days | delta = 7 days | delta = 7.000…d | ✓ |
| 4 | PREMIUM → START downgrade — `/reports/sales` 200 → 403 | Immediate access loss (no caching) | BEFORE=200, AFTER=403, plan=START | ✓ |
| 5 | ACTIVE → EXPIRED via cron | status=EXPIRED + guard returns 403 | Cron has no manual trigger; simulated via the same `UPDATE … WHERE status IN ('ACTIVE','TRIAL') AND currentPeriodEnd < NOW()` the cron runs. Guard rejects EXPIRED with 403 as expected. | ? |
| 6 | EXPIRED → ACTIVE via reactivation | status=ACTIVE, plan=PREMIUM, periodEnd>now | status=ACTIVE, plan=PREMIUM, periodEnd>now=true | ✓ |

**Net: 5 ✓ / 0 ✗ / 1 ?**

## Audit log entries verified

```
          action          |  entityType  |               entityId               |        createdAt
--------------------------+--------------+--------------------------------------+-------------------------
 subscription.approve     | subscription | 8b18285a-6678-47b9-8079-e7f45fe69bde | 2026-05-12 05:57:07.643
 subscription.plan_change | subscription | 8b18285a-6678-47b9-8079-e7f45fe69bde | 2026-05-12 05:57:07.306
 subscription.approve     | subscription | 00673821-7656-4df3-8660-b56ff66bf1a5 | 2026-05-12 05:57:06.926
 subscription.approve     | subscription | 00673821-7656-4df3-8660-b56ff66bf1a5 | 2026-05-12 05:57:06.657
```

- **3× `subscription.approve`** — one per approve-payment call (scenarios 1, 2, 6). ✓
- **1× `subscription.plan_change`** — admin downgrade (scenario 4). ✓
- **0× `subscription.extend`** — see Findings. ✗

Note: `subscription.approve` rows are written with `userId='system'` (hard-coded literal in `subscriptions.service.ts:330`), not the actual admin user id. `subscription.plan_change` has the same issue (`userId='system'` at line 442). Only `subscription.reject` records the real `reviewedBy`.

## Findings

- **F-1 (P3): `subscription.extend` is not audited.** `adminExtend` (service.ts:406-422) silently mutates `currentPeriodEnd` without an `audit.record(…)` call. Approvals, rejections, and plan changes all log; extend is the gap. For an admin operation that gives away revenue (free days), this should be logged for accountability.
- **F-2 (P2): `subscription.approve` and `subscription.plan_change` audit rows record `userId='system'` instead of the acting admin.** Only `subscription.reject` correctly threads `reviewedBy` into the audit row. With the current data, you cannot answer "which admin approved this payment?" from `audit_logs` alone — you have to cross-reference `payments.reviewedBy`. For `plan_change` there is no equivalent fallback column at all.
- **F-3 (P3): No manual trigger for the auto-expiry cron (`@Cron('0 0 * * *')` at `subscriptions.service.ts:486`).** The transition itself works (we confirmed: SQL flip to EXPIRED + guard returns 403), but the cron *handler* (which also fires per-owner push notifications) cannot be exercised without waiting until midnight or restarting the scheduler. Recommendation: add an admin-only `POST /api/admin/subscriptions/run-expiry-check` that calls `checkExpiredSubscriptions()` directly. Same applies to `sendExpiryReminders` at line 523.
- **F-4 (P3 — confirmation, not a bug): downgrade access loss is immediate** (no caching layer on `SubscriptionGuard`). PREMIUM → START flips the `/reports/sales` response from 200 to 403 within a single round-trip. Good.
- **F-5 (P3): renewal-while-active extends from `currentPeriodEnd`, not from `now`.** This is the intended behaviour per `subscriptions.service.ts:286-289` — paying early during an active period stacks +30d onto the existing end, you don't lose the remaining days. Worth documenting in user-facing copy because it's not obvious.

## Recommendations

- **R-1**: Add `audit.record(reviewedBy, 'subscription.extend', 'subscription', subscriptionId, { days: dto.days, oldEnd, newEnd })` in `adminExtend`. Wire `@CurrentUser('id')` through the controller signature like `approvePayment` already does.
- **R-2**: Replace the literal `'system'` userId in the `subscription.approve` and `subscription.plan_change` audit calls with the real acting admin id. Pass it through the controller (already done for approve in the controller signature — `@CurrentUser('id') userId` — but the value is then *ignored* by `audit.record` in favor of `'system'`).
- **R-3**: Add an admin endpoint `POST /api/admin/subscriptions/run-expiry-check` (and `…/send-expiry-reminders`) that delegates to the existing cron methods, gated by `AdminGuard`. Lets QA exercise the full code path (DB flip + push notifications) without timing tricks.

## Files

- `qa/2026-05-12-subscription-lifecycle/run.sh` — driver script (executable, repeatable)
- `qa/2026-05-12-subscription-lifecycle/results.txt` — last-run pass/fail log
- `qa/2026-05-12-subscription-lifecycle/REPORT.md` — this file
