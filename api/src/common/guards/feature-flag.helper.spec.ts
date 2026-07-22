import { hasFeatureFlag } from './feature-flag.helper';

// Direct unit tests for hasFeatureFlag() itself, independent of the
// callers that use it (ProductsService.findAll's paybackPercent gating,
// StockAlertsService's cron gating). This mirrors SubscriptionGuard's
// policy — plan-has-flag AND status is ACTIVE/TRIAL — so it needs its
// own coverage of the status gate rather than relying solely on those
// callers' fakes, which historically never modeled `status` at all.

type SubscriptionRow = {
  storeId: string;
  plan: string;
  status: string;
};
type PlanConfigRow = {
  plan: string;
  hasBatchProfitability: boolean;
};

function makePrismaFake(opts: {
  subscriptions?: SubscriptionRow[];
  planConfigs?: PlanConfigRow[];
}) {
  const subscriptions = opts.subscriptions ?? [];
  const planConfigs = opts.planConfigs ?? [];

  return {
    subscription: {
      findUnique: jest.fn(async ({ where }: any) => {
        return subscriptions.find((s) => s.storeId === where.storeId) ?? null;
      }),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async ({ where }: any) => {
        return planConfigs.find((c) => c.plan === where.plan) ?? null;
      }),
    },
  } as any;
}

describe('hasFeatureFlag', () => {
  it('returns false when there is no subscription row for the store', async () => {
    const prisma = makePrismaFake({});

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(false);
    expect(prisma.subscriptionPlanConfig.findUnique).not.toHaveBeenCalled();
  });

  it('returns true when status is ACTIVE and the plan has the flag', async () => {
    const prisma = makePrismaFake({
      subscriptions: [
        { storeId: 'store-1', plan: 'BUSINESS', status: 'ACTIVE' },
      ],
      planConfigs: [{ plan: 'BUSINESS', hasBatchProfitability: true }],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(true);
  });

  it('returns true when status is TRIAL and the plan has the flag', async () => {
    const prisma = makePrismaFake({
      subscriptions: [
        { storeId: 'store-1', plan: 'BUSINESS', status: 'TRIAL' },
      ],
      planConfigs: [{ plan: 'BUSINESS', hasBatchProfitability: true }],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(true);
  });

  it('returns false when status is PAST_DUE even though the plan has the flag (regression case)', async () => {
    // The exact bug this fixes: a privileged plan with a lapsed
    // subscription must still deny, matching SubscriptionGuard.
    const prisma = makePrismaFake({
      subscriptions: [
        { storeId: 'store-1', plan: 'BUSINESS', status: 'PAST_DUE' },
      ],
      planConfigs: [{ plan: 'BUSINESS', hasBatchProfitability: true }],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(false);
    expect(prisma.subscriptionPlanConfig.findUnique).not.toHaveBeenCalled();
  });

  it('returns false when status is CANCELLED', async () => {
    const prisma = makePrismaFake({
      subscriptions: [
        { storeId: 'store-1', plan: 'BUSINESS', status: 'CANCELLED' },
      ],
      planConfigs: [{ plan: 'BUSINESS', hasBatchProfitability: true }],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(false);
  });

  it('returns false when status is EXPIRED', async () => {
    const prisma = makePrismaFake({
      subscriptions: [
        { storeId: 'store-1', plan: 'BUSINESS', status: 'EXPIRED' },
      ],
      planConfigs: [{ plan: 'BUSINESS', hasBatchProfitability: true }],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(false);
  });

  it('returns false when status is ACTIVE but there is no matching SubscriptionPlanConfig row', async () => {
    const prisma = makePrismaFake({
      subscriptions: [
        { storeId: 'store-1', plan: 'BUSINESS', status: 'ACTIVE' },
      ],
      planConfigs: [],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(false);
  });

  it('returns false when status is ACTIVE and the plan config exists but the flag is false', async () => {
    const prisma = makePrismaFake({
      subscriptions: [{ storeId: 'store-1', plan: 'START', status: 'ACTIVE' }],
      planConfigs: [{ plan: 'START', hasBatchProfitability: false }],
    });

    await expect(
      hasFeatureFlag(prisma, 'store-1', 'hasBatchProfitability'),
    ).resolves.toBe(false);
  });
});
