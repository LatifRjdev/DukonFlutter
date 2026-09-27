// Seeds the fixed-ID fixtures the e2e suite depends on but has no other
// way to create (test/debt-payments-idempotency.e2e-spec.ts and
// test/stock-movements-idempotency.e2e-spec.ts both hardcode QA_STORE_ID
// and log in as QA_PHONE — they scaffold their own scratch data via Prisma,
// but the user + store + one active product must already exist).
//
// Idempotent: safe to run against an already-seeded database (upserts on
// phone/id) or a completely fresh one (CI runs `prisma migrate deploy` then
// this script before `npm run test:e2e`).
import { PrismaClient, StoreCategory, Currency } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const QA_STORE_ID = 'd169d2e8-0a24-4a23-844a-5d5e7b690d8c';
const QA_PHONE = '+992910001002';
const QA_PASSWORD = 'qatest1234';

async function main() {
  const prisma = new PrismaClient();

  const password = await bcrypt.hash(QA_PASSWORD, 10);
  const owner = await prisma.user.upsert({
    where: { phone: QA_PHONE },
    update: { password, isActive: true },
    create: {
      phone: QA_PHONE,
      name: 'QA BUSINESS',
      password,
      isAdmin: false,
      isActive: true,
    },
  });

  const store = await prisma.store.upsert({
    where: { id: QA_STORE_ID },
    update: {},
    create: {
      id: QA_STORE_ID,
      ownerId: owner.id,
      name: 'QA e2e Store',
      category: StoreCategory.OTHER,
      currency: Currency.TJS,
    },
  });

  const existingProduct = await prisma.product.findFirst({
    where: { storeId: store.id, isActive: true },
  });
  if (!existingProduct) {
    await prisma.product.create({
      data: {
        storeId: store.id,
        name: 'QA e2e Product',
        sellPrice: 10,
        quantity: 100,
      },
    });
  }

  console.log('QA e2e fixtures ready:', {
    userId: owner.id,
    storeId: store.id,
  });
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
