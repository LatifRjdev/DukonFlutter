import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { SubscriptionsService } from '../src/modules/subscriptions/subscriptions.service';
import { AppModule } from '../src/app.module';

// Two defects, same money: a duplicate PENDING request can be approved twice
// (Task 2), and the plan a payment buys lived only in a free-text note that
// approval recovered with a regex — missing for every manually typed note
// (Task 3).
describe('Payment integrity (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let subs: SubscriptionsService;

  // Initialised to '' rather than undefined: Prisma drops an undefined filter
  // field, so deleteMany({ where: { id: undefined } }) empties the table.
  let storeId = '';
  let userId = '';
  let subscriptionId = '';

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    subs = app.get(SubscriptionsService);

    const user = await prisma.user.create({
      data: {
        phone: `+99291${Date.now().toString().slice(-7)}`,
        password: 'x',
        name: 'payment integrity e2e',
      },
    });
    userId = user.id;

    const store = await prisma.store.create({
      data: {
        name: 'payment integrity e2e store',
        ownerId: userId,
        category: 'OTHER',
      },
    });
    storeId = store.id;

    const sub = await prisma.subscription.create({
      data: {
        storeId,
        plan: 'START',
        status: 'ACTIVE',
        currentPeriodStart: new Date(),
        currentPeriodEnd: new Date(Date.now() + 30 * 86400000),
      },
    });
    subscriptionId = sub.id;
  });

  // Each test must clean up its own payments: the duplicate-pending guard
  // means a PENDING row left over from one test breaks the next.
  afterEach(async () => {
    await prisma.payment.deleteMany({ where: { subscriptionId } });
  });

  afterAll(async () => {
    await prisma.payment.deleteMany({ where: { subscriptionId } });
    await prisma.subscription.deleteMany({ where: { storeId } });
    await prisma.store.deleteMany({ where: { id: storeId } });
    await prisma.user.deleteMany({ where: { id: userId } });
    await app.close();
  });

  it('should refuse a second request while one is still pending', async () => {
    await subs.requestChange(storeId, {
      plan: 'BUSINESS',
      paymentMethod: 'CASH',
    } as any);

    await expect(
      subs.requestChange(storeId, {
        plan: 'PREMIUM',
        paymentMethod: 'CASH',
      } as any),
    ).rejects.toThrow();

    // The row count, not just the exception: a guard that throws AFTER
    // creating the row would pass an exception-only assertion while leaving
    // exactly the duplicate it exists to prevent.
    const pending = await prisma.payment.count({
      where: { subscriptionId, status: 'PENDING' },
    });
    expect(pending).toBe(1);
  });

  it('should allow a new request once the pending one is settled', async () => {
    const first = await subs.requestChange(storeId, {
      plan: 'BUSINESS',
      paymentMethod: 'CASH',
    } as any);
    await prisma.payment.update({
      where: { id: first.id },
      data: { status: 'REJECTED' },
    });

    const second = await subs.requestChange(storeId, {
      plan: 'PREMIUM',
      paymentMethod: 'CASH',
    } as any);
    expect(second.id).not.toBe(first.id);
  });

  it('should record the requested plan in the column, not only the note', async () => {
    const payment = await subs.requestChange(storeId, {
      plan: 'PREMIUM',
      paymentMethod: 'CASH',
    } as any);
    expect(payment.requestedPlan).toBe('PREMIUM');
  });
});
