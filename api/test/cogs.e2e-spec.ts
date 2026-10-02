import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { FinancesService } from '../src/modules/finances/finances.service';
import { FinanceQueryDto } from '../src/modules/finances/dto/finance-query.dto';
import { ReportsService } from '../src/modules/reports/reports.service';
import { ReportQueryDto } from '../src/modules/reports/dto/report-query.dto';
import { AppModule } from '../src/app.module';

// Exercises the cost-of-goods aggregate against a real database.
//
// The unit spec (finances.service.spec.ts) stubs $queryRaw, so it can only
// assert the SQL text the service sends. Everything that makes the aggregate
// correct — the join, the status filter, the refund term, the NULL costPrice
// path — is Postgres behaviour and is only observable here.
describe('Cost of goods sold (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let finances: FinancesService;
  let reports: ReportsService;

  // Initialised to '' rather than left undefined: Prisma drops an undefined
  // filter field, so `deleteMany({ where: { storeId: undefined } })` becomes
  // `deleteMany({})` and empties the table. afterAll runs even when beforeAll
  // throws, so an empty string — which matches nothing — is the safe default.
  let storeId = '';
  let userId = '';
  let productId = '';

  // An hour ago. It must be in the PAST: getDateRange's relative periods end at
  // `new Date()`, so a fixture stamped later today is outside the window and
  // every assertion silently reads 0 on any run before that time of day.
  const soldAt = new Date(Date.now() - 60 * 60 * 1000);

  // Explicit bounds rather than a relative period, so the window cannot move
  // under the fixture: getDateRange short-circuits on startDate+endDate.
  const from = new Date(soldAt.getTime() - 60 * 60 * 1000).toISOString();
  const to = new Date(soldAt.getTime() + 60 * 60 * 1000).toISOString();
  const range: FinanceQueryDto = { startDate: from, endDate: to };
  // The reports module names the same bounds differently.
  const reportRange: ReportQueryDto = { from, to };

  /** A completed sale of `qty` units at cost 10, price 25. */
  const makeSale = async (
    receiptNo: string,
    qty: number,
    opts: {
      status?: 'COMPLETED' | 'CANCELLED' | 'PARTIALLY_RETURNED';
      refundedQuantity?: number;
      costPrice?: number | null;
    } = {},
  ) => {
    const cost = opts.costPrice === undefined ? 10 : opts.costPrice;
    await prisma.sale.create({
      data: {
        storeId,
        receiptNo,
        subtotal: 25 * qty,
        total: 25 * qty,
        paymentType: 'CASH',
        paidAmount: 25 * qty,
        status: opts.status ?? 'COMPLETED',
        createdAt: soldAt,
        items: {
          create: {
            productId,
            productName: 'COGS probe',
            quantity: qty,
            unitPrice: 25,
            costPrice: cost,
            total: 25 * qty,
            refundedQuantity: opts.refundedQuantity ?? 0,
          },
        },
      },
    });
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    finances = app.get(FinancesService);
    reports = app.get(ReportsService);

    const user = await prisma.user.create({
      data: { phone: '+992999000098', password: 'x', name: 'COGS test owner' },
    });
    userId = user.id;
    const store = await prisma.store.create({
      data: { name: 'COGS test store', category: 'GROCERY', ownerId: user.id },
    });
    storeId = store.id;
    const product = await prisma.product.create({
      data: { storeId, name: 'COGS probe', costPrice: 10, sellPrice: 25 },
    });
    productId = product.id;
  });

  afterAll(async () => {
    // sale_items cascade from sales; everything else is deleted explicitly.
    if (storeId) {
      await prisma.sale.deleteMany({ where: { storeId } });
      await prisma.product.deleteMany({ where: { storeId } });
      await prisma.store.deleteMany({ where: { id: storeId } });
    }
    if (userId) await prisma.user.deleteMany({ where: { id: userId } });
    if (app) await app.close();
  });

  afterEach(async () => {
    if (storeId) await prisma.sale.deleteMany({ where: { storeId } });
  });

  it('should match the hand-computed figure when sales have a cost snapshot', async () => {
    await makeSale('COGS-1', 3); // 3 x 10
    await makeSale('COGS-2', 5); // 5 x 10

    const r = (await finances.getSummary(storeId, range)) as { cogs: number };

    expect(r.cogs).toBe(80);
  });

  it('should exclude a cancelled sale when computing cost of goods', async () => {
    await makeSale('COGS-3', 4);
    await makeSale('COGS-4', 100, { status: 'CANCELLED' });

    const r = (await finances.getSummary(storeId, range)) as { cogs: number };

    expect(r.cogs).toBe(40);
  });

  it('should exclude a partially returned sale from both cost and revenue', async () => {
    // The refund path moves the sale out of COMPLETED, so the sale leaves the
    // aggregate whole rather than having its refunded units netted off. This
    // pins that behaviour deliberately: revenue uses the same filter, so the
    // two stay consistent and the margin stays right. If the status filter is
    // ever widened, this test is the one that must be revisited.
    await makeSale('COGS-5', 4);
    await makeSale('COGS-6', 10, {
      status: 'PARTIALLY_RETURNED',
      refundedQuantity: 6,
    });

    // getDashboard is the endpoint that carries both figures, so the two can
    // be compared against each other rather than taken on trust separately.
    const r = (await finances.getDashboard(storeId, range)) as {
      cogs: number;
      totalRevenue: number;
    };

    expect(r.cogs).toBe(40);
    expect(r.totalRevenue).toBe(100);
  });

  it('should treat a missing cost snapshot as zero rather than returning null', async () => {
    await makeSale('COGS-7', 4, { costPrice: null });

    const r = (await finances.getSummary(storeId, range)) as { cogs: number };

    expect(r.cogs).toBe(0);
  });

  it('should count only the costed lines when one sale mixes costed and uncosted items', async () => {
    // Both lines on the SAME sale, so this exercises SUM skipping a NULL row
    // rather than the status filter dropping a whole sale.
    await prisma.sale.create({
      data: {
        storeId,
        receiptNo: 'COGS-8',
        subtotal: 275,
        total: 275,
        paymentType: 'CASH',
        paidAmount: 275,
        createdAt: soldAt,
        items: {
          create: [
            { productId, productName: 'costed', quantity: 4, unitPrice: 25, costPrice: 10, total: 100 },
            { productId, productName: 'uncosted', quantity: 7, unitPrice: 25, costPrice: null, total: 175 },
          ],
        },
      },
    });

    const r = (await finances.getSummary(storeId, range)) as { cogs: number };

    expect(r.cogs).toBe(40);
  });

  it('should not count another store cost of goods', async () => {
    // Ids captured before any await so the finally can clean up whatever got
    // created, however far this got. A fixture leaked by an early throw would
    // otherwise collide on the unique phone and fail every later run.
    let otherUserId = '';
    let otherStoreId = '';
    try {
      const otherUser = await prisma.user.create({
        data: {
          phone: '+992999000097',
          password: 'x',
          name: 'COGS other owner',
        },
      });
      otherUserId = otherUser.id;
      const otherStore = await prisma.store.create({
        data: {
          name: 'COGS other store',
          category: 'GROCERY',
          ownerId: otherUser.id,
        },
      });
      otherStoreId = otherStore.id;
      const otherProduct = await prisma.product.create({
        data: {
          storeId: otherStore.id,
          name: 'other probe',
          costPrice: 10,
          sellPrice: 25,
        },
      });
      await prisma.sale.create({
        data: {
          storeId: otherStore.id,
          receiptNo: 'COGS-OTHER',
          subtotal: 250,
          total: 250,
          paymentType: 'CASH',
          paidAmount: 250,
          createdAt: soldAt,
          items: {
            create: {
              productId: otherProduct.id,
              productName: 'other probe',
              quantity: 10,
              unitPrice: 25,
              costPrice: 10,
              total: 250,
            },
          },
        },
      });

      await makeSale('COGS-10', 4);

      const r = (await finances.getSummary(storeId, range)) as { cogs: number };
      expect(r.cogs).toBe(40);
    } finally {
      if (otherStoreId) {
        await prisma.sale.deleteMany({ where: { storeId: otherStoreId } });
        await prisma.product.deleteMany({ where: { storeId: otherStoreId } });
        await prisma.store.deleteMany({ where: { id: otherStoreId } });
      }
      if (otherUserId) {
        await prisma.user.deleteMany({ where: { id: otherUserId } });
      }
    }
  });

  it('should report the same cost of goods to the finance screen and the profit report', async () => {
    // These render one tap apart — Финансы and Отчёты → Прибыль. They used to
    // compute the figure from two separate copies of the aggregate, and the
    // copies had already drifted. This is the property that keeps them honest.
    await makeSale('COGS-13', 6);

    const finance = (await finances.getSummary(storeId, range)) as {
      cogs: number;
    };
    const report = (await reports.getProfitReport(storeId, reportRange)) as {
      cogs: number;
      grossProfit: number;
    };

    expect(finance.cogs).toBe(60);
    expect(report.cogs).toBe(finance.cogs);
    expect(report.grossProfit).toBe(150 - 60);
  });

  it('should exclude sales outside the requested period', async () => {
    await makeSale('COGS-11', 4);
    const longAgo = new Date(soldAt);
    longAgo.setFullYear(longAgo.getFullYear() - 2);  // well outside `range`
    await prisma.sale.create({
      data: {
        storeId,
        receiptNo: 'COGS-12',
        subtotal: 2500,
        total: 2500,
        paymentType: 'CASH',
        paidAmount: 2500,
        createdAt: longAgo,
        items: {
          create: {
            productId,
            productName: 'COGS probe',
            quantity: 100,
            unitPrice: 25,
            costPrice: 10,
            total: 2500,
          },
        },
      },
    });

    const r = (await finances.getSummary(storeId, range)) as { cogs: number };

    expect(r.cogs).toBe(40);
  });
});
