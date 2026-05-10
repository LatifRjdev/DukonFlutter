import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import {
  BadRequestException,
  ExecutionContext,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AdminGuard } from '../../common/guards/admin.guard';

// Behavioral fake covering admin payment flows. Keeps tx history so we can
// assert idempotency (approving twice should NOT extend twice) by counting
// successful subscription updates.
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
  };
  type Pay = {
    id: string;
    subscriptionId: string;
    amount: number;
    currency: string;
    method: string;
    status:
      | 'PENDING'
      | 'APPROVED'
      | 'REJECTED'
      | 'COMPLETED'
      | 'FAILED'
      | 'REFUNDED';
    note: string | null;
    rejectionReason: string | null;
    receiptImage: string | null;
    reviewedAt: Date | null;
    reviewedBy: string | null;
    createdAt: Date;
  };

  const subsById = new Map<string, Sub>();
  const payments = new Map<string, Pay>();
  const stores = new Map<string, { ownerId: string; name: string }>();
  const subscriptionUpdateCalls: any[] = [];
  const paymentUpdateCalls: any[] = [];

  return {
    _subsById: subsById,
    _payments: payments,
    _stores: stores,
    _subscriptionUpdateCalls: subscriptionUpdateCalls,
    _paymentUpdateCalls: paymentUpdateCalls,
    subscription: {
      findUnique: jest.fn(async ({ where, include }: any = {}) => {
        const sub = subsById.get(where.id);
        if (!sub) return null;
        if (include?.payments) {
          const filterId = include.payments.where?.id;
          const matched = Array.from(payments.values()).filter(
            (p) =>
              p.subscriptionId === sub.id && (!filterId || p.id === filterId),
          );
          return { ...sub, payments: matched };
        }
        return { ...sub };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const sub = subsById.get(where.id);
        if (!sub) throw new Error('not found');
        Object.assign(sub, data);
        subscriptionUpdateCalls.push({ where, data });
        return { ...sub };
      }),
    },
    payment: {
      findMany: jest.fn(async ({ where }: any = {}) => {
        return Array.from(payments.values()).filter((p) => {
          if (where?.status && p.status !== where.status) return false;
          return true;
        });
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const p = payments.get(where.id);
        if (!p) throw new Error('not found');
        Object.assign(p, data);
        paymentUpdateCalls.push({ where, data });
        return { ...p };
      }),
    },
    store: {
      findUnique: jest.fn(async ({ where }: any) => {
        const s = stores.get(where.id);
        if (!s) return null;
        return { ...s };
      }),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async () => null),
    },
    $transaction: jest.fn(async (ops: any[]) => {
      // Service uses prisma.$transaction([...promises]) form. Promises are
      // already executing — just await them.
      return Promise.all(ops);
    }),
  };
}

describe('Admin payments flow', () => {
  let service: SubscriptionsService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock };

  const seedSub = (overrides: Partial<any> = {}) => {
    const now = new Date('2026-04-27T00:00:00Z');
    const periodEnd = new Date('2026-05-27T00:00:00Z');
    const sub = {
      id: 'sub-1',
      storeId: 'store-A',
      plan: 'START',
      status: 'TRIAL',
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      adminDiscount: null,
      createdAt: now,
      updatedAt: now,
      ...overrides,
    };
    prisma._subsById.set(sub.id, sub);
    prisma._stores.set(sub.storeId, {
      ownerId: 'owner-1',
      name: 'My Store',
    });
    return sub;
  };

  const seedPayment = (overrides: Partial<any> = {}) => {
    const p = {
      id: 'pay-1',
      subscriptionId: 'sub-1',
      amount: 400,
      currency: 'TJS',
      method: 'CARD',
      status: 'PENDING' as const,
      note: 'Plan change request to BUSINESS',
      // F2.5: separate column for rejection reason; defaults to null
      // until the admin actually rejects.
      rejectionReason: null as string | null,
      receiptImage: 'uploads/receipts/x.png',
      reviewedAt: null,
      reviewedBy: null,
      createdAt: new Date(),
      ...overrides,
    };
    prisma._payments.set(p.id, p);
    return p;
  };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendPush: jest.fn(async () => undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  describe('AdminGuard', () => {
    it('should allow request when user.isAdmin is true', () => {
      const guard = new AdminGuard();
      const ctx = {
        switchToHttp: () => ({
          getRequest: () => ({ user: { isAdmin: true, id: 'u1' } }),
        }),
      } as unknown as ExecutionContext;
      expect(guard.canActivate(ctx)).toBe(true);
    });

    it('should throw ForbiddenException when user is not admin', () => {
      const guard = new AdminGuard();
      const ctx = {
        switchToHttp: () => ({
          getRequest: () => ({ user: { isAdmin: false, id: 'u1' } }),
        }),
      } as unknown as ExecutionContext;
      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });
  });

  describe('adminApprovePayment', () => {
    it('should extend currentPeriodEnd by 30 days and activate subscription when approving a pending payment', async () => {
      const sub = seedSub({ status: 'TRIAL' });
      seedPayment({ status: 'PENDING' });
      const originalEnd = sub.currentPeriodEnd;

      const { subscription, payment } = await service.adminApprovePayment(
        'sub-1',
        'pay-1',
        'admin-1',
      );

      expect(payment.status).toBe('APPROVED');
      expect(subscription.status).toBe('ACTIVE');
      expect(subscription.plan).toBe('BUSINESS'); // parsed from note
      // Extended ~30 days from original end (which was in the future)
      const diffDays = Math.round(
        (subscription.currentPeriodEnd.getTime() - originalEnd.getTime()) /
          (1000 * 60 * 60 * 24),
      );
      expect(diffDays).toBe(30);
    });

    it('should be idempotent when adminApprovePayment is invoked twice on the same payment', async () => {
      seedSub({ status: 'TRIAL' });
      seedPayment({ status: 'PENDING' });

      await service.adminApprovePayment('sub-1', 'pay-1', 'admin-1');
      const firstEnd = prisma._subsById.get('sub-1')!.currentPeriodEnd;
      const firstReviewedAt = prisma._payments.get('pay-1')!.reviewedAt;

      await service.adminApprovePayment('sub-1', 'pay-1', 'admin-1');
      const secondEnd = prisma._subsById.get('sub-1')!.currentPeriodEnd;
      const secondReviewedAt = prisma._payments.get('pay-1')!.reviewedAt;

      expect(prisma._payments.get('pay-1')!.status).toBe('APPROVED');
      expect(prisma._subsById.get('sub-1')!.status).toBe('ACTIVE');
      expect(secondEnd.getTime()).toBe(firstEnd.getTime());
      expect(secondReviewedAt).toEqual(firstReviewedAt);
    });

    it('should throw BadRequestException when approving a previously REJECTED payment', async () => {
      seedSub({ status: 'TRIAL' });
      seedPayment({ status: 'REJECTED' });

      await expect(
        service.adminApprovePayment('sub-1', 'pay-1', 'admin-1'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw NotFoundException when payment id does not belong to subscription', async () => {
      seedSub();
      // No payment seeded
      await expect(
        service.adminApprovePayment('sub-1', 'pay-missing', 'admin-1'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('adminRejectPayment', () => {
    it('should mark payment REJECTED with reason and not change subscription status when rejected', async () => {
      const sub = seedSub({ status: 'TRIAL' });
      seedPayment({ status: 'PENDING' });
      const originalStatus = sub.status;
      const originalEnd = sub.currentPeriodEnd.getTime();

      await service.adminRejectPayment(
        'sub-1',
        'pay-1',
        { reason: 'Receipt unreadable' } as any,
        'admin-1',
      );

      const p = prisma._payments.get('pay-1')!;
      expect(p.status).toBe('REJECTED');
      // F2.5: rejection reason now lives on its own column. The
      // original `note` (request audit trail) is preserved.
      expect(p.rejectionReason).toBe('Receipt unreadable');
      expect(p.note).toBe('Plan change request to BUSINESS');
      expect(prisma._subsById.get('sub-1')!.status).toBe(originalStatus);
      expect(prisma._subsById.get('sub-1')!.currentPeriodEnd.getTime()).toBe(
        originalEnd,
      );
    });
  });

  describe('adminGetPendingPayments', () => {
    it('should return only PENDING payments by default when listing', async () => {
      seedSub();
      seedPayment({ id: 'pay-pending', status: 'PENDING' });
      seedPayment({ id: 'pay-approved', status: 'APPROVED' });
      seedPayment({ id: 'pay-rejected', status: 'REJECTED' });

      const result = await service.adminGetPendingPayments();
      const ids = (result as any[]).map((p) => p.id);

      expect(ids).toContain('pay-pending');
      expect(ids).not.toContain('pay-approved');
      expect(ids).not.toContain('pay-rejected');
    });
  });
});
