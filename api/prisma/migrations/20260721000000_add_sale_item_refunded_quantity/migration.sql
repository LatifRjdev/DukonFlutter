-- Migration: track cumulative refunded quantity per sale item.
-- Without this, SalesService.refund() could only validate a refund
-- request against the sale item's original quantity, so the same
-- saleItemId could be resubmitted for refund an unbounded number of
-- times (each call re-incrementing stock and re-crediting customer
-- debt/totalSpent) as long as the sale hadn't reached the fully-
-- RETURNED terminal state.
ALTER TABLE "sale_items" ADD COLUMN "refundedQuantity" INTEGER NOT NULL DEFAULT 0;
