-- 2026-05-11 finance correctness pass.
-- Spec: docs/superpowers/specs/2026-05-11-finance-nav-fixes-design.md
-- Brainstorm decisions: Q1=C, Q4a=B (CHECK), Q4b=ii (orphan debts).
--
-- Order matters: cleanup data BEFORE adding the CHECK constraint, otherwise
-- the constraint creation fails on existing bad rows.

-- 1. Clamp legacy negative numeric fields on `sales` to 0.
-- These existed as a side-effect of the BUG #14 probe pollution (yesterday).
-- BUG #14 fix already prevents new sales from going negative via the API,
-- but historic rows are still in the DB and break the finance dashboard
-- aggregations (BUG #29). Update is idempotent.
UPDATE "sales" SET "total"      = 0 WHERE "total"      < 0;
UPDATE "sales" SET "subtotal"   = 0 WHERE "subtotal"   < 0;
UPDATE "sales" SET "paidAmount" = 0 WHERE "paidAmount" < 0;
UPDATE "sales" SET "change"     = 0 WHERE "change"     < 0;
UPDATE "sales" SET "debtAmount" = 0 WHERE "debtAmount" < 0;

-- 2. Same for sale_items (the discount is the originator of the bug, but
-- the resulting line.total can also be negative).
UPDATE "sale_items" SET "total"    = 0 WHERE "total"    < 0;
UPDATE "sale_items" SET "discount" = 0 WHERE "discount" < 0;

-- 3. Orphan debt cleanup. F4.1 (Sprint A) prevents future writes that
-- have customerId=null AND debtAmount>0, but legacy rows from before
-- F4.1 may exist. Phantom debts the merchant cannot collect — set
-- to 0 so they stop polluting the customer-debt aggregations.
UPDATE "sales"
   SET "debtAmount" = 0
 WHERE "customerId" IS NULL AND "debtAmount" > 0;

-- 4. Add CHECK constraints. Defense in depth — the API clamp from
-- BUG #14 stops bad writes through the normal path, but a direct
-- SQL admin write or broken seed could re-pollute. Postgres now
-- rejects them at the row level.
ALTER TABLE "sales"
  ADD CONSTRAINT "sales_total_non_negative"      CHECK ("total"      >= 0),
  ADD CONSTRAINT "sales_subtotal_non_negative"   CHECK ("subtotal"   >= 0),
  ADD CONSTRAINT "sales_paidAmount_non_negative" CHECK ("paidAmount" >= 0),
  ADD CONSTRAINT "sales_change_non_negative"     CHECK ("change"     >= 0),
  ADD CONSTRAINT "sales_debtAmount_non_negative" CHECK ("debtAmount" >= 0);

ALTER TABLE "sale_items"
  ADD CONSTRAINT "sale_items_total_non_negative"    CHECK ("total"    >= 0),
  ADD CONSTRAINT "sale_items_discount_non_negative" CHECK ("discount" >= 0);
