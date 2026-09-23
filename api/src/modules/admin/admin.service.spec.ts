import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

// Minimal prisma fake — only the models AdminService announcement
// methods actually touch. Other AdminService methods are covered by
// dedicated spec files (admin.payments.spec.ts, etc.).
function makePrismaFake() {
  return {
    store: {
      findMany: jest.fn(async () => [] as any[]),
    },
    announcement: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'a-generated',
        ...data,
      })),
      findMany: jest.fn(async () => [] as any[]),
      count: jest.fn(async () => 0),
    },
    user: {
      findMany: jest.fn(async () => [] as any[]),
    },
  };
}

describe('AdminService — announcements (Spec C)', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendPush: jest.fn(async () => undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('preview audienceCount matches createAnnouncement recipientCount', async () => {
    const fakeStores = [
      {
        id: 's1',
        name: 'Store 1',
        currency: 'TJS',
        ownerId: 'u1',
        owner: { id: 'u1', name: 'Алишер', phone: '+992900000001' },
        subscription: {
          plan: 'BUSINESS',
          currentPeriodEnd: new Date('2026-06-01'),
        },
      },
      {
        id: 's2',
        name: 'Store 2',
        currency: 'TJS',
        ownerId: 'u2',
        owner: { id: 'u2', name: 'Зарина', phone: '+992900000002' },
        subscription: {
          plan: 'BUSINESS',
          currentPeriodEnd: new Date('2026-06-01'),
        },
      },
    ];
    (prisma.store.findMany as jest.Mock).mockResolvedValue(fakeStores);
    (prisma.announcement.create as jest.Mock).mockResolvedValue({ id: 'a1' });

    const dto = {
      title: 'Hi {{user.name}}',
      body: 'Plan {{store.subscription.plan}}',
      targetPlan: 'BUSINESS' as const,
    };

    const preview = await service.previewAnnouncement(dto as any);
    const created = await service.createAnnouncement(dto as any, 'admin-1');

    expect(preview.audienceCount).toBe(2);
    expect((created as any).id).toBe('a1');
    const createCall = (prisma.announcement.create as jest.Mock).mock
      .calls[0][0];
    expect(createCall.data.recipientCount).toBe(preview.audienceCount);
  });

  it('createAnnouncement renders title per user (different names)', async () => {
    const fakeStores = [
      {
        id: 's1',
        name: 'Store 1',
        currency: 'TJS',
        ownerId: 'u1',
        owner: { id: 'u1', name: 'Алишер', phone: '+992900000001' },
        subscription: {
          plan: 'BUSINESS',
          currentPeriodEnd: new Date('2026-06-01'),
        },
      },
      {
        id: 's2',
        name: 'Store 2',
        currency: 'TJS',
        ownerId: 'u2',
        owner: { id: 'u2', name: 'Зарина', phone: '+992900000002' },
        subscription: {
          plan: 'BUSINESS',
          currentPeriodEnd: new Date('2026-06-01'),
        },
      },
    ];
    (prisma.store.findMany as jest.Mock).mockResolvedValue(fakeStores);
    (prisma.announcement.create as jest.Mock).mockResolvedValue({ id: 'a1' });

    const sendPushSpy = notifications.sendPush;
    sendPushSpy.mockClear();

    await service.createAnnouncement(
      {
        title: 'Hi {{user.name}}',
        body: 'Hello',
        targetPlan: 'BUSINESS' as const,
      } as any,
      'admin-1',
    );

    expect(sendPushSpy).toHaveBeenCalledTimes(2);
    // sendPush(userId, title, body, type, storeId)
    expect(sendPushSpy.mock.calls[0][0]).toBe('u1');
    expect(sendPushSpy.mock.calls[0][1]).toBe('Hi Алишер');
    expect(sendPushSpy.mock.calls[1][0]).toBe('u2');
    expect(sendPushSpy.mock.calls[1][1]).toBe('Hi Зарина');
  });

  it('preview returns sample with fake vars when audience is empty', async () => {
    (prisma.store.findMany as jest.Mock).mockResolvedValue([]);

    const preview = await service.previewAnnouncement({
      title: 'Hello {{user.name}}',
      body: 'plan {{store.subscription.plan}}',
      targetPlan: 'PREMIUM' as const,
    } as any);

    expect(preview.audienceCount).toBe(0);
    expect(preview.renderedTitle).toBe('Hello Имя');
    expect(preview.renderedBody).toBe('plan START');
  });
});

describe('AdminService — updatePlan', () => {
  let service: AdminService;
  let prisma: {
    subscriptionPlanConfig: { findUnique: jest.Mock; update: jest.Mock };
  };

  beforeEach(async () => {
    prisma = {
      subscriptionPlanConfig: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('updates hasEcommerceIntegration when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan(
      'PREMIUM' as any,
      {
        hasEcommerceIntegration: true,
      } as any,
    );

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasEcommerceIntegration: true },
    });
    expect((result as any).hasEcommerceIntegration).toBe(true);
  });

  it('updates hasZakat when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan(
      'PREMIUM' as any,
      {
        hasZakat: true,
      } as any,
    );

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasZakat: true },
    });
    expect((result as any).hasZakat).toBe(true);
  });

  it('updates hasInvestments when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan(
      'PREMIUM' as any,
      {
        hasInvestments: true,
      } as any,
    );

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasInvestments: true },
    });
    expect((result as any).hasInvestments).toBe(true);
  });

  it('updates hasLoyalty when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan(
      'PREMIUM' as any,
      {
        hasLoyalty: true,
      } as any,
    );

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasLoyalty: true },
    });
    expect((result as any).hasLoyalty).toBe(true);
  });

  it('updates hasBatchProfitability when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan(
      'PREMIUM' as any,
      {
        hasBatchProfitability: true,
      } as any,
    );

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasBatchProfitability: true },
    });
    expect((result as any).hasBatchProfitability).toBe(true);
  });
});

describe('AdminService — listAnnouncements attaches senderName', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('resolves sentBy to the sending admin\'s name via a batch lookup', async () => {
    prisma.announcement.findMany.mockResolvedValueOnce([
      {
        id: 'ann1',
        title: 'Hello',
        body: 'World',
        targetPlan: null,
        targetStatus: null,
        sentBy: 'admin-1',
        recipientCount: 5,
        createdAt: new Date('2026-04-01T00:00:00Z'),
      },
    ]);
    prisma.announcement.count.mockResolvedValueOnce(1);
    prisma.user.findMany.mockResolvedValueOnce([
      { id: 'admin-1', name: 'Алишер Админ' },
    ]);

    const result = await service.listAnnouncements({
      page: 1,
      limit: 20,
    } as any);

    expect(result.data[0].senderName).toBe('Алишер Админ');
    expect(prisma.user.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['admin-1'] } },
      select: { id: true, name: true },
    });
  });

  it('falls back to null senderName when the sending admin no longer exists', async () => {
    prisma.announcement.findMany.mockResolvedValueOnce([
      {
        id: 'ann1',
        title: 'Hello',
        body: 'World',
        targetPlan: null,
        targetStatus: null,
        sentBy: 'deleted-admin',
        recipientCount: 0,
        createdAt: new Date('2026-04-01T00:00:00Z'),
      },
    ]);
    prisma.announcement.count.mockResolvedValueOnce(1);
    prisma.user.findMany.mockResolvedValueOnce([]);

    const result = await service.listAnnouncements({
      page: 1,
      limit: 20,
    } as any);

    expect(result.data[0].senderName).toBeNull();
  });
});
