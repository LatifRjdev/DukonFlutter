import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { AppModule } from '../src/app.module';

// Validates the CHECK constraints from migration
// 20260511000000_finance_correctness. The application path is already
// clamped (BUG #14 fix), so this proves the DB-level guarantee for any
// path that bypasses the service layer (admin SQL, broken seed, …).
describe('Finance correctness — DB CHECK constraints', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects raw INSERT that sets sale.total to a negative value', async () => {
    // Use $executeRawUnsafe so we bypass the application clamp entirely.
    // We expect Postgres to throw a check_violation.
    await expect(
      prisma.$executeRawUnsafe(
        `INSERT INTO sales
           (id, "storeId", "receiptNo", subtotal, total, "paymentType",
            "paidAmount", status, "createdAt", "updatedAt")
         VALUES
           (gen_random_uuid(), gen_random_uuid()::text,
            'CHK-TEST-NEG', 5, -1, 'CASH', 5, 'COMPLETED', NOW(), NOW())`,
      ),
    ).rejects.toThrow(/sales_total_non_negative/);
  });

  it('rejects raw INSERT with negative subtotal', async () => {
    await expect(
      prisma.$executeRawUnsafe(
        `INSERT INTO sales
           (id, "storeId", "receiptNo", subtotal, total, "paymentType",
            "paidAmount", status, "createdAt", "updatedAt")
         VALUES
           (gen_random_uuid(), gen_random_uuid()::text,
            'CHK-TEST-SUB', -1, 0, 'CASH', 0, 'COMPLETED', NOW(), NOW())`,
      ),
    ).rejects.toThrow(/sales_subtotal_non_negative/);
  });
});
