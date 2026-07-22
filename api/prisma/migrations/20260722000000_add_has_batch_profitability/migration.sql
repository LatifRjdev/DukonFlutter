-- Migration: add hasBatchProfitability flag to subscription_plan_configs.
ALTER TABLE "subscription_plan_configs" ADD COLUMN "hasBatchProfitability" BOOLEAN NOT NULL DEFAULT false;
