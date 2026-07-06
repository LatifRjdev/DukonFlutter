-- Enable loyalty for BIZ+ plans
UPDATE "subscription_plan_configs"
SET "hasLoyalty" = true
WHERE plan IN ('BUSINESS', 'PREMIUM');
