import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { ZakatService } from './zakat.service';
import { PrismaService } from '../../prisma/prisma.service';

// Map-backed Prisma fake. Zakat calculation pulls product stock value via a
// $queryRaw and customer/supplier debts via aggregate. The fake supports the
// raw query by computing sum(quantity * costPrice|sellPrice) from the in-memory
// product map so we can verify correctness end-to-end without a real DB.
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
    amount: number;
    totalAssets: number;
    zakatDue: number;
    breakdown: any;
    notes?: string | null;
    paidAt: Date;
  };

  const products = new Map<string, Product>();
  const customers = new Map<string, Customer>();
  const suppliers = new Map<string, Supplier>();
  const settingsByStore = new Map<string, Settings>();
  const payments = new Map<string, Payment>();
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
          if (where.isActive !== undefined && p.isActive !== where.isActive) return false;
          if (where.quantity?.gt !== undefined && p.quantity <= where.quantity.gt)
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
            c.storeId === where.storeId && c.debt > (where.debt?.gt ?? -Infinity),
        );
        return { _sum: { debt: matched.reduce((s, c) => s + c.debt, 0) } };
      }),
    },
    supplier: {
      aggregate: jest.fn(async ({ where }: any) => {
        const matched = Array.from(suppliers.values()).filter(
          (s) =>
            s.storeId === where.storeId && s.debt > (where.debt?.gt ?? -Infinity),
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
          nisabAmount: 0,
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
          amount: Number(data.amount),
          totalAssets: Number(data.totalAssets ?? 0),
          zakatDue: Number(data.zakatDue ?? data.amount),
          breakdown: data.breakdown ?? {},
          notes: data.notes ?? null,
          paidAt: new Date(),
        };
        payments.set(id, row);
        return row;
      }),
      findMany: jest.fn(async ({ where }: any) =>
        Array.from(payments.values())
          .filter((p) => p.storeId === where.storeId)
          .sort((a, b) => b.paidAt.getTime() - a.paidAt.getTime()),
      ),
    },
    // Raw query: sum(quantity * COALESCE(costPrice, sellPrice)) for active
    // products in the store. Match the SQL semantics exactly.
    $queryRaw: jest.fn(async (strings: any, ...values: any[]) => {
      // Service passes one parameter: storeId
      const storeId = values[0];
      const total = Array.from(products.values())
        .filter(
          (p) => p.storeId === storeId && p.isActive && p.quantity > 0,
        )
        .reduce(
          (sum, p) => sum + p.quantity * Number(p.costPrice ?? p.sellPrice),
          0,
        );
      return [{ total }];
    }),
  };
}

describe('ZakatService', () => {
  let service: ZakatService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        ZakatService,
        { provide: PrismaService, useValue: prisma },
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

  describe('calculate', () => {
    it('should compute zakat as 2.5% of net assets when settings are at default', async () => {
      // 10 * 100 = 1000 inventory, no debts → zakatDue = 1000 * 2.5% = 25
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });

      const result = await service.calculate('store-A');

      expect(result.breakdown.inventoryValue).toBe(1000);
      expect(result.totalAssets).toBe(1000);
      expect(result.netAssets).toBe(1000);
      expect(result.zakatRate).toBe(2.5);
      expect(result.zakatDue).toBeCloseTo(25, 6);
      expect(result.isAboveNisab).toBe(true);
    });

    it('should subtract supplier payables from total assets when computing netAssets', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 150 });
      // Receivables 200 (customer debt to us)
      prisma._customers.set('c1', {
        id: 'c1',
        storeId: 'store-A',
        debt: 200,
      });
      // Payables 300 (we owe supplier)
      prisma._suppliers.set('s1', {
        id: 's1',
        storeId: 'store-A',
        debt: 300,
      });

      const result = await service.calculate('store-A');

      // 1000 inventory + 200 receivables - 300 payables = 900
      expect(result.totalAssets).toBe(1200);
      expect(result.netAssets).toBe(900);
      expect(result.zakatDue).toBeCloseTo(900 * 0.025, 6); // 22.5
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

      expect(result.netAssets).toBe(50);
      expect(result.isAboveNisab).toBe(false);
      expect(result.zakatDue).toBe(0);
    });

    it('should not include inventory from other stores when computing assets', async () => {
      seedProduct({ id: 'a1', storeId: 'store-A', quantity: 5, costPrice: 100 });
      seedProduct({ id: 'b1', storeId: 'store-B', quantity: 100, costPrice: 9999 });

      const result = await service.calculate('store-A');

      expect(result.breakdown.inventoryValue).toBe(500); // 5 * 100
    });

    it('should honor a custom zakatRate from settings when calculating', async () => {
      seedProduct({ quantity: 10, costPrice: 100, sellPrice: 100 });
      prisma._settings.set('store-A', {
        id: 'zs1',
        storeId: 'store-A',
        nisabGold: 85,
        nisabSilver: 595,
        nisabCurrency: 'TJS',
        nisabAmount: 0,
        haulStartDate: null,
        zakatRate: 5, // doubled from default
        includeStock: true,
        includeCash: true,
        includeDebts: true,
      });

      const result = await service.calculate('store-A');

      expect(result.zakatRate).toBe(5);
      expect(result.zakatDue).toBeCloseTo(50, 6); // 1000 * 5%
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

      expect(result.breakdown.inventoryValue).toBe(0);
      expect(result.totalAssets).toBe(0);
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
