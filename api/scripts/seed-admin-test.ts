import {
  PrismaClient,
  SubscriptionPlan,
  SubscriptionStatus,
  PaymentStatus,
  PaymentMethod,
  Currency,
  StoreCategory,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const hashedPassword = await bcrypt.hash('test12345', 10);

  // --- Users ---
  const user1 = await prisma.user.upsert({
    where: { phone: '+992900000010' },
    update: {},
    create: {
      phone: '+992900000010',
      password: hashedPassword,
      name: 'Тестовый Клиент 1',
      isAdmin: false,
    },
  });

  const user2 = await prisma.user.upsert({
    where: { phone: '+992900000011' },
    update: {},
    create: {
      phone: '+992900000011',
      password: hashedPassword,
      name: 'Тестовый Клиент 2',
      isAdmin: false,
    },
  });

  // --- Stores ---
  const store1 = await prisma.store.upsert({
    where: { id: 'seed-store-1' },
    update: {},
    create: {
      id: 'seed-store-1',
      ownerId: user1.id,
      name: 'Тестовый магазин 1 (активная подписка)',
      category: StoreCategory.GROCERY,
      currency: Currency.TJS,
    },
  });

  const store2 = await prisma.store.upsert({
    where: { id: 'seed-store-2' },
    update: {},
    create: {
      id: 'seed-store-2',
      ownerId: user2.id,
      name: 'Тестовый магазин 2 (ожидает подтверждения)',
      category: StoreCategory.OTHER,
      currency: Currency.TJS,
    },
  });

  // --- Subscriptions ---
  const now = new Date();
  const in30Days = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

  const sub1 = await prisma.subscription.upsert({
    where: { storeId: store1.id },
    update: {},
    create: {
      storeId: store1.id,
      plan: SubscriptionPlan.BUSINESS,
      status: SubscriptionStatus.ACTIVE,
      currentPeriodStart: now,
      currentPeriodEnd: in30Days,
    },
  });

  const sub2 = await prisma.subscription.upsert({
    where: { storeId: store2.id },
    update: {},
    create: {
      storeId: store2.id,
      plan: SubscriptionPlan.START,
      // No "pending" status in schema; PAST_DUE is the closest
      // meaning for "awaiting payment confirmation".
      status: SubscriptionStatus.PAST_DUE,
      currentPeriodStart: now,
      currentPeriodEnd: in30Days,
    },
  });

  // --- Pending payment on store2's subscription ---
  // Schema uses a single `Payment` model scoped to Subscription
  // (not a dedicated SubscriptionPayment model). It has no natural
  // unique key for idempotency, so we check manually.
  const existingPendingPayment = await prisma.payment.findFirst({
    where: {
      subscriptionId: sub2.id,
      status: PaymentStatus.PENDING,
    },
  });

  if (!existingPendingPayment) {
    await prisma.payment.create({
      data: {
        subscriptionId: sub2.id,
        amount: 50,
        currency: Currency.TJS,
        method: PaymentMethod.MOBILE_TRANSFER,
        status: PaymentStatus.PENDING,
        receiptImage: 'https://placeholder.example.com/receipt.jpg',
        note: 'Seed: ожидает подтверждения администратора',
      },
    });
  }

  // --- Announcement ---
  // Announcement requires a non-null `sentBy` referencing the admin
  // who issued it. Resolve the first admin user at runtime.
  const admin = await prisma.user.findFirst({ where: { isAdmin: true } });
  if (!admin) {
    throw new Error(
      'No admin user found. Run: npx ts-node scripts/create-admin.ts first.',
    );
  }

  await prisma.announcement.upsert({
    where: { id: 'seed-announcement-1' },
    update: {},
    create: {
      id: 'seed-announcement-1',
      title: 'Добро пожаловать!',
      body: 'Это тестовое объявление для QA админ-панели.',
      targetPlan: null,
      targetStatus: null,
      sentBy: admin.id,
      recipientCount: 0,
    },
  });

  console.log('Seed complete:');
  console.log(`  Users:          ${user1.phone}, ${user2.phone}`);
  console.log(`  Stores:         ${store1.id}, ${store2.id}`);
  console.log(`  Subscriptions:  ${sub1.status} / ${sub2.status}`);
  console.log(`  Announcements:  1`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
