# Spec D "Investments Data Integrity Hardening" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the zakat-hardening pattern to the investments module: localId idempotency, $transaction on update/delete, AuditLogService on all mutations, list-perf index, DB CHECK constraints, tier-gating via `hasInvestments` flag (BIZ + PREMIUM only), 6 new unit tests.

**Architecture:** One Prisma migration combining the new column + 2 indexes + 2 CHECK constraints + plan-config flag column. Service refactor mirrors `ZakatService` (commit `2557f6d`): inject `AuditLogService`, idempotent `create`, `$transaction`-wrapped `update`/`remove`, `userId` threaded from controller via `@CurrentUser`. Controller adds `SubscriptionGuard` + `@RequiresFeature('hasInvestments')` at class level.

**Tech Stack:** NestJS 10 + Prisma 6.19 + Postgres 16.

**Spec:** `docs/superpowers/specs/2026-05-16-spec-d-investments-hardening-design.md` (commit e3fed27).

---

## File Structure

**Modify:**
- `api/prisma/schema.prisma` — `Investment` model (`localId` + indexes + unique) + `SubscriptionPlanConfig.hasInvestments`
- `api/src/modules/investments/dto/create-investment.dto.ts` — add optional `localId`
- `api/src/modules/investments/investments.service.ts` — refactor `create`, `update`, `remove`; inject `AuditLogService`; threading `userId`
- `api/src/modules/investments/investments.controller.ts` — add `SubscriptionGuard` + class-level `@RequiresFeature` + `@CurrentUser('id')` on mutation handlers
- `api/src/modules/investments/investments.module.ts` — verify `AuditLogService` import (likely already global; add if not)
- `api/src/modules/subscriptions/subscriptions.service.ts` — `seedPlanConfigs` adds `hasInvestments` per tier
- `api/src/modules/investments/investments.service.spec.ts` — update existing tests for new `userId` arg + add 6 new tests

**Create:**
- `api/prisma/migrations/20260516160000_investments_hardening/migration.sql`

---

## Task 1: Schema model edits

**Files:**
- Modify: `api/prisma/schema.prisma`

- [ ] **Step 1: Inspect current Investment + SubscriptionPlanConfig**

```bash
grep -n "model Investment\b\|model SubscriptionPlanConfig" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
sed -n '/model Investment\b/,/^}/p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
echo "---"
sed -n '/model SubscriptionPlanConfig/,/^}/p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
```

Expected: `Investment` has `@@index([storeId])` + `@@index([status])` + `@@map("investments")`. `SubscriptionPlanConfig` has `hasZakat` (added in earlier spec) but no `hasInvestments`.

- [ ] **Step 2: Edit Investment model**

Find the model block. Insert `localId String?` field BEFORE `createdAt`:

```prisma
  // Spec D: client-supplied UUID for offline-replay idempotency.
  // Per-store unique because clients may reset UUIDs on re-install.
  localId       String?
  createdAt     DateTime         @default(now())
  updatedAt     DateTime         @updatedAt

  @@index([storeId])
  @@index([status])
  @@index([storeId, createdAt(sort: Desc)])
  @@unique([storeId, localId])
  @@map("investments")
}
```

(Keep existing 2 indexes; add the compound index + unique below them.)

- [ ] **Step 3: Edit SubscriptionPlanConfig**

Find the model block. Add after `hasZakat`:

```prisma
  hasZakat        Boolean  @default(false)
  hasInvestments  Boolean  @default(false)

  @@map("subscription_plan_configs")
}
```

- [ ] **Step 4: Verify schema is valid**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma format 2>&1 | tail -3
npx prisma validate 2>&1 | tail -3
```
Expected: `Schema is valid`.

- [ ] **Step 5: Commit (schema-only — migration in next task)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/prisma/schema.prisma
git commit -m "schema(investments): add localId, indexes, hasInvestments tier flag"
```

---

## Task 2: Migration apply

**Files:**
- Create: `api/prisma/migrations/20260516160000_investments_hardening/migration.sql`

- [ ] **Step 1: Create migration directory + SQL**

```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260516160000_investments_hardening
```

Write the file `api/prisma/migrations/20260516160000_investments_hardening/migration.sql`:

```sql
-- Spec D: data integrity hardening for Investment.

-- 1. Idempotent create.
ALTER TABLE "investments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "investments_storeId_localId_key"
  ON "investments"("storeId", "localId");

-- 2. List performance — covering index for default sort.
CREATE INDEX "investments_storeId_createdAt_idx"
  ON "investments"("storeId", "createdAt" DESC);

-- 3. DB-level non-negative guards.
ALTER TABLE "investments"
  ADD CONSTRAINT investments_amount_non_negative
    CHECK ("amount" >= 0),
  ADD CONSTRAINT investments_return_amount_non_negative
    CHECK ("returnAmount" IS NULL OR "returnAmount" >= 0);

-- 4. Tier-gating flag on SubscriptionPlanConfig.
ALTER TABLE "subscription_plan_configs"
  ADD COLUMN "hasInvestments" BOOLEAN NOT NULL DEFAULT false;

UPDATE "subscription_plan_configs" SET "hasInvestments" = false WHERE plan = 'START';
UPDATE "subscription_plan_configs" SET "hasInvestments" = true  WHERE plan = 'BUSINESS';
UPDATE "subscription_plan_configs" SET "hasInvestments" = true  WHERE plan = 'PREMIUM';
```

- [ ] **Step 2: Apply via psql**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260516160000_investments_hardening/migration.sql | docker exec -i dukonpro-db psql -U dukonpro -d dukonpro 2>&1
```
Expected: `ALTER TABLE`, `CREATE INDEX`, `CREATE INDEX`, `ALTER TABLE`, `ALTER TABLE`, `UPDATE 1`, `UPDATE 1`, `UPDATE 1`.

- [ ] **Step 3: Register in `_prisma_migrations`**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "INSERT INTO _prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) VALUES (gen_random_uuid()::text, 'manual-investments-hardening', NOW(), '20260516160000_investments_hardening', NULL, NULL, NOW(), 1);"
```

- [ ] **Step 4: Regenerate Prisma client**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma generate 2>&1 | tail -3
```

- [ ] **Step 5: Verify**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT conname, pg_get_constraintdef(oid)
   FROM pg_constraint
   WHERE conrelid = '\"investments\"'::regclass AND contype = 'c'
   ORDER BY conname;"
echo "---indexes---"
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'investments' ORDER BY indexname;"
echo "---plan flag---"
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT plan, \"hasInvestments\" FROM subscription_plan_configs ORDER BY plan;"
```
Expected:
- 2 CHECK constraints on `investments`
- `investments_storeId_localId_key` UNIQUE + `investments_storeId_createdAt_idx` indexes present
- START=false, BUSINESS=true, PREMIUM=true

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/prisma/migrations/20260516160000_investments_hardening/
git commit -m "fix(schema): apply investments hardening migration

localId UNIQUE on (storeId,localId), createdAt DESC composite
index, 2 CHECK constraints, hasInvestments tier flag (false on
START, true on BUSINESS/PREMIUM)."
```

---

## Task 3: DTO add `localId`

**Files:**
- Modify: `api/src/modules/investments/dto/create-investment.dto.ts`

- [ ] **Step 1: Read current DTO**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/dto/create-investment.dto.ts
```

- [ ] **Step 2: Add `localId` field**

Use Edit tool. Add this property anywhere inside the class (placing it last, after existing fields):

```typescript
  @ApiPropertyOptional({ description: 'Client-generated UUID for idempotent replay' })
  @IsOptional()
  @IsString()
  localId?: string;
```

If imports are missing, add to existing import line:
```typescript
import { IsOptional, IsString /* + existing */ } from 'class-validator';
import { ApiPropertyOptional /* + existing */ } from '@nestjs/swagger';
```

- [ ] **Step 3: Verify TS compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "create-investment.dto" | head
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/investments/dto/create-investment.dto.ts
git commit -m "feat(investments): DTO accepts optional localId"
```

---

## Task 4: Service refactor (`create` idempotent + audit, `update`/`remove` $transaction + audit)

**Files:**
- Modify: `api/src/modules/investments/investments.service.ts`

- [ ] **Step 1: Read current service end-to-end**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/investments.service.ts
```

Identify:
- Constructor signature (currently `constructor(private prisma: PrismaService) {}`)
- `create(storeId, dto)`, `update(storeId, id, dto)`, `remove(storeId, id)` method signatures
- Path to `AuditLogService`:
  ```bash
  grep -n "AuditLogService\|audit-log.service" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/zakat.service.ts | head
  ```
  Use the same import.

- [ ] **Step 2: Add `AuditLogService` import + inject in constructor**

Add import at top:
```typescript
import { AuditLogService } from '../../common/audit/audit-log.service';
```

(Verify path matches what zakat.service.ts uses; adjust if different.)

Change constructor:
```typescript
@Injectable()
export class InvestmentsService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditLogService,
  ) {}
```

- [ ] **Step 3: Refactor `create` — idempotent + audit**

Replace existing `create` method with:

```typescript
  async create(storeId: string, dto: CreateInvestmentDto, userId: string) {
    // Spec D: idempotent on (storeId, localId).
    if (dto.localId) {
      const existing = await this.prisma.investment.findUnique({
        where: { storeId_localId: { storeId, localId: dto.localId } },
      });
      if (existing) return existing;
    }

    const created = await this.prisma.investment.create({
      data: {
        storeId,
        name: dto.name,
        description: dto.description,
        amount: dto.amount,
        returnAmount: dto.returnAmount,
        investorName: dto.investorName,
        investorPhone: dto.investorPhone,
        status: dto.status,
        startDate: new Date(dto.startDate),
        endDate: dto.endDate ? new Date(dto.endDate) : undefined,
        localId: dto.localId ?? null,
      },
    });

    // Best-effort audit — never blocks the create.
    try {
      await this.audit.record({
        action: 'investment.create',
        entityType: 'investment',
        entityId: created.id,
        userId,
        metadata: { storeId, amount: created.amount.toString(), name: created.name },
      });
    } catch {
      // Swallow — audit failure must not break the user's flow.
    }

    return created;
  }
```

(Verify `audit.record(...)` signature matches the pattern used in `zakat.service.ts` — copy exactly the field names from there.)

- [ ] **Step 4: Refactor `update` — $transaction + audit**

Replace existing `update`:

```typescript
  async update(storeId: string, id: string, dto: UpdateInvestmentDto, userId: string) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.investment.findFirst({
        where: { id, storeId },
      });
      if (!existing) {
        throw new NotFoundException(`Investment ${id} not found`);
      }

      const data: Prisma.InvestmentUpdateInput = {};
      if (dto.name !== undefined) data.name = dto.name;
      if (dto.description !== undefined) data.description = dto.description;
      if (dto.amount !== undefined) data.amount = dto.amount;
      if (dto.returnAmount !== undefined) data.returnAmount = dto.returnAmount;
      if (dto.investorName !== undefined) data.investorName = dto.investorName;
      if (dto.investorPhone !== undefined) data.investorPhone = dto.investorPhone;
      if (dto.status !== undefined) data.status = dto.status;
      if (dto.startDate !== undefined) data.startDate = new Date(dto.startDate);
      if (dto.endDate !== undefined) {
        data.endDate = dto.endDate ? new Date(dto.endDate) : null;
      }

      return tx.investment.update({ where: { id }, data });
    });

    try {
      await this.audit.record({
        action: 'investment.update',
        entityType: 'investment',
        entityId: id,
        userId,
        metadata: { storeId, after: { amount: updated.amount.toString(), status: updated.status } },
      });
    } catch {
      // ignore
    }

    return updated;
  }
```

If the existing `update` method does the field mapping differently, preserve its style — the key change is the `$transaction` wrap + audit call.

- [ ] **Step 5: Refactor `remove` — $transaction + audit**

Replace existing `remove`:

```typescript
  async remove(storeId: string, id: string, userId: string) {
    const removed = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.investment.findFirst({
        where: { id, storeId },
      });
      if (!existing) {
        throw new NotFoundException(`Investment ${id} not found`);
      }
      await tx.investment.delete({ where: { id } });
      return existing;
    });

    try {
      await this.audit.record({
        action: 'investment.delete',
        entityType: 'investment',
        entityId: id,
        userId,
        metadata: { storeId, amount: removed.amount.toString(), name: removed.name },
      });
    } catch {
      // ignore
    }

    return { success: true };
  }
```

(If the existing `remove` returns the deleted entity instead of `{success: true}`, preserve that — match what callers expect.)

- [ ] **Step 6: Verify TS compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "investments.service" | head
```
Expected: no output.

If `audit.record(...)` argument shape differs from zakat's pattern, adjust to match. Check by:
```bash
grep -B1 -A 6 "audit.record" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/zakat.service.ts | head
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/investments/investments.service.ts
git commit -m "feat(investments): idempotent create + \$transaction update/remove + audit

Spec D: mirrors the zakat-service hardening (commit 2557f6d).
- create checks (storeId, localId) for replay; returns existing
- update + remove wrapped in \$transaction (TOCTOU race fix)
- audit.record on all 3 mutation paths with the acting userId
- Method signatures take userId; controller threads it via @CurrentUser"
```

---

## Task 5: Controller refactor (SubscriptionGuard + @RequiresFeature + @CurrentUser)

**Files:**
- Modify: `api/src/modules/investments/investments.controller.ts`

- [ ] **Step 1: Read current controller**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/investments.controller.ts
```

Identify:
- The class-level `@UseGuards(...)` line
- Each mutation handler (`create`, `update`, `remove`) — they currently don't take a `userId` param

- [ ] **Step 2: Add imports**

Add to top of file:
```typescript
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
```

(Verify exact paths via `ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/common/decorators/ /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/common/guards/` — match what zakat.controller.ts uses.)

- [ ] **Step 3: Update class-level decorators**

Find:
```typescript
@UseGuards(JwtAuthGuard, StoreAccessGuard, PermissionsGuard)
@Controller('stores/:storeId/investments')
export class InvestmentsController {
```

Replace with:
```typescript
@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard, PermissionsGuard)
@RequiresFeature('hasInvestments')
@Controller('stores/:storeId/investments')
export class InvestmentsController {
```

- [ ] **Step 4: Thread `userId` into 3 mutation handlers**

For `create`:
```typescript
  @Post()
  @Permissions('investments.write')
  create(
    @Param('storeId') storeId: string,
    @Body() dto: CreateInvestmentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.investmentsService.create(storeId, dto, userId);
  }
```

For `update`:
```typescript
  @Put(':id')
  @Permissions('investments.write')
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateInvestmentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.investmentsService.update(storeId, id, dto, userId);
  }
```

For `remove`:
```typescript
  @Delete(':id')
  @Permissions('investments.write')
  remove(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.investmentsService.remove(storeId, id, userId);
  }
```

(Adapt if existing decorators differ — e.g. `@Permissions` may not be present on every method; preserve actual pattern.)

- [ ] **Step 5: Verify TS compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "investments.controller" | head
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/investments/investments.controller.ts
git commit -m "feat(investments): tier-gate via @RequiresFeature + thread userId

Spec D: SubscriptionGuard + class-level @RequiresFeature('hasInvestments')
matches the zakat pattern. Mutation handlers now extract
@CurrentUser('id') and pass it through to the service for
audit-log attribution."
```

---

## Task 6: Seed `hasInvestments` in plan-config

**Files:**
- Modify: `api/src/modules/subscriptions/subscriptions.service.ts`

- [ ] **Step 1: Locate seedPlanConfigs**

```bash
grep -n "seedPlanConfigs\|hasZakat" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/subscriptions/subscriptions.service.ts
```

- [ ] **Step 2: Add `hasInvestments` to all 3 plans**

Find the 3 plan config objects. After the existing `hasZakat: true/false` line in each, add:

START:
```typescript
        hasZakat: false,
        hasInvestments: false,
```

BUSINESS:
```typescript
        hasZakat: true,
        hasInvestments: true,
```

PREMIUM:
```typescript
        hasZakat: true,
        hasInvestments: true,
```

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "subscriptions.service" | head
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/subscriptions/subscriptions.service.ts
git commit -m "feat(subscriptions): seed hasInvestments per tier"
```

---

## Task 7: Spec tests (update existing + add 6 new) + final verification gate

**Files:**
- Modify: `api/src/modules/investments/investments.service.spec.ts`

- [ ] **Step 1: Read current spec**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/investments.service.spec.ts
```

Note:
- The prisma fake structure
- Existing test calls (likely `service.create(storeId, dto)` — will need `userId` arg added)
- Whether `AuditLogService` mock exists yet

- [ ] **Step 2: Add `AuditLogService` mock + update existing test calls**

In the `Test.createTestingModule` providers array, add (alongside `PrismaService`):
```typescript
{
  provide: AuditLogService,
  useValue: { record: jest.fn().mockResolvedValue(undefined) },
},
```

Add the import at the top of the spec:
```typescript
import { AuditLogService } from '../../common/audit/audit-log.service';
```

For every existing test that calls `service.create(...)`, `service.update(...)`, `service.remove(...)`, append `'test-user-id'` as the new `userId` arg:
```typescript
// Before:
await service.create(storeId, dto);
// After:
await service.create(storeId, dto, 'test-user-id');
```

(grep for these calls and update each.)

The prisma fake also needs `investment.findUnique` (for the new idempotency check) and `$transaction` support. If the fake uses an inline `{}` shape, add:
```typescript
investment: {
  ...existing,
  findUnique: jest.fn(async ({ where }) => {
    // simple in-memory match on storeId_localId compound
    return null;  // default no-existing-row; tests override per-case
  }),
},
$transaction: jest.fn().mockImplementation(async (cb: any) => {
  // Pass a fake `tx` object with the same shape as `prisma`
  if (typeof cb === 'function') return cb(/* the same fake prisma */);
  // Array form (not used by investments) — return Promise.all
  return Promise.all(cb);
}),
```

(Match the pattern used in `zakat.service.spec.ts` from commit `2557f6d`.)

- [ ] **Step 3: Add 6 new tests**

Append a new describe block at the bottom of the spec:

```typescript
describe('Spec D — investments hardening', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('create: passes localId through to prisma.create.data', async () => {
    const createSpy = (prisma.investment.create as jest.Mock).mockResolvedValue({
      id: 'inv-1', amount: { toString: () => '1000' }, name: 'Test', storeId: 's1',
    });
    await service.create(
      's1',
      { name: 'Test', amount: 1000, investorName: 'A', startDate: '2026-01-01', status: 'ACTIVE', localId: 'abc-123' } as any,
      'user-1',
    );
    expect(createSpy.mock.calls[0][0].data.localId).toBe('abc-123');
  });

  it('create: returns existing row when localId already used (idempotent)', async () => {
    (prisma.investment.findUnique as jest.Mock).mockResolvedValue({ id: 'existing-1', name: 'Old' });
    const createSpy = (prisma.investment.create as jest.Mock);

    const result = await service.create(
      's1',
      { name: 'Test', amount: 1000, investorName: 'A', startDate: '2026-01-01', status: 'ACTIVE', localId: 'abc-123' } as any,
      'user-1',
    );

    expect((result as any).id).toBe('existing-1');
    expect(createSpy).not.toHaveBeenCalled();
  });

  it('create: writes investment.create audit log with userId', async () => {
    (prisma.investment.create as jest.Mock).mockResolvedValue({
      id: 'inv-1', amount: { toString: () => '500' }, name: 'X', storeId: 's1',
    });
    const auditMock = (audit as any).record as jest.Mock;
    await service.create(
      's1',
      { name: 'X', amount: 500, investorName: 'A', startDate: '2026-01-01', status: 'ACTIVE' } as any,
      'admin-42',
    );
    expect(auditMock).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'investment.create',
        userId: 'admin-42',
        entityId: 'inv-1',
      }),
    );
  });

  it('update: throws NotFound when row missing', async () => {
    (prisma.investment.findFirst as jest.Mock).mockResolvedValue(null);
    await expect(
      service.update('s1', 'missing-id', { name: 'New' } as any, 'user-1'),
    ).rejects.toThrow(/not found/i);
  });

  it('update: writes investment.update audit log', async () => {
    (prisma.investment.findFirst as jest.Mock).mockResolvedValue({ id: 'inv-1', amount: 100 });
    (prisma.investment.update as jest.Mock).mockResolvedValue({
      id: 'inv-1', amount: { toString: () => '200' }, status: 'ACTIVE',
    });
    const auditMock = (audit as any).record as jest.Mock;
    await service.update('s1', 'inv-1', { amount: 200 } as any, 'admin-42');
    expect(auditMock).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'investment.update', userId: 'admin-42' }),
    );
  });

  it('remove: writes investment.delete audit log', async () => {
    (prisma.investment.findFirst as jest.Mock).mockResolvedValue({
      id: 'inv-1', amount: { toString: () => '100' }, name: 'X', storeId: 's1',
    });
    (prisma.investment.delete as jest.Mock).mockResolvedValue({});
    const auditMock = (audit as any).record as jest.Mock;
    await service.remove('s1', 'inv-1', 'admin-42');
    expect(auditMock).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'investment.delete', userId: 'admin-42' }),
    );
  });
});
```

**ADAPT** to actual mock variable names (likely `prisma`, `service`, `audit`). If the existing spec uses a different scaffold, match its pattern.

- [ ] **Step 4: Run tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- investments 2>&1 | tail -15
```
Expected: existing tests + 6 new = ≥10 pass (was 4 per audit, +6 new). All green.

If existing tests break because the prisma fake doesn't support `$transaction`-as-callback, fix the fake. Iterate until green.

- [ ] **Step 5: Run full unit + e2e gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v "\.spec\." | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail
```
Expected:
- 0 tsc errors
- ≥222 unit (was 216, +6 investments)
- ≥11 e2e

- [ ] **Step 6: Live verification probes**

```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done

# START tier should now get 403
T_START=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001001","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
SID_START=$(docker exec dukonpro-db psql -U dukonpro -d dukonpro -t -A -c \
  "SELECT s.id FROM stores s JOIN users u ON u.id=s.\"ownerId\" WHERE u.phone='+992910001001' LIMIT 1;")
echo "START tier on /investments (expect 403): HTTP=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:4455/api/stores/$SID_START/investments" -H "Authorization: Bearer $T_START")"

# BIZ tier should get 200
T_BIZ=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001002","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
SID_BIZ="d169d2e8-0a24-4a23-844a-5d5e7b690d8c"
echo "BUSINESS tier on /investments (expect 200): HTTP=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:4455/api/stores/$SID_BIZ/investments" -H "Authorization: Bearer $T_BIZ")"

# Idempotent create — same localId twice
LOCAL_ID="qa-spec-d-$(date +%s)"
PAYLOAD="{\"name\":\"QA test\",\"amount\":100,\"investorName\":\"A\",\"startDate\":\"2026-01-01\",\"status\":\"ACTIVE\",\"localId\":\"$LOCAL_ID\"}"
ID1=$(curl -sf -X POST "http://localhost:4455/api/stores/$SID_BIZ/investments" \
  -H "Authorization: Bearer $T_BIZ" -H 'Content-Type: application/json' -d "$PAYLOAD" | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')
ID2=$(curl -sf -X POST "http://localhost:4455/api/stores/$SID_BIZ/investments" \
  -H "Authorization: Bearer $T_BIZ" -H 'Content-Type: application/json' -d "$PAYLOAD" | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')
echo "Idempotency: ID1=$ID1 ID2=$ID2 (should be equal)"

# Cleanup the test row
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c "DELETE FROM investments WHERE \"localId\"='$LOCAL_ID';"

# Audit log
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT action, \"entityId\", \"createdAt\" FROM audit_logs WHERE action LIKE 'investment%' ORDER BY \"createdAt\" DESC LIMIT 5;"
```
Expected:
- START → 403
- BIZ → 200
- ID1 == ID2 (idempotent)
- audit_logs has at least 1 `investment.create` row from the test

- [ ] **Step 7: Final commit (if anything uncommitted)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git status --short
git log --oneline e3fed27..HEAD
```

If clean, just print the commit list.

---

## Self-Review

**Spec coverage:**
- ✅ Schema migration (Spec section A) — Tasks 1 + 2
- ✅ DTO (Spec section C) — Task 3
- ✅ Service refactor (Spec section C) — Task 4
- ✅ Controller refactor (Spec section C) — Task 5
- ✅ Plan-config seed (Spec section C) — Task 6
- ✅ Tests (Spec section D) — Task 7 (steps 2-4)
- ✅ Live verification — Task 7 step 6 (5 probes match acceptance criteria)
- ✅ Final test gate — Task 7 step 5

**Type / name consistency:**
- `localId` field: schema (T1), DTO (T3), service create (T4), tests (T7) ✓
- `userId: string` arg: service signatures (T4), controller (T5), tests (T7) ✓
- `audit.record({action, entityType, entityId, userId, metadata})`: shape used T4 + T7 ✓
- `'hasInvestments'`: schema flag (T1), seedPlanConfigs (T6), `@RequiresFeature` (T5) ✓
- `SubscriptionGuard` + `@RequiresFeature` imports: T5 ✓

**Placeholders:** none — every step has concrete code or commands.

Plan complete and saved to `docs/superpowers/plans/2026-05-16-spec-d-investments-hardening.md`.
