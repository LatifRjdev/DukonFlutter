import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

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
