# Design — 4 Carry-Forward Fixes

**Date:** 2026-05-12
**Scope:** 4 items left after the 2-day session: BUG #25 (printer
encoder), multi-currency live test, subscription lifecycle full,
app lifecycle stress.
**Decisions:** Q1=A (esc_pos_utils_plus), Q2=A (test-only), Q3=A
(test-only), Q4=A (test-only).

## Summary

One umbrella spec with four independent sub-sections. Item #1 is the
real engineering work (package swap); items #2–#4 are verification
matrices that exercise existing code and surface gaps. The four
ship as four separate commits, in order — #1 first because it
unblocks the 9 currently-skipped printer tests.

## Sub-section A — BUG #25: thermal_printer package swap

### Problem

`thermal_printer 1.0.5` hardcodes `latin1.encode(text)` in
`Generator._encode` (line ~70). Any Cyrillic or Tajik character
(Товар, Хлеб, Молоко, ҳ, ӣ, ҷ, …) throws "Contains invalid
characters" at print time. Setting a wire codepage via
`setGlobalCodeTable('CP1251')` does not help — the encoder runs
before the codepage byte is even sent.

### Fix

Replace `thermal_printer: ^1.0.5` with two pure-dart packages:
- `esc_pos_utils_plus` — byte generation, supports CP1251 codepage
  natively in `_encode`. Same `Generator / PaperSize / PosColumn /
  PosStyles` API surface — drop-in for our `_buildReceiptBytes`.
- `esc_pos_bluetooth` — BLE scan/connect/print using the bytes from
  the utils package. Replaces the BLE half of `thermal_printer`.

### Files touched

**Replace:**
- `app/pubspec.yaml` — drop `thermal_printer`, add
  `esc_pos_utils_plus` + `esc_pos_bluetooth`.

**Modify:**
- `app/lib/core/services/thermal_printer_service.dart` — swap
  imports, replace `PrinterManager` calls with
  `PrinterBluetoothManager`, add `generator.setGlobalCodeTable('CP1251')`
  at the top of `_buildReceiptBytes`. Remove the workaround comment
  (BUG #25 paragraph) and replace it with a one-line "uses CP1251
  via esc_pos_utils_plus" note.
- `app/test/core/services/thermal_printer_service_test.dart` —
  unskip the 9 `BUG #25` tests. Re-add the Cyrillic + Tajik test
  cases (`Молоко 3.2%`, `Чойи сабз ҳамчун ёд`) and confirm bytes
  produced.

**Verify:**
- Build APK + install + manual print test on emulator's "send to
  Telegram" path, OR connect a real BLE printer if available.
- All 10 `buildReceiptBytesForTest` tests pass.

### Acceptance

- 0 `skip:'BUG #25'` tests remain.
- `dart analyze` 0 issues.
- Cyrillic + Tajik strings produce non-empty byte arrays.
- BLE print path returns success when a printer is available (manual
  test is acceptable; integration test still tracked as G.1).

---

## Sub-section B — Multi-currency live test

### Problem

Currency enum exists (TJS / USD / RUB), `store.currency` is mutable
but blocked once a sale exists (BUG #15 fix). Reports + finance
dashboard format amounts as bare numbers with the store's current
currency suffix. The whole multi-currency happy path (create store
in RUB, sell, verify reports) was never live-tested.

### Fix

Test-only matrix. No code changes unless a live failure surfaces.

### Test matrix

| Scenario | Steps | Expected |
|----------|-------|----------|
| Create store in TJS, sell, view dashboard | normal flow | `5 TJS` everywhere |
| Create store in USD, sell, view dashboard | swap currency BEFORE first sale | `5 USD` everywhere |
| Create store in RUB, view all 3 reports (sales/profit/products) | flow | `5 RUB` everywhere |
| Try to change currency after a sale exists | PUT /stores/:id with new currency | API rejects with 400 + clear message (BUG #15 fix) |
| Currencies module rates (`/currencies/rates`) | GET + POST `/rates/fetch` | endpoints respond, no 500 |

### Files touched

- `qa/2026-05-12-currency-test/REPORT.md` — narrative + screenshots.
- New seed user `qa-currency` if needed for a fresh USD/RUB store
  (or reuse qa-business by switching its currency BEFORE any sale —
  cleaner). Use the existing `seed-3-tier-users.ts` pattern.

### Acceptance

- All 5 scenarios documented with expected vs actual + screenshot.
- Any gap surfaces as a new bug entry, not a fix in this spec.

---

## Sub-section C — Subscription lifecycle full test

### Problem

Verified earlier: PAST_DUE / CANCELLED / EXPIRED → 403 on feature
endpoints. NOT verified: TRIAL → ACTIVE on first paid payment,
renewal extending `currentPeriodEnd`, plan-change refund accounting,
downgrade PREMIUM → START access loss.

### Fix

Test-only matrix using direct DB manipulation + admin API where
possible. No new code unless a live failure surfaces.

### Test matrix

| Scenario | Setup | Trigger | Expected |
|----------|-------|---------|----------|
| TRIAL → ACTIVE | seed sub `status=TRIAL`, create `SubscriptionPayment status=PENDING` | `POST /admin/subscriptions/:id/payments/:pid/approve` | `subscription.status='ACTIVE'`, `currentPeriodEnd` = now + 30 days, audit log entry `subscription.approve` |
| ACTIVE renewal | seed sub `status=ACTIVE`, `currentPeriodEnd=now+5days`, new approved payment | approve | `currentPeriodEnd` = old + 30 days |
| Admin extend (manual) | seed sub `status=ACTIVE` | `POST /admin/subscriptions/:id/extend {days:30}` | `currentPeriodEnd += 30` |
| Plan change PREMIUM → START | seed sub `status=ACTIVE plan=PREMIUM` | `POST /admin/subscriptions/:id/change-plan {plan:'START'}` | `plan='START'`, audit log `subscription.plan_change`, `/reports/sales` immediately returns 403 (was 200), `/inventory-counts` immediately 403 |
| ACTIVE auto → EXPIRED | seed sub `status=ACTIVE`, `currentPeriodEnd=now-1day` | wait for cron OR call `markExpiredSubscriptions()` directly | `status='EXPIRED'`, FCM push fired (or logged) |
| EXPIRED → ACTIVE | EXPIRED sub, create payment, approve | approve | `status='ACTIVE'`, new period from now |

### Files touched

- `qa/2026-05-12-subscription-lifecycle/REPORT.md` — matrix + curl
  outputs.
- Helper script `qa/2026-05-12-subscription-lifecycle/run.sh` — seeds
  + drives the 6 transitions.

### Acceptance

- All 6 transitions verified.
- Audit log rows confirmed for approve / reject / plan_change.
- Any gap (e.g., no auto-expiry cron, plan-change doesn't immediately
  block features) surfaces as a separate bug entry with severity.

---

## Sub-section D — App lifecycle stress test

### Problem

Cart persistence works (E.4 fix). NOT verified: process kill
mid-sale data loss, OS Doze mode, long background idle, lifecycle
resume after device sleep.

### Fix

Test-only stress matrix using `adb` to drive the failure modes.

### Test matrix

| Scenario | Trigger | Expected |
|----------|---------|----------|
| Kill mid-cart | add 2 items, `adb shell am kill com.itlsolutions.dukonpro` | restart app → "Restore previous cart?" prompt → restore reproduces 2 items + customer if any |
| Kill mid-checkout (after Оформить, before Завершить) | navigate to cash payment screen, kill | restart → opens to dashboard, cart cleared (intentional — user was about to commit), no orphan sale on server |
| Kill mid-offline-sale (queued, network off) | offline mode, complete sale, kill before reconnect | restart → bring network back → sync queue replays the queued sale, server-side dedupe via localId prevents duplicate |
| OS Doze mode | `adb shell dumpsys deviceidle force-idle`, wait 30s, attempt sale | sale completes (POS is foreground = exempt from Doze) |
| Long background | press home, sleep emulator 5 min, resume | app resumes to last state, no token-refresh storm, no crash |
| Token expiry while backgrounded | force `tokensRevokedAt` server-side, resume app | app handles 401 gracefully — refresh OR redirect to login, no white screen |

### Files touched

- `qa/2026-05-12-app-lifecycle/REPORT.md` — narrative + screenshots
  per scenario.
- Helper script `qa/2026-05-12-app-lifecycle/run.sh` — drives the 6
  scenarios via `adb`.

### Acceptance

- All 6 scenarios documented.
- Any data loss / crash surfaces as a new bug entry.

---

## Order of execution

1. **A** first — unblocks 9 tests + reduces test-skip count.
2. **B**, **C**, **D** in parallel-able order. Each is a self-
   contained verification pass. Each produces a REPORT.md.

## What's NOT in scope

- Schema change to tag sales with currency (Q2 option B) — out
  of scope; current mono-currency-per-store is correct.
- Auto-renewal billing redesign (Q3 option C) — out of scope.
- Full state-restoration framework (Q4 option C) — out of scope.
- New stock-summary screen, hardware printer integration test (G.1)
  — already deferred from earlier specs.

## Risks

- **Package swap (A) might break BLE permission flow** on Android
  13+. Mitigation: test on emulator AND a real device if available;
  if BLE permissions changed, add the new permission to
  `AndroidManifest.xml`.
- **Currency change test (B) might surface that some screens
  hardcode 'TJS'** in label strings. Mitigation: surface as a
  separate bug entry, not a fix in this spec.
- **Plan-change downgrade test (C) might find the access-loss isn't
  immediate** (e.g., guard caches the plan for the duration of the
  request). Mitigation: surface as a bug, fix in a follow-up spec.
- **Lifecycle stress (D) might find data loss in the offline-replay
  path** (e.g., localId dedupe not actually working). Mitigation:
  the BUG #19 fix added localId dedupe — this is a regression test,
  not a new feature.

## Test results gate

After implementation:
- API: `npm test` (≥184 unit) + `npm run test:e2e` (≥8 e2e)
- App: `flutter test` (≥403 + 9 unskipped from BUG #25 = ≥412)
- `dart analyze` 0 issues, `tsc` 0 errors
- 4 REPORT.md files in `qa/2026-05-12-*/`
