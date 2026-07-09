import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { LoyaltyService, isBirthday } from './loyalty.service';
import { PrismaService } from '../../prisma/prisma.service';
import { TelegramService } from '../telegram/telegram.service';

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

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        LoyaltyService,
        { provide: PrismaService, useValue: prisma },
        { provide: TelegramService, useValue: { sendMessage: jest.fn().mockResolvedValue(undefined), getStoreChatId: jest.fn().mockResolvedValue(null) } },
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
  });
});
