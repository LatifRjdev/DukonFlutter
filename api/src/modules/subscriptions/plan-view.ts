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
 * not, so 33% off 200 produced 134 from one and 134.00000000000003 from the
 * other. Decimal(12,2) reconciled them on write, which is why nobody noticed.
 * Both call this now.
 */
export function discountedPrice(
  listPrice: number,
  discountPercent: number | null | undefined,
): number {
  const discount = discountPercent ? Number(discountPercent) : 0;
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
