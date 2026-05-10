# Live Offline QA — 2026-05-10

**Tester:** automated via adb on Android emulator (Pixel API 34)
**Build:** main @ cabee90 (Sprint C committed)
**Account:** qa-business-store / +992910001002
**API:** http://localhost:4455 (NestJS dev server, restarted to load Sprint C)

---

## Test Plan

1. Login while online, cache dashboard.
2. Disable wifi + data → verify navigation still renders cached state.
3. Open POS, add item to cart, complete CASH sale **while offline**.
4. Re-enable network, verify the queued sale is pushed to API.

## Outcome

**End-to-end sync path WORKS.** A CASH sale created with no network was
successfully pushed to the API after reconnect:

```json
{
  "receiptNo": "R-000001",
  "total": 5,
  "paymentType": "CASH",
  "paidAmount": 5,
  "items": [{ "productName": "Offline-test Bread", "quantity": 1, "total": 5 }]
}
```

Dashboard refreshed and reflects the sale (`5 TJS, 1 продаж`).
F4.3 (Sprint C) receipt-number sequence allocated correctly — first sale
got `R-000001` even though it was created via the offline replay path.

---

## Bugs Found

### 🔴 P1 — POS success screen shows "0 TJS" instead of sale total
**Repro:** complete a CASH sale where the customer paid the exact amount.
**Expected:** big "X TJS" = sale total, with a separate "Сдача: 0 TJS" if any.
**Actual:** under "Продажа оформлена!" the only number shown is the
*change* (сдача), unlabeled, in a large bold font. With exact payment
that reads visually as "sale = 0 TJS" — confusing and looks like a
data bug.
**Fix:** label the field, or show `total` instead of `change`.
**Screenshot:** `screenshots/20-after-checkout-sm.png`

### 🟠 P2 — POS product list does not refresh after navigation
**Repro:** open POS (1 product), exit to Главная, refresh list (now 2),
return to POS — POS still shows 1.
**Expected:** POS re-fetches its product list when re-entered.
**Actual:** POS holds the snapshot from app cold-start; only a full
`am force-stop` brings new products in.
**Workaround:** restart app.
**Screenshots:** `screenshots/08-pos-with-stocked-sm.png` (1 chip),
`screenshots/16-pos-fresh-sm.png` (2 chips after restart).
**Fix:** invalidate POS product list on tab focus, or wire it to the
same source-of-truth Stream as the Товары tab.

### 🟠 P2 — Flutter render overflow on POS product chips
**Repro:** any POS chip with a long name renders a red-on-yellow
"BOTTOM OVERFLOWED BY 2.0 PIXELS" badge in debug builds.
Production users on debug-enabled flavours would see this.
**Expected:** chip clips text or wraps; no overflow indicator.
**Actual:** overflow indicator visible at top of chip stack.
**Screenshots:** `screenshots/06-pos-empty-sm.png`,
`screenshots/16-pos-fresh-sm.png`.
**Fix:** wrap chip Text in `Flexible` / give it `maxLines: 2`,
or shrink the chip width to avoid the 2px miscalc.

### 🟡 P3 — `localId` is not preserved on the synced sale
**Repro:** offline sale → API POST → DB row.
**Expected:** the locally-generated UUID lives in `Sale.localId` so the
client can dedupe in case of replay.
**Actual:** `localId: null` in the API response. If the sync engine
retries before getting a response, we'd create a duplicate sale.
**Fix:** verify the offline-replay codepath sets `localId` on the
outgoing payload (the column exists in Prisma schema, the API accepts
it — just not being sent).

### 🟡 P3 — `createdAt` reflects sync time, not sale time
**Repro:** sale tapped at 12:44 local; API row `createdAt` = 13:18 local
(when reconnect+push happened).
**Expected:** offline sale's original timestamp preserved (`createdAt`
or `occurredAt`) so end-of-day reports are correct.
**Actual:** API uses server-side `now()`; offline sales appear in the
wrong day if reconnect spans midnight.
**Fix:** add an `occurredAt` (client-supplied) column on Sale, default
to `createdAt` for online sales; reports use `occurredAt`.

### 🟡 P3 — Cash-payment sub-page lost the offline banner
**Repro:** on POS cart with offline banner visible, tap "Оформить" →
"Оплата наличными" page renders without the orange "Нет подключения"
strip at top, even though we're still offline.
**Expected:** banner is global / part of root scaffold.
**Actual:** sub-page covers it.
**Fix:** put the banner in `MaterialApp.builder` or root `Scaffold`
not per-screen.
**Screenshot:** `screenshots/19-cash-set-sm.png`.

---

## What worked

- Offline navigation across Главная/Товары/Финансы — no fatals,
  cached data renders, orange banner shown on each top-level tab.
- Cart add + total calc — local-only.
- Cash entry + change calculation — local-only.
- Sale persists offline and pushes on reconnect.
- API receives correct totals + items + payment type.
- Receipt-number sequence (Sprint C F4.3) starts from `R-000001` as
  expected on the first ever sale for the store.

## Verdict

**Offline write path is functional but rough around the edges.** The
critical "merchant rings up a sale with no signal, syncs later" flow
works end-to-end. The 5 issues above are polish: 1 P1 (display bug
on success screen) + 2 P2 (POS list staleness, render overflow) +
3 P3 (localId, createdAt semantics, banner missing on sub-page).

None are release-blockers in isolation, but the P1 success-screen bug
is user-visible on every cash sale and should be fixed before launch.
