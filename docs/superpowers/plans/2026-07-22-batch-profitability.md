# Batch Profitability ("Окупаемость партии") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show, per product, the cost/revenue/profit performance of the most recent restock ("batch"), and alert store owners when a batch has stopped selling while a large chunk is still unsold.

**Architecture:** No new inventory data model — every metric is computed on read from data that already exists (`StockMovement`, `SaleItem`, `Product`). Backend adds one new plan-gated sub-endpoint (mirrors the existing `:productId/stock-movements` pattern), one new field on the product-list response, one new daily cron, and two new store-setting thresholds. Flutter adds a badge to the two product-card widgets, a new lazily-loaded section on the product detail page (mirrors the existing `_StockMovementsSection` pattern exactly — direct `DioClient` call, no repository layer, since that's this file's established local convention), and two new fields on the notification-settings screen.

**Tech Stack:** NestJS + Prisma + Jest (backend), Flutter + BLoC/StatefulWidget + Dio (app). See `docs/superpowers/specs/2026-07-22-batch-profitability-design.md` for the full design rationale — read it before starting if anything below is unclear on the "why."

---

## Before you start

- Full spec: `docs/superpowers/specs/2026-07-22-batch-profitability-design.md`
- Run backend tests from `api/`: `npx jest --no-coverage`. Full suite must stay green after every task (currently 43 suites / 415 tests).
- Run backend typecheck: `npx tsc --noEmit` from `api/`.
- Run Flutter tests from `app/`: `flutter test --exclude-tags=golden` (golden tests are unrelated to this feature).
- The dev Postgres DB has pre-existing migration drift (unrelated to this feature) that makes `npx prisma migrate dev` want to reset the whole database. **Do not run `prisma migrate dev` or `prisma migrate reset`.** Task 1 shows the exact workaround already used successfully earlier in this project (hand-write the migration SQL file, apply it directly via `docker exec dukonpro-db psql`, then `npx prisma generate`).
- Three key design decisions this plan implements without asking again (see spec for reasoning if you want it):
  1. New permission key `products.viewProfitability`, granted to ADMIN only (not WAREHOUSE, which already has `products.manage`). OWNER always bypasses via the existing guard short-circuit.
  2. Batch-profitability detail lives on its own endpoint (`GET /:id/batch-profitability`), not embedded in the existing `GET /:id`, because that route has no `@Permissions` decorator today and would otherwise leak the data to every role.
  3. The list endpoint's lightweight `paybackPercent` field is gated by an ad-hoc in-service check (new `hasFeatureFlag`/`checkStaffPermission` helpers), not a route guard, because `GET /products` must stay accessible to CASHIER/WAREHOUSE — only the new field is conditionally included.

---

## Part 1 — Backend

### Task 1: `SubscriptionPlanConfig.hasBatchProfitability` flag

**Files:**
- Modify: `api/prisma/schema.prisma`
- Create: `api/prisma/migrations/20260722000000_add_has_batch_profitability/migration.sql`
- Modify: `api/src/modules/subscriptions/subscriptions.service.ts`
- Test: `api/src/modules/subscriptions/subscriptions.service.spec.ts`

- [ ] **Step 1: Add the column to the schema**

In `api/prisma/schema.prisma`, find the `SubscriptionPlanConfig` model and add one line:

```prisma
model SubscriptionPlanConfig {
  plan           SubscriptionPlan @id
  price          Decimal          @db.Decimal(12, 2)
  maxProducts    Int
  maxStaff       Int
  maxDiscounts   Int
  hasReportsAll  Boolean
  hasExport      Boolean
  hasTelegram    Boolean
  hasAllPush     Boolean
  hasDelivery    Boolean
  hasInventory   Boolean
  hasZakat           Boolean @default(false)
  hasInvestments     Boolean @default(false)
  hasLoyalty         Boolean @default(false)
  hasBatchProfitability Boolean @default(false)

  @@map("subscription_plan_configs")
}
```

- [ ] **Step 2: Write the migration SQL file**

```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260722000000_add_has_batch_profitability
cat > /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260722000000_add_has_batch_profitability/migration.sql << 'EOF'
-- Migration: add hasBatchProfitability flag to subscription_plan_configs.
ALTER TABLE "subscription_plan_configs" ADD COLUMN "hasBatchProfitability" BOOLEAN NOT NULL DEFAULT false;
EOF
```

- [ ] **Step 3: Apply it directly to the dev DB** (bypasses the `prisma migrate dev` drift-reset problem)

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c 'ALTER TABLE subscription_plan_configs ADD COLUMN "hasBatchProfitability" BOOLEAN NOT NULL DEFAULT false;'
```

Expected: `ALTER TABLE`

- [ ] **Step 4: Regenerate the Prisma client**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx prisma generate
```

Expected: `✔ Generated Prisma Client`

- [ ] **Step 5: Write the failing test**

In `api/src/modules/subscriptions/subscriptions.service.spec.ts`, add `upsert` to the existing `subscriptionPlanConfig` fake object inside `makePrismaFake()` (it currently only has `findUnique`):

```typescript
    subscriptionPlanConfig: {
      findUnique: jest.fn(async ({ where }: any) => {
        const prices: Record<string, number> = {
          START: 200,
          BUSINESS: 400,
          PREMIUM: 600,
        };
        if (prices[where.plan] === undefined) return null;
        return { plan: where.plan, price: prices[where.plan] };
      }),
      upsert: jest.fn(async ({ where, create }: any) => ({
        plan: where.plan,
        ...create,
      })),
    },
```

Then add a new `describe` block at the bottom of the file:

```typescript
describe('SubscriptionsService — seedPlanConfigs', () => {
  it('should seed hasBatchProfitability=false for START and true for BUSINESS/PREMIUM', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );
    expect(byPlan.START.create.hasBatchProfitability).toBe(false);
    expect(byPlan.BUSINESS.create.hasBatchProfitability).toBe(true);
    expect(byPlan.PREMIUM.create.hasBatchProfitability).toBe(true);
  });

  it('should patch hasBatchProfitability on the update path too, so an existing row self-heals on next boot', async () => {
    const prisma = makePrismaFake();
    const upsertCalls: any[] = [];
    prisma.subscriptionPlanConfig.upsert = jest.fn(
      async ({ where, create, update }: any) => {
        upsertCalls.push({ where, create, update });
        return { plan: where.plan, ...create };
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: fakeNotifications },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    const service = moduleRef.get(SubscriptionsService);

    await service.onModuleInit();

    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );
    expect(byPlan.BUSINESS.update).toEqual({ hasBatchProfitability: true });
    expect(byPlan.PREMIUM.update).toEqual({ hasBatchProfitability: true });
    expect(byPlan.START.update).toEqual({ hasBatchProfitability: false });
  });
});
```

- [ ] **Step 6: Run the test, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/subscriptions/subscriptions.service.spec.ts -t seedPlanConfigs --no-coverage
```

Expected: FAIL — `create.hasBatchProfitability` is `undefined`, and `update` is `{}` (current code always passes `update: {}`).

- [ ] **Step 7: Implement — update `seedPlanConfigs()`**

In `api/src/modules/subscriptions/subscriptions.service.ts`, update the three plan literals and the upsert call:

```typescript
  private async seedPlanConfigs() {
    const plans = [
      {
        plan: 'START' as const,
        price: 200,
        maxProducts: 500,
        maxStaff: 2,
        maxDiscounts: 0,
        hasReportsAll: false,
        hasExport: false,
        hasTelegram: false,
        hasAllPush: false,
        hasDelivery: false,
        hasInventory: false,
        hasZakat: false,
        hasInvestments: false,
        hasBatchProfitability: false,
      },
      {
        plan: 'BUSINESS' as const,
        price: 400,
        maxProducts: 2000,
        maxStaff: 10,
        maxDiscounts: 5,
        hasReportsAll: true,
        hasExport: false,
        hasTelegram: true,
        hasAllPush: true,
        hasDelivery: true,
        hasInventory: true,
        hasZakat: true,
        hasInvestments: true,
        hasBatchProfitability: true,
      },
      {
        plan: 'PREMIUM' as const,
        price: 600,
        maxProducts: -1,
        maxStaff: -1,
        maxDiscounts: -1,
        hasReportsAll: true,
        hasExport: true,
        hasTelegram: true,
        hasAllPush: true,
        hasDelivery: true,
        hasInventory: true,
        hasZakat: true,
        hasInvestments: true,
        hasBatchProfitability: true,
      },
    ];

    for (const config of plans) {
      await this.prisma.subscriptionPlanConfig.upsert({
        where: { plan: config.plan },
        create: config,
        // BE: `update: {}` used to mean existing rows in a running DB
        // never picked up newly-added flags. Patch hasBatchProfitability
        // explicitly so existing rows self-heal on the next server boot.
        update: { hasBatchProfitability: config.hasBatchProfitability },
      });
    }

    this.logger.log('Subscription plan configs seeded');
  }
```

- [ ] **Step 8: Run the test, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/subscriptions/subscriptions.service.spec.ts --no-coverage
```

Expected: PASS, all tests in the file including the 2 new ones.

- [ ] **Step 9: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

Expected: 0 tsc errors, all suites pass.

- [ ] **Step 10: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/prisma/schema.prisma api/prisma/migrations/20260722000000_add_has_batch_profitability api/src/modules/subscriptions/subscriptions.service.ts api/src/modules/subscriptions/subscriptions.service.spec.ts
git commit -m "feat(subscriptions): add hasBatchProfitability plan flag"
```

---

### Task 2: `products.viewProfitability` permission + `checkStaffPermission` helper

**Files:**
- Create: `api/src/common/guards/permission-check.helper.ts`
- Modify: `api/src/common/guards/permissions.guard.ts`
- Modify: `api/src/common/guards/permissions-matrix.ts`
- Test: `api/src/common/guards/permissions.guard.spec.ts`

This extracts the existing permission-check logic out of `PermissionsGuard` into a plain function so `ProductsService` (Task 5) can reuse the exact same logic for a non-route-blocking, per-request field-inclusion decision, without duplicating (and risking drift from) the guard's logic.

- [ ] **Step 1: Run the existing guard tests first, confirm green baseline**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/common/guards/permissions.guard.spec.ts --no-coverage
```

Expected: PASS, 9/9 (this is the safety net for the refactor in the next steps).

- [ ] **Step 2: Create the extracted helper**

```typescript
// api/src/common/guards/permission-check.helper.ts
import { PrismaService } from '../../prisma/prisma.service';
import { hasDefaultPermission, legacyPermissionKeyFor } from './permissions-matrix';

/**
 * Returns true if `userId` (as staff of `storeId`, or as the store owner)
 * has all of `requiredPermissions`. Never throws — callers that need a
 * hard block (route guards) should throw ForbiddenException themselves
 * based on the boolean result; callers that just want to conditionally
 * shape a response (e.g. include/omit a field) can use the boolean
 * directly.
 *
 * Extracted from PermissionsGuard.canActivate so both the route-level
 * guard and any in-service field-visibility check share one
 * implementation — see permissions.guard.ts for why the DB-override
 * translation (legacyPermissionKeyFor) exists.
 */
export async function checkStaffPermission(
  prisma: PrismaService,
  storeId: string,
  userId: string,
  requiredPermissions: string[],
): Promise<boolean> {
  if (requiredPermissions.length === 0) return true;

  const store = await prisma.store.findUnique({
    where: { id: storeId },
    select: { ownerId: true },
  });
  if (store?.ownerId === userId) return true;

  const staffRecord = await prisma.staff.findUnique({
    where: { storeId_userId: { storeId, userId } },
    select: { role: true, isActive: true },
  });
  if (!staffRecord || !staffRecord.isActive) return false;
  if (staffRecord.role === 'OWNER') return true;

  const legacyKeyByPermission = new Map<string, string>();
  for (const perm of requiredPermissions) {
    const legacyKey = legacyPermissionKeyFor(perm);
    if (legacyKey) legacyKeyByPermission.set(perm, legacyKey);
  }
  const dbPermissionKeys = [...new Set(legacyKeyByPermission.values())];

  const rolePermissions = dbPermissionKeys.length
    ? await prisma.rolePermission.findMany({
        where: {
          storeId,
          role: staffRecord.role,
          permission: { in: dbPermissionKeys },
        },
        select: { permission: true, isGranted: true },
      })
    : [];

  const dbAllow = new Set(
    rolePermissions.filter((rp) => rp.isGranted).map((rp) => rp.permission),
  );
  const dbDeny = new Set(
    rolePermissions.filter((rp) => !rp.isGranted).map((rp) => rp.permission),
  );

  return requiredPermissions.every((perm) => {
    const legacyKey = legacyKeyByPermission.get(perm);
    if (legacyKey) {
      if (dbDeny.has(legacyKey)) return false;
      if (dbAllow.has(legacyKey)) return true;
    }
    return hasDefaultPermission(staffRecord.role, perm);
  });
}
```

- [ ] **Step 3: Refactor the guard to use it (identical behavior, just relocated)**

Replace the body of `api/src/common/guards/permissions.guard.ts` with:

```typescript
import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { checkStaffPermission } from './permission-check.helper';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    const storeId = request.params.storeId;

    if (!userId || !storeId) {
      throw new ForbiddenException('Access denied');
    }

    const allowed = await checkStaffPermission(
      this.prisma,
      storeId,
      userId,
      requiredPermissions,
    );

    if (!allowed) {
      throw new ForbiddenException('You do not have the required permissions');
    }

    return true;
  }
}
```

Note: the original guard distinguished "no store access at all" (`!staffRecord || !staffRecord.isActive` → `'You do not have access to this store'`) from "wrong permission" (`'You do not have the required permissions'`) as two different error messages. The extracted helper collapses both into a single `false`, so both cases now surface as `'You do not have the required permissions'`. Check this doesn't break an existing test asserting the specific message string before proceeding — if it does, adjust the guard to re-check `staffRecord` existence itself before calling the helper, preserving the original two-message behavior.

- [ ] **Step 4: Run the existing guard tests, confirm still green**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/common/guards/permissions.guard.spec.ts --no-coverage
```

Expected: PASS, 9/9 unchanged. If any fail on message-text assertions, apply the fix noted in Step 3 and re-run.

- [ ] **Step 5: Add the new permission key**

In `api/src/common/guards/permissions-matrix.ts`, add `'products.viewProfitability'` to ADMIN's array only:

```typescript
  ADMIN: [
    'staff.manage', 'store.manage', 'roles.manage',
    'products.manage', 'products.delete', 'products.viewProfitability', 'categories.manage',
    'customers.manage', 'suppliers.manage', 'sales.manage', 'sales.refund',
    'shifts.manage', 'payroll.manage', 'payroll.pay', 'expenses.write',
    'zakat.manage', 'reports.view',
    'discounts.write', 'inventory.write', 'deliveries.write', 'investments.write',
  ],
```

CASHIER and WAREHOUSE arrays are unchanged — leaving `products.viewProfitability` out of both means `hasDefaultPermission` returns `false` for them.

- [ ] **Step 6: Write failing tests for the new permission**

Add to `api/src/common/guards/permissions.guard.spec.ts`, inside a new `describe` block:

```typescript
  describe('products.viewProfitability (new permission)', () => {
    it('allows ADMIN by default-matrix fallback (no DB override needed)', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          { storeId: 'store-1', userId: 'admin-1', role: 'ADMIN', isActive: true },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);
      const ctx = makeContext({
        permissions: ['products.viewProfitability'],
        userId: 'admin-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });

    it('denies WAREHOUSE by default (it has products.manage but not products.viewProfitability)', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          { storeId: 'store-1', userId: 'wh-1', role: 'WAREHOUSE', isActive: true },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);
      const ctx = makeContext({
        permissions: ['products.viewProfitability'],
        userId: 'wh-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('denies CASHIER by default', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          { storeId: 'store-1', userId: 'cash-1', role: 'CASHIER', isActive: true },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);
      const ctx = makeContext({
        permissions: ['products.viewProfitability'],
        userId: 'cash-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(ForbiddenException);
    });
  });
```

- [ ] **Step 7: Run, verify pass**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/common/guards/permissions.guard.spec.ts --no-coverage
```

Expected: PASS, 12/12.

- [ ] **Step 8: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 9: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/common/guards/permission-check.helper.ts api/src/common/guards/permissions.guard.ts api/src/common/guards/permissions-matrix.ts api/src/common/guards/permissions.guard.spec.ts
git commit -m "feat(access-control): add products.viewProfitability permission; extract checkStaffPermission helper"
```

---

### Task 3: `hasFeatureFlag` helper + `ProductsService.getBatchProfitability()`

**Files:**
- Create: `api/src/common/guards/feature-flag.helper.ts`
- Modify: `api/src/modules/products/products.service.ts`
- Test: `api/src/modules/products/products.service.spec.ts`

- [ ] **Step 1: Create the feature-flag helper** (mirrors `plan-limit.helper.ts`'s subscription/planConfig lookup exactly)

```typescript
// api/src/common/guards/feature-flag.helper.ts
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Returns whether `storeId`'s current subscription plan has `flag`
 * enabled on SubscriptionPlanConfig. Fail-closed (false) if there's no
 * subscription or no plan config row — unlike assertWithinPlanLimit's
 * fail-open convention, a missing/misconfigured plan should not silently
 * unlock a paid feature.
 */
export async function hasFeatureFlag(
  prisma: PrismaService,
  storeId: string,
  flag: 'hasBatchProfitability',
): Promise<boolean> {
  const sub = await prisma.subscription.findUnique({ where: { storeId } });
  if (!sub) return false;

  const planConfig = await prisma.subscriptionPlanConfig.findUnique({
    where: { plan: sub.plan },
  });
  if (!planConfig) return false;

  return Boolean(planConfig[flag]);
}
```

- [ ] **Step 2: Write the failing test for the core computation**

Add `costPrice` to the fake's `ProductRow` type and add `stockMovement`/`saleItem` fake models in `api/src/modules/products/products.service.spec.ts`'s `makePrismaFake()`:

```typescript
  type ProductRow = {
    id: string;
    storeId: string;
    name: string;
    sku?: string | null;
    barcode?: string | null;
    sellPrice: number;
    costPrice?: number | null;
    quantity: number;
    minQuantity: number;
    unit: string;
    isActive: boolean;
    categoryId?: string | null;
    supplierId?: string | null;
    createdAt: Date;
  };
```

Then, inside the object `makePrismaFake()` returns, add two new fake collections and models (alongside the existing `product` key):

```typescript
  const stockMovements: Array<{
    id: string;
    productId: string;
    type: string;
    quantity: number;
    unitCost: number | null;
    totalCost: number | null;
    createdAt: Date;
  }> = [];
  const saleItems: Array<{
    id: string;
    productId: string;
    quantity: number;
    unitPrice: number;
    costPrice: number | null;
    total: number;
    refundedQuantity: number;
    saleStoreId: string;
    saleCreatedAt: Date;
  }> = [];

  return {
    _rows: rows,
    _stockMovements: stockMovements,
    _saleItems: saleItems,
    stockMovement: {
      findFirst: jest.fn(async ({ where, orderBy }: any) => {
        let matches = stockMovements.filter(
          (m) => m.productId === where.productId && (!where.type || m.type === where.type),
        );
        if (orderBy?.createdAt === 'desc') {
          matches = [...matches].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        }
        return matches[0] ?? null;
      }),
    },
    saleItem: {
      findMany: jest.fn(async ({ where }: any) => {
        return saleItems.filter((si) => {
          if (si.productId !== where.productId) return false;
          if (where.sale?.storeId && si.saleStoreId !== where.sale.storeId) return false;
          if (
            where.sale?.createdAt?.gte &&
            si.saleCreatedAt < where.sale.createdAt.gte
          ) {
            return false;
          }
          return true;
        });
      }),
    },
    // ... existing product: { ... } stays exactly as-is below this point
```

(Keep the existing `product: { ... }` object exactly as it is today, just add the two new sibling keys above it — and add `costPrice: data.costPrice ?? null,` to the `product.create` row-building code so seeded test products can carry a cost price.)

Now add the test itself, in a new `describe` block:

```typescript
describe('ProductsService.getBatchProfitability', () => {
  let service: ProductsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [ProductsService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(ProductsService);
  });

  it('should compute the worked example from the design spec (100@10, sold 33@30, 67 remain)', async () => {
    prisma._rows.set('p1', {
      id: 'p1', storeId: 'store-A', name: 'Widget', sellPrice: 30, costPrice: 10,
      quantity: 67, minQuantity: 0, unit: 'PCS', isActive: true, createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      unitCost: 10, totalCost: 1000, createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si1', productId: 'p1', quantity: 33, unitPrice: 30, costPrice: 10,
      total: 990, refundedQuantity: 0, saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-07-15'),
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.hasBatch).toBe(true);
    expect(result.batchQuantity).toBe(100);
    expect(result.batchCost).toBe(1000);
    expect(result.soldQuantity).toBe(33);
    expect(result.revenue).toBe(990);
    expect(result.profitEarned).toBe(660);
    expect(result.remainingQuantity).toBe(67);
    expect(result.remainingStockValue).toBe(670);
    expect(result.paybackPercent).toBeCloseTo(99);
    expect(result.paybackShortfall).toBeCloseTo(-10);
  });

  it('should net out refunded quantity from sold/revenue/profit', async () => {
    prisma._rows.set('p1', {
      id: 'p1', storeId: 'store-A', name: 'Widget', sellPrice: 30, costPrice: 10,
      quantity: 90, minQuantity: 0, unit: 'PCS', isActive: true, createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      unitCost: 10, totalCost: 1000, createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si1', productId: 'p1', quantity: 10, unitPrice: 30, costPrice: 10,
      total: 300, refundedQuantity: 4, saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-07-15'),
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    // 6 net units sold (10 - 4 refunded), pro-rated revenue = 300/10*6=180
    expect(result.soldQuantity).toBe(6);
    expect(result.revenue).toBe(180);
    expect(result.profitEarned).toBe(120); // 180 - 6*10
  });

  it('should only count sales on or after the anchor purchase date, not earlier ones', async () => {
    prisma._rows.set('p1', {
      id: 'p1', storeId: 'store-A', name: 'Widget', sellPrice: 30, costPrice: 10,
      quantity: 100, minQuantity: 0, unit: 'PCS', isActive: true, createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv-old', productId: 'p1', type: 'PURCHASE', quantity: 50,
      unitCost: 8, totalCost: 400, createdAt: new Date('2026-06-01'),
    });
    prisma._stockMovements.push({
      id: 'mv-new', productId: 'p1', type: 'PURCHASE', quantity: 100,
      unitCost: 10, totalCost: 1000, createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si-old', productId: 'p1', quantity: 5, unitPrice: 30, costPrice: 8,
      total: 150, refundedQuantity: 0, saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-06-15'), // before the newest purchase — excluded
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.batchQuantity).toBe(100); // the newest anchor, not 50
    expect(result.soldQuantity).toBe(0);
    expect(result.revenue).toBe(0);
  });

  it('should return hasBatch=false when the product has no PURCHASE stock movement', async () => {
    prisma._rows.set('p1', {
      id: 'p1', storeId: 'store-A', name: 'Widget', sellPrice: 30, costPrice: 10,
      quantity: 10, minQuantity: 0, unit: 'PCS', isActive: true, createdAt: new Date(),
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.hasBatch).toBe(false);
    expect(result.remainingQuantity).toBe(10);
  });

  it('should throw NotFoundException for a product in a different store', async () => {
    prisma._rows.set('p1', {
      id: 'p1', storeId: 'store-B', name: 'Widget', sellPrice: 30, costPrice: 10,
      quantity: 10, minQuantity: 0, unit: 'PCS', isActive: true, createdAt: new Date(),
    });

    await expect(
      service.getBatchProfitability('store-A', 'p1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
```

- [ ] **Step 3: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/products/products.service.spec.ts -t getBatchProfitability --no-coverage
```

Expected: FAIL — `service.getBatchProfitability` is not a function.

- [ ] **Step 4: Implement the method**

In `api/src/modules/products/products.service.ts`, add `Prisma` to the existing import from `@prisma/client` (already imported) and add this method to the class:

```typescript
  async getBatchProfitability(storeId: string, id: string) {
    const product = await this.prisma.product.findFirst({
      where: { id, storeId, isActive: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const anchor = await this.prisma.stockMovement.findFirst({
      where: { productId: id, type: 'PURCHASE' },
      orderBy: { createdAt: 'desc' },
    });

    const remainingQuantity = product.quantity;
    const remainingStockValue = product.costPrice
      ? Number(product.costPrice) * remainingQuantity
      : null;

    if (!anchor || anchor.totalCost == null) {
      return {
        hasBatch: false,
        batchQuantity: null,
        batchCost: null,
        soldQuantity: null,
        revenue: null,
        profitEarned: null,
        remainingQuantity,
        remainingStockValue,
        paybackPercent: null,
        paybackShortfall: null,
      };
    }

    const soldItems = await this.prisma.saleItem.findMany({
      where: {
        productId: id,
        sale: { storeId, createdAt: { gte: anchor.createdAt } },
      },
      select: { quantity: true, refundedQuantity: true, costPrice: true, total: true },
    });

    let soldQuantity = 0;
    let revenue = new Prisma.Decimal(0);
    let profitEarned = new Prisma.Decimal(0);
    for (const item of soldItems) {
      const netQty = item.quantity - item.refundedQuantity;
      soldQuantity += netQty;
      // F-RACE-2 pattern (see sales.service.ts refund()): `total` already
      // nets out any discount for the FULL line, so pro-rate it to the
      // non-refunded quantity rather than recomputing from unitPrice.
      const perUnitNet = new Prisma.Decimal(item.total).div(item.quantity);
      const lineRevenue = perUnitNet.mul(netQty);
      revenue = revenue.add(lineRevenue);
      const costSnapshot = item.costPrice != null ? new Prisma.Decimal(item.costPrice) : new Prisma.Decimal(0);
      profitEarned = profitEarned.add(lineRevenue.sub(costSnapshot.mul(netQty)));
    }

    const batchCost = new Prisma.Decimal(anchor.totalCost);
    const paybackPercent = batchCost.gt(0)
      ? revenue.div(batchCost).mul(100).toNumber()
      : null;
    const paybackShortfall = revenue.sub(batchCost).toNumber();

    return {
      hasBatch: true,
      batchQuantity: anchor.quantity,
      batchCost: batchCost.toNumber(),
      soldQuantity,
      revenue: revenue.toNumber(),
      profitEarned: profitEarned.toNumber(),
      remainingQuantity,
      remainingStockValue,
      paybackPercent,
      paybackShortfall,
    };
  }
```

- [ ] **Step 5: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/products/products.service.spec.ts --no-coverage
```

Expected: PASS, all tests in the file including the 5 new ones.

- [ ] **Step 6: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/common/guards/feature-flag.helper.ts api/src/modules/products/products.service.ts api/src/modules/products/products.service.spec.ts
git commit -m "feat(products): add getBatchProfitability computation"
```

---

### Task 4: `GET /:id/batch-profitability` endpoint

**Files:**
- Modify: `api/src/modules/products/products.controller.ts`

No new test file needed — the route is thin wiring over the already-tested `getBatchProfitability` service method and the already-tested guards; this task is wiring-only, verified by a quick manual/typecheck pass rather than a new spec (consistent with how `findOne`/other GET routes on this controller have no dedicated controller-level tests either).

- [ ] **Step 1: Add the imports and route**

In `api/src/modules/products/products.controller.ts`, add two imports:

```typescript
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
```

Then add a new route right after the existing `findOne` (`GET :id`) handler:

```typescript
  @Get(':id/batch-profitability')
  @UseGuards(SubscriptionGuard)
  @RequiresFeature('hasBatchProfitability')
  @Permissions('products.viewProfitability')
  @ApiOperation({ summary: 'Get batch (most recent restock) profitability for a product' })
  getBatchProfitability(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
  ) {
    return this.productsService.getBatchProfitability(storeId, id);
  }
```

This mirrors the exact guard-stacking pattern already used on `deliveries.controller.ts` (`@RequiresFeature('hasDelivery')`) — `SubscriptionGuard` is added per-route here (not at class level, since most other routes on this controller aren't plan-gated), stacking on top of the class-level `JwtAuthGuard, StoreAccessGuard, PermissionsGuard`.

- [ ] **Step 2: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit
```

Expected: 0 errors.

- [ ] **Step 3: Full suite**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest --no-coverage
```

Expected: all suites still pass (no test exercises this new route directly yet — that's fine, its dependencies are covered).

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/products/products.controller.ts
git commit -m "feat(products): wire GET /:id/batch-profitability endpoint"
```

---

### Task 5: `paybackPercent` on the product list response

**Files:**
- Modify: `api/src/modules/products/products.service.ts`
- Modify: `api/src/modules/products/products.controller.ts`
- Test: `api/src/modules/products/products.service.spec.ts`

The list endpoint stays open to every role (no route-level gate), but each returned product gets an extra `paybackPercent: number | null` field, computed only when the caller has `products.viewProfitability` AND the store's plan has `hasBatchProfitability`. This requires threading the caller's `userId` into `findAll`, which it doesn't currently receive.

- [ ] **Step 1: Write the failing test**

Add to `api/src/modules/products/products.service.spec.ts` (reuse the `stockMovement`/`saleItem` fakes added in Task 3; add `store`, `staff`, `subscription`, `subscriptionPlanConfig` fakes needed by `checkStaffPermission`/`hasFeatureFlag`):

```typescript
describe('ProductsService.findAll — paybackPercent gating', () => {
  let service: ProductsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    prisma.store = {
      findUnique: jest.fn(async ({ where }: any) =>
        where.id === 'store-A' ? { ownerId: 'owner-1' } : null,
      ),
    };
    prisma.staff = {
      findUnique: jest.fn(async ({ where }: any) => {
        const { userId } = where.storeId_userId;
        if (userId === 'admin-1') return { role: 'ADMIN', isActive: true };
        if (userId === 'cashier-1') return { role: 'CASHIER', isActive: true };
        return null;
      }),
    };
    prisma.subscription = {
      findUnique: jest.fn(async () => ({ storeId: 'store-A', plan: 'BUSINESS' })),
    };
    prisma.subscriptionPlanConfig = {
      findUnique: jest.fn(async () => ({ plan: 'BUSINESS', hasBatchProfitability: true })),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [ProductsService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(ProductsService);

    prisma._rows.set('p1', {
      id: 'p1', storeId: 'store-A', name: 'Widget', sellPrice: 30, costPrice: 10,
      quantity: 67, minQuantity: 0, unit: 'PCS', isActive: true, createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      unitCost: 10, totalCost: 1000, createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si1', productId: 'p1', quantity: 33, unitPrice: 30, costPrice: 10,
      total: 990, refundedQuantity: 0, saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-07-15'),
    });
  });

  it('should include paybackPercent for a caller with products.viewProfitability on a plan with the flag', async () => {
    const result = await service.findAll('store-A', {} as any, 'admin-1');
    expect(result.data[0].paybackPercent).toBeCloseTo(99);
  });

  it('should omit paybackPercent (null) for a caller without the permission', async () => {
    const result = await service.findAll('store-A', {} as any, 'cashier-1');
    expect(result.data[0].paybackPercent).toBeNull();
  });

  it('should omit paybackPercent (null) when the store plan lacks hasBatchProfitability, even for a privileged caller', async () => {
    prisma.subscriptionPlanConfig.findUnique = jest.fn(
      async () => ({ plan: 'START', hasBatchProfitability: false }),
    );
    const result = await service.findAll('store-A', {} as any, 'admin-1');
    expect(result.data[0].paybackPercent).toBeNull();
  });
});
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/products/products.service.spec.ts -t "paybackPercent gating" --no-coverage
```

Expected: FAIL — `findAll` doesn't accept a third argument yet / `paybackPercent` is undefined.

- [ ] **Step 3: Implement**

In `api/src/modules/products/products.service.ts`, add imports:

```typescript
import { checkStaffPermission } from '../../common/guards/permission-check.helper';
import { hasFeatureFlag } from '../../common/guards/feature-flag.helper';
```

Replace the entire `findAll` method (it currently has two separate return points — one for the `lowStock` branch, one for the normal branch — both fixed today in an earlier session; this version unifies them into one `products`/`total` pair so the payback enrichment only has to be written once) with:

```typescript
  async findAll(
    storeId: string,
    query: ProductQueryDto,
    requestingUserId?: string,
  ) {
    // F3.1: soft-deleted (isActive=false) products previously remained
    // visible in list + total count. Default to active-only here; pass
    // `?includeArchived=true` to see archived rows.
    const where: Prisma.ProductWhereInput = { storeId };
    if (!query.includeArchived) {
      where.isActive = true;
    }

    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { sku: { contains: query.search, mode: 'insensitive' } },
        { barcode: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    if (query.categoryId) where.categoryId = query.categoryId;
    if (query.inStock === true) where.quantity = { gt: 0 };
    if (query.inStock === false) where.quantity = { lte: 0 };

    const orderBy: Prisma.ProductOrderByWithRelationInput = {};
    if (query.sortBy) {
      (orderBy as any)[query.sortBy] = query.sortOrder || 'desc';
    }
    const effectiveOrderBy = Object.keys(orderBy).length
      ? orderBy
      : { createdAt: 'desc' as const };
    const limit = query.limit || 20;

    let products: any[];
    let total: number;

    // "Low stock" means quantity <= minQuantity (and quantity > 0, since an
    // out-of-stock product is a distinct concept handled by inStock=false).
    // That's a column-vs-column comparison on the same row, which Prisma's
    // query builder cannot express in `where`. There's no existing
    // $queryRaw precedent in this module/module set, so rather than bolt on
    // raw SQL for this one filter, fetch rows matching every other filter
    // normally, apply the low-stock predicate in application code, and
    // paginate the filtered result ourselves. Store catalogs are bounded in
    // size, so loading the filtered set before paginating is fine here.
    if (query.lowStock) {
      const candidates = await this.prisma.product.findMany({
        where,
        include: { category: { select: { id: true, name: true } } },
        orderBy: effectiveOrderBy,
      });
      const filtered = candidates.filter(
        (p: any) => p.quantity > 0 && p.quantity <= p.minQuantity,
      );
      total = filtered.length;
      products = filtered.slice(query.skip, query.skip + limit);
    } else {
      const [data, count] = await Promise.all([
        this.prisma.product.findMany({
          where,
          include: { category: { select: { id: true, name: true } } },
          orderBy: effectiveOrderBy,
          skip: query.skip,
          take: limit,
        }),
        this.prisma.product.count({ where }),
      ]);
      products = data;
      total = count;
    }

    let canViewProfitability = false;
    if (requestingUserId) {
      const [hasPermission, planHasFlag] = await Promise.all([
        checkStaffPermission(this.prisma, storeId, requestingUserId, [
          'products.viewProfitability',
        ]),
        hasFeatureFlag(this.prisma, storeId, 'hasBatchProfitability'),
      ]);
      canViewProfitability = hasPermission && planHasFlag;
    }

    const data = canViewProfitability
      ? await Promise.all(
          products.map(async (p) => ({
            ...p,
            paybackPercent: (await this.getBatchProfitability(storeId, p.id))
              .paybackPercent,
          })),
        )
      : products.map((p) => ({ ...p, paybackPercent: null }));

    return {
      data,
      total,
      page: query.page || 1,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }
```

- [ ] **Step 4: Update the controller to pass the caller's id**

In `api/src/modules/products/products.controller.ts`, the `findAll` handler currently is:

```typescript
  @Get()
  findAll(@Param('storeId') storeId: string, @Query() query: ProductQueryDto) {
    return this.productsService.findAll(storeId, query);
  }
```

Change to:

```typescript
  @Get()
  findAll(
    @Param('storeId') storeId: string,
    @Query() query: ProductQueryDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.productsService.findAll(storeId, query, userId);
  }
```

(`CurrentUser` is already imported in this file per the existing import list.)

- [ ] **Step 5: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/products/products.service.spec.ts --no-coverage
```

Expected: PASS, all tests including the 3 new ones.

- [ ] **Step 6: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/products/products.service.ts api/src/modules/products/products.controller.ts api/src/modules/products/products.service.spec.ts
git commit -m "feat(products): include paybackPercent on product list for privileged callers"
```

---

### Task 6: Notification settings — two new thresholds

**Files:**
- Modify: `api/src/modules/notifications/dto/notification-settings.dto.ts`
- Modify: `api/src/modules/notifications/notifications.service.ts`
- Test: `api/src/modules/notifications/notifications.service.spec.ts`

- [ ] **Step 1: Extend the DTO**

In `api/src/modules/notifications/dto/notification-settings.dto.ts`, update the imports and add two fields:

```typescript
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsBoolean, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class NotificationSettingsDto {
  @ApiPropertyOptional({ description: 'Alert when product stock falls below minimum' })
  @IsOptional()
  @IsBoolean()
  lowStockAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Notify on each new sale' })
  @IsOptional()
  @IsBoolean()
  newSaleAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Notify when a shift is closed' })
  @IsOptional()
  @IsBoolean()
  shiftClosedAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Notify when a delivery is completed' })
  @IsOptional()
  @IsBoolean()
  deliveryCompletedAlerts?: boolean;

  @ApiPropertyOptional({ description: 'Send debt reminders to customers' })
  @IsOptional()
  @IsBoolean()
  debtReminderAlerts?: boolean;

  @ApiPropertyOptional({
    description: 'Days without a sale before a product is flagged as slow-moving',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  daysWithoutSaleThreshold?: number;

  @ApiPropertyOptional({
    description: 'Minimum % of the batch still unsold to trigger a slow-moving alert',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  remainingPercentThreshold?: number;
}
```

- [ ] **Step 2: Write the failing test**

Find `api/src/modules/notifications/notifications.service.spec.ts`'s existing test(s) for `getNotificationSettings`/`saveNotificationSettings` (they exist per the low-stock-alerts default) and add two assertions alongside them, in the same style:

```typescript
  describe('getNotificationSettings — batch profitability thresholds', () => {
    it('should default daysWithoutSaleThreshold to 30 and remainingPercentThreshold to 50 when unset', async () => {
      prisma.store.findUnique = jest.fn(async () => ({ settings: {} }));
      const result = await service.getNotificationSettings('store-1');
      expect(result.daysWithoutSaleThreshold).toBe(30);
      expect(result.remainingPercentThreshold).toBe(50);
    });

    it('should return the persisted values when previously saved', async () => {
      prisma.store.findUnique = jest.fn(async () => ({
        settings: { notifications: { daysWithoutSaleThreshold: 14, remainingPercentThreshold: 30 } },
      }));
      const result = await service.getNotificationSettings('store-1');
      expect(result.daysWithoutSaleThreshold).toBe(14);
      expect(result.remainingPercentThreshold).toBe(30);
    });
  });
```

(Match the exact `prisma.store.findUnique` mocking convention already used by the sibling `lowStockAlerts` tests in this file — if the fixture setup differs from the sketch above, follow the file's actual existing pattern instead.)

- [ ] **Step 3: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/notifications/notifications.service.spec.ts -t "batch profitability thresholds" --no-coverage
```

Expected: FAIL — `daysWithoutSaleThreshold` is `undefined`.

- [ ] **Step 4: Implement**

In `api/src/modules/notifications/notifications.service.ts`, update `getNotificationSettings`:

```typescript
  async getNotificationSettings(storeId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { settings: true },
    });
    const notif = (store?.settings as any)?.notifications ?? {};
    return {
      lowStockAlerts: notif.lowStockAlerts ?? true,
      newSaleAlerts: notif.newSaleAlerts ?? true,
      shiftClosedAlerts: notif.shiftClosedAlerts ?? true,
      deliveryCompletedAlerts: notif.deliveryCompletedAlerts ?? true,
      debtReminderAlerts: notif.debtReminderAlerts ?? true,
      daysWithoutSaleThreshold: notif.daysWithoutSaleThreshold ?? 30,
      remainingPercentThreshold: notif.remainingPercentThreshold ?? 50,
    };
  }
```

`saveNotificationSettings` needs no changes — it already spreads `...dto` over the existing settings object, so the two new optional numeric fields flow through automatically.

- [ ] **Step 5: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/notifications/notifications.service.spec.ts --no-coverage
```

- [ ] **Step 6: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/notifications/dto/notification-settings.dto.ts api/src/modules/notifications/notifications.service.ts api/src/modules/notifications/notifications.service.spec.ts
git commit -m "feat(notifications): add slow-moving-stock threshold settings"
```

---

### Task 7: `StockAlertsService` daily cron

**Files:**
- Create: `api/src/modules/products/stock-alerts.service.ts`
- Modify: `api/src/modules/products/products.module.ts`
- Test: `api/src/modules/products/stock-alerts.service.spec.ts`

- [ ] **Step 1: Write the failing test**

```typescript
// api/src/modules/products/stock-alerts.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { StockAlertsService } from './stock-alerts.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

function makePrismaFake() {
  const stores: any[] = [];
  const products: any[] = [];
  const stockMovements: any[] = [];
  const saleItems: any[] = [];
  const subscriptions: any[] = [];
  const planConfigs: any[] = [];

  return {
    _stores: stores,
    _products: products,
    _stockMovements: stockMovements,
    _saleItems: saleItems,
    _subscriptions: subscriptions,
    _planConfigs: planConfigs,
    store: {
      findMany: jest.fn(async ({ where }: any) =>
        stores.filter((s) => !where?.isActive || s.isActive === where.isActive),
      ),
    },
    product: {
      findMany: jest.fn(async ({ where }: any) =>
        products.filter(
          (p) =>
            p.storeId === where.storeId &&
            p.isActive === where.isActive &&
            (!where.quantity?.gt || p.quantity > where.quantity.gt),
        ),
      ),
    },
    stockMovement: {
      findFirst: jest.fn(async ({ where, orderBy }: any) => {
        let matches = stockMovements.filter(
          (m) => m.productId === where.productId && m.type === where.type,
        );
        if (orderBy?.createdAt === 'desc') {
          matches = [...matches].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        }
        return matches[0] ?? null;
      }),
    },
    saleItem: {
      findFirst: jest.fn(async ({ where, orderBy }: any) => {
        let matches = saleItems.filter((si) => {
          if (si.productId !== where.productId) return false;
          if (where.sale?.storeId && si.saleStoreId !== where.sale.storeId) return false;
          if (where.sale?.createdAt?.gte && si.saleCreatedAt < where.sale.createdAt.gte) return false;
          return true;
        });
        if (orderBy?.sale?.createdAt === 'desc') {
          matches = [...matches].sort((a, b) => b.saleCreatedAt.getTime() - a.saleCreatedAt.getTime());
        }
        return matches[0] ? { sale: { createdAt: matches[0].saleCreatedAt } } : null;
      }),
    },
    subscription: {
      findUnique: jest.fn(async ({ where }: any) =>
        subscriptions.find((s) => s.storeId === where.storeId) ?? null,
      ),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async ({ where }: any) =>
        planConfigs.find((c) => c.plan === where.plan) ?? null,
      ),
    },
  } as any;
}

describe('StockAlertsService.checkSlowMovingStock', () => {
  let service: StockAlertsService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let sendToStoreUsers: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    sendToStoreUsers = jest.fn().mockResolvedValue(undefined);
    const moduleRef = await Test.createTestingModule({
      providers: [
        StockAlertsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendToStoreUsers } },
      ],
    }).compile();
    service = moduleRef.get(StockAlertsService);
  });

  it('should notify for a product that has not sold in 32 days and still has 67% of its batch left', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({ id: 'p1', storeId: 'store-1', name: 'Куртка', quantity: 67, isActive: true });
    const oldDate = new Date(Date.now() - 40 * 24 * 60 * 60 * 1000);
    prisma._stockMovements.push({ id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100, createdAt: oldDate });
    prisma._saleItems.push({
      productId: 'p1', saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 32 * 24 * 60 * 60 * 1000),
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).toHaveBeenCalledTimes(1);
    expect(sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.stringContaining('Куртка'),
      'SLOW_MOVING_STOCK',
    );
  });

  it('should NOT notify when the product sold recently', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({ id: 'p1', storeId: 'store-1', name: 'Куртка', quantity: 67, isActive: true });
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });
    prisma._saleItems.push({
      productId: 'p1', saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });

  it('should NOT notify when remaining quantity is below the 50% threshold', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({ id: 'p1', storeId: 'store-1', name: 'Куртка', quantity: 10, isActive: true }); // only 10%
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });

  it('should NOT notify for a store whose plan lacks hasBatchProfitability', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'START' });
    prisma._planConfigs.push({ plan: 'START', hasBatchProfitability: false });
    prisma._products.push({ id: 'p1', storeId: 'store-1', name: 'Куртка', quantity: 67, isActive: true });
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });

  it('should respect a store-configured custom threshold', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true, settings: { notifications: { daysWithoutSaleThreshold: 10, remainingPercentThreshold: 20 } } });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({ id: 'p1', storeId: 'store-1', name: 'Куртка', quantity: 25, isActive: true }); // 25% >= 20%
    prisma._stockMovements.push({
      id: 'mv1', productId: 'p1', type: 'PURCHASE', quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });
    prisma._saleItems.push({
      productId: 'p1', saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000), // 15 days ago >= 10-day threshold
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/products/stock-alerts.service.spec.ts --no-coverage
```

Expected: FAIL — `Cannot find module './stock-alerts.service'`.

- [ ] **Step 3: Implement**

```typescript
// api/src/modules/products/stock-alerts.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { hasFeatureFlag } from '../../common/guards/feature-flag.helper';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

@Injectable()
export class StockAlertsService {
  private readonly logger = new Logger(StockAlertsService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  // Runs before the store day typically starts. Other crons in this
  // codebase use 0/2/9 — pick a distinct slot to avoid clustering.
  @Cron('0 8 * * *')
  async checkSlowMovingStock(): Promise<void> {
    const stores = await this.prisma.store.findMany({
      where: { isActive: true },
      select: { id: true, settings: true },
    });

    for (const store of stores) {
      try {
        await this.checkStoreForSlowMovingStock(store);
      } catch (err) {
        this.logger.error(`checkSlowMovingStock failed for store ${store.id}`, err);
      }
    }
  }

  private async checkStoreForSlowMovingStock(store: { id: string; settings: unknown }) {
    const planHasFlag = await hasFeatureFlag(this.prisma, store.id, 'hasBatchProfitability');
    if (!planHasFlag) return;

    const notif = (store.settings as any)?.notifications ?? {};
    const daysThreshold = notif.daysWithoutSaleThreshold ?? 30;
    const percentThreshold = notif.remainingPercentThreshold ?? 50;
    const cutoff = new Date(Date.now() - daysThreshold * MS_PER_DAY);

    const products = await this.prisma.product.findMany({
      where: { storeId: store.id, isActive: true, quantity: { gt: 0 } },
      select: { id: true, name: true, quantity: true },
    });

    // One product at a time (N+1 queries) — acceptable for a once-daily
    // background job; not something a request handler should ever do.
    for (const product of products) {
      const anchor = await this.prisma.stockMovement.findFirst({
        where: { productId: product.id, type: 'PURCHASE' },
        orderBy: { createdAt: 'desc' },
        select: { quantity: true, createdAt: true },
      });
      if (!anchor || anchor.quantity <= 0) continue;

      const remainingPercent = (product.quantity / anchor.quantity) * 100;
      if (remainingPercent < percentThreshold) continue;

      const lastSale = await this.prisma.saleItem.findFirst({
        where: {
          productId: product.id,
          sale: { storeId: store.id, createdAt: { gte: anchor.createdAt } },
        },
        orderBy: { sale: { createdAt: 'desc' } },
        select: { sale: { select: { createdAt: true } } },
      });
      const referenceDate = lastSale?.sale.createdAt ?? anchor.createdAt;
      if (referenceDate > cutoff) continue;

      const daysSince = Math.floor((Date.now() - referenceDate.getTime()) / MS_PER_DAY);

      void this.notifications.sendToStoreUsers(
        store.id,
        '📉 Товар не продаётся',
        `Товар "${product.name}" не продаётся ${daysSince} дней, осталось ${product.quantity} из ${anchor.quantity} шт. Возможно, стоит снизить цену.`,
        'SLOW_MOVING_STOCK',
      );
    }
  }
}
```

- [ ] **Step 4: Register the provider**

In `api/src/modules/products/products.module.ts`:

```typescript
import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { StockMovementsService } from './stock-movements.service';
import { ImportProductsService } from './import-products.service';
import { StockAlertsService } from './stock-alerts.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [ProductsController],
  providers: [
    ProductsService,
    StockMovementsService,
    ImportProductsService,
    StockAlertsService,
  ],
  exports: [ProductsService, StockMovementsService],
})
export class ProductsModule {}
```

- [ ] **Step 5: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/products/stock-alerts.service.spec.ts --no-coverage
```

Expected: PASS, 5/5.

- [ ] **Step 6: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/products/stock-alerts.service.ts api/src/modules/products/stock-alerts.service.spec.ts api/src/modules/products/products.module.ts
git commit -m "feat(products): add daily slow-moving-stock notification cron"
```

---

## Part 2 — Flutter

### Task 8: `paybackPercent` on the `Product` entity + API endpoint constant

**Files:**
- Modify: `app/lib/core/constants/api_endpoints.dart`
- Modify: `app/lib/domain/entities/product.dart`
- Modify: `app/lib/data/datasources/remote/product_remote_datasource.dart`

- [ ] **Step 1: Add the endpoint constant**

In `app/lib/core/constants/api_endpoints.dart`, right after the existing `stockMovements` constant:

```dart
  static String productBatchProfitability(String storeId, String productId) =>
      '/stores/$storeId/products/$productId/batch-profitability';
```

- [ ] **Step 2: Add the field to `Product`**

In `app/lib/domain/entities/product.dart`, add one field, one constructor param, and include it in `props`:

```dart
import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String storeId;
  final String? categoryId;
  final String? categoryName;
  final String? supplierId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final double? costPrice;
  final double sellPrice;
  final double? wholesalePrice;
  final int quantity;
  final int minQuantity;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final double? paybackPercent;

  const Product({
    required this.id,
    required this.storeId,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.costPrice,
    required this.sellPrice,
    this.wholesalePrice,
    this.quantity = 0,
    this.minQuantity = 0,
    this.unit = 'PCS',
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.paybackPercent,
  });

  bool get isLowStock => quantity > 0 && quantity <= minQuantity;
  bool get isOutOfStock => quantity <= 0;
  double? get profit => costPrice != null ? sellPrice - costPrice! : null;
  double? get margin => costPrice != null && costPrice! > 0
      ? ((sellPrice - costPrice!) / sellPrice) * 100
      : null;

  @override
  List<Object?> get props =>
      [id, storeId, name, sku, barcode, sellPrice, quantity, isActive, paybackPercent];
}
```

- [ ] **Step 3: Parse it in `_mapProduct`**

In `app/lib/data/datasources/remote/product_remote_datasource.dart`, find the `_mapProduct` method's `Product(...)` constructor call and add:

```dart
      paybackPercent: (json['paybackPercent'] as num?)?.toDouble(),
```

as an additional named argument alongside the existing ones (exact insertion point: wherever the existing fields like `quantity:`/`isActive:` are set in that constructor call — add this as one more line in the same block).

- [ ] **Step 4: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter analyze lib/domain/entities/product.dart lib/data/datasources/remote/product_remote_datasource.dart lib/core/constants/api_endpoints.dart
```

Expected: No issues found (or only pre-existing unrelated infos).

- [ ] **Step 5: Run existing product entity/datasource tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter test test/domain/entities/product_test.dart test/data/datasources/remote/product_remote_datasource_test.dart
```

Expected: all still pass (adding an optional field with a default doesn't break existing fixtures — if any test constructs a `Product` via named args exhaustively and a strict-equality check now needs `paybackPercent`, add it as `null` there).

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add app/lib/core/constants/api_endpoints.dart app/lib/domain/entities/product.dart app/lib/data/datasources/remote/product_remote_datasource.dart
git commit -m "feat(products): add paybackPercent field to Product entity"
```

---

### Task 9: Payback badge on `ProductCard`

**Files:**
- Modify: `app/lib/presentation/widgets/product/product_card.dart`
- Test: `app/test/presentation/widgets/product/product_card_test.dart` (create if it doesn't exist; check first)

- [ ] **Step 1: Check for an existing test file**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && ls test/presentation/widgets/product/product_card_test.dart 2>&1
```

If it exists, read it fully before writing new tests, and follow its existing structure/imports exactly. If it doesn't exist, Step 2 creates one from scratch — this feature doesn't need golden-image tests, just widget-tree assertions (`find.text`, `find.byType`), consistent with this codebase's non-golden widget test convention.

- [ ] **Step 2: Write the failing test**

```dart
// app/test/presentation/widgets/product/product_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/widgets/product/product_card.dart';

Product _product({double? paybackPercent, int quantity = 10}) {
  return Product(
    id: 'p1',
    storeId: 'store-1',
    name: 'Test Product',
    sellPrice: 30,
    quantity: quantity,
    createdAt: DateTime(2026, 1, 1),
    paybackPercent: paybackPercent,
  );
}

void main() {
  group('ProductCard — payback badge', () {
    testWidgets('does not show a payback badge when paybackPercent is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductCard(product: _product(paybackPercent: null))),
      ));

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows the rounded payback percentage when present', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductCard(product: _product(paybackPercent: 99.4))),
      ));

      expect(find.text('99%'), findsOneWidget);
    });

    testWidgets('rounds up correctly at the boundary', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductCard(product: _product(paybackPercent: 100.0))),
      ));

      expect(find.text('100%'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter test test/presentation/widgets/product/product_card_test.dart
```

Expected: FAIL — no widget shows the percentage text yet.

- [ ] **Step 4: Implement**

In `app/lib/presentation/widgets/product/product_card.dart`, replace the `Row`'s second child (`_buildQuantityIndicator(context)` at line 90) with a `Column` wrapping both badges, and add the new badge-building method:

```dart
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            Formatters.price(product.sellPrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildQuantityIndicator(context),
                            if (product.paybackPercent != null) ...[
                              const SizedBox(height: 4),
                              _buildPaybackBadge(context),
                            ],
                          ],
                        ),
                      ],
                    ),
```

And add this method right after `_buildQuantityIndicator`:

```dart
  Widget _buildPaybackBadge(BuildContext context) {
    final percent = product.paybackPercent!;
    Color color;
    if (percent < 50) {
      color = context.danger;
    } else if (percent < 100) {
      color = context.warning;
    } else {
      color = context.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        '${percent.round()}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
```

- [ ] **Step 5: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter test test/presentation/widgets/product/product_card_test.dart
```

Expected: PASS, 3/3.

- [ ] **Step 6: Run any existing golden tests for this widget to check for visual regressions**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && find test -iname "*product_card*golden*"
```

If a golden test file exists, run it and regenerate goldens if the diff is only the new (absent, since `paybackPercent` defaults to `null` in existing fixtures) badge — i.e. it should NOT need regeneration since existing golden fixtures won't set `paybackPercent`, so the badge stays hidden and the golden image is unaffected. If it does need updating, that's expected and fine: `flutter test --update-goldens <path>`.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add app/lib/presentation/widgets/product/product_card.dart app/test/presentation/widgets/product/product_card_test.dart
git commit -m "feat(products): show payback badge on product grid card"
```

---

### Task 10: Payback badge on `ProductListItem`

**Files:**
- Modify: `app/lib/presentation/widgets/product/product_list_item.dart`
- Test: `app/test/presentation/widgets/product/product_list_item_test.dart` (create if it doesn't exist; check first, same as Task 9 Step 1)

- [ ] **Step 1: Write the failing test** (mirror Task 9's test file exactly, swapping the widget)

```dart
// app/test/presentation/widgets/product/product_list_item_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/widgets/product/product_list_item.dart';

Product _product({double? paybackPercent}) {
  return Product(
    id: 'p1',
    storeId: 'store-1',
    name: 'Test Product',
    sellPrice: 30,
    quantity: 10,
    createdAt: DateTime(2026, 1, 1),
    paybackPercent: paybackPercent,
  );
}

void main() {
  group('ProductListItem — payback badge', () {
    testWidgets('does not show a payback badge when paybackPercent is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductListItem(product: _product(paybackPercent: null))),
      ));

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows the rounded payback percentage when present', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductListItem(product: _product(paybackPercent: 42.9))),
      ));

      expect(find.text('43%'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter test test/presentation/widgets/product/product_list_item_test.dart
```

- [ ] **Step 3: Implement**

In `app/lib/presentation/widgets/product/product_list_item.dart`, replace the `_buildQuantityBadge(context)` call at the end of the outer `Row` (line 93) with a `Column`, and add the badge method:

```dart
              const SizedBox(width: AppConstants.spacingSm),
              // Quantity + payback badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildQuantityBadge(context),
                  if (product.paybackPercent != null) ...[
                    const SizedBox(height: 4),
                    _buildPaybackBadge(context),
                  ],
                ],
              ),
```

```dart
  Widget _buildPaybackBadge(BuildContext context) {
    final percent = product.paybackPercent!;
    Color backgroundColor;
    Color textColor;

    if (percent < 50) {
      backgroundColor = context.danger.withValues(alpha: 0.1);
      textColor = context.danger;
    } else if (percent < 100) {
      backgroundColor = context.warning.withValues(alpha: 0.1);
      textColor = context.warning;
    } else {
      backgroundColor = context.success.withValues(alpha: 0.1);
      textColor = context.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        '${percent.round()}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter test test/presentation/widgets/product/product_list_item_test.dart
```

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add app/lib/presentation/widgets/product/product_list_item.dart app/test/presentation/widgets/product/product_list_item_test.dart
git commit -m "feat(products): show payback badge on product list item"
```

---

### Task 11: "Окупаемость партии" section on the product detail page

**Files:**
- Modify: `app/lib/presentation/pages/product/product_detail_page.dart`

This mirrors the existing `_StockMovementsSection` `StatefulWidget` in the same file exactly (direct `sl<DioClient>()` call, raw `Map<String, dynamic>` parsing, `_loading`/`_error` state) — that is this specific file's established local convention for a lazily-loaded sub-section, and there's no other page in this app currently using `getBatchProfitability`, so introducing a full repository/datasource round trip here would be indirection with no reuse benefit.

- [ ] **Step 1: Add the new section widget class**

Add this new class at the end of `app/lib/presentation/pages/product/product_detail_page.dart` (after the existing `_StockMovementsSection`/`_StockMovementsSectionState` classes, so it sits alongside its sibling):

```dart
// ---------------------------------------------------------------------------
// Batch Profitability ("Окупаемость партии")
// ---------------------------------------------------------------------------

class _BatchProfitabilitySection extends StatefulWidget {
  final String storeId;
  final String productId;

  const _BatchProfitabilitySection({
    required this.storeId,
    required this.productId,
  });

  @override
  State<_BatchProfitabilitySection> createState() =>
      _BatchProfitabilitySectionState();
}

class _BatchProfitabilitySectionState
    extends State<_BatchProfitabilitySection> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _forbidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.storeId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final resp = await sl<DioClient>().get<Map<String, dynamic>>(
        ApiEndpoints.productBatchProfitability(widget.storeId, widget.productId),
      );
      setState(() {
        _data = resp.data;
        _loading = false;
      });
    } on DioException catch (e) {
      // 403 = plan doesn't include this feature, or caller's role can't
      // view it — both cases just hide the section, no error UI.
      setState(() {
        _forbidden = e.response?.statusCode == 403;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(num? value) =>
      value == null ? '—' : Formatters.price(value.toDouble());

  @override
  Widget build(BuildContext context) {
    if (_loading || _forbidden || _data == null) {
      return const SizedBox.shrink();
    }
    final data = _data!;
    if (data['hasBatch'] != true) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          boxShadow: AppShadows.md,
        ),
        child: Text(
          'Нет данных о последней закупке — оформите приход, чтобы видеть окупаемость партии.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
      );
    }

    final paybackPercent = (data['paybackPercent'] as num?)?.toDouble();
    final paybackShortfall = (data['paybackShortfall'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Окупаемость партии',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Себестоимость партии',
            value: _formatMoney((data['batchCost'] as num?)),
          ),
          const Divider(height: 20),
          _InfoRow(
            label: 'Выручка от партии',
            value: _formatMoney((data['revenue'] as num?)),
          ),
          const Divider(height: 20),
          _InfoRow(
            label: 'Прибыль заработана',
            value: _formatMoney((data['profitEarned'] as num?)),
          ),
          const Divider(height: 20),
          _InfoRow(
            label: 'До окупаемости партии',
            value: paybackShortfall == null
                ? '—'
                : paybackShortfall >= 0
                    ? 'Партия окупилась'
                    : _formatMoney(paybackShortfall),
          ),
          const Divider(height: 20),
          _InfoRow(
            label: 'Остаток',
            value:
                '${data['remainingQuantity']} шт. на ${_formatMoney((data['remainingStockValue'] as num?))}',
          ),
          if (paybackPercent != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (paybackPercent / 100).clamp(0.0, 1.0),
              backgroundColor: context.surfaceMuted,
              color: paybackPercent >= 100
                  ? AppColors.success
                  : paybackPercent >= 50
                      ? AppColors.warning
                      : AppColors.error,
            ),
            const SizedBox(height: 4),
            Text(
              '${paybackPercent.toStringAsFixed(0)}% окупаемости',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Insert it into the main build tree**

In the same file's main `build()` method, find `const SizedBox(height: 20);` that follows the 2×2 price/cost/profit/margin grid (right before the "Наличие на складе" stock `Container`) and insert the new section between them:

```dart
                    const SizedBox(height: 20),

                    // Batch profitability
                    _BatchProfitabilitySection(
                      storeId: () {
                        final storeState = context.read<StoreBloc>().state;
                        return storeState is StoreLoaded
                            ? storeState.selectedStore?.id ?? ''
                            : '';
                      }(),
                      productId: product.id,
                    ),
                    const SizedBox(height: 20),

                    // Stock section with progress bar
                    Container(
```

(This mirrors the exact storeId-deriving inline closure already used for the existing `_StockMovementsSection` instantiation further down in the same build method.)

- [ ] **Step 3: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter analyze lib/presentation/pages/product/product_detail_page.dart
```

Expected: No issues found.

- [ ] **Step 4: Manual verification** (this page reads `GoRouterState.extra`, so it can't be reached by a plain widget test without a full router harness — verify by running the app)

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4455/api
```

Navigate to a product's detail page and confirm the new "Окупаемость партии" section renders (or is silently absent for a product with no purchase history / for a non-privileged role / on a START-plan store) with no crash.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add app/lib/presentation/pages/product/product_detail_page.dart
git commit -m "feat(products): add batch profitability section to product detail page"
```

---

### Task 12: Notification settings — two new threshold fields + fix existing key mismatch

**Files:**
- Modify: `app/lib/presentation/pages/notifications/notification_settings_page.dart`

While adding the two new fields, this task also fixes a pre-existing bug in the same lines being touched: the page currently sends/reads JSON keys (`lowStock`, `newSale`, `shiftClosed`, `deliveryCompleted`, `debtReminder`) that don't match the backend's actual field names (`lowStockAlerts`, `newSaleAlerts`, `shiftClosedAlerts`, `deliveryCompletedAlerts`, `debtReminderAlerts`), so every toggle silently resets to its default on every load. Fixing this is directly in the path of this task (same `_loadSettings`/`_saveSettings` maps) — see writing-plans guidance on including targeted improvements that serve the current goal.

- [ ] **Step 1: Fix the key mismatch and add the two new numeric fields**

In `app/lib/presentation/pages/notifications/notification_settings_page.dart`, update the state fields:

```dart
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  bool _lowStock = true;
  bool _newSale = true;
  bool _shiftClosed = true;
  bool _deliveryCompleted = true;
  bool _debtReminder = true;
  int _daysWithoutSaleThreshold = 30;
  int _remainingPercentThreshold = 50;
  late final TextEditingController _daysController;
  late final TextEditingController _percentController;
```

Update `initState`/`dispose` (add if not already using controllers — check the file first; if it's currently stateless beyond the bool fields, add a standard `initState`/`dispose` pair):

```dart
  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController();
    _percentController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _percentController.dispose();
    super.dispose();
  }
```

Update `_loadSettings`:

```dart
  Future<void> _loadSettings() async {
    final res = await _dioClient.get('/stores/${widget.storeId}/notifications/settings');
    final data = res.data as Map<String, dynamic>? ?? {};
    setState(() {
      _lowStock = data['lowStockAlerts'] as bool? ?? true;
      _newSale = data['newSaleAlerts'] as bool? ?? true;
      _shiftClosed = data['shiftClosedAlerts'] as bool? ?? true;
      _deliveryCompleted = data['deliveryCompletedAlerts'] as bool? ?? true;
      _debtReminder = data['debtReminderAlerts'] as bool? ?? true;
      _daysWithoutSaleThreshold = data['daysWithoutSaleThreshold'] as int? ?? 30;
      _remainingPercentThreshold = data['remainingPercentThreshold'] as int? ?? 50;
      _daysController.text = _daysWithoutSaleThreshold.toString();
      _percentController.text = _remainingPercentThreshold.toString();
      _loading = false;
    });
  }
```

Update `_saveSettings`:

```dart
  Future<void> _saveSettings() async {
    await _dioClient.put('/stores/${widget.storeId}/notifications/settings', data: {
      'lowStockAlerts': _lowStock,
      'newSaleAlerts': _newSale,
      'shiftClosedAlerts': _shiftClosed,
      'deliveryCompletedAlerts': _deliveryCompleted,
      'debtReminderAlerts': _debtReminder,
      'daysWithoutSaleThreshold': int.tryParse(_daysController.text) ?? 30,
      'remainingPercentThreshold': int.tryParse(_percentController.text) ?? 50,
    });
    // existing AppSnackbar.success/error handling stays as-is
  }
```

- [ ] **Step 2: Add the two input fields to the build method**

Find the `ListView` that renders the 5 `_buildSwitch(...)` rows and add two new `TextFormField` rows after them, matching the `Card`-wrapped style already used for the switches:

```dart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Залежалый товар',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Уведомлять, если товар не продаётся N дней и остаток ещё большой',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Дней без продаж',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _percentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Остаток, % от партии',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
```

(Insert this `Card` into the existing `ListView`'s children list, after the last `_buildSwitch(...)` row and before the "Save" `ElevatedButton` — read the current build method first to place it precisely in that list.)

- [ ] **Step 3: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter analyze lib/presentation/pages/notifications/notification_settings_page.dart
```

Expected: No issues found.

- [ ] **Step 4: Manual verification**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app && flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4455/api
```

Navigate to notification settings, confirm the 5 existing toggles now correctly reflect their persisted state after a save+reload (previously they silently reset to defaults — this is the bug fix), and the two new numeric fields save/reload correctly.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add app/lib/presentation/pages/notifications/notification_settings_page.dart
git commit -m "fix(notifications): correct settings JSON key mismatch; add slow-moving-stock thresholds"
```

---

## Final check

- [ ] Backend: `cd api && npx tsc --noEmit && npx jest --no-coverage` — full suite green, 0 tsc errors.
- [ ] Flutter: `cd app && flutter analyze` — no new issues. `flutter test --exclude-tags=golden` — full suite green.
- [ ] Manually walk through: create a product → stock intake (PURCHASE) → make a sale of it → view product detail page (should show the batch block) → view product list (should show badge on the card, if the logged-in role/plan qualifies).
- [ ] Confirm a CASHIER-role login does NOT see the badge/section (permission gate) and a START-plan store does NOT see it either (plan gate), per Task 2/Task 4's gating.
