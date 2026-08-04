import { Test } from '@nestjs/testing';
import { ReportsService } from './reports.service';
import { PrismaService } from '../../prisma/prisma.service';

type SaleRow = {
  id: string;
  storeId: string;
  status: 'COMPLETED' | 'CANCELLED';
  staffId: string | null;
  total: number;
  createdAt: Date;
  channel: 'IN_STORE' | 'ONLINE';
};

type SaleItemRow = {
  id: string;
  saleId: string;
  productId: string;
  productName: string;
  quantity: number;
  total: number;
  costPrice?: number | null;
};

type ExpenseRow = {
  id: string;
  storeId: string;
  amount: number;
  date: Date;
};

type ProductRow = {
  id: string;
  storeId: string;
  name: string;
  sku: string | null;
  isActive: boolean;
  quantity: number;
  sellPrice: number;
  costPrice: number | null;
};

type StaffRow = {
  id: string;
  role: 'OWNER' | 'ADMIN' | 'CASHIER' | 'WAREHOUSE';
  user: { name: string };
};

function inRange(d: Date, gte?: Date, lte?: Date) {
  if (gte && d < gte) return false;
  if (lte && d > lte) return false;
  return true;
}

function makePrismaFake() {
  const sales: SaleRow[] = [];
  const items: SaleItemRow[] = [];
  const expenses: ExpenseRow[] = [];
  const products: ProductRow[] = [];
  const staff: StaffRow[] = [];

  const saleAggregate = jest.fn(async ({ where, _sum, _avg, _count }: any) => {
    const filtered = sales.filter(
      (s) =>
        s.storeId === where.storeId &&
        s.status === where.status &&
        inRange(s.createdAt, where.createdAt?.gte, where.createdAt?.lte) &&
        (where.channel === undefined || s.channel === where.channel),
    );
    const sum = filtered.reduce((acc, s) => acc + s.total, 0);
    const avg = filtered.length === 0 ? 0 : sum / filtered.length;
    return {
      _sum: _sum?.total !== undefined ? { total: sum } : undefined,
      _avg: _avg?.total !== undefined ? { total: avg } : undefined,
      _count: _count !== undefined ? filtered.length : undefined,
    };
  });

  const saleGroupBy = jest.fn(async ({ by, where }: any) => {
    const baseFiltered = sales.filter(
      (s) =>
        s.storeId === where.storeId &&
        s.status === where.status &&
        inRange(s.createdAt, where.createdAt?.gte, where.createdAt?.lte) &&
        (where.channel === undefined || s.channel === where.channel),
    );

    if (by.includes('channel')) {
      const byChannel = new Map<
        string,
        { channel: string; total: number; count: number }
      >();
      for (const s of baseFiltered) {
        const existing = byChannel.get(s.channel) ?? {
          channel: s.channel,
          total: 0,
          count: 0,
        };
        existing.total += s.total;
        existing.count += 1;
        byChannel.set(s.channel, existing);
      }
      return Array.from(byChannel.values()).map((v) => ({
        channel: v.channel,
        _sum: { total: v.total },
        _count: v.count,
      }));
    }

    const filtered = baseFiltered.filter((s) => s.staffId !== null);
    const byStaff = new Map<
      string,
      { staffId: string; total: number; count: number }
    >();
    for (const s of filtered) {
      const existing = byStaff.get(s.staffId!) ?? {
        staffId: s.staffId!,
        total: 0,
        count: 0,
      };
      existing.total += s.total;
      existing.count += 1;
      byStaff.set(s.staffId!, existing);
    }
    return Array.from(byStaff.values()).map((v) => ({
      staffId: v.staffId,
      _sum: { total: v.total },
      _avg: { total: v.count === 0 ? 0 : v.total / v.count },
      _count: v.count,
    }));
  });

  const itemGroupBy = jest.fn(async ({ where, take }: any) => {
    const matchSales = new Set(
      sales
        .filter(
          (s) =>
            s.storeId === where.sale.storeId &&
            s.status === where.sale.status &&
            inRange(
              s.createdAt,
              where.sale.createdAt?.gte,
              where.sale.createdAt?.lte,
            ) &&
            (where.sale.channel === undefined ||
              s.channel === where.sale.channel),
        )
        .map((s) => s.id),
    );
    const groups = new Map<
      string,
      { productId: string; productName: string; qty: number; total: number }
    >();
    for (const it of items) {
      if (!matchSales.has(it.saleId)) continue;
      const key = it.productId;
      const g = groups.get(key) ?? {
        productId: it.productId,
        productName: it.productName,
        qty: 0,
        total: 0,
      };
      g.qty += it.quantity;
      g.total += it.total;
      groups.set(key, g);
    }
    const arr = Array.from(groups.values()).map((g) => ({
      productId: g.productId,
      productName: g.productName,
      _sum: { quantity: g.qty, total: g.total },
    }));
    arr.sort((a, b) => (b._sum.total ?? 0) - (a._sum.total ?? 0));
    return take ? arr.slice(0, take) : arr;
  });

  const itemFindMany = jest.fn(async ({ where }: any) => {
    const matchSales = new Set(
      sales
        .filter(
          (s) =>
            s.storeId === where.sale.storeId &&
            s.status === where.sale.status &&
            inRange(
              s.createdAt,
              where.sale.createdAt?.gte,
              where.sale.createdAt?.lte,
            ),
        )
        .map((s) => s.id),
    );
    const ids = new Set<string>();
    for (const it of items) {
      if (!matchSales.has(it.saleId)) continue;
      ids.add(it.productId);
    }
    return Array.from(ids).map((productId) => ({ productId }));
  });

  const expenseAggregate = jest.fn(async ({ where }: any) => {
    const filtered = expenses.filter(
      (e) =>
        e.storeId === where.storeId &&
        inRange(e.date, where.date?.gte, where.date?.lte),
    );
    const sum = filtered.reduce((acc, e) => acc + e.amount, 0);
    return { _sum: { amount: sum } };
  });

  const productFindMany = jest.fn(async ({ where, take }: any) => {
    const list = products.filter((p) => {
      if (where.storeId && p.storeId !== where.storeId) return false;
      if (where.isActive !== undefined && p.isActive !== where.isActive)
        return false;
      if (where.quantity?.gt !== undefined && !(p.quantity > where.quantity.gt))
        return false;
      if (where.id?.notIn && where.id.notIn.includes(p.id)) return false;
      return true;
    });
    return take ? list.slice(0, take) : list;
  });

  const staffFindMany = jest.fn(async ({ where }: any) => {
    return staff.filter((s) => where.id?.in?.includes(s.id));
  });

  const queryRaw = jest.fn(async (strings: any, ...values: any[]) => {
    // Approximate: we only use it for sales-by-date and stock value.
    // Distinguish by inspecting the SQL string body.
    const sql = strings.join(' ');
    if (sql.includes('FROM sales')) {
      const storeId = values[0];
      const start = values[1] as Date;
      const end = values[2] as Date;
      // The 4th interpolated value is the conditional channel fragment
      // (Prisma.sql`AND channel = ...` or Prisma.empty). Both are `Sql`
      // instances with a `.values` array — non-empty only when a real
      // channel filter fragment was interpolated.
      const channelFragment = values[3] as { values?: unknown[] } | undefined;
      const channel = channelFragment?.values?.length
        ? (channelFragment.values[0] as string)
        : undefined;
      const filtered = sales.filter(
        (s) =>
          s.storeId === storeId &&
          s.status === 'COMPLETED' &&
          inRange(s.createdAt, start, end) &&
          (channel === undefined || s.channel === channel),
      );
      const byDate = new Map<string, { count: number; revenue: number }>();
      for (const s of filtered) {
        const key = s.createdAt.toISOString().slice(0, 10);
        const cur = byDate.get(key) ?? { count: 0, revenue: 0 };
        cur.count += 1;
        cur.revenue += s.total;
        byDate.set(key, cur);
      }
      return Array.from(byDate.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([d, v]) => ({
          date: new Date(d),
          count: BigInt(v.count),
          revenue: v.revenue,
          avg_check: v.count === 0 ? 0 : v.revenue / v.count,
        }));
    }
    if (sql.includes('FROM products')) {
      const storeId = values[0];
      const total = products
        .filter((p) => p.storeId === storeId && p.isActive && p.costPrice)
        .reduce((acc, p) => acc + p.quantity * (p.costPrice ?? 0), 0);
      return [{ total_value: total }];
    }
    if (sql.includes('FROM sale_items')) {
      const storeId = values[0];
      const start = values[1] as Date;
      const end = values[2] as Date;
      const matchSaleIds = new Set(
        sales
          .filter(
            (s) =>
              s.storeId === storeId &&
              s.status === 'COMPLETED' &&
              inRange(s.createdAt, start, end),
          )
          .map((s) => s.id),
      );
      const cogs = items
        .filter((it) => matchSaleIds.has(it.saleId))
        .reduce((acc, it) => acc + it.quantity * (it.costPrice ?? 0), 0);
      return [{ cogs }];
    }
    return [];
  });

  return {
    sale: { aggregate: saleAggregate, groupBy: saleGroupBy },
    saleItem: { groupBy: itemGroupBy, findMany: itemFindMany },
    expense: { aggregate: expenseAggregate },
    product: { findMany: productFindMany },
    staff: { findMany: staffFindMany },
    $queryRaw: queryRaw,
    __sales: sales,
    __items: items,
    __expenses: expenses,
    __products: products,
    __staff: staff,
  } as any;
}

describe('ReportsService', () => {
  let service: ReportsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [ReportsService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(ReportsService);
  });

  const seedSale = (s: Partial<SaleRow> & { id: string; storeId: string }) => {
    const row: SaleRow = {
      status: 'COMPLETED',
      staffId: null,
      total: 100,
      createdAt: new Date('2026-04-15T10:00:00Z'),
      channel: 'IN_STORE',
      ...s,
    } as SaleRow;
    prisma.__sales.push(row);
    return row;
  };

  const seedItem = (
    it: Partial<SaleItemRow> & { id: string; saleId: string },
  ) => {
    const row: SaleItemRow = {
      productId: 'p1',
      productName: 'Product',
      quantity: 1,
      total: 0,
      costPrice: null,
      ...it,
    } as SaleItemRow;
    prisma.__items.push(row);
    return row;
  };

  describe('getSalesReport — aggregation correctness', () => {
    it('should sum revenue and count only COMPLETED sales for the requested store and range', async () => {
      seedSale({ id: 's1', storeId: 'A', total: 100 });
      seedSale({ id: 's2', storeId: 'A', total: 250 });
      seedSale({ id: 's3', storeId: 'A', total: 999, status: 'CANCELLED' }); // excluded
      seedSale({ id: 's4', storeId: 'B', total: 500 }); // wrong store

      const r = await service.getSalesReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });

      expect(r.totalRevenue).toBe(350);
      expect(r.totalCount).toBe(2);
      expect(r.avgCheck).toBe(175);
    });

    it('should exclude sales outside the date range', async () => {
      seedSale({
        id: 's-in',
        storeId: 'A',
        total: 100,
        createdAt: new Date('2026-04-15T10:00:00Z'),
      });
      seedSale({
        id: 's-out',
        storeId: 'A',
        total: 9999,
        createdAt: new Date('2026-03-15T10:00:00Z'),
      });

      const r = await service.getSalesReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });
      expect(r.totalRevenue).toBe(100);
    });

    it('should NOT leak sales from another store via the storeId filter', async () => {
      seedSale({ id: 's1', storeId: 'A', total: 100 });
      seedSale({ id: 's2', storeId: 'OTHER', total: 9999 });

      const r = await service.getSalesReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });
      expect(r.totalRevenue).toBe(100);
      expect(r.totalCount).toBe(1);
    });

    it('filters by channel when provided and always includes a channel breakdown', async () => {
      (prisma.sale.groupBy as jest.Mock).mockResolvedValue([
        { channel: 'IN_STORE', _sum: { total: 800 }, _count: 4 },
        { channel: 'ONLINE', _sum: { total: 200 }, _count: 1 },
      ]);

      const result = await service.getSalesReport('A', {
        channel: 'ONLINE',
      } as any);

      expect(prisma.sale.groupBy).toHaveBeenCalledWith(
        expect.objectContaining({ by: ['channel'] }),
      );
      expect(result.channelBreakdown).toEqual([
        { channel: 'IN_STORE', revenue: 800, count: 4 },
        { channel: 'ONLINE', revenue: 200, count: 1 },
      ]);
    });

    it('narrows byDate, topProducts, and totals to the requested channel — while channelBreakdown always covers every channel, filtered or not', async () => {
      // Two IN_STORE sales + one ONLINE sale, each with its own item, so
      // filtered vs. unfiltered results are provably different (not just
      // differently-labeled copies of the same numbers).
      seedSale({ id: 's-instore-1', storeId: 'A', total: 100, channel: 'IN_STORE' });
      seedSale({ id: 's-instore-2', storeId: 'A', total: 200, channel: 'IN_STORE' });
      seedSale({ id: 's-online-1', storeId: 'A', total: 50, channel: 'ONLINE' });
      seedItem({
        id: 'i-instore-1',
        saleId: 's-instore-1',
        productId: 'p-instore',
        productName: 'In-store product',
        quantity: 1,
        total: 100,
      });
      seedItem({
        id: 'i-online-1',
        saleId: 's-online-1',
        productId: 'p-online',
        productName: 'Online product',
        quantity: 1,
        total: 50,
      });

      const unfiltered = await service.getSalesReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });
      const onlineOnly = await service.getSalesReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
        channel: 'ONLINE',
      } as any);

      // Unfiltered: all 3 sales / both products.
      expect(unfiltered.totalRevenue).toBe(350);
      expect(unfiltered.totalCount).toBe(3);
      expect(unfiltered.topProducts.map((p) => p.productId).sort()).toEqual([
        'p-instore',
        'p-online',
      ]);
      expect(unfiltered.byDate.reduce((sum, d) => sum + d.revenue, 0)).toBe(350);

      // channel: 'ONLINE' narrows totals (sale.aggregate), topProducts
      // (saleItem.groupBy), and byDate (the raw-SQL query) — not just the
      // unconditional channelBreakdown query.
      expect(onlineOnly.totalRevenue).toBe(50);
      expect(onlineOnly.totalCount).toBe(1);
      expect(onlineOnly.topProducts).toEqual([
        expect.objectContaining({ productId: 'p-online', totalRevenue: 50 }),
      ]);
      expect(onlineOnly.byDate.reduce((sum, d) => sum + d.revenue, 0)).toBe(50);

      // channelBreakdown is the unconditional 4th query: it reports the
      // full IN_STORE/ONLINE split regardless of whether `channel` was
      // set on this same call.
      const breakdownFiltered = Object.fromEntries(
        onlineOnly.channelBreakdown.map((c) => [c.channel, c]),
      );
      expect(breakdownFiltered['IN_STORE']).toMatchObject({
        revenue: 300,
        count: 2,
      });
      expect(breakdownFiltered['ONLINE']).toMatchObject({
        revenue: 50,
        count: 1,
      });

      // ...and the same full breakdown is present on the unfiltered call
      // too — confirms the unfiltered case isn't missing channelBreakdown.
      const breakdownUnfiltered = Object.fromEntries(
        unfiltered.channelBreakdown.map((c) => [c.channel, c]),
      );
      expect(breakdownUnfiltered['IN_STORE']).toMatchObject({
        revenue: 300,
        count: 2,
      });
      expect(breakdownUnfiltered['ONLINE']).toMatchObject({
        revenue: 50,
        count: 1,
      });
    });
  });

  describe('getProfitReport — profit and margin math', () => {
    it('should compute profit = income - expenses and margin% rounded to 2 decimals', async () => {
      seedSale({ id: 's1', storeId: 'A', total: 1000 });
      prisma.__expenses.push({
        id: 'e1',
        storeId: 'A',
        amount: 250,
        date: new Date('2026-04-10T00:00:00Z'),
      });

      const r = await service.getProfitReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });

      expect(r.income).toBe(1000);
      expect(r.expenses).toBe(250);
      expect(r.profit).toBe(750);
      expect(r.marginPercent).toBe(75);
    });

    it('should report margin 0 when there is no income (avoid divide-by-zero)', async () => {
      prisma.__expenses.push({
        id: 'e1',
        storeId: 'A',
        amount: 100,
        date: new Date('2026-04-10T00:00:00Z'),
      });
      const r = await service.getProfitReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });
      expect(r.income).toBe(0);
      expect(r.profit).toBe(-100);
      expect(r.marginPercent).toBe(0);
    });

    it('should deduct cost of goods sold (SaleItem.costPrice * quantity) from profit', async () => {
      // 3 sales, revenue 120 total, known COGS 50 -> true margin ~58.33%
      seedSale({ id: 's1', storeId: 'A', total: 40 });
      seedSale({ id: 's2', storeId: 'A', total: 40 });
      seedSale({ id: 's3', storeId: 'A', total: 40 });
      seedItem({
        id: 'i1',
        saleId: 's1',
        quantity: 2,
        costPrice: 10, // 20
      });
      seedItem({
        id: 'i2',
        saleId: 's2',
        quantity: 1,
        costPrice: 15, // 15
      });
      seedItem({
        id: 'i3',
        saleId: 's3',
        quantity: 3,
        costPrice: 5, // 15
      });
      // total cogs = 20 + 15 + 15 = 50

      const r = await service.getProfitReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });

      expect(r.income).toBe(120);
      expect(r.cogs).toBe(50);
      expect(r.grossProfit).toBe(70);
      expect(r.expenses).toBe(0);
      expect(r.profit).toBe(70);
      expect(r.marginPercent).toBe(58.33);
    });

    it('should subtract both COGS and manual expenses from income for net profit', async () => {
      seedSale({ id: 's1', storeId: 'A', total: 1000 });
      seedItem({ id: 'i1', saleId: 's1', quantity: 10, costPrice: 20 }); // cogs 200
      prisma.__expenses.push({
        id: 'e1',
        storeId: 'A',
        amount: 100,
        date: new Date('2026-04-10T00:00:00Z'),
      });

      const r = await service.getProfitReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });

      expect(r.income).toBe(1000);
      expect(r.cogs).toBe(200);
      expect(r.grossProfit).toBe(800);
      expect(r.expenses).toBe(100);
      expect(r.profit).toBe(700);
      expect(r.marginPercent).toBe(70);
    });

    it('should ignore sale items from CANCELLED sales when computing COGS', async () => {
      seedSale({ id: 's1', storeId: 'A', total: 100 });
      seedSale({
        id: 's2',
        storeId: 'A',
        total: 999,
        status: 'CANCELLED',
      });
      seedItem({ id: 'i1', saleId: 's1', quantity: 1, costPrice: 10 });
      seedItem({ id: 'i2', saleId: 's2', quantity: 100, costPrice: 100 }); // excluded

      const r = await service.getProfitReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });

      expect(r.income).toBe(100);
      expect(r.cogs).toBe(10);
    });
  });

  describe('getStaffReport — group-by staff', () => {
    it('should group sales by staffId and produce per-staff totals', async () => {
      seedSale({ id: 's1', storeId: 'A', staffId: 'st-1', total: 100 });
      seedSale({ id: 's2', storeId: 'A', staffId: 'st-1', total: 200 });
      seedSale({ id: 's3', storeId: 'A', staffId: 'st-2', total: 50 });

      prisma.__staff.push(
        { id: 'st-1', role: 'CASHIER', user: { name: 'Ali' } },
        { id: 'st-2', role: 'CASHIER', user: { name: 'Bek' } },
      );

      const r = await service.getStaffReport('A', {
        from: '2026-04-01',
        to: '2026-04-30',
      });

      const byId = Object.fromEntries(r.byStaff.map((s) => [s.staffId, s]));
      expect(byId['st-1']).toMatchObject({
        salesCount: 2,
        totalRevenue: 300,
        avgCheck: 150,
        staffName: 'Ali',
      });
      expect(byId['st-2']).toMatchObject({
        salesCount: 1,
        totalRevenue: 50,
        staffName: 'Bek',
      });
    });
  });
});
