import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

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
});
