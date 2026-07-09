# Spec K — Feature Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver three features that close open stubs: (1) backend Excel export wired to the Flutter UI, (2) Telegram push notifications when loyalty points are earned, (3) a loyalty analytics dashboard.

**Architecture:** All three features extend existing modules — `ReportsModule`, `LoyaltyModule`, `CustomersModule` on the backend; `ReportsPage`, `CustomerFormPage`, `CustomerDetailPage`, `LoyaltySettingsPage` on Flutter. No new top-level modules.

**Tech Stack:** NestJS 10, Prisma 5, Flutter 3.22, BLoC 8, ExcelJS, node-telegram-bot-api, Dio

---

## Pre-flight: what is already done

Before starting any task, verify this against the live files:

| File | Status |
|---|---|
| `api/src/modules/reports/export.service.ts` | ✅ DONE — `exportSales`, `exportProducts`, `exportCustomers` all implemented |
| `api/src/modules/reports/reports.controller.ts` | ✅ DONE — `GET /reports/export?type=...` endpoint exists |
| `api/prisma/schema.prisma` Customer model | ✅ `telegramChatId String?` already exists |
| `app/lib/presentation/pages/finance/reports_page.dart` | Partial — has local Excel export but NOT server-side; no `hasExport` gating |

---

## File Map

**Backend — New:**
- `api/src/modules/reports/export.service.spec.ts`
- `api/src/modules/customers/dto/link-telegram.dto.ts`
- `api/prisma/migrations/20260709_add_user_telegram_chat_id/migration.sql`
- `api/src/modules/loyalty/dto/loyalty-analytics-query.dto.ts`

**Backend — Modified:**
- `api/prisma/schema.prisma` — add `User.telegramChatId String?`
- `api/src/modules/telegram/telegram.service.ts` — add `sendMessage()`, `resolveUsername()`, `getStoreChatId()`
- `api/src/modules/customers/customers.service.ts` — add `linkTelegram()`
- `api/src/modules/customers/customers.controller.ts` — add `PUT :id/telegram`
- `api/src/modules/customers/customers.service.spec.ts` — 2 new tests
- `api/src/modules/loyalty/loyalty.module.ts` — import TelegramModule
- `api/src/modules/loyalty/loyalty.service.ts` — inject TelegramService, push in `earnPoints`, add `getAnalytics()`
- `api/src/modules/loyalty/loyalty.controller.ts` — add GET analytics endpoint
- `api/src/modules/loyalty/loyalty.service.spec.ts` — 4 new tests

**Flutter — New:**
- `app/lib/domain/entities/loyalty_analytics.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_analytics_event.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_analytics_state.dart`
- `app/lib/presentation/blocs/loyalty/loyalty_analytics_bloc.dart`
- `app/lib/presentation/pages/settings/loyalty_analytics_page.dart`
- `app/test/presentation/blocs/loyalty/loyalty_analytics_bloc_test.dart`

**Flutter — Modified:**
- `app/lib/domain/entities/customer.dart` — add `telegramChatId String?`
- `app/lib/data/datasources/remote/customer_remote_datasource.dart` — map `telegramChatId`
- `app/lib/core/constants/api_endpoints.dart` — add `customerTelegram()`, `loyaltyAnalytics()`
- `app/lib/domain/repositories/loyalty_repository.dart` — add `getAnalytics()`
- `app/lib/data/repositories/loyalty_repository_impl.dart` — implement `getAnalytics()`
- `app/lib/data/datasources/remote/loyalty_remote_datasource.dart` — add `getAnalytics()`
- `app/lib/presentation/pages/customer/customer_form_page.dart` — Telegram username field
- `app/lib/presentation/pages/customer/customer_detail_page.dart` — Telegram badge
- `app/lib/presentation/pages/finance/reports_page.dart` — server-side export + `hasExport` gating
- `app/lib/presentation/pages/settings/loyalty_settings_page.dart` — "Аналитика →" button
- `app/lib/core/router/route_names.dart` — add `loyaltyAnalytics`
- `app/lib/core/router/app_router.dart` — register `LoyaltyAnalyticsPage` route
- `app/lib/injection.dart` — register `LoyaltyAnalyticsBloc`
- `app/lib/app.dart` — add `LoyaltyAnalyticsBloc` to `MultiBlocProvider`

---

## Task 1: ExportService tests

**Files:**
- Create: `api/src/modules/reports/export.service.spec.ts`

The `ExportService` is already fully implemented. This task writes the three unit tests.

- [ ] **Step 1: Write the test file**

```typescript
// api/src/modules/reports/export.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import * as ExcelJS from 'exceljs';
import { ExportService } from './export.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrisma() {
  return {
    sale: { findMany: jest.fn() },
    product: { findMany: jest.fn() },
    customer: { findMany: jest.fn() },
  };
}

describe('ExportService', () => {
  let service: ExportService;
  let prisma: ReturnType<typeof makePrisma>;

  beforeEach(async () => {
    prisma = makePrisma();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExportService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = module.get(ExportService);
  });

  describe('exportSales', () => {
    it('should return a buffer whose worksheet has the correct column headers', async () => {
      prisma.sale.findMany.mockResolvedValue([
        {
          receiptNo: 'R001',
          createdAt: new Date('2026-07-01T10:00:00Z'),
          customer: { name: 'Алишер', phone: '+992123456789' },
          total: 500,
          paidAmount: 500,
          debtAmount: 0,
          paymentType: 'CASH',
          status: 'COMPLETED',
        },
      ]);

      const buf = await service.exportSales('store-1');

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(buf);
      const ws = wb.getWorksheet('Sales')!;

      expect(ws.getRow(1).getCell(1).value).toBe('Receipt');
      expect(ws.getRow(1).getCell(2).value).toBe('Date');
      expect(ws.getRow(2).getCell(1).value).toBe('R001');
      expect(ws.getRow(2).getCell(4).value).toBe(500);
    });
  });

  describe('exportProducts', () => {
    it('should produce one data row per product and include all 8 columns', async () => {
      prisma.product.findMany.mockResolvedValue([
        {
          name: 'Арбуз',
          sku: 'ARB001',
          barcode: '4600001',
          category: { name: 'Фрукты' },
          sellPrice: 15,
          costPrice: 8,
          quantity: 100,
          unit: 'KG',
        },
        {
          name: 'Дыня',
          sku: null,
          barcode: null,
          category: null,
          sellPrice: 12,
          costPrice: 6,
          quantity: 50,
          unit: 'KG',
        },
      ]);

      const buf = await service.exportProducts('store-1');

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(buf);
      const ws = wb.getWorksheet('Products')!;

      expect(ws.columnCount).toBe(8);
      expect(ws.rowCount).toBe(3); // 1 header + 2 data rows
    });
  });

  describe('exportCustomers', () => {
    it('should produce one data row per customer with correct row count', async () => {
      const customers = Array.from({ length: 5 }, (_, i) => ({
        name: `Клиент ${i}`,
        phone: `+99290000000${i}`,
        totalSpent: i * 100,
        debt: 0,
        createdAt: new Date(),
      }));
      prisma.customer.findMany.mockResolvedValue(customers);

      const buf = await service.exportCustomers('store-1');

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(buf);
      const ws = wb.getWorksheet('Customers')!;

      expect(ws.rowCount).toBe(6); // 1 header + 5 data
    });
  });
});
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd api && npx jest src/modules/reports/export.service.spec.ts --no-coverage
```

Expected: 3 passing.

- [ ] **Step 3: Run full suite to confirm no regressions**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add api/src/modules/reports/export.service.spec.ts
git commit -m "test(reports): ExportService unit tests — 3 passing (Spec K T1)"
```

---

## Task 2: User.telegramChatId + TelegramService helpers

**Files:**
- Modify: `api/prisma/schema.prisma`
- Create: `api/prisma/migrations/20260709_add_user_telegram_chat_id/migration.sql`
- Modify: `api/src/modules/telegram/telegram.service.ts`

Adds the `telegramChatId` field to the `User` model for store owner notifications, extends `TelegramService` with three new methods, and updates `handleWebhook` to also link store owners who share their phone number.

- [ ] **Step 1: Add `telegramChatId` to schema.prisma**

In `api/prisma/schema.prisma`, in the `model User` block, after `tokensRevokedAt DateTime?`, add:

```prisma
  telegramChatId  String?
```

- [ ] **Step 2: Create the migration file**

```bash
mkdir -p api/prisma/migrations/20260709_add_user_telegram_chat_id
cat > api/prisma/migrations/20260709_add_user_telegram_chat_id/migration.sql << 'EOF'
-- Migration: add telegramChatId to User for store owner Telegram notifications
ALTER TABLE "User" ADD COLUMN "telegramChatId" TEXT;
EOF
```

- [ ] **Step 3: Apply migration and regenerate client**

```bash
cd api && npx prisma migrate dev --name add_user_telegram_chat_id
```

Expected: migration applied, Prisma client regenerated with `User.telegramChatId`.

- [ ] **Step 4: Add three methods to TelegramService**

In `api/src/modules/telegram/telegram.service.ts`, add after the constructor:

```typescript
/** Generic fire-and-forget message. No-op if bot is not configured. */
async sendMessage(chatId: string, text: string): Promise<void> {
  if (!this.bot) return;
  await this.bot.sendMessage(chatId, text);
}

/**
 * Resolve a Telegram @username to a numeric chatId string.
 * Returns null if the bot is not configured or username is not found.
 */
async resolveUsername(username: string): Promise<string | null> {
  if (!this.bot) return null;
  try {
    const handle = username.startsWith('@') ? username : `@${username}`;
    const chat = await this.bot.getChat(handle);
    return String(chat.id);
  } catch {
    return null;
  }
}

/** Return the store owner's Telegram chatId, or null if not linked. */
async getStoreChatId(storeId: string): Promise<string | null> {
  const store = await this.prisma.store.findUnique({
    where: { id: storeId },
    include: { owner: { select: { telegramChatId: true } } },
  });
  return store?.owner?.telegramChatId ?? null;
}
```

- [ ] **Step 5: Update handleWebhook to link store owners**

In the `if (message.contact?.phone_number)` branch of `handleWebhook`, after the existing customer update block, add:

```typescript
// Also link store owner (User) if same phone belongs to a User
const user = await this.prisma.user.findUnique({ where: { phone } });
if (user) {
  await this.prisma.user.update({
    where: { id: user.id },
    data: { telegramChatId: String(chatId) },
  });
  await this.bot!.sendMessage(
    chatId,
    `✅ Telegram привязан к вашему аккаунту владельца магазина.`,
  );
}
```

- [ ] **Step 6: Run full test suite**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -5
```

Expected: all tests pass (no existing tests break — handleWebhook has no spec, and the new methods are additive).

- [ ] **Step 7: Commit**

```bash
git add api/prisma/schema.prisma \
        api/prisma/migrations/20260709_add_user_telegram_chat_id/migration.sql \
        api/src/modules/telegram/telegram.service.ts \
        api/prisma/migrations/migration_lock.toml
git commit -m "feat(telegram): User.telegramChatId + sendMessage/resolveUsername/getStoreChatId (Spec K T2)"
```

---

## Task 3: linkTelegram endpoint in CustomersService + Controller

**Files:**
- Create: `api/src/modules/customers/dto/link-telegram.dto.ts`
- Modify: `api/src/modules/customers/customers.service.ts`
- Modify: `api/src/modules/customers/customers.controller.ts`
- Modify: `api/src/modules/customers/customers.module.ts`
- Modify: `api/src/modules/customers/customers.service.spec.ts`

- [ ] **Step 1: Write the two failing tests in customers.service.spec.ts**

Open `api/src/modules/customers/customers.service.spec.ts`. In the existing `describe('CustomersService', ...)` block, add a new `describe('linkTelegram', ...)` block **before** the closing `});`:

```typescript
describe('linkTelegram', () => {
  it('should save chatId on customer when Telegram resolves the username', async () => {
    const fakeTelegram = {
      resolveUsername: jest.fn().mockResolvedValue('123456789'),
    };
    // Re-create service with TelegramService injected
    const mod = await Test.createTestingModule({
      providers: [
        CustomersService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: { log: jest.fn() } },
        { provide: TelegramService, useValue: fakeTelegram },
      ],
    }).compile();
    const svc = mod.get(CustomersService);

    prisma.customer.findFirst.mockResolvedValue({ id: 'cust-1', storeId: 'store-1' });
    prisma.customer.update.mockResolvedValue({});

    await svc.linkTelegram('store-1', 'cust-1', '@alisher');

    expect(prisma.customer.update).toHaveBeenCalledWith({
      where: { id: 'cust-1' },
      data: { telegramChatId: '123456789' },
    });
  });

  it('should throw NotFoundException when resolveUsername returns null', async () => {
    const fakeTelegram = {
      resolveUsername: jest.fn().mockResolvedValue(null),
    };
    const mod = await Test.createTestingModule({
      providers: [
        CustomersService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: { log: jest.fn() } },
        { provide: TelegramService, useValue: fakeTelegram },
      ],
    }).compile();
    const svc = mod.get(CustomersService);

    prisma.customer.findFirst.mockResolvedValue({ id: 'cust-1', storeId: 'store-1' });

    await expect(svc.linkTelegram('store-1', 'cust-1', '@nobody')).rejects.toThrow(
      NotFoundException,
    );
  });
});
```

Also add these imports at the top of the spec file if not already present:
```typescript
import { TelegramService } from '../telegram/telegram.service';
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd api && npx jest src/modules/customers/customers.service.spec.ts --no-coverage 2>&1 | tail -10
```

Expected: 2 failures — `linkTelegram is not a function`.

- [ ] **Step 3: Create the DTO**

```typescript
// api/src/modules/customers/dto/link-telegram.dto.ts
import { IsString } from 'class-validator';

export class LinkTelegramDto {
  @IsString()
  username: string; // e.g. "@alisher" or "alisher"
}
```

- [ ] **Step 4: Add linkTelegram to CustomersService**

In `api/src/modules/customers/customers.service.ts`:

Add import:
```typescript
import { TelegramService } from '../telegram/telegram.service';
```

Update constructor to inject TelegramService:
```typescript
constructor(
  private prisma: PrismaService,
  private audit: AuditLogService,
  private telegram: TelegramService,
) {}
```

Add the method (after `getDebts` or before the closing `}`):
```typescript
async linkTelegram(storeId: string, customerId: string, username: string): Promise<void> {
  const customer = await this.prisma.customer.findFirst({
    where: { id: customerId, storeId, isActive: true },
  });
  if (!customer) throw new NotFoundException('Customer not found');

  const chatId = await this.telegram.resolveUsername(username);
  if (!chatId) throw new NotFoundException('Telegram user not found or account is private');

  await this.prisma.customer.update({
    where: { id: customerId },
    data: { telegramChatId: chatId },
  });
}
```

- [ ] **Step 5: Add the PUT endpoint to CustomersController**

In `api/src/modules/customers/customers.controller.ts`, add import:
```typescript
import { Put, Body } from '@nestjs/common';
import { LinkTelegramDto } from './dto/link-telegram.dto';
```

(These may already be partially imported — merge with existing imports.)

Add route after the `getDebts` handler:
```typescript
@Put(':id/telegram')
@ApiOperation({ summary: 'Link customer Telegram account by @username' })
linkTelegram(
  @Param('storeId') storeId: string,
  @Param('id') id: string,
  @Body() dto: LinkTelegramDto,
) {
  return this.customersService.linkTelegram(storeId, id, dto.username);
}
```

- [ ] **Step 6: Update CustomersModule to import TelegramModule**

In `api/src/modules/customers/customers.module.ts`:
```typescript
import { Module } from '@nestjs/common';
import { TelegramModule } from '../telegram/telegram.module';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';

@Module({
  imports: [TelegramModule],
  controllers: [CustomersController],
  providers: [CustomersService],
  exports: [CustomersService],
})
export class CustomersModule {}
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
cd api && npx jest src/modules/customers/customers.service.spec.ts --no-coverage 2>&1 | tail -10
```

Expected: all tests pass (the two new + existing 6).

- [ ] **Step 8: Run full suite**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -5
```

- [ ] **Step 9: Commit**

```bash
git add api/src/modules/customers/dto/link-telegram.dto.ts \
        api/src/modules/customers/customers.service.ts \
        api/src/modules/customers/customers.controller.ts \
        api/src/modules/customers/customers.module.ts \
        api/src/modules/customers/customers.service.spec.ts
git commit -m "feat(customers): linkTelegram endpoint + 2 tests (Spec K T3)"
```

---

## Task 4: LoyaltyService — Telegram push in earnPoints

**Files:**
- Modify: `api/src/modules/loyalty/loyalty.module.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.spec.ts`

- [ ] **Step 1: Write the two failing tests in loyalty.service.spec.ts**

Open `api/src/modules/loyalty/loyalty.service.spec.ts`. Locate the `describe('earnPoints', ...)` block and add two tests **inside** it:

```typescript
it('should fire Telegram push to customer when telegramChatId is set', async () => {
  const fakeTelegram = {
    sendMessage: jest.fn().mockResolvedValue(undefined),
    getStoreChatId: jest.fn().mockResolvedValue(null),
  };
  // rebuild service with TelegramService
  const mod = await Test.createTestingModule({
    providers: [
      LoyaltyService,
      { provide: PrismaService, useValue: prisma },
      { provide: TelegramService, useValue: fakeTelegram },
    ],
  }).compile();
  const svc = mod.get(LoyaltyService);

  const mockTx = buildMockTx(); // reuse the helper from the top of the spec
  await svc.earnPoints(mockTx, {
    customerId: 'cust-1',
    storeId: 'store-1',
    saleId: 'sale-1',
    points: 50,
    expiresAt: null,
  });

  // earnPoints retrieves the customer balance after update — mock needed
  prisma._customers.get('cust-1').loyaltyPoints = 150; // balance after earn

  // Verify sendMessage was called with customer's chatId
  // Note: the chatId comes from the customer row fetched inside earnPoints
  expect(fakeTelegram.sendMessage).toHaveBeenCalled();
});

it('should not throw when Telegram sendMessage rejects', async () => {
  const fakeTelegram = {
    sendMessage: jest.fn().mockRejectedValue(new Error('Network error')),
    getStoreChatId: jest.fn().mockResolvedValue(null),
  };
  const mod = await Test.createTestingModule({
    providers: [
      LoyaltyService,
      { provide: PrismaService, useValue: prisma },
      { provide: TelegramService, useValue: fakeTelegram },
    ],
  }).compile();
  const svc = mod.get(LoyaltyService);

  const mockTx = buildMockTx();
  await expect(
    svc.earnPoints(mockTx, {
      customerId: 'cust-1',
      storeId: 'store-1',
      saleId: 'sale-1',
      points: 50,
      expiresAt: null,
    }),
  ).resolves.not.toThrow();
});
```

Add `TelegramService` import at the top of the spec:
```typescript
import { TelegramService } from '../telegram/telegram.service';
```

Also add a `buildMockTx()` helper near the top of the spec file if it doesn't exist:
```typescript
function buildMockTx() {
  return {
    loyaltyTransaction: {
      create: jest.fn().mockResolvedValue({}),
    },
    customer: {
      update: jest.fn().mockImplementation(({ data }) => {
        // simulate increment
        return Promise.resolve({});
      }),
      findUnique: jest.fn().mockResolvedValue({ telegramChatId: 'tg-123', loyaltyPoints: 100 }),
    },
  };
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd api && npx jest src/modules/loyalty/loyalty.service.spec.ts --no-coverage 2>&1 | tail -10
```

Expected: 2 new tests fail.

- [ ] **Step 3: Update LoyaltyModule to import TelegramModule**

```typescript
// api/src/modules/loyalty/loyalty.module.ts
import { Module } from '@nestjs/common';
import { TelegramModule } from '../telegram/telegram.module';
import { LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';

@Module({
  imports: [TelegramModule],
  controllers: [LoyaltyController],
  providers: [LoyaltyService],
  exports: [LoyaltyService],
})
export class LoyaltyModule {}
```

- [ ] **Step 4: Inject TelegramService into LoyaltyService and add push**

In `api/src/modules/loyalty/loyalty.service.ts`:

Add import:
```typescript
import { TelegramService } from '../telegram/telegram.service';
```

Update constructor:
```typescript
constructor(
  private prisma: PrismaService,
  private telegram: TelegramService,
) {}
```

Update `earnPoints` — after the two `await tx.xxx` calls, add the fire-and-forget push block:

```typescript
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

  // Fire-and-forget Telegram notifications — never throw
  const customer = await this.prisma.customer.findUnique({
    where: { id: opts.customerId },
    select: { telegramChatId: true, name: true, loyaltyPoints: true },
  });
  if (customer?.telegramChatId) {
    this.telegram
      .sendMessage(
        customer.telegramChatId,
        `+${opts.points} баллов начислено за покупку. Баланс: ${customer.loyaltyPoints} баллов 🎉`,
      )
      .catch(() => {});
  }
  this.telegram
    .getStoreChatId(opts.storeId)
    .then((storeChatId) => {
      if (storeChatId && customer) {
        this.telegram
          .sendMessage(
            storeChatId,
            `Клиент ${customer.name} получил +${opts.points} баллов`,
          )
          .catch(() => {});
      }
    })
    .catch(() => {});
}
```

- [ ] **Step 5: Run tests**

```bash
cd api && npx jest src/modules/loyalty/loyalty.service.spec.ts --no-coverage 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 6: Run full suite**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add api/src/modules/loyalty/loyalty.module.ts \
        api/src/modules/loyalty/loyalty.service.ts \
        api/src/modules/loyalty/loyalty.service.spec.ts
git commit -m "feat(loyalty): Telegram push on earnPoints + 2 tests (Spec K T4)"
```

---

## Task 5: LoyaltyService.getAnalytics() + Controller endpoint + tests

**Files:**
- Create: `api/src/modules/loyalty/dto/loyalty-analytics-query.dto.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.ts`
- Modify: `api/src/modules/loyalty/loyalty.controller.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.spec.ts`

- [ ] **Step 1: Write failing tests**

In `api/src/modules/loyalty/loyalty.service.spec.ts`, add `describe('getAnalytics', ...)` block:

```typescript
describe('getAnalytics', () => {
  it('should return correct aggregates for a period with mixed transaction types', async () => {
    const from = new Date('2026-07-01');
    const to = new Date('2026-07-31');

    // Mock aggregate calls (3 calls: EARN, REDEEM, EXPIRE)
    prisma.loyaltyTransaction.aggregate
      .mockResolvedValueOnce({ _sum: { points: 500 } })  // EARN
      .mockResolvedValueOnce({ _sum: { points: -200 } }) // REDEEM
      .mockResolvedValueOnce({ _sum: { points: -50 } }); // EXPIRE

    prisma.customer.count.mockResolvedValue(12);
    prisma.customer.findMany.mockResolvedValue([
      { id: 'cust-1', name: 'Алишер', loyaltyPoints: 300 },
      { id: 'cust-2', name: 'Бобур', loyaltyPoints: 200 },
    ]);
    prisma.loyaltyTransaction.groupBy.mockResolvedValue([
      { customerId: 'cust-1', _sum: { points: 400 } },
      { customerId: 'cust-2', _sum: { points: 200 } },
    ]);
    prisma.loyaltySettings.findUnique.mockResolvedValue({ pointValue: 0.1 });

    const result = await service.getAnalytics('store-1', from, to);

    expect(result.totalEarned).toBe(500);
    expect(result.totalRedeemed).toBe(200);
    expect(result.totalExpired).toBe(50);
    expect(result.discountValue).toBeCloseTo(20); // 200 × 0.1
    expect(result.activeParticipants).toBe(12);
    expect(result.topCustomers).toHaveLength(2);
    expect(result.topCustomers[0].totalEarned).toBe(400);
  });

  it('should return zero values when no transactions exist in the period', async () => {
    const from = new Date('2026-01-01');
    const to = new Date('2026-01-31');

    prisma.loyaltyTransaction.aggregate
      .mockResolvedValue({ _sum: { points: null } });
    prisma.customer.count.mockResolvedValue(0);
    prisma.customer.findMany.mockResolvedValue([]);
    prisma.loyaltyTransaction.groupBy.mockResolvedValue([]);
    prisma.loyaltySettings.findUnique.mockResolvedValue(null);

    const result = await service.getAnalytics('store-1', from, to);

    expect(result.totalEarned).toBe(0);
    expect(result.totalRedeemed).toBe(0);
    expect(result.totalExpired).toBe(0);
    expect(result.discountValue).toBe(0);
    expect(result.activeParticipants).toBe(0);
    expect(result.topCustomers).toHaveLength(0);
  });
});
```

> **Note:** These tests will require the Prisma fake in the spec file to support `aggregate`, `groupBy`, and `loyaltySettings.findUnique`. If the existing fake doesn't have these, add mock setup lines in `beforeEach`:
> ```typescript
> prisma.loyaltyTransaction.aggregate = jest.fn();
> prisma.loyaltyTransaction.groupBy = jest.fn();
> prisma.customer.count = jest.fn();
> prisma.loyaltySettings = { findUnique: jest.fn() };
> ```

- [ ] **Step 2: Run to confirm failure**

```bash
cd api && npx jest src/modules/loyalty/loyalty.service.spec.ts --no-coverage -t "getAnalytics" 2>&1 | tail -10
```

Expected: 2 failing — `getAnalytics is not a function`.

- [ ] **Step 3: Create the DTO**

```typescript
// api/src/modules/loyalty/dto/loyalty-analytics-query.dto.ts
import { IsDateString } from 'class-validator';

export class LoyaltyAnalyticsQueryDto {
  @IsDateString()
  from: string;

  @IsDateString()
  to: string;
}
```

- [ ] **Step 4: Implement getAnalytics in LoyaltyService**

Add the method to `api/src/modules/loyalty/loyalty.service.ts`:

```typescript
async getAnalytics(storeId: string, from: Date, to: Date) {
  const dateFilter = { gte: from, lte: to };

  const [earned, redeemed, expired, participants, topCustomers, settings] =
    await Promise.all([
      this.prisma.loyaltyTransaction.aggregate({
        where: { storeId, type: 'EARN', createdAt: dateFilter },
        _sum: { points: true },
      }),
      this.prisma.loyaltyTransaction.aggregate({
        where: { storeId, type: 'REDEEM', createdAt: dateFilter },
        _sum: { points: true },
      }),
      this.prisma.loyaltyTransaction.aggregate({
        where: { storeId, type: 'EXPIRE', createdAt: dateFilter },
        _sum: { points: true },
      }),
      this.prisma.customer.count({
        where: { storeId, loyaltyPoints: { gt: 0 } },
      }),
      this.prisma.customer.findMany({
        where: { storeId, loyaltyPoints: { gt: 0 } },
        orderBy: { loyaltyPoints: 'desc' },
        take: 10,
        select: { id: true, name: true, loyaltyPoints: true },
      }),
      this.prisma.loyaltySettings.findUnique({ where: { storeId } }),
    ]);

  const totalEarned = earned._sum.points ?? 0;
  const totalRedeemed = Math.abs(redeemed._sum.points ?? 0);
  const totalExpired = Math.abs(expired._sum.points ?? 0);
  const pointValue = Number(settings?.pointValue ?? 0);

  const earnedPerCustomer =
    topCustomers.length > 0
      ? await this.prisma.loyaltyTransaction.groupBy({
          by: ['customerId'],
          where: {
            storeId,
            customerId: { in: topCustomers.map((c) => c.id) },
            type: 'EARN',
          },
          _sum: { points: true },
        })
      : [];

  const earnMap = new Map(
    earnedPerCustomer.map((r) => [r.customerId, r._sum.points ?? 0]),
  );

  return {
    period: { from: from.toISOString(), to: to.toISOString() },
    totalEarned,
    totalRedeemed,
    totalExpired,
    discountValue: totalRedeemed * pointValue,
    activeParticipants: participants,
    topCustomers: topCustomers.map((c) => ({
      customerId: c.id,
      name: c.name,
      balance: c.loyaltyPoints,
      totalEarned: earnMap.get(c.id) ?? 0,
    })),
  };
}
```

- [ ] **Step 5: Add analytics endpoint to LoyaltyController**

In `api/src/modules/loyalty/loyalty.controller.ts`, add:

```typescript
import { Get, Query } from '@nestjs/common'; // already imported, ensure Query is present
import { LoyaltyAnalyticsQueryDto } from './dto/loyalty-analytics-query.dto';
```

Add method:
```typescript
@Get('analytics')
@ApiOperation({ summary: 'Loyalty analytics: totals, participants, top customers' })
async getAnalytics(
  @Param('storeId') storeId: string,
  @Query() query: LoyaltyAnalyticsQueryDto,
) {
  const from = new Date(query.from);
  const to = new Date(query.to);
  return this.loyaltyService.getAnalytics(storeId, from, to);
}
```

- [ ] **Step 6: Run analytics tests**

```bash
cd api && npx jest src/modules/loyalty/loyalty.service.spec.ts --no-coverage 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 7: Run full suite**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -5
```

- [ ] **Step 8: Commit**

```bash
git add api/src/modules/loyalty/dto/loyalty-analytics-query.dto.ts \
        api/src/modules/loyalty/loyalty.service.ts \
        api/src/modules/loyalty/loyalty.controller.ts \
        api/src/modules/loyalty/loyalty.service.spec.ts
git commit -m "feat(loyalty): getAnalytics endpoint + 2 tests (Spec K T5)"
```

---

## Task 6: Flutter — Customer entity + datasource + API endpoints

**Files:**
- Modify: `app/lib/domain/entities/customer.dart`
- Modify: `app/lib/data/datasources/remote/customer_remote_datasource.dart`
- Modify: `app/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Add telegramChatId to Customer entity**

In `app/lib/domain/entities/customer.dart`, add field after `isActive`:

```dart
final String? telegramChatId;
```

Add to constructor:
```dart
this.telegramChatId,
```

- [ ] **Step 2: Map telegramChatId in _mapCustomer**

In `app/lib/data/datasources/remote/customer_remote_datasource.dart`, in `_mapCustomer()`, add after `isActive` mapping:

```dart
telegramChatId: json['telegramChatId'] as String?,
```

- [ ] **Step 3: Add API endpoint constants**

In `app/lib/core/constants/api_endpoints.dart`, add after existing loyalty endpoints:

```dart
static String customerTelegram(String storeId, String customerId) =>
    '/stores/$storeId/customers/$customerId/telegram';

static String loyaltyAnalytics(String storeId) =>
    '/stores/$storeId/loyalty/analytics';
```

- [ ] **Step 4: Run dart analyze**

```bash
cd app && dart analyze lib/domain/entities/customer.dart lib/data/datasources/remote/customer_remote_datasource.dart lib/core/constants/api_endpoints.dart
```

Expected: no issues.

- [ ] **Step 5: Run full Flutter test suite**

```bash
cd app && flutter test --no-pub 2>&1 | tail -10
```

Expected: all 453 tests pass (Customer entity change is additive — `telegramChatId` defaults to null).

- [ ] **Step 6: Commit**

```bash
git add app/lib/domain/entities/customer.dart \
        app/lib/data/datasources/remote/customer_remote_datasource.dart \
        app/lib/core/constants/api_endpoints.dart
git commit -m "feat(customer): telegramChatId field + API endpoint constants (Spec K T6)"
```

---

## Task 7: Flutter — CustomerFormPage Telegram field

**Files:**
- Modify: `app/lib/presentation/pages/customer/customer_form_page.dart`

The existing CustomerFormPage has controllers for name, phone, email, birthday, notes. We add a Telegram username field. On save, if non-empty, we fire-and-forget the `PUT /customers/:id/telegram` call after the main customer save.

- [ ] **Step 1: Add Telegram field**

In `customer_form_page.dart`:

1. Add the controller as a field (after `_notesController`):
```dart
final _telegramController = TextEditingController();
```

2. In `initState` / `_populate` (wherever the form pre-fills from an existing customer), add:
```dart
if (widget.customer?.telegramChatId != null) {
  // chatId is already linked — show placeholder but don't prefill username
  // (we can't reverse chatId→username; just show the link status)
}
```

3. In `dispose()`, add:
```dart
_telegramController.dispose();
```

4. In the form widget tree (after the notes field), add:
```dart
const SizedBox(height: AppConstants.spacingSm),
TextFormField(
  controller: _telegramController,
  decoration: const InputDecoration(
    labelText: 'Telegram @username',
    hintText: '@alisher',
    prefixIcon: Icon(Icons.telegram_outlined),
  ),
),
```

5. In `_save()` (or wherever `createCustomer`/`updateCustomer` is called), after a successful customer save, add:

```dart
final tg = _telegramController.text.trim();
if (tg.isNotEmpty && savedCustomerId != null) {
  sl<DioClient>()
      .put(
        ApiEndpoints.customerTelegram(widget.storeId, savedCustomerId),
        data: {'username': tg},
      )
      .then((_) => AppSnackbar.success(context, 'Telegram привязан'))
      .catchError((_) => AppSnackbar.error(context, 'Не удалось привязать Telegram'));
}
```

> **Where to find `savedCustomerId`:** look at the `_save()` method. After `createCustomer` or `updateCustomer` returns a `Customer`, use `customer.id`.

- [ ] **Step 2: Run dart analyze**

```bash
cd app && dart analyze lib/presentation/pages/customer/customer_form_page.dart
```

- [ ] **Step 3: Run Flutter tests**

```bash
cd app && flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/lib/presentation/pages/customer/customer_form_page.dart
git commit -m "feat(customer): Telegram username field in CustomerFormPage (Spec K T7)"
```

---

## Task 8: Flutter — CustomerDetailPage Telegram badge

**Files:**
- Modify: `app/lib/presentation/pages/customer/customer_detail_page.dart`

Show a Telegram icon next to the customer name if `customer.telegramChatId != null`. Tapping it opens a Telegram deep link.

- [ ] **Step 1: Add Telegram icon to the header card**

In `customer_detail_page.dart`, find the `Text(customer.name, ...)` line in the `AppCard` (around line 101). Wrap it in a `Row` with a Telegram icon:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(customer.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    if (customer.telegramChatId != null) ...[
      const SizedBox(width: 6),
      const Icon(Icons.telegram_outlined, color: Color(0xFF26A5E4), size: 20),
    ],
  ],
),
```

- [ ] **Step 2: Run dart analyze**

```bash
cd app && dart analyze lib/presentation/pages/customer/customer_detail_page.dart
```

- [ ] **Step 3: Run Flutter tests**

```bash
cd app && flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/lib/presentation/pages/customer/customer_detail_page.dart
git commit -m "feat(customer): Telegram badge in CustomerDetailPage (Spec K T8)"
```

---

## Task 9: Flutter — ReportsPage server-side Excel export with hasExport gating

**Files:**
- Modify: `app/lib/presentation/pages/finance/reports_page.dart`

The existing ReportsPage already has `_exportExcel()` which does a local client-side export from chart data. This task adds a server-side export that downloads the full dataset from the backend. The Excel option in the sheet becomes gated by `hasExport` from `SubscriptionBloc`.

The existing PDF export stays unchanged (it exports the in-screen chart data, not a backend call).

- [ ] **Step 1: Add SubscriptionBloc import and hasExport check**

At the top of `reports_page.dart`, ensure the import exists:
```dart
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_state.dart';
```

- [ ] **Step 2: Add _exportServerExcel() method**

Add a new method after `_exportExcel()`:

```dart
Future<void> _exportServerExcel(String type) async {
  final storeId = _storeId;
  if (storeId == null) return;

  try {
    final response = await sl<DioClient>().get(
      ApiEndpoints.reportsExport(storeId, type),
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data as List<int>;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/export_${type}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);
    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Экспорт $type');
    }
  } catch (e) {
    if (mounted) AppSnackbar.error(context, 'Ошибка экспорта: $e');
  }
}
```

- [ ] **Step 3: Add reportsExport to ApiEndpoints**

In `app/lib/core/constants/api_endpoints.dart`, add:
```dart
static String reportsExport(String storeId, String type) =>
    '/stores/$storeId/reports/export?type=$type';
```

- [ ] **Step 4: Gate the Excel export tile behind hasExport**

In `_showExportSheet()`, find the existing `_ExportTile` for Excel. Replace it with a conditional that checks `SubscriptionBloc`:

```dart
BlocBuilder<SubscriptionBloc, SubscriptionState>(
  builder: (ctx, sub) {
    if (!sub.hasExport) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        _ExportTile(
          icon: Icons.table_chart_outlined,
          label: 'Скачать Excel (все данные)',
          onTap: () {
            Navigator.pop(ctx);
            _showExportTypeSheet();
          },
        ),
      ],
    );
  },
),
```

- [ ] **Step 5: Add _showExportTypeSheet() method**

```dart
void _showExportTypeSheet() {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXxl)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Что экспортировать?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppConstants.spacingMd),
            for (final (label, type) in [
              ('Продажи', 'sales'),
              ('Товары', 'products'),
              ('Клиенты', 'customers'),
            ])
              ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportServerExcel(type);
                },
              ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 6: Run dart analyze**

```bash
cd app && dart analyze lib/presentation/pages/finance/reports_page.dart
```

- [ ] **Step 7: Run Flutter tests (update goldens if needed)**

```bash
cd app && flutter test --no-pub 2>&1 | tail -10
```

If golden tests for ReportsPage fail due to the UI change, update them:
```bash
cd app && flutter test --update-goldens test/presentation/pages/finance/reports_page_golden_test.dart
```

Then re-run:
```bash
cd app && flutter test --no-pub 2>&1 | tail -5
```

- [ ] **Step 8: Commit**

```bash
git add app/lib/presentation/pages/finance/reports_page.dart \
        app/lib/core/constants/api_endpoints.dart \
        app/test/presentation/pages/finance/goldens/
git commit -m "feat(reports): server-side Excel export with hasExport gating (Spec K T9)"
```

---

## Task 10: Flutter — LoyaltyAnalytics entity + remote datasource

**Files:**
- Create: `app/lib/domain/entities/loyalty_analytics.dart`
- Modify: `app/lib/domain/repositories/loyalty_repository.dart`
- Modify: `app/lib/data/datasources/remote/loyalty_remote_datasource.dart`
- Modify: `app/lib/data/repositories/loyalty_repository_impl.dart`

- [ ] **Step 1: Create LoyaltyAnalytics entity**

```dart
// app/lib/domain/entities/loyalty_analytics.dart
class LoyaltyAnalyticsTopCustomer {
  final String customerId;
  final String name;
  final int balance;
  final int totalEarned;

  const LoyaltyAnalyticsTopCustomer({
    required this.customerId,
    required this.name,
    required this.balance,
    required this.totalEarned,
  });
}

class LoyaltyAnalytics {
  final DateTime from;
  final DateTime to;
  final int totalEarned;
  final int totalRedeemed;
  final int totalExpired;
  final double discountValue;
  final int activeParticipants;
  final List<LoyaltyAnalyticsTopCustomer> topCustomers;

  const LoyaltyAnalytics({
    required this.from,
    required this.to,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.totalExpired,
    required this.discountValue,
    required this.activeParticipants,
    required this.topCustomers,
  });

  factory LoyaltyAnalytics.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    final tops = (json['topCustomers'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((c) => LoyaltyAnalyticsTopCustomer(
              customerId: c['customerId'] as String,
              name: c['name'] as String,
              balance: (c['balance'] as num).toInt(),
              totalEarned: (c['totalEarned'] as num).toInt(),
            ))
        .toList();
    return LoyaltyAnalytics(
      from: DateTime.parse(period['from'] as String),
      to: DateTime.parse(period['to'] as String),
      totalEarned: (json['totalEarned'] as num).toInt(),
      totalRedeemed: (json['totalRedeemed'] as num).toInt(),
      totalExpired: (json['totalExpired'] as num).toInt(),
      discountValue: (json['discountValue'] as num).toDouble(),
      activeParticipants: (json['activeParticipants'] as num).toInt(),
      topCustomers: tops,
    );
  }
}
```

- [ ] **Step 2: Add getAnalytics to LoyaltyRepository interface**

In `app/lib/domain/repositories/loyalty_repository.dart`:
```dart
import '../entities/loyalty_analytics.dart';

// Add to abstract class:
Future<LoyaltyAnalytics> getAnalytics(String storeId, DateTime from, DateTime to);
```

- [ ] **Step 3: Add getAnalytics to LoyaltyRemoteDatasource**

In `app/lib/data/datasources/remote/loyalty_remote_datasource.dart`:

Add to abstract class:
```dart
Future<LoyaltyAnalytics> getAnalytics(String storeId, DateTime from, DateTime to);
```

Add implementation in `LoyaltyRemoteDatasourceImpl`:
```dart
@override
Future<LoyaltyAnalytics> getAnalytics(String storeId, DateTime from, DateTime to) async {
  try {
    final response = await _dioClient.get(
      ApiEndpoints.loyaltyAnalytics(storeId),
      queryParameters: {
        'from': from.toIso8601String().substring(0, 10),
        'to': to.toIso8601String().substring(0, 10),
      },
    );
    final json = decodeApiObject(response.data) ?? <String, dynamic>{};
    return LoyaltyAnalytics.fromJson(json);
  } on DioException catch (e) {
    throw _handleDioError(e);
  }
}
```

Don't forget the import at the top:
```dart
import '../../../domain/entities/loyalty_analytics.dart';
```

- [ ] **Step 4: Add getAnalytics to LoyaltyRepositoryImpl**

In `app/lib/data/repositories/loyalty_repository_impl.dart`:

```dart
@override
Future<LoyaltyAnalytics> getAnalytics(String storeId, DateTime from, DateTime to) =>
    _remote.getAnalytics(storeId, from, to);
```

Add import:
```dart
import '../../domain/entities/loyalty_analytics.dart';
```

- [ ] **Step 5: Run dart analyze**

```bash
cd app && dart analyze lib/domain/entities/loyalty_analytics.dart \
                      lib/domain/repositories/loyalty_repository.dart \
                      lib/data/datasources/remote/loyalty_remote_datasource.dart \
                      lib/data/repositories/loyalty_repository_impl.dart
```

Expected: no issues.

- [ ] **Step 6: Run Flutter tests**

```bash
cd app && flutter test --no-pub 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add app/lib/domain/entities/loyalty_analytics.dart \
        app/lib/domain/repositories/loyalty_repository.dart \
        app/lib/data/datasources/remote/loyalty_remote_datasource.dart \
        app/lib/data/repositories/loyalty_repository_impl.dart
git commit -m "feat(loyalty): LoyaltyAnalytics entity + datasource + repo (Spec K T10)"
```

---

## Task 11: Flutter — LoyaltyAnalyticsBloc

**Files:**
- Create: `app/lib/presentation/blocs/loyalty/loyalty_analytics_event.dart`
- Create: `app/lib/presentation/blocs/loyalty/loyalty_analytics_state.dart`
- Create: `app/lib/presentation/blocs/loyalty/loyalty_analytics_bloc.dart`

- [ ] **Step 1: Write the failing test file first** (see Task 13 — write tests here, implement in steps 2-4)

Skip ahead to Task 13 step 1 to write the test, then return here to implement.

- [ ] **Step 2: Create events**

```dart
// app/lib/presentation/blocs/loyalty/loyalty_analytics_event.dart
abstract class LoyaltyAnalyticsEvent {}

class LoyaltyAnalyticsLoadRequested extends LoyaltyAnalyticsEvent {
  final String storeId;
  final DateTime from;
  final DateTime to;

  LoyaltyAnalyticsLoadRequested({
    required this.storeId,
    required this.from,
    required this.to,
  });
}
```

- [ ] **Step 3: Create states**

```dart
// app/lib/presentation/blocs/loyalty/loyalty_analytics_state.dart
import 'package:equatable/equatable.dart';
import '../../../domain/entities/loyalty_analytics.dart';

abstract class LoyaltyAnalyticsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoyaltyAnalyticsInitial extends LoyaltyAnalyticsState {}

class LoyaltyAnalyticsLoading extends LoyaltyAnalyticsState {}

class LoyaltyAnalyticsLoaded extends LoyaltyAnalyticsState {
  final LoyaltyAnalytics data;
  const LoyaltyAnalyticsLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class LoyaltyAnalyticsError extends LoyaltyAnalyticsState {
  final String message;
  const LoyaltyAnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 4: Create the Bloc**

```dart
// app/lib/presentation/blocs/loyalty/loyalty_analytics_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/loyalty_repository.dart';
import 'loyalty_analytics_event.dart';
import 'loyalty_analytics_state.dart';

class LoyaltyAnalyticsBloc
    extends Bloc<LoyaltyAnalyticsEvent, LoyaltyAnalyticsState> {
  final LoyaltyRepository _repository;

  LoyaltyAnalyticsBloc({required LoyaltyRepository repository})
      : _repository = repository,
        super(LoyaltyAnalyticsInitial()) {
    on<LoyaltyAnalyticsLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    LoyaltyAnalyticsLoadRequested event,
    Emitter<LoyaltyAnalyticsState> emit,
  ) async {
    emit(LoyaltyAnalyticsLoading());
    try {
      final data = await _repository.getAnalytics(
        event.storeId,
        event.from,
        event.to,
      );
      emit(LoyaltyAnalyticsLoaded(data));
    } catch (e) {
      emit(LoyaltyAnalyticsError(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Run dart analyze**

```bash
cd app && dart analyze lib/presentation/blocs/loyalty/
```

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/blocs/loyalty/loyalty_analytics_event.dart \
        app/lib/presentation/blocs/loyalty/loyalty_analytics_state.dart \
        app/lib/presentation/blocs/loyalty/loyalty_analytics_bloc.dart
git commit -m "feat(loyalty): LoyaltyAnalyticsBloc (Spec K T11)"
```

---

## Task 12: Flutter — LoyaltyAnalyticsPage + route + DI

**Files:**
- Create: `app/lib/presentation/pages/settings/loyalty_analytics_page.dart`
- Modify: `app/lib/core/router/route_names.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/injection.dart`
- Modify: `app/lib/app.dart`
- Modify: `app/lib/presentation/pages/settings/loyalty_settings_page.dart`

- [ ] **Step 1: Create LoyaltyAnalyticsPage**

```dart
// app/lib/presentation/pages/settings/loyalty_analytics_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../domain/entities/loyalty_analytics.dart';
import '../../blocs/loyalty/loyalty_analytics_bloc.dart';
import '../../blocs/loyalty/loyalty_analytics_event.dart';
import '../../blocs/loyalty/loyalty_analytics_state.dart';

enum _Period { week, month, year }

class LoyaltyAnalyticsPage extends StatefulWidget {
  final String storeId;
  const LoyaltyAnalyticsPage({super.key, required this.storeId});

  @override
  State<LoyaltyAnalyticsPage> createState() => _LoyaltyAnalyticsPageState();
}

class _LoyaltyAnalyticsPageState extends State<LoyaltyAnalyticsPage> {
  _Period _period = _Period.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final now = DateTime.now();
    final (from, to) = switch (_period) {
      _Period.week => (now.subtract(const Duration(days: 7)), now),
      _Period.month => (DateTime(now.year, now.month, 1), now),
      _Period.year => (DateTime(now.year, 1, 1), now),
    };
    context.read<LoyaltyAnalyticsBloc>().add(
          LoyaltyAnalyticsLoadRequested(
              storeId: widget.storeId, from: from, to: to),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика баллов')),
      body: Column(
        children: [
          _PeriodChips(
            selected: _period,
            onChanged: (p) {
              setState(() => _period = p);
              _load();
            },
          ),
          Expanded(
            child: BlocBuilder<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
              builder: (context, state) {
                if (state is LoyaltyAnalyticsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is LoyaltyAnalyticsError) {
                  return Center(child: Text(state.message));
                }
                if (state is LoyaltyAnalyticsLoaded) {
                  return _Body(data: state.data);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingSm),
      child: Row(
        children: [
          for (final (label, p) in [
            ('Неделя', _Period.week),
            ('Месяц', _Period.month),
            ('Год', _Period.year),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == p,
                onSelected: (_) => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final LoyaltyAnalytics data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _StatCard(label: 'Начислено', value: '${data.totalEarned} баллов'),
            _StatCard(label: 'Списано', value: '${data.totalRedeemed} баллов'),
            _StatCard(label: 'Сгорело', value: '${data.totalExpired} баллов'),
            _StatCard(
                label: 'Экономия',
                value: '${data.discountValue.toStringAsFixed(0)} сом'),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text('Активных участников: ${data.activeParticipants}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: AppConstants.spacingMd),
        if (data.topCustomers.isNotEmpty) ...[
          const Text('Топ клиентов',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppConstants.spacingSm),
          ...data.topCustomers.map((c) {
            final maxBalance =
                data.topCustomers.first.balance.toDouble().clamp(1, double.infinity);
            return Padding(
              padding:
                  const EdgeInsets.only(bottom: AppConstants.spacingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${c.balance} баллов',
                          style: const TextStyle(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: c.balance / maxBalance,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: context.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add route constant**

In `app/lib/core/router/route_names.dart`, add after `loyaltySettings`:
```dart
static const String loyaltyAnalytics = '/settings/loyalty/analytics';
```

- [ ] **Step 3: Register route in app_router.dart**

In `app/lib/core/router/app_router.dart`, find the `GoRoute` for `loyaltySettings` (around line 595) and nest or add a sibling route for analytics. Add after the `loyaltySettings` route:

```dart
GoRoute(
  path: RouteNames.loyaltyAnalytics,
  builder: (context, state) {
    final storeId = state.uri.queryParameters['storeId'] ??
        (context.read<StoreBloc>().state is StoreLoaded
            ? (context.read<StoreBloc>().state as StoreLoaded).store.id
            : '');
    return BlocProvider(
      create: (_) => sl<LoyaltyAnalyticsBloc>(),
      child: LoyaltyAnalyticsPage(storeId: storeId),
    );
  },
),
```

Add import at the top:
```dart
import '../../../presentation/pages/settings/loyalty_analytics_page.dart';
import '../../../presentation/blocs/loyalty/loyalty_analytics_bloc.dart';
```

- [ ] **Step 4: Register LoyaltyAnalyticsBloc in injection.dart**

In `app/lib/injection.dart`, after the `LoyaltySettingsBloc` registration:
```dart
sl.registerFactory<LoyaltyAnalyticsBloc>(
  () => LoyaltyAnalyticsBloc(repository: sl<LoyaltyRepository>()),
);
```

Add import:
```dart
import 'presentation/blocs/loyalty/loyalty_analytics_bloc.dart';
```

- [ ] **Step 5: Add "Аналитика →" button to LoyaltySettingsPage**

In `app/lib/presentation/pages/settings/loyalty_settings_page.dart`, find `initState` (or the build method). Add an "Аналитика →" button at the top of the page body (before the settings form fields), visible only when loyalty is enabled:

```dart
// Near the top of the body ListView/Column, before the switch:
if (_isEnabled)
  Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      icon: const Icon(Icons.bar_chart_outlined),
      label: const Text('Аналитика →'),
      onPressed: () => context.push(
        RouteNames.loyaltyAnalytics,
        extra: {'storeId': widget.storeId},
      ),
    ),
  ),
```

Or pass storeId as query param:
```dart
onPressed: () => context.push(
  '${RouteNames.loyaltyAnalytics}?storeId=${widget.storeId}',
),
```

- [ ] **Step 6: Run dart analyze**

```bash
cd app && dart analyze lib/presentation/pages/settings/loyalty_analytics_page.dart \
                      lib/presentation/pages/settings/loyalty_settings_page.dart \
                      lib/core/router/ \
                      lib/injection.dart
```

- [ ] **Step 7: Run Flutter tests**

```bash
cd app && flutter test --no-pub 2>&1 | tail -10
```

- [ ] **Step 8: Commit**

```bash
git add app/lib/presentation/pages/settings/loyalty_analytics_page.dart \
        app/lib/presentation/pages/settings/loyalty_settings_page.dart \
        app/lib/core/router/route_names.dart \
        app/lib/core/router/app_router.dart \
        app/lib/injection.dart
git commit -m "feat(loyalty): LoyaltyAnalyticsPage + route + DI (Spec K T12)"
```

---

## Task 13: Flutter — LoyaltyAnalyticsBloc tests

**Files:**
- Create: `app/test/presentation/blocs/loyalty/loyalty_analytics_bloc_test.dart`

- [ ] **Step 1: Write the test file**

```dart
// app/test/presentation/blocs/loyalty/loyalty_analytics_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/loyalty_analytics.dart';
import 'package:dukonpro/domain/repositories/loyalty_repository.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_analytics_bloc.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_analytics_event.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_analytics_state.dart';

// Fake repository — test behavior, not implementation
class FakeLoyaltyRepository implements LoyaltyRepository {
  LoyaltyAnalytics? analyticsResult;
  Exception? analyticsError;

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) async => {};

  @override
  Future<Map<String, dynamic>> updateSettings(
          String storeId, Map<String, dynamic> data) async => {};

  @override
  Future<({int points, List transactions})> getCustomerBalance(
      String storeId, String customerId) async => (points: 0, transactions: []);

  @override
  Future<LoyaltyAnalytics> getAnalytics(
      String storeId, DateTime from, DateTime to) async {
    if (analyticsError != null) throw analyticsError!;
    return analyticsResult!;
  }
}

LoyaltyAnalytics _makeAnalytics() => LoyaltyAnalytics(
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
      totalEarned: 1000,
      totalRedeemed: 200,
      totalExpired: 50,
      discountValue: 20,
      activeParticipants: 5,
      topCustomers: [
        const LoyaltyAnalyticsTopCustomer(
          customerId: 'cust-1',
          name: 'Алишер',
          balance: 300,
          totalEarned: 500,
        ),
      ],
    );

void main() {
  group('LoyaltyAnalyticsBloc', () {
    late FakeLoyaltyRepository repo;

    setUp(() => repo = FakeLoyaltyRepository());

    blocTest<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
      'should emit [Loading, Loaded] when LoadRequested succeeds',
      build: () {
        repo.analyticsResult = _makeAnalytics();
        return LoyaltyAnalyticsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(LoyaltyAnalyticsLoadRequested(
        storeId: 'store-1',
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 31),
      )),
      expect: () => [
        isA<LoyaltyAnalyticsLoading>(),
        isA<LoyaltyAnalyticsLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as LoyaltyAnalyticsLoaded;
        expect(state.data.totalEarned, 1000);
        expect(state.data.topCustomers, hasLength(1));
      },
    );

    blocTest<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
      'should reload when period changes (second LoadRequested re-emits Loaded)',
      build: () {
        repo.analyticsResult = _makeAnalytics();
        return LoyaltyAnalyticsBloc(repository: repo);
      },
      act: (bloc) async {
        bloc.add(LoyaltyAnalyticsLoadRequested(
          storeId: 'store-1',
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
        ));
        await Future.delayed(Duration.zero);
        bloc.add(LoyaltyAnalyticsLoadRequested(
          storeId: 'store-1',
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        ));
      },
      expect: () => [
        isA<LoyaltyAnalyticsLoading>(),
        isA<LoyaltyAnalyticsLoaded>(),
        isA<LoyaltyAnalyticsLoading>(),
        isA<LoyaltyAnalyticsLoaded>(),
      ],
    );

    blocTest<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
      'should emit [Loading, Error] when repository throws',
      build: () {
        repo.analyticsError = Exception('Network error');
        return LoyaltyAnalyticsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(LoyaltyAnalyticsLoadRequested(
        storeId: 'store-1',
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 31),
      )),
      expect: () => [
        isA<LoyaltyAnalyticsLoading>(),
        isA<LoyaltyAnalyticsError>(),
      ],
    );
  });
}
```

- [ ] **Step 2: Run the tests**

```bash
cd app && flutter test test/presentation/blocs/loyalty/loyalty_analytics_bloc_test.dart --no-pub
```

Expected: 3 passing.

- [ ] **Step 3: Run full Flutter test suite**

```bash
cd app && flutter test --no-pub 2>&1 | tail -5
```

Expected: 456+ tests passing (453 baseline + 3 new).

- [ ] **Step 4: Commit**

```bash
git add app/test/presentation/blocs/loyalty/loyalty_analytics_bloc_test.dart
git commit -m "test(loyalty): LoyaltyAnalyticsBloc — 3 tests (Spec K T13)"
```

---

## Final verification

After all 13 tasks are committed:

- [ ] **Backend suite**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -5
```

Expected: all tests pass (260 baseline + ~7 new = ~267).

- [ ] **Flutter suite**

```bash
cd app && flutter test --no-pub 2>&1 | tail -5
```

Expected: 456+ tests passing.

- [ ] **TypeScript build clean**

```bash
cd api && npx tsc --noEmit 2>&1 | head -20
```

Expected: no errors.

- [ ] **Dart analyze clean**

```bash
cd app && dart analyze lib/ 2>&1 | tail -5
```

Expected: no issues.

---

## Self-review against spec

| Spec requirement | Task |
|---|---|
| `ExportService` + 3 xlsx methods | ✅ Already implemented; Task 1 adds tests |
| `GET /reports/export?type=...` endpoint | ✅ Already implemented |
| Flutter: download xlsx from server | Task 9 |
| Flutter: `hasExport` gating | Task 9 |
| `User.telegramChatId` migration | Task 2 |
| `TelegramService.sendMessage()` | Task 2 |
| `TelegramService.getStoreChatId()` | Task 2 |
| `PUT /customers/:id/telegram` endpoint | Task 3 |
| `linkTelegram` resolve @username | Task 3 |
| `LoyaltyService.earnPoints` fires push (customer + store) | Task 4 |
| Push failures are silent | Task 4 |
| `GET /loyalty/analytics` endpoint | Task 5 |
| `LoyaltyAnalytics` response shape | Task 5 |
| `Customer.telegramChatId` in Flutter entity | Task 6 |
| Flutter: CustomerFormPage Telegram field | Task 7 |
| Flutter: CustomerDetailPage Telegram badge | Task 8 |
| `LoyaltyAnalyticsBloc` | Task 11 |
| `LoyaltyAnalyticsPage` (period chips, 4 cards, top list) | Task 12 |
| "Аналитика →" entry point in LoyaltySettingsPage | Task 12 |
| `loyalty_analytics_bloc_test.dart` — 3 tests | Task 13 |
| `export.service.spec.ts` — 3 tests | Task 1 |
| `customers.service.spec.ts` — 2 new tests | Task 3 |
| `loyalty.service.spec.ts` — 4 new tests | Tasks 4 + 5 |
| All existing tests remain green | Verified at each task |
