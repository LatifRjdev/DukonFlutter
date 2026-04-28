import { Test } from '@nestjs/testing';
import { NotFoundException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../../prisma/prisma.service';

// Mock firebase-admin so the service treats FCM as enabled in tests, and
// we can assert the dispatch shape (call args, multicast tokens, payload).
const sendEachForMulticast = jest.fn();
const messaging = jest.fn(() => ({ sendEachForMulticast }));
const cert = jest.fn(() => ({}));
const initializeApp = jest.fn(() => ({ name: 'test-app' }));
const adminApps: any[] = [];

jest.mock(
  'firebase-admin',
  () => ({
    get apps() {
      return adminApps;
    },
    credential: { cert },
    initializeApp,
    messaging,
  }),
  { virtual: true },
);

type NotificationRow = {
  id: string;
  storeId: string;
  userId: string;
  type: string;
  title: string;
  body: string;
  read: boolean;
  createdAt: Date;
};

type FcmTokenRow = { id: string; userId: string; token: string; platform: string };

type StoreRow = { id: string; settings: Record<string, unknown> };

function makePrismaFake() {
  const notifications = new Map<string, NotificationRow>();
  const fcmTokens = new Map<string, FcmTokenRow>();
  const stores = new Map<string, StoreRow>();
  let nSeq = 0;
  let tSeq = 0;

  const notification = {
    create: jest.fn(async ({ data }: any) => {
      const id = `notif-${++nSeq}`;
      const row: NotificationRow = {
        id,
        storeId: data.storeId,
        userId: data.userId,
        type: data.type,
        title: data.title,
        body: data.body,
        read: false,
        createdAt: new Date(),
      };
      notifications.set(id, row);
      return row;
    }),
    findFirst: jest.fn(async ({ where }: any) => {
      for (const n of notifications.values()) {
        if (where.id && n.id !== where.id) continue;
        if (where.storeId && n.storeId !== where.storeId) continue;
        return n;
      }
      return null;
    }),
    findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any) => {
      const list = Array.from(notifications.values())
        .filter(
          (n) => n.storeId === where.storeId && n.userId === where.userId,
        )
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      return list.slice(skip, skip + take);
    }),
    count: jest.fn(async ({ where }: any) => {
      return Array.from(notifications.values()).filter(
        (n) => n.storeId === where.storeId && n.userId === where.userId,
      ).length;
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const n = notifications.get(where.id);
      if (!n) throw new Error('Not found');
      Object.assign(n, data);
      return n;
    }),
  };

  const fcmToken = {
    findMany: jest.fn(async ({ where }: any) => {
      return Array.from(fcmTokens.values())
        .filter((t) => t.userId === where.userId)
        .map((t) => ({ token: t.token }));
    }),
    upsert: jest.fn(async ({ where, update, create }: any) => {
      // find by token
      let existing: FcmTokenRow | undefined;
      for (const t of fcmTokens.values()) {
        if (t.token === where.token) {
          existing = t;
          break;
        }
      }
      if (existing) {
        Object.assign(existing, update);
        return existing;
      }
      const id = `fcm-${++tSeq}`;
      const row: FcmTokenRow = {
        id,
        userId: create.userId,
        token: create.token,
        platform: create.platform,
      };
      fcmTokens.set(id, row);
      return row;
    }),
    deleteMany: jest.fn(async ({ where }: any) => {
      let count = 0;
      for (const [k, v] of fcmTokens.entries()) {
        if (where.token?.in && where.token.in.includes(v.token)) {
          fcmTokens.delete(k);
          count++;
        }
      }
      return { count };
    }),
  };

  const store = {
    findUnique: jest.fn(async ({ where }: any) => stores.get(where.id) ?? null),
    update: jest.fn(async ({ where, data }: any) => {
      const s = stores.get(where.id);
      if (!s) throw new Error('Not found');
      Object.assign(s, data);
      return s;
    }),
  };

  return {
    notification,
    fcmToken,
    store,
    __notifications: notifications,
    __fcmTokens: fcmTokens,
    __stores: stores,
  } as any;
}

function makeConfig(values: Record<string, string | undefined>) {
  return {
    get: jest.fn((key: string) => values[key]),
  } as unknown as ConfigService;
}

describe('NotificationsService', () => {
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(() => {
    jest.clearAllMocks();
    sendEachForMulticast.mockReset();
    initializeApp.mockClear();
    adminApps.length = 0;
    prisma = makePrismaFake();
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'debug').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  async function buildService(
    configValues: Record<string, string | undefined> = {
      FIREBASE_SERVICE_ACCOUNT: JSON.stringify({ project_id: 'fake-proj' }),
    },
  ) {
    const moduleRef = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: ConfigService, useValue: makeConfig(configValues) },
      ],
    }).compile();
    return moduleRef.get(NotificationsService);
  }

  describe('sendPush — persistence + FCM dispatch shape', () => {
    it('should persist a Notification row with title, body, type, storeId, userId when called', async () => {
      sendEachForMulticast.mockResolvedValue({
        successCount: 0,
        responses: [],
      });
      const service = await buildService();

      await service.sendPush(
        'user-1',
        'Low stock',
        'Coca Cola < 5',
        'LOW_STOCK',
        'store-A',
      );

      expect(prisma.__notifications.size).toBe(1);
      const row = Array.from(prisma.__notifications.values())[0];
      expect(row).toMatchObject({
        userId: 'user-1',
        title: 'Low stock',
        body: 'Coca Cola < 5',
        type: 'LOW_STOCK',
        storeId: 'store-A',
        read: false,
      });
    });

    it('should dispatch multicast with the user FCM tokens and payload referencing the persisted notification id', async () => {
      sendEachForMulticast.mockResolvedValue({
        successCount: 2,
        responses: [{ success: true }, { success: true }],
      });
      const service = await buildService();
      await service.saveFcmToken('user-1', 'token-AAA', 'ANDROID');
      await service.saveFcmToken('user-1', 'token-BBB', 'IOS');

      await service.sendPush(
        'user-1',
        'Hi',
        'Body',
        'NEW_SALE',
        'store-A',
      );

      expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
      const call = sendEachForMulticast.mock.calls[0][0];
      expect(call.tokens.sort()).toEqual(['token-AAA', 'token-BBB']);
      expect(call.notification).toEqual({ title: 'Hi', body: 'Body' });
      expect(call.data.type).toBe('NEW_SALE');
      expect(call.data.storeId).toBe('store-A');
      // notificationId in payload matches the persisted row
      const persisted = Array.from(prisma.__notifications.values())[0];
      expect(call.data.notificationId).toBe(persisted.id);
    });

    it('should NOT dispatch a second time for the same notification id (idempotent per call)', async () => {
      sendEachForMulticast.mockResolvedValue({
        successCount: 1,
        responses: [{ success: true }],
      });
      const service = await buildService();
      await service.saveFcmToken('user-1', 'token-AAA', 'ANDROID');

      await service.sendPush('user-1', 'A', 'B', 'NEW_SALE', 'store-A');
      const firstId = Array.from(prisma.__notifications.values())[0].id;
      const firstCallNotifId =
        sendEachForMulticast.mock.calls[0][0].data.notificationId;
      expect(firstCallNotifId).toBe(firstId);

      // Second call creates a *new* notification row with a *different* id —
      // and crucially the previously-dispatched id is never reused.
      await service.sendPush('user-1', 'A', 'B', 'NEW_SALE', 'store-A');
      const secondCallNotifId =
        sendEachForMulticast.mock.calls[1][0].data.notificationId;
      expect(secondCallNotifId).not.toBe(firstCallNotifId);
      expect(prisma.__notifications.size).toBe(2);
    });

    it('should skip multicast (and not throw) when FCM is disabled because FIREBASE_SERVICE_ACCOUNT is missing', async () => {
      const service = await buildService({ FIREBASE_SERVICE_ACCOUNT: undefined });

      await expect(
        service.sendPush('u', 't', 'b', 'NEW_SALE', 'store-A'),
      ).resolves.toBeUndefined();

      expect(sendEachForMulticast).not.toHaveBeenCalled();
      // Persistence still happened
      expect(prisma.__notifications.size).toBe(1);
    });

    it('should remove stale tokens that FCM rejects with registration-token-not-registered', async () => {
      const service = await buildService();
      await service.saveFcmToken('user-1', 'good-token', 'ANDROID');
      await service.saveFcmToken('user-1', 'stale-token', 'IOS');

      sendEachForMulticast.mockImplementation(async ({ tokens }: any) => ({
        successCount: 1,
        responses: tokens.map((t: string) =>
          t === 'stale-token'
            ? {
                success: false,
                error: {
                  code: 'messaging/registration-token-not-registered',
                },
              }
            : { success: true },
        ),
      }));

      await service.sendPush(
        'user-1',
        'Hi',
        'Body',
        'NEW_SALE',
        'store-A',
      );

      const remaining = Array.from(prisma.__fcmTokens.values()).map(
        (t) => t.token,
      );
      expect(remaining).toEqual(['good-token']);
    });
  });

  describe('markAsRead — storeId scoping', () => {
    it('should throw NotFoundException when notification belongs to another store', async () => {
      const service = await buildService();
      sendEachForMulticast.mockResolvedValue({ successCount: 0, responses: [] });

      await service.sendPush('u', 't', 'b', 'NEW_SALE', 'store-A');
      const id = Array.from(prisma.__notifications.values())[0].id;

      await expect(
        service.markAsRead('store-OTHER', id),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should set read=true when notification belongs to the calling store', async () => {
      const service = await buildService();
      sendEachForMulticast.mockResolvedValue({ successCount: 0, responses: [] });

      await service.sendPush('u', 't', 'b', 'NEW_SALE', 'store-A');
      const id = Array.from(prisma.__notifications.values())[0].id;

      await service.markAsRead('store-A', id);
      expect(prisma.__notifications.get(id)!.read).toBe(true);
    });
  });
});
