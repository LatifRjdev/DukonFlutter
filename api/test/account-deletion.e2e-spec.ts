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
