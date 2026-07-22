import { PrismaService } from '../../prisma/prisma.service';

/**
 * Returns whether `storeId`'s current subscription plan has `flag`
 * enabled on SubscriptionPlanConfig. Fail-closed (false) if there's no
 * subscription, no plan config row, or the subscription's status isn't
 * one of ACTIVE/TRIAL — unlike assertWithinPlanLimit's fail-open
 * convention, a missing/misconfigured plan should not silently unlock a
 * paid feature. The status check mirrors SubscriptionGuard's exact gate
 * (`!['ACTIVE', 'TRIAL'].includes(subscription.status)` → deny), so a
 * lapsed subscription (PAST_DUE/CANCELLED/EXPIRED) is denied here the
 * same way it's denied at the route level, even though the plan itself
 * is untouched.
 */
export async function hasFeatureFlag(
  prisma: PrismaService,
  storeId: string,
  flag: 'hasBatchProfitability',
): Promise<boolean> {
  const sub = await prisma.subscription.findUnique({ where: { storeId } });
  if (!sub) return false;
  if (!['ACTIVE', 'TRIAL'].includes(sub.status)) return false;

  const planConfig = await prisma.subscriptionPlanConfig.findUnique({
    where: { plan: sub.plan },
  });
  if (!planConfig) return false;

  return Boolean(planConfig[flag]);
}
