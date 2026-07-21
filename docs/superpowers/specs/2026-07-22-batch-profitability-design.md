# Окупаемость партии — Design Spec

**Date:** 2026-07-22
**Status:** Approved, ready for implementation planning

## Problem

Store owners currently see per-unit profit/margin on the product detail page
(`sellPrice − costPrice`), but nothing tells them how a specific restock is
performing as a whole: how much cash they put into it, how much they've
recovered, and how much stock is still sitting unsold. Today the only signal
for "this isn't moving" is the generic low-stock filter (which fires on
*low* stock, the opposite problem), and low-stock alerts don't even send a
push today (dead setting, confirmed during the 2026-07-21 full-system QA
sweep).

## Goals

- Show, per product, how the most recent restock is performing: cost
  invested, revenue recovered, profit already earned, and how much cash is
  still short of full payback.
- Alert the owner when a product has stopped selling while a large chunk of
  that restock is still on the shelf, so they can consider a price cut
  before a season/trend passes.
- Keep this a BUSINESS/PREMIUM differentiator, consistent with how
  `hasReportsAll`/`hasAllPush` are already gated.

## Non-goals (explicitly out of scope for v1)

- True FIFO/lot inventory accounting (a real `Batch`/`Lot` table with
  per-batch remaining-quantity tracking and batch-aware sale consumption).
  The data model stays exactly as it is today — no new tables, no changes
  to how `StockMovement`/`SaleItem`/`Product.costPrice` behave.
- Automatic price-drop calculation or one-tap discount application. The
  notification links to the existing product-edit price field; the owner
  decides and types the new price themselves.
- Historical view of *past* batches (only the current one — since the most
  recent `PURCHASE` movement — is tracked).

## Two distinct numbers, not one

Early in design, "profit" and "cash payback" got conflated — worth stating
explicitly since it drove the final UI: these are two different, both
useful questions, and the UI shows both, clearly labeled, rather than
picking one:

- **Прибыль заработана** (profit already earned) — standard accounting
  profit on units actually sold: `Σ (unitPrice − costPrice_snapshot) ×
  (quantity − refundedQuantity)` over sold line items. This is real money
  already made per unit sold, independent of whether the whole restock's
  cash outlay has been recovered yet.
- **До окупаемости партии** (shortfall to full payback) — cash-flow view:
  `revenue_from_batch − cost_of_batch`. Negative means the owner hasn't yet
  recovered, in cash terms, everything they spent buying the whole restock
  (the unsold units still on the shelf are a real asset, just not yet
  converted to cash). Positive means the batch has fully paid for itself
  and everything sold beyond that point is pure profit on top.

Worked example (100 units @ 10 TJS cost, sold 33 @ 30 TJS, 67 remain):
- Cost of batch: 100 × 10 = 1000
- Revenue from batch: 33 × 30 = 990
- Прибыль заработана: 33 × (30−10) = **+660 TJS**
- До окупаемости партии: 990 − 1000 = **−10 TJS** (one more sale away from
  full payback)
- Остаток: 67 шт., себестоимость остатка 67 × 10 = 670 TJS

## Metric definitions

"Partiya" is not a new stored entity — it's computed on read from data that
already exists:

1. **Anchor**: the most recent `StockMovement` of `type = PURCHASE` for the
   product. Its `quantity` and `unitCost`/`totalCost` are the batch size and
   batch cost, fixed at the time of that purchase (doesn't drift if the
   product is later restocked at a different cost — that starts a *new*
   batch cycle instead, which is the intended behavior, not a bug).
2. **Sold from this batch**: sum of `SaleItem.quantity −
   SaleItem.refundedQuantity` for this product where the parent `Sale.
   createdAt >= anchor.createdAt`.
3. **Revenue from batch**: sum of `SaleItem.unitPrice × (quantity −
   refundedQuantity)` over the same set, net of item-level discount
   (use `SaleItem.total`, which already reflects discount, rather than
   `unitPrice × quantity` — consistent with how the sales module already
   computes line totals elsewhere).
4. **Профиль заработана**: sum of `(unitPrice_per_unit − costPrice_snapshot)
   × (quantity − refundedQuantity)` over the same set — uses each sale's own
   `SaleItem.costPrice` snapshot, so it stays correct even if `Product.
   costPrice` has since changed.
5. **Остаток**: current `Product.quantity` (live counter, not derived from
   the batch — may not exactly equal `batch_qty − sold_qty` if there were
   `WRITE_OFF`/`ADJUSTMENT`/`RETURN` movements in between; that's expected
   and informative, not reconciled away).
6. **Себестоимость остатка**: `Product.quantity × Product.costPrice`
   (current cost, per the earlier decision to keep this simple rather than
   historically exact).
7. **Окупаемость, %**: `revenue_from_batch / cost_of_batch × 100`, clamped
   for display at a sane upper bound (selling out and continuing to sell
   more than the original batch size after a fresh restock is normal; don't
   let the percentage look broken — see open question below).

**No-anchor edge case**: if a product has never had a `PURCHASE`
`StockMovement` (e.g. its initial `quantity` was set directly at product
creation and never restocked through the stock-intake flow), there's no
batch to compute. Show an empty/prompt state instead of a zero or
misleading number: "Нет данных о последней закупке — оформите приход, чтобы
видеть окупаемость партии."

## UI

- **Product list/grid cards** (`product_card.dart`, `product_list_item.dart`):
  a small colored badge showing payback %, visible only to
  OWNER/ADMIN — red (<50%), yellow (50–99%), green (≥100%). Hidden entirely
  (no badge) for CASHIER/WAREHOUSE and for products with no anchor.
- **Product detail page** (`product_detail_page.dart`): a new card block,
  "Окупаемость партии", alongside the existing 2×2 price/cost/profit/margin
  grid. Shows: cost of batch, revenue from batch, Прибыль заработана
  (+660), До окупаемости партии (−10 or "Партия окупилась" once ≥0),
  Остаток (67 шт. / 670 TJS).

## Access control

Gated the same way as other manage-level product actions — reuse the
existing `products.manage`-style permission check (or a dedicated
`products.viewProfitability` permission if that reads cleaner against the
current permissions matrix; decide during planning by checking what's
already there) so OWNER/ADMIN see it and CASHIER/WAREHOUSE don't.

## Notifications

- **Trigger**: no sale of the product in **30 days** (configurable per
  store, default 30) AND remaining quantity ≥ **50%** of the batch quantity
  (configurable per store, default 50%).
- **Cadence**: daily cron job, following the existing pattern in
  `loyalty.service.ts` (`@Cron(...)` + `sendToStoreUsers`).
- **Content**: `Товар "{name}" не продаётся {N} дней, осталось {qty} из
  {batchQty} шт. Возможно, стоит снизить цену.`
- **Action**: tapping the notification navigates to the product detail
  page. No auto-discount calculation or one-tap action in v1 — the owner
  edits the price manually via the existing edit flow.
- **Settings**: the two thresholds (days-without-sale, remaining-%) live in
  store settings alongside the existing `lowStockAlerts`-style toggles.

## Subscription plan gating

New `SubscriptionPlanConfig` boolean flag: `hasBatchProfitability`.
- START: `false`
- BUSINESS: `true`
- PREMIUM: `true`

A dedicated flag (not reusing `hasReportsAll`/`hasAllPush`) so this can be
priced/toggled independently later without entangling it with unrelated
reporting features. Gates both the UI metric display and the notification
cron for that store.

## Data/API surface (for planning, not full implementation detail)

- Backend: no schema migration needed beyond the new
  `SubscriptionPlanConfig.hasBatchProfitability` boolean (and its seed
  values in `seedPlanConfigs()`).
- New computed response, either as fields embedded in the existing
  `GET /stores/:storeId/products/:id` response or a new
  `GET /stores/:storeId/products/:id/batch-profitability` endpoint —
  decide during planning based on how heavy the product-detail response
  already is and whether this should be lazy-loaded.
- New cron job in a sensible existing or new service (e.g.
  `products` module or a small dedicated service) mirroring loyalty's
  `@Cron` + `sendToStoreUsers` pattern, gated by
  `hasBatchProfitability` and the store's configured thresholds.
- Flutter: extend `Product` entity (or a separate value object returned
  alongside it) with the computed fields; extend `product_card.dart`/
  `product_list_item.dart` with the badge; new block on
  `product_detail_page.dart`; new settings fields for the two thresholds.

## Open questions for the planning phase

- Exact permission key to gate on (reuse vs. new) — resolve by reading the
  current permissions matrix during planning, not guessing here.
- Display treatment when payback % is very high (e.g. 400%, a small
  restock that sold out and kept selling into what's really the *next*
  purchase's inventory before that purchase was recorded as a
  `StockMovement`) — likely just let the number run high with no artificial
  cap, since it's an honest signal, but worth a product decision.
- Whether the batch-profitability fields belong on the existing product
  GET response or a separate endpoint (performance/lazy-load tradeoff).
