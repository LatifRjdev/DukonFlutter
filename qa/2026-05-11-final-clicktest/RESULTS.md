# Final Click-Test Results — 2026-05-11

After all 8 fix commits + the fresh APK rebuild, walked through every
flow involving the 4 fixes plus the new no-minus UX. Found 2 latent
issues during the click test, fixed both inline.

## Verified ✅ — what should appear matches what is there

### FIX #27 — Dashboard "Вам должны" / "Вы должны" no longer crashes
- **Before:** red Flutter "type 'String' is not a subtype of 'Map'" error screen. App effectively dead until tab away.
- **After:** page renders normally. (See screenshot `03-vam-dolzhny-FIX27-sm.png` → no red.)
- **NEW BUG #30 surfaced + fixed:** the route was correct (no crash) but pointed at the WRONG page (single-customer detail instead of all-debts overview). Dashboard now routes to `/debts` (DebtsOverviewPage with Нам должны / Мы должны tabs). Verified in `07-debts-overview-sm.png`.

### FIX #26 — "Остатки на складе" tile pre-filters Товары
- **Before:** opens unfiltered Товары tab.
- **After (initial test attempt):** tile navigates correctly but the chip wasn't being pre-selected.
- **Latent bug found:** `ProductListPage` is kept alive in HomePage's `IndexedStack`, so `initState` only fires once for the whole session. The fix originally only read `widget.initialFilter` in initState, so subsequent navigations from the tile saw the new prop but never re-applied it. **Fix:** added `didUpdateWidget` to apply the new `initialFilter` when it changes (commit incoming).
- **Verified:** after the rebuild, tapping the tile shows ONLY the 1 attention-needing product (`qa-p-business-23494 / 0 шт`). The "Все" chip is unselected, indicating the off-screen "Требует внимания" is the active filter. `08-products-attention-sm.png`.

### FIX #28 — История продаж no longer "Не удалось выполнить операцию" on every load
- **Before:** error icon + "Повторить" button on every visit, even with valid 200 API response.
- **After:** shows proper empty state ("Нет продаж") when there's no data; would show the list when there is. The parser is now resilient (BUG #28 layer 2 — try/catch per row). `09-history-FIX28-sm.png`.

### Finance dashboard: no minus on revenue cards (Q1=C decision)
- **Before (user's screenshot):** "Общий доход −127 TJS", "Общие расходы −X TJS", "Валовая прибыль −127 TJS", "Чистая прибыль −127 TJS". All four with leading minus.
- **After:** "Общий доход 66 TJS", "Общие расходы 0 TJS", "Валовая прибыль 66 TJS", "Чистая прибыль 66 TJS". All clamped non-negative. `13-finance-sm.png`.
- **Architectural correctness preserved:** Валовая прибыль and Чистая прибыль can still show negatives when the merchant operates at a loss (cost > revenue or expenses > gross profit). They're just not negative in this dataset right now. The clamp specifically targets only Общий доход and Общие расходы.

### BUG #29 (data-layer) — DB CHECK constraint blocks negative totals
- **Before:** API path was clamped (BUG #14 fix) but a direct SQL admin write or broken seed could re-insert negative totals.
- **After:** `ALTER TABLE sales ADD CONSTRAINT sales_total_non_negative CHECK (total >= 0)` plus 6 sibling constraints on `sales` and `sale_items`. E2E test in `api/test/finance-correctness.e2e-spec.ts` proves a raw `$executeRawUnsafe INSERT` with `total = -1` is rejected by Postgres with the exact constraint name. Migration `20260511000000_finance_correctness` also clamped 3 legacy rows + cleared 1 orphan debt.

## Per-tier feature matrix (existing — re-verified earlier session, no regression)

| Feature endpoint | START | BIZ | PREM |
|------------------|-------|-----|------|
| `GET /reports/sales`    | 403 | 200 | 200 |
| `GET /reports/profit`   | 403 | 200 | 200 |
| `GET /reports/products` | 403 | 200 | 200 |
| `GET /reports/staff`    | 403 | 200 | 200 |
| `GET /reports/export`   | 403 | 403 | 200 |
| `GET /deliveries`       | 403 | 200 | 200 |
| `GET /inventory-counts/:id` | 403 | 200 | 200 |
| `POST /inventory-counts`    | 403 | 201 | 201 |
| `POST /telegram/send-receipt` | 403 | 400* | 400* |
| `PUT /notifications/settings` | 403 | 204 | 204 |

\* 400 = bad payload but feature gate cleared.

## Per-role permission matrix (existing — re-verified)

| Action | OWNER | ADMIN | CASHIER | WAREHOUSE |
|--------|-------|-------|---------|-----------|
| products.view | ✓ | ✓ | ✓ | ✓ |
| products.manage (create/edit) | ✓ | ✓ | ✗ | ✓ |
| products.delete | ✓ | ✓ | ✗ | ✗ |
| sales.manage | ✓ | ✓ | ✓ | ✗ |
| sales.refund | ✓ | ✓ | ✗ | ✗ |
| staff.manage | ✓ | ✓ | ✗ | ✗ |
| roles.manage | ✓ | ✓ | ✗ | ✗ |
| expenses.write | ✓ | ✓ | ✗ | ✗ |
| discounts.write (#21 fix) | ✓ | ✓ | ✗ | ✗ |
| inventory.write (#22 fix) | ✓ | ✓ | ✗ | ✓ |
| reports.view (#23/#24 fix) | ✓ | ✓ | ✗ | ✗ |
| store.manage | ✓ | ✓ | ✗ | ✗ |

## Plan limits (re-verified)

| Limit | START | BIZ | PREM |
|-------|-------|-----|------|
| maxStaff | 2 | 10 | ∞ |
| maxProducts | 500 | 2000 | ∞ |
| maxDiscounts | 0 | 5 | ∞ |
| maxStores | (dropped — Sprint D.1) | | |

## What still needs work (carry-forward)

These are NOT in the spec but emerged or were already known:
1. **BUG #25** — `thermal_printer 1.0.5` cannot encode Cyrillic. Replace package (esc_pos_printer or esc_pos_utils_plus). 9 buildReceiptBytes tests are skipped with `BUG #25` reason and unskip themselves once the package is replaced.
2. **Telegram webhook** — protected by `TELEGRAM_WEBHOOK_SECRET` header check; verify the env is set in production.
3. **Email/i18n** — base coverage is OK (ru=381 keys, tg/uz=375); 6 keys are metadata, not real translations.
4. **Hardware-bound printer integration test (G.1)** — needs physical $30 thermal printer or esc-pos emulator. Framework is wired (skip:'BUG #25'), unskips when package switched.

## Cumulative session bug count

**33 bugs found, 30 fixed, 3 carry-forward** across 13 commits in 2 days
(8 from spec execution + 1 final didUpdateWidget + 1 routing fix + 3 review fixes
embedded in earlier commits; the 3 deferred are #25 + the two architectural
decisions documented in spec).

This was the last QA/dev pass before merge — work is now on `main` and the
4 user-facing carry-forward items from the click-test session are all closed.
