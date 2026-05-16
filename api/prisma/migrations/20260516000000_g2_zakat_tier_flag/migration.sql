-- Z-P1-4: hasZakat tier flag on SubscriptionPlanConfig.
-- Decision (2026-05-16): tier-gated.
--   START    → false (basic POS, no advanced accounting)
--   BUSINESS → true
--   PREMIUM  → true
-- Same pattern as hasReportsAll, hasInventory, hasDelivery.
-- Default false on the column itself so existing/future rows
-- without an explicit value land in the "no zakat" state.

ALTER TABLE "subscription_plan_configs"
  ADD COLUMN "hasZakat" BOOLEAN NOT NULL DEFAULT false;

-- Backfill the 3 seeded plan rows.
UPDATE "subscription_plan_configs" SET "hasZakat" = false WHERE plan = 'START';
UPDATE "subscription_plan_configs" SET "hasZakat" = true  WHERE plan = 'BUSINESS';
UPDATE "subscription_plan_configs" SET "hasZakat" = true  WHERE plan = 'PREMIUM';
