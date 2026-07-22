import { PrismaService } from '../../prisma/prisma.service';

/**
 * Returns whether `storeId`'s current subscription plan has `flag`
 * enabled on SubscriptionPlanConfig. Fail-closed (false) if there's no
 * subscription or no plan config row — unlike assertWithinPlanLimit's
 * fail-open convention, a missing/misconfigured plan should not silently
 * unlock a paid feature.
 */
export async function hasFeatureFlag(
  prisma: PrismaService,
  storeId: string,
  flag: 'hasBatchProfitability',
): Promise<boolean> {
  const sub = await prisma.subscription.findUnique({ where: { storeId } });
  if (!sub) return false;

  const planConfig = await prisma.subscriptionPlanConfig.findUnique({
    where: { plan: sub.plan },
  });
  if (!planConfig) return false;

  return Boolean(planConfig[flag]);
}
