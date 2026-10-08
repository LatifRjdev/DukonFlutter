import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { SubscriptionsService } from '../src/modules/subscriptions/subscriptions.service';
import { AppModule } from '../src/app.module';

// The number on a plan card and the number written to the Payment row must be
// the same number. They came from two different expressions — one rounded, one
// not — and Decimal(12,2) hid the difference on write.
//
// The discount here is 33, deliberately. At 50 the arithmetic is exact and the
// two expressions agree under ANY implementation, so the test would pass
// against the bug. Same trap as the one-hour margin that made an earlier
// trial-countdown test pass under both implementations.
describe('Plan pricing agreement (e2e)', () => {
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
        phone: `+99290${Date.now().toString().slice(-7)}`,
        password: 'x',
        name: 'pricing e2e',
      },
    });
    userId = user.id;

    const store = await prisma.store.create({
      data: { name: 'pricing e2e store', ownerId: userId, category: 'OTHER' },
    });
    storeId = store.id;

    const sub = await prisma.subscription.create({
      data: {
        storeId,
        plan: 'START',
        status: 'ACTIVE',
        currentPeriodStart: new Date(),
        currentPeriodEnd: new Date(Date.now() + 30 * 86400000),
        adminDiscount: 33,
      },
    });
    subscriptionId = sub.id;
  });

  afterAll(async () => {
    await prisma.payment.deleteMany({ where: { subscriptionId } });
    await prisma.subscription.deleteMany({ where: { storeId } });
    await prisma.store.deleteMany({ where: { id: storeId } });
    await prisma.user.deleteMany({ where: { id: userId } });
    await app.close();
  });

  it('should charge exactly the price it advertises for every plan', async () => {
    const response: any = await subs.getSubscription(storeId);
    expect(response.availablePlans.length).toBeGreaterThan(0);

    for (const planView of response.availablePlans) {
      const payment = await subs.requestChange(storeId, {
        plan: planView.plan,
        paymentMethod: 'CASH',
      } as any);

      expect(Number(payment.amount)).toBe(planView.price);

      await prisma.payment.delete({ where: { id: payment.id } });
    }
  });

  it('should reduce the advertised price by the discount, not ignore it', async () => {
    // Without this, a bug that dropped the discount entirely would still pass
    // the agreement test above — both sides would simply be the list price.
    const response: any = await subs.getSubscription(storeId);
    for (const planView of response.availablePlans) {
      expect(planView.price).toBeLessThan(planView.listPrice);
    }
  });
});
