import { Test } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  INestApplication,
} from '@nestjs/common';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { UsersService } from '../src/modules/users/users.service';
import * as bcrypt from 'bcrypt';
import { mkdir, writeFile, access } from 'fs/promises';
import { join } from 'path';

/**
 * Account deletion is a Google Play requirement for any app with sign-in.
 *
 * These tests run against the real development database (see the project's
 * note on api/test hitting the dev DB), so every fixture uses phone numbers in
 * the +99290000009x range, which no QA fixture occupies, and cleans up after
 * itself.
 */
/** Every fixture in this file uses a phone in this range. */
const FIXTURE_PHONE_PREFIX = '+99290000009';

describe('account deletion', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  /**
   * Removes any fixture left behind by an earlier failed run.
   *
   * Without this, one failure between `create` and `delete` leaves a row that
   * makes every later run fail on the unique phone constraint — the suite
   * would stay red for a reason that has nothing to do with the code. Deleting
   * the user is enough now that the cascade is in place.
   */
  async function clearFixtures(): Promise<void> {
    await prisma.user.deleteMany({
      where: { phone: { startsWith: FIXTURE_PHONE_PREFIX } },
    });
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    await clearFixtures();
  });

  afterAll(async () => {
    await clearFixtures();
    await app.close();
  });

  it('should delete an owner and cascade their store when no other staff remain', async () => {
    const user = await prisma.user.create({
      data: {
        phone: '+992900000091',
        name: 'Delete Me',
        password: 'placeholder-hash',
      },
    });
    const store = await prisma.store.create({
      data: { name: 'Doomed Store', ownerId: user.id, category: 'GROCERY' },
    });

    await prisma.user.delete({ where: { id: user.id } });

    expect(await prisma.user.findUnique({ where: { id: user.id } })).toBeNull();
    expect(
      await prisma.store.findUnique({ where: { id: store.id } }),
    ).toBeNull();
  });

  it('should refuse deletion when an owned store still has other staff', async () => {
    const owner = await prisma.user.create({
      data: {
        phone: `${FIXTURE_PHONE_PREFIX}2`,
        name: 'Owner',
        password: await bcrypt.hash('correct-password', 12),
      },
    });
    const colleague = await prisma.user.create({
      data: {
        phone: `${FIXTURE_PHONE_PREFIX}3`,
        name: 'Colleague',
        password: await bcrypt.hash('irrelevant', 12),
      },
    });
    const store = await prisma.store.create({
      data: { name: 'Staffed Store', ownerId: owner.id, category: 'GROCERY' },
    });
    await prisma.staff.create({
      data: { storeId: store.id, userId: colleague.id, role: 'CASHIER' },
    });

    const service = app.get(UsersService);
    // The status code is load-bearing, not just the wording: the mobile client
    // tells "you still have staff" (400) apart from "wrong password" (403) by
    // status alone, because the exception's message never reaches the UI.
    const thrown = await service
      .deleteAccount(owner.id, 'correct-password')
      .then(
        () => null,
        (e: unknown) => e,
      );
    expect(thrown).toBeInstanceOf(BadRequestException);
    expect((thrown as BadRequestException).getStatus()).toBe(400);

    // The guard must leave everything standing, not half-delete.
    expect(
      await prisma.user.findUnique({ where: { id: owner.id } }),
    ).not.toBeNull();
    expect(
      await prisma.store.findUnique({ where: { id: store.id } }),
    ).not.toBeNull();
  });

  it('should refuse deletion when the password is wrong', async () => {
    const user = await prisma.user.create({
      data: {
        phone: `${FIXTURE_PHONE_PREFIX}4`,
        name: 'Wrong Pass',
        password: await bcrypt.hash('right-password', 12),
      },
    });

    const service = app.get(UsersService);
    // 403, deliberately not 401: the client's Dio interceptor treats any 401 as
    // an expired token, so it would refresh and replay the DELETE. See the
    // reasoning on UsersService.deleteAccount.
    const thrown = await service
      .deleteAccount(user.id, 'wrong-password')
      .then(
        () => null,
        (e: unknown) => e,
      );
    expect(thrown).toBeInstanceOf(ForbiddenException);
    expect((thrown as ForbiddenException).getStatus()).toBe(403);

    expect(
      await prisma.user.findUnique({ where: { id: user.id } }),
    ).not.toBeNull();
  });

  it('should delete an owner whose store carries a full business history', async () => {
    // The point of this test is the shape of the fixture, not the assertion.
    //
    // The earlier "business data" test seeded a store with one product, which
    // every version of the schema could delete. It therefore passed while
    // account deletion was broken for every real merchant: the foreign keys
    // into `stores` cascaded, but the tables hanging off THOSE children were
    // still RESTRICT. One sale gives you a sale_item; one subscription payment
    // gives you a payments row; either stopped the cascade dead.
    //
    // So this builds a store that looks like a store — sale with line items,
    // stock movement, customer, supplier with a recorded payment, subscription
    // with a payment, staff member with a shift — and deletes the owner. Run it
    // against the pre-cascade schema and it fails on a foreign key.
    const user = await prisma.user.create({
      data: {
        phone: `${FIXTURE_PHONE_PREFIX}6`,
        name: 'Real Merchant',
        password: await bcrypt.hash('correct-password', 12),
      },
    });
    const store = await prisma.store.create({
      data: { name: 'Real Store', ownerId: user.id, category: 'GROCERY' },
    });
    const product = await prisma.product.create({
      data: { storeId: store.id, name: 'Нон', sellPrice: 5, quantity: 100 },
    });
    const customer = await prisma.customer.create({
      data: { storeId: store.id, name: 'Покупатель', updatedAt: new Date() },
    });
    const sale = await prisma.sale.create({
      data: {
        storeId: store.id,
        customerId: customer.id,
        receiptNo: 'FIXTURE-0001',
        subtotal: 10,
        total: 10,
        paymentType: 'CASH',
        paidAmount: 10,
        updatedAt: new Date(),
      },
    });
    await prisma.saleItem.create({
      data: {
        saleId: sale.id,
        productId: product.id,
        productName: 'Нон',
        quantity: 2,
        unitPrice: 5,
        total: 10,
      },
    });
    await prisma.stockMovement.create({
      data: { productId: product.id, type: 'SALE', quantity: -2 },
    });
    const supplier = await prisma.supplier.create({
      data: { storeId: store.id, name: 'Поставщик', updatedAt: new Date() },
    });
    await prisma.supplierPayment.create({
      data: {
        storeId: store.id,
        supplierId: supplier.id,
        amount: 50,
        method: 'CASH',
      },
    });
    const subscription = await prisma.subscription.create({
      data: {
        storeId: store.id,
        plan: 'BUSINESS',
        currentPeriodStart: new Date(),
        currentPeriodEnd: new Date(Date.now() + 30 * 24 * 3600 * 1000),
        updatedAt: new Date(),
      },
    });
    await prisma.payment.create({
      data: {
        subscriptionId: subscription.id,
        amount: 400,
        currency: 'TJS',
        method: 'CASH',
        status: 'APPROVED',
      },
    });
    // The owner's own staff row: deleteAccount only blocks on OTHER staff.
    const ownStaff = await prisma.staff.create({
      data: { storeId: store.id, userId: user.id, role: 'OWNER' },
    });
    await prisma.shift.create({
      data: { storeId: store.id, staffId: ownStaff.id, openingCash: 0 },
    });

    const service = app.get(UsersService);
    await service.deleteAccount(user.id, 'correct-password');

    expect(await prisma.user.findUnique({ where: { id: user.id } })).toBeNull();
    expect(
      await prisma.store.findUnique({ where: { id: store.id } }),
    ).toBeNull();
    // Spot-check both cascade levels: the store's own children, and the rows
    // that hang off those children.
    expect(
      await prisma.product.findUnique({ where: { id: product.id } }),
    ).toBeNull();
    expect(await prisma.saleItem.count({ where: { saleId: sale.id } })).toBe(0);
    expect(
      await prisma.payment.count({ where: { subscriptionId: subscription.id } }),
    ).toBe(0);
    expect(
      await prisma.supplierPayment.count({ where: { supplierId: supplier.id } }),
    ).toBe(0);
    expect(
      await prisma.shift.count({ where: { staffId: ownStaff.id } }),
    ).toBe(0);
  });

  it('should delete the uploaded receipt file, not just its database row', async () => {
    // A cascade deletes the `payments` row. The image it names is a file on
    // disk, and nothing in the database layer can reach it — so without an
    // explicit unlink the receipt outlives the account it belongs to. The
    // privacy policy promises otherwise.
    const dir = join(process.cwd(), 'uploads', 'receipts');
    await mkdir(dir, { recursive: true });
    const filename = `fixture-${Date.now()}.png`;
    const diskPath = join(dir, filename);
    await writeFile(diskPath, 'not really a png');
    const storedPath = `uploads/receipts/${filename}`;

    const user = await prisma.user.create({
      data: {
        phone: `${FIXTURE_PHONE_PREFIX}7`,
        name: 'Receipt Owner',
        password: await bcrypt.hash('correct-password', 12),
      },
    });
    const store = await prisma.store.create({
      data: { name: 'Receipt Store', ownerId: user.id, category: 'GROCERY' },
    });
    const subscription = await prisma.subscription.create({
      data: {
        storeId: store.id,
        plan: 'BUSINESS',
        currentPeriodStart: new Date(),
        currentPeriodEnd: new Date(Date.now() + 30 * 24 * 3600 * 1000),
        updatedAt: new Date(),
      },
    });
    await prisma.payment.create({
      data: {
        subscriptionId: subscription.id,
        amount: 400,
        currency: 'TJS',
        method: 'CASH',
        status: 'APPROVED',
        receiptImage: storedPath,
      },
    });

    // The file is there before the deletion, so its absence afterwards means
    // something removed it rather than it never having existed.
    await expect(access(diskPath)).resolves.toBeUndefined();

    const service = app.get(UsersService);
    await service.deleteAccount(user.id, 'correct-password');

    await expect(access(diskPath)).rejects.toThrow();
  });

  it('should delete an owner whose store has no staff but has business data', async () => {
    const user = await prisma.user.create({
      data: {
        phone: `${FIXTURE_PHONE_PREFIX}5`,
        name: 'Busy Owner',
        password: await bcrypt.hash('correct-password', 12),
      },
    });
    const store = await prisma.store.create({
      data: { name: 'Busy Store', ownerId: user.id, category: 'GROCERY' },
    });
    const product = await prisma.product.create({
      data: { storeId: store.id, name: 'Чай', sellPrice: 12, quantity: 5 },
    });

    const service = app.get(UsersService);
    await service.deleteAccount(user.id, 'correct-password');

    expect(await prisma.user.findUnique({ where: { id: user.id } })).toBeNull();
    expect(
      await prisma.store.findUnique({ where: { id: store.id } }),
    ).toBeNull();
    // The whole point of cascading from the owner: business data goes too.
    expect(
      await prisma.product.findUnique({ where: { id: product.id } }),
    ).toBeNull();
  });
});
