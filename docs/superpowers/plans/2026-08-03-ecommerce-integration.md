# E-commerce Integration (PREMIUM) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a PREMIUM-tier Dukon store connect an external website (any generic REST/webhook-capable platform) so that orders placed on the site decrement Dukon's stock, create a real `Sale` on a new `ONLINE` channel, and Dukon pushes real-time stock updates back out to the site — with full reporting visibility and idempotent, transactional order create/cancel handling.

**Architecture:** One new backend module (`api/src/modules/ecommerce/`) with three focused services — `EcommerceIntegrationService` (per-store settings + manual product-mapping CRUD, JWT-authenticated), `EcommerceOrdersService` (the public inbound webhook, authenticated by a per-store API key, one Prisma transaction per order), and `EcommerceOutboundService` (fire-and-forget outbound stock-update pushes with retry, called both from the new module and wired into the three existing places that already mutate `Product.quantity`). Two new Prisma models (`EcommerceIntegration`, `ExternalProductMapping`) plus two new fields on `Sale` (`channel`, `externalOrderId`) and one new plan-config flag (`hasEcommerceIntegration`). Reporting gets a `channel` filter. Mobile gets a new Settings screen pair (integration config + product mapping).

**Tech Stack:** NestJS, Prisma/PostgreSQL, class-validator, Jest (backend); Next.js/TanStack Query (admin — one small cross-cutting change only); Flutter/Dio (mobile).

---

## Spec coverage

| Design spec section | Task(s) |
|---|---|
| Модель данных (`EcommerceIntegration`, `ExternalProductMapping`, `SalesChannel`, `Sale.channel`/`externalOrderId`, `hasEcommerceIntegration`) | Task 1 |
| `hasEcommerceIntegration` reachable via `PUT /admin/plans/:plan` | Task 2 |
| Исходящий поток (outbound push, retry, anti-spam) | Task 3 |
| Управление интеграцией + сопоставление товаров (backend) | Task 4 |
| Входящий поток (`order.created`/`order.cancelled` webhook) | Task 5 |
| Точка входа исходящего потока — существующий код, меняющий `Product.quantity` | Task 6 |
| Отчётность (канал-фильтр + разбивка) | Task 7 |
| UI в мобильном приложении | Task 8 |

---

## Task 1: Prisma schema — `EcommerceIntegration`, `ExternalProductMapping`, `Sale` fields, plan flag

**Files:**
- Modify: `api/prisma/schema.prisma`
- Create: Prisma migration under `api/prisma/migrations/`

- [ ] **Step 1: Add the two new models and the `SalesChannel` enum**

In `api/prisma/schema.prisma`, find `model Store {` (line 53) and add the following directly after the `Store` model closes (right before `model SubscriptionPlanConfig {` at line 181), so the new models sit next to the entity they're most tightly coupled to:

```prisma
model EcommerceIntegration {
  id                 String   @id @default(uuid())
  storeId            String   @unique
  store              Store    @relation(fields: [storeId], references: [id])
  apiKey             String   @unique
  outboundWebhookUrl String?
  enabled            Boolean  @default(true)
  createdAt          DateTime @default(now())
  updatedAt          DateTime @updatedAt

  @@map("ecommerce_integrations")
}

model ExternalProductMapping {
  id                String   @id @default(uuid())
  storeId           String
  store             Store    @relation(fields: [storeId], references: [id])
  productId         String
  product           Product  @relation(fields: [productId], references: [id])
  externalProductId String
  createdAt         DateTime @default(now())

  @@unique([storeId, externalProductId])
  @@index([productId])
  @@map("external_product_mappings")
}

enum SalesChannel {
  IN_STORE
  ONLINE
}
```

(The `@@index([productId])` is an addition beyond the spec's literal model — `EcommerceOutboundService`, built in Task 3, needs to look up every mapping for a given product on every stock change, and that lookup has no other index to use without this.)

- [ ] **Step 2: Add the two relation back-references**

`Store` (starts line 53) needs back-references for the two new models above — find the existing relation list inside `model Store { ... }` (look for lines like `products Product[]` / `sales Sale[]`) and add two lines alongside them:
```prisma
  ecommerceIntegration    EcommerceIntegration?
  externalProductMappings ExternalProductMapping[]
```

`Product` (starts line 222) needs one back-reference — find its existing relation list (`saleItems SaleItem[]` etc., around line 245) and add:
```prisma
  externalMappings ExternalProductMapping[]
```

- [ ] **Step 3: Add `channel`/`externalOrderId` to `Sale`**

In `model Sale {` (line 298), add two fields. Place them right after `status SaleStatus @default(COMPLETED)` (existing line, currently followed by `notes String?`):
```prisma
  channel         SalesChannel @default(IN_STORE)
  externalOrderId String?
```

Then add a unique index on the pair, next to the existing `@@unique([storeId, receiptNo])` line inside the same model:
```prisma
  @@unique([storeId, externalOrderId])
```

(Postgres treats `NULL` as distinct for uniqueness purposes, so this only rejects a genuine duplicate `externalOrderId` for the same store — every in-store sale, which has `externalOrderId: null`, is unaffected. This also gives Task 5's webhook handler free idempotency: replaying the same `order.created` webhook twice will hit this constraint on the second attempt rather than silently double-selling stock.)

- [ ] **Step 4: Add `hasEcommerceIntegration` to `SubscriptionPlanConfig`**

In `model SubscriptionPlanConfig {` (line 181), add one field alongside the other `has*` flags (e.g. right after `hasBatchProfitability Boolean @default(false)`):
```prisma
  hasEcommerceIntegration Boolean @default(false)
```

- [ ] **Step 5: Generate the migration**

Run: `cd api && npx prisma migrate dev --name add_ecommerce_integration`

This shared dev database has a history of pre-existing checksum drift on unrelated older migrations (encountered and safely resolved in two earlier, independently-reviewed feature branches on this same repo — see `api/prisma/migrations/20260730000000_add_banners/` and `.../20260731000000_add_impersonation_requests/` for the precedent). If `migrate dev` refuses to proceed due to drift on migrations unrelated to this change:
1. Run `npx prisma migrate diff --from-url "$DATABASE_URL" --to-schema-datamodel prisma/schema.prisma --script` to confirm the only real delta is what this task added.
2. Hand-write `api/prisma/migrations/<timestamp>_add_ecommerce_integration/migration.sql` with the following content (this is what `migrate dev` should generate from the schema changes above — use it verbatim if you have to hand-write it, or diff your generated file against it to sanity-check):

```sql
-- CreateEnum
CREATE TYPE "SalesChannel" AS ENUM ('IN_STORE', 'ONLINE');

-- AlterTable
ALTER TABLE "sales" ADD COLUMN "channel" "SalesChannel" NOT NULL DEFAULT 'IN_STORE';
ALTER TABLE "sales" ADD COLUMN "externalOrderId" TEXT;

-- AlterTable
ALTER TABLE "subscription_plan_configs" ADD COLUMN "hasEcommerceIntegration" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "ecommerce_integrations" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "apiKey" TEXT NOT NULL,
    "outboundWebhookUrl" TEXT,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ecommerce_integrations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "external_product_mappings" (
    "id" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "externalProductId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "external_product_mappings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ecommerce_integrations_storeId_key" ON "ecommerce_integrations"("storeId");

-- CreateIndex
CREATE UNIQUE INDEX "ecommerce_integrations_apiKey_key" ON "ecommerce_integrations"("apiKey");

-- CreateIndex
CREATE INDEX "external_product_mappings_productId_idx" ON "external_product_mappings"("productId");

-- CreateIndex
CREATE UNIQUE INDEX "external_product_mappings_storeId_externalProductId_key" ON "external_product_mappings"("storeId", "externalProductId");

-- CreateIndex
CREATE UNIQUE INDEX "sales_storeId_externalOrderId_key" ON "sales"("storeId", "externalOrderId");

-- AddForeignKey
ALTER TABLE "ecommerce_integrations" ADD CONSTRAINT "ecommerce_integrations_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "external_product_mappings" ADD CONSTRAINT "external_product_mappings_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "external_product_mappings" ADD CONSTRAINT "external_product_mappings_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
```
3. Apply it: `npx prisma db execute --file prisma/migrations/<timestamp>_add_ecommerce_integration/migration.sql --schema prisma/schema.prisma`
4. Mark it applied: `npx prisma migrate resolve --applied <timestamp>_add_ecommerce_integration`
5. Confirm: `npx prisma migrate status` should report "Database schema is up to date!"

Either way (clean `migrate dev` or the manual fallback), finish with: `npx prisma generate` to regenerate the Prisma client with `prisma.ecommerceIntegration` / `prisma.externalProductMapping` and the new `Sale`/`SubscriptionPlanConfig` fields.

- [ ] **Step 6: Run the full backend suite to confirm nothing broke**

Run: `cd api && npx jest`
Expected: PASS, same count as before this task (schema-only change, no behavior change yet).

- [ ] **Step 7: Commit**

```bash
cd api
git add prisma/schema.prisma prisma/migrations
git commit -m "feat(ecommerce): add EcommerceIntegration/ExternalProductMapping models, Sale.channel, hasEcommerceIntegration flag"
```

---

## Task 2: Wire `hasEcommerceIntegration` into the admin plan-config UI

**Context:** `SubscriptionPlanConfig`'s boolean feature flags are **not** automatically surfaced anywhere outside the schema — three separate places hardcode the known flag list (confirmed by checking the four most-recently-added flags, `hasZakat`/`hasInvestments`/`hasLoyalty`/`hasBatchProfitability`, none of which appear in any of the three places below). Without this task, an admin has no way to actually turn PREMIUM-only e-commerce access on for any store, even after Task 1's migration lands.

**Files:**
- Modify: `api/src/modules/admin/dto/update-plan.dto.ts`
- Modify: `api/src/modules/admin/admin.service.ts:485` (`updatePlan`)
- Modify: `admin/lib/types.ts` (`Plan` interface)
- Modify: `admin/app/(admin)/subscriptions/plans/page.tsx` (`FEATURE_LABELS`)

- [ ] **Step 1: Add the field to `UpdatePlanDto`**

In `api/src/modules/admin/dto/update-plan.dto.ts`, add after the existing `hasInventory?: boolean;` field (the last one in the class):
```typescript
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasEcommerceIntegration?: boolean;
```

- [ ] **Step 2: Add the whitelist branch in `AdminService.updatePlan()`**

In `api/src/modules/admin/admin.service.ts`, inside `updatePlan()` (starts line 485), add one line to the `updateData` whitelist, right after the existing `hasInventory` branch:
```typescript
    if (dto.hasEcommerceIntegration !== undefined)
      updateData.hasEcommerceIntegration = dto.hasEcommerceIntegration;
```

- [ ] **Step 3: Add a test confirming the field round-trips**

Find the existing `admin.service.spec.ts` test(s) for `updatePlan` (search `describe.*updatePlan` or similar) and add one alongside them:
```typescript
  it('updates hasEcommerceIntegration when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan('PREMIUM' as any, {
      hasEcommerceIntegration: true,
    } as any);

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasEcommerceIntegration: true },
    });
    expect((result as any).hasEcommerceIntegration).toBe(true);
  });
```
(Match this test's exact fake-Prisma shape to whatever `admin.service.spec.ts` already uses for its other `updatePlan` tests — read the file first, this snippet assumes the same `prisma.subscriptionPlanConfig.findUnique`/`.update` jest-mock pattern used elsewhere in that file.)

- [ ] **Step 4: Run the test**

Run: `cd api && npx jest admin.service.spec.ts -t updatePlan`
Expected: PASS

- [ ] **Step 5: Add the field to the admin frontend `Plan` type**

In `admin/lib/types.ts`, inside `export interface Plan { ... }`, add after `hasInventory: boolean;`:
```typescript
  hasEcommerceIntegration: boolean;
```

- [ ] **Step 6: Add the label so the toggle actually renders**

In `admin/app/(admin)/subscriptions/plans/page.tsx`, inside `const FEATURE_LABELS: Record<string, string> = { ... }`, add after `hasInventory: 'Инвентаризация',`:
```typescript
  hasEcommerceIntegration: 'Интернет-магазин',
```

- [ ] **Step 7: Verify the admin build**

Run: `cd admin && npx tsc --noEmit`
Expected: clean.

- [ ] **Step 8: Commit**

```bash
cd api && git add src/modules/admin/dto/update-plan.dto.ts src/modules/admin/admin.service.ts src/modules/admin/admin.service.spec.ts
git commit -m "feat(admin): wire hasEcommerceIntegration into the plan-config update path"
cd ../admin && git add lib/types.ts "app/(admin)/subscriptions/plans/page.tsx"
git commit -m "feat(admin): surface hasEcommerceIntegration in the plan-config UI"
```

---

## Task 3: `EcommerceOutboundService` — outbound stock-update push with retry

**Context:** This is built before the modules that call it (Tasks 5 and 6) so those tasks can depend on a real, tested class rather than a stub. There is no existing outbound-HTTP convention anywhere in this codebase (confirmed: no `axios`/`@nestjs/axios`/`node-fetch` dependency, no retry helper) — this uses Node's built-in global `fetch` (available in the Node version this project runs on) rather than adding a new dependency for a single call site.

**Files:**
- Create: `api/src/modules/ecommerce/ecommerce-outbound.service.ts`
- Test: `api/src/modules/ecommerce/ecommerce-outbound.service.spec.ts`
- Create: `api/src/modules/ecommerce/ecommerce.module.ts` (started here, extended in Tasks 4/5)

- [ ] **Step 1: Write the failing tests**

```typescript
// api/src/modules/ecommerce/ecommerce-outbound.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

function makePrismaFake() {
  return {
    externalProductMapping: {
      findMany: jest.fn(async () => [] as any[]),
    },
    product: {
      findUnique: jest.fn(async () => ({ id: 'p1', quantity: 10 }) as any),
    },
    ecommerceIntegration: {
      findUnique: jest.fn(async () => null as any),
    },
  };
}

describe('EcommerceOutboundService', () => {
  let service: EcommerceOutboundService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendToStoreUsers: jest.Mock };
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendToStoreUsers: jest.fn(async () => undefined) };
    fetchMock = jest.fn();
    global.fetch = fetchMock as any;

    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceOutboundService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();
    service = moduleRef.get(EcommerceOutboundService);
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.clearAllMocks();
  });

  it('does nothing when the product has no external mapping', async () => {
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([]);

    await service.pushStockUpdate('p1', 'store-1');

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('does nothing when the store has no integration, or it is disabled, or has no outboundWebhookUrl', async () => {
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: false,
      outboundWebhookUrl: 'https://example.com/webhook',
    });

    await service.pushStockUpdate('p1', 'store-1');

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('posts the current quantity for every mapped externalProductId on success', async () => {
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    (prisma.product.findUnique as jest.Mock).mockResolvedValue({
      id: 'p1',
      quantity: 7,
    });
    fetchMock.mockResolvedValue({ ok: true, status: 200 });

    await service.pushStockUpdate('p1', 'store-1');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://example.com/webhook',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ externalProductId: 'sku-1', quantity: 7 }),
      }),
    );
  });

  it('retries up to 3 times with backoff on network error, then succeeds on a later attempt', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock
      .mockRejectedValueOnce(new Error('network down'))
      .mockResolvedValueOnce({ ok: true, status: 200 });

    const pushPromise = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000);
    await pushPromise;

    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('gives up after 3 failed attempts and notifies the store owner once', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock.mockRejectedValue(new Error('network down'));

    const pushPromise = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await pushPromise;

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(notifications.sendToStoreUsers).toHaveBeenCalledTimes(1);
    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.any(String),
      'ECOMMERCE_PUSH_FAILED',
    );
  });

  it('does not send a second failure notification within 15 minutes for the same store', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock.mockRejectedValue(new Error('network down'));

    const first = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await first;

    const second = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await second;

    expect(notifications.sendToStoreUsers).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd api && npx jest ecommerce-outbound.service.spec.ts`
Expected: FAIL — cannot find module `./ecommerce-outbound.service`

- [ ] **Step 3: Implement `EcommerceOutboundService`**

```typescript
// api/src/modules/ecommerce/ecommerce-outbound.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const RETRY_DELAYS_MS = [1000, 4000, 16000];
const FAILURE_NOTIFICATION_COOLDOWN_MS = 15 * 60 * 1000;

@Injectable()
export class EcommerceOutboundService {
  private readonly logger = new Logger(EcommerceOutboundService.name);

  // In-memory per-store cooldown for the "push failed" owner notification.
  // Single-instance-only (no Redis/queue infra exists in this project —
  // see the design spec's explicit non-goals). If this service ever runs
  // on more than one instance, each instance tracks its own cooldown
  // independently, so an owner could in theory get one notification per
  // instance within the same 15-minute window — an acceptable, documented
  // limitation, not something to fix here.
  private readonly lastFailureNotifiedAt = new Map<string, number>();

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  /**
   * Called after any successful change to Product.quantity (sale, refund,
   * purchase, adjustment, or an e-commerce order itself — self-echo from
   * the last case is harmless, just one extra outbound check). Fire-and-
   * forget from the caller's perspective — this method itself awaits its
   * own retries internally but never throws.
   */
  async pushStockUpdate(productId: string, storeId: string): Promise<void> {
    try {
      const mappings = await this.prisma.externalProductMapping.findMany({
        where: { productId, storeId },
      });
      if (mappings.length === 0) return;

      const integration = await this.prisma.ecommerceIntegration.findUnique({
        where: { storeId },
      });
      if (!integration || !integration.enabled || !integration.outboundWebhookUrl) {
        return;
      }

      const product = await this.prisma.product.findUnique({
        where: { id: productId },
        select: { quantity: true },
      });
      if (!product) return;

      for (const mapping of mappings) {
        const succeeded = await this.postWithRetry(integration.outboundWebhookUrl, {
          externalProductId: mapping.externalProductId,
          quantity: product.quantity,
        });
        if (!succeeded) {
          await this.notifyFailureIfNotRecentlyNotified(storeId);
        }
      }
    } catch (err) {
      // Never let an outbound-push failure affect the caller — this is
      // explicitly a best-effort side channel, not part of the operation
      // that changed stock in Dukon.
      this.logger.warn(`pushStockUpdate failed for product ${productId}: ${err}`);
    }
  }

  private async postWithRetry(
    url: string,
    body: { externalProductId: string; quantity: number },
  ): Promise<boolean> {
    for (let attempt = 0; attempt < RETRY_DELAYS_MS.length; attempt++) {
      if (attempt > 0) {
        await this.sleep(RETRY_DELAYS_MS[attempt - 1]);
      }
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
        if (res.ok) return true;
        this.logger.warn(
          `Outbound stock push to ${url} returned ${res.status} (attempt ${attempt + 1}/${RETRY_DELAYS_MS.length})`,
        );
      } catch (err) {
        this.logger.warn(
          `Outbound stock push to ${url} failed (attempt ${attempt + 1}/${RETRY_DELAYS_MS.length}): ${err}`,
        );
      }
    }
    return false;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private async notifyFailureIfNotRecentlyNotified(storeId: string): Promise<void> {
    const now = Date.now();
    const last = this.lastFailureNotifiedAt.get(storeId);
    if (last && now - last < FAILURE_NOTIFICATION_COOLDOWN_MS) return;

    this.lastFailureNotifiedAt.set(storeId, now);
    await this.notifications.sendToStoreUsers(
      storeId,
      'Не удалось обновить остатки на сайте',
      'Проверьте настройки интеграции с интернет-магазином — обновление остатков не дошло до вашего сайта.',
      'ECOMMERCE_PUSH_FAILED',
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd api && npx jest ecommerce-outbound.service.spec.ts`
Expected: PASS (6 tests)

- [ ] **Step 5: Create the module (minimal, extended by later tasks)**

```typescript
// api/src/modules/ecommerce/ecommerce.module.ts
import { Module } from '@nestjs/common';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  providers: [EcommerceOutboundService],
  exports: [EcommerceOutboundService],
})
export class EcommerceModule {}
```

- [ ] **Step 6: Register the module**

In `api/src/app.module.ts`, add `EcommerceModule` to the `imports: [...]` array (find the existing list — it currently ends with `AdminModule, BannersModule, ImpersonationModule,` or similar — add `EcommerceModule` alongside them) and add the corresponding import statement at the top of the file next to the other feature-module imports.

- [ ] **Step 7: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
cd api
git add src/modules/ecommerce/ src/app.module.ts
git commit -m "feat(ecommerce): add EcommerceOutboundService with retry and anti-spam owner notification"
```

---

## Task 4: `EcommerceIntegrationService` + Controller — settings & product-mapping CRUD

**Files:**
- Create: `api/src/modules/ecommerce/dto/upsert-ecommerce-integration.dto.ts`
- Create: `api/src/modules/ecommerce/dto/upsert-product-mapping.dto.ts`
- Create: `api/src/modules/ecommerce/ecommerce-integration.service.ts`
- Create: `api/src/modules/ecommerce/ecommerce-integration.controller.ts`
- Test: `api/src/modules/ecommerce/ecommerce-integration.service.spec.ts`
- Modify: `api/src/modules/ecommerce/ecommerce.module.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// api/src/modules/ecommerce/ecommerce-integration.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    ecommerceIntegration: {
      findUnique: jest.fn(async () => null as any),
      upsert: jest.fn(async ({ create, update }: any) => ({
        id: 'ei-1',
        ...create,
        ...update,
      })),
      update: jest.fn(async ({ data }: any) => ({ id: 'ei-1', ...data })),
    },
    externalProductMapping: {
      findMany: jest.fn(async () => [] as any[]),
      upsert: jest.fn(async ({ create }: any) => ({ id: 'm-1', ...create })),
      delete: jest.fn(async () => undefined),
      findUnique: jest.fn(async () => null as any),
    },
  };
}

describe('EcommerceIntegrationService', () => {
  let service: EcommerceIntegrationService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceIntegrationService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(EcommerceIntegrationService);
  });

  it('getSettings returns null when no integration exists yet', async () => {
    const result = await service.getSettings('store-1');
    expect(result).toBeNull();
  });

  it('upsertSettings creates a new integration with a generated apiKey on first call', async () => {
    const result = await service.upsertSettings('store-1', {
      outboundWebhookUrl: 'https://site.example/webhook',
      enabled: true,
    });

    expect(prisma.ecommerceIntegration.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: 'store-1' },
        create: expect.objectContaining({
          storeId: 'store-1',
          outboundWebhookUrl: 'https://site.example/webhook',
          enabled: true,
          apiKey: expect.any(String),
        }),
        update: expect.objectContaining({
          outboundWebhookUrl: 'https://site.example/webhook',
          enabled: true,
        }),
      }),
    );
    expect((result as any).apiKey).toBeDefined();
  });

  it('regenerateApiKey throws NotFoundException when no integration exists', async () => {
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue(null);
    await expect(service.regenerateApiKey('store-1')).rejects.toThrow(NotFoundException);
  });

  it('regenerateApiKey replaces apiKey with a new value', async () => {
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      id: 'ei-1',
      apiKey: 'old-key',
    });

    await service.regenerateApiKey('store-1');

    const call = (prisma.ecommerceIntegration.update as jest.Mock).mock.calls[0][0];
    expect(call.where).toEqual({ storeId: 'store-1' });
    expect(call.data.apiKey).toBeDefined();
    expect(call.data.apiKey).not.toBe('old-key');
  });

  it('upsertMapping creates a mapping when externalProductId is non-empty', async () => {
    await service.upsertMapping('store-1', 'product-1', 'sku-123');

    expect(prisma.externalProductMapping.upsert).toHaveBeenCalledWith({
      where: { storeId_externalProductId: { storeId: 'store-1', externalProductId: 'sku-123' } },
      create: { storeId: 'store-1', productId: 'product-1', externalProductId: 'sku-123' },
      update: { productId: 'product-1' },
    });
  });

  it('upsertMapping deletes any existing mapping for the product when externalProductId is empty', async () => {
    (prisma.externalProductMapping.findUnique as jest.Mock).mockResolvedValue({
      id: 'm-1',
      storeId: 'store-1',
      productId: 'product-1',
    });

    await service.upsertMapping('store-1', 'product-1', '');

    expect(prisma.externalProductMapping.delete).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd api && npx jest ecommerce-integration.service.spec.ts`
Expected: FAIL — cannot find module `./ecommerce-integration.service`

- [ ] **Step 3: Write the DTOs**

```typescript
// api/src/modules/ecommerce/dto/upsert-ecommerce-integration.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUrl, IsBoolean } from 'class-validator';

export class UpsertEcommerceIntegrationDto {
  @ApiPropertyOptional({ example: 'https://my-shop.example.com/dukon-webhook' })
  @IsOptional()
  @IsUrl({ require_tld: false })
  outboundWebhookUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
```

```typescript
// api/src/modules/ecommerce/dto/upsert-product-mapping.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class UpsertProductMappingDto {
  // Empty string / omitted means "remove the mapping for this product" —
  // matches the mobile screen's single editable text field per product
  // (Task 8): clearing the field and saving deletes the mapping.
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  externalProductId?: string;
}
```

- [ ] **Step 4: Implement `EcommerceIntegrationService`**

```typescript
// api/src/modules/ecommerce/ecommerce-integration.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { UpsertEcommerceIntegrationDto } from './dto/upsert-ecommerce-integration.dto';

@Injectable()
export class EcommerceIntegrationService {
  constructor(private prisma: PrismaService) {}

  private generateApiKey(): string {
    return randomBytes(24).toString('hex');
  }

  async getSettings(storeId: string) {
    return this.prisma.ecommerceIntegration.findUnique({ where: { storeId } });
  }

  async upsertSettings(storeId: string, dto: UpsertEcommerceIntegrationDto) {
    return this.prisma.ecommerceIntegration.upsert({
      where: { storeId },
      create: {
        storeId,
        apiKey: this.generateApiKey(),
        outboundWebhookUrl: dto.outboundWebhookUrl,
        enabled: dto.enabled ?? true,
      },
      update: {
        ...(dto.outboundWebhookUrl !== undefined && {
          outboundWebhookUrl: dto.outboundWebhookUrl,
        }),
        ...(dto.enabled !== undefined && { enabled: dto.enabled }),
      },
    });
  }

  async regenerateApiKey(storeId: string) {
    const existing = await this.prisma.ecommerceIntegration.findUnique({
      where: { storeId },
    });
    if (!existing) {
      throw new NotFoundException('E-commerce integration not configured for this store');
    }
    return this.prisma.ecommerceIntegration.update({
      where: { storeId },
      data: { apiKey: this.generateApiKey() },
    });
  }

  async listMappings(storeId: string) {
    return this.prisma.externalProductMapping.findMany({
      where: { storeId },
      include: { product: { select: { id: true, name: true, sku: true } } },
    });
  }

  async upsertMapping(storeId: string, productId: string, externalProductId?: string) {
    if (!externalProductId) {
      const existing = await this.prisma.externalProductMapping.findUnique({
        where: { storeId_productId: { storeId, productId } } as any,
      });
      if (existing) {
        await this.prisma.externalProductMapping.delete({ where: { id: existing.id } });
      }
      return null;
    }

    return this.prisma.externalProductMapping.upsert({
      where: {
        storeId_externalProductId: { storeId, externalProductId },
      },
      create: { storeId, productId, externalProductId },
      update: { productId },
    });
  }
}
```

**Before running the tests:** the `upsertMapping` deletion branch above looks up an existing mapping by a `storeId_productId` compound key, but Task 1's schema only declared `@@unique([storeId, externalProductId])` on `ExternalProductMapping` — there is no `storeId_productId` unique key, so `findUnique({ where: { storeId_productId: ... } })` will not compile against the generated Prisma client. Fix this before proceeding: change that lookup to `findFirst({ where: { storeId, productId } })` instead (a plain filter, not a unique-key lookup — one product should only ever have zero or one mapping row in practice via this service's own upsert logic, but `findFirst` doesn't require a matching `@@unique` to exist). Update the code above to:
```typescript
      const existing = await this.prisma.externalProductMapping.findFirst({
        where: { storeId, productId },
      });
```
(This correction is deliberately left as a step here rather than baked into Step 4's code, because working through *why* the naive version doesn't compile — and confirming that against the real generated Prisma client types — is exactly the kind of thing this plan wants you to verify against the actual schema rather than copy blindly.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd api && npx jest ecommerce-integration.service.spec.ts`
Expected: PASS (6 tests)

- [ ] **Step 6: Write the controller**

```typescript
// api/src/modules/ecommerce/ecommerce-integration.controller.ts
import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';
import { RequiresFeature } from '../../common/decorators/requires-feature.decorator';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { UpsertEcommerceIntegrationDto } from './dto/upsert-ecommerce-integration.dto';
import { UpsertProductMappingDto } from './dto/upsert-product-mapping.dto';

@ApiTags('Ecommerce')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard, SubscriptionGuard)
@RequiresFeature('hasEcommerceIntegration')
@Controller('stores/:storeId/ecommerce')
export class EcommerceIntegrationController {
  constructor(private readonly integrationService: EcommerceIntegrationService) {}

  @Get('integration')
  @ApiOperation({ summary: 'Get the current e-commerce integration settings, if configured' })
  getSettings(@Param('storeId') storeId: string) {
    return this.integrationService.getSettings(storeId);
  }

  @Put('integration')
  @ApiOperation({ summary: 'Create or update the e-commerce integration settings' })
  upsertSettings(@Param('storeId') storeId: string, @Body() dto: UpsertEcommerceIntegrationDto) {
    return this.integrationService.upsertSettings(storeId, dto);
  }

  @Post('integration/regenerate-key')
  @ApiOperation({ summary: 'Invalidate the current inbound API key and generate a new one' })
  regenerateApiKey(@Param('storeId') storeId: string) {
    return this.integrationService.regenerateApiKey(storeId);
  }

  @Get('mappings')
  @ApiOperation({ summary: 'List all external-product-id mappings for this store' })
  listMappings(@Param('storeId') storeId: string) {
    return this.integrationService.listMappings(storeId);
  }

  @Put('mappings/:productId')
  @ApiOperation({ summary: 'Set (or clear, with an empty body) the external product id for a Dukon product' })
  upsertMapping(
    @Param('storeId') storeId: string,
    @Param('productId') productId: string,
    @Body() dto: UpsertProductMappingDto,
  ) {
    return this.integrationService.upsertMapping(storeId, productId, dto.externalProductId);
  }
}
```

- [ ] **Step 7: Register the controller and service in the module**

Update `api/src/modules/ecommerce/ecommerce.module.ts`:
```typescript
import { Module } from '@nestjs/common';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { EcommerceIntegrationController } from './ecommerce-integration.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [EcommerceIntegrationController],
  providers: [EcommerceOutboundService, EcommerceIntegrationService],
  exports: [EcommerceOutboundService],
})
export class EcommerceModule {}
```

- [ ] **Step 8: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
cd api
git add src/modules/ecommerce/
git commit -m "feat(ecommerce): add integration settings and product-mapping CRUD, gated by hasEcommerceIntegration"
```

---

## Task 5: `EcommerceOrdersService` + Controller — inbound webhook (`order.created` / `order.cancelled`)

**Files:**
- Create: `api/src/modules/ecommerce/dto/ecommerce-webhook.dto.ts`
- Create: `api/src/modules/ecommerce/ecommerce-orders.service.ts`
- Create: `api/src/modules/ecommerce/ecommerce-orders.controller.ts`
- Test: `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts`
- Modify: `api/src/modules/ecommerce/ecommerce.module.ts`

- [ ] **Step 1: Write the failing tests**

This is the most involved test file in the plan — it exercises the full transactional order-create and order-cancel flows, including both rejection paths.

```typescript
// api/src/modules/ecommerce/ecommerce-orders.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { ForbiddenException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { EcommerceOrdersService } from './ecommerce-orders.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EcommerceOutboundService } from './ecommerce-outbound.service';

function makePrismaFake() {
  const tx = {
    customer: {
      upsert: jest.fn(async ({ create }: any) => ({ id: 'cust-1', ...create })),
    },
    sale: {
      create: jest.fn(async ({ data }: any) => ({ id: 'sale-1', ...data, items: [] })),
      findUnique: jest.fn(async () => null as any),
      update: jest.fn(async ({ data }: any) => ({ id: 'sale-1', ...data })),
    },
    saleItem: {
      findMany: jest.fn(async () => [] as any[]),
    },
    product: {
      updateMany: jest.fn(async () => ({ count: 1 })),
      update: jest.fn(async () => ({})),
    },
    stockMovement: {
      createMany: jest.fn(async () => ({ count: 1 })),
    },
    delivery: {
      create: jest.fn(async () => ({ id: 'del-1' })),
    },
  };

  return {
    ecommerceIntegration: {
      findUnique: jest.fn(async () => ({
        storeId: 'store-1',
        apiKey: 'valid-key',
        enabled: true,
      })),
    },
    subscription: {
      findUnique: jest.fn(async () => ({ storeId: 'store-1', plan: 'PREMIUM', status: 'ACTIVE' })),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async () => ({ plan: 'PREMIUM', hasEcommerceIntegration: true, hasDelivery: false })),
    },
    externalProductMapping: {
      findMany: jest.fn(async () => [
        { externalProductId: 'sku-1', productId: 'p1' },
      ] as any[]),
    },
    product: {
      findMany: jest.fn(async () => [
        { id: 'p1', name: 'Товар 1', quantity: 10, sellPrice: 150, costPrice: 100 },
      ] as any[]),
    },
    sale: {
      findUnique: jest.fn(async () => null as any),
    },
    $transaction: jest.fn(async (cb: any) => cb(tx)),
    __tx: tx,
  };
}

function makeOrderCreatedDto(overrides: Partial<any> = {}) {
  return {
    event: 'order.created',
    externalOrderId: 'site-order-1',
    items: [{ externalProductId: 'sku-1', quantity: 2, price: 150 }],
    customer: { name: 'Иван Иванов', phone: '+992900000000', address: 'ул. Рудаки 1' },
    totalAmount: 300,
    ...overrides,
  };
}

describe('EcommerceOrdersService', () => {
  let service: EcommerceOrdersService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendToStoreUsers: jest.Mock };
  let outbound: { pushStockUpdate: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendToStoreUsers: jest.fn(async () => undefined) };
    outbound = { pushStockUpdate: jest.fn(async () => undefined) };

    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceOrdersService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: EcommerceOutboundService, useValue: outbound },
      ],
    }).compile();
    service = moduleRef.get(EcommerceOrdersService);
  });

  it('rejects with UnauthorizedException when the api key does not match', async () => {
    await expect(
      service.handleWebhook('store-1', 'wrong-key', makeOrderCreatedDto()),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('rejects with ForbiddenException when the store plan lacks hasEcommerceIntegration', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'START',
      hasEcommerceIntegration: false,
    });
    await expect(
      service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto()),
    ).rejects.toThrow(ForbiddenException);
  });

  it('creates a sale, decrements stock, and links a customer on a valid order.created', async () => {
    const result = await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());

    expect(prisma.__tx.customer.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId_phone: { storeId: 'store-1', phone: '+992900000000' } },
      }),
    );
    expect(prisma.__tx.sale.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          channel: 'ONLINE',
          paymentType: 'CARD',
          externalOrderId: 'site-order-1',
          status: 'COMPLETED',
        }),
      }),
    );
    expect(prisma.__tx.product.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'p1', quantity: { gte: 2 } },
        data: { quantity: { decrement: 2 } },
      }),
    );
    expect((result as any).id).toBe('sale-1');
  });

  it('creates a Delivery when the plan has hasDelivery enabled', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
      hasEcommerceIntegration: true,
      hasDelivery: true,
    });

    await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());

    expect(prisma.__tx.delivery.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          address: 'ул. Рудаки 1',
          status: 'NEW',
        }),
      }),
    );
  });

  it('rejects the whole order (422) and notifies the owner when a line item has no mapping', async () => {
    const dto = makeOrderCreatedDto({
      items: [{ externalProductId: 'unmapped-sku', quantity: 1, price: 100 }],
    });

    await expect(service.handleWebhook('store-1', 'valid-key', dto)).rejects.toThrow();
    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect(notifications.sendToStoreUsers).toHaveBeenCalled();
  });

  it('rejects the whole order (422) and notifies the owner when stock is insufficient', async () => {
    (prisma.product.findMany as jest.Mock).mockResolvedValue([
      { id: 'p1', name: 'Товар 1', quantity: 1, sellPrice: 150, costPrice: 100 },
    ]);
    const dto = makeOrderCreatedDto({
      items: [{ externalProductId: 'sku-1', quantity: 5, price: 150 }],
    });

    await expect(service.handleWebhook('store-1', 'valid-key', dto)).rejects.toThrow();
    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect(notifications.sendToStoreUsers).toHaveBeenCalled();
  });

  it('is idempotent: replaying the same externalOrderId returns the existing sale without reprocessing', async () => {
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue({ id: 'sale-existing' });

    const result = await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());

    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect((result as any).id).toBe('sale-existing');
  });

  it('cancels an existing sale, restores stock, and marks it CANCELLED', async () => {
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue({
      id: 'sale-1',
      status: 'COMPLETED',
      externalOrderId: 'site-order-1',
    });
    (prisma.__tx.saleItem.findMany as jest.Mock).mockResolvedValue([
      { productId: 'p1', quantity: 2 },
    ]);

    await service.handleWebhook('store-1', 'valid-key', {
      event: 'order.cancelled',
      externalOrderId: 'site-order-1',
    });

    expect(prisma.__tx.product.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'p1' },
        data: { quantity: { increment: 2 } },
      }),
    );
    expect(prisma.__tx.sale.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'CANCELLED' } }),
    );
  });

  it('returns 404 (idempotent) when cancelling an order Dukon never saw', async () => {
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.handleWebhook('store-1', 'valid-key', {
        event: 'order.cancelled',
        externalOrderId: 'unknown-order',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('pushes an outbound stock update for every affected product after a successful order.created', async () => {
    await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());
    expect(outbound.pushStockUpdate).toHaveBeenCalledWith('p1', 'store-1');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: FAIL — cannot find module `./ecommerce-orders.service`

- [ ] **Step 3: Write the webhook DTO**

```typescript
// api/src/modules/ecommerce/dto/ecommerce-webhook.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsString,
  IsOptional,
  IsNumber,
  IsArray,
  ValidateNested,
  ValidateIf,
  Min,
} from 'class-validator';

export class EcommerceOrderItemDto {
  @ApiProperty()
  @IsString()
  externalProductId: string;

  @ApiProperty()
  @IsNumber()
  @Min(1)
  quantity: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;
}

export class EcommerceCustomerDto {
  @ApiProperty()
  @IsString()
  name: string;

  @ApiProperty()
  @IsString()
  phone: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;
}

export class EcommerceWebhookDto {
  @ApiProperty({ enum: ['order.created', 'order.cancelled'] })
  @IsIn(['order.created', 'order.cancelled'])
  event: 'order.created' | 'order.cancelled';

  @ApiProperty()
  @IsString()
  externalOrderId: string;

  @ApiPropertyOptional({ type: [EcommerceOrderItemDto] })
  @ValidateIf((o) => o.event === 'order.created')
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EcommerceOrderItemDto)
  items?: EcommerceOrderItemDto[];

  @ApiPropertyOptional()
  @ValidateIf((o) => o.event === 'order.created')
  @ValidateNested()
  @Type(() => EcommerceCustomerDto)
  customer?: EcommerceCustomerDto;

  @ApiPropertyOptional()
  @ValidateIf((o) => o.event === 'order.created')
  @IsNumber()
  @Min(0)
  totalAmount?: number;
}
```

- [ ] **Step 4: Implement `EcommerceOrdersService`**

```typescript
// api/src/modules/ecommerce/ecommerce-orders.service.ts
import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceWebhookDto } from './dto/ecommerce-webhook.dto';

@Injectable()
export class EcommerceOrdersService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private outbound: EcommerceOutboundService,
  ) {}

  async handleWebhook(storeId: string, apiKey: string, dto: EcommerceWebhookDto) {
    await this.assertAuthorized(storeId, apiKey);

    if (dto.event === 'order.created') {
      return this.createOrder(storeId, dto);
    }
    return this.cancelOrder(storeId, dto.externalOrderId);
  }

  private async assertAuthorized(storeId: string, apiKey: string): Promise<void> {
    const integration = await this.prisma.ecommerceIntegration.findUnique({
      where: { storeId },
    });
    if (!integration || integration.apiKey !== apiKey || !integration.enabled) {
      throw new UnauthorizedException('Invalid or disabled e-commerce integration API key');
    }

    // Defensive re-check: the integration row can exist and even carry a
    // valid key after the store has since downgraded off PREMIUM (e.g.
    // subscription lapsed) — mirrors SubscriptionGuard's own logic
    // (subscription.guard.ts) since that guard needs a JwtAuthGuard
    // request context this public webhook doesn't have.
    const subscription = await this.prisma.subscription.findUnique({ where: { storeId } });
    if (!subscription || !['ACTIVE', 'TRIAL'].includes(subscription.status)) {
      throw new ForbiddenException('Store subscription is not active');
    }
    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: subscription.plan },
    });
    if (!planConfig?.hasEcommerceIntegration) {
      throw new ForbiddenException('E-commerce integration is not available on the current plan');
    }
  }

  private async createOrder(storeId: string, dto: EcommerceWebhookDto) {
    const existing = await this.prisma.sale.findUnique({
      where: { storeId_externalOrderId: { storeId, externalOrderId: dto.externalOrderId } },
    });
    if (existing) return existing;

    const items = dto.items!;
    const mappings = await this.prisma.externalProductMapping.findMany({
      where: { storeId, externalProductId: { in: items.map((i) => i.externalProductId) } },
    });
    const mappingByExternalId = new Map(mappings.map((m) => [m.externalProductId, m]));

    const missing = items.find((i) => !mappingByExternalId.has(i.externalProductId));
    if (missing) {
      await this.notifications.sendToStoreUsers(
        storeId,
        'Заказ с сайта отклонён',
        `Товар "${missing.externalProductId}" не сопоставлен с товаром Dukon — заказ ${dto.externalOrderId} отклонён.`,
        'ECOMMERCE_ORDER_REJECTED',
      );
      throw new UnprocessableEntityException(
        `No product mapping for externalProductId "${missing.externalProductId}"`,
      );
    }

    const productIds = items.map((i) => mappingByExternalId.get(i.externalProductId)!.productId);
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds }, storeId },
    });
    const productById = new Map(products.map((p) => [p.id, p]));

    for (const item of items) {
      const productId = mappingByExternalId.get(item.externalProductId)!.productId;
      const product = productById.get(productId);
      if (!product || product.quantity < item.quantity) {
        await this.notifications.sendToStoreUsers(
          storeId,
          'Заказ с сайта отклонён',
          `Заказ ${dto.externalOrderId} отклонён — не хватает товара "${product?.name ?? item.externalProductId}".`,
          'ECOMMERCE_ORDER_REJECTED',
        );
        throw new UnprocessableEntityException(
          `Insufficient stock for product "${product?.name ?? productId}"`,
        );
      }
    }

    const subscription = await this.prisma.subscription.findUnique({ where: { storeId } });
    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: subscription!.plan },
    });

    const sale = await this.prisma.$transaction(async (tx) => {
      const customer = await tx.customer.upsert({
        where: { storeId_phone: { storeId, phone: dto.customer!.phone } },
        create: { storeId, name: dto.customer!.name, phone: dto.customer!.phone },
        update: { name: dto.customer!.name },
      });

      const saleItemsData = items.map((item) => {
        const productId = mappingByExternalId.get(item.externalProductId)!.productId;
        const product = productById.get(productId)!;
        const unitPrice = item.price ?? Number(product.sellPrice);
        return {
          productId,
          productName: product.name,
          quantity: item.quantity,
          unitPrice,
          costPrice: product.costPrice ?? undefined,
          total: unitPrice * item.quantity,
        };
      });

      const createdSale = await tx.sale.create({
        data: {
          storeId,
          customerId: customer.id,
          channel: 'ONLINE',
          // Deliberately not SalesService's generateReceiptNo() sequence
          // (that's for in-store cash-register receipts). externalOrderId
          // is already unique per store (Task 1's @@unique constraint),
          // so this derived value automatically satisfies Sale's own
          // @@unique([storeId, receiptNo]) with no extra query needed.
          receiptNo: `ONLINE-${dto.externalOrderId}`,
          subtotal: dto.totalAmount!,
          total: dto.totalAmount!,
          paymentType: 'CARD',
          paidAmount: dto.totalAmount!,
          status: 'COMPLETED',
          externalOrderId: dto.externalOrderId,
          items: { create: saleItemsData },
        },
        include: { items: true },
      });

      for (const item of items) {
        const productId = mappingByExternalId.get(item.externalProductId)!.productId;
        const result = await tx.product.updateMany({
          where: { id: productId, quantity: { gte: item.quantity } },
          data: { quantity: { decrement: item.quantity } },
        });
        if (result.count === 0) {
          // Stock changed between the pre-transaction check above and
          // this write (race with an in-store sale) — abort the whole
          // transaction; the site should retry the webhook per the
          // design spec's data-integrity contract.
          throw new UnprocessableEntityException(
            `Stock for product ${productId} changed concurrently — retry the webhook`,
          );
        }
      }

      await tx.stockMovement.createMany({
        data: items.map((item) => ({
          productId: mappingByExternalId.get(item.externalProductId)!.productId,
          type: 'SALE' as const,
          quantity: item.quantity,
          reference: dto.externalOrderId,
        })),
      });

      if (planConfig?.hasDelivery && dto.customer?.address) {
        await tx.delivery.create({
          data: {
            storeId,
            saleId: createdSale.id,
            address: dto.customer.address,
            status: 'NEW',
          },
        });
      }

      return createdSale;
    });

    for (const item of items) {
      const productId = mappingByExternalId.get(item.externalProductId)!.productId;
      void this.outbound.pushStockUpdate(productId, storeId);
    }

    return sale;
  }

  private async cancelOrder(storeId: string, externalOrderId: string) {
    const sale = await this.prisma.sale.findUnique({
      where: { storeId_externalOrderId: { storeId, externalOrderId } },
    });
    if (!sale) {
      // Idempotent per the design spec: the site may have retried a
      // cancel for an order Dukon never successfully recorded due to an
      // earlier failure — treat "not found" as "already cancelled or
      // never existed", not an error the site needs to handle specially.
      throw new NotFoundException('No matching order found for this store');
    }
    if (sale.status === 'CANCELLED') {
      return sale;
    }

    const affectedProductIds: string[] = [];

    const updated = await this.prisma.$transaction(async (tx) => {
      const items = await tx.saleItem.findMany({ where: { saleId: sale.id } });
      for (const item of items) {
        await tx.product.update({
          where: { id: item.productId },
          data: { quantity: { increment: item.quantity } },
        });
        affectedProductIds.push(item.productId);
      }
      if (items.length > 0) {
        await tx.stockMovement.createMany({
          data: items.map((item) => ({
            productId: item.productId,
            type: 'RETURN' as const,
            quantity: item.quantity,
            reference: externalOrderId,
          })),
        });
      }
      return tx.sale.update({ where: { id: sale.id }, data: { status: 'CANCELLED' } });
    });

    for (const productId of affectedProductIds) {
      void this.outbound.pushStockUpdate(productId, storeId);
    }

    return updated;
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: PASS (11 tests)

- [ ] **Step 6: Write the public webhook controller**

```typescript
// api/src/modules/ecommerce/ecommerce-orders.controller.ts
import { Body, Controller, Headers, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { EcommerceOrdersService } from './ecommerce-orders.service';
import { EcommerceWebhookDto } from './dto/ecommerce-webhook.dto';

@ApiTags('Ecommerce')
@Controller('stores/:storeId/ecommerce')
export class EcommerceOrdersController {
  constructor(private readonly ordersService: EcommerceOrdersService) {}

  // No JwtAuthGuard — the caller is the merchant's own website, which has
  // no Dukon user session. Authenticated via the per-store X-API-Key
  // header instead (checked inside EcommerceOrdersService), mirroring
  // TelegramController's shared-secret webhook pattern but with a
  // per-store DB-stored key rather than one global env var.
  @Post('orders')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @ApiOperation({ summary: 'Inbound order.created / order.cancelled webhook from the merchant site' })
  handleWebhook(
    @Param('storeId') storeId: string,
    @Headers('x-api-key') apiKey: string,
    @Body() dto: EcommerceWebhookDto,
  ) {
    return this.ordersService.handleWebhook(storeId, apiKey, dto);
  }
}
```

- [ ] **Step 7: Register in the module**

Update `api/src/modules/ecommerce/ecommerce.module.ts`:
```typescript
import { Module } from '@nestjs/common';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceIntegrationService } from './ecommerce-integration.service';
import { EcommerceIntegrationController } from './ecommerce-integration.controller';
import { EcommerceOrdersService } from './ecommerce-orders.service';
import { EcommerceOrdersController } from './ecommerce-orders.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [EcommerceIntegrationController, EcommerceOrdersController],
  providers: [EcommerceOutboundService, EcommerceIntegrationService, EcommerceOrdersService],
  exports: [EcommerceOutboundService],
})
export class EcommerceModule {}
```

- [ ] **Step 8: Write the end-to-end integration test the design spec explicitly asks for**

The design spec's Testing section calls for a scenario test spanning "входящий заказ → списание остатка → срабатывание исходящего push (мокнутый HTTP-клиент) → отмена → возврат остатка → повторный push" — i.e. multiple real units composed together (not each mocked out from the others), with only the outbound HTTP call itself mocked. Add this to `ecommerce-orders.service.spec.ts`, in a new `describe` block using the REAL `EcommerceOutboundService` instead of a fake:

```typescript
describe('EcommerceOrdersService — end-to-end scenario (real EcommerceOutboundService)', () => {
  let service: EcommerceOrdersService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    (prisma as any).ecommerceIntegration.findUnique = jest.fn(async () => ({
      storeId: 'store-1',
      apiKey: 'valid-key',
      enabled: true,
      outboundWebhookUrl: 'https://site.example/webhook',
    }));
    (prisma as any).externalProductMapping.findMany = jest.fn(async () => [
      { externalProductId: 'sku-1', productId: 'p1' },
    ]);
    (prisma as any).product = {
      ...prisma.product,
      findUnique: jest.fn(async () => ({ id: 'p1', quantity: 8 })),
    };

    fetchMock = jest.fn().mockResolvedValue({ ok: true, status: 200 });
    global.fetch = fetchMock as any;

    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceOrdersService,
        EcommerceOutboundService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendToStoreUsers: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(EcommerceOrdersService);
  });

  it('order.created decrements stock and pushes the new quantity; order.cancelled restores stock and pushes again', async () => {
    await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());
    expect(fetchMock).toHaveBeenCalledWith(
      'https://site.example/webhook',
      expect.objectContaining({
        body: JSON.stringify({ externalProductId: 'sku-1', quantity: 8 }),
      }),
    );

    fetchMock.mockClear();
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue({
      id: 'sale-1',
      status: 'COMPLETED',
      externalOrderId: 'site-order-1',
    });
    (prisma.__tx.saleItem.findMany as jest.Mock).mockResolvedValue([
      { productId: 'p1', quantity: 2 },
    ]);

    await service.handleWebhook('store-1', 'valid-key', {
      event: 'order.cancelled',
      externalOrderId: 'site-order-1',
    });

    expect(fetchMock).toHaveBeenCalledWith(
      'https://site.example/webhook',
      expect.objectContaining({
        body: JSON.stringify({ externalProductId: 'sku-1', quantity: 8 }),
      }),
    );
  });
});
```

(The outbound push in both branches uses `pushStockUpdate`'s own fresh `product.findUnique` read for "current quantity," so it reflects whatever the fake's `findUnique` mock returns at push time — not something the test needs to hand-compute from the decrement/increment amounts. Adjust the mock wiring above if your actual `makePrismaFake()` structures `product` differently than assumed here; the point of this test is realistic multi-unit composition, so get the fixture right rather than forcing this snippet to pass superficially.)

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: PASS (13 tests total in the file)

- [ ] **Step 9: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
cd api
git add src/modules/ecommerce/
git commit -m "feat(ecommerce): add inbound order.created/order.cancelled webhook with transactional stock handling"
```

---

## Task 6: Wire `EcommerceOutboundService` into every existing place that changes `Product.quantity`

**Context:** Task 5's webhook already pushes outbound updates for the orders it creates/cancels itself. This task covers the other direction the design spec requires: an in-store sale, a refund, a manual stock adjustment, or a purchase/inventory count in Dukon must also notify the merchant's website, since a physical sale can just as easily cause overselling online as the reverse. Grounded against the actual current code: `SalesService.create()` and `SalesService.refund()` both mutate `Product.quantity` inline inside their own transactions (not via `StockMovementsService` — confirmed no such delegation exists today); `StockMovementsService.create()` is the one other place, used for manual/purchase/adjustment/write-off movements via `ProductsController`.

**Files:**
- Modify: `api/src/modules/sales/sales.module.ts` (import `EcommerceModule`)
- Modify: `api/src/modules/sales/sales.service.ts` (`create()`, `refund()`)
- Modify: `api/src/modules/products/products.module.ts` (import `EcommerceModule`)
- Modify: `api/src/modules/products/stock-movements.service.ts` (`create()`)
- Modify (tests): `api/src/modules/sales/sales.service.spec.ts`, `api/src/modules/products/stock-movements.service.spec.ts`

- [ ] **Step 1: Export `EcommerceOutboundService` is already done (Task 5's module `exports: [EcommerceOutboundService]`) — import `EcommerceModule` into `SalesModule`**

In `api/src/modules/sales/sales.module.ts`, add `EcommerceModule` to the `imports: [...]` array and its corresponding top-of-file import.

- [ ] **Step 2: Inject `EcommerceOutboundService` into `SalesService` and add a failing test for `create()`**

In the existing `sales.service.spec.ts`, find the `Test.createTestingModule` provider list used for `SalesService` and add a fake for the new dependency:
```typescript
        { provide: EcommerceOutboundService, useValue: { pushStockUpdate: jest.fn() } },
```
(Import `EcommerceOutboundService` from `'../ecommerce/ecommerce-outbound.service'` at the top of the spec file.)

Then add this test near the other `create()` tests:
```typescript
  it('pushes an outbound stock update for every sold product after a successful sale', async () => {
    const outbound = moduleRef.get(EcommerceOutboundService) as any;
    await service.create(storeId, {
      items: [{ productId: 'p1', quantity: 1 }],
      paymentType: 'CASH',
      paidAmount: 100,
    } as any);
    expect(outbound.pushStockUpdate).toHaveBeenCalledWith('p1', storeId);
  });
```
(Adjust the exact fake-Prisma setup this test needs — e.g. a fake product `p1` with enough stock — to match whatever fixture pattern the rest of `sales.service.spec.ts` already uses for a minimal successful `create()` call; read the file first rather than guessing the fixture shape.)

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd api && npx jest sales.service.spec.ts -t "outbound stock update"`
Expected: FAIL — `EcommerceOutboundService` not provided / `pushStockUpdate` never called

- [ ] **Step 4: Wire it into `SalesService`**

In `api/src/modules/sales/sales.service.ts`:
1. Add the import: `import { EcommerceOutboundService } from '../ecommerce/ecommerce-outbound.service';`
2. Add `private ecommerceOutbound: EcommerceOutboundService,` to the constructor's dependency list.
3. In `create()`, after the `$transaction(...)` call resolves into `result` (the existing code already does something with `result` afterward for `maybeNotifyBigSale` — add alongside it, not inside the transaction):
```typescript
    for (const item of dto.items) {
      void this.ecommerceOutbound.pushStockUpdate(item.productId, storeId);
    }
```
4. In `refund()`, the method currently does `return this.prisma.$transaction(async (tx) => {...})` directly. Change the outer `return` to capture the result first:
```typescript
    const result = await this.prisma.$transaction(async (tx) => {
      // ...existing transaction body, unchanged...
    });
    for (const refundItem of dto.items) {
      const saleItem = sale.items.find((i) => i.id === refundItem.saleItemId)!;
      void this.ecommerceOutbound.pushStockUpdate(saleItem.productId, storeId);
    }
    return result;
```
(`sale` here is the pre-transaction snapshot already fetched at the top of `refund()` via `this.findOne(storeId, saleId)` — it already has `.items` with `.productId` per item, no new query needed.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd api && npx jest sales.service.spec.ts`
Expected: PASS, including the new test

- [ ] **Step 6: Repeat the same pattern for `StockMovementsService`**

Add `EcommerceModule` to `api/src/modules/products/products.module.ts`'s imports (same pattern as Step 1).

Add a test to `stock-movements.service.spec.ts`:
```typescript
  it('pushes an outbound stock update after successfully recording a movement', async () => {
    const outbound = moduleRef.get(EcommerceOutboundService) as any;
    await service.create(storeId, {
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 10,
    } as any);
    expect(outbound.pushStockUpdate).toHaveBeenCalledWith('p1', storeId);
  });
```
(Again, match the exact existing fixture conventions in that spec file — read it first.)

Run: `cd api && npx jest stock-movements.service.spec.ts -t "outbound stock update"` — confirm it fails first.

In `api/src/modules/products/stock-movements.service.ts`:
1. Add the import and constructor dependency, same as `SalesService`.
2. `create()` already wraps its work in `this.prisma.$transaction(async (tx) => {...})` (per Task 3 research, line 45) — apply the same "capture the result, push after" pattern:
```typescript
    const result = await this.prisma.$transaction(async (tx) => {
      // ...existing transaction body, unchanged...
    });
    void this.ecommerceOutbound.pushStockUpdate(dto.productId, storeId);
    return result;
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd api && npx jest stock-movements.service.spec.ts`
Expected: PASS

- [ ] **Step 8: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
cd api
git add src/modules/sales/ src/modules/products/
git commit -m "feat(ecommerce): push outbound stock updates from in-store sales, refunds, and manual stock movements"
```

---

## Task 7: Reports — `channel` filter and online/in-store breakdown

**Files:**
- Modify: `api/src/modules/reports/dto/report-query.dto.ts`
- Modify: `api/src/modules/reports/reports.service.ts` (`getSalesReport`)
- Test: `api/src/modules/reports/reports.service.spec.ts`
- Modify: `app/lib/presentation/pages/finance/reports_page.dart`

- [ ] **Step 1: Add `channel` to `ReportQueryDto`**

In `api/src/modules/reports/dto/report-query.dto.ts`, add:
```typescript
  @ApiPropertyOptional({ enum: ['IN_STORE', 'ONLINE'] })
  @IsOptional()
  @IsIn(['IN_STORE', 'ONLINE'])
  channel?: 'IN_STORE' | 'ONLINE';
```
(Add `IsIn` to the existing `class-validator` import line at the top of the file.)

- [ ] **Step 2: Write the failing test**

Find the existing `describe('getSalesReport'...)` block in `reports.service.spec.ts` (or wherever `ReportsService` is tested — read the file first for its exact fixture pattern) and add:
```typescript
  it('filters by channel when provided and always includes a channel breakdown', async () => {
    (prisma.sale.groupBy as jest.Mock).mockResolvedValue([
      { channel: 'IN_STORE', _sum: { total: 800 }, _count: 4 },
      { channel: 'ONLINE', _sum: { total: 200 }, _count: 1 },
    ]);

    const result = await service.getSalesReport(storeId, { channel: 'ONLINE' } as any);

    expect(prisma.sale.groupBy).toHaveBeenCalledWith(
      expect.objectContaining({ by: ['channel'] }),
    );
    expect(result.channelBreakdown).toEqual([
      { channel: 'IN_STORE', revenue: 800, count: 4 },
      { channel: 'ONLINE', revenue: 200, count: 1 },
    ]);
  });
```
(This test assumes `prisma.sale.groupBy` is mockable on whatever fake-Prisma fixture this spec file already uses for `ReportsService` — check whether the file mocks `$queryRaw`/`saleItem.groupBy`/`sale.aggregate` already, since `getSalesReport` uses all three, and add a `sale.groupBy` mock alongside them if it's missing.)

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd api && npx jest reports.service.spec.ts -t "channel breakdown"`
Expected: FAIL

- [ ] **Step 4: Implement the channel filter and breakdown**

In `api/src/modules/reports/reports.service.ts`, `getSalesReport()`:
1. Add a `channel` clause, applied to all three existing parallel queries when `query.channel` is set — for the raw SQL query, add ``AND channel = ${query.channel ?? Prisma.sql\`channel\`}`` is awkward for conditional raw SQL; instead build the WHERE clause conditionally. Replace the raw-SQL `salesByDate` query's fixed template with:
```typescript
      this.prisma.$queryRaw<
        { date: Date; count: bigint; revenue: number; avg_check: number }[]
      >`
        SELECT
          DATE("createdAt") as date,
          COUNT(*)::bigint as count,
          COALESCE(SUM(total), 0)::float as revenue,
          COALESCE(AVG(total), 0)::float as avg_check
        FROM sales
        WHERE "storeId" = ${storeId}
          AND status = 'COMPLETED'
          AND "createdAt" >= ${startDate}
          AND "createdAt" <= ${endDate}
          ${query.channel ? Prisma.sql`AND channel = ${query.channel}::"SalesChannel"` : Prisma.empty}
        GROUP BY DATE("createdAt")
        ORDER BY date ASC
      `,
```
(`Prisma.sql`/`Prisma.empty` need `import { Prisma } from '@prisma/client';` at the top of the file if not already imported — check first.)

2. Add `channel: query.channel` to the `where` clauses of the existing `topProducts` (`saleItem.groupBy`, inside its `where.sale`) and `totals` (`sale.aggregate`) queries, only when defined — e.g. `...(query.channel && { channel: query.channel })` spread into each `where` object.

3. Add a fourth parallel query (unconditional — always shows the full breakdown regardless of the `channel` filter, so the UI can render "В магазине / Онлайн" context even while filtered to one channel):
```typescript
      this.prisma.sale.groupBy({
        by: ['channel'],
        where: { storeId, status: 'COMPLETED', createdAt: { gte: startDate, lte: endDate } },
        _sum: { total: true },
        _count: true,
      }),
```
Add it to the `Promise.all([...])` array (rename the destructured result, e.g. `const [salesByDate, topProducts, totals, channelBreakdownRaw] = await Promise.all([...])`), then include in the return value:
```typescript
      channelBreakdown: channelBreakdownRaw.map((row) => ({
        channel: row.channel,
        revenue: Number(row._sum.total ?? 0),
        count: row._count,
      })),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd api && npx jest reports.service.spec.ts`
Expected: PASS

- [ ] **Step 6: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 7: Commit the backend change**

```bash
cd api
git add src/modules/reports/
git commit -m "feat(reports): add channel filter and online/in-store revenue breakdown to the sales report"
```

- [ ] **Step 8: Add the mobile filter chip**

In `app/lib/presentation/pages/finance/reports_page.dart`:

1. Add a field to `_ReportsPageState` (near the existing `_from`/`_to` fields): `String? _selectedChannel;`
2. In `_loadSales()`, add the channel to the query params only when set:
```dart
      final resp = await _dio.get<Map<String, dynamic>>(
        '/stores/$id/reports/sales',
        queryParameters: {
          'from': _fmt(_from),
          'to': _fmt(_to),
          if (_selectedChannel != null) 'channel': _selectedChannel,
        },
      );
```
3. Add a small chip row directly below `_buildPeriodBar()`'s closing `Container`, visible only on the Sales tab (index 0). In the `build()` method where `_buildPeriodBar()` is called (around line 858), add conditionally right after it:
```dart
          _buildPeriodBar(),
          if (_tabController.index == 0) _buildChannelFilterBar(),
```
4. Add the new method, right after `_buildPeriodBar()`:
```dart
  Widget _buildChannelFilterBar() {
    return Container(
      color: context.surfaceMuted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Все каналы'),
            selected: _selectedChannel == null,
            onSelected: (_) {
              setState(() => _selectedChannel = null);
              _loadSales();
            },
          ),
          ChoiceChip(
            label: const Text('В магазине'),
            selected: _selectedChannel == 'IN_STORE',
            onSelected: (_) {
              setState(() => _selectedChannel = 'IN_STORE');
              _loadSales();
            },
          ),
          ChoiceChip(
            label: const Text('Онлайн'),
            selected: _selectedChannel == 'ONLINE',
            onSelected: (_) {
              setState(() => _selectedChannel = 'ONLINE');
              _loadSales();
            },
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 9: Run `flutter analyze` on the touched file**

Run: `cd app && flutter analyze lib/presentation/pages/finance/reports_page.dart`
Expected: No new issues.

- [ ] **Step 10: Manual verification**

Run the mobile app against a store with at least one `ONLINE`-channel sale (created via Task 5's webhook, or directly via a test script hitting `POST /stores/:storeId/ecommerce/orders`) and one ordinary in-store sale. Open Отчёты → Продажи, confirm all three chips filter the list and totals correctly.

- [ ] **Step 11: Commit the mobile change**

```bash
git add app/lib/presentation/pages/finance/reports_page.dart
git commit -m "feat(mobile): add channel filter to the sales report"
```

---

## Task 8: Mobile — «Интернет-магазин» settings screen + product mapping screen

**Files:**
- Create: `app/lib/presentation/pages/settings/ecommerce_settings_page.dart`
- Create: `app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart`
- Modify: `app/lib/core/router/route_names.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: Add route names**

In `app/lib/core/router/route_names.dart`, add near `telegramBot`:
```dart
  static const String ecommerceSettings = '/settings/ecommerce';
  static const String ecommerceProductMapping = '/settings/ecommerce/mappings';
```

- [ ] **Step 2: Write the integration settings screen**

Modeled directly on `TelegramBotSettingsPage` (`app/lib/presentation/pages/settings/telegram_bot_settings_page.dart`) — same `storeId`-scoped `StatefulWidget` + `DioClient` + `AppSnackbar` conventions, plus a copy-to-clipboard affordance (modeled on the one existing use of `Clipboard.setData` in `zakat_calculator_page.dart:294`).

```dart
// app/lib/presentation/pages/settings/ecommerce_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/router/route_names.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:go_router/go_router.dart';

class EcommerceSettingsPage extends StatefulWidget {
  final String storeId;
  const EcommerceSettingsPage({super.key, required this.storeId});

  @override
  State<EcommerceSettingsPage> createState() => _EcommerceSettingsPageState();
}

class _EcommerceSettingsPageState extends State<EcommerceSettingsPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  bool _configured = false;
  String? _apiKey;
  bool _enabled = true;
  final _webhookUrlController = TextEditingController();

  String get _inboundWebhookUrl =>
      '${_dioClient.baseUrl}/stores/${widget.storeId}/ecommerce/orders';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dioClient.get('/stores/${widget.storeId}/ecommerce/integration');
      final data = res.data as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _configured = true;
          _apiKey = data['apiKey'] as String?;
          _enabled = data['enabled'] as bool? ?? true;
          _webhookUrlController.text = data['outboundWebhookUrl'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      final res = await _dioClient.put(
        '/stores/${widget.storeId}/ecommerce/integration',
        data: {
          'outboundWebhookUrl': _webhookUrlController.text.trim().isEmpty
              ? null
              : _webhookUrlController.text.trim(),
          'enabled': _enabled,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _configured = true;
          _apiKey = data?['apiKey'] as String? ?? _apiKey;
        });
        AppSnackbar.success(context, 'Настройки сохранены');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  Future<void> _regenerateKey() async {
    try {
      final res = await _dioClient.post(
        '/stores/${widget.storeId}/ecommerce/integration/regenerate-key',
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted) {
        setState(() => _apiKey = data?['apiKey'] as String?);
        AppSnackbar.success(context, 'Ключ перегенерирован');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.info(context, '$label скопирован(о)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Интернет-магазин'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('URL для входящих заказов',
                    style: TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 6),
                _CopyableField(
                  value: _inboundWebhookUrl,
                  onCopy: () => _copy(_inboundWebhookUrl, 'URL'),
                ),
                const SizedBox(height: 16),
                Text('API-ключ', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 6),
                _CopyableField(
                  value: _configured ? (_apiKey ?? '—') : 'Сохраните настройки, чтобы создать ключ',
                  onCopy: _apiKey == null ? null : () => _copy(_apiKey!, 'Ключ'),
                ),
                if (_configured) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _regenerateKey,
                    child: const Text('Перегенерировать ключ'),
                  ),
                ],
                const SizedBox(height: 16),
                Text('URL вебхука вашего сайта',
                    style: TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _webhookUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://your-shop.example.com/dukon-webhook',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Интеграция активна'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeThumbColor: AppColors.primary,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                    ),
                    onPressed: _save,
                    child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push(
                    RouteNames.ecommerceProductMapping,
                    extra: widget.storeId,
                  ),
                  child: const Text('Сопоставление товаров'),
                ),
              ],
            ),
    );
  }
}

class _CopyableField extends StatelessWidget {
  final String value;
  final VoidCallback? onCopy;
  const _CopyableField({required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
```

**Before wiring the router:** confirm `DioClient` actually exposes a `baseUrl` getter (used above for `_inboundWebhookUrl`) via `grep -n "baseUrl" app/lib/core/network/dio_client.dart` — if it doesn't, use whatever the real base-URL constant/config this codebase already exposes (check `app/lib/core/constants/app_constants.dart` for something like `apiBaseUrl`) and adjust the getter accordingly rather than assuming.

- [ ] **Step 3: Write the product mapping screen**

```dart
// app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';

class EcommerceProductMappingPage extends StatefulWidget {
  final String storeId;
  const EcommerceProductMappingPage({super.key, required this.storeId});

  @override
  State<EcommerceProductMappingPage> createState() => _EcommerceProductMappingPageState();
}

class _EcommerceProductMappingPageState extends State<EcommerceProductMappingPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final productsRes = await _dioClient.get('/stores/${widget.storeId}/products');
      final mappingsRes = await _dioClient.get('/stores/${widget.storeId}/ecommerce/mappings');

      final productsJson = (productsRes.data is List)
          ? productsRes.data as List
          : (productsRes.data as Map)['data'] as List? ?? [];
      final mappingsJson = (mappingsRes.data as List?) ?? [];

      final mappingByProductId = {
        for (final m in mappingsJson.cast<Map<String, dynamic>>())
          m['productId'] as String: m['externalProductId'] as String,
      };

      for (final p in productsJson.cast<Map<String, dynamic>>()) {
        final id = p['id'] as String;
        _controllers[id] = TextEditingController(text: mappingByProductId[id] ?? '');
      }

      setState(() {
        _products = productsJson.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveMapping(String productId) async {
    final value = _controllers[productId]?.text.trim() ?? '';
    try {
      await _dioClient.put(
        '/stores/${widget.storeId}/ecommerce/mappings/$productId',
        data: {'externalProductId': value.isEmpty ? null : value},
      );
      if (mounted) AppSnackbar.success(context, 'Сохранено');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Сопоставление товаров'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = _products[index];
                final id = product['id'] as String;
                final name = product['name'] as String? ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(name, style: const TextStyle(fontSize: 14)),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _controllers[id],
                          decoration: const InputDecoration(
                            hintText: 'Внешний ID',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _saveMapping(id),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        onPressed: () => _saveMapping(id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
```

**Before finalizing:** verify the real `GET /stores/:storeId/products` response shape (list vs. `{data: [...]}`) via `grep -n "async findAll\|@Get()" api/src/modules/products/products.controller.ts api/src/modules/products/products.service.ts` — the code above defensively handles both shapes, but confirm which one is actually correct so the defensive branch isn't silently masking a wrong assumption.

- [ ] **Step 4: Wire the routes**

In `app/lib/core/router/app_router.dart`, add two `GoRoute`s near the existing `telegramBot` one:
```dart
    GoRoute(
      path: RouteNames.ecommerceSettings,
      builder: (context, state) {
        final storeId = state.extra as String? ?? '';
        return EcommerceSettingsPage(storeId: storeId);
      },
    ),
    GoRoute(
      path: RouteNames.ecommerceProductMapping,
      builder: (context, state) {
        final storeId = state.extra as String? ?? '';
        return EcommerceProductMappingPage(storeId: storeId);
      },
    ),
```
Add the corresponding imports at the top of the file.

- [ ] **Step 5: Add the Settings tile**

In `app/lib/presentation/pages/settings/settings_page.dart`, inside the "Интеграции" `_buildSectionCard([...])` (around line 172), add a new tile + divider before the closing `]`:
```dart
    _buildDivider(),
    _buildTile(Icons.storefront_outlined, 'Интернет-магазин',
      onTap: () => context.push(RouteNames.ecommerceSettings, extra: _getStoreId())),
```
(Match whatever conditional-visibility pattern the file already uses, if any, to only show PREMIUM-gated tiles for stores that actually have the feature — check how `hasDelivery`-gated tiles, if any exist in this file, decide visibility, and mirror that convention for `hasEcommerceIntegration` rather than always showing the tile regardless of plan.)

- [ ] **Step 6: Run `flutter analyze` on the touched files**

Run: `cd app && flutter analyze lib/presentation/pages/settings/ecommerce_settings_page.dart lib/presentation/pages/settings/ecommerce_product_mapping_page.dart lib/presentation/pages/settings/settings_page.dart lib/core/router/app_router.dart lib/core/router/route_names.dart`
Expected: No issues found.

- [ ] **Step 7: Manual verification**

Run the mobile app on a PREMIUM test account: open Настройки → Интернет-магазин, confirm the inbound webhook URL and (after first save) API key display correctly and are copyable, save a test outbound webhook URL, toggle "Интеграция активна", open "Сопоставление товаров", set an external ID on one product, save, reload the screen, confirm it persisted.

- [ ] **Step 8: Commit**

```bash
git add app/lib/presentation/pages/settings/ app/lib/core/router/
git commit -m "feat(mobile): add e-commerce integration and product-mapping settings screens"
```

---

## Final check

- [ ] Run `cd api && npx jest` — full backend suite green.
- [ ] Run `cd api && npx tsc --noEmit` — clean.
- [ ] Run `cd admin && npx tsc --noEmit` — clean.
- [ ] Run `cd app && flutter analyze` — no new issues introduced by this plan's mobile changes.
- [ ] Confirm all 8 task commits are present via `git log --oneline` since this plan's first commit.
