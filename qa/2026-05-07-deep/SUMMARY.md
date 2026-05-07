# Deep QA — A→Я Cross-cutting Summary

**Date:** 2026-05-07
**Spec:** `docs/superpowers/specs/2026-05-07-deep-qa-design.md`
**Plan:** `docs/superpowers/plans/2026-05-07-deep-qa.md`
**Test stack:** API :4455, admin :3001, emulator-5554 (Pixel 1080×2400, API 36)
**Live data created:** 2 stores (qa-store-A, qa-store-B), 102 products,
6 receipts (R-000001..R-000006 with R-000003 missing), 1 cashier
staff, 1 shift opened+closed, 1 customer (debt 13 TJS), 1 supplier,
1 inventory count, 1 expense, 5 subscription payment rows.

## Verdict

🟡 **YELLOW** — no app-level crashes anywhere; the entire stack walks
end-to-end. But **two P0 monetization bugs** plus **five P1 bugs** in
revenue and data correctness need to land before launch.

## Findings — severity matrix

### P0 (must fix before any submission)

| ID | Finding | Phase | Fix path |
|---|---|---|---|
| F2.1 | Numeric plan limits (`maxStores`, `maxProducts`, `maxStaff`, `maxDiscounts`) NEVER enforced server-side | 2 | Add a per-resource guard or service-call to throw `ForbiddenException` on overflow. |
| F2.2 | Boolean plan flags partially decorative — `hasExport`, `hasTelegram`, `hasAllPush` ungated; `hasReportsAll`, `hasInventory`, `hasDelivery` correctly use `@RequiresFeature`. | 2/7 | Add `@RequiresFeature` to PDF export, Telegram send-receipt, push-settings endpoints. |

These two together mean the **subscription tiers are largely cosmetic**:
a START-plan user (200 TJS/mo) gets unlimited products/stores/staff
plus Telegram and PDF export which are supposed to be PREMIUM-only.

### P1 (must fix before launch)

| ID | Finding | Phase | Fix path |
|---|---|---|---|
| F1.1 | Onboarding 4-slide carousel never shows on fresh install | 1 | Investigate `splash_page.dart` navigation — `hasSeenOnboarding` flag persistence on Android. |
| F3.1 | Soft-deleted products still readable via GET + counted in list `total` | 3 | Default `where: { isActive: true }` on findOne/findAll. |
| F4.1 | CASH paid < total silently creates orphan debt (no customer) | 4 | Validate paymentType=CASH ⇒ paidAmount ≥ total in `SalesService.create`. |
| F4.2 | Refund does not adjust `customer.debt` or `sale.debtAmount` | 4 | Inside `SalesService.refund`, decrement debt by min(refunded, sale.debtAmount). |
| F5.2 | Soft-deleted customer remains readable (linked to F3.1) | 5 | Same fix as F3.1; share via Prisma extension. |

### P2 (next-sprint polish)

| ID | Finding | Phase |
|---|---|---|
| F1.2 | Validation messages mostly in English (class-validator defaults) | 1 |
| F1.3 | Auth throttler aggressive (~3 req/window), error not localized | 1 |
| F5.1 | Customer phone validation absent (accepts "123") | 5 |
| F7.1 | NBT currency rate fetch returns empty (silent scrape failure) | 7 |
| F8.1 | `@RequiresFeature` may return 404 vs 403 in some routes — needs targeted retest | 8 |
| Carryover from 2026-05-06: receipt-template DTO accepts {} silent reset | 9 | |
| Carryover: zakat-settings DTO accepts {} silent default | 9 | |

### P3 (backlog)

- F2.3: per-store independent trials (combined with F2.1 = trial-stacking risk)
- F2.4: `paymentMethod` (DTO) vs `method` (DB) inconsistent naming
- F2.5: reject overwrites original request `note`, audit trail loses requested plan
- F3.2: categories hard-delete vs products soft-delete — pick one
- F3.3: Russian search urlencoding test inconclusive
- F4.3: receipt-number sequence has gaps after failed transactions
- F6.1: staff list returns top-level `name=null` while `user.name` populated
- F7.2: dashboard topProducts qty doesn't match manual count
- F7.3: reports DTO uses `from/to`, not `startDate/endDate`
- F8.2: discount DTO requires `condition` enum + ISO `startDate` — not obvious from Swagger
- F8.3: list/read of inventory + delivery NOT plan-gated, only POST is
- F9.1: change-password uses `currentPassword` not `oldPassword`
- F9.2: loyalty-settings endpoint not mounted

## Per-phase severity counts

| Phase | PASS | P0 | P1 | P2 | P3 | Notes |
|---|---|---|---|---|---|---|
| 1 — Auth & onboarding | 3 | 0 | 1 | 2 | 0 | onboarding skip, validation EN, throttler |
| 2 — Store & subscription | 11 | **2** | 0 | 0 | 3 | the big monetization findings |
| 3 — Catalog | 13 | 0 | 1 | 0 | 2 | soft-delete leak |
| 4 — POS & sales | 8 | 0 | 2 | 0 | 1 | orphan cash debt + refund debt |
| 5 — Customers & suppliers | 8 | 0 | 1 | 1 | 0 | linked to F3.1 |
| 6 — Staff/shifts/payroll | 12 | 0 | 0 | 0 | 1 | cleanest phase |
| 7 — Finance & reports | 10 | 0 | 0 | 1 | 2 | F2.2 partial-update |
| 8 — Operations | 5 | 0 | 0 | 1 | 2 | discounts/inventory/delivery |
| 9 — Settings | 7 | 0 | 0 | 1 | 2 | known carryover |
| 10 — Sync | 4 | 0 | 0 | 0 | 0 | static checks only |
| 11 — Admin | n/a | 0 | 0 | 0 | 0 | covered by 2026-05-06 + P0 fix |
| **TOTAL** | **81** | **2** | **5** | **6** | **13** | **107 findings + checks** |

## Recommended fix sequencing

### Sprint A — pre-submission (1 week)

1. **F2.1 + F2.2 (3 missing flags)** — wire plan-limit enforcement.
   Without this, the entire revenue model breaks at scale.
2. **F4.1 + F4.2** — revenue correctness in POS. Cashiers will get
   confused or skim cash without these.
3. **F3.1 + F5.2 (linked)** — soft-delete leak. One Prisma extension
   fixes both.
4. **F1.1** — onboarding skip investigation. Important for first-impression
   marketing.

### Sprint B — pre-launch polish (1 sprint)

5. F1.2, F1.3, F5.1, F7.1, F8.1 — validation localization, throttler
   tuning, customer phone, NBT scraper, retest 403 vs 404.
6. Carryover P2 from 2026-05-06.

### Backlog (post-launch)

All 13 P3 nits.

## What was NOT covered

Phase 10 (sync live cycle), Phase 9 (Telegram live), Bluetooth printer,
real iOS — all need either dedicated time, special hardware, or full
Xcode install. Recommend a dedicated half-day offline-mode QA before
launch.

## Test data cleanup

The 102 products, 6 sales, customer with 13 TJS debt, and the 5
subscription payments are **left in place** in qa-store-A so admin /
finance / reports flows have non-trivial data to inspect. To wipe:
delete qa-store-A and qa-store-B from admin (cascades).
