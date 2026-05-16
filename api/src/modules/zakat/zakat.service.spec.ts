import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { ZakatService } from './zakat.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';

// Map-backed Prisma fake. Zakat calculation now batches its 4 reads
// inside `prisma.$transaction([...])` (Z-P1-6), so the fake exposes
// `$transaction(promises)` that simply awaits the array — the order
// the service passes them in (settings, customers, suppliers,
// stockResult) is preserved by Promise.all. Inventory total is
// computed via `$queryRaw` which sums quantity * COALESCE(costPrice,
// sellPrice) for active products in the store; we mirror that SQL
// in JS so we can verify correctness end-to-end without a real DB.
function makePrismaFake() {
  type Product = {
    id: string;
    storeId: string;
    isActive: boolean;
    quantity: number;
    costPrice: number | null;
    sellPrice: number;
  };
  type Customer = { id: string; storeId: string; debt: number };
  type Supplier = { id: string; storeId: string; debt: number };
  type Settings = {
    id: string;
    storeId: string;
    nisabGold: number;
    nisabSilver: number;
    nisabCurrency: string;
    nisabAmount: number;
    haulStartDate: Date | null;
    zakatRate: number;
    includeStock: boolean;
    includeCash: boolean;
    includeDebts: boolean;
  };
  type Payment = {
    id: string;
    storeId: string;
    amount: any;
    totalAssets: any;
    zakatDue: any;
    breakdown: any;
    notes?: string | null;
    paidAt: Date;
    localId?: string | null;
  };

  const products = new Map<string, Product>();
  const customers = new Map<string, Customer>();
  const suppliers = new Map<string, Supplier>();
  const settingsByStore = new Map<string, Settings>();
  const payments = new Map<string, Payment>();
  const paymentsByLocalId = new Map<string, Payment>();
  let idSeq = 0;
  const newId = (p: string) => `${p}-${++idSeq}`;

  return {
    _products: products,
    _customers: customers,
    _suppliers: suppliers,
    _settings: settingsByStore,
    _payments: payments,
    product: {
      aggregate: jest.fn(async ({ where, _sum }: any) => {
        const matched = Array.from(products.values()).filter((p) => {
          if (where.storeId && p.storeId !== where.storeId) return false;
          if (where.isActive !== undefined && p.isActive !== where.isActive)
            return false;
          if (
            where.quantity?.gt !== undefined &&
            p.quantity <= where.quantity.gt
          )
            return false;
          return true;
        });
        const out: any = { _sum: {} };
        if (_sum?.costPrice) {
          out._sum.costPrice = matched.reduce(
            (s, m) => s + Number(m.costPrice ?? 0),
            0,
          );
        }
        if (_sum?.sellPrice) {
          out._sum.sellPrice = matched.reduce(
            (s, m) => s + Number(m.sellPrice),
            0,
          );
        }
        return out;
      }),
    },
    customer: {
      aggregate: jest.fn(async ({ where }: any) => {
        const matched = Array.from(customers.values()).filter(
          (c) =>
            c.storeId === where.storeId &&
            c.debt > (where.debt?.gt ?? -Infinity),
        );
        return { _sum: { debt: matched.reduce((s, c) => s + c.debt, 0) } };
      }),
    },
    supplier: {
      aggregate: jest.fn(async ({ where }: any) => {
        const matched = Array.from(suppliers.values()).filter(
          (s) =>
            s.storeId === where.storeId &&
            s.debt > (where.debt?.gt ?? -Infinity),
        );
        return { _sum: { debt: matched.reduce((acc, s) => acc + s.debt, 0) } };
      }),
    },
    zakatSettings: {
      findUnique: jest.fn(async ({ where }: any) => {
        return settingsByStore.get(where.storeId) ?? null;
      }),
      upsert: jest.fn(async ({ where, create, update }: any) => {
        const existing = settingsByStore.get(where.storeId);
        if (existing) {
          Object.assign(existing, update);
          return existing;
        }
        const row: Settings = {
          id: newId('zs'),
          storeId: where.storeId,
          nisabGold: 85,
          nisabSilver: 595,
          nisabCurrency: 'TJS',
          // G.2: changed from 0 → 1 because the new safer default
          // is "no zakat under nisab"; setting nisabAmount=0 in
          // these fixtures used to mean "ignore the threshold".
          // Tests that intentionally explore the "below nisab"
          // path still set nisabAmount explicitly above 1.
          nisabAmount: 1,
          haulStartDate: null,
          zakatRate: 2.5,
          includeStock: true,
          includeCash: true,
          includeDebts: true,
          ...create,
        };
        settingsByStore.set(where.storeId, row);
        return row;
      }),
    },
    zakatPayment: {
      create: jest.fn(async ({ data }: any) => {
        const id = newId('zp');
        const row: Payment = {
          id,
          storeId: data.storeId,
          amount: data.amount,
          totalAssets: data.totalAssets ?? 0,
          zakatDue: data.zakatDue ?? data.amount,
          breakdown: data.breakdown ?? {},
          notes: data.notes ?? null,
          paidAt: new Date(),
          localId: data.localId ?? null,
        };
        payments.set(id, row);
        if (row.localId)
          paymentsByLocalId.set(`${row.storeId}::${row.localId}`, row);
        return row;
      }),
      // Z-P1-1: support idempotent upsert keyed on (storeId, localId).
      upsert: jest.fn(async ({ where, create, update: _update }: any) => {
        const key = `${where.storeId_localId.storeId}::${where.storeId_localId.localId}`;
        const existing = paymentsByLocalId.get(key);
        if (existing) {
          // The service passes `update: {}` for true no-op retry semantics.
          return existing;
        }
        const id = newId('zp');
        const row: Payment = {
          id,
          storeId: create.storeId,
          amount: create.amount,
          totalAssets: create.totalAssets ?? 0,
          zakatDue: create.zakatDue ?? create.amount,
          breakdown: create.breakdown ?? {},
          notes: create.notes ?? null,
          paidAt: new Date(),
          localId: create.localId ?? null,
        };
        payments.set(id, row);
        paymentsByLocalId.set(key, row);
        return row;
      }),
      findMany: jest.fn(async ({ where }: any) =>
        Array.from(payments.values())
          .filter((p) => p.storeId === where.storeId)
          .sort((a, b) => b.paidAt.getTime() - a.paidAt.getTime()),
      ),
    },
    auditLog: {
      create: jest.fn(async () => ({ id: newId('al') })),
    },
    // Z-P1-6: service wraps reads in $transaction([...]). The real
    // PrismaClient resolves the tagged-template `$queryRaw` calls
    // eagerly into PrismaPromise objects which are then materialized
    // by $transaction. Our fake's `$queryRaw` already returns a real
    // Promise, and `aggregate` / `findUnique` likewise. So
    // $transaction is just `Promise.all`.
    $transaction: jest.fn(async (promises: Promise<any>[]) => {
      return Promise.all(promises);
    }),
    // Raw query: sum(quantity * COALESCE(costPrice, sellPrice)) for active
    // products in the store. New service shape returns the value as a
    // string under `total` (matching `::text` cast in the SQL).
    $queryRaw: jest.fn(async (strings: any, ...values: any[]) => {
      const storeId = values[0];
      const total = Array.from(products.values())
        .filter((p) => p.storeId === storeId && p.isActive && p.quantity > 0)
        .reduce(
          (sum, p) => sum + p.quantity * Number(p.costPrice ?? p.sellPrice),
          0,
        );
      return [{ total: String(total) }];
    }),
  };
}

describe('ZakatService', () => {
  let service: ZakatService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let auditMock: { record: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    auditMock = { record: jest.fn().mockResolvedValue(undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        ZakatService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditMock },
      ],
    }).compile();
    service = moduleRef.get(ZakatService);
  });

  const seedProduct = (overrides: Partial<any> = {}) => {
    const id = overrides.id ?? `p-${prisma._products.size + 1}`;
    const p = {
      id,
      storeId: 'store-A',
      isActive: true,
      quantity: 10,
      costPrice: 100,
      sellPrice: 150,
      ...overrides,
    };
    prisma._products.set(id, p as any);
    return p;
  };

  // Z-P1-6: service now returns Prisma.Decimal instances; the global
  // TransformInterceptor coerces them to JS Number on the HTTP wire,
  // but unit tests call methods directly. Helpers keep assertions
  // readable.
  const num = (v: any) => Number(v?.toString ? v.toString() : v);

  describe('calculate', () => {
    it('should compute zakat as 2.5% of net assets when nisabAmount is configured', async () => {
      // G.2: previously this test ran against the default
      // synthesized settings (nisabAmount=0). The old code defaulted
      // isAboveNisab=true for unset nisab, which religiously over-
      // triggered zakat. New default = no zakat unless nisabAmount
      // is explicitly set, so we configure it here.
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      await prisma.zakatSettings.upsert({
        where: { storeId: 'store-A' },
        update: { nisabAmount: 100 },
        create: { storeId: 'store-A', nisabAmount: 100 },
      } as any);

      const result = await service.calculate('store-A');

      expect(num(result.breakdown.inventoryValue)).toBe(1000);
      expect(num(result.totalAssets)).toBe(1000);
      expect(num(result.netAssets)).toBe(1000);
      expect(num(result.zakatRate)).toBe(2.5);
      expect(num(result.zakatDue)).toBeCloseTo(25, 6);
      expect(result.isAboveNisab).toBe(true);
    });

    it('should NOT trigger zakat by default when nisabAmount is unset (G.2 conservative default)', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      const result = await service.calculate('store-A');
      expect(num(result.netAssets)).toBe(1000);
      expect(result.isAboveNisab).toBe(false);
      expect(num(result.zakatDue)).toBe(0);
    });

    it('should subtract supplier payables from total assets when computing netAssets', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      prisma._customers.set('c1', {
        id: 'c1',
        storeId: 'store-A',
        debt: 200,
      });
      prisma._suppliers.set('s1', {
        id: 's1',
        storeId: 'store-A',
        debt: 300,
      });
      // G.2: nisabAmount must be set for zakat to compute (new
      // conservative default).
      await prisma.zakatSettings.upsert({
        where: { storeId: 'store-A' },
        update: { nisabAmount: 100 },
        create: { storeId: 'store-A', nisabAmount: 100 },
      } as any);

      const result = await service.calculate('store-A');

      // 1000 inventory + 200 receivables - 300 payables = 900
      expect(num(result.totalAssets)).toBe(1200);
      expect(num(result.netAssets)).toBe(900);
      expect(num(result.zakatDue)).toBeCloseTo(900 * 0.025, 6); // 22.5
    });

    it('should return zakatDue=0 when netAssets are below the configured nisabAmount', async () => {
      seedProduct({ quantity: 1, costPrice: 50, sellPrice: 50 });
      prisma._settings.set('store-A', {
        id: 'zs1',
        storeId: 'store-A',
        nisabGold: 85,
        nisabSilver: 595,
        nisabCurrency: 'TJS',
        nisabAmount: 1000, // above the 50 inventory value
        haulStartDate: null,
        zakatRate: 2.5,
        includeStock: true,
        includeCash: true,
        includeDebts: true,
      });

      const result = await service.calculate('store-A');

      expect(num(result.netAssets)).toBe(50);
      expect(result.isAboveNisab).toBe(false);
      expect(num(result.zakatDue)).toBe(0);
    });

    it('should not include inventory from other stores when computing assets', async () => {
      seedProduct({
        id: 'a1',
        storeId: 'store-A',
        quantity: 5,
        costPrice: 100,
      });
      seedProduct({
        id: 'b1',
        storeId: 'store-B',
        quantity: 100,
        costPrice: 9999,
      });

      const result = await service.calculate('store-A');

      expect(num(result.breakdown.inventoryValue)).toBe(500); // 5 * 100
    });

    it('should honor a custom zakatRate from settings when calculating', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 100 });
      prisma._settings.set('store-A', {
        id: 'zs1',
        storeId: 'store-A',
        nisabGold: 85,
        nisabSilver: 595,
        nisabCurrency: 'TJS',
        // G.2: nisabAmount must be set for zakat to be computed.
        nisabAmount: 100,
        haulStartDate: null,
        zakatRate: 5, // doubled from default
        includeStock: true,
        includeCash: true,
        includeDebts: true,
      });

      const result = await service.calculate('store-A');

      expect(num(result.zakatRate)).toBe(5);
      expect(num(result.zakatDue)).toBeCloseTo(50, 6); // 1000 * 5%
    });

    it('should zero out inventoryValue when settings.includeStock is false', async () => {
      seedProduct({ quantity: 10, costPrice: 100 });
      prisma._settings.set('store-A', {
        id: 'zs1',
        storeId: 'store-A',
        nisabGold: 85,
        nisabSilver: 595,
        nisabCurrency: 'TJS',
        nisabAmount: 0,
        haulStartDate: null,
        zakatRate: 2.5,
        includeStock: false,
        includeCash: true,
        includeDebts: true,
      });

      const result = await service.calculate('store-A');

      expect(num(result.breakdown.inventoryValue)).toBe(0);
      expect(num(result.totalAssets)).toBe(0);
    });
  });

  // ZC-P1-1: 354-day Hijri lunar year (haul) gate. zakatDue must
  // remain 0 until that period elapses since `haulStartDate`, and
  // the response must surface `isHaulComplete` + `haulCompletesOn`
  // so Flutter can render the "haul completes on YYYY-MM-DD" hint
  // and disable the "mark as paid" CTA.
  describe('haul (354-day) enforcement', () => {
    it('returns isHaulComplete=false + zakatDue=0 when haulStartDate < 354 days ago', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      prisma._settings.set('store-A', {
        id: 'zs1',
        storeId: 'store-A',
        nisabGold: 85,
        nisabSilver: 595,
        nisabCurrency: 'TJS',
        nisabAmount: 100,
        haulStartDate: new Date('2026-01-01'),
        zakatRate: 2.5,
        includeStock: true,
        includeCash: true,
        includeDebts: true,
      });

      // ~134 days after haulStartDate — well under the 354-day gate.
      const now = new Date('2026-05-14');
      const result = await service.calculate('store-A', now);

      expect(result.isHaulComplete).toBe(false);
      expect(num(result.zakatDue)).toBe(0);
      expect(result.haulCompletesOn).toBeInstanceOf(Date);
      // ISO date prefix is sufficient — exact ms doesn't matter.
      expect((result.haulCompletesOn as Date).toISOString().slice(0, 10)).toBe(
        '2026-12-21',
      );
    });

    it('returns isHaulComplete=true + zakatDue computed when haulStartDate >= 354 days ago', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      prisma._settings.set('store-A', {
        id: 'zs1',
        storeId: 'store-A',
        nisabGold: 85,
        nisabSilver: 595,
        nisabCurrency: 'TJS',
        nisabAmount: 100,
        haulStartDate: new Date('2024-01-01'),
        zakatRate: 2.5,
        includeStock: true,
        includeCash: true,
        includeDebts: true,
      });

      const now = new Date('2026-05-14'); // ~865 days
      const result = await service.calculate('store-A', now);

      expect(result.isHaulComplete).toBe(true);
      expect(num(result.zakatDue)).toBeGreaterThan(0);
      expect(num(result.zakatDue)).toBeCloseTo(25, 6);
    });

    it('treats unset haulStartDate as backwards-compat (isHaulComplete=true)', async () => {
      // Existing stores predating ZC-P1-1 won't have haulStartDate
      // set. We deliberately default isHaulComplete=true so the
      // feature rollout doesn't suddenly zero out zakat for them.
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      await prisma.zakatSettings.upsert({
        where: { storeId: 'store-A' },
        update: { nisabAmount: 100 },
        create: { storeId: 'store-A', nisabAmount: 100 },
      } as any);

      const result = await service.calculate('store-A');
      expect(result.isHaulComplete).toBe(true);
      expect(num(result.zakatDue)).toBeCloseTo(25, 6);
    });
  });

  describe('createPayment trust + idempotency', () => {
    const seedAboveNisab = async () => {
      // Inventory of 10 * 100 = 1000, nisab = 100, so zakatDue = 25.
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      await prisma.zakatSettings.upsert({
        where: { storeId: 'store-A' },
        update: { nisabAmount: 100 },
        create: { storeId: 'store-A', nisabAmount: 100 },
      } as any);
    };

    it('rejects when client zakatDue diverges > 0.5% from server calc', async () => {
      await seedAboveNisab();
      // Server will compute zakatDue ≈ 25; client claims 200.
      await expect(
        service.createPayment(
          'store-A',
          { amount: 200, zakatDue: 200 } as any,
          'user-42',
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('accepts when client zakatDue is within 0.5% of server calc', async () => {
      await seedAboveNisab();
      // Server: 25.00; client: 25.05 → 0.2% off, within tolerance.
      const payment = await service.createPayment(
        'store-A',
        { amount: 25.05, zakatDue: 25.05 } as any,
        'user-42',
      );
      // Server-trusted zakatDue is what we persist, NOT the client claim.
      expect(num(payment.zakatDue)).toBeCloseTo(25, 6);
    });

    it('upserts on (storeId, localId) when localId provided — idempotent retries', async () => {
      await seedAboveNisab();
      const dto = { amount: 25, zakatDue: 25, localId: 'abc-123' } as any;

      const first = await service.createPayment('store-A', dto, 'user-42');
      const second = await service.createPayment('store-A', dto, 'user-42');

      // Same row — retry was a no-op, no duplicate.
      expect(second.id).toBe(first.id);
      expect(prisma.zakatPayment.upsert).toHaveBeenCalledTimes(2);
      expect(prisma.zakatPayment.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            storeId_localId: { storeId: 'store-A', localId: 'abc-123' },
          },
        }),
      );
      // Map only ever gained one row.
      expect(prisma._payments.size).toBe(1);
    });

    it('falls through to plain create when localId is omitted (backwards compat)', async () => {
      await seedAboveNisab();
      await service.createPayment(
        'store-A',
        { amount: 25, zakatDue: 25 } as any,
        'user-42',
      );
      expect(prisma.zakatPayment.create).toHaveBeenCalledTimes(1);
      expect(prisma.zakatPayment.upsert).not.toHaveBeenCalled();
    });
  });

  describe('audit log', () => {
    it('writes zakat.payment.create audit on createPayment', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      await prisma.zakatSettings.upsert({
        where: { storeId: 'store-A' },
        update: { nisabAmount: 100 },
        create: { storeId: 'store-A', nisabAmount: 100 },
      } as any);

      await service.createPayment(
        'store-A',
        { amount: 25, zakatDue: 25 } as any,
        'user-42',
      );

      expect(auditMock.record).toHaveBeenCalledWith(
        'user-42',
        'zakat.payment.create',
        'zakat_payment',
        expect.any(String),
        expect.objectContaining({ storeId: 'store-A' }),
      );
    });

    it('writes zakat.settings.upsert audit on upsertSettings', async () => {
      await service.upsertSettings(
        'store-A',
        { nisabAmount: 500, zakatRate: 2.5 } as any,
        'user-99',
      );
      expect(auditMock.record).toHaveBeenCalledWith(
        'user-99',
        'zakat.settings.upsert',
        'zakat_settings',
        expect.any(String),
        expect.objectContaining({ storeId: 'store-A' }),
      );
    });
  });

  describe('getPayments', () => {
    it('should return only payments scoped to storeId when listing zakat history', async () => {
      prisma._payments.set('p1', {
        id: 'p1',
        storeId: 'store-A',
        amount: 100,
        totalAssets: 1000,
        zakatDue: 100,
        breakdown: {},
        paidAt: new Date('2026-01-01'),
      } as any);
      prisma._payments.set('p2', {
        id: 'p2',
        storeId: 'store-OTHER',
        amount: 9999,
        totalAssets: 1,
        zakatDue: 1,
        breakdown: {},
        paidAt: new Date(),
      } as any);

      const res = await service.getPayments('store-A');

      expect(res.length).toBe(1);
      expect(res[0].id).toBe('p1');
    });
  });
});
