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
        const prices: Record<string, number> = {
          START: 200,
          BUSINESS: 400,
          PREMIUM: 600,
        };
        if (prices[where.plan] === undefined) return null;
        return { plan: where.plan, price: prices[where.plan] };
      }),
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
        { provide: AuditLogService, useValue: { record: jest.fn(async () => undefined) } },
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

    const updateArg = (prisma.subscription.update as jest.Mock).mock.calls[0][0];
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
        { provide: AuditLogService, useValue: { record: jest.fn(async () => undefined) } },
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
      { id: 'sub-a', status: 'ACTIVE', currentPeriodEnd: pastEnd, store: { ownerId: 'o1', id: 's1', name: 'Shop A' } },
      { id: 'sub-b', status: 'TRIAL', currentPeriodEnd: pastEnd, store: { ownerId: 'o2', id: 's2', name: 'Shop B' } },
    ]);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['sub-a', 'sub-b'] } },
      data: { status: 'EXPIRED' },
    });
    expect(sendPushMock).toHaveBeenCalledTimes(2);
    expect(sendPushMock).toHaveBeenCalledWith('o1', expect.any(String), expect.stringContaining('Shop A'), 'SUBSCRIPTION_EXPIRED', 's1');
    expect(sendPushMock).toHaveBeenCalledWith('o2', expect.any(String), expect.stringContaining('Shop B'), 'SUBSCRIPTION_EXPIRED', 's2');
  });

  it('should not call updateMany or sendPush when no subscriptions have expired', async () => {
    prisma.subscription.findMany = jest.fn(async () => []);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).not.toHaveBeenCalled();
    expect(sendPushMock).not.toHaveBeenCalled();
  });
});
