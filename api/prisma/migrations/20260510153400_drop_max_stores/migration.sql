-- Drop maxStores from subscription_plan_configs.
-- See PlanLimitField in src/common/guards/plan-limit.helper.ts for context:
-- each store has its own subscription, so a per-merchant store cap had
-- no architectural anchor and was never enforced.
ALTER TABLE "subscription_plan_configs" DROP COLUMN "maxStores";
