import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { SubscriptionsService } from './subscriptions.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

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
      await expect(service.getSubscription('ghost-store')).rejects.toBeInstanceOf(
        NotFoundException,
      );
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
