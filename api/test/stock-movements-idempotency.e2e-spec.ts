/**
 * StockMovement idempotency e2e (Task A.5).
 *
 * Verifies that two POSTs to /stores/:storeId/stock-movements with the
 * same `localId` produce a single row (server returns the existing row
 * on the second call). Backend wiring landed in commit 205f95b.
 *
 * Uses the real AppModule + real Prisma (same pattern as
 * finance-correctness.e2e-spec.ts) and the qa-business OWNER seed.
 */
import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

const QA_STORE_ID = 'd169d2e8-0a24-4a23-844a-5d5e7b690d8c';
const QA_PHONE = '+992910001002';
const QA_PASSWORD = 'qatest1234';

describe('StockMovement idempotency (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let token: string;
  let productId: string;
  const createdLocalIds: string[] = [];

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: false,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    await app.init();
    prisma = app.get(PrismaService);

    const loginRes = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ phone: QA_PHONE, password: QA_PASSWORD });
    token =
      loginRes.body.accessToken ??
      loginRes.body.access_token ??
      loginRes.body?.data?.accessToken;
    if (!token) {
      throw new Error(
        `Login failed for qa user ${QA_PHONE}: ` +
          JSON.stringify(loginRes.body),
      );
    }

    const product = await prisma.product.findFirst({
      where: { storeId: QA_STORE_ID, isActive: true },
    });
    if (!product) {
      throw new Error(`No active product in qa store ${QA_STORE_ID}`);
    }
    productId = product.id;
  });

  afterAll(async () => {
    // Clean up any stock_movement rows this suite created. Delete by
    // localId so we never touch unrelated qa data.
    for (const localId of createdLocalIds) {
      await prisma.stockMovement
        .deleteMany({ where: { localId } })
        .catch(() => undefined);
    }
    await app?.close();
  });

  it('returns the same StockMovement row on duplicate localId', async () => {
    const localId = `qa-test-stock-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 8)}`;
    createdLocalIds.push(localId);

    const payload = {
      productId,
      type: 'PURCHASE',
      quantity: 5,
      unitCost: 12.5,
      localId,
    };

    // Route lives on ProductsController, not the standalone
    // StockMovementsController file (which isn't registered). The
    // :productId URL segment is unused by the handler — productId
    // comes from the body — but the path must include it to match.
    const url = `/api/stores/${QA_STORE_ID}/products/${productId}/stock-movements`;

    const r1 = await request(app.getHttpServer())
      .post(url)
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    const r2 = await request(app.getHttpServer())
      .post(url)
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    expect(r1.status).toBeGreaterThanOrEqual(200);
    expect(r1.status).toBeLessThan(300);
    expect(r2.status).toBeGreaterThanOrEqual(200);
    expect(r2.status).toBeLessThan(300);

    const id1 = r1.body?.id ?? r1.body?.data?.id;
    const id2 = r2.body?.id ?? r2.body?.data?.id;
    expect(id1).toBeTruthy();
    expect(id2).toBeTruthy();
    expect(id1).toBe(id2);

    // Belt + braces: the unique constraint on localId means there can
    // only ever be one row, but the controller also short-circuits
    // before insert. Assert both invariants hold.
    const count = await prisma.stockMovement.count({ where: { localId } });
    expect(count).toBe(1);
  });
});
