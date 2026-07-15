import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { LoyaltyService, isBirthday } from './loyalty.service';
import { PrismaService } from '../../prisma/prisma.service';
import { TelegramService } from '../telegram/telegram.service';
import { NotificationsService } from '../notifications/notifications.service';

// ---------------------------------------------------------------------------
// Map-based Prisma fake
// ---------------------------------------------------------------------------
function makePrismaFake() {
  const customers = new Map<string, any>();
  const txs = new Map<string, any>();
  const settings = new Map<string, any>();
  let idSeq = 0;
  const newId = () => `id-${++idSeq}`;

  const loyaltySettings = {
    upsert: jest.fn(async ({ where, create }: any) => {
      if (!settings.has(where.storeId)) {
        settings.set(where.storeId, { ...create });
      }
      return settings.get(where.storeId);
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const s = settings.get(where.storeId);
      if (!s) throw new Error('not found');
      Object.assign(s, data);
      return s;
    }),
    findUnique: jest.fn(
      async ({ where }: any) => settings.get(where.storeId) ?? null,
    ),
    findMany: jest.fn(async ({ where, select }: any = {}) => {
      let results = Array.from(settings.values()).filter((s) => {
        if (where?.isEnabled !== undefined && s.isEnabled !== where.isEnabled)
          return false;
        if (
          where?.birthdayDiscount?.not === null &&
          s.birthdayDiscount == null
        )
          return false;
        return true;
      });
      if (select) {
        results = results.map((s) => {
          const out: any = {};
          for (const k of Object.keys(select)) {
            if (select[k]) out[k] = s[k];
          }
          return out;
        });
      }
      return results;
    }),
  };

  const customer = {
    findFirst: jest.fn(async ({ where }: any) => {
      for (const c of customers.values()) {
        if (where.id && c.id !== where.id) continue;
        if (where.storeId && c.storeId !== where.storeId) continue;
        return c;
      }
      return null;
    }),
    findUnique: jest.fn(async ({ where }: any) => {
      return customers.get(where.id) ?? null;
    }),
    count: jest.fn(async ({ where }: any = {}) => {
      return Array.from(customers.values()).filter((c) => {
        if (where?.storeId && c.storeId !== where.storeId) return false;
        if (
          where?.loyaltyPoints?.gt !== undefined &&
          !(c.loyaltyPoints > where.loyaltyPoints.gt)
        )
          return false;
        return true;
      }).length;
    }),
    findMany: jest.fn(async ({ where, orderBy, take, select }: any = {}) => {
      let results = Array.from(customers.values()).filter((c) => {
        if (where?.storeId && c.storeId !== where.storeId) return false;
        if (
          where?.loyaltyPoints?.gt !== undefined &&
          !(c.loyaltyPoints > where.loyaltyPoints.gt)
        )
          return false;
        return true;
      });
      if (take !== undefined) results = results.slice(0, take);
      if (select) {
        results = results.map((c) => {
          const out: any = {};
          for (const k of Object.keys(select)) {
            if (select[k]) out[k] = c[k];
          }
          return out;
        });
      }
      return results;
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const c = customers.get(where.id);
      if (!c) throw new Error('customer not found');
      if (data.loyaltyPoints?.increment !== undefined) {
        c.loyaltyPoints += data.loyaltyPoints.increment;
      }
      if (data.loyaltyPoints?.decrement !== undefined) {
        c.loyaltyPoints -= data.loyaltyPoints.decrement;
      }
      return c;
    }),
  };

  const loyaltyTransaction = {
    aggregate: jest.fn(async () => ({ _sum: { points: null } })),
    groupBy: jest.fn(async () => []),
    create: jest.fn(async ({ data }: any) => {
      const id = data.id ?? newId();
      const row = { id, ...data, createdAt: data.createdAt ?? new Date() };
      txs.set(id, row);
      return row;
    }),
    findMany: jest.fn(async ({ where, take, orderBy }: any = {}) => {
      let results = Array.from(txs.values()).filter((t) => {
        if (where?.type && t.type !== where.type) return false;
        if (where?.customerId && t.customerId !== where.customerId)
          return false;
        if (where?.storeId && t.storeId !== where.storeId) return false;
        if (where?.sourceEarnId?.not === null && t.sourceEarnId == null)
          return false;
        if (where?.expiresAt?.lt && t.expiresAt >= where.expiresAt.lt)
          return false;
        if (where?.NOT?.id?.in && where.NOT.id.in.includes(t.id)) return false;
        return true;
      });
      if (take !== undefined) results = results.slice(0, take);
      return results;
    }),
  };

  // Self-referential api object so $transaction can call tx.loyaltyTransaction etc.
  const api: any = {
    loyaltySettings,
    customer,
    loyaltyTransaction,
    $transaction: null,
  };
  api.$transaction = jest.fn(async (cb: (tx: any) => Promise<any>) => cb(api));

  return {
    _customers: customers,
    _txs: txs,
    _settings: settings,
    ...api,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('isBirthday (pure helper)', () => {
  it('should return true when birthday day+month matches today UTC', () => {
    const today = new Date();
    const bday = new Date(
      Date.UTC(1990, today.getUTCMonth(), today.getUTCDate()),
    );
    expect(isBirthday(bday)).toBe(true);
  });

  it('should return false for a date that is not today', () => {
    const today = new Date();
    // Use a month that is definitely not today
    const otherMonth = (today.getUTCMonth() + 6) % 12;
    const bday = new Date(Date.UTC(1990, otherMonth, today.getUTCDate()));
    expect(isBirthday(bday)).toBe(false);
  });
});

describe('LoyaltyService', () => {
  let service: LoyaltyService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let sendToStoreUsers: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    sendToStoreUsers = jest.fn().mockResolvedValue(undefined);
    const moduleRef = await Test.createTestingModule({
      providers: [
        LoyaltyService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: TelegramService,
          useValue: {
            sendMessage: jest.fn().mockResolvedValue(undefined),
            getStoreChatId: jest.fn().mockResolvedValue(null),
          },
        },
        {
          provide: NotificationsService,
          useValue: { sendToStoreUsers },
        },
      ],
    }).compile();
    service = moduleRef.get(LoyaltyService);
  });

  // -------------------------------------------------------------------------
  // getSettings
  // -------------------------------------------------------------------------
  describe('getSettings', () => {
    it('should call loyaltySettings.upsert with the storeId when settings are fetched', async () => {
      await service.getSettings('store-1');
      expect(prisma.loyaltySettings.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ where: { storeId: 'store-1' } }),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getCustomerBalance
  // -------------------------------------------------------------------------
  describe('getCustomerBalance', () => {
    it('should return { points: 0, transactions: [] } when customer has 0 points and no txs', async () => {
      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        loyaltyPoints: 0,
      });

      const result = await service.getCustomerBalance('store-1', 'cust-1');

      expect(result.points).toBe(0);
      expect(result.transactions).toEqual([]);
    });
  });

  // -------------------------------------------------------------------------
  // earnPoints
  // -------------------------------------------------------------------------
  describe('earnPoints', () => {
    it('should create an EARN transaction and increment customer loyaltyPoints', async () => {
      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        loyaltyPoints: 50,
      });

      await service.earnPoints(prisma as any, {
        customerId: 'cust-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        points: 30,
        expiresAt: null,
      });

      // Customer points incremented
      expect(prisma._customers.get('cust-1').loyaltyPoints).toBe(80);

      // EARN transaction created
      const earnTxs = (Array.from(prisma._txs.values()) as any[]).filter(
        (t: any) => t.type === 'EARN',
      );
      expect(earnTxs).toHaveLength(1);
      expect(earnTxs[0].points).toBe(30);
    });

    it('should be a no-op when the points argument is 0', async () => {
      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        loyaltyPoints: 50,
      });

      await service.earnPoints(prisma as any, {
        customerId: 'cust-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        points: 0,
        expiresAt: null,
      });

      expect(prisma._customers.get('cust-1').loyaltyPoints).toBe(50);
      expect(prisma._txs.size).toBe(0);
    });

    it('should fire Telegram push to customer when telegramChatId is set', async () => {
      const fakeTelegram = {
        sendMessage: jest.fn().mockResolvedValue(undefined),
        getStoreChatId: jest.fn().mockResolvedValue(null),
      };
      const mod = await Test.createTestingModule({
        providers: [
          LoyaltyService,
          { provide: PrismaService, useValue: prisma },
          { provide: TelegramService, useValue: fakeTelegram },
          { provide: NotificationsService, useValue: { sendToStoreUsers: jest.fn() } },
        ],
      }).compile();
      const svc = mod.get(LoyaltyService);

      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        loyaltyPoints: 100,
        telegramChatId: 'tg-123',
        name: 'Alisher',
      });

      await svc.earnPoints(prisma as any, {
        customerId: 'cust-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        points: 50,
        expiresAt: null,
      });

      // Allow fire-and-forget microtasks to flush
      await Promise.resolve();

      expect(fakeTelegram.sendMessage).toHaveBeenCalledWith(
        'tg-123',
        expect.stringContaining('+50'),
      );
    });

    it('should not throw when Telegram sendMessage rejects', async () => {
      const fakeTelegram = {
        sendMessage: jest.fn().mockRejectedValue(new Error('Network error')),
        getStoreChatId: jest.fn().mockResolvedValue(null),
      };
      const mod = await Test.createTestingModule({
        providers: [
          LoyaltyService,
          { provide: PrismaService, useValue: prisma },
          { provide: TelegramService, useValue: fakeTelegram },
          { provide: NotificationsService, useValue: { sendToStoreUsers: jest.fn() } },
        ],
      }).compile();
      const svc = mod.get(LoyaltyService);

      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        loyaltyPoints: 100,
        telegramChatId: 'tg-123',
        name: 'Alisher',
      });

      await expect(
        svc.earnPoints(prisma as any, {
          customerId: 'cust-1',
          storeId: 'store-1',
          saleId: 'sale-1',
          points: 50,
          expiresAt: null,
        }),
      ).resolves.not.toThrow();
    });
  });

  // -------------------------------------------------------------------------
  // redeemPoints
  // -------------------------------------------------------------------------
  describe('redeemPoints', () => {
    it('should create a REDEEM transaction with negative points and decrement balance', async () => {
      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        loyaltyPoints: 100,
      });

      await service.redeemPoints(prisma as any, {
        customerId: 'cust-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        points: 40,
      });

      expect(prisma._customers.get('cust-1').loyaltyPoints).toBe(60);

      const redeemTxs = (Array.from(prisma._txs.values()) as any[]).filter(
        (t: any) => t.type === 'REDEEM',
      );
      expect(redeemTxs).toHaveLength(1);
      expect(redeemTxs[0].points).toBe(-40);
    });
  });

  // -------------------------------------------------------------------------
  // getAnalytics
  // -------------------------------------------------------------------------
  describe('getAnalytics', () => {
    it('should return correct aggregates for a period with mixed transaction types', async () => {
      const from = new Date('2026-07-01');
      const to = new Date('2026-07-31');

      prisma.loyaltyTransaction.aggregate
        .mockResolvedValueOnce({ _sum: { points: 500 } })
        .mockResolvedValueOnce({ _sum: { points: -200 } })
        .mockResolvedValueOnce({ _sum: { points: -50 } });

      prisma.customer.count.mockResolvedValue(12);
      prisma.customer.findMany.mockResolvedValue([
        { id: 'cust-1', name: 'Алишер', loyaltyPoints: 300 },
        { id: 'cust-2', name: 'Бобур', loyaltyPoints: 200 },
      ]);
      prisma.loyaltyTransaction.groupBy.mockResolvedValue([
        { customerId: 'cust-1', _sum: { points: 400 } },
        { customerId: 'cust-2', _sum: { points: 200 } },
      ]);
      prisma.loyaltySettings.findUnique.mockResolvedValue({ pointValue: 0.1 });

      const result = await service.getAnalytics('store-1', from, to);

      expect(result.totalEarned).toBe(500);
      expect(result.totalRedeemed).toBe(200);
      expect(result.totalExpired).toBe(50);
      expect(result.discountValue).toBeCloseTo(20);
      expect(result.activeParticipants).toBe(12);
      expect(result.topCustomers).toHaveLength(2);
      expect(result.topCustomers[0].totalEarned).toBe(400);
    });

    it('should return zero values when no transactions exist in the period', async () => {
      const from = new Date('2026-01-01');
      const to = new Date('2026-01-31');

      prisma.loyaltyTransaction.aggregate.mockResolvedValue({
        _sum: { points: null },
      });
      prisma.customer.count.mockResolvedValue(0);
      prisma.customer.findMany.mockResolvedValue([]);
      prisma.loyaltyTransaction.groupBy.mockResolvedValue([]);
      prisma.loyaltySettings.findUnique.mockResolvedValue(null);

      const result = await service.getAnalytics('store-1', from, to);

      expect(result.totalEarned).toBe(0);
      expect(result.totalRedeemed).toBe(0);
      expect(result.totalExpired).toBe(0);
      expect(result.discountValue).toBe(0);
      expect(result.activeParticipants).toBe(0);
      expect(result.topCustomers).toHaveLength(0);
    });
  });

  // -------------------------------------------------------------------------
  // expireOverduePoints
  // -------------------------------------------------------------------------
  describe('expireOverduePoints', () => {
    it(
      'should create an EXPIRE tx with sourceEarnId and decrement balance for an overdue EARN; ' +
        'return { expired: 1, customersAffected: 1 }',
      async () => {
        // Seed customer
        prisma._customers.set('cust-1', {
          id: 'cust-1',
          storeId: 'store-1',
          loyaltyPoints: 100,
        });

        // Seed overdue EARN in the txs map
        const earnTx = {
          id: 'earn-1',
          type: 'EARN',
          points: 100,
          expiresAt: new Date(Date.now() - 86400_000),
          customerId: 'cust-1',
          storeId: 'store-1',
          createdAt: new Date(),
        };
        prisma._txs.set('earn-1', earnTx);

        // Override findMany:
        // 1st call → alreadyExpired set (empty)
        // 2nd call → overdueEarns (our earn tx)
        prisma.loyaltyTransaction.findMany
          .mockResolvedValueOnce([])
          .mockResolvedValueOnce([earnTx]);

        const result = await service.expireOverduePoints();

        expect(result).toEqual({ expired: 1, customersAffected: 1 });

        // Customer balance decremented
        expect(prisma._customers.get('cust-1').loyaltyPoints).toBe(0);

        // An EXPIRE transaction was created
        const expireTxs = (Array.from(prisma._txs.values()) as any[]).filter(
          (t: any) => t.type === 'EXPIRE',
        );
        expect(expireTxs).toHaveLength(1);
        expect(expireTxs[0].sourceEarnId).toBe('earn-1');
        expect(expireTxs[0].points).toBe(-100);
      },
    );

    it('should return { expired: 0, customersAffected: 0 } when no overdue transactions exist', async () => {
      // Both calls return empty
      prisma.loyaltyTransaction.findMany
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([]);

      const result = await service.expireOverduePoints();

      expect(result).toEqual({ expired: 0, customersAffected: 0 });
    });

    it('should call sendToStoreUsers once per store after expiring points', async () => {
      prisma._customers.set('cust-1', { id: 'cust-1', storeId: 'store-1', loyaltyPoints: 100 });
      const earnTx = {
        id: 'earn-1',
        type: 'EARN',
        points: 100,
        expiresAt: new Date(Date.now() - 1000),
        customerId: 'cust-1',
        storeId: 'store-1',
        createdAt: new Date(),
      };
      prisma._txs.set('earn-1', earnTx);
      prisma.loyaltyTransaction.findMany
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([earnTx]);

      await service.expireOverduePoints();

      // Allow fire-and-forget microtasks to flush
      await Promise.resolve();

      expect(sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '⏳ Баллы истекли',
        expect.stringContaining('1'),
        'LOYALTY_EXPIRY',
      );
    });

    it('should not call sendToStoreUsers when no points expired', async () => {
      prisma.loyaltyTransaction.findMany
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([]);

      await service.expireOverduePoints();
      await Promise.resolve();

      expect(sendToStoreUsers).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // notifyLowBalanceIfNeeded
  // -------------------------------------------------------------------------
  describe('notifyLowBalanceIfNeeded', () => {
    it('should call sendToStoreUsers when customer balance is below threshold', async () => {
      prisma._customers.set('cust-low', {
        id: 'cust-low',
        storeId: 'store-1',
        name: 'Alice',
        loyaltyPoints: 30,
      });

      await service.notifyLowBalanceIfNeeded('cust-low', 'store-1');

      expect(sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '📉 Низкий баланс',
        expect.stringContaining('Alice'),
        'LOYALTY_LOW_BALANCE',
      );
    });

    it('should not call sendToStoreUsers when customer balance is at or above threshold', async () => {
      prisma._customers.set('cust-ok', {
        id: 'cust-ok',
        storeId: 'store-1',
        name: 'Bob',
        loyaltyPoints: 50,
      });

      await service.notifyLowBalanceIfNeeded('cust-ok', 'store-1');

      expect(sendToStoreUsers).not.toHaveBeenCalled();
    });

    it('should not throw when customer does not exist', async () => {
      await expect(
        service.notifyLowBalanceIfNeeded('missing-cust', 'store-1'),
      ).resolves.toBeUndefined();
      expect(sendToStoreUsers).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // sendBirthdayPushes
  // -------------------------------------------------------------------------
  describe('sendBirthdayPushes', () => {
    function todayBirthday(): Date {
      const today = new Date();
      return new Date(
        Date.UTC(1990, today.getUTCMonth(), today.getUTCDate()),
      );
    }

    function otherDayBirthday(): Date {
      const today = new Date();
      const otherMonth = (today.getUTCMonth() + 6) % 12;
      return new Date(Date.UTC(1990, otherMonth, today.getUTCDate()));
    }

    it('should call sendToStoreUsers for each customer whose birthday is today', async () => {
      prisma._settings.set('store-1', {
        storeId: 'store-1',
        isEnabled: true,
        birthdayDiscount: 10,
      });
      prisma._customers.set('cust-a', {
        id: 'cust-a',
        storeId: 'store-1',
        name: 'Alice',
        birthday: todayBirthday(),
        loyaltyPoints: 0,
      });
      prisma._customers.set('cust-b', {
        id: 'cust-b',
        storeId: 'store-1',
        name: 'Bob',
        birthday: todayBirthday(),
        loyaltyPoints: 0,
      });

      await service.sendBirthdayPushes();

      expect(sendToStoreUsers).toHaveBeenCalledTimes(2);
      expect(sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '🎂 День рождения',
        expect.stringContaining('Alice'),
        'LOYALTY_BIRTHDAY',
      );
      expect(sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '🎂 День рождения',
        expect.stringContaining('Bob'),
        'LOYALTY_BIRTHDAY',
      );
    });

    it('should not call sendToStoreUsers for customers whose birthday is not today', async () => {
      prisma._settings.set('store-2', {
        storeId: 'store-2',
        isEnabled: true,
        birthdayDiscount: 5,
      });
      prisma._customers.set('cust-c', {
        id: 'cust-c',
        storeId: 'store-2',
        name: 'Carol',
        birthday: otherDayBirthday(),
        loyaltyPoints: 0,
      });

      await service.sendBirthdayPushes();

      expect(sendToStoreUsers).not.toHaveBeenCalled();
    });

    it('should not call sendToStoreUsers for stores where loyalty is disabled', async () => {
      prisma._settings.set('store-3', {
        storeId: 'store-3',
        isEnabled: false,
        birthdayDiscount: 10,
      });
      prisma._customers.set('cust-d', {
        id: 'cust-d',
        storeId: 'store-3',
        name: 'Dave',
        birthday: todayBirthday(),
        loyaltyPoints: 0,
      });

      await service.sendBirthdayPushes();

      expect(sendToStoreUsers).not.toHaveBeenCalled();
    });
  });
});
