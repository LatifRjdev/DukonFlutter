import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { FinancesService } from '../src/modules/finances/finances.service';
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

  let storeId: string;
  let userId: string;
  let productId: string;

  // One day comfortably inside the "month" range the service computes, and far
  // enough from midnight that the test cannot straddle a day boundary.
  const soldAt = (() => {
    const d = new Date();
    d.setDate(Math.min(d.getDate(), 28));
    d.setHours(12, 0, 0, 0);
    return d;
  })();

  const range = { period: 'month' } as never;

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
    await prisma.sale.deleteMany({ where: { storeId } });
    await prisma.product.deleteMany({ where: { storeId } });
    await prisma.store.deleteMany({ where: { id: storeId } });
    await prisma.user.deleteMany({ where: { id: userId } });
    await app.close();
  });

  afterEach(async () => {
    await prisma.sale.deleteMany({ where: { storeId } });
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

  it('should count only the costed lines when a sale mixes costed and uncosted items', async () => {
    await makeSale('COGS-8', 4); // 4 x 10 = 40
    await makeSale('COGS-9', 7, { costPrice: null }); // contributes nothing

    const r = (await finances.getSummary(storeId, range)) as { cogs: number };

    expect(r.cogs).toBe(40);
  });

  it('should not count another store cost of goods', async () => {
    const otherUser = await prisma.user.create({
      data: { phone: '+992999000097', password: 'x', name: 'COGS other owner' },
    });
    const otherStore = await prisma.store.create({
      data: {
        name: 'COGS other store',
        category: 'GROCERY',
        ownerId: otherUser.id,
      },
    });
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

    try {
      const r = (await finances.getSummary(storeId, range)) as { cogs: number };
      expect(r.cogs).toBe(40);
    } finally {
      await prisma.sale.deleteMany({ where: { storeId: otherStore.id } });
      await prisma.product.deleteMany({ where: { storeId: otherStore.id } });
      await prisma.store.deleteMany({ where: { id: otherStore.id } });
      await prisma.user.deleteMany({ where: { id: otherUser.id } });
    }
  });

  it('should exclude sales outside the requested period', async () => {
    await makeSale('COGS-11', 4);
    const longAgo = new Date(soldAt);
    longAgo.setFullYear(longAgo.getFullYear() - 2);
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
