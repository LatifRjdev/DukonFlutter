import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { FinancesService } from './finances.service';
import { PrismaService } from '../../prisma/prisma.service';
import { BalancePeriod } from './dto/balance-query.dto';

// Map-backed Prisma fake: financial aggregations must respect storeId
// (no cross-store leakage) and date-range bounds (gte/lte). The fake mimics
// Prisma's where filters precisely so we test the SERVICE behavior, not the
// shape of mock arguments.
function makePrismaFake() {
  type Sale = {
    id: string;
    storeId: string;
    status: string;
    total: number;
    paymentType: string;
    receiptNo: string;
    createdAt: Date;
    customer?: { name: string } | null;
  };
  type Expense = {
    id: string;
    storeId: string;
    category: string;
    amount: number;
    description?: string | null;
    date: Date;
  };
  type Customer = {
    id: string;
    storeId: string;
    name: string;
    phone?: string | null;
    debt: number;
    totalSpent: number;
  };
  type Supplier = {
    id: string;
    storeId: string;
    name: string;
    phone?: string | null;
    debt: number;
  };

  const sales = new Map<string, Sale>();
  const expenses = new Map<string, Expense>();
  const customers = new Map<string, Customer>();
  const suppliers = new Map<string, Supplier>();

  const inRange = (d: Date, gte?: Date, lte?: Date) => {
    const t = d.getTime();
    if (gte && t < gte.getTime()) return false;
    if (lte && t > lte.getTime()) return false;
    return true;
  };

  const filterSales = (where: any = {}) =>
    Array.from(sales.values()).filter((s) => {
      if (where.storeId && s.storeId !== where.storeId) return false;
      if (where.status && s.status !== where.status) return false;
      if (where.createdAt && !inRange(s.createdAt, where.createdAt.gte, where.createdAt.lte))
        return false;
      return true;
    });

  const filterExpenses = (where: any = {}) =>
    Array.from(expenses.values()).filter((e) => {
      if (where.storeId && e.storeId !== where.storeId) return false;
      if (where.date && !inRange(e.date, where.date.gte, where.date.lte))
        return false;
      return true;
    });

  return {
    _sales: sales,
    _expenses: expenses,
    _customers: customers,
    _suppliers: suppliers,
    sale: {
      aggregate: jest.fn(async ({ where, _sum, _avg }: any = {}) => {
        const matched = filterSales(where);
        const totalSum = matched.reduce((s, x) => s + Number(x.total), 0);
        const avg = matched.length ? totalSum / matched.length : 0;
        return {
          _sum: _sum?.total ? { total: totalSum } : { total: 0 },
          _avg: _avg?.total ? { total: avg } : { total: 0 },
          _count: matched.length,
        };
      }),
      count: jest.fn(async ({ where }: any = {}) =>
        filterSales(where).length,
      ),
      findMany: jest.fn(async ({ where, take = 5 }: any = {}) => {
        const matched = filterSales(where).sort(
          (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
        );
        return matched.slice(0, take);
      }),
    },
    expense: {
      aggregate: jest.fn(async ({ where }: any = {}) => {
        const matched = filterExpenses(where);
        const sum = matched.reduce((s, x) => s + Number(x.amount), 0);
        return { _sum: { amount: sum }, _count: matched.length };
      }),
      groupBy: jest.fn(async ({ where }: any = {}) => {
        const matched = filterExpenses(where);
        const byCat = new Map<string, { sum: number; count: number }>();
        for (const e of matched) {
          const slot = byCat.get(e.category) ?? { sum: 0, count: 0 };
          slot.sum += Number(e.amount);
          slot.count += 1;
          byCat.set(e.category, slot);
        }
        return Array.from(byCat.entries()).map(([category, v]) => ({
          category,
          _sum: { amount: v.sum },
          _count: v.count,
        }));
      }),
      findMany: jest.fn(async ({ where, take = 10 }: any = {}) => {
        const matched = filterExpenses(where).sort(
          (a, b) => b.date.getTime() - a.date.getTime(),
        );
        return matched.slice(0, take);
      }),
    },
    product: {
      count: jest.fn(async () => 0),
    },
    customer: {
      findMany: jest.fn(async ({ where }: any = {}) =>
        Array.from(customers.values()).filter(
          (c) =>
            c.storeId === where.storeId && c.debt > (where.debt?.gt ?? -Infinity),
        ),
      ),
      aggregate: jest.fn(async ({ where }: any = {}) => {
        const matched = Array.from(customers.values()).filter(
          (c) =>
            c.storeId === where.storeId && c.debt > (where.debt?.gt ?? -Infinity),
        );
        return {
          _sum: { debt: matched.reduce((s, c) => s + c.debt, 0) },
          _count: matched.length,
        };
      }),
    },
    supplier: {
      findMany: jest.fn(async ({ where }: any = {}) =>
        Array.from(suppliers.values()).filter(
          (s) =>
            s.storeId === where.storeId && s.debt > (where.debt?.gt ?? -Infinity),
        ),
      ),
      aggregate: jest.fn(async ({ where }: any = {}) => {
        const matched = Array.from(suppliers.values()).filter(
          (s) =>
            s.storeId === where.storeId && s.debt > (where.debt?.gt ?? -Infinity),
        );
        return {
          _sum: { debt: matched.reduce((sum, s) => sum + s.debt, 0) },
          _count: matched.length,
        };
      }),
    },
    saleItem: {
      groupBy: jest.fn(async () => []),
    },
    // getSummary / getBalance use $queryRaw — return empty rows; tests below
    // focus on aggregate-driven fields rather than raw-query output.
    $queryRaw: jest.fn(async () => []),
  };
}

describe('FinancesService', () => {
  let service: FinancesService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        FinancesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(FinancesService);
  });

  const seedSale = (s: Partial<any> = {}) => {
    const sale = {
      id: s.id ?? `sale-${prisma._sales.size + 1}`,
      storeId: 'store-A',
      status: 'COMPLETED',
      total: 100,
      paymentType: 'CASH',
      receiptNo: 'R-001',
      createdAt: new Date('2026-04-15T12:00:00Z'),
      customer: null,
      ...s,
    };
    prisma._sales.set(sale.id, sale as any);
    return sale;
  };

  const seedExpense = (e: Partial<any> = {}) => {
    const expense = {
      id: e.id ?? `exp-${prisma._expenses.size + 1}`,
      storeId: 'store-A',
      category: 'OTHER',
      amount: 50,
      description: null,
      date: new Date('2026-04-15T00:00:00Z'),
      ...e,
    };
    prisma._expenses.set(expense.id, expense as any);
    return expense;
  };

  describe('getDashboard', () => {
    it('should exclude sales from other stores when computing totalRevenue', async () => {
      seedSale({ id: 'a1', storeId: 'store-A', total: 100 });
      seedSale({ id: 'b1', storeId: 'store-B', total: 9999 });

      const result = await service.getDashboard('store-A', {
        startDate: '2026-04-01',
        endDate: '2026-04-30',
      } as any);

      expect(result.totalRevenue).toBe(100);
      expect(result.salesCount).toBe(1);
    });

    it('should compute profit as totalRevenue minus totalExpenses with decimal precision', async () => {
      seedSale({ total: 199.99 });
      seedSale({ total: 0.02 });
      seedExpense({ amount: 50.5 });
      seedExpense({ amount: 0.01 });

      const result = await service.getDashboard('store-A', {
        startDate: '2026-04-01',
        endDate: '2026-04-30',
      } as any);

      // 200.01 - 50.51 = 149.50 (allow tiny float epsilon)
      expect(result.totalRevenue).toBeCloseTo(200.01, 2);
      expect(result.totalExpenses).toBeCloseTo(50.51, 2);
      expect(result.profit).toBeCloseTo(149.5, 2);
    });

    it('should respect startDate/endDate filters when aggregating sales', async () => {
      seedSale({ id: 'before', total: 1000, createdAt: new Date('2026-03-31T23:59:59Z') });
      seedSale({ id: 'inrange', total: 200, createdAt: new Date('2026-04-15T12:00:00Z') });
      seedSale({ id: 'after', total: 5000, createdAt: new Date('2026-05-01T00:00:01Z') });

      const result = await service.getDashboard('store-A', {
        startDate: '2026-04-01T00:00:00Z',
        endDate: '2026-04-30T23:59:59Z',
      } as any);

      expect(result.totalRevenue).toBe(200);
    });

    it('should exclude non-COMPLETED sales when computing revenue', async () => {
      seedSale({ id: 'paid', total: 300, status: 'COMPLETED' });
      seedSale({ id: 'cancelled', total: 999, status: 'CANCELLED' });

      const result = await service.getDashboard('store-A', {
        startDate: '2026-04-01',
        endDate: '2026-04-30',
      } as any);

      expect(result.totalRevenue).toBe(300);
      expect(result.salesCount).toBe(1);
    });
  });

  describe('getCreditsSummary', () => {
    it('should exclude debts from other stores when computing receivables and payables', async () => {
      prisma._customers.set('c1', {
        id: 'c1',
        storeId: 'store-A',
        name: 'Alice',
        debt: 100,
        totalSpent: 0,
      } as any);
      prisma._customers.set('c2', {
        id: 'c2',
        storeId: 'store-B',
        name: 'Bob',
        debt: 5000,
        totalSpent: 0,
      } as any);
      prisma._suppliers.set('s1', {
        id: 's1',
        storeId: 'store-A',
        name: 'Sup A',
        debt: 40,
      } as any);
      prisma._suppliers.set('s2', {
        id: 's2',
        storeId: 'store-B',
        name: 'Sup B',
        debt: 9999,
      } as any);

      const result = await service.getCreditsSummary('store-A');

      expect(result.receivables.totalAmount).toBe(100);
      expect(result.receivables.count).toBe(1);
      expect(result.payables.totalAmount).toBe(40);
      expect(result.payables.count).toBe(1);
      expect(result.netPosition).toBe(60); // 100 - 40
    });
  });

  describe('getBalance', () => {
    it('should compute income, expenses, and profit for the month period when given store data', async () => {
      const recent = new Date();
      recent.setDate(recent.getDate() - 5);
      seedSale({ total: 500, createdAt: recent });
      seedExpense({ amount: 200, date: recent });

      const result = await service.getBalance('store-A', {
        period: BalancePeriod.MONTH,
      } as any);

      expect(result.income).toBe(500);
      expect(result.expenses).toBe(200);
      expect(result.profit).toBe(300);
      expect(result.currentBalance).toBe(300);
    });
  });
});
