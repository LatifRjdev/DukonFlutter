-- Enable e-commerce integration for PREMIUM plan
UPDATE "subscription_plan_configs"
SET "hasEcommerceIntegration" = true
WHERE plan = 'PREMIUM';
