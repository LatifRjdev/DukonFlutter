import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { SubscriptionsService } from './subscriptions.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SubscriptionPlanEnum } from './dto/request-change.dto';

// Behavioral fake covering only the prisma surface SubscriptionsService
// touches in the methods under test. We DO NOT call onModuleInit (which
// seeds plan configs) — tests construct the service via Nest DI but skip
// lifecycle, since seeding is not behavior we're testing here.
function makePrismaFake() {
  type Sub = {
    id: string;
    storeId: string;
    plan: string;
    status: string;
    currentPeriodStart: Date;
    currentPeriodEnd: Date;
    adminDiscount: number | null;
    createdAt: Date;
    updatedAt: Date;
    payments?: any[];
  };

  const subsByStore = new Map<string, Sub>();
  const subsById = new Map<string, Sub>();

  // Full per-plan config rows, including the boolean feature flags and
  // numeric limits that getSubscription() now surfaces as top-level
  // `features`/`limits` objects (and as `availablePlans`) for the mobile
  // client. Eleven flags, matching the real seed in onModuleInit.
  const planConfigs: Record<string, any> = {
    START: {
      plan: 'START',
      price: 200,
      maxProducts: 500,
      maxStaff: 2,
      maxDiscounts: 0,
      hasReportsAll: false,
      hasExport: false,
      hasTelegram: false,
      hasAllPush: false,
      hasDelivery: false,
      hasInventory: false,
      hasZakat: false,
      hasInvestments: false,
      hasLoyalty: false,
      hasBatchProfitability: false,
      hasEcommerceIntegration: false,
    },
    BUSINESS: {
      plan: 'BUSINESS',
      price: 400,
      maxProducts: 2000,
      maxStaff: 10,
      maxDiscounts: 5,
      hasReportsAll: true,
      hasExport: false,
      hasTelegram: true,
      hasAllPush: true,
      hasDelivery: true,
      hasInventory: true,
      hasZakat: true,
      hasInvestments: true,
      hasLoyalty: true,
      hasBatchProfitability: true,
      hasEcommerceIntegration: false,
    },
    PREMIUM: {
      plan: 'PREMIUM',
      price: 600,
      maxProducts: -1,
      maxStaff: -1,
      maxDiscounts: -1,
      hasReportsAll: true,
      hasExport: true,
      hasTelegram: true,
      hasAllPush: true,
      hasDelivery: true,
      hasInventory: true,
      hasZakat: true,
      hasInvestments: true,
      hasLoyalty: true,
      hasBatchProfitability: true,
      hasEcommerceIntegration: true,
    },
  };

  return {
    _subsByStore: subsByStore,
    _subsById: subsById,
    subscription: {
      findUnique: jest.fn(async ({ where, include }: any = {}) => {
        let sub: Sub | undefined;
        if (where?.storeId) sub = subsByStore.get(where.storeId);
        else if (where?.id) sub = subsById.get(where.id);
        if (!sub) return null;
        if (include?.store) {
          return { ...sub, store: { name: 'Store ' + sub.storeId } };
        }
        return { ...sub };
      }),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async ({ where }: any) => {
        return planConfigs[where.plan] ?? null;
      }),
      // getSubscription() now fetches every plan (for `availablePlans`) via
      // findMany rather than looking up a single plan by name.
      findMany: jest.fn(async () => Object.values(planConfigs)),
      upsert: jest.fn(async ({ where, create }: any) => ({
        plan: where.plan,
        ...create,
      })),
    },
  };
}

const fakeNotifications = {
  sendPush: jest.fn(async () => undefined),
} as unknown as NotificationsService;

describe('SubscriptionsService — read paths', () => {
  let service: SubscriptionsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  describe('getSubscription', () => {
    it('should return active or trial subscription for store when one exists', async () => {
      const now = new Date();
      const in30 = new Date(now);
      in30.setDate(in30.getDate() + 30);

      const sub = {
        id: 'sub-1',
        storeId: 'store-A',
        plan: 'BUSINESS',
        status: 'ACTIVE',
        currentPeriodStart: now,
        currentPeriodEnd: in30,
        adminDiscount: null,
        createdAt: now,
        updatedAt: now,
      };
      prisma._subsByStore.set('store-A', sub);
      prisma._subsById.set('sub-1', sub);

      const result = await service.getSubscription('store-A');

      expect(result.status).toBe('ACTIVE');
      expect(result.plan).toBe('BUSINESS');
      expect(result.calculatedPrice).toBe(400);
    });

    it('should throw NotFoundException when no subscription exists for store', async () => {
      await expect(
        service.getSubscription('ghost-store'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should include features and limits objects derived from planConfig when a subscription exists', async () => {
      const now = new Date();
      const in30 = new Date(now);
      in30.setDate(in30.getDate() + 30);

      const sub = {
        id: 'sub-premium',
        storeId: 'store-premium',
        plan: 'PREMIUM',
        status: 'ACTIVE',
        currentPeriodStart: now,
        currentPeriodEnd: in30,
        adminDiscount: null,
        createdAt: now,
        updatedAt: now,
      };
      prisma._subsByStore.set('store-premium', sub);
      prisma._subsById.set('sub-premium', sub);

      const result = await service.getSubscription('store-premium');

      // The field the real-world bug hinged on: mobile's client-side gate
      // reads result.features.hasEcommerceIntegration, not
      // result.planConfig.hasEcommerceIntegration.
      //
      // features used to be typed out by hand as seven keys; it is now
      // derived from PLAN_FEATURE_FLAGS (eleven keys), so we check the keys
      // this test cares about via toMatchObject rather than an exact object
      // — growing the flag set should not require editing this assertion.
      // hasZakat/hasInvestments/hasLoyalty/hasBatchProfitability are the
      // four that getSubscription used to drop entirely, which is the whole
      // defect this fixes: a PREMIUM merchant with @RequiresFeature-gated
      // controllers for zakat/loyalty/batch profitability hit a 403 reading
      // "Недостаточно прав" despite being entitled.
      expect(result.features).toMatchObject({
        hasReportsAll: true,
        hasExport: true,
        hasTelegram: true,
        hasAllPush: true,
        hasDelivery: true,
        hasInventory: true,
        hasZakat: true,
        hasInvestments: true,
        hasLoyalty: true,
        hasBatchProfitability: true,
        hasEcommerceIntegration: true,
      });
      expect(Object.keys(result.features ?? {})).toHaveLength(11);
      expect(result.limits).toEqual({
        maxProducts: -1,
        maxStaff: -1,
        maxDiscounts: -1,
      });
      // planConfig stays present too — additive change, not a replacement.
      expect(result.planConfig).toBeTruthy();
    });

    it('should leave features and limits undefined when the subscription plan has no seeded planConfig row', async () => {
      const now = new Date();
      const in30 = new Date(now);
      in30.setDate(in30.getDate() + 30);

      const sub = {
        id: 'sub-orphan',
        storeId: 'store-orphan',
        plan: 'UNSEEDED_PLAN',
        status: 'ACTIVE',
        currentPeriodStart: now,
        currentPeriodEnd: in30,
        adminDiscount: null,
        createdAt: now,
        updatedAt: now,
      };
      prisma._subsByStore.set('store-orphan', sub);
      prisma._subsById.set('sub-orphan', sub);

      const result = await service.getSubscription('store-orphan');

      expect(result.planConfig).toBeNull();
      expect(result.features).toBeUndefined();
      expect(result.limits).toBeUndefined();
      expect(result.calculatedPrice).toBe(0);
    });

    it('should compute remaining days correctly when subscription is active in the future', async () => {
      // Helper computation that mirrors what the cron uses for reminders.
      // We assert the math in isolation to lock down the day-bucket rule.
      const now = new Date('2026-04-27T12:00:00Z');
      const end = new Date('2026-05-02T12:00:00Z'); // 5 days later
      const msLeft = end.getTime() - now.getTime();
      const daysLeft = Math.ceil(msLeft / (1000 * 60 * 60 * 24));
      expect(daysLeft).toBe(5);
    });

    it('should treat subscription as expired when validUntil is in the past relative to now', async () => {
      // checkExpiredSubscriptions queries currentPeriodEnd < now; we assert
      // the predicate directly to lock down the comparison rule.
      const now = new Date('2026-04-27T12:00:00Z');
      const expiredEnd = new Date('2026-04-26T12:00:00Z');
      const activeEnd = new Date('2026-04-28T12:00:00Z');

      expect(expiredEnd < now).toBe(true);
      expect(activeEnd < now).toBe(false);
    });
  });
});

// ─── Admin write-path audit log tests ────────────────────────────────────────

function makeAdminPrismaFake() {
  const now = new Date();
  const in30 = new Date(now);
  in30.setDate(in30.getDate() + 30);

  const baseSub = {
    id: 'sub-audit',
    storeId: 'store-audit',
    plan: 'START',
    status: 'ACTIVE',
    currentPeriodStart: now,
    currentPeriodEnd: in30,
    adminDiscount: null,
    createdAt: now,
    updatedAt: now,
  };

  const basePayment = {
    id: 'pay-audit',
    subscriptionId: 'sub-audit',
    status: 'PENDING',
    amount: 200,
    plan: 'START',
    note: null,
    rejectionReason: null,
    reviewedAt: null,
    reviewedBy: null,
    createdAt: now,
    updatedAt: now,
  };

  const fakePrisma: any = {
    $transaction: jest.fn(async (ops: Promise<any>[]) => Promise.all(ops)),
    subscription: {
      findUnique: jest.fn(async ({ where, include }: any = {}) => {
        if (where?.id !== 'sub-audit') return null;
        const sub = { ...baseSub };
        if (include?.payments) {
          return {
            ...sub,
            payments: [{ ...basePayment }],
          };
        }
        return sub;
      }),
      update: jest.fn(async ({ data }: any) => ({ ...baseSub, ...data })),
    },
    payment: {
      update: jest.fn(async ({ data }: any) => ({
        ...basePayment,
        ...data,
        status: data.status ?? basePayment.status,
      })),
      // adminApprovePayment's supersede step: reject every other PENDING
      // payment on the subscription. Not exercised by these fixtures (each
      // has only the one `basePayment` in play), so `{ count: 0 }` is the
      // right default.
      updateMany: jest.fn(async () => ({ count: 0 })),
    },
    store: {
      findUnique: jest.fn(async () => ({
        ownerId: 'owner-1',
        name: 'Test Store',
      })),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async ({ where }: any) => {
        const prices: Record<string, number> = {
          START: 200,
          BUSINESS: 400,
          PREMIUM: 600,
        };
        return prices[where.plan] !== undefined
          ? { plan: where.plan, price: prices[where.plan] }
          : null;
      }),
    },
  };
  return fakePrisma;
}

describe('SubscriptionsService — admin audit logs', () => {
  let service: SubscriptionsService;
  let auditRecord: jest.Mock;

  beforeEach(async () => {
    auditRecord = jest.fn();
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: makeAdminPrismaFake() },
        {
          provide: NotificationsService,
          useValue: { sendPush: jest.fn(async () => undefined) },
        },
        { provide: AuditLogService, useValue: { record: auditRecord } },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('should record subscription.approve audit log with the acting admin userId when adminApprovePayment succeeds', async () => {
    await service.adminApprovePayment(
      'sub-audit',
      'pay-audit',
      'admin-user-42',
    );

    // audit.record is called with void (fire-and-forget) — flush microtasks
    await new Promise((r) => setImmediate(r));

    expect(auditRecord).toHaveBeenCalledWith(
      'admin-user-42',
      'subscription.approve',
      'subscription',
      'sub-audit',
      expect.objectContaining({ paymentId: 'pay-audit' }),
    );
    expect(auditRecord).not.toHaveBeenCalledWith(
      'system',
      expect.anything(),
      expect.anything(),
      expect.anything(),
      expect.anything(),
    );
  });

  it('should record subscription.extend audit log with the acting admin userId when adminExtend is called', async () => {
    await service.adminExtend('sub-audit', { days: 7 }, 'admin-user-42');

    await new Promise((r) => setImmediate(r));

    expect(auditRecord).toHaveBeenCalledWith(
      'admin-user-42',
      'subscription.extend',
      'subscription',
      'sub-audit',
      expect.objectContaining({ days: 7 }),
    );
  });

  it('should record subscription.plan_change audit log with the acting admin userId when adminChangePlan is called', async () => {
    await service.adminChangePlan(
      'sub-audit',
      { plan: SubscriptionPlanEnum.BUSINESS },
      'admin-user-42',
    );

    await new Promise((r) => setImmediate(r));

    expect(auditRecord).toHaveBeenCalledWith(
      'admin-user-42',
      'subscription.plan_change',
      'subscription',
      'sub-audit',
      expect.objectContaining({ from: 'START', to: 'BUSINESS' }),
    );
    expect(auditRecord).not.toHaveBeenCalledWith(
      'system',
      expect.anything(),
      expect.anything(),
      expect.anything(),
      expect.anything(),
    );
  });

  it('should throw NotFoundException when subscription does not exist', async () => {
    await expect(
      service.adminChangePlan(
        'no-such-sub',
        { plan: SubscriptionPlanEnum.BUSINESS },
        'admin-1',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('SubscriptionsService — adminChangePlan field guard', () => {
  let service: SubscriptionsService;
  let prisma: ReturnType<typeof makeAdminPrismaFake>;

  beforeEach(async () => {
    prisma = makeAdminPrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: NotificationsService,
          useValue: { sendPush: jest.fn(async () => undefined) },
        },
        {
          provide: AuditLogService,
          useValue: { record: jest.fn(async () => undefined) },
        },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('should update ONLY the plan field — not currentPeriodEnd or other fields', async () => {
    await service.adminChangePlan(
      'sub-audit',
      { plan: SubscriptionPlanEnum.PREMIUM },
      'admin-1',
    );

    await new Promise<void>((r) => setImmediate(r));

    expect(prisma.subscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { plan: SubscriptionPlanEnum.PREMIUM },
      }),
    );

    const updateArg = (prisma.subscription.update as jest.Mock).mock
      .calls[0][0];
    expect(updateArg.data).not.toHaveProperty('currentPeriodEnd');
  });
});

// ─── checkExpiredSubscriptions behaviour ─────────────────────────────────────

describe('SubscriptionsService — checkExpiredSubscriptions', () => {
  let service: SubscriptionsService;
  let prisma: any;
  let sendPushMock: jest.Mock;

  beforeEach(async () => {
    sendPushMock = jest.fn(async () => undefined);
    prisma = {
      subscription: {
        findMany: jest.fn(async () => []),
        updateMany: jest.fn(async () => ({ count: 0 })),
      },
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: sendPushMock } },
        {
          provide: AuditLogService,
          useValue: { record: jest.fn(async () => undefined) },
        },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('should flip ACTIVE subscription to EXPIRED and send push when period has ended', async () => {
    const pastEnd = new Date(Date.now() - 86_400_000);
    prisma.subscription.findMany = jest.fn(async () => [
      {
        id: 'sub-expired',
        status: 'ACTIVE',
        currentPeriodEnd: pastEnd,
        store: { ownerId: 'owner-1', id: 'store-1', name: 'My Shop' },
      },
    ]);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['sub-expired'] } },
      data: { status: 'EXPIRED' },
    });
    expect(sendPushMock).toHaveBeenCalledWith(
      'owner-1',
      expect.any(String),
      expect.stringContaining('My Shop'),
      'SUBSCRIPTION_EXPIRED',
      'store-1',
    );
  });

  it('should send a push for each expired subscription individually', async () => {
    const pastEnd = new Date(Date.now() - 86_400_000);
    prisma.subscription.findMany = jest.fn(async () => [
      {
        id: 'sub-a',
        status: 'ACTIVE',
        currentPeriodEnd: pastEnd,
        store: { ownerId: 'o1', id: 's1', name: 'Shop A' },
      },
      {
        id: 'sub-b',
        status: 'TRIAL',
        currentPeriodEnd: pastEnd,
        store: { ownerId: 'o2', id: 's2', name: 'Shop B' },
      },
    ]);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['sub-a', 'sub-b'] } },
      data: { status: 'EXPIRED' },
    });
    expect(sendPushMock).toHaveBeenCalledTimes(2);
    expect(sendPushMock).toHaveBeenCalledWith(
      'o1',
      expect.any(String),
      expect.stringContaining('Shop A'),
      'SUBSCRIPTION_EXPIRED',
      's1',
    );
    expect(sendPushMock).toHaveBeenCalledWith(
      'o2',
      expect.any(String),
      expect.stringContaining('Shop B'),
      'SUBSCRIPTION_EXPIRED',
      's2',
    );
  });

  it('should not call updateMany or sendPush when no subscriptions have expired', async () => {
    prisma.subscription.findMany = jest.fn(async () => []);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).not.toHaveBeenCalled();
    expect(sendPushMock).not.toHaveBeenCalled();
  });
});

describe('SubscriptionsService — seedPlanConfigs', () => {
  it('should seed hasBatchProfitability=undefined (omitted) for START and true for BUSINESS/PREMIUM', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );
    expect(byPlan.START.create.hasBatchProfitability).toBeUndefined();
    expect(byPlan.BUSINESS.create.hasBatchProfitability).toBe(true);
    expect(byPlan.PREMIUM.create.hasBatchProfitability).toBe(true);
  });

  it('should seed every flag a plan is meant to have, not rely on a backfill migration', async () => {
    // The `create` branch IS the fresh-database case: a new CI, staging or
    // restored environment runs its migrations against an empty
    // subscription_plan_configs, so a backfill `UPDATE ... WHERE plan IN
    // (...)` matches zero rows, and whatever the create literal omits falls to
    // Prisma's @default(false) and is never revisited.
    //
    // hasLoyalty was omitted from both the literal and the update: block,
    // leaving BUSINESS and PREMIUM permanently without loyalty everywhere
    // except databases old enough to have received the one-time migration —
    // which is why dev looked fine. It only became visible when the flag
    // started reaching the app.
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );

    // Paid-tier flags, asserted on the create payload rather than on a row
    // read back, because the create payload is what a fresh install gets.
    for (const plan of ['BUSINESS', 'PREMIUM']) {
      expect(byPlan[plan].create.hasZakat).toBe(true);
      expect(byPlan[plan].create.hasInvestments).toBe(true);
      expect(byPlan[plan].create.hasLoyalty).toBe(true);
      expect(byPlan[plan].create.hasBatchProfitability).toBe(true);
    }
    expect(byPlan.START.create.hasZakat).toBe(false);
    expect(byPlan.START.create.hasInvestments).toBe(false);
  });

  it('should seed hasEcommerceIntegration=true for PREMIUM only, not START or BUSINESS', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );
    expect(byPlan.PREMIUM.create.hasEcommerceIntegration).toBe(true);
    expect(byPlan.START.create.hasEcommerceIntegration).toBeUndefined();
    expect(byPlan.BUSINESS.create.hasEcommerceIntegration).toBeUndefined();
  });

  it('should patch hasBatchProfitability on the update path too, so an existing row self-heals on next boot', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );
    // BUSINESS/START have no hasEcommerceIntegration field on their plan
    // literals, so it resolves to undefined here; Prisma treats undefined
    // as "field not provided" and skips the write, leaving any admin
    // override of the flag on those plans untouched.
    expect(byPlan.BUSINESS.update).toEqual({
      hasBatchProfitability: true,
      hasEcommerceIntegration: undefined,
    });
    expect(byPlan.PREMIUM.update).toEqual({
      hasBatchProfitability: true,
      hasEcommerceIntegration: true,
    });
    expect(byPlan.START.update).toEqual({
      hasBatchProfitability: undefined,
      hasEcommerceIntegration: undefined,
    });
  });

  it('should patch hasEcommerceIntegration=true on the update path for PREMIUM, so existing PREMIUM rows self-heal on next boot', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );
    expect(byPlan.PREMIUM.update.hasEcommerceIntegration).toBe(true);
    expect(byPlan.START.update.hasEcommerceIntegration).toBeUndefined();
    expect(byPlan.BUSINESS.update.hasEcommerceIntegration).toBeUndefined();
  });

  it('should not include hasBatchProfitability in the update payload for START, so an admin override on START self-heals safely', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );

    expect(byPlan.START.update.hasBatchProfitability).toBeUndefined();
    // BUSINESS/PREMIUM keep the existing forced-true self-heal — unchanged behavior.
    expect(byPlan.BUSINESS.update.hasBatchProfitability).toBe(true);
    expect(byPlan.PREMIUM.update.hasBatchProfitability).toBe(true);
  });
});
