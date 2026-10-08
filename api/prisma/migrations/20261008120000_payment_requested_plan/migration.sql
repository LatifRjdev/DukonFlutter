-- The plan a payment buys, promoted out of the free-text note.
--
-- Approval used to recover it from `note` with a regular expression, so a
-- miss silently left the plan unchanged while the money was taken. It misses
-- for every manual payment, whose note an admin types freely.
ALTER TABLE "payments" ADD COLUMN "requestedPlan" "SubscriptionPlan";

-- Backfill from the only format requestChange has ever written. One exact
-- LIKE per plan rather than a single loose pattern: the set is three and
-- closed, and a broad match could mis-assign.
--
-- Rows this cannot parse stay NULL, which approval reads as "extend the
-- period, leave the plan alone" — already their behaviour, now visible.
UPDATE "payments" SET "requestedPlan" = 'START'
 WHERE "note" LIKE 'Plan change request to START%' AND "requestedPlan" IS NULL;

UPDATE "payments" SET "requestedPlan" = 'BUSINESS'
 WHERE "note" LIKE 'Plan change request to BUSINESS%' AND "requestedPlan" IS NULL;

UPDATE "payments" SET "requestedPlan" = 'PREMIUM'
 WHERE "note" LIKE 'Plan change request to PREMIUM%' AND "requestedPlan" IS NULL;
