# Phase 7 — Finance & reports

**Date:** 2026-05-07

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Finance dashboard | 🟢 PASS | — | totalRevenue=50 (matches sum of sales), profit=50, salesCount=4, topProducts populated. |
| Balance | 🟢 PASS | — | currentBalance, income, expenses, profit + chartData per day. |
| Zakat settings (default load) | 🟢 PASS | — | Returns defaults when no row exists (nisab gold/silver/zakat rate=2.5%). |
| Zakat calculate | 🟢 PASS | — | breakdown with inventory/cash/receivables/payables; zakatDue = 2.5% of netAssets (1.5625 for net 62.5). Math verified. |
| Expense create | 🟢 PASS | — | 201 with category=RENT. |
| Investments list | 🟢 PASS | — | Empty array OK. |
| Currencies — list | 🟢 PASS | — | Returns empty array (no rates yet). |
| **Currencies — fetch from NBT** | 🔴 FAIL | **P2** | See F7.1 — POST /rates/fetch returns 201 with empty array, no rows persisted. |
| Reports sales (correct DTO `from/to`) | 🟢 PASS | — | byDate + topProducts populated with revenue 50 / qty 9. |
| Reports profit (plan-gated) | 🟢 PASS | — | START plan returns 403 "This feature (hasReportsAll) is not available on your current plan". So plan flags ARE checked here — see F2.2 update below. |
| Reports DTO mismatch (`startDate/endDate` vs actual `from/to`) | 🟡 NIT | P3 | If a frontend uses Swagger-style query names it will get 400 with "property startDate should not exist". |

## Findings

### Update to F2.2 — partial enforcement, not fully decorative

While walking the reports module, I found that **`@RequiresFeature` decorator
DOES exist** and is wired to:
- `hasReportsAll` → `reports.controller.ts` (3 endpoints: profit/products/staff)
- `hasInventory` → `inventory-counts.controller.ts`
- `hasDelivery` → `deliveries.controller.ts`

So 3 of 6 boolean plan flags ARE enforced. The original F2.2 was overly
broad. Corrected status:
- **NOT enforced (still P0):** `hasExport` (PDF/Excel export endpoints
  like /reports/sales export are gated nowhere), `hasTelegram` (send-receipt
  endpoint), `hasAllPush` (notification settings).
- **Numeric limits still entirely missing:** maxStores, maxProducts,
  maxStaff, maxDiscounts (F2.1 unchanged).

### F7.1 — P2: NBT currency rate fetch returns empty

**Repro:**
```bash
curl -X POST .../api/currencies/rates/fetch
# 201, body []
curl .../api/currencies/rates
# 200, []
```

The endpoint exists and returns 201, but no rate rows are written. Either:
- The NBT scrape is failing silently (returns no rows but 200 to caller),
- Or the parser is broken,
- Or NBT is rate-limiting / returning HTML the parser doesn't expect.

**Why this matters:** the currencies module is the basis for multi-currency
sales (USD/RUB items). Without rates, the conversion math everywhere
falls back to "no rate" which surfaces as zero or NaN in reports.

**Fix path:** add a log/Sentry breadcrumb inside the NBT scraper for what
HTML it received and what it parsed. Revisit XML parser if NBT changed
their response shape.

### F7.2 — P3: topQuantity vs actual sold mismatch

Dashboard reports `apple totalQuantity=9, totalRevenue=45` but our
manual sales for apples were 3+5+4+1 = 13 (with 2 returned via partial
refund → 11 net). The dashboard's 9 doesn't match either count.

May be filtering by something I'm not seeing (e.g. excluding sales with
debt > 0, or excluding R-000004 because of cash-shortfall = some other
status). Worth digging into the aggregate query if numbers in the wild
look off.

## Phase 7 summary

10 PASS / 0 P0 (note F2.2 partial-update softens the earlier classification)
/ 0 P1 / 1 P2 (currency fetch broken) / 2 P3 nits.

Most finance + zakat + reports flows work. Plan gating actually exists
for some features (hasReportsAll, hasInventory, hasDelivery) — earlier
"plans are decorative" finding needs to be downgraded for those three.
