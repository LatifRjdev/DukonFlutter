-- Spec D: data integrity hardening for Investment.

-- 1. Idempotent create.
ALTER TABLE "investments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "investments_storeId_localId_key"
  ON "investments"("storeId", "localId");

-- 2. List performance — covering index for default sort.
CREATE INDEX "investments_storeId_createdAt_idx"
  ON "investments"("storeId", "createdAt" DESC);

-- 3. DB-level non-negative guards.
ALTER TABLE "investments"
  ADD CONSTRAINT investments_amount_non_negative
    CHECK ("amount" >= 0),
  ADD CONSTRAINT investments_return_amount_non_negative
    CHECK ("returnAmount" IS NULL OR "returnAmount" >= 0);

-- 4. Tier-gating flag on SubscriptionPlanConfig.
ALTER TABLE "subscription_plan_configs"
  ADD COLUMN "hasInvestments" BOOLEAN NOT NULL DEFAULT false;

UPDATE "subscription_plan_configs" SET "hasInvestments" = false WHERE plan = 'START';
UPDATE "subscription_plan_configs" SET "hasInvestments" = true  WHERE plan = 'BUSINESS';
UPDATE "subscription_plan_configs" SET "hasInvestments" = true  WHERE plan = 'PREMIUM';
