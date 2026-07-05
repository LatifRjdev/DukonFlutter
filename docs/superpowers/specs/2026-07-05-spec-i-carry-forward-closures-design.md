# Design — Spec I "Carry-Forward Closures"

**Date:** 2026-07-05  
**Scope:** Close 3 verification gaps deferred from previous specs — multi-currency test coverage, subscription lifecycle edge cases, app lifecycle stress. BUG #25 (thermal printer Cyrillic) was already fixed in a prior session and is excluded.

## Summary

All work in this spec is tests + one QA markdown doc. No new endpoints, no migrations, no UI changes. The goal is to make the "verified to work" surface match the "code exists" surface for three feature areas.

## Item 1 — Multi-currency test coverage

**Context:** `store.currency` (TJS / USD / RUB) is stored on the store. All sales for a store implicitly use that currency. The `currencies` module manages exchange rates (admin-set, stored in `CurrencyRate`). Per-store reports are mono-currency by design — no conversion happens inside report aggregations.

**Gap:** No test exercises a non-TJS currency store end-to-end, and no test covers the exchange rate CRUD surface.

**What to add:**

1. `api/src/modules/currencies/currencies.service.spec.ts` (new file):
   - `setRate(from, to, rate)` — stores the rate, returns the record
   - `getRate(from, to)` — retrieves the stored rate
   - `getRate` on missing pair — throws `NotFoundException`

2. `api/src/modules/sales/sales.service.spec.ts` (extend existing):
   - Create a sale for a USD-currency store — sale record carries no currency field (currency lives on the store), service does not throw, totals are numeric
   - Reports (`getSalesReport`) for a store with `currency: USD` — response includes correct numeric totals, no conversion attempted

**Out of scope:** Cross-store admin aggregation with currency conversion (future feature).

## Item 2 — Subscription lifecycle completion

**Context:** Already verified — TRIAL→ACTIVE on first payment, renewal extending period, 403 on EXPIRED/CANCELLED/PAST_DUE. Not yet verified: `adminChangePlan`, the auto-expiry scheduler, and explicit downgrade access test.

**What to add:**

1. `api/src/modules/subscriptions/subscriptions.service.spec.ts` (extend existing):
   - `adminChangePlan(subId, plan, adminId)` — updates `plan` field only (does NOT change `currentPeriodEnd`), fires `AuditLogService.record` with `subscription.plan_change` and correct `{from, to}` payload
   - `adminChangePlan` on non-existent subscription — throws `NotFoundException`

2. `api/src/modules/subscriptions/subscriptions.controller.spec.ts` (extend existing — cron path):
   - Auto-expiry scheduler method — when called with a subscription whose `currentPeriodEnd < now`, sets `status = EXPIRED` and calls `NotificationsService.sendPush`
   - When `currentPeriodEnd >= now` — no status change, no push

3. `api/src/common/guards/subscription.guard.spec.ts` (extend existing):
   - Downgrade explicit test: store plan = START, endpoint requires PREMIUM → guard throws `ForbiddenException` (documents the downgrade path explicitly, even though the guard is plan-agnostic)

**Not in scope:** Refund accounting — Dukon payments are manual (admin approves receipts), no automated proration exists.

## Item 3 — App lifecycle stress

**Unit/bloc tests** (pure Dart, run in CI):

File: `app/test/presentation/blocs/pos/cart_bloc_persistence_test.dart` (new file)

Cart persistence lives in `CartBloc` (not `CheckoutBloc`). `CartBloc` accepts an optional `CartLocalDatasource` and auto-saves with a 400ms debounce on every state change. Tests use `SharedPreferences.setMockInitialValues({})` for a hermetic fake.

- Add items → wait 400ms → `CartLocalDatasource.load()` returns the same items (happy path persistence)
- Add items → load immediately (before debounce) → load returns null (debounce not yet fired — documents expected behavior)
- Persist state → create new `CartBloc` with same `CartLocalDatasource` → `CartBloc` emits restored items on `CartLoadRequested` event (simulates process kill + reopen)

Implementation approach: `fakeAsync` + `tick(Duration(milliseconds: 450))` to advance past debounce without real timer waits.

**Manual QA doc**: `qa/2026-07-05-app-lifecycle/REPORT.md`

Four scenarios, same format as `qa/2026-05-12-app-lifecycle/REPORT.md`:

| # | Scenario | Steps | Expected | Result |
|---|---|---|---|---|
| 1 | OS kill mid-sale | Open cart with 3 items → force-stop app → reopen | Cart restores with same 3 items | — |
| 2 | Doze mode (10 min background) | Start sale → lock screen 10 min → unlock → foreground | Session valid, no crash, cart intact | — |
| 3 | Device sleep during active sale | Open cart → lock screen → unlock immediately | Resume works, cart intact | — |
| 4 | Low-memory kill | Fill cart → use Android Dev Options "Don't keep activities" → home → reopen | Cart restores, no corrupt state | — |

Result column filled in after manual run on Android emulator.

## Files touched

**Create:**
- `api/src/modules/currencies/currencies.service.spec.ts`
- `app/test/presentation/blocs/pos/cart_bloc_persistence_test.dart`
- `qa/2026-07-05-app-lifecycle/REPORT.md`

**Modify:**
- `api/src/modules/sales/sales.service.spec.ts` — add USD-store sale + report tests
- `api/src/modules/subscriptions/subscriptions.service.spec.ts` — add `adminChangePlan` tests
- `api/src/modules/subscriptions/subscriptions.controller.spec.ts` — add auto-expiry cron tests
- `api/src/common/guards/subscription.guard.spec.ts` — add explicit downgrade test

## Acceptance

- `npm test` ≥ 241 (current 231 + ~10 new API tests)
- `flutter test` ≥ 444 (current 441 + 3 new cart persistence tests)
- `qa/2026-07-05-app-lifecycle/REPORT.md` exists with all 4 scenario results filled in (pass/fail from manual emulator run)
- 0 new TypeScript errors

## Out of scope

- Cross-store currency aggregation in admin reports
- Automated Doze mode / process-kill tests (OS-level, require real device + instrumentation harness)
- Thermal printer Cyrillic fix (BUG #25) — already closed
- New subscription features (auto-renewal payments, proration, invoices)
