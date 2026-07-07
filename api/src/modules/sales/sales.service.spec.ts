import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { SalesService } from './sales.service';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { LoyaltyService } from '../loyalty/loyalty.service';

// Behavioral fake: Map-backed product/sale/saleItem stores, plus a
// transaction wrapper that just runs the callback against the same fake
// (matches Prisma's contract for our purposes — atomicity is asserted by
// state-after-failure assertions, not by mocking $transaction's rollback).
function makePrismaFake() {
  type ProductRow = {
    id: string;
    storeId: string;
    name: string;
    sellPrice: Prisma.Decimal;
    costPrice: Prisma.Decimal | null;
    quantity: number;
  };
  type SaleRow = {
    id: string;
    storeId: string;
    receiptNo: string;
    subtotal: Prisma.Decimal;
    discount: Prisma.Decimal;
    discountType: string | null;
    total: Prisma.Decimal;
    paymentType: string;
    paidAmount: Prisma.Decimal;
    change: Prisma.Decimal;
    debtAmount: Prisma.Decimal;
    customerId: string | null;
    status: string;
    items: any[];
    debtPayments: any[];
    createdAt: Date;
  };

  const products = new Map<string, ProductRow>();
  const sales = new Map<string, SaleRow>();
  const customers = new Map<string, any>();
  const stockMovements: any[] = [];
  let saleSeq = 0;
  let saleItemSeq = 0;

  const tx = {
    product: {
      findMany: jest.fn(async ({ where }: any) => {
        const ids: string[] = where.id?.in ?? [];
        return ids
          .map((id) => products.get(id))
          .filter((p): p is ProductRow => !!p && p.storeId === where.storeId);
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const p = products.get(where.id);
        if (!p) throw new Error('product not found');
        if (data.quantity?.decrement != null) {
          p.quantity -= data.quantity.decrement;
        }
        if (data.quantity?.increment != null) {
          p.quantity += data.quantity.increment;
        }
        return p;
      }),
      // F-RACE-1: sales.create now uses conditional updateMany so the
      // DB enforces stock invariants under concurrency. Mirror the
      // semantics here so the existing tests continue to pass.
      updateMany: jest.fn(async ({ where, data }: any) => {
        const p = products.get(where.id);
        if (!p) return { count: 0 };
        const need = data.quantity?.decrement ?? 0;
        if (where.quantity?.gte != null && p.quantity < where.quantity.gte) {
          return { count: 0 };
        }
        p.quantity -= need;
        return { count: 1 };
      }),
    },
    sale: {
      create: jest.fn(async ({ data }: any) => {
        const id = `sale-${++saleSeq}`;
        const items = (data.items?.create ?? []).map((it: any) => ({
          id: `si-${++saleItemSeq}`,
          saleId: id,
          ...it,
        }));
        const row: SaleRow = {
          id,
          storeId: data.storeId,
          receiptNo: data.receiptNo,
          subtotal: data.subtotal,
          discount: data.discount,
          discountType: data.discountType ?? null,
          total: data.total,
          paymentType: data.paymentType,
          paidAmount: data.paidAmount,
          change: data.change,
          debtAmount: data.debtAmount,
          customerId: data.customerId ?? null,
          status: 'COMPLETED',
          items,
          debtPayments: [],
          createdAt: new Date(),
        };
        sales.set(id, row);
        return row;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const s = sales.get(where.id);
        if (!s) throw new Error('sale not found');
        Object.assign(s, data);
        return s;
      }),
    },
    stockMovement: {
      create: jest.fn(async ({ data }: any) => {
        stockMovements.push(data);
        return data;
      }),
      createMany: jest.fn(async ({ data }: any) => {
        const rows = Array.isArray(data) ? data : [data];
        for (const r of rows) stockMovements.push(r);
        return { count: rows.length };
      }),
    },
    customer: {
      update: jest.fn(async ({ where, data }: any) => {
        const c = customers.get(where.id);
        if (c) {
          if (data.totalSpent?.increment != null) {
            c.totalSpent = new Prisma.Decimal(c.totalSpent ?? 0).add(data.totalSpent.increment).toNumber();
          }
          if (data.debt?.increment != null) {
            c.debt = new Prisma.Decimal(c.debt ?? 0).add(data.debt.increment).toNumber();
          }
        }
        return c ?? {};
      }),
      findUnique: jest.fn(async ({ where }: any) => customers.get(where.id) ?? null),
    },
    subscription: {
      findUnique: jest.fn(async () => null) as jest.Mock,
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async () => null) as jest.Mock,
    },
    loyaltySettings: {
      findUnique: jest.fn(async () => null) as jest.Mock,
    },
  };

  return {
    _products: products,
    _sales: sales,
    _customers: customers,
    _stockMovements: stockMovements,
    _tx: tx,
    customer: {
      // outer-level customer.findFirst used by SalesService to validate customerId exists
      findFirst: jest.fn(async ({ where }: any) => customers.get(where.id) ?? null),
    },
    sale: {
      findFirst: jest.fn(async ({ where }: any) => {
        const s = sales.get(where.id);
        if (!s || s.storeId !== where.storeId) return null;
        return s;
      }),
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const all = Array.from(sales.values()).filter(
          (s) => !where?.storeId || s.storeId === where.storeId,
        );
        return all.slice(skip, skip + take);
      }),
      count: jest.fn(async ({ where }: any = {}) => {
        return Array.from(sales.values()).filter(
          (s) => !where?.storeId || s.storeId === where.storeId,
        ).length;
      }),
    },
    $transaction: jest.fn(async (cb: any) => {
      // Our SalesService calls $transaction with a callback. We run it
      // against tx; state mutations are visible in `products`/`sales` maps.
      // Real Prisma rolls back on throw — we don't simulate rollback here
      // because the negative tests assert that the throw happens *before*
      // any mutation (validation phase inside the callback).
      return cb(tx);
    }),
  };
}

function fakeRedis(): Pick<RedisService, 'incr'> {
  let n = 0;
  return {
    incr: jest.fn(async (_k: string) => ++n),
  } as any;
}

describe('SalesService', () => {
  let service: SalesService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let loyaltyService: { earnPoints: jest.Mock; redeemPoints: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    loyaltyService = {
      earnPoints: jest.fn(async () => undefined),
      redeemPoints: jest.fn(async () => undefined),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        SalesService,
        { provide: PrismaService, useValue: prisma },
        { provide: RedisService, useValue: fakeRedis() },
        // D.3 — AuditLogService is fire-and-forget; tests don't care
        // about it but the DI container does.
        { provide: AuditLogService, useValue: { record: jest.fn() } },
        // F.3 — NotificationsService.sendPush is fire-and-forget.
        {
          provide: NotificationsService,
          useValue: { sendPush: jest.fn(async () => undefined) },
        },
        {
          provide: LoyaltyService,
          useValue: loyaltyService,
        },
      ],
    }).compile();
    service = moduleRef.get(SalesService);

    // Seed two products in store-A
    prisma._products.set('p1', {
      id: 'p1',
      storeId: 'store-A',
      name: 'Bread',
      sellPrice: new Prisma.Decimal('10.00'),
      costPrice: new Prisma.Decimal('6.00'),
      quantity: 100,
    });
    prisma._products.set('p2', {
      id: 'p2',
      storeId: 'store-A',
      name: 'Milk',
      sellPrice: new Prisma.Decimal('20.00'),
      costPrice: new Prisma.Decimal('15.00'),
      quantity: 5,
    });
  });

  describe('create', () => {
    it('should decrement product stock atomically when sale is created', async () => {
      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 3 }],
        paymentType: 'CASH',
        paidAmount: 30,
      } as any);

      expect(prisma._products.get('p1')!.quantity).toBe(97);
      // exactly one stock movement of type SALE
      expect(prisma._stockMovements).toHaveLength(1);
      expect(prisma._stockMovements[0].type).toBe('SALE');
    });

    it('should throw BadRequestException and not mutate stock when item exceeds available quantity', async () => {
      await expect(
        service.create('store-A', {
          items: [{ productId: 'p2', quantity: 99 }],
          paymentType: 'CASH',
          paidAmount: 1980,
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);

      // Stock unchanged because validation failed before product.update ran
      expect(prisma._products.get('p2')!.quantity).toBe(5);
    });

    it('should compute total = sum(qty*price) - sale discount when items+discount given', async () => {
      const sale = await service.create('store-A', {
        items: [
          { productId: 'p1', quantity: 2 }, // 2 * 10 = 20
          { productId: 'p2', quantity: 1 }, // 1 * 20 = 20
        ],
        discount: 5,
        discountType: 'FIXED',
        paymentType: 'CASH',
        paidAmount: 35,
      } as any);

      expect(Number(sale.subtotal)).toBe(40);
      expect(Number(sale.discount)).toBe(5);
      expect(Number(sale.total)).toBe(35);
    });

    it('should persist sale items rows linked to the sale when create succeeds', async () => {
      const sale = await service.create('store-A', {
        items: [
          { productId: 'p1', quantity: 2 },
          { productId: 'p2', quantity: 1 },
        ],
        paymentType: 'CASH',
        paidAmount: 40,
      } as any);

      expect(sale.items).toHaveLength(2);
      expect(sale.items.every((i: any) => i.saleId === sale.id)).toBe(true);
      expect(sale.items.map((i: any) => i.productId).sort()).toEqual(
        ['p1', 'p2'].sort(),
      );
    });

    it('should throw BadRequestException when items is empty', async () => {
      await expect(
        service.create('store-A', {
          items: [],
          paymentType: 'CASH',
          paidAmount: 0,
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('refund', () => {
    it('should restore stock and mark RETURNED when full refund given', async () => {
      const sale = await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 4 }],
        paymentType: 'CASH',
        paidAmount: 40,
      } as any);
      expect(prisma._products.get('p1')!.quantity).toBe(96);

      const saleItemId = sale.items[0].id;
      const refunded = await service.refund('store-A', sale.id, {
        items: [{ saleItemId, quantity: 4 }],
        reason: 'damaged',
      } as any);

      expect(refunded.status).toBe('RETURNED');
      expect(prisma._products.get('p1')!.quantity).toBe(100);
    });
  });

  describe('findAll', () => {
    it('should only return sales belonging to caller storeId when other stores have sales', async () => {
      // seed second store product
      prisma._products.set('pX', {
        id: 'pX',
        storeId: 'store-B',
        name: 'Other',
        sellPrice: new Prisma.Decimal('5'),
        costPrice: new Prisma.Decimal('3'),
        quantity: 10,
      });
      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 1 }],
        paymentType: 'CASH',
        paidAmount: 10,
      } as any);
      await service.create('store-B', {
        items: [{ productId: 'pX', quantity: 1 }],
        paymentType: 'CASH',
        paidAmount: 5,
      } as any);

      const result = await service.findAll('store-A', { skip: 0 } as any);
      expect(result.total).toBe(1);
      expect(result.data[0].storeId).toBe('store-A');
    });
  });

  // ── Helpers shared by loyalty tests ─────────────────────────────────────
  function seedCustomer(
    fake: ReturnType<typeof makePrismaFake>,
    overrides: Partial<{
      id: string;
      loyaltyPoints: number;
      totalSpent: number;
      birthday: string | null;
    }> = {},
  ) {
    const c = {
      id: 'cust-1',
      loyaltyPoints: 0,
      totalSpent: 0,
      birthday: null,
      debt: 0,
      ...overrides,
    };
    fake._customers.set(c.id, c);
    return c;
  }

  const LOYALTY_ENABLED_SETTINGS = {
    isEnabled: true,
    pointsPerAmount: 1,
    amountForPoints: new Prisma.Decimal('100'),
    pointValue: new Prisma.Decimal('0.01'),
    welcomePoints: 0,
    birthdayDiscount: null,
    pointsExpireDays: null,
  };

  describe('loyalty integration', () => {
    it('should call earnPoints when loyalty is enabled and plan has hasLoyalty', async () => {
      seedCustomer(prisma, { totalSpent: 200 });
      // Use amountForPoints=10 so a 20-TJS sale earns 2 base points
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue({
        ...LOYALTY_ENABLED_SETTINGS,
        amountForPoints: new Prisma.Decimal('10'),
      });
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'BUSINESS' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: true });

      await service.create('store-A', {
        items: [{ productId: 'p2', quantity: 1 }], // total = 20
        paymentType: 'CASH',
        paidAmount: 20,
        customerId: 'cust-1',
      } as any);

      expect(loyaltyService.earnPoints).toHaveBeenCalled();
    });

    it('should add welcomePoints on first sale when customer totalSpent was 0', async () => {
      seedCustomer(prisma, { totalSpent: 0, loyaltyPoints: 0 });
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue({
        ...LOYALTY_ENABLED_SETTINGS,
        welcomePoints: 50,
      });
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'BUSINESS' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: true });

      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 1 }], // total = 10
        paymentType: 'CASH',
        paidAmount: 10,
        customerId: 'cust-1',
      } as any);

      // base points = floor(10 / 100) * 1 = 0; welcome = 50 → total = 50
      expect(loyaltyService.earnPoints).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ points: 50 }),
      );
    });

    it('should NOT add welcomePoints on subsequent sale when customer totalSpent is non-zero', async () => {
      // totalSpent = 500 before the sale — returning customer, welcome bonus must NOT apply
      seedCustomer(prisma, { totalSpent: 500, loyaltyPoints: 0 });
      // amountForPoints = 10 so p1 (price 10) × 10 items → total = 100
      // base points = floor(100 / 10) * 1 = 10 — guarantees earnPoints IS called
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue({
        ...LOYALTY_ENABLED_SETTINGS,
        amountForPoints: new Prisma.Decimal('10'),
        pointsPerAmount: 1,
        welcomePoints: 50, // would add 50 if first sale — must NOT apply here
      });
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'BUSINESS' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: true });

      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 10 }], // 10 * 10 = 100
        paymentType: 'CASH',
        paidAmount: 100,
        customerId: 'cust-1',
      } as any);

      // earnPoints MUST be called (base = floor(100/10)*1 = 10 > 0)
      expect(loyaltyService.earnPoints).toHaveBeenCalled();
      const call = loyaltyService.earnPoints.mock.calls[0];
      // Points = 10 (base only) — NOT 60 (base + welcome bonus)
      expect(call[1].points).toBe(10);
    });

    it('should call redeemPoints when dto.redemptionPoints is provided and customer has enough points', async () => {
      seedCustomer(prisma, { loyaltyPoints: 100, totalSpent: 200 });
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue(LOYALTY_ENABLED_SETTINGS);
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'BUSINESS' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: true });

      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 1 }],
        paymentType: 'CASH',
        paidAmount: 10,
        customerId: 'cust-1',
        redemptionPoints: 30,
      } as any);

      expect(loyaltyService.redeemPoints).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ points: 30 }),
      );
    });

    it('should throw BadRequestException when redemptionPoints exceeds customer balance', async () => {
      seedCustomer(prisma, { loyaltyPoints: 10, totalSpent: 200 });
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue(LOYALTY_ENABLED_SETTINGS);
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'BUSINESS' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: true });

      await expect(
        service.create('store-A', {
          items: [{ productId: 'p1', quantity: 1 }],
          paymentType: 'CASH',
          paidAmount: 10,
          customerId: 'cust-1',
          redemptionPoints: 50,
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should NOT earn points when loyaltySettings isEnabled is false', async () => {
      seedCustomer(prisma, { totalSpent: 200 });
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue({ isEnabled: false });
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'BUSINESS' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: true });

      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 1 }],
        paymentType: 'CASH',
        paidAmount: 10,
        customerId: 'cust-1',
      } as any);

      expect(loyaltyService.earnPoints).not.toHaveBeenCalled();
    });

    it('should NOT earn points when plan config has hasLoyalty false', async () => {
      seedCustomer(prisma, { totalSpent: 200 });
      prisma._tx.loyaltySettings.findUnique.mockResolvedValue(LOYALTY_ENABLED_SETTINGS);
      prisma._tx.subscription.findUnique.mockResolvedValue({ plan: 'STARTER' });
      prisma._tx.subscriptionPlanConfig.findUnique.mockResolvedValue({ hasLoyalty: false });

      await service.create('store-A', {
        items: [{ productId: 'p1', quantity: 1 }],
        paymentType: 'CASH',
        paidAmount: 10,
        customerId: 'cust-1',
      } as any);

      expect(loyaltyService.earnPoints).not.toHaveBeenCalled();
    });
  });
});

// ─── Big-sale notification — multi-currency ───────────────────────────────

function makeUsdSaleFake() {
  const tx = {
    product: {
      findMany: jest.fn(async () => [
        {
          id: 'p-luxury',
          storeId: 'store-usd',
          name: 'Luxury Item',
          sellPrice: new Prisma.Decimal('1100'),
          costPrice: new Prisma.Decimal('900'),
          quantity: 50,
        },
      ]),
      updateMany: jest.fn(async () => ({ count: 1 })),
    },
    sale: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'sale-usd-1',
        storeId: 'store-usd',
        cashierId: 'cashier-1',
        receiptNo: data.receiptNo,
        subtotal: new Prisma.Decimal('1100'),
        discount: new Prisma.Decimal('0'),
        discountType: 'FIXED',
        total: new Prisma.Decimal('1100'),
        paymentType: 'CASH',
        paidAmount: new Prisma.Decimal('1100'),
        change: new Prisma.Decimal('0'),
        debtAmount: new Prisma.Decimal('0'),
        customerId: null,
        status: 'COMPLETED',
        createdAt: new Date(),
        items: [
          {
            id: 'si-usd-1',
            saleId: 'sale-usd-1',
            productId: 'p-luxury',
            quantity: 1,
            sellPrice: new Prisma.Decimal('1100'),
            total: new Prisma.Decimal('1100'),
          },
        ],
        debtPayments: [],
      })),
    },
    stockMovement: { createMany: jest.fn(async () => ({ count: 1 })) },
    customer: { update: jest.fn(async () => ({})), findUnique: jest.fn(async () => null) },
    subscription: { findUnique: jest.fn(async () => null) },
    subscriptionPlanConfig: { findUnique: jest.fn(async () => null) },
    loyaltySettings: { findUnique: jest.fn(async () => null) },
  };

  return {
    store: {
      findUnique: jest.fn(async () => ({
        id: 'store-usd',
        ownerId: 'owner-usd',
        name: 'USD Shop',
        currency: 'USD',
        settings: {},
      })),
    },
    $transaction: jest.fn(async (cb: (tx: any) => Promise<any>) => cb(tx)),
    sale: {
      findFirst: jest.fn(async () => null),
      findMany: jest.fn(async () => []),
      count: jest.fn(async () => 0),
    },
  };
}

describe('SalesService — big-sale notification (USD store)', () => {
  let service: SalesService;
  let sendPushMock: jest.Mock;

  beforeEach(async () => {
    sendPushMock = jest.fn(async () => undefined);
    const module = await Test.createTestingModule({
      providers: [
        SalesService,
        { provide: PrismaService, useValue: makeUsdSaleFake() },
        { provide: RedisService, useValue: fakeRedis() },
        { provide: NotificationsService, useValue: { sendPush: sendPushMock } },
        {
          provide: AuditLogService,
          useValue: { record: jest.fn(async () => undefined) },
        },
        {
          provide: LoyaltyService,
          useValue: { earnPoints: jest.fn(async () => undefined), redeemPoints: jest.fn(async () => undefined) },
        },
      ],
    }).compile();
    service = module.get(SalesService);
  });

  it('should include store currency in big-sale push body when sale total exceeds threshold', async () => {
    await service.create('store-usd', {
      items: [{ productId: 'p-luxury', quantity: 1 }],
      paymentType: 'CASH',
      paidAmount: 1100,
    } as any);

    // maybeNotifyBigSale is void — drain the async queue before asserting
    await new Promise<void>((r) => setImmediate(r));

    expect(sendPushMock).toHaveBeenCalledWith(
      'owner-usd',
      expect.any(String),
      expect.stringContaining('USD'),
      'BIG_SALE',
      'store-usd',
    );
  });
});
