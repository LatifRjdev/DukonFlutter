import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { SubscriptionsService } from './subscriptions.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { AdminManualPaymentDto } from './dto/admin-manual-payment.dto';

function makePrismaFake() {
  return {
    subscription: {
      findUnique: jest.fn(async () => null as any),
      update: jest.fn(async ({ data }: any) => ({ ...data })),
    },
    store: {
      findUnique: jest.fn(async () => null as any),
    },
    payment: {
      create: jest.fn(async ({ data }: any) => ({ id: 'pay-1', ...data })),
    },
    $transaction: jest.fn(async (ops: any[]) => Promise.all(ops)),
  };
}

describe('SubscriptionsService — adminCreateManualPayment', () => {
  let service: SubscriptionsService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock };
  let audit: { record: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendPush: jest.fn(async () => undefined) };
    audit = { record: jest.fn(async () => undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: AuditLogService, useValue: audit },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('throws NotFoundException when subscription does not exist', async () => {
    (prisma.subscription.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.adminCreateManualPayment(
        'sub-missing',
        { amount: 400, method: 'CASH', periodDays: 30 } as any,
        'admin-1',
      ),
    ).rejects.toThrow(NotFoundException);
  });

  it('extends currentPeriodEnd by periodDays from the later of now/currentPeriodEnd, and notifies the owner', async () => {
    const currentPeriodEnd = new Date('2099-01-01');
    const foundSubscription = {
      id: 'sub-1',
      storeId: 'store-1',
      currentPeriodEnd,
    };
    (prisma.subscription.findUnique as jest.Mock).mockResolvedValue(
      foundSubscription,
    );
    // Real Prisma's update() echoes back the full row (unchanged fields
    // included), not just the fields passed in `data` — replicate that here.
    (prisma.subscription.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ ...foundSubscription, ...data }),
    );
    (prisma.store.findUnique as jest.Mock).mockResolvedValue({
      ownerId: 'owner-1',
      name: 'Магазин',
    });

    const result = await service.adminCreateManualPayment(
      'sub-1',
      {
        amount: 400,
        method: 'CASH',
        periodDays: 30,
        notes: 'Наличные в офисе',
      } as any,
      'admin-1',
    );

    const expectedEnd = new Date(currentPeriodEnd);
    expectedEnd.setDate(expectedEnd.getDate() + 30);

    expect((result.subscription as any).currentPeriodEnd.getTime()).toBe(
      expectedEnd.getTime(),
    );
    expect(notifications.sendPush).toHaveBeenCalledWith(
      'owner-1',
      expect.any(String),
      expect.any(String),
      'SUBSCRIPTION_MANUAL_PAYMENT',
      'store-1',
    );
    expect(audit.record).toHaveBeenCalledWith(
      'admin-1',
      'subscription.manual-payment',
      'subscription',
      'sub-1',
      expect.objectContaining({ amount: 400, periodDays: 30 }),
    );
  });
});

describe('AdminManualPaymentDto validation', () => {
  it('passes validation for a well-formed payload', async () => {
    const dto = plainToInstance(AdminManualPaymentDto, {
      amount: 400,
      method: 'CASH',
      periodDays: 30,
      notes: 'Наличные в офисе',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('fails validation when amount exceeds the sanity ceiling (e.g. a fat-fingered extra digit)', async () => {
    const dto = plainToInstance(AdminManualPaymentDto, {
      amount: 4_000_000,
      method: 'CASH',
      periodDays: 30,
    });

    const errors = await validate(dto);

    expect(errors.some((e) => e.property === 'amount')).toBe(true);
  });

  it('fails validation when periodDays is not an integer', async () => {
    const dto = plainToInstance(AdminManualPaymentDto, {
      amount: 400,
      method: 'CASH',
      periodDays: 1.5,
    });

    const errors = await validate(dto);

    expect(errors.some((e) => e.property === 'periodDays')).toBe(true);
  });
});
