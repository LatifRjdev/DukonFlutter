import { SubscriptionPlanConfig } from '@prisma/client';

/**
 * Every feature flag on SubscriptionPlanConfig, in one place.
 *
 * getSubscription used to type seven of these out by hand into its response
 * while the table had eleven. Three of the four it missed — hasZakat,
 * hasLoyalty, hasBatchProfitability — are enforced server-side with
 * @RequiresFeature on whole controllers, so the app could not gate them and a
 * merchant on a plan without them met a 403 reading "Недостаточно прав".
 *
 * plan-view.spec.ts parses `model SubscriptionPlanConfig` out of schema.prisma
 * and fails if any has* column is absent here, so the list cannot drift again.
 */
export const PLAN_FEATURE_FLAGS = [
  'hasReportsAll',
  'hasExport',
  'hasTelegram',
  'hasAllPush',
  'hasDelivery',
  'hasInventory',
  'hasZakat',
  'hasInvestments',
  'hasLoyalty',
  'hasBatchProfitability',
  'hasEcommerceIntegration',
] as const;

export type PlanFeatureFlag = (typeof PLAN_FEATURE_FLAGS)[number];

export type PlanFeatures = Record<PlanFeatureFlag, boolean>;

export interface PlanView {
  plan: string;
  /** What this merchant pays, discount applied. */
  price: number;
  /** Before the discount, so a card can show what is being saved. */
  listPrice: number;
  maxProducts: number;
  maxStaff: number;
  maxDiscounts: number;
  features: PlanFeatures;
}

/**
 * The merchant's price for a plan. The ONLY place the discount is applied.
 *
 * getSubscription rounded (`Math.round(p * 100) / 100`) and requestChange did
 * not, so the two disagreed wherever the arithmetic was inexact: 33% off the
 * PREMIUM price of 600 gives 401.99999999999994 from one and 402 from the
 * other. Decimal(12,2) reconciled them on write, which is why nobody noticed.
 *
 * Not 200 — `200 * (1 - 33/100)` is exactly 134, which is how the first
 * version of the spec test came to assert nothing.
 * Both call this now.
 */
export function discountedPrice(
  listPrice: number,
  discountPercent: number | null | undefined,
): number {
  // Clamped rather than trusted. `SetDiscountDto` constrains this to 0-100 and
  // is the only writer today, so nothing can currently reach the branches
  // below — but this function is now the single place a merchant's price is
  // decided, and a price that goes negative because a caller skipped
  // validation is not a failure mode worth leaving open for the sake of two
  // lines.
  const raw = discountPercent ? Number(discountPercent) : 0;
  const discount = Math.min(100, Math.max(0, raw));
  return Math.round(listPrice * (1 - discount / 100) * 100) / 100;
}

export function toPlanView(
  config: SubscriptionPlanConfig,
  discountPercent: number | null | undefined,
): PlanView {
  const listPrice = Number(config.price);
  const features = Object.fromEntries(
    PLAN_FEATURE_FLAGS.map((flag) => [flag, config[flag]]),
  ) as PlanFeatures;

  return {
    plan: config.plan,
    price: discountedPrice(listPrice, discountPercent),
    listPrice,
    maxProducts: config.maxProducts,
    maxStaff: config.maxStaff,
    maxDiscounts: config.maxDiscounts,
    features,
  };
}
