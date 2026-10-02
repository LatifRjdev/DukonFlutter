# Correct Finance Figures, and Refresh on Store Switch — Design

**Date:** 2026-10-02
**Status:** Approved
**Base:** `main` at `2082dc8`

## Scope: these are structural fixes, not per-store ones

Every fix below is in shared code — one API endpoint, one shared UI computation, one provider tree.
**None touches data and none is configured per store**, so every existing store and every store created in
future gets the corrected behaviour automatically.

Verified before committing to that claim: **all 17 sale items across all 6 stores with sales have a
populated `costPrice`** — zero NULLs, zero zeros. So cost of goods sold is computable retroactively, and
historical periods will report correctly too, not just new sales.

## How these were found

Seeded each of two stores with 10 products (cost `10×i`, price `25×i`), 3 sales and 2 expenses, then
compared every figure the UI shows against values computed independently: revenue **575**, COGS **230**,
expenses **420**, gross profit **345**, 3 sales, average check **191.67**.

Confirmed correct and unchanged by this work: stock deduction (48/49/47/50×6/49, exact), the Товары
screen including its inventory valuation footer (68 175 and 27 270, both exact), `/finances/dashboard`'s
own figures, and revenue / sales count / average check / product count on the home dashboard.

## Defect 1 — the dashboard's «Себестоимость» and «Расходы» are always zero

`dashboard_remote_datasource.dart:50-51` reads `todayCost` (fallback `costOfGoods`) and `todayExpenses`
(fallback `expenses`). `/finances/overview` sends **none of those four**. Both cards therefore render `0`
for every store, always — with real expenses of 420 the card showed 0.

It also makes the screen self-contradictory: it displays revenue 575, expenses 0 and profit 155, where
155 is `575 − 420`. The profit already accounts for expenses the same screen reports as zero.

**Fix:** `/finances/overview` returns `todayCost` and `todayExpenses`.

### A deliberate change of meaning, called out

`todayProfit` is currently `revenue − expenses`, ignoring COGS entirely. Once COGS is available the
honest figure is `revenue − COGS − expenses`: **−75**, not 155.

This changes an existing field, so it is a decision rather than a detail. It is the right one: the
dashboard shows revenue above three cards reading Прибыль / Себестоимость / Расходы, and a user should be
able to add them up. After the change `575 − 230 − 420 = −75` checks out. Before it, nothing did.

## Defect 2 — «Чистая прибыль» subtracts expenses twice

`finance_dashboard_page.dart:211` computes net profit as `s.profit - s.totalExpenses`, while
`finance_remote_datasource.dart:65` already defines `profit = totalIncome - totalExpenses`. Expenses are
therefore deducted twice: `575 − 420 − 420 = −265`.

The screen reported a **−265 TJS loss on a store that is not making one**. This is the most damaging of
the four, because the number is both wrong and alarming.

**Fix:** net profit = gross profit − expenses, with gross defined as below.

## Defect 3 — «Валовая прибыль» is not gross profit

`finance_dashboard_page.dart:200` renders `s.profit` — `revenue − expenses` — under a label that means
`revenue − COGS`. With the seeded data it showed 155 where gross profit is 345.

COGS is absent from the entire finance path: neither `/finances/summary` (which returns only
`salesByDay`, `expensesByDay`, `expensesByCategory`) nor `/finances/dashboard` computes it.

**Fix:** `/finances/summary` returns COGS for the period; the app computes gross = revenue − COGS.

**Defects 2 and 3 must be fixed together.** Correcting net profit to "gross − expenses" while gross is
still `revenue − expenses` would leave net wrong in a new way. They are one change.

## Defect 4 — switching stores refreshes nothing

After switching the active store, the dashboard, Финансы and Товары all kept showing the **previous**
store's data — zeros instead of 575/420/10 products. The API log shows only a `banners/active` request
for the newly selected store; no `finances/overview`, no `products`. Recovery requires a manual period
change or pull-to-refresh on each screen separately.

This is the same class as the logout bug fixed in `2082dc8`: bloc state outliving the context it belongs
to. The mechanism built there extends to cover it.

**Fix — two levels of keying, not one.** The obvious move is to add the store id to the existing session
key, but that breaks the earlier fix: `StoreBloc` owns the store list *and* the selection, so if it sits
inside a store-keyed subtree it is destroyed by its own selection change. Putting it at the root instead
makes `selectedStore` survive logout again — exactly the bug just fixed.

So:

| Level | Holds | Resets when |
|---|---|---|
| root | `AuthBloc`, `SettingsBloc` | never |
| keyed on session | `StoreBloc` | account changes |
| keyed on session + store | the other 23 blocs | account **or** store changes |

A key cannot be forgotten the way a per-bloc refresh listener can, and the next bloc anyone adds is
covered by construction.

## Computing COGS

`SaleItem` snapshots `costPrice` at sale time (`schema.prisma`), so COGS does not depend on a product's
current cost — correct behaviour, since re-pricing a product must not rewrite past margins.

```
COGS = SUM((quantity - refundedQuantity) * costPrice)
```

over sale items joined to that store's non-cancelled sales in the period. `refundedQuantity` already
tracks cumulative refunds per line, so refunded units drop out without extra work. Verified against the
seeded data: the aggregate returns exactly **230.00**.

A shared private helper serves all three endpoints rather than three copies of the aggregate.

## Testing

**Backend** — unit tests on the finance service: COGS matches a hand-computed figure; a partial refund
reduces it proportionally; a cancelled sale is excluded; `overview` includes `todayCost` and
`todayExpenses`; `todayProfit` equals `revenue − COGS − expenses`.

**App** — a widget or unit test pinning both corrected formulas: gross = revenue − COGS, net = gross −
expenses, asserted against 575/230/420 → 345/−75. The double-subtraction must fail this test.

**Emulator, against the already-seeded data** — the figures are known, so each screen is checkable rather
than merely "renders":

| Screen | Expected after the fix |
|---|---|
| Главная | revenue 575, Себестоимость **230**, Расходы **420**, Прибыль **−75**, 3 sales, 10 products |
| Финансы | доход 575, расходы 420, валовая **345**, чистая **−75** |
| Store switch | all three screens show the new store's figures with **no** manual refresh |

## Verification

| Check | Expectation |
|---|---|
| `api`: `npm test`, `npx tsc --noEmit` | green, 0 errors |
| `app`: `flutter analyze` | `No issues found!` |
| `app`: `flutter test` | failing set identical to the documented 18 macOS goldens |
| `dart run tool/check_i18n.dart` | exit 0, 343 files |
| Emulator | the table above, on both QA accounts |

## Risks

- **Changing `todayProfit`'s meaning** is a visible behaviour change. Deliberate, argued above, and the
  only way to make the dashboard's four numbers consistent with each other.
- **Two-level keying is more intricate than one.** If `StoreBloc` ends up in the wrong level the result is
  either the logout bug returning or a store switch that destroys the store list mid-selection. The
  implementation must verify both paths on the emulator, not just the store-switch one.
- **COGS excludes sales with a NULL `costPrice`.** None exist today, but a future import path that skips
  the snapshot would silently understate COGS. Treating NULL as 0 is the honest default — it cannot be
  inferred — but it is worth a comment at the aggregate so the limitation is visible.
