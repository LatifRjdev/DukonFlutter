# Loyalty Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a full loyalty points program — settings CRUD, points accrual/redemption/expiry, birthday discount, welcome points — gated behind `hasLoyalty` on BIZ+ plans.

**Architecture:** New `loyalty/` NestJS module (settings + customer balance + expiry cron) + surgical changes to `SalesService.create` (accrual/redemption/birthday logic inside the existing `$transaction`). Flutter adds a settings page, POS redemption UI, and customer history panel. The `LoyaltyTransaction` ledger table is the source of truth; `customer.loyaltyPoints` is a denormalized cache kept in sync by every earn/redeem/expire operation.

**Tech Stack:** NestJS + Prisma + PostgreSQL (backend); Flutter + BLoC (frontend); `@nestjs/schedule` for cron (already wired in `AppModule`).

---

## File map

**Create (backend):**
- `api/prisma/migrations/20260706000000_add_loyalty/migration.sql` — schema migration
- `api/src/modules/loyalty/loyalty.module.ts`
- `api/src/modules/loyalty/loyalty.service.ts`
- `api/src/modules/loyalty/loyalty.controller.ts`
- `api/src/modules/loyalty/dto/update-loyalty-settings.dto.ts`
- `api/src/modules/loyalty/loyalty.service.spec.ts`
- `api/src/modules/loyalty/loyalty.controller.spec.ts`

**Create (Flutter):**
- `app/lib/data/datasources/remote/loyalty_remote_datasource.dart`
- `app/lib/data/repositories/loyalty_repository_impl.dart`
- `app/lib/domain/repositories/loyalty_repository.dart`
- `app/lib/domain/entities/loyalty_transaction.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_settings_bloc.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_settings_event.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_settings_state.dart`
- `app/lib/presentation/pages/settings/loyalty_settings_page.dart`
- `app/test/presentation/blocs/loyalty/loyalty_settings_bloc_test.dart`
- `app/test/presentation/blocs/pos/cart_bloc_loyalty_test.dart`

**Modify (backend):**
- `api/prisma/schema.prisma` — add `LoyaltyTransaction` model + `LoyaltyTxType` enum + `hasLoyalty` on `SubscriptionPlanConfig`
- `api/src/modules/sales/sales.service.ts` — loyalty integration in `create()`
- `api/src/modules/sales/dto/create-sale.dto.ts` — add `redemptionPoints`
- `api/src/modules/sales/sales.module.ts` — import `LoyaltyModule`
- `api/src/app.module.ts` — import `LoyaltyModule`
- `api/src/modules/sales/sales.service.spec.ts` — add loyalty test cases

**Modify (Flutter):**
- `app/lib/presentation/blocs/pos/cart_state.dart` — add loyalty fields
- `app/lib/presentation/blocs/pos/cart_event.dart` — add loyalty events
- `app/lib/presentation/blocs/pos/cart_bloc.dart` — loyalty balance + redemption handlers
- `app/lib/presentation/pages/pos/pos_checkout_page.dart` — redemption UI
- `app/lib/presentation/pages/customer/customer_detail_page.dart` — transaction history
- `app/lib/core/constants/api_endpoints.dart` — add loyalty endpoints
- `app/lib/core/router/route_names.dart` — add `loyaltySettings` route
- `app/lib/core/router/app_router.dart` — register loyalty settings route
- `app/lib/presentation/pages/settings/settings_page.dart` — add loyalty tile
- `app/lib/core/services/thermal_printer_service.dart` — points line on receipt

---

## Task 1: Schema migration

**Files:**
- Modify: `api/prisma/schema.prisma`
- Create: `api/prisma/migrations/20260706000000_add_loyalty/migration.sql`

- [ ] **Step 1: Add `LoyaltyTxType` enum and `LoyaltyTransaction` model to schema.prisma**

Open `api/prisma/schema.prisma`. After the last `enum` block, add:

```prisma
enum LoyaltyTxType {
  EARN
  REDEEM
  EXPIRE
  ADJUST
}
```

After `model LoyaltySettings { ... }`, add:

```prisma
model LoyaltyTransaction {
  id           String        @id @default(uuid())
  customerId   String
  customer     Customer      @relation(fields: [customerId], references: [id], onDelete: Cascade)
  storeId      String
  store        Store         @relation(fields: [storeId], references: [id], onDelete: Cascade)
  type         LoyaltyTxType
  points       Int
  saleId       String?
  sale         Sale?         @relation(fields: [saleId], references: [id], onDelete: SetNull)
  expiresAt    DateTime?
  sourceEarnId String?
  note         String?
  createdAt    DateTime      @default(now())

  @@index([customerId, createdAt(sort: Desc)])
  @@index([expiresAt])
  @@map("loyalty_transactions")
}
```

Also add back-relations on `Customer`, `Store`, and `Sale` models:

In `model Customer`, add:
```prisma
  loyaltyTransactions LoyaltyTransaction[]
```

In `model Store`, add:
```prisma
  loyaltyTransactions LoyaltyTransaction[]
```

In `model Sale`, add:
```prisma
  loyaltyTransactions LoyaltyTransaction[]
```

- [ ] **Step 2: Add `hasLoyalty` to `SubscriptionPlanConfig`**

In `model SubscriptionPlanConfig`, add after `hasInvestments`:

```prisma
  hasLoyalty   Boolean @default(false)
```

- [ ] **Step 3: Run migration**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma migrate dev --name add_loyalty
```

Expected: migration file created in `prisma/migrations/`, Prisma client regenerated with no errors.

- [ ] **Step 4: Update plan configs — enable hasLoyalty on BIZ and PREMIUM**

Create `api/prisma/migrations/20260706000001_loyalty_plan_flags/migration.sql`:

```sql
UPDATE subscription_plan_configs
SET has_loyalty = true
WHERE plan IN ('BUSINESS', 'PREMIUM');
```

Run it:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma migrate dev --name loyalty_plan_flags
```

- [ ] **Step 5: Verify schema compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma validate
npx tsc --noEmit 2>&1 | tail -5
```

Expected: no output from tsc.

- [ ] **Step 6: Commit**

```bash
git add api/prisma/schema.prisma api/prisma/migrations/
git commit -m "feat(db): add LoyaltyTransaction table + hasLoyalty plan flag (Spec J)"
```

---

## Task 2: LoyaltyService — settings CRUD, balance, earn/redeem helpers

**Files:**
- Create: `api/src/modules/loyalty/loyalty.module.ts`
- Create: `api/src/modules/loyalty/loyalty.service.ts`
- Create: `api/src/modules/loyalty/dto/update-loyalty-settings.dto.ts`

- [ ] **Step 1: Create `update-loyalty-settings.dto.ts`**

```ts
// api/src/modules/loyalty/dto/update-loyalty-settings.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

export class UpdateLoyaltySettingsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isEnabled?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  pointsPerAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amountForPoints?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  pointValue?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  welcomePoints?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  birthdayDiscount?: number | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  pointsExpireDays?: number | null;
}
```

- [ ] **Step 2: Create `loyalty.service.ts`**

```ts
// api/src/modules/loyalty/loyalty.service.ts
import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateLoyaltySettingsDto } from './dto/update-loyalty-settings.dto';
import { Prisma } from '@prisma/client';

// Helper: returns true if customer birthday day+month matches today (UTC).
export function isBirthday(birthday: Date): boolean {
  const today = new Date();
  return (
    birthday.getUTCMonth() === today.getUTCMonth() &&
    birthday.getUTCDate() === today.getUTCDate()
  );
}

// Helper: adds N calendar days to a date.
export function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

type PrismaTx = Omit<PrismaService, '$connect' | '$disconnect' | '$on' | '$transaction' | '$use' | '$extends'>;

@Injectable()
export class LoyaltyService {
  constructor(private prisma: PrismaService) {}

  async getSettings(storeId: string) {
    return this.prisma.loyaltySettings.upsert({
      where: { storeId },
      update: {},
      create: {
        storeId,
        isEnabled: false,
        pointsPerAmount: 1,
        amountForPoints: new Prisma.Decimal(100),
        pointValue: new Prisma.Decimal('0.01'),
        welcomePoints: 0,
      },
    });
  }

  async updateSettings(storeId: string, dto: UpdateLoyaltySettingsDto) {
    await this.getSettings(storeId); // ensure row exists
    return this.prisma.loyaltySettings.update({
      where: { storeId },
      data: {
        ...(dto.isEnabled !== undefined && { isEnabled: dto.isEnabled }),
        ...(dto.pointsPerAmount !== undefined && { pointsPerAmount: dto.pointsPerAmount }),
        ...(dto.amountForPoints !== undefined && { amountForPoints: new Prisma.Decimal(dto.amountForPoints) }),
        ...(dto.pointValue !== undefined && { pointValue: new Prisma.Decimal(dto.pointValue) }),
        ...(dto.welcomePoints !== undefined && { welcomePoints: dto.welcomePoints }),
        ...('birthdayDiscount' in dto && {
          birthdayDiscount: dto.birthdayDiscount != null ? new Prisma.Decimal(dto.birthdayDiscount) : null,
        }),
        ...('pointsExpireDays' in dto && { pointsExpireDays: dto.pointsExpireDays ?? null }),
      },
    });
  }

  async getCustomerBalance(storeId: string, customerId: string) {
    const [customer, transactions] = await Promise.all([
      this.prisma.customer.findFirst({
        where: { id: customerId, storeId },
        select: { loyaltyPoints: true },
      }),
      this.prisma.loyaltyTransaction.findMany({
        where: { customerId, storeId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    return {
      points: customer?.loyaltyPoints ?? 0,
      transactions,
    };
  }

  // Called INSIDE an existing $transaction from SalesService.
  async earnPoints(
    tx: PrismaTx,
    opts: {
      customerId: string;
      storeId: string;
      saleId: string;
      points: number;
      expiresAt: Date | null;
    },
  ): Promise<void> {
    if (opts.points <= 0) return;
    await tx.loyaltyTransaction.create({
      data: {
        customerId: opts.customerId,
        storeId: opts.storeId,
        type: 'EARN',
        points: opts.points,
        saleId: opts.saleId,
        expiresAt: opts.expiresAt,
      },
    });
    await tx.customer.update({
      where: { id: opts.customerId },
      data: { loyaltyPoints: { increment: opts.points } },
    });
  }

  // Called INSIDE an existing $transaction from SalesService.
  async redeemPoints(
    tx: PrismaTx,
    opts: {
      customerId: string;
      storeId: string;
      saleId: string;
      points: number;
    },
  ): Promise<void> {
    if (opts.points <= 0) return;
    await tx.loyaltyTransaction.create({
      data: {
        customerId: opts.customerId,
        storeId: opts.storeId,
        type: 'REDEEM',
        points: -opts.points,
        saleId: opts.saleId,
      },
    });
    await tx.customer.update({
      where: { id: opts.customerId },
      data: { loyaltyPoints: { decrement: opts.points } },
    });
  }

  @Cron('0 2 * * *') // 02:00 UTC daily
  async expireOverduePoints(): Promise<{ expired: number; customersAffected: number }> {
    const now = new Date();

    // IDs of EARN transactions already expired (have a matching EXPIRE row)
    const alreadyExpired = await this.prisma.loyaltyTransaction.findMany({
      where: { type: 'EXPIRE', sourceEarnId: { not: null } },
      select: { sourceEarnId: true },
    });
    const expiredEarnIds = new Set(
      alreadyExpired.map((r) => r.sourceEarnId!),
    );

    const overdueEarns = await this.prisma.loyaltyTransaction.findMany({
      where: {
        type: 'EARN',
        expiresAt: { lt: now },
        NOT: expiredEarnIds.size > 0 ? { id: { in: [...expiredEarnIds] } } : undefined,
      },
      take: 100,
    });

    if (overdueEarns.length === 0) return { expired: 0, customersAffected: 0 };

    const affectedCustomers = new Set(overdueEarns.map((e) => e.customerId));

    await this.prisma.$transaction(
      overdueEarns.map((earn) =>
        this.prisma.loyaltyTransaction.create({
          data: {
            customerId: earn.customerId,
            storeId: earn.storeId,
            type: 'EXPIRE',
            points: -earn.points,
            sourceEarnId: earn.id,
            note: `Points from ${earn.createdAt.toISOString()} expired`,
          },
        }),
      ),
    );

    // Decrement each affected customer's balance by their expired total
    for (const customerId of affectedCustomers) {
      const expiredTotal = overdueEarns
        .filter((e) => e.customerId === customerId)
        .reduce((sum, e) => sum + e.points, 0);
      await this.prisma.customer.update({
        where: { id: customerId },
        data: { loyaltyPoints: { decrement: expiredTotal } },
      });
    }

    return { expired: overdueEarns.length, customersAffected: affectedCustomers.size };
  }
}
```

- [ ] **Step 3: Create `loyalty.module.ts`**

```ts
// api/src/modules/loyalty/loyalty.module.ts
import { Module } from '@nestjs/common';
import { LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';

@Module({
  controllers: [LoyaltyController],
  providers: [LoyaltyService],
  exports: [LoyaltyService],
})
export class LoyaltyModule {}
```

- [ ] **Step 4: Verify it compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep loyalty
```

Expected: no output (the controller import will fail — that's fine until Task 3).

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/loyalty/
git commit -m "feat(loyalty): LoyaltyService — settings CRUD, balance, earn/redeem, expiry cron"
```

---

## Task 3: LoyaltyController + register module

**Files:**
- Create: `api/src/modules/loyalty/loyalty.controller.ts`
- Modify: `api/src/app.module.ts`

- [ ] **Step 1: Create `loyalty.controller.ts`**

```ts
// api/src/modules/loyalty/loyalty.controller.ts
import {
  Controller,
  Get,
  Put,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { LoyaltyService } from './loyalty.service';
import { UpdateLoyaltySettingsDto } from './dto/update-loyalty-settings.dto';

@ApiTags('Loyalty')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)
@RequiresFeature('hasLoyalty')
@Controller('stores/:storeId/loyalty')
export class LoyaltyController {
  constructor(private readonly loyaltyService: LoyaltyService) {}

  @Get('settings')
  @ApiOperation({ summary: 'Get loyalty program settings' })
  getSettings(@Param('storeId') storeId: string) {
    return this.loyaltyService.getSettings(storeId);
  }

  @Put('settings')
  @ApiOperation({ summary: 'Update loyalty program settings' })
  updateSettings(
    @Param('storeId') storeId: string,
    @Body() dto: UpdateLoyaltySettingsDto,
  ) {
    return this.loyaltyService.updateSettings(storeId, dto);
  }

  @Get('customers/:customerId/balance')
  @ApiOperation({ summary: 'Get customer loyalty balance + last 20 transactions' })
  getCustomerBalance(
    @Param('storeId') storeId: string,
    @Param('customerId') customerId: string,
  ) {
    return this.loyaltyService.getCustomerBalance(storeId, customerId);
  }
}
```

- [ ] **Step 2: Register `LoyaltyModule` in `app.module.ts`**

In `api/src/app.module.ts`, add the import and add to `imports` array:

```ts
import { LoyaltyModule } from './modules/loyalty/loyalty.module';
```

Add `LoyaltyModule` to the `imports` array (alongside other feature modules like `DiscountsModule`).

- [ ] **Step 3: Verify full compile**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1
```

Expected: zero errors.

- [ ] **Step 4: Run existing tests — must stay green**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest --no-coverage 2>&1 | tail -5
```

Expected: 241 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/loyalty/loyalty.controller.ts api/src/app.module.ts
git commit -m "feat(loyalty): LoyaltyController + register LoyaltyModule in AppModule"
```

---

## Task 4: LoyaltyService unit tests

**Files:**
- Create: `api/src/modules/loyalty/loyalty.service.spec.ts`

- [ ] **Step 1: Create the spec file**

```ts
// api/src/modules/loyalty/loyalty.service.spec.ts
import { Test } from '@nestjs/testing';
import { SchedulerRegistry } from '@nestjs/schedule';
import { LoyaltyService, isBirthday, addDays } from './loyalty.service';
import { PrismaService } from '../../prisma/prisma.service';

// ---- Prisma fake ----
type CustomerRow = { id: string; storeId: string; loyaltyPoints: number; totalSpent: any; birthday: Date | null };
type TxRow = { id: string; customerId: string; storeId: string; type: string; points: number; saleId: string | null; expiresAt: Date | null; sourceEarnId: string | null; createdAt: Date };

function makeFake() {
  const customers = new Map<string, CustomerRow>();
  const txs = new Map<string, TxRow>();
  let seq = 0;

  const loyaltySettings = {
    upsert: jest.fn(async ({ where, create }: any) => {
      return { storeId: where.storeId, isEnabled: false, pointsPerAmount: 1, amountForPoints: '100', pointValue: '0.01', welcomePoints: 0, birthdayDiscount: null, pointsExpireDays: null, ...create };
    }),
    update: jest.fn(async ({ data }: any) => data),
    findMany: jest.fn(async () => []),
    findUnique: jest.fn(async () => null),
  };

  const customer = {
    findFirst: jest.fn(async ({ where }: any) => customers.get(where.id) ?? null),
    update: jest.fn(async ({ where, data }: any) => {
      const c = customers.get(where.id);
      if (!c) throw new Error('customer not found');
      if (data.loyaltyPoints?.increment) c.loyaltyPoints += data.loyaltyPoints.increment;
      if (data.loyaltyPoints?.decrement) c.loyaltyPoints -= data.loyaltyPoints.decrement;
      return c;
    }),
  };

  const loyaltyTransaction = {
    create: jest.fn(async ({ data }: any) => {
      const id = `tx-${++seq}`;
      const row: TxRow = { id, customerId: data.customerId, storeId: data.storeId, type: data.type, points: data.points, saleId: data.saleId ?? null, expiresAt: data.expiresAt ?? null, sourceEarnId: data.sourceEarnId ?? null, createdAt: new Date() };
      txs.set(id, row);
      return row;
    }),
    findMany: jest.fn(async ({ where }: any) => {
      return [...txs.values()].filter((t) => {
        if (where?.type && t.type !== where.type) return false;
        if (where?.sourceEarnId?.not === null) return t.sourceEarnId !== null;
        if (where?.expiresAt?.lt && t.expiresAt && t.expiresAt >= where.expiresAt.lt) return false;
        return true;
      });
    }),
  };

  const api: any = {
    loyaltySettings,
    customer,
    loyaltyTransaction,
    $transaction: jest.fn(async (ops: any) => {
      if (Array.isArray(ops)) return Promise.all(ops);
      return ops(api);
    }),
    _customers: customers,
    _txs: txs,
  };
  return api;
}

describe('isBirthday', () => {
  it('should return true when day and month match today', () => {
    const today = new Date();
    const bday = new Date(Date.UTC(2000, today.getUTCMonth(), today.getUTCDate()));
    expect(isBirthday(bday)).toBe(true);
  });

  it('should return false for tomorrow', () => {
    const tomorrow = addDays(new Date(), 1);
    const bday = new Date(Date.UTC(2000, tomorrow.getUTCMonth(), tomorrow.getUTCDate()));
    expect(isBirthday(bday)).toBe(false);
  });
});

describe('LoyaltyService', () => {
  let service: LoyaltyService;
  let prisma: ReturnType<typeof makeFake>;

  function seedCustomer(opts: Partial<CustomerRow> = {}) {
    const c: CustomerRow = { id: 'cust-1', storeId: 'store-1', loyaltyPoints: 0, totalSpent: 0, birthday: null, ...opts };
    prisma._customers.set(c.id, c);
    return c;
  }

  beforeEach(async () => {
    prisma = makeFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        LoyaltyService,
        { provide: PrismaService, useValue: prisma },
        { provide: SchedulerRegistry, useValue: {} },
      ],
    }).compile();
    service = moduleRef.get(LoyaltyService);
  });

  describe('getSettings', () => {
    it('should upsert default settings when none exist', async () => {
      await service.getSettings('store-1');
      expect(prisma.loyaltySettings.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ where: { storeId: 'store-1' } }),
      );
    });
  });

  describe('getCustomerBalance', () => {
    it('should return 0 points when customer has no transactions', async () => {
      seedCustomer({ loyaltyPoints: 0 });
      const result = await service.getCustomerBalance('store-1', 'cust-1');
      expect(result.points).toBe(0);
      expect(result.transactions).toEqual([]);
    });
  });

  describe('earnPoints', () => {
    it('should create EARN transaction and increment customer loyaltyPoints', async () => {
      seedCustomer({ loyaltyPoints: 0 });
      await service.earnPoints(prisma, {
        customerId: 'cust-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        points: 10,
        expiresAt: null,
      });
      expect(prisma._customers.get('cust-1')!.loyaltyPoints).toBe(10);
      const tx = [...prisma._txs.values()][0];
      expect(tx.type).toBe('EARN');
      expect(tx.points).toBe(10);
    });

    it('should not create transaction when points is 0', async () => {
      seedCustomer();
      await service.earnPoints(prisma, { customerId: 'cust-1', storeId: 'store-1', saleId: 'sale-1', points: 0, expiresAt: null });
      expect(prisma._txs.size).toBe(0);
    });
  });

  describe('redeemPoints', () => {
    it('should create REDEEM transaction and decrement loyaltyPoints', async () => {
      seedCustomer({ loyaltyPoints: 50 });
      await service.redeemPoints(prisma, { customerId: 'cust-1', storeId: 'store-1', saleId: 'sale-1', points: 30 });
      expect(prisma._customers.get('cust-1')!.loyaltyPoints).toBe(20);
      const tx = [...prisma._txs.values()][0];
      expect(tx.type).toBe('REDEEM');
      expect(tx.points).toBe(-30);
    });
  });

  describe('expireOverduePoints', () => {
    it('should create EXPIRE transaction and decrement balance for overdue EARN', async () => {
      seedCustomer({ loyaltyPoints: 100 });
      // Seed an overdue EARN tx directly in the map
      const pastDate = new Date(Date.now() - 86400_000);
      prisma._txs.set('earn-1', { id: 'earn-1', customerId: 'cust-1', storeId: 'store-1', type: 'EARN', points: 100, saleId: null, expiresAt: pastDate, sourceEarnId: null, createdAt: new Date(Date.now() - 10 * 86400_000) });

      // Override findMany to return the seeded tx
      prisma.loyaltyTransaction.findMany
        .mockResolvedValueOnce([]) // first call: already-expired set
        .mockResolvedValueOnce([prisma._txs.get('earn-1')]); // second: overdue earns

      const result = await service.expireOverduePoints();
      expect(result.expired).toBe(1);
      expect(result.customersAffected).toBe(1);
      expect(prisma._customers.get('cust-1')!.loyaltyPoints).toBe(0);
    });

    it('should not double-expire already-expired transactions', async () => {
      seedCustomer({ loyaltyPoints: 0 });
      prisma.loyaltyTransaction.findMany
        .mockResolvedValueOnce([{ sourceEarnId: 'earn-1' }]) // already expired
        .mockResolvedValueOnce([]); // no new overdue
      const result = await service.expireOverduePoints();
      expect(result.expired).toBe(0);
    });

    it('should return zeros when no overdue transactions exist', async () => {
      prisma.loyaltyTransaction.findMany.mockResolvedValue([]);
      const result = await service.expireOverduePoints();
      expect(result.expired).toBe(0);
      expect(result.customersAffected).toBe(0);
    });
  });
});
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest loyalty.service.spec --no-coverage 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add api/src/modules/loyalty/loyalty.service.spec.ts
git commit -m "test(loyalty): unit tests for LoyaltyService earn/redeem/expire/birthday"
```

---

## Task 5: LoyaltyController spec

**Files:**
- Create: `api/src/modules/loyalty/loyalty.controller.spec.ts`

- [ ] **Step 1: Create controller spec**

```ts
// api/src/modules/loyalty/loyalty.controller.spec.ts
import { Test } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { PrismaService } from '../../prisma/prisma.service';

const mockSettings = {
  storeId: 'store-biz',
  isEnabled: true,
  pointsPerAmount: 1,
  amountForPoints: '100',
  pointValue: '0.01',
  welcomePoints: 50,
  birthdayDiscount: null,
  pointsExpireDays: 365,
};

describe('LoyaltyController', () => {
  let controller: LoyaltyController;
  let loyaltyService: jest.Mocked<LoyaltyService>;
  let prismaMock: any;

  function makePrismaForPlan(hasLoyalty: boolean) {
    return {
      subscription: {
        findUnique: jest.fn(async () => ({ plan: hasLoyalty ? 'BUSINESS' : 'START', status: 'ACTIVE' })),
      },
      subscriptionPlanConfig: {
        findUnique: jest.fn(async () => ({ plan: hasLoyalty ? 'BUSINESS' : 'START', hasLoyalty })),
      },
    };
  }

  async function buildModule(hasLoyalty: boolean) {
    prismaMock = makePrismaForPlan(hasLoyalty);
    const loyaltyServiceMock = {
      getSettings: jest.fn(async () => mockSettings),
      updateSettings: jest.fn(async () => mockSettings),
      getCustomerBalance: jest.fn(async () => ({ points: 0, transactions: [] })),
    } as unknown as jest.Mocked<LoyaltyService>;

    const moduleRef = await Test.createTestingModule({
      controllers: [LoyaltyController],
      providers: [
        { provide: LoyaltyService, useValue: loyaltyServiceMock },
        { provide: PrismaService, useValue: prismaMock },
        Reflector,
        SubscriptionGuard,
      ],
    }).compile();

    controller = moduleRef.get(LoyaltyController);
    loyaltyService = moduleRef.get(LoyaltyService) as jest.Mocked<LoyaltyService>;
    return moduleRef;
  }

  describe('getSettings', () => {
    it('should return settings for BIZ store', async () => {
      await buildModule(true);
      const result = await controller.getSettings('store-biz');
      expect(result).toEqual(mockSettings);
      expect(loyaltyService.getSettings).toHaveBeenCalledWith('store-biz');
    });
  });

  describe('updateSettings', () => {
    it('should update and return settings', async () => {
      await buildModule(true);
      const result = await controller.updateSettings('store-biz', { isEnabled: true });
      expect(result).toEqual(mockSettings);
    });
  });

  describe('getCustomerBalance', () => {
    it('should return balance for customer in BIZ store', async () => {
      await buildModule(true);
      const result = await controller.getCustomerBalance('store-biz', 'cust-1');
      expect(result).toEqual({ points: 0, transactions: [] });
    });
  });
});
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest loyalty.controller.spec --no-coverage 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 3: Run full suite**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest --no-coverage 2>&1 | grep "Tests:"
```

Expected: ≥ 254 passed.

- [ ] **Step 4: Commit**

```bash
git add api/src/modules/loyalty/loyalty.controller.spec.ts
git commit -m "test(loyalty): controller spec — settings CRUD + feature gate"
```

---

## Task 6: SalesService — loyalty integration

**Files:**
- Modify: `api/src/modules/sales/dto/create-sale.dto.ts`
- Modify: `api/src/modules/sales/sales.service.ts`
- Modify: `api/src/modules/sales/sales.module.ts`

- [ ] **Step 1: Add `redemptionPoints` to `CreateSaleDto`**

In `api/src/modules/sales/dto/create-sale.dto.ts`, add at the end of `CreateSaleDto`:

```ts
  @ApiPropertyOptional({ description: 'Loyalty points to redeem (reduces total by points × pointValue)' })
  @IsOptional()
  @IsInt()
  @Min(0)
  redemptionPoints?: number;
```

Also add `IsInt` to the imports from `class-validator`.

- [ ] **Step 2: Add `LoyaltyModule` import to `SalesModule`**

In `api/src/modules/sales/sales.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { SalesController } from './sales.controller';
import { SalesService } from './sales.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';

@Module({
  imports: [NotificationsModule, LoyaltyModule],
  controllers: [SalesController],
  providers: [SalesService],
  exports: [SalesService],
})
export class SalesModule {}
```

- [ ] **Step 3: Inject `LoyaltyService` into `SalesService`**

In `api/src/modules/sales/sales.service.ts`:

Add import:
```ts
import { LoyaltyService, isBirthday, addDays } from '../loyalty/loyalty.service';
```

Update constructor:
```ts
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private audit: AuditLogService,
    private notifications: NotificationsService,
    private loyaltyService: LoyaltyService,
  ) {}
```

- [ ] **Step 4: Add loyalty logic inside `create()` — after `customer.update` and before `return sale`**

Inside the `$transaction` callback in `create()`, after the existing `customer.update` block (which updates `totalSpent` and `debt`), add:

```ts
      // === LOYALTY INTEGRATION ===
      // Only runs when: loyalty enabled + BIZ+ plan + customer attached
      let pointsEarned = 0;
      let birthdayDiscountApplied = false;

      if (dto.customerId) {
        // Check if this store's plan has hasLoyalty
        const planConfig = await tx.subscriptionPlanConfig.findUnique({
          where: {
            plan: (
              await tx.subscription.findUnique({
                where: { storeId },
                select: { plan: true },
              })
            )?.plan ?? 'START',
          },
          select: { hasLoyalty: true },
        });

        if (planConfig?.hasLoyalty) {
          const loyaltySettings = await tx.loyaltySettings.findUnique({
            where: { storeId },
          });

          if (loyaltySettings?.isEnabled) {
            const customer = await tx.customer.findUnique({
              where: { id: dto.customerId },
              select: { loyaltyPoints: true, totalSpent: true, birthday: true },
            });

            let effectiveTotal = total; // Prisma.Decimal

            // Birthday discount (auto-applied if today is customer's birthday)
            if (
              loyaltySettings.birthdayDiscount &&
              customer?.birthday &&
              isBirthday(customer.birthday)
            ) {
              const factor = new Prisma.Decimal(1).sub(
                new Prisma.Decimal(loyaltySettings.birthdayDiscount).div(100),
              );
              effectiveTotal = effectiveTotal.mul(factor).toDecimalPlaces(2);
              birthdayDiscountApplied = true;
            }

            // Validate and apply redemption
            if (dto.redemptionPoints && dto.redemptionPoints > 0) {
              const currentPoints = customer?.loyaltyPoints ?? 0;
              if (dto.redemptionPoints > currentPoints) {
                throw new BadRequestException(
                  `Cannot redeem ${dto.redemptionPoints} points — customer only has ${currentPoints}`,
                );
              }
              const pointValueDecimal = new Prisma.Decimal(loyaltySettings.pointValue);
              const redemptionValue = pointValueDecimal.mul(dto.redemptionPoints);
              effectiveTotal = Prisma.Decimal.max(
                effectiveTotal.sub(redemptionValue),
                new Prisma.Decimal(0),
              );
              await this.loyaltyService.redeemPoints(tx, {
                customerId: dto.customerId,
                storeId,
                saleId: sale.id,
                points: dto.redemptionPoints,
              });
            }

            // Earn points on effective total
            // First sale = totalSpent was 0 BEFORE this transaction's increment
            const isFirstSale = (customer?.totalSpent ?? new Prisma.Decimal(0)).eq(0);
            const earned =
              Math.floor(
                effectiveTotal
                  .div(new Prisma.Decimal(loyaltySettings.amountForPoints))
                  .toNumber(),
              ) * loyaltySettings.pointsPerAmount +
              (isFirstSale ? loyaltySettings.welcomePoints : 0);

            if (earned > 0) {
              const expiresAt = loyaltySettings.pointsExpireDays
                ? addDays(new Date(), loyaltySettings.pointsExpireDays)
                : null;
              await this.loyaltyService.earnPoints(tx, {
                customerId: dto.customerId,
                storeId,
                saleId: sale.id,
                points: earned,
                expiresAt,
              });
              pointsEarned = earned;
            }
          }
        }
      }
      // === END LOYALTY ===

      return { ...sale, pointsEarned, birthdayDiscountApplied };
```

- [ ] **Step 5: Verify full compile**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1
```

Expected: zero errors.

- [ ] **Step 6: Run existing sales tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest sales.service.spec --no-coverage 2>&1 | tail -10
```

Expected: all existing tests still pass (loyalty logic is no-op when `planConfig.hasLoyalty` is false or no loyalty settings).

- [ ] **Step 7: Commit**

```bash
git add api/src/modules/sales/ 
git commit -m "feat(sales): integrate loyalty accrual/redemption/birthday into sale create"
```

---

## Task 7: SalesService loyalty tests

**Files:**
- Modify: `api/src/modules/sales/sales.service.spec.ts`

The existing spec uses `makePrismaFake()`. We need to add `loyaltySettings`, `subscription`, `subscriptionPlanConfig`, and `loyaltyTransaction` fakes to it, plus inject a mock `LoyaltyService`.

- [ ] **Step 1: Extend `makePrismaFake()` in `sales.service.spec.ts`**

Inside `makePrismaFake()`, add these tables alongside the existing `products` and `sales` maps:

```ts
  const loyaltyTxs: any[] = [];

  // Add to the returned tx/api object:
  loyaltySettings: {
    findUnique: jest.fn(async () => ({
      storeId: 'store-1',
      isEnabled: true,
      pointsPerAmount: 1,
      amountForPoints: new Prisma.Decimal('100'),
      pointValue: new Prisma.Decimal('0.01'),
      welcomePoints: 50,
      birthdayDiscount: null,
      pointsExpireDays: 365,
    })),
  },
  subscription: {
    findUnique: jest.fn(async () => ({ plan: 'BUSINESS', status: 'ACTIVE' })),
  },
  subscriptionPlanConfig: {
    findUnique: jest.fn(async () => ({ plan: 'BUSINESS', hasLoyalty: true })),
  },
  loyaltyTransaction: {
    create: jest.fn(async (args: any) => {
      loyaltyTxs.push(args.data);
      return args.data;
    }),
  },
  _loyaltyTxs: loyaltyTxs,
```

Also add `customer` map to the fake (customers are referenced in loyalty logic):

```ts
  const customers = new Map<string, any>();

  // In the returned object:
  customer: {
    findFirst: jest.fn(async ({ where }: any) => customers.get(where.id) ?? null),
    findUnique: jest.fn(async ({ where }: any) => customers.get(where.id) ?? null),
    update: jest.fn(async ({ where, data }: any) => {
      const c = customers.get(where.id);
      if (!c) return null;
      if (data.loyaltyPoints?.increment) c.loyaltyPoints = (c.loyaltyPoints || 0) + data.loyaltyPoints.increment;
      if (data.loyaltyPoints?.decrement) c.loyaltyPoints = (c.loyaltyPoints || 0) - data.loyaltyPoints.decrement;
      if (data.totalSpent?.increment) c.totalSpent = (c.totalSpent || 0) + Number(data.totalSpent.increment);
      if (data.debt?.increment) c.debt = (c.debt || 0) + Number(data.debt.increment);
      return c;
    }),
  },
  _customers: customers,
```

- [ ] **Step 2: Update `SalesService` provider in `beforeEach` to include `LoyaltyService`**

In the `beforeEach` block, add:

```ts
    const loyaltyServiceMock = {
      earnPoints: jest.fn(async () => undefined),
      redeemPoints: jest.fn(async () => undefined),
    };
```

And add it to providers:
```ts
    { provide: LoyaltyService, useValue: loyaltyServiceMock },
```

Store a reference: `let loyaltyService: any;` and assign `loyaltyService = moduleRef.get(LoyaltyService);`

- [ ] **Step 3: Add loyalty test cases**

Add a new `describe` block at the end of the spec:

```ts
describe('loyalty integration', () => {
  function seedProduct(price = 300) {
    const p = {
      id: 'prod-loyalty',
      storeId: 'store-1',
      name: 'Widget',
      sellPrice: new Prisma.Decimal(price),
      costPrice: new Prisma.Decimal(100),
      quantity: 99,
    };
    prisma._products.set(p.id, p);
    return p;
  }

  function seedCustomer(opts: any = {}) {
    const c = { id: 'cust-loyalty', storeId: 'store-1', loyaltyPoints: 0, totalSpent: new Prisma.Decimal(0), birthday: null, ...opts };
    prisma._customers.set(c.id, c);
    return c;
  }

  const baseDto = {
    customerId: 'cust-loyalty',
    paymentType: 'CASH' as any,
    paidAmount: 300,
    items: [{ productId: 'prod-loyalty', quantity: 1 }],
  };

  it('should call earnPoints when loyalty is enabled and plan is BIZ', async () => {
    seedProduct(300);
    seedCustomer();
    await service.create('store-1', baseDto);
    expect(loyaltyService.earnPoints).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ points: expect.any(Number), customerId: 'cust-loyalty' }),
    );
  });

  it('should add welcomePoints on first sale (totalSpent === 0)', async () => {
    seedProduct(300);
    seedCustomer({ totalSpent: new Prisma.Decimal(0) });
    await service.create('store-1', baseDto);
    const call = loyaltyService.earnPoints.mock.calls[0][1];
    // 300/100 * 1 = 3 base + 50 welcome = 53
    expect(call.points).toBe(53);
  });

  it('should NOT add welcomePoints on second sale (totalSpent > 0)', async () => {
    seedProduct(300);
    seedCustomer({ totalSpent: new Prisma.Decimal(500) });
    await service.create('store-1', baseDto);
    const call = loyaltyService.earnPoints.mock.calls[0][1];
    // 300/100 * 1 = 3 base only
    expect(call.points).toBe(3);
  });

  it('should call redeemPoints when redemptionPoints is provided', async () => {
    seedProduct(300);
    seedCustomer({ loyaltyPoints: 100 });
    await service.create('store-1', { ...baseDto, redemptionPoints: 50 });
    expect(loyaltyService.redeemPoints).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ points: 50, customerId: 'cust-loyalty' }),
    );
  });

  it('should throw BadRequestException when redemptionPoints exceeds balance', async () => {
    seedProduct(300);
    seedCustomer({ loyaltyPoints: 10 });
    await expect(service.create('store-1', { ...baseDto, redemptionPoints: 50 }))
      .rejects.toBeInstanceOf(BadRequestException);
  });

  it('should apply birthdayDiscount when customer birthday matches today', async () => {
    seedProduct(300);
    const today = new Date();
    const birthday = new Date(Date.UTC(1990, today.getUTCMonth(), today.getUTCDate()));
    seedCustomer({ birthday });
    // Mock loyaltySettings to include 10% birthday discount
    prisma.loyaltySettings.findUnique.mockResolvedValueOnce({
      storeId: 'store-1', isEnabled: true, pointsPerAmount: 1,
      amountForPoints: new Prisma.Decimal('100'), pointValue: new Prisma.Decimal('0.01'),
      welcomePoints: 0, birthdayDiscount: new Prisma.Decimal('10'), pointsExpireDays: null,
    });
    await service.create('store-1', baseDto);
    // effectiveTotal = 300 * 0.9 = 270 → 270/100 * 1 = 2 points
    const call = loyaltyService.earnPoints.mock.calls[0][1];
    expect(call.points).toBe(2);
  });

  it('should NOT earn points when loyalty isEnabled is false', async () => {
    seedProduct(300);
    seedCustomer();
    prisma.loyaltySettings.findUnique.mockResolvedValueOnce({ isEnabled: false });
    await service.create('store-1', baseDto);
    expect(loyaltyService.earnPoints).not.toHaveBeenCalled();
  });

  it('should NOT earn points when plan is START (hasLoyalty = false)', async () => {
    seedProduct(300);
    seedCustomer();
    prisma.subscriptionPlanConfig.findUnique.mockResolvedValueOnce({ plan: 'START', hasLoyalty: false });
    await service.create('store-1', baseDto);
    expect(loyaltyService.earnPoints).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest sales.service.spec --no-coverage 2>&1 | tail -10
```

Expected: all tests pass (including the new 7 loyalty tests).

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/sales/sales.service.spec.ts
git commit -m "test(sales): loyalty integration tests — earn, welcome, redeem, birthday, plan-gate"
```

---

## Task 8: Flutter data layer

**Files:**
- Create: `app/lib/domain/entities/loyalty_transaction.dart`
- Create: `app/lib/domain/repositories/loyalty_repository.dart`
- Create: `app/lib/data/datasources/remote/loyalty_remote_datasource.dart`
- Create: `app/lib/data/repositories/loyalty_repository_impl.dart`
- Modify: `app/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Create loyalty entity**

```dart
// app/lib/domain/entities/loyalty_transaction.dart
class LoyaltyTransaction {
  final String id;
  final String customerId;
  final String storeId;
  final String type; // EARN | REDEEM | EXPIRE | ADJUST
  final int points;
  final String? saleId;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.type,
    required this.points,
    this.saleId,
    this.expiresAt,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) =>
      LoyaltyTransaction(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        storeId: json['storeId'] as String,
        type: json['type'] as String,
        points: (json['points'] as num).toInt(),
        saleId: json['saleId'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
```

- [ ] **Step 2: Create loyalty repository interface**

```dart
// app/lib/domain/repositories/loyalty_repository.dart
import '../entities/loyalty_transaction.dart';

abstract class LoyaltyRepository {
  Future<Map<String, dynamic>> getSettings(String storeId);
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data);
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId);
}
```

- [ ] **Step 3: Add API endpoints**

In `app/lib/core/constants/api_endpoints.dart`, add:

```dart
  // Loyalty
  static String loyaltySettings(String storeId) =>
      '/stores/$storeId/loyalty/settings';
  static String loyaltyCustomerBalance(String storeId, String customerId) =>
      '/stores/$storeId/loyalty/customers/$customerId/balance';
```

- [ ] **Step 4: Create remote datasource**

```dart
// app/lib/data/datasources/remote/loyalty_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/loyalty_transaction.dart';

abstract class LoyaltyRemoteDatasource {
  Future<Map<String, dynamic>> getSettings(String storeId);
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data);
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId);
}

class LoyaltyRemoteDatasourceImpl implements LoyaltyRemoteDatasource {
  final DioClient _dioClient;

  LoyaltyRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) async {
    final response =
        await _dioClient.get(ApiEndpoints.loyaltySettings(storeId));
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data) async {
    final response = await _dioClient.put(
        ApiEndpoints.loyaltySettings(storeId),
        data: data);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId) async {
    try {
      final response = await _dioClient.get(
          ApiEndpoints.loyaltyCustomerBalance(storeId, customerId));
      final data = response.data as Map<String, dynamic>;
      final txList = (data['transactions'] as List? ?? [])
          .map((t) => LoyaltyTransaction.fromJson(t as Map<String, dynamic>))
          .toList();
      return (
        points: (data['points'] as num).toInt(),
        transactions: txList,
      );
    } on DioException {
      // 403 = plan not eligible, treat as no loyalty
      return (points: 0, transactions: <LoyaltyTransaction>[]);
    }
  }
}
```

- [ ] **Step 5: Create repository impl**

```dart
// app/lib/data/repositories/loyalty_repository_impl.dart
import '../../domain/entities/loyalty_transaction.dart';
import '../../domain/repositories/loyalty_repository.dart';
import '../datasources/remote/loyalty_remote_datasource.dart';

class LoyaltyRepositoryImpl implements LoyaltyRepository {
  final LoyaltyRemoteDatasource _remote;

  LoyaltyRepositoryImpl({required LoyaltyRemoteDatasource remote})
      : _remote = remote;

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) =>
      _remote.getSettings(storeId);

  @override
  Future<Map<String, dynamic>> updateSettings(
          String storeId, Map<String, dynamic> data) =>
      _remote.updateSettings(storeId, data);

  @override
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId) =>
          _remote.getCustomerBalance(storeId, customerId);
}
```

- [ ] **Step 6: Analyze**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/domain/entities/loyalty_transaction.dart lib/domain/repositories/loyalty_repository.dart lib/data/datasources/remote/loyalty_remote_datasource.dart lib/data/repositories/loyalty_repository_impl.dart 2>&1
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add app/lib/domain/entities/loyalty_transaction.dart app/lib/domain/repositories/ app/lib/data/datasources/remote/loyalty_remote_datasource.dart app/lib/data/repositories/loyalty_repository_impl.dart app/lib/core/constants/api_endpoints.dart
git commit -m "feat(loyalty): Flutter data layer — entity, repository, datasource"
```

---

## Task 9: LoyaltySettingsBloc + LoyaltySettingsPage

**Files:**
- Create: `app/lib/presentation/blocs/loyalty/loyalty_settings_event.dart`
- Create: `app/lib/presentation/blocs/loyalty/loyalty_settings_state.dart`
- Create: `app/lib/presentation/blocs/loyalty/loyalty_settings_bloc.dart`
- Create: `app/lib/presentation/pages/settings/loyalty_settings_page.dart`
- Modify: `app/lib/core/router/route_names.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: Create events**

```dart
// app/lib/presentation/blocs/loyalty/loyalty_settings_event.dart
import 'package:equatable/equatable.dart';

abstract class LoyaltySettingsEvent extends Equatable {
  const LoyaltySettingsEvent();
  @override
  List<Object?> get props => [];
}

class LoyaltySettingsLoadRequested extends LoyaltySettingsEvent {
  final String storeId;
  const LoyaltySettingsLoadRequested(this.storeId);
  @override
  List<Object?> get props => [storeId];
}

class LoyaltySettingsSaveRequested extends LoyaltySettingsEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const LoyaltySettingsSaveRequested(this.storeId, this.data);
  @override
  List<Object?> get props => [storeId, data];
}
```

- [ ] **Step 2: Create states**

```dart
// app/lib/presentation/blocs/loyalty/loyalty_settings_state.dart
import 'package:equatable/equatable.dart';

abstract class LoyaltySettingsState extends Equatable {
  const LoyaltySettingsState();
  @override
  List<Object?> get props => [];
}

class LoyaltySettingsInitial extends LoyaltySettingsState {}
class LoyaltySettingsLoading extends LoyaltySettingsState {}

class LoyaltySettingsLoaded extends LoyaltySettingsState {
  final Map<String, dynamic> settings;
  const LoyaltySettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

class LoyaltySettingsSaved extends LoyaltySettingsState {
  final Map<String, dynamic> settings;
  const LoyaltySettingsSaved(this.settings);
  @override
  List<Object?> get props => [settings];
}

class LoyaltySettingsError extends LoyaltySettingsState {
  final String message;
  const LoyaltySettingsError(this.message);
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Create bloc**

```dart
// app/lib/presentation/blocs/loyalty/loyalty_settings_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/loyalty_repository.dart';
import 'loyalty_settings_event.dart';
import 'loyalty_settings_state.dart';

class LoyaltySettingsBloc
    extends Bloc<LoyaltySettingsEvent, LoyaltySettingsState> {
  final LoyaltyRepository _repository;

  LoyaltySettingsBloc({required LoyaltyRepository repository})
      : _repository = repository,
        super(LoyaltySettingsInitial()) {
    on<LoyaltySettingsLoadRequested>(_onLoad);
    on<LoyaltySettingsSaveRequested>(_onSave);
  }

  Future<void> _onLoad(
      LoyaltySettingsLoadRequested event, Emitter<LoyaltySettingsState> emit) async {
    emit(LoyaltySettingsLoading());
    try {
      final settings = await _repository.getSettings(event.storeId);
      emit(LoyaltySettingsLoaded(settings));
    } catch (e) {
      emit(LoyaltySettingsError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSave(
      LoyaltySettingsSaveRequested event, Emitter<LoyaltySettingsState> emit) async {
    emit(LoyaltySettingsLoading());
    try {
      final settings =
          await _repository.updateSettings(event.storeId, event.data);
      emit(LoyaltySettingsSaved(settings));
    } catch (e) {
      emit(LoyaltySettingsError(mapErrorToUserMessage(e)));
    }
  }
}
```

- [ ] **Step 4: Create `LoyaltySettingsPage`**

```dart
// app/lib/presentation/pages/settings/loyalty_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/loyalty/loyalty_settings_bloc.dart';
import '../../blocs/loyalty/loyalty_settings_event.dart';
import '../../blocs/loyalty/loyalty_settings_state.dart';

class LoyaltySettingsPage extends StatefulWidget {
  final String storeId;
  const LoyaltySettingsPage({super.key, required this.storeId});

  @override
  State<LoyaltySettingsPage> createState() => _LoyaltySettingsPageState();
}

class _LoyaltySettingsPageState extends State<LoyaltySettingsPage> {
  final _pointsPerAmountCtrl = TextEditingController();
  final _amountForPointsCtrl = TextEditingController();
  final _pointValueCtrl = TextEditingController();
  final _welcomePointsCtrl = TextEditingController();
  final _birthdayDiscountCtrl = TextEditingController();
  final _expireDaysCtrl = TextEditingController();
  bool _isEnabled = false;

  @override
  void dispose() {
    _pointsPerAmountCtrl.dispose();
    _amountForPointsCtrl.dispose();
    _pointValueCtrl.dispose();
    _welcomePointsCtrl.dispose();
    _birthdayDiscountCtrl.dispose();
    _expireDaysCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> s) {
    _isEnabled = s['isEnabled'] as bool? ?? false;
    _pointsPerAmountCtrl.text = '${s['pointsPerAmount'] ?? 1}';
    _amountForPointsCtrl.text = '${s['amountForPoints'] ?? 100}';
    _pointValueCtrl.text = '${s['pointValue'] ?? 0.01}';
    _welcomePointsCtrl.text = '${s['welcomePoints'] ?? 0}';
    _birthdayDiscountCtrl.text = s['birthdayDiscount']?.toString() ?? '';
    _expireDaysCtrl.text = s['pointsExpireDays']?.toString() ?? '';
    setState(() {});
  }

  void _save(BuildContext context) {
    context.read<LoyaltySettingsBloc>().add(
          LoyaltySettingsSaveRequested(widget.storeId, {
            'isEnabled': _isEnabled,
            'pointsPerAmount': int.tryParse(_pointsPerAmountCtrl.text) ?? 1,
            'amountForPoints': double.tryParse(_amountForPointsCtrl.text) ?? 100,
            'pointValue': double.tryParse(_pointValueCtrl.text) ?? 0.01,
            'welcomePoints': int.tryParse(_welcomePointsCtrl.text) ?? 0,
            if (_birthdayDiscountCtrl.text.isNotEmpty)
              'birthdayDiscount': double.tryParse(_birthdayDiscountCtrl.text),
            if (_expireDaysCtrl.text.isNotEmpty)
              'pointsExpireDays': int.tryParse(_expireDaysCtrl.text),
          }),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoyaltySettingsBloc, LoyaltySettingsState>(
      listener: (context, state) {
        if (state is LoyaltySettingsLoaded) _populate(state.settings);
        if (state is LoyaltySettingsSaved) {
          _populate(state.settings);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Настройки сохранены')),
          );
        }
        if (state is LoyaltySettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final loading = state is LoyaltySettingsLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Программа лояльности')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Активна'),
                      value: _isEnabled,
                      onChanged: (v) => setState(() => _isEnabled = v),
                    ),
                    const Divider(),
                    _field('За каждые N сом', _amountForPointsCtrl, TextInputType.number),
                    _field('Начислять X баллов', _pointsPerAmountCtrl, TextInputType.number),
                    _field('1 балл = N сом', _pointValueCtrl, const TextInputType.numberWithOptions(decimal: true)),
                    _field('Приветственные баллы', _welcomePointsCtrl, TextInputType.number),
                    _field('Скидка в ДР, %', _birthdayDiscountCtrl, const TextInputType.numberWithOptions(decimal: true)),
                    _field('Срок действия, дней (пусто = не истекают)', _expireDaysCtrl, TextInputType.number),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: loading ? null : () => _save(context),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );
}
```

- [ ] **Step 5: Add route constant**

In `app/lib/core/router/route_names.dart`, add inside the Settings section:

```dart
  static const String loyaltySettings = '/settings/loyalty';
```

- [ ] **Step 6: Register route in `app_router.dart`**

Add import:
```dart
import '../../presentation/pages/settings/loyalty_settings_page.dart';
```

Add GoRoute (near the discounts route):
```dart
GoRoute(
  path: RouteNames.loyaltySettings,
  builder: (context, state) {
    final storeId = state.extra as String? ?? '';
    return BlocProvider(
      create: (context) => LoyaltySettingsBloc(
        repository: LoyaltyRepositoryImpl(
          remote: LoyaltyRemoteDatasourceImpl(
            dioClient: context.read<DioClient>(),
          ),
        ),
      )..add(LoyaltySettingsLoadRequested(storeId)),
      child: LoyaltySettingsPage(storeId: storeId),
    );
  },
),
```

- [ ] **Step 7: Add tile in `settings_page.dart`**

In the "Магазин" section (where "Скидки" tile is), add after the Discounts tile:

```dart
_buildDivider(),
_buildTile(Icons.card_giftcard_outlined, 'Программа лояльности',
  onTap: () => context.push(RouteNames.loyaltySettings, extra: _getStoreId())),
```

- [ ] **Step 8: Analyze**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | grep -v "^Analyzing" | head -20
```

Expected: 0 issues.

- [ ] **Step 9: Run Flutter tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --no-pub 2>&1 | tail -5
```

Expected: all existing tests pass.

- [ ] **Step 10: Commit**

```bash
git add app/lib/presentation/blocs/loyalty/ app/lib/presentation/pages/settings/loyalty_settings_page.dart app/lib/core/router/
git commit -m "feat(loyalty): Flutter loyalty settings bloc + page + route"
```

---

## Task 10: CartBloc loyalty — balance loading + redemption

**Files:**
- Modify: `app/lib/presentation/blocs/pos/cart_state.dart`
- Modify: `app/lib/presentation/blocs/pos/cart_event.dart`
- Modify: `app/lib/presentation/blocs/pos/cart_bloc.dart`
- Create: `app/test/presentation/blocs/pos/cart_bloc_loyalty_test.dart`

- [ ] **Step 1: Extend `CartState`**

In `app/lib/presentation/blocs/pos/cart_state.dart`, add fields to `CartState`:

```dart
  final int customerLoyaltyPoints;   // available balance (0 if no loyalty)
  final double loyaltyPointValue;    // 1 point = N сом (from settings)
  final int redemptionPoints;        // how many points cashier wants to redeem

  const CartState({
    this.items = const [],
    this.discount = 0,
    this.discountType = 'FIXED',
    this.customerId,
    this.customerName,
    this.customerLoyaltyPoints = 0,
    this.loyaltyPointValue = 0,
    this.redemptionPoints = 0,
  });

  double get loyaltyRedemptionValue => redemptionPoints * loyaltyPointValue;
  double get total => subtotal - discountAmount - loyaltyRedemptionValue;

  // In copyWith, add:
  int? customerLoyaltyPoints,
  double? loyaltyPointValue,
  int? redemptionPoints,
  // ...and in return:
  customerLoyaltyPoints: customerLoyaltyPoints ?? this.customerLoyaltyPoints,
  loyaltyPointValue: loyaltyPointValue ?? this.loyaltyPointValue,
  redemptionPoints: redemptionPoints ?? this.redemptionPoints,

  // In props, add:
  customerLoyaltyPoints, loyaltyPointValue, redemptionPoints,
```

Note: the existing `total` getter changes — subtract `loyaltyRedemptionValue`. This is fine because when `redemptionPoints == 0` the value is 0.

- [ ] **Step 2: Add new events**

In `app/lib/presentation/blocs/pos/cart_event.dart`, add:

```dart
class LoyaltyBalanceLoaded extends CartEvent {
  final int points;
  final double pointValue;
  const LoyaltyBalanceLoaded({required this.points, required this.pointValue});
  @override
  List<Object?> get props => [points, pointValue];
}

class RedemptionPointsChanged extends CartEvent {
  final int points;
  const RedemptionPointsChanged(this.points);
  @override
  List<Object?> get props => [points];
}
```

- [ ] **Step 3: Update `CartBloc`**

In `app/lib/presentation/blocs/pos/cart_bloc.dart`, add imports and new handlers:

```dart
// Add import
import '../../../domain/repositories/loyalty_repository.dart';

// In constructor, add optional repository:
final LoyaltyRepository? _loyaltyRepository;
final String? _storeId;

CartBloc({
  CartLocalDatasource? persistence,
  LoyaltyRepository? loyaltyRepository,
  String? storeId,
}) : _persistence = persistence,
     _loyaltyRepository = loyaltyRepository,
     _storeId = storeId,
     super(const CartState()) {
  on<CartItemAdded>(_onItemAdded);
  on<CartItemRemoved>(_onItemRemoved);
  on<CartItemQuantityChanged>(_onQuantityChanged);
  on<CartDiscountApplied>(_onDiscountApplied);
  on<CartCleared>(_onCleared);
  on<CartCustomerSelected>(_onCustomerSelected);
  on<CartRestored>(_onRestored);
  on<LoyaltyBalanceLoaded>(_onLoyaltyBalanceLoaded);
  on<RedemptionPointsChanged>(_onRedemptionPointsChanged);
}

// Update _onCustomerSelected to load loyalty balance:
void _onCustomerSelected(CartCustomerSelected event, Emitter<CartState> emit) {
  if (event.customerId == null) {
    emit(state.copyWith(
      customerId: null, customerName: null,
      customerLoyaltyPoints: 0, loyaltyPointValue: 0, redemptionPoints: 0,
    ));
    return;
  }
  emit(state.copyWith(
    customerId: event.customerId, customerName: event.customerName,
    redemptionPoints: 0,
  ));
  _schedulePersist();
  // Load loyalty balance asynchronously
  if (_loyaltyRepository != null && _storeId != null && event.customerId != null) {
    _loyaltyRepository!.getCustomerBalance(_storeId!, event.customerId!).then((result) {
      if (!isClosed) {
        add(LoyaltyBalanceLoaded(
          points: result.points,
          pointValue: 0.01, // default; settings loaded separately
        ));
      }
    });
  }
}

void _onLoyaltyBalanceLoaded(LoyaltyBalanceLoaded event, Emitter<CartState> emit) {
  emit(state.copyWith(
    customerLoyaltyPoints: event.points,
    loyaltyPointValue: event.pointValue,
  ));
}

void _onRedemptionPointsChanged(RedemptionPointsChanged event, Emitter<CartState> emit) {
  // Cap redemption at available points and at floor(total / pointValue)
  final maxByBalance = state.customerLoyaltyPoints;
  final maxByTotal = state.loyaltyPointValue > 0
      ? (state.subtotal - state.discountAmount) ~/ state.loyaltyPointValue
      : 0;
  final capped = event.points.clamp(0, maxByBalance < maxByTotal ? maxByBalance : maxByTotal);
  emit(state.copyWith(redemptionPoints: capped));
  _schedulePersist();
}
```

- [ ] **Step 4: Create `cart_bloc_loyalty_test.dart`**

```dart
// app/test/presentation/blocs/pos/cart_bloc_loyalty_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukon/domain/entities/loyalty_transaction.dart';
import 'package:dukon/domain/repositories/loyalty_repository.dart';
import 'package:dukon/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukon/presentation/blocs/pos/cart_event.dart';
import 'package:dukon/presentation/blocs/pos/cart_state.dart';
import 'package:dukon/domain/entities/product.dart';

class MockLoyaltyRepository extends Mock implements LoyaltyRepository {}

Product makeProduct({double price = 500}) => Product(
      id: 'p1', storeId: 's1', name: 'Widget', barcode: null,
      sellPrice: price, costPrice: 200, quantity: 99,
      unit: 'PCS', isActive: true,
      categoryId: null, categoryName: null, imageUrl: null,
      description: null, minQuantity: 0,
    );

void main() {
  late MockLoyaltyRepository loyaltyRepo;

  setUp(() {
    loyaltyRepo = MockLoyaltyRepository();
    when(() => loyaltyRepo.getCustomerBalance(any(), any())).thenAnswer(
      (_) async => (points: 200, transactions: <LoyaltyTransaction>[]),
    );
    when(() => loyaltyRepo.getSettings(any())).thenAnswer(
      (_) async => {'pointValue': 0.01},
    );
  });

  group('loyalty balance loading', () {
    blocTest<CartBloc, CartState>(
      'should load loyalty balance when customer is selected',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo, storeId: 's1'),
      act: (bloc) {
        bloc.add(const CartItemAdded(product: null)); // just to have a state
        bloc.add(const CartCustomerSelected(customerId: 'c1', customerName: 'Ali'));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<CartState>().having((s) => s.customerId, 'customerId', 'c1'),
        isA<CartState>().having((s) => s.customerLoyaltyPoints, 'points', 200),
      ],
      skip: 0,
    );

    blocTest<CartBloc, CartState>(
      'should clear loyalty when customer is removed',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo, storeId: 's1'),
      seed: () => const CartState(customerId: 'c1', customerLoyaltyPoints: 200, loyaltyPointValue: 0.01),
      act: (bloc) => bloc.add(const CartCustomerSelected(customerId: null)),
      expect: () => [
        isA<CartState>()
            .having((s) => s.customerLoyaltyPoints, 'points', 0)
            .having((s) => s.redemptionPoints, 'redemption', 0),
      ],
    );
  });

  group('redemption', () {
    blocTest<CartBloc, CartState>(
      'should cap redemption at floor(total / pointValue)',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo, storeId: 's1'),
      seed: () => const CartState(
        items: [],
        customerLoyaltyPoints: 5000,
        loyaltyPointValue: 0.01,
      ),
      act: (bloc) => bloc.add(const RedemptionPointsChanged(99999)),
      // subtotal = 0, so maxByTotal = 0
      expect: () => [
        isA<CartState>().having((s) => s.redemptionPoints, 'capped', 0),
      ],
    );

    blocTest<CartBloc, CartState>(
      'should apply partial redemption within cart total',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo, storeId: 's1'),
      seed: () => CartState(
        items: [CartItem(productId: 'p1', productName: 'W', unitPrice: 500, quantity: 1, unit: 'PCS')],
        customerLoyaltyPoints: 5000,
        loyaltyPointValue: 0.01,
      ),
      act: (bloc) => bloc.add(const RedemptionPointsChanged(100)),
      // total = 500, pointValue = 0.01, maxByTotal = 500/0.01 = 50000
      // cap = min(5000, 50000) = 5000 but requested 100 → 100
      expect: () => [
        isA<CartState>()
            .having((s) => s.redemptionPoints, 'points', 100)
            .having((s) => s.loyaltyRedemptionValue, 'value', 1.0),
      ],
    );
  });
}
```

- [ ] **Step 5: Run the new tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/presentation/blocs/pos/cart_bloc_loyalty_test.dart --no-pub 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 6: Run full Flutter test suite**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --no-pub 2>&1 | tail -5
```

Expected: ≥ 447 passed.

- [ ] **Step 7: Commit**

```bash
git add app/lib/presentation/blocs/pos/ app/test/presentation/blocs/pos/cart_bloc_loyalty_test.dart
git commit -m "feat(loyalty): CartBloc loyalty balance + redemption state"
```

---

## Task 11: POS checkout redemption UI

**Files:**
- Modify: `app/lib/presentation/pages/pos/pos_checkout_page.dart`

- [ ] **Step 1: Add redemption chip + bottom sheet**

In `pos_checkout_page.dart`, locate the area above the "Оформить" button. Add this widget before the button:

```dart
// Insert this helper method in the _PosCheckoutPageState class:
Widget _buildLoyaltyWidget(BuildContext context, CartState cart) {
  if (cart.customerLoyaltyPoints <= 0 || cart.loyaltyPointValue <= 0) {
    return const SizedBox.shrink();
  }
  final redeemValue = (cart.redemptionPoints * cart.loyaltyPointValue).toStringAsFixed(2);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: InkWell(
      onTap: () => _showRedemptionSheet(context, cart),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cart.redemptionPoints > 0
                    ? '${cart.redemptionPoints} баллов = -$redeemValue сом'
                    : '${cart.customerLoyaltyPoints} баллов доступно',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    ),
  );
}

void _showRedemptionSheet(BuildContext context, CartState cart) {
  int selected = cart.redemptionPoints;
  final maxByBalance = cart.customerLoyaltyPoints;
  final maxByTotal = cart.loyaltyPointValue > 0
      ? (cart.subtotal - cart.discountAmount) ~/ cart.loyaltyPointValue
      : 0;
  final maxRedeemable = maxByBalance < maxByTotal ? maxByBalance : maxByTotal;

  showModalBottomSheet(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setInner) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Списать баллы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Доступно: ${cart.customerLoyaltyPoints} баллов'),
            const SizedBox(height: 16),
            Slider(
              value: selected.toDouble(),
              min: 0,
              max: maxRedeemable.toDouble(),
              divisions: maxRedeemable > 0 ? maxRedeemable : 1,
              label: '$selected',
              onChanged: (v) => setInner(() => selected = v.round()),
            ),
            Text(
              'Скидка: -${(selected * cart.loyaltyPointValue).toStringAsFixed(2)} сом',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<CartBloc>().add(RedemptionPointsChanged(selected));
                  Navigator.pop(ctx);
                },
                child: const Text('Применить'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

Then in the `build` method, wrap the checkout button area with a `BlocBuilder<CartBloc, CartState>` and call `_buildLoyaltyWidget(context, cart)` just above the "Оформить" button.

Also ensure the checkout payload includes `redemptionPoints`:

In the method that calls `context.read<CheckoutBloc>().add(CheckoutSubmitted(...))`, add:
```dart
redemptionPoints: cart.redemptionPoints,
```

In `CreateSaleDto` (Flutter side, wherever the DTO is assembled), add the `redemptionPoints` field.

- [ ] **Step 2: Analyze**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/pos/pos_checkout_page.dart 2>&1
```

Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/pos/pos_checkout_page.dart
git commit -m "feat(loyalty): POS checkout redemption chip + bottom sheet"
```

---

## Task 12: CustomerDetailPage transaction history

**Files:**
- Modify: `app/lib/presentation/pages/customer/customer_detail_page.dart`

- [ ] **Step 1: Load loyalty balance in `CustomerDetailBloc`**

In `customer_detail_page.dart`, after the customer is loaded, make a separate call to fetch loyalty balance. The simplest approach: make the call directly in the page using `FutureBuilder`, keeping it self-contained without touching `CustomerDetailBloc`.

Add a `LoyaltyRemoteDatasource` instance to the page and display transactions:

```dart
// In _CustomerDetailPageState, add:
List<LoyaltyTransaction> _loyaltyTxs = [];
int _loyaltyPoints = 0;
bool _loyaltyExpanded = false;

Future<void> _loadLoyalty(String storeId, String customerId) async {
  try {
    final repo = LoyaltyRepositoryImpl(
      remote: LoyaltyRemoteDatasourceImpl(dioClient: context.read<DioClient>()),
    );
    final result = await repo.getCustomerBalance(storeId, customerId);
    if (mounted) {
      setState(() {
        _loyaltyPoints = result.points;
        _loyaltyTxs = result.transactions;
      });
    }
  } catch (_) {}
}
```

Call `_loadLoyalty(storeId, customerId)` in `initState` (after bloc load).

Add to the UI below the existing loyaltyPoints chip:

```dart
if (_loyaltyTxs.isNotEmpty)
  ExpansionTile(
    title: const Text('История баллов'),
    initiallyExpanded: false,
    children: _loyaltyTxs.take(10).map((tx) {
      final sign = tx.points > 0 ? '+' : '';
      final color = tx.type == 'EARN'
          ? Colors.green
          : tx.type == 'REDEEM'
              ? Colors.blue
              : Colors.grey;
      return ListTile(
        dense: true,
        leading: Icon(
          tx.type == 'EARN' ? Icons.add_circle_outline
              : tx.type == 'REDEEM' ? Icons.remove_circle_outline
              : Icons.timer_off_outlined,
          color: color, size: 20,
        ),
        title: Text('$sign${tx.points} баллов', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle: Text(_formatDate(tx.createdAt)),
        trailing: tx.expiresAt != null && tx.type == 'EARN'
            ? Text('до ${_formatDate(tx.expiresAt!)}', style: const TextStyle(fontSize: 11, color: Colors.orange))
            : null,
      );
    }).toList(),
  ),
```

Add helper:
```dart
String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
```

- [ ] **Step 2: Analyze**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/customer/customer_detail_page.dart 2>&1
```

Expected: 0 issues.

- [ ] **Step 3: Run full Flutter tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/lib/presentation/pages/customer/customer_detail_page.dart
git commit -m "feat(loyalty): customer detail page — loyalty transaction history panel"
```

---

## Task 13: Receipt loyalty line

**Files:**
- Modify: `app/lib/core/services/thermal_printer_service.dart`

- [ ] **Step 1: Add loyalty line to thermal receipt**

In `thermal_printer_service.dart`, find the `_buildReceiptBytes` method (or equivalent). After the total line, add:

```dart
// Add pointsEarned and newBalance parameters to the method signature:
// _buildReceiptBytes({ ..., int pointsEarned = 0, int newBalance = 0, DateTime? pointsExpiresAt })

if (pointsEarned > 0) {
  bytes += generator.text(
    'Начислено баллов: +$pointsEarned',
    styles: const PosStyles(align: PosAlign.left),
  );
  bytes += generator.text(
    'Ваш баланс: $newBalance баллов',
    styles: const PosStyles(align: PosAlign.left),
  );
  if (pointsExpiresAt != null) {
    final d = pointsExpiresAt;
    bytes += generator.text(
      'Действует до: ${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}',
      styles: const PosStyles(align: PosAlign.left),
    );
  }
}
```

Update all call sites of `_buildReceiptBytes` to pass `pointsEarned`, `newBalance`, and `pointsExpiresAt` from the sale response (`sale.pointsEarned`, `sale.pointsBalance`, computed `expiresAt = now + pointsExpireDays`).

- [ ] **Step 2: Analyze**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/core/services/thermal_printer_service.dart 2>&1
```

Expected: 0 issues.

- [ ] **Step 3: Run full test suite — final gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx jest --no-coverage 2>&1 | grep "Tests:"

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --no-pub 2>&1 | tail -5

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | grep -v "^Analyzing"
```

Expected:
- API: ≥ 254 tests passed
- Flutter: ≥ 447 tests passed
- tsc: 0 errors
- dart analyze: 0 issues

- [ ] **Step 4: Commit**

```bash
git add app/lib/core/services/thermal_printer_service.dart
git commit -m "feat(loyalty): receipt loyalty line — points earned + balance + expiry"
```

---

## Self-review: spec coverage check

| Spec requirement | Task |
|---|---|
| Schema migration: LoyaltyTransaction + hasLoyalty | Task 1 |
| LoyaltyService settings CRUD | Task 2 |
| LoyaltyService earn/redeem helpers | Task 2 |
| LoyaltyController endpoints | Task 3 |
| RequiresFeature('hasLoyalty') BIZ+ gate | Task 3 |
| LoyaltyService unit tests | Task 4 |
| Controller spec | Task 5 |
| CreateSaleDto.redemptionPoints | Task 6 |
| SalesService: birthday discount | Task 6 |
| SalesService: welcome points on first sale | Task 6 |
| SalesService: points accrual inside $transaction | Task 6 |
| SalesService: redemption validation | Task 6 |
| SalesService loyalty tests (7 cases) | Task 7 |
| Expiry cron | Task 2 |
| Expiry cron tests | Task 4 |
| Flutter data layer (entity, repo, datasource) | Task 8 |
| Flutter loyalty settings page + bloc | Task 9 |
| Flutter settings tile | Task 9 |
| CartBloc loyalty balance + redemption | Task 10 |
| CartBloc loyalty tests | Task 10 |
| POS checkout redemption UI | Task 11 |
| CustomerDetailPage transaction history | Task 12 |
| Receipt loyalty line | Task 13 |
