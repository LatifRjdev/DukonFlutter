/**
 * Debt-payment idempotency e2e (Task A.5).
 *
 * Two endpoints:
 *   POST /stores/:storeId/customers/:id/payments  (DebtPayment, unique
 *     on (saleId, localId))   — wired pre-A.5.
 *   POST /stores/:storeId/suppliers/:id/payments  (SupplierPayment,
 *     unique on (storeId, localId)) — wired in 90cc5a0.
 *
 * No qa seed has a debt-laden sale or an indebted supplier, so this
 * suite creates and tears down its own scaffolding via Prisma. Uses
 * the real AppModule (same pattern as finance-correctness.e2e-spec.ts)
 * and the qa-business OWNER login.
 */
import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

const QA_STORE_ID = 'd169d2e8-0a24-4a23-844a-5d5e7b690d8c';
const QA_PHONE = '+992910001002';
const QA_PASSWORD = 'qatest1234';

describe('Debt-payment idempotency (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let token: string;

  // Scratch rows we create and must clean up. We capture the localIds
  // of any debt/supplier payment rows the test inserted so we can
  // remove them even on partial failure.
  let scratchCustomerId: string | null = null;
  let scratchSaleId: string | null = null;
  let scratchSupplierId: string | null = null;
  const scratchDebtLocalIds: string[] = [];
  const scratchSupplierLocalIds: string[] = [];

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

    // --- Scaffold a debt-laden sale for the customer-payment test ---
    const customer = await prisma.customer.create({
      data: {
        storeId: QA_STORE_ID,
        name: 'qa-idempotency-customer',
        debt: 100,
      },
    });
    scratchCustomerId = customer.id;

    const sale = await prisma.sale.create({
      data: {
        storeId: QA_STORE_ID,
        customerId: customer.id,
        receiptNo: `IDEM-${Date.now()}`,
        subtotal: 100,
        total: 100,
        paymentType: 'DEBT',
        paidAmount: 0,
        debtAmount: 100,
        status: 'COMPLETED',
      },
    });
    scratchSaleId = sale.id;

    // --- Scaffold an indebted supplier for the supplier-payment test ---
    const supplier = await prisma.supplier.create({
      data: {
        storeId: QA_STORE_ID,
        name: 'qa-idempotency-supplier',
        debt: 100,
      },
    });
    scratchSupplierId = supplier.id;
  });

  afterAll(async () => {
    // Order matters: payment rows reference sale/supplier, sale
    // references customer. Clean children first.
    for (const localId of scratchDebtLocalIds) {
      await prisma.debtPayment
        .deleteMany({ where: { localId } })
        .catch(() => undefined);
    }
    for (const localId of scratchSupplierLocalIds) {
      await prisma.supplierPayment
        .deleteMany({ where: { localId } })
        .catch(() => undefined);
    }
    if (scratchSaleId) {
      await prisma.sale
        .deleteMany({ where: { id: scratchSaleId } })
        .catch(() => undefined);
    }
    if (scratchCustomerId) {
      await prisma.customer
        .deleteMany({ where: { id: scratchCustomerId } })
        .catch(() => undefined);
    }
    if (scratchSupplierId) {
      await prisma.supplier
        .deleteMany({ where: { id: scratchSupplierId } })
        .catch(() => undefined);
    }
    await app?.close();
  });

  it('returns the same DebtPayment row on duplicate customer-payment localId', async () => {
    if (!scratchCustomerId || !scratchSaleId) {
      throw new Error('scaffold missing — beforeAll should have created it');
    }
    const localId = `qa-test-debtpay-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 8)}`;
    scratchDebtLocalIds.push(localId);

    const payload = {
      saleId: scratchSaleId,
      amount: 25,
      method: 'CASH',
      localId,
    };

    const r1 = await request(app.getHttpServer())
      .post(
        `/api/stores/${QA_STORE_ID}/customers/${scratchCustomerId}/payments`,
      )
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    const r2 = await request(app.getHttpServer())
      .post(
        `/api/stores/${QA_STORE_ID}/customers/${scratchCustomerId}/payments`,
      )
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    expect(r1.status).toBeGreaterThanOrEqual(200);
    expect(r1.status).toBeLessThan(300);
    expect(r2.status).toBeGreaterThanOrEqual(200);
    expect(r2.status).toBeLessThan(300);

    const id1 = r1.body?.id ?? r1.body?.data?.id;
    const id2 = r2.body?.id ?? r2.body?.data?.id;
    expect(id1).toBeTruthy();
    expect(id1).toBe(id2);

    // Only one row physically exists, and the sale was debited exactly
    // once: from 100 to 75, not 50.
    const count = await prisma.debtPayment.count({ where: { localId } });
    expect(count).toBe(1);
    const sale = await prisma.sale.findUnique({
      where: { id: scratchSaleId },
    });
    expect(Number(sale!.debtAmount)).toBe(75);
  });

  it('returns the same SupplierPayment row on duplicate supplier-payment localId', async () => {
    if (!scratchSupplierId) {
      throw new Error('scaffold missing — beforeAll should have created it');
    }
    const localId = `qa-test-supplierpay-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 8)}`;
    scratchSupplierLocalIds.push(localId);

    const payload = {
      amount: 30,
      method: 'CASH',
      localId,
    };

    const r1 = await request(app.getHttpServer())
      .post(
        `/api/stores/${QA_STORE_ID}/suppliers/${scratchSupplierId}/payments`,
      )
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    const r2 = await request(app.getHttpServer())
      .post(
        `/api/stores/${QA_STORE_ID}/suppliers/${scratchSupplierId}/payments`,
      )
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    expect(r1.status).toBeGreaterThanOrEqual(200);
    expect(r1.status).toBeLessThan(300);
    expect(r2.status).toBeGreaterThanOrEqual(200);
    expect(r2.status).toBeLessThan(300);

    const id1 = r1.body?.id ?? r1.body?.data?.id;
    const id2 = r2.body?.id ?? r2.body?.data?.id;
    expect(id1).toBeTruthy();
    expect(id1).toBe(id2);

    // Only one row physically exists, supplier.debt decremented exactly
    // once: 100 -> 70, not 40.
    const count = await prisma.supplierPayment.count({ where: { localId } });
    expect(count).toBe(1);
    const supplier = await prisma.supplier.findUnique({
      where: { id: scratchSupplierId },
    });
    expect(Number(supplier!.debt)).toBe(70);
  });
});
