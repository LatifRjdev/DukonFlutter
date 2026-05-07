import { ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export type PlanLimitField =
  | 'maxStores'
  | 'maxProducts'
  | 'maxStaff'
  | 'maxDiscounts';

/**
 * Server-side plan-limit gate. Throws ForbiddenException when the
 * caller is at or beyond the plan's headroom for `field`.
 *
 * - A limit value of `-1` means unlimited (PREMIUM convention).
 * - A missing subscription / planConfig = fail-open (no limit applied)
 *   so a misconfigured row can't lock a customer out of their own data.
 *   Misconfiguration should surface elsewhere (admin alert).
 *
 * Closes F2.1 from qa/2026-05-07-deep/SUMMARY.md.
 */
export async function assertWithinPlanLimit(
  prisma: PrismaService,
  storeId: string,
  field: PlanLimitField,
  currentCount: number,
): Promise<void> {
  const sub = await prisma.subscription.findUnique({
    where: { storeId },
  });
  if (!sub) return;

  // SubscriptionPlanConfig is keyed by plan enum (no FK on Subscription),
  // so we look it up separately. Missing config row = fail-open (admin
  // hasn't configured this plan tier yet).
  const planConfig = await prisma.subscriptionPlanConfig.findUnique({
    where: { plan: sub.plan },
  });
  if (!planConfig) return;

  const limit = planConfig[field];
  if (limit === -1 || limit == null) return;
  if (currentCount < limit) return;

  throw new ForbiddenException(
    `Plan limit reached: ${sub.plan} allows ${limit} ${humanize(field)}. Upgrade your subscription to add more.`,
  );
}

function humanize(field: PlanLimitField): string {
  switch (field) {
    case 'maxStores':
      return 'stores';
    case 'maxProducts':
      return 'products';
    case 'maxStaff':
      return 'staff members';
    case 'maxDiscounts':
      return 'discount rules';
  }
}
