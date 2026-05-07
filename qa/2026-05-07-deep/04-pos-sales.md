# Phase 4 — POS & Sales

**Date:** 2026-05-07
**Stack:** API :4455, store qa-store-A on START plan.

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Stock intake (PURCHASE +20 / +50) | 🟢 PASS | — | Quantities updated correctly. unitCost stored. |
| Sales: cash sale, paid > total | 🟢 PASS | — | subtotal=15, paid=20, change=5. Stock decremented apple 20→17. Receipt R-000001 generated. |
| Sales: debt sale (full debt, customer linked) | 🟢 PASS | — | debt=5, customer.debt=5, customer.totalSpent=5. |
| Sales: mixed sale (12 cash + 8 debt = 20) | 🟢 PASS | — | debt=8, customer.debt 5→13, totalSpent 5→25. |
| Sales: empty cart blocked | 🟢 PASS | — | 400 "Sale must have at least one item". |
| Sales: oversell blocked | 🟢 PASS | — | 400 "Insufficient stock for 🍎 Яблоко 🟢. Available: 17". UTF-8 product name preserved in error message. |
| **Sales: CASH paid < total** | 🔴 FAIL | **P1** | See F4.1 — silently creates orphan debt with no customer. |
| Sales: refund (partial) | 🟢 PASS | — | status → PARTIALLY_RETURNED, stock returned (apple 8→10). |
| **Sales: refund updates customer.debt** | 🔴 FAIL | **P1** | See F4.2 — customer debt unchanged after refunding goods bought on credit. |
| Sales: list filter by status | 🟢 PASS | — | `?status=COMPLETED` and `?status=PARTIALLY_RETURNED` return correct subsets. |
| Sales: receipt numbering | 🟡 NIT | P3 | Sequence has gaps (R-000001, 000002, 000004, 000005 — no 000003 in final state). Likely a failed transaction reserved the number then released it. Confusing for users / accounting. |

## Findings

### F4.1 — P1: CASH paymentType silently converts shortfall to orphan debt

**Repro:**
```bash
# Sell 5 apples × 5 TJS = 25 TJS, cash payment, but only 5 paid
curl -X POST .../sales -d '{
  "items":[{"productId":"<APPLE>","quantity":5}],
  "paymentType":"CASH",
  "paidAmount":5
}'
```

**Expected:** 400 `BadRequest("Cash payment must cover the full total. For partial cash + debt, use paymentType=MIXED with a customerId")`.

**Observed:** 201. Sale created with:
```json
{
  "receiptNo":"R-000004",
  "total":25,
  "paymentType":"CASH",
  "paidAmount":5,
  "change":0,
  "debtAmount":20,
  "customerId":null,
  "status":"COMPLETED"
}
```
20 TJS of debt with **no customer attached**. The merchant has effectively
delivered 25 TJS of goods and received 5 TJS cash, with no record of who
owes the remaining 20.

**Why this matters:**
- Reports will count `total=25` as revenue but only 5 was collected
- The 20 TJS is invisible — it doesn't sit on any customer's debt page
- A cashier could exploit this to skim cash (sell goods, pocket the difference, mark as "cash partial")

**Fix path:** in `SalesService.create`, if `paymentType=CASH` and
`paidAmount < total`, throw 400. Either force MIXED + customerId or
DEBT + customerId.

### F4.2 — P1: Refund does not adjust customer debt

**Repro:**
1. Customer has debt=13, total spent=25 (from a mixed sale where they
   owed 8 + an earlier debt sale of 5).
2. Refund 2 of 4 apples from the mixed sale (worth 10 TJS).
3. Re-fetch customer.

**Expected:** customer.debt drops by min(refund_amount, current_sale_debt) = min(10, 8) = 8 → new debt = 5. The sale's `debtAmount` should also drop to 0.

**Observed:**
- Sale status correctly → PARTIALLY_RETURNED
- Sale's `debtAmount` still 8 (unchanged)
- Customer.debt still 13 (unchanged)
- Stock correctly returned (+2 apples)

**Why this matters:**
- Customer is still on the hook for goods they returned
- Reports of outstanding debt overstate by the refunded amount
- Manually settling the debt later would over-collect

**Fix path:** in `SalesService.refund`, if the original sale had
`debtAmount > 0` and `customerId`, compute the refunded portion and:
- decrement `Sale.debtAmount` by min(refunded_value, sale.debtAmount)
- decrement `Customer.debt` by the same amount
- decrement `Customer.totalSpent` by refunded_value

### F4.3 — P3: Receipt-number gaps

After a series of valid + invalid sale attempts, R-000003 is missing
from the final sequence (only 1, 2, 4, 5 exist). Likely a failed
transaction reserved the next number from a sequence and didn't roll
back.

**Why this matters:** in Tajikistan POS regulations and bookkeeping
practice, receipt numbers are usually expected to be a continuous
sequence per shift / per day for audit. Gaps may complicate later
reconciliation.

**Fix path:** generate the receiptNo INSIDE the sale-creation
transaction so a rollback also rolls back the number. OR move to a
gap-tolerant scheme and document it.

## What's pending

- **Telegram receipt send** — needs real chat ID. API contract:
  POST /api/stores/:storeId/telegram/send-receipt. Will exercise as
  smoke-only in Phase 9.
- **Bluetooth printer** — needs hardware. Out of scope.
- **Receipt preview** (UI rendering of the chosen sale) — UI flow,
  will fold into a Phase 9 walk.

## Phase 4 summary

8 PASS / **2 P1** (cash-shortfall orphan debt; refund doesn't adjust
customer debt) / 0 P0 / 1 P3 (receipt-number gaps).

The two P1s are revenue-correctness issues that affect day-to-day
bookkeeping in real shops. Both are small fixes and should land
before launch.
