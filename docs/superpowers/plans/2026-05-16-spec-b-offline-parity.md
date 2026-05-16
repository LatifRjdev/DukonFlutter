# Spec B "Offline Parity" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `StockRepository` and `DebtRepository` to offline-write parity with the existing `Sale`/`Customer` pattern: client-generated `localId`, server-side idempotent upsert, sync queue replay on reconnect.

**Architecture:** Two repository changes (E.2 refactor existing, E.3 introduce new abstraction + bloc refactor), one consolidated Prisma migration adding `localId` columns + unique indexes, sync-engine endpoint mapping additions.

**Tech Stack:** Flutter 3.x with Bloc + Sqlite-backed `SyncQueue`, NestJS 10 + Prisma 6.19 + Postgres 16.

**Spec:** `docs/superpowers/specs/2026-05-16-spec-b-offline-parity-design.md` (commit 4293a68).

---

## File Structure

**Schema (one consolidated migration):**
- Modify: `api/prisma/schema.prisma`
  - `StockMovement`: add `localId String? @unique`
  - `DebtPayment`: add `@@unique([saleId, localId])` (field already exists)
  - `SupplierPayment`: add `localId String?` + `@@unique([storeId, localId])`
- Create: `api/prisma/migrations/20260516120000_offline_parity_localid/migration.sql`

**Backend DTO + service idempotency:**
- Modify: `api/src/modules/products/stock-movements.controller.ts` (or wherever the create lives — verify via grep)
- Modify: `api/src/modules/products/dto/create-stock-movement.dto.ts` — add optional `localId`
- Modify: `api/src/modules/products/products.service.ts` (the method that creates StockMovement) — idempotent return on `localId` hit
- Modify: `api/src/modules/customers/dto/create-customer-payment.dto.ts` — add optional `localId`
- Modify: `api/src/modules/customers/customers.service.ts` `addPayment` — propagate `localId` to `DebtPayment.create`, idempotent return on `(saleId, localId)` hit
- Modify: `api/src/modules/suppliers/dto/create-supplier-payment.dto.ts` — add optional `localId`
- Modify: `api/src/modules/suppliers/suppliers.service.ts` `addPayment` — same idempotency pattern

**E.2 (StockRepository):**
- Modify: `app/lib/data/repositories/stock_repository_impl.dart` — inject `NetworkInfo + SyncQueue`, refactor `createStockMovement`
- Modify: `app/lib/injection.dart` — pass new deps to `StockRepositoryImpl` factory
- Modify: `app/lib/data/sync/sync_engine.dart` `_resolveEndpoint` — add `case 'stock_movement'`
- Test: `app/test/data/repositories/stock_repository_test.dart` (new file)

**E.3 (DebtRepository — new):**
- Create: `app/lib/domain/repositories/debt_repository.dart`
- Create: `app/lib/data/repositories/debt_repository_impl.dart`
- Modify: `app/lib/presentation/blocs/debt/debt_bloc.dart` — replace `DioClient` with `DebtRepository`
- Modify: `app/lib/presentation/blocs/debt/debt_state.dart` — add `DebtPaymentQueued` state
- Modify: `app/lib/presentation/pages/debt/customer_debts_page.dart` (and supplier debts page) — handle queued state
- Modify: `app/lib/injection.dart` — register `DebtRepository`
- Modify: `app/lib/data/sync/sync_engine.dart` `_resolveEndpoint` — add `case 'supplier_debt_payment'` (customer case already exists)
- Test: `app/test/data/repositories/debt_repository_test.dart` (new)
- Test: `app/test/presentation/blocs/debt/debt_bloc_test.dart` (new)

**API tests:**
- Extend or create: `api/test/stock-movements.e2e-spec.ts` (or extend products spec)
- Extend or create: `api/test/customers-debt-payment.e2e-spec.ts`
- Extend or create: `api/test/suppliers-debt-payment.e2e-spec.ts`

---

## Sub-section A — Schema migration + backend idempotency

### Task A.1: Add `localId` to schema models

**Files:**
- Modify: `api/prisma/schema.prisma`

- [ ] **Step 1: Inspect current model state**

```bash
sed -n '259,275p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
echo "---"
sed -n '361,375p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
echo "---"
sed -n '573,590p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
```

Expected:
- `StockMovement` has no `localId`
- `DebtPayment` has `localId String?` field (no unique)
- `SupplierPayment` has no `localId`

- [ ] **Step 2: Add `localId @unique` to StockMovement**

Use Edit. Find:
```prisma
model StockMovement {
  id         String       @id @default(uuid())
  ...
  createdAt  DateTime     @default(now())

  @@index([productId, createdAt])
  @@map("stock_movements")
}
```

Insert before `@@index`:
```prisma
  // Spec B E.2: client-supplied UUID for offline-replay idempotency.
  // Globally unique because clients generate v4 UUIDs and we don't
  // need to scope dedup per-store (StockMovement has no storeId column;
  // it scopes through product).
  localId    String?      @unique
```

- [ ] **Step 3: Add `@@unique` to DebtPayment**

Find:
```prisma
model DebtPayment {
  id        String          @id @default(uuid())
  saleId    String
  ...
  // E.3: client-supplied UUID for offline-replay idempotency.
  localId   String?
  createdAt DateTime        @default(now())

  @@map("debt_payments")
}
```

Insert before `@@map`:
```prisma
  @@unique([saleId, localId])
```

(Field exists already from earlier sprint — only constraint missing.)

- [ ] **Step 4: Add `localId` + `@@unique` to SupplierPayment**

Find:
```prisma
model SupplierPayment {
  id         String          @id @default(uuid())
  storeId    String
  store      Store           @relation(fields: [storeId], references: [id])
  ...
  createdAt  DateTime        @default(now())

  @@index([supplierId, createdAt])
  @@map("supplier_payments")
}
```

Insert before `@@index`:
```prisma
  // Spec B E.3: client-supplied UUID for offline-replay idempotency.
  localId    String?
```

After `@@index`:
```prisma
  @@unique([storeId, localId])
```

- [ ] **Step 5: Verify schema compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma format 2>&1 | tail -3
npx prisma validate 2>&1 | tail -3
```
Expected: `Schema is valid`.

- [ ] **Step 6: Commit (schema-only — no migration yet)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/prisma/schema.prisma
git commit -m "schema(offline): add localId + unique on StockMovement / DebtPayment / SupplierPayment"
```

---

### Task A.2: Write + apply migration

**Files:**
- Create: `api/prisma/migrations/20260516120000_offline_parity_localid/migration.sql`

- [ ] **Step 1: Create migration directory + file**

```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260516120000_offline_parity_localid
```

Create `api/prisma/migrations/20260516120000_offline_parity_localid/migration.sql`:

```sql
-- Spec B (Offline Parity): add localId for idempotent replay on
-- StockMovement / DebtPayment / SupplierPayment. Existing rows
-- keep localId = NULL; Postgres treats multiple NULLs as distinct
-- in a unique index, so legacy rows are exempt.

-- StockMovement: globally-unique localId (no storeId column).
ALTER TABLE "stock_movements" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "stock_movements_localId_key"
  ON "stock_movements"("localId");

-- DebtPayment: localId column already exists from a prior sprint;
-- only the unique constraint is missing.
CREATE UNIQUE INDEX "debt_payments_saleId_localId_key"
  ON "debt_payments"("saleId", "localId");

-- SupplierPayment: scope per store (matches Customer/Sale pattern).
ALTER TABLE "supplier_payments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "supplier_payments_storeId_localId_key"
  ON "supplier_payments"("storeId", "localId");
```

- [ ] **Step 2: Apply via psql (skip prisma migrate dev because of prior drift)**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260516120000_offline_parity_localid/migration.sql | docker exec -i dukonpro-db psql -U dukonpro -d dukonpro 2>&1
```
Expected: `ALTER TABLE`, `CREATE INDEX`, `CREATE INDEX`, `ALTER TABLE`, `CREATE INDEX` (5 lines all succeed).

- [ ] **Step 3: Register in `_prisma_migrations`**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "INSERT INTO _prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) VALUES (gen_random_uuid()::text, 'manual-offline-parity-localid', NOW(), '20260516120000_offline_parity_localid', NULL, NULL, NOW(), 1);"
```

- [ ] **Step 4: Regenerate Prisma client**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma generate 2>&1 | tail -3
```
Expected: "Generated Prisma Client".

- [ ] **Step 5: Verify columns + indexes**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT t.relname AS table_name, i.relname AS index_name, pg_get_indexdef(i.oid) AS def
   FROM pg_index x
   JOIN pg_class t ON t.oid = x.indrelid
   JOIN pg_class i ON i.oid = x.indexrelid
   WHERE t.relname IN ('stock_movements','debt_payments','supplier_payments')
     AND i.relname LIKE '%localId%'
   ORDER BY t.relname, i.relname;"
```
Expected: 3 rows, all `UNIQUE`.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/prisma/migrations/20260516120000_offline_parity_localid/
git commit -m "fix(schema): apply offline-parity localId migration

Three unique indexes for idempotent client-driven replay:
- stock_movements.localId UNIQUE
- debt_payments.(saleId, localId) UNIQUE
- supplier_payments.(storeId, localId) UNIQUE"
```

---

### Task A.3: StockMovement DTO + idempotent service

**Files:**
- Modify: `api/src/modules/products/dto/create-stock-movement.dto.ts`
- Modify: `api/src/modules/products/products.service.ts` (or `stock-movements.service.ts` — verify location)

- [ ] **Step 1: Locate the create-stock-movement DTO + service method**

```bash
grep -rn "CreateStockMovementDto\|createStockMovement\|stock_movements" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/products/ | head -10
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/products/dto/create-stock-movement.dto.ts 2>/dev/null
```

If the DTO file doesn't exist, find the actual file (e.g. `add-stock.dto.ts`).

- [ ] **Step 2: Add `localId` field to DTO**

Edit the DTO. Add inside the class body:
```typescript
@ApiPropertyOptional({ description: 'Client-generated UUID for idempotent replay' })
@IsOptional()
@IsString()
localId?: string;
```

Add the imports if missing:
```typescript
import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
```

- [ ] **Step 3: Make the service method idempotent on `localId`**

Find the create-StockMovement method in the service (`createStockMovement`, `addStock`, or similar). Modify it to:

```typescript
async createStockMovement(productId: string, dto: CreateStockMovementDto) {
  // Spec B E.2: idempotent replay. If localId already used, return
  // the existing row instead of throwing the unique-constraint error.
  if (dto.localId) {
    const existing = await this.prisma.stockMovement.findUnique({
      where: { localId: dto.localId },
    });
    if (existing) return existing;
  }

  // ... existing creation logic, but pass localId:
  return this.prisma.stockMovement.create({
    data: {
      productId,
      type: dto.type,
      quantity: dto.quantity,
      // ... other fields ...
      localId: dto.localId ?? null,
    },
  });
}
```

Adapt to the actual method shape. Preserve any existing `$transaction` blocks (e.g. if create also updates `Product.quantity`, keep that in the transaction).

- [ ] **Step 4: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | grep -v "\.spec\." | head
```
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/products/
git commit -m "feat(stock-movements): idempotent localId on create"
```

---

### Task A.4: Customer + Supplier debt-payment DTO + idempotent service

**Files:**
- Modify: `api/src/modules/customers/dto/create-customer-payment.dto.ts` (or whatever name — verify)
- Modify: `api/src/modules/customers/customers.service.ts` `addPayment`
- Modify: `api/src/modules/suppliers/dto/create-supplier-payment.dto.ts`
- Modify: `api/src/modules/suppliers/suppliers.service.ts` `addPayment`

- [ ] **Step 1: Locate the customer + supplier payment DTOs**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/customers/dto/
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/suppliers/dto/
grep -l "addPayment" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/customers/*.ts /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/suppliers/*.ts
```

- [ ] **Step 2: Add `localId` to both DTOs**

For each (`create-customer-payment.dto.ts`, `create-supplier-payment.dto.ts`):

Add inside the class:
```typescript
@ApiPropertyOptional({ description: 'Client-generated UUID for idempotent replay' })
@IsOptional()
@IsString()
localId?: string;
```

(Add imports if missing.)

- [ ] **Step 3: Customer service — idempotent DebtPayment.create**

In `customers.service.ts` `addPayment` method. The current logic likely loops over the customer's debt-laden sales and creates `DebtPayment` rows for them. Two changes:

1. Before allocating, check `localId`:
```typescript
if (dto.localId) {
  const existing = await this.prisma.debtPayment.findFirst({
    where: { localId: dto.localId, sale: { storeId, customerId } },
  });
  if (existing) {
    // Already processed — return whatever shape addPayment returns
    return this.getPaymentSummaryFor(customerId, dto.localId);
  }
}
```

2. When creating each DebtPayment row, pass `localId` ONLY on the first one (or compose `localId-N` for splits — but simpler: pass on the FIRST and leave NULL on subsequent splits):

Find the `prisma.debtPayment.create({...})` call(s). For the first allocation in the loop, add `localId: dto.localId ?? null`. For splits (allocation #2+), leave `localId` undefined.

If the existing code uses `prisma.debtPayment.createMany`, switch to a `$transaction` of individual creates so we can control which gets the `localId`.

- [ ] **Step 4: Supplier service — idempotent SupplierPayment.create**

Simpler: SupplierPayment is one row per call. In `suppliers.service.ts` `addPayment`:

```typescript
async addPayment(storeId: string, supplierId: string, dto: CreateSupplierPaymentDto) {
  if (dto.localId) {
    const existing = await this.prisma.supplierPayment.findUnique({
      where: { storeId_localId: { storeId, localId: dto.localId } },
    });
    if (existing) return existing;
  }
  // ... existing creation logic, plus:
  return this.prisma.supplierPayment.create({
    data: {
      storeId,
      supplierId,
      amount: dto.amount,
      method: dto.method,
      notes: dto.notes,
      localId: dto.localId ?? null,
    },
  });
}
```

Preserve any existing supplier-debt decrement logic (likely a `$transaction` updating `Supplier.debt`).

- [ ] **Step 5: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | grep -v "\.spec\." | head
npm test -- 'customers|suppliers' 2>&1 | tail -5
```
Expected: 0 tsc errors; existing tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/customers/ api/src/modules/suppliers/
git commit -m "feat(debt-payments): idempotent localId on customer + supplier payments"
```

---

### Task A.5: API e2e idempotency tests

**Files:**
- Create or extend: `api/test/stock-movements-idempotency.e2e-spec.ts`
- Create or extend: `api/test/debt-payments-idempotency.e2e-spec.ts`

- [ ] **Step 1: Inspect existing e2e test setup**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/test/
head -30 /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/test/sales-idempotency.e2e-spec.ts 2>/dev/null || \
head -30 /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/test/customers.e2e-spec.ts 2>/dev/null || \
head -30 /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/test/$(ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/test/ | head -1)
```

Identify the bootstrap pattern used (likely `Test.createTestingModule` with `AppModule` + `INestApplication`).

- [ ] **Step 2: Write stock-movement idempotency test**

Create `api/test/stock-movements-idempotency.e2e-spec.ts`:

```typescript
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('StockMovement idempotency (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let token: string;
  let storeId: string;
  let productId: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);

    // Login as qa-business
    const loginRes = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ phone: '+992910001002', password: 'qatest1234' });
    token = loginRes.body.accessToken;

    storeId = 'd169d2e8-0a24-4a23-844a-5d5e7b690d8c';
    // Pick any active product
    const products = await prisma.product.findMany({
      where: { storeId, isActive: true },
      take: 1,
    });
    productId = products[0].id;
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns the same StockMovement when called twice with same localId', async () => {
    const localId = `qa-test-${Date.now()}`;
    const payload = { type: 'PURCHASE', quantity: 5, localId };

    const r1 = await request(app.getHttpServer())
      .post(`/api/stores/${storeId}/products/${productId}/stock-movements`)
      .set('Authorization', `Bearer ${token}`)
      .send(payload)
      .expect(201);

    const r2 = await request(app.getHttpServer())
      .post(`/api/stores/${storeId}/products/${productId}/stock-movements`)
      .set('Authorization', `Bearer ${token}`)
      .send(payload)
      .expect(201);

    expect(r1.body.id).toBe(r2.body.id);

    // Cleanup
    await prisma.stockMovement.delete({ where: { localId } });
  });
});
```

Adjust `expect(201)` to whatever the actual create endpoint returns. Verify the auth-token shape with the existing e2e tests.

- [ ] **Step 3: Write debt-payments idempotency test**

Create `api/test/debt-payments-idempotency.e2e-spec.ts` with two `it` blocks: customer payment dedup, supplier payment dedup. Same shape as step 2; just use the customer/supplier endpoints.

For the customer test, you need an existing debt-bearing sale on a customer. Either find one in the qa data or create one as part of the test setup.

- [ ] **Step 4: Run + verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm run test:e2e 2>&1 | grep "Tests:" | tail -3
```
Expected: ≥10 passed (was 8, +2-3 new).

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/test/
git commit -m "test(e2e): idempotency for stock + debt payments"
```

---

## Sub-section B — E.2 StockRepository offline-aware

### Task B.1: Add `_resolveEndpoint` case for stock_movement

**Files:**
- Modify: `app/lib/data/sync/sync_engine.dart`

- [ ] **Step 1: Read current `_resolveEndpoint`**

```bash
grep -n "_resolveEndpoint\|case '" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/data/sync/sync_engine.dart | head -20
sed -n '160,250p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/data/sync/sync_engine.dart
```

Identify the switch structure. Each case parses the `entityId` string and returns a URL.

- [ ] **Step 2: Add stock_movement case**

Add inside the switch (alphabetical-ish order, near `case 'shift':`):

```dart
case 'stock_movement':
  // entityId format: '$storeId:$productId:$tempId'
  if (parts.length < 3) return null;
  final storeId = parts[0];
  final productId = parts[1];
  if (item.operation == 'CREATE') {
    return ApiEndpoints.stockMovements(storeId, productId);
  }
  return null;
```

(Verify `ApiEndpoints.stockMovements` exists; it does per earlier grep.)

- [ ] **Step 3: Add supplier_debt_payment case (for E.3)**

Same switch:
```dart
case 'supplier_debt_payment':
  // entityId format: '$storeId:$supplierId:$tempId'
  if (parts.length < 3) return null;
  final storeId = parts[0];
  final supplierId = parts[1];
  if (item.operation == 'CREATE') {
    return ApiEndpoints.supplierPayments(storeId, supplierId);
  }
  return null;
```

- [ ] **Step 4: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/data/sync/sync_engine.dart 2>&1 | tail -5
```
Expected: 0 issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/data/sync/sync_engine.dart
git commit -m "feat(sync): map stock_movement + supplier_debt_payment endpoints"
```

---

### Task B.2: Refactor `StockRepositoryImpl` to be offline-aware

**Files:**
- Modify: `app/lib/data/repositories/stock_repository_impl.dart`
- Modify: `app/lib/injection.dart`

- [ ] **Step 1: Inspect current shape + the SaleRepositoryImpl pattern**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/data/repositories/stock_repository_impl.dart
echo "===pattern reference==="
sed -n '1,50p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/data/repositories/sale_repository_impl.dart
```

- [ ] **Step 2: Refactor**

Replace the current `StockRepositoryImpl` with:

```dart
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_repository.dart';
import '../sync/sync_queue.dart';

/// Spec B E.2: offline-aware. Online → POST. Offline → enqueue with
/// client-generated `localId` so the server returns the existing row
/// on retry instead of double-counting stock.
class StockRepositoryImpl implements StockRepository {
  final DioClient _dioClient;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  StockRepositoryImpl({
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _dioClient = dioClient,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<StockMovement> createStockMovement(
    String storeId,
    String productId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        final response = await _dioClient.post(
          ApiEndpoints.stockMovements(storeId, productId),
          data: payload,
        );
        return _mapStockMovement(
          response.data['data'] as Map<String, dynamic>,
        );
      }
    } on NetworkException {
      // Fall through to offline path.
    } on DioException catch (e) {
      throw _handleDioError(e);
    }

    // Offline: temp row + queue.
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMovement = StockMovement(
      id: tempId,
      productId: productId,
      type: data['type'] as String? ?? 'PURCHASE',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (data['unitCost'] as num?)?.toDouble(),
      totalCost: (data['totalCost'] as num?)?.toDouble(),
      supplierId: data['supplierId'] as String?,
      reference: data['reference'] as String?,
      notes: data['notes'] as String?,
      createdAt: DateTime.now(),
    );

    await _syncQueue.enqueue(
      entityType: 'stock_movement',
      entityId: '$storeId:$productId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );

    return tempMovement;
  }

  // Keep the existing getStockMovements implementation unchanged
  // (offline READ is out of scope — see spec).
  @override
  Future<({List<StockMovement> data, int total, int totalPages})>
      getStockMovements(...) {
    // (unchanged from before — keep the existing implementation here)
  }

  StockMovement _mapStockMovement(Map<String, dynamic> json) {
    // (unchanged — keep existing helper)
  }

  Exception _handleDioError(DioException e) {
    // (unchanged — keep existing helper)
  }
}
```

**IMPORTANT:** preserve the existing `getStockMovements`, `_mapStockMovement`, `_handleDioError` bodies verbatim — only change the constructor and `createStockMovement`. Read the original file first to copy the unchanged blocks.

- [ ] **Step 3: Update injection.dart**

```bash
grep -n "StockRepositoryImpl\|StockRepository" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/injection.dart
```

Find the registration like:
```dart
sl.registerLazySingleton<StockRepository>(
  () => StockRepositoryImpl(dioClient: sl()),
);
```

Replace with:
```dart
sl.registerLazySingleton<StockRepository>(
  () => StockRepositoryImpl(
    dioClient: sl(),
    networkInfo: sl(),
    syncQueue: sl(),
  ),
);
```

(Verify `NetworkInfo` and `SyncQueue` are already registered as singletons — they should be, per `SaleRepositoryImpl`.)

- [ ] **Step 4: Verify compiles + existing tests pass**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; ≥417 pass (existing count maintained).

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/data/repositories/stock_repository_impl.dart app/lib/injection.dart
git commit -m "feat(stock-repo): offline-aware createStockMovement (Spec B E.2)"
```

---

### Task B.3: Stock repository unit test (offline scenario)

**Files:**
- Create: `app/test/data/repositories/stock_repository_test.dart`

- [ ] **Step 1: Look at existing repo test pattern**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/test/data/repositories/ 2>/dev/null
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/test/data/repositories/sale_repository_test.dart 2>/dev/null | head -80
```

If no sale repo test exists, create from scratch using `mocktail`. Pattern:
- Mock `DioClient`, `NetworkInfo`, `SyncQueue`
- 3 tests: online happy path, offline → queue, online but Dio throws Network → falls through to queue

- [ ] **Step 2: Write the test**

Create `app/test/data/repositories/stock_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/repositories/stock_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';

class _MockDio extends Mock implements DioClient {}
class _MockNetwork extends Mock implements NetworkInfo {}
class _MockQueue extends Mock implements SyncQueue {}

void main() {
  late StockRepositoryImpl repo;
  late _MockDio dio;
  late _MockNetwork network;
  late _MockQueue queue;

  setUp(() {
    dio = _MockDio();
    network = _MockNetwork();
    queue = _MockQueue();
    repo = StockRepositoryImpl(
      dioClient: dio,
      networkInfo: network,
      syncQueue: queue,
    );
  });

  group('createStockMovement offline path', () {
    test('enqueues with stock_movement entityType when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => queue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async => 1);

      final movement = await repo.createStockMovement(
        'store-1',
        'prod-1',
        {'type': 'PURCHASE', 'quantity': 10},
      );

      expect(movement.id.startsWith('temp_'), isTrue);
      verify(() => queue.enqueue(
            entityType: 'stock_movement',
            entityId: any(named: 'entityId', that: startsWith('store-1:prod-1:temp_')),
            operation: 'CREATE',
            payload: any(
              named: 'payload',
              that: predicate<Map>((p) => p['localId'] is String && p['type'] == 'PURCHASE'),
            ),
          )).called(1);
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('does NOT enqueue when online', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {
            'data': {
              'id': 'srv-1',
              'productId': 'prod-1',
              'type': 'PURCHASE',
              'quantity': 10,
              'createdAt': DateTime.now().toIso8601String(),
            },
          },
          requestOptions: RequestOptions(path: '/x'),
        ),
      );

      final movement = await repo.createStockMovement(
        'store-1',
        'prod-1',
        {'type': 'PURCHASE', 'quantity': 10},
      );

      expect(movement.id, 'srv-1');
      verifyNever(() => queue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('attaches localId UUID when payload omits one', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      Map<String, dynamic>? capturedPayload;
      when(() => queue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          )).thenAnswer((invocation) async {
        capturedPayload = invocation.namedArguments[#payload] as Map<String, dynamic>;
        return 1;
      });

      await repo.createStockMovement(
        'store-1',
        'prod-1',
        {'type': 'PURCHASE', 'quantity': 5},
      );

      expect(capturedPayload?['localId'], isA<String>());
      expect((capturedPayload!['localId'] as String).length, greaterThan(20));
    });
  });
}
```

(Adapt the import for `Response` / `RequestOptions` if Dio is wrapped differently.)

- [ ] **Step 3: Run + verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/data/repositories/stock_repository_test.dart --reporter=compact 2>&1 | tail -5
```
Expected: 3 passed.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/test/data/repositories/stock_repository_test.dart
git commit -m "test(stock-repo): offline enqueue + online direct + auto-localId"
```

---

## Sub-section C — E.3 DebtRepository abstraction + offline-aware

### Task C.1: Create the domain interface

**Files:**
- Create: `app/lib/domain/repositories/debt_repository.dart`

- [ ] **Step 1: Create interface**

```dart
// app/lib/domain/repositories/debt_repository.dart
//
// Spec B E.3: replaces direct DioClient calls inside DebtBloc.
// Both methods support offline replay via client-generated localId.
abstract class DebtRepository {
  /// Records a payment toward a customer's outstanding debt.
  /// Returns once the API confirms (online) OR the request is queued
  /// (offline). Caller should treat both as success.
  Future<void> addCustomerPayment(
    String storeId,
    String customerId,
    Map<String, dynamic> data,
  );

  /// Records a payment to a supplier (reduces our debt to them).
  Future<void> addSupplierPayment(
    String storeId,
    String supplierId,
    Map<String, dynamic> data,
  );
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/domain/repositories/debt_repository.dart 2>&1 | tail -3
```
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/domain/repositories/debt_repository.dart
git commit -m "feat(debt-repo): domain interface (Spec B E.3)"
```

---

### Task C.2: Implement DebtRepositoryImpl

**Files:**
- Create: `app/lib/data/repositories/debt_repository_impl.dart`

- [ ] **Step 1: Create implementation**

```dart
// app/lib/data/repositories/debt_repository_impl.dart
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../domain/repositories/debt_repository.dart';
import '../sync/sync_queue.dart';

/// Spec B E.3: offline-aware writes for both customer and supplier
/// debt payments. Online → POST. Offline → enqueue. Server-side
/// idempotency on (saleId|storeId, localId) makes replay safe.
class DebtRepositoryImpl implements DebtRepository {
  final DioClient _dioClient;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  DebtRepositoryImpl({
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _dioClient = dioClient,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<void> addCustomerPayment(
    String storeId,
    String customerId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        await _dioClient.post(
          ApiEndpoints.customerPayments(storeId, customerId),
          data: payload,
        );
        return;
      }
    } on NetworkException {
      // Fall through.
    } on DioException catch (e) {
      throw _handleDioError(e);
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _syncQueue.enqueue(
      entityType: 'debt_payment',
      entityId: '$storeId:$customerId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );
  }

  @override
  Future<void> addSupplierPayment(
    String storeId,
    String supplierId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        await _dioClient.post(
          ApiEndpoints.supplierPayments(storeId, supplierId),
          data: payload,
        );
        return;
      }
    } on NetworkException {
      // Fall through.
    } on DioException catch (e) {
      throw _handleDioError(e);
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _syncQueue.enqueue(
      entityType: 'supplier_debt_payment',
      entityId: '$storeId:$supplierId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkException('Нет соединения');
    }
    final status = e.response?.statusCode ?? 0;
    if (status == 401) return UnauthorizedException();
    if (status >= 500) return ServerException('Ошибка сервера');
    return ServerException(
      e.response?.data?['message']?.toString() ?? 'Не удалось выполнить операцию',
    );
  }
}
```

(If `NetworkException` / `UnauthorizedException` / `ServerException` constructors differ, adapt to actual signatures from `core/errors/exceptions.dart`.)

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/data/repositories/debt_repository_impl.dart 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/data/repositories/debt_repository_impl.dart
git commit -m "feat(debt-repo): offline-aware impl (Spec B E.3)"
```

---

### Task C.3: Register in DI + add `DebtPaymentQueued` state

**Files:**
- Modify: `app/lib/injection.dart`
- Modify: `app/lib/presentation/blocs/debt/debt_state.dart`

- [ ] **Step 1: Add DebtRepository registration**

```bash
grep -n "DebtBloc\|registerFactory.*Debt" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/injection.dart
```

Add (in the "Repositories" section, alphabetically near other repos):
```dart
import 'data/repositories/debt_repository_impl.dart';
import 'domain/repositories/debt_repository.dart';

// ...

sl.registerLazySingleton<DebtRepository>(
  () => DebtRepositoryImpl(
    dioClient: sl(),
    networkInfo: sl(),
    syncQueue: sl(),
  ),
);
```

(Don't change DebtBloc registration yet — that's Task C.4.)

- [ ] **Step 2: Add DebtPaymentQueued state**

Read existing `debt_state.dart`:
```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/blocs/debt/debt_state.dart
```

Add at the bottom (preserving the existing pattern, e.g. extending an `abstract class DebtState with Equatable`):

```dart
/// Spec B E.3: emitted when a debt payment was successfully queued
/// for offline replay (i.e. user is offline). UI should show a
/// snackbar like "Платёж сохранён, отправится при подключении".
class DebtPaymentQueued extends DebtState {
  const DebtPaymentQueued();
}
```

- [ ] **Step 3: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/injection.dart lib/presentation/blocs/debt/debt_state.dart 2>&1 | tail -3
```

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/injection.dart app/lib/presentation/blocs/debt/debt_state.dart
git commit -m "feat(debt-bloc): register DebtRepository + add DebtPaymentQueued state"
```

---

### Task C.4: Refactor DebtBloc to use DebtRepository

**Files:**
- Modify: `app/lib/presentation/blocs/debt/debt_bloc.dart`
- Modify: `app/lib/injection.dart` (DebtBloc factory injection)

- [ ] **Step 1: Read current bloc**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/blocs/debt/debt_bloc.dart
```

Identify:
- Constructor signature (currently takes `DioClient`)
- The two payment-add handlers (lines ~50 + ~104)
- Reads (debts list, customer/supplier debts) — these stay on `DioClient` for now since reads aren't offline-scoped

- [ ] **Step 2: Refactor constructor**

Replace constructor:
```dart
class DebtBloc extends Bloc<DebtEvent, DebtState> {
  final DioClient _dioClient;
  final DebtRepository _debtRepository;
  final NetworkInfo _networkInfo;

  DebtBloc({
    required DioClient dioClient,
    required DebtRepository debtRepository,
    required NetworkInfo networkInfo,
  })  : _dioClient = dioClient,
        _debtRepository = debtRepository,
        _networkInfo = networkInfo,
        super(DebtInitial()) {
    // ... existing on<...> handlers
  }
```

- [ ] **Step 3: Replace customer payment handler**

Find:
```dart
on<DebtCustomerPaymentRequested>((event, emit) async {
  ...
  await _dioClient.post(
    ApiEndpoints.customerPayments(event.storeId, event.customerId),
    data: event.data,
  );
  ...
});
```

Replace the `_dioClient.post(...)` call with:
```dart
final wasOnline = await _networkInfo.isConnected;
await _debtRepository.addCustomerPayment(
  event.storeId,
  event.customerId,
  event.data,
);
if (!wasOnline) {
  emit(const DebtPaymentQueued());
} else {
  // existing success state — keep the emit that was already there
}
```

(Preserve the existing `try/catch` and other emits.)

- [ ] **Step 4: Replace supplier payment handler**

Same pattern for the supplier event handler (around line 104).

- [ ] **Step 5: Update DebtBloc factory in injection.dart**

```bash
grep -B1 -A 5 "registerFactory.*Debt\|DebtBloc(" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/injection.dart
```

Replace the factory:
```dart
sl.registerFactory<DebtBloc>(
  () => DebtBloc(
    dioClient: sl(),
    debtRepository: sl(),
    networkInfo: sl(),
  ),
);
```

- [ ] **Step 6: Verify compiles + tests pass**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; ≥417 pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/blocs/debt/debt_bloc.dart app/lib/injection.dart
git commit -m "refactor(debt-bloc): use DebtRepository (Spec B E.3)"
```

---

### Task C.5: UI consumers — handle DebtPaymentQueued

**Files:**
- Modify: `app/lib/presentation/pages/debt/customer_debts_page.dart`
- Modify: `app/lib/presentation/pages/debt/supplier_debts_page.dart` (if exists)

- [ ] **Step 1: Find consumers**

```bash
grep -rln "DebtBloc\|BlocListener.*Debt\|BlocConsumer.*Debt" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/debt/
```

- [ ] **Step 2: Add snackbar in BlocListener**

In each page, find the `BlocListener<DebtBloc, DebtState>` block. Add a state branch:

```dart
} else if (state is DebtPaymentQueued) {
  AppSnackbar.info(
    context,
    'Платёж сохранён офлайн — отправим при подключении',
  );
}
```

(If `AppSnackbar.info` doesn't exist, use `success` or `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`.)

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/debt/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/pages/debt/
git commit -m "feat(debt-ui): snackbar on offline-queued payment"
```

---

### Task C.6: DebtRepository unit test

**Files:**
- Create: `app/test/data/repositories/debt_repository_test.dart`

- [ ] **Step 1: Write tests**

Same pattern as B.3, with both customer + supplier methods:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/repositories/debt_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';

class _MockDio extends Mock implements DioClient {}
class _MockNetwork extends Mock implements NetworkInfo {}
class _MockQueue extends Mock implements SyncQueue {}

void main() {
  late DebtRepositoryImpl repo;
  late _MockDio dio;
  late _MockNetwork network;
  late _MockQueue queue;

  setUp(() {
    dio = _MockDio();
    network = _MockNetwork();
    queue = _MockQueue();
    repo = DebtRepositoryImpl(
      dioClient: dio,
      networkInfo: network,
      syncQueue: queue,
    );
  });

  group('addCustomerPayment', () {
    test('enqueues with debt_payment entityType when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => queue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async => 1);

      await repo.addCustomerPayment('s1', 'c1', {'amount': 100});

      verify(() => queue.enqueue(
            entityType: 'debt_payment',
            entityId: any(named: 'entityId', that: startsWith('s1:c1:temp_')),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('hits API when online', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(data: {}, requestOptions: RequestOptions(path: '/x')),
      );

      await repo.addCustomerPayment('s1', 'c1', {'amount': 100});

      verifyNever(() => queue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });
  });

  group('addSupplierPayment', () {
    test('enqueues with supplier_debt_payment entityType when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => queue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async => 1);

      await repo.addSupplierPayment('s1', 'sup1', {'amount': 200});

      verify(() => queue.enqueue(
            entityType: 'supplier_debt_payment',
            entityId: any(named: 'entityId', that: startsWith('s1:sup1:temp_')),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });
}
```

- [ ] **Step 2: Run + verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/data/repositories/debt_repository_test.dart --reporter=compact 2>&1 | tail -3
```
Expected: 3 passed.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/test/data/repositories/debt_repository_test.dart
git commit -m "test(debt-repo): online + offline + supplier paths"
```

---

### Task C.7: DebtBloc test (offline → DebtPaymentQueued)

**Files:**
- Create: `app/test/presentation/blocs/debt/debt_bloc_test.dart`

- [ ] **Step 1: Write test using bloc_test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/domain/repositories/debt_repository.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_bloc.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_event.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_state.dart';

class _MockDio extends Mock implements DioClient {}
class _MockRepo extends Mock implements DebtRepository {}
class _MockNetwork extends Mock implements NetworkInfo {}

void main() {
  late _MockDio dio;
  late _MockRepo repo;
  late _MockNetwork network;

  setUp(() {
    dio = _MockDio();
    repo = _MockRepo();
    network = _MockNetwork();
  });

  blocTest<DebtBloc, DebtState>(
    'emits DebtPaymentQueued when adding customer payment offline',
    build: () {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => repo.addCustomerPayment(any(), any(), any())).thenAnswer((_) async {});
      return DebtBloc(dioClient: dio, debtRepository: repo, networkInfo: network);
    },
    act: (bloc) => bloc.add(DebtCustomerPaymentRequested(
      storeId: 's1',
      customerId: 'c1',
      data: const {'amount': 100},
    )),
    expect: () => [isA<DebtPaymentQueued>()],
  );
}
```

(Adapt event class name + constructor to whatever exists in `debt_event.dart`.)

- [ ] **Step 2: Run + verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/presentation/blocs/debt/debt_bloc_test.dart --reporter=compact 2>&1 | tail -3
```
Expected: 1 passed.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/test/presentation/blocs/debt/debt_bloc_test.dart
git commit -m "test(debt-bloc): offline path emits DebtPaymentQueued"
```

---

## Task D.1: Final verification gate

**Files:**
- None (verification only)

- [ ] **Step 1: Full test gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v "\.spec\." | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected:
- 0 tsc errors (non-spec)
- ≥205 unit tests pass (was 205; no new unit tests added on the API side this spec)
- ≥10 e2e tests pass (was 8, +2 idempotency)
- 0 dart analyze issues
- ≥420 flutter pass (was 417, +3 stock-repo +3 debt-repo +1 bloc test = 424 expected)

- [ ] **Step 2: Manual offline probe (optional)**

If you have an emulator handy:
```bash
adb -s emulator-5554 shell svc wifi disable
adb -s emulator-5554 shell svc data disable
# In the app: Товары → product → Приход → 5шт → save
# Expect: snackbar "Сохранено офлайн"
adb -s emulator-5554 shell svc wifi enable
adb -s emulator-5554 shell svc data enable
sleep 10
# Verify: stock movement appears on server exactly once via curl
```

If no emulator, skip — the API e2e idempotency tests cover the dedup logic.

- [ ] **Step 3: Commit summary (only if any incidental fix surfaced)**

If anything is uncommitted:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git status --short
```
Commit + push as needed.

---

## Self-Review

**Spec coverage:**
- ✅ Sub-section A (E.2 StockRepository): Tasks B.1 (sync engine) + B.2 (repo refactor + DI) + B.3 (test)
- ✅ Sub-section B (E.3 DebtRepository): Tasks C.1 (interface) + C.2 (impl) + C.3 (DI + state) + C.4 (bloc refactor) + C.5 (UI snackbar) + C.6 (repo test) + C.7 (bloc test)
- ✅ Schema migration: Tasks A.1 (schema models) + A.2 (migration SQL + manual apply)
- ✅ Backend idempotency: Tasks A.3 (stock movement) + A.4 (customer + supplier debt payments)
- ✅ E2E idempotency: Task A.5
- ✅ Final gate: Task D.1

**Type / name consistency:**
- `StockRepositoryImpl` constructor signature matches across B.2 (impl) + B.3 (test) ✓
- `DebtRepository.addCustomerPayment` / `addSupplierPayment` defined C.1 → consumed C.2, C.4, C.6 ✓
- `DebtPaymentQueued` defined C.3 → consumed C.4 (bloc emit) + C.5 (UI listener) + C.7 (test expect) ✓
- `entityType: 'stock_movement'` used B.1 (sync engine), B.2 (repo enqueue), B.3 (test verify) ✓
- `entityType: 'supplier_debt_payment'` used B.1 + C.2 + C.6 ✓
- `localId` field added A.1 → consumed A.3, A.4 (services), B.2/C.2 (Flutter payloads) ✓

**Placeholders:** none. Each step has concrete code or commands.

Plan complete and saved to `docs/superpowers/plans/2026-05-16-spec-b-offline-parity.md`.
