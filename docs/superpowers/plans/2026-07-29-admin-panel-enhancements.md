# Admin Panel Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 independent admin-panel capabilities to Dukon: targeted notifications, manual payment recording, CSV/Excel export, before/after diff in the audit log, in-app banners, and support impersonation.

**Architecture:** Every backend addition lives in the existing `api/src/modules/admin/` module (new controllers/services alongside the existing 6), reusing `JwtAuthGuard`/`AdminGuard`/`AuditInterceptor` exactly as the current admin routes do. Frontend additions are new Next.js App Router pages/dialogs under `admin/app/(admin)/`, copying the shadcn + TanStack Query + `sonner` toast conventions already used by `/announcements`, `/users/[id]`, and `/audit-log`.

**Tech Stack:** NestJS, Prisma, PostgreSQL, class-validator, Jest — backend. Next.js App Router, TanStack Query, shadcn/ui, Tailwind — frontend (`admin/`). Flutter/Dart for the two mobile-app-visible pieces (banners, impersonation consent screen).

---

## Spec coverage checklist (self-review, done before tasks below)

| Spec section | Task |
|---|---|
| 1. Точечные уведомления | Task 1 |
| 2. Ручное создание платежа | Task 2 |
| 3. Экспорт в Excel | Task 3 |
| 4. Diff в аудит-логе | Task 4 |
| 5. In-app баннеры | Task 5 |
| 6. Impersonate | Task 6 |

All 6 spec sections have a corresponding task. No gaps found.

---

## Task 1: Точечные уведомления (direct notifications)

**Files:**
- Create: `api/src/modules/admin/dto/send-direct-notification.dto.ts`
- Create: `api/src/modules/admin/admin-notifications.controller.ts`
- Modify: `api/src/modules/admin/admin.service.ts` (add `sendDirectNotification` method)
- Modify: `api/src/modules/admin/admin.module.ts` (register new controller)
- Test: `api/src/modules/admin/admin.direct-notifications.spec.ts`
- Modify: `admin/app/(admin)/users/[id]/page.tsx` (add "Отправить сообщение" button + dialog)
- Modify: `admin/app/(admin)/stores/[id]/page.tsx` (same button + dialog, store-scoped)

**Design note:** `NotificationsService.sendPush(userId, title, body, type, storeId)` requires `storeId` as a non-optional parameter even when targeting a specific user. When the admin targets a `userId` directly (not a `storeId`), we resolve the user's oldest owned store as the association target — mirrors how `AdminService._resolveAnnouncementAudience` already picks "first store per user as primary".

- [ ] **Step 1: Write the DTO**

```typescript
// api/src/modules/admin/dto/send-direct-notification.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength, ValidateIf } from 'class-validator';

export class SendDirectNotificationDto {
  @ApiPropertyOptional({ description: 'Target a specific user account. Exactly one of userId/storeId must be set.' })
  @ValidateIf((o) => !o.storeId)
  @IsNotEmpty()
  @IsString()
  userId?: string;

  @ApiPropertyOptional({ description: 'Target every owner+staff of a store. Exactly one of userId/storeId must be set.' })
  @ValidateIf((o) => !o.userId)
  @IsNotEmpty()
  @IsString()
  storeId?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(200)
  title: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(1000)
  body: string;
}
```

- [ ] **Step 2: Write the failing test for `AdminService.sendDirectNotification`**

```typescript
// api/src/modules/admin/admin.direct-notifications.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake() {
  return {
    store: {
      findFirst: jest.fn(async () => null as any),
    },
  };
}

describe('AdminService — sendDirectNotification', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock; sendToStoreUsers: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = {
      sendPush: jest.fn(async () => undefined),
      sendToStoreUsers: jest.fn(async () => undefined),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('sends to every store user when storeId is given', async () => {
    await service.sendDirectNotification({
      storeId: 's1',
      title: 'Заголовок',
      body: 'Текст',
    } as any);

    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      's1',
      'Заголовок',
      'Текст',
      'ADMIN_DIRECT',
    );
    expect(notifications.sendPush).not.toHaveBeenCalled();
  });

  it('resolves the user oldest owned store and sends push when userId is given', async () => {
    (prisma.store.findFirst as jest.Mock).mockResolvedValue({ id: 'store-primary' });

    await service.sendDirectNotification({
      userId: 'u1',
      title: 'Заголовок',
      body: 'Текст',
    } as any);

    expect(prisma.store.findFirst).toHaveBeenCalledWith({
      where: { ownerId: 'u1' },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });
    expect(notifications.sendPush).toHaveBeenCalledWith(
      'u1',
      'Заголовок',
      'Текст',
      'ADMIN_DIRECT',
      'store-primary',
    );
  });

  it('throws NotFoundException when targeted user owns no store', async () => {
    (prisma.store.findFirst as jest.Mock).mockResolvedValue(null);

    await expect(
      service.sendDirectNotification({
        userId: 'u-no-store',
        title: 'Заголовок',
        body: 'Текст',
      } as any),
    ).rejects.toThrow(NotFoundException);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd api && npx jest admin.direct-notifications.spec.ts`
Expected: FAIL — `service.sendDirectNotification is not a function`

- [ ] **Step 4: Implement `sendDirectNotification` in `AdminService`**

In `api/src/modules/admin/admin.service.ts`, add the import at the top:

```typescript
import { SendDirectNotificationDto } from './dto/send-direct-notification.dto';
```

Add this method inside the `AdminService` class, right after the `// ============ ANNOUNCEMENTS ============` section closes (after `listAnnouncements`, before `// ============ AUDIT LOGS ============`):

```typescript
  // ============ DIRECT NOTIFICATIONS ============

  async sendDirectNotification(dto: SendDirectNotificationDto): Promise<void> {
    if (dto.storeId) {
      await this.notifications.sendToStoreUsers(
        dto.storeId,
        dto.title,
        dto.body,
        'ADMIN_DIRECT',
      );
      return;
    }

    const store = await this.prisma.store.findFirst({
      where: { ownerId: dto.userId },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });
    if (!store) {
      throw new NotFoundException('User has no store to associate the notification with');
    }

    await this.notifications.sendPush(
      dto.userId!,
      dto.title,
      dto.body,
      'ADMIN_DIRECT',
      store.id,
    );
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd api && npx jest admin.direct-notifications.spec.ts`
Expected: PASS (3 tests)

- [ ] **Step 6: Create the controller**

```typescript
// api/src/modules/admin/admin-notifications.controller.ts
import { Controller, Post, Body, UseGuards, UseInterceptors } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { SendDirectNotificationDto } from './dto/send-direct-notification.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/notifications')
export class AdminNotificationsController {
  constructor(private readonly adminService: AdminService) {}

  @Post('direct')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Send a push notification to one specific user or every user of one store' })
  sendDirect(@Body() dto: SendDirectNotificationDto) {
    return this.adminService.sendDirectNotification(dto);
  }
}
```

- [ ] **Step 7: Wire the controller into the module**

In `api/src/modules/admin/admin.module.ts`, add the import:

```typescript
import { AdminNotificationsController } from './admin-notifications.controller';
```

Add `AdminNotificationsController` to the `controllers` array (after `AdminAnnouncementsController`):

```typescript
  controllers: [
    AdminUsersController,
    AdminStoresController,
    AdminDashboardController,
    AdminPlansController,
    AdminAnnouncementsController,
    AdminNotificationsController,
    AdminAuditLogController,
  ],
```

- [ ] **Step 8: Run the full admin test suite**

Run: `cd api && npx jest src/modules/admin`
Expected: PASS (all admin spec files, including the 3 new tests)

- [ ] **Step 9: Commit backend**

```bash
cd api
git add src/modules/admin/dto/send-direct-notification.dto.ts \
        src/modules/admin/admin-notifications.controller.ts \
        src/modules/admin/admin.service.ts \
        src/modules/admin/admin.module.ts \
        src/modules/admin/admin.direct-notifications.spec.ts
git commit -m "feat(admin): add direct notification endpoint for a specific user or store"
```

- [ ] **Step 10: Add the "Отправить сообщение" dialog to the user detail page**

In `admin/app/(admin)/users/[id]/page.tsx`, add these imports (extend the existing `lucide-react` import and add new ones):

```tsx
import { useState } from 'react';
import { ArrowLeft, Store, ShieldCheck, ShieldOff, Ban, CheckCircle, Send } from 'lucide-react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
```

Inside `UserDetailPage`, add state and a mutation right after the existing `toggleBlockMutation` declaration:

```tsx
  const [messageDialog, setMessageDialog] = useState(false);
  const [msgTitle, setMsgTitle] = useState('');
  const [msgBody, setMsgBody] = useState('');

  const sendMessageMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/notifications/direct', { userId: id, title: msgTitle, body: msgBody }),
    onSuccess: () => {
      setMessageDialog(false);
      setMsgTitle('');
      setMsgBody('');
      toast.success('Сообщение отправлено');
    },
    onError: () => toast.error('Ошибка отправки сообщения'),
  });
```

Add the button inside the existing `<div className="flex gap-3">` block (right after the block/unblock `<Button>`, before its closing `</div>`):

```tsx
            <Button variant="outline" onClick={() => setMessageDialog(true)}>
              <Send className="mr-2 h-4 w-4" />
              Отправить сообщение
            </Button>
```

Add the dialog right before the final closing `</div>` of the component's returned JSX:

```tsx
      <Dialog open={messageDialog} onOpenChange={setMessageDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Отправить сообщение пользователю</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Заголовок</Label>
              <Input value={msgTitle} onChange={(e) => setMsgTitle(e.target.value)} maxLength={200} />
            </div>
            <div className="space-y-2">
              <Label>Текст</Label>
              <Textarea value={msgBody} onChange={(e) => setMsgBody(e.target.value)} rows={4} maxLength={1000} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMessageDialog(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => sendMessageMutation.mutate()}
              disabled={!msgTitle.trim() || !msgBody.trim() || sendMessageMutation.isPending}
            >
              <Send className="mr-2 h-4 w-4" />
              Отправить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
```

- [ ] **Step 11: Repeat the same button+dialog on the store detail page**

Apply the identical pattern from Step 10 to `admin/app/(admin)/stores/[id]/page.tsx`, with one change: the mutation body sends `{ storeId: id, title: msgTitle, body: msgBody }` instead of `userId`. Match whatever existing button-row markup that file already has (follow its own existing `<div className="flex gap-3">`-style action row, the same way Step 10 did for the user page).

- [ ] **Step 12: Manual verification**

Run the admin dev server (`cd admin && npm run dev`), open a user detail page, click "Отправить сообщение", fill title/body, send, confirm the success toast appears and no console errors. Repeat on a store detail page.

- [ ] **Step 13: Commit frontend**

```bash
git add admin/app/\(admin\)/users/\[id\]/page.tsx admin/app/\(admin\)/stores/\[id\]/page.tsx
git commit -m "feat(admin): add send-direct-message UI on user and store detail pages"
```

---

## Task 2: Ручное создание платежа (manual payment)

**Files:**
- Create: `api/src/modules/subscriptions/dto/admin-manual-payment.dto.ts`
- Modify: `api/src/modules/subscriptions/subscriptions.service.ts` (add `adminCreateManualPayment`)
- Modify: `api/src/modules/subscriptions/subscriptions.controller.ts` (add endpoint on `AdminSubscriptionsController`)
- Test: `api/src/modules/subscriptions/subscriptions.manual-payment.spec.ts`
- Modify: `admin/app/(admin)/subscriptions/page.tsx` (add "Внести платёж вручную" action)

- [ ] **Step 1: Write the DTO**

```typescript
// api/src/modules/subscriptions/dto/admin-manual-payment.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, Min, IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { PaymentMethod } from '@prisma/client';

export class AdminManualPaymentDto {
  @ApiProperty({ example: 400 })
  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  amount: number;

  @ApiProperty({ enum: PaymentMethod })
  @IsNotEmpty()
  @IsEnum(PaymentMethod)
  method: PaymentMethod;

  @ApiProperty({ example: 30, description: 'Number of days to extend the subscription by' })
  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  periodDays: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
```

- [ ] **Step 2: Write the failing test**

```typescript
// api/src/modules/subscriptions/subscriptions.manual-payment.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { SubscriptionsService } from './subscriptions.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../../common/audit/audit-log.service';

function makePrismaFake() {
  return {
    subscription: {
      findUnique: jest.fn(async () => null as any),
    },
    store: {
      findUnique: jest.fn(async () => null as any),
    },
    payment: {
      create: jest.fn(async ({ data }: any) => ({ id: 'pay-1', ...data })),
    },
    $transaction: jest.fn(async (ops: any[]) => Promise.all(ops)),
  };
}

describe('SubscriptionsService — adminCreateManualPayment', () => {
  let service: SubscriptionsService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock };
  let audit: { record: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendPush: jest.fn(async () => undefined) };
    audit = { record: jest.fn(async () => undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: AuditLogService, useValue: audit },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('throws NotFoundException when subscription does not exist', async () => {
    (prisma.subscription.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.adminCreateManualPayment(
        'sub-missing',
        { amount: 400, method: 'CASH', periodDays: 30 } as any,
        'admin-1',
      ),
    ).rejects.toThrow(NotFoundException);
  });

  it('extends currentPeriodEnd by periodDays from the later of now/currentPeriodEnd, and notifies the owner', async () => {
    const currentPeriodEnd = new Date('2099-01-01');
    (prisma.subscription.findUnique as jest.Mock).mockResolvedValue({
      id: 'sub-1',
      storeId: 'store-1',
      currentPeriodEnd,
    });
    (prisma.store.findUnique as jest.Mock).mockResolvedValue({
      ownerId: 'owner-1',
      name: 'Магазин',
    });

    const result = await service.adminCreateManualPayment(
      'sub-1',
      { amount: 400, method: 'CASH', periodDays: 30, notes: 'Наличные в офисе' } as any,
      'admin-1',
    );

    const expectedEnd = new Date(currentPeriodEnd);
    expectedEnd.setDate(expectedEnd.getDate() + 30);

    expect((result.subscription as any).currentPeriodEnd.getTime()).toBe(expectedEnd.getTime());
    expect(notifications.sendPush).toHaveBeenCalledWith(
      'owner-1',
      expect.any(String),
      expect.any(String),
      'SUBSCRIPTION_MANUAL_PAYMENT',
      'store-1',
    );
    expect(audit.record).toHaveBeenCalledWith(
      'admin-1',
      'subscription.manual-payment',
      'subscription',
      'sub-1',
      expect.objectContaining({ amount: 400, periodDays: 30 }),
    );
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd api && npx jest subscriptions.manual-payment.spec.ts`
Expected: FAIL — `service.adminCreateManualPayment is not a function`

- [ ] **Step 4: Implement `adminCreateManualPayment`**

In `api/src/modules/subscriptions/subscriptions.service.ts`, add the import:

```typescript
import { AdminManualPaymentDto } from './dto/admin-manual-payment.dto';
```

Add this method right after `adminApprovePayment` closes:

```typescript
  async adminCreateManualPayment(
    subscriptionId: string,
    dto: AdminManualPaymentDto,
    reviewedBy: string,
  ) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });
    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    const now = new Date();
    const base =
      subscription.currentPeriodEnd > now ? subscription.currentPeriodEnd : now;
    const newPeriodEnd = new Date(base);
    newPeriodEnd.setDate(newPeriodEnd.getDate() + dto.periodDays);

    const [payment, updatedSubscription] = await this.prisma.$transaction([
      this.prisma.payment.create({
        data: {
          subscriptionId,
          amount: dto.amount,
          currency: 'TJS',
          method: dto.method,
          status: 'APPROVED',
          note: dto.notes,
          reviewedAt: now,
          reviewedBy,
        },
      }),
      this.prisma.subscription.update({
        where: { id: subscriptionId },
        data: {
          status: 'ACTIVE',
          currentPeriodEnd: newPeriodEnd,
          currentPeriodStart: now,
        },
      }),
    ]);

    const store = await this.prisma.store.findUnique({
      where: { id: updatedSubscription.storeId },
      select: { ownerId: true, name: true },
    });

    if (store) {
      await this.notificationsService.sendPush(
        store.ownerId,
        'Подписка продлена',
        `Платёж внесён администратором. Подписка активна до ${newPeriodEnd.toLocaleDateString('ru-RU')}.`,
        'SUBSCRIPTION_MANUAL_PAYMENT',
        updatedSubscription.storeId,
      );
    }

    void this.audit.record(
      reviewedBy,
      'subscription.manual-payment',
      'subscription',
      updatedSubscription.id,
      {
        paymentId: payment.id,
        amount: dto.amount,
        periodDays: dto.periodDays,
      },
    );

    return { payment, subscription: updatedSubscription };
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd api && npx jest subscriptions.manual-payment.spec.ts`
Expected: PASS (2 tests)

- [ ] **Step 6: Add the controller endpoint**

In `api/src/modules/subscriptions/subscriptions.controller.ts`, add the import:

```typescript
import { AdminManualPaymentDto } from './dto/admin-manual-payment.dto';
```

Add this method inside `AdminSubscriptionsController`, next to `approvePayment`:

```typescript
  @SkipThrottle()
  @Post(':id/manual-payment')
  @ApiOperation({ summary: 'Admin: record a manual payment (cash/transfer received outside the app) and extend the subscription' })
  manualPayment(
    @Param('id') id: string,
    @Body() dto: AdminManualPaymentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.subscriptionsService.adminCreateManualPayment(id, dto, userId);
  }
```

(If `Post` and `Body` aren't already imported from `@nestjs/common` in this controller file, add them to the existing import statement.)

- [ ] **Step 7: Run the full subscriptions test suite**

Run: `cd api && npx jest src/modules/subscriptions`
Expected: PASS (all existing subscription specs plus the 2 new ones)

- [ ] **Step 8: Commit backend**

```bash
cd api
git add src/modules/subscriptions/dto/admin-manual-payment.dto.ts \
        src/modules/subscriptions/subscriptions.service.ts \
        src/modules/subscriptions/subscriptions.controller.ts \
        src/modules/subscriptions/subscriptions.manual-payment.spec.ts
git commit -m "feat(subscriptions): add admin manual-payment endpoint that extends the subscription period"
```

- [ ] **Step 9: Add "Внести платёж вручную" to the subscriptions admin page**

Open `admin/app/(admin)/subscriptions/page.tsx`, locate the existing per-row action buttons (extend/change-plan/set-discount — follow whatever pattern is already there for opening a dialog against a specific subscription row). Add a new dialog following the exact same `useState`/`useMutation`/`Dialog` structure demonstrated in Task 1 Step 10, with:
- Fields: Сумма (`Input type="number"`), Способ оплаты (`Select` with `CASH`/`CARD`/`MOBILE_TRANSFER`), Период продления в днях (`Input type="number"`, default `30`), Примечание (`Textarea`, optional).
- Mutation: `api.post(`/admin/subscriptions/${subscriptionId}/manual-payment`, { amount, method, periodDays, notes })`.
- On success: `queryClient.invalidateQueries({ queryKey: ['subscriptions'] })` (match whatever query key the page already uses for its subscriptions list) + `toast.success('Платёж внесён, подписка продлена')`.

- [ ] **Step 10: Manual verification**

Run `cd admin && npm run dev`, open `/subscriptions`, click "Внести платёж вручную" on a row, submit, confirm success toast and that `currentPeriodEnd` visibly updates in the table after refetch.

- [ ] **Step 11: Commit frontend**

```bash
git add admin/app/\(admin\)/subscriptions/page.tsx
git commit -m "feat(admin): add manual payment dialog to subscriptions page"
```

---

## Task 3: Экспорт в Excel

**Files:**
- Create: `api/src/modules/admin/admin-export.service.ts`
- Modify: `api/src/modules/admin/admin-users.controller.ts` (add `GET /admin/users/export`)
- Modify: `api/src/modules/admin/admin-stores.controller.ts` (add `GET /admin/stores/export`)
- Modify: `api/src/modules/subscriptions/subscriptions.controller.ts` (add `GET /admin/subscriptions/export`)
- Modify: `api/src/modules/admin/admin.module.ts` (register `AdminExportService`, export it for the subscriptions module to consume)
- Test: `api/src/modules/admin/admin-export.service.spec.ts`

**Design note:** admin-scoped export is a distinct data shape from the existing per-store `ExportService` (`api/src/modules/reports/export.service.ts`, which exports one store's own sales/products/customers). This new `AdminExportService` copies its ExcelJS usage pattern but queries system-wide tables filtered by the same query params the admin list endpoints already accept, reusing `AdminUsersQueryDto`/`AdminStoresQueryDto` where-building logic inline (not paginated — capped at 10000 rows, matching the existing `ExportService` convention).

- [ ] **Step 1: Write the failing test**

```typescript
// api/src/modules/admin/admin-export.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import * as ExcelJS from 'exceljs';
import { AdminExportService } from './admin-export.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    user: {
      findMany: jest.fn(async () => [
        { id: 'u1', name: 'Алишер', phone: '+992900000001', email: null, isAdmin: false, isActive: true, createdAt: new Date('2026-01-01') },
      ]),
    },
    store: {
      findMany: jest.fn(async () => [] as any[]),
    },
  };
}

describe('AdminExportService', () => {
  let service: AdminExportService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [AdminExportService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(AdminExportService);
  });

  it('exportUsers produces an xlsx buffer with one row per user, honoring the search filter', async () => {
    const buffer = await service.exportUsers({ search: 'Алишер' } as any);

    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'Алишер', mode: 'insensitive' } },
          ]),
        }),
      }),
    );

    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(buffer as any);
    const ws = wb.getWorksheet('Users');
    expect(ws?.rowCount).toBe(2); // header + 1 data row
    expect(ws?.getRow(2).getCell(1).value).toBe('Алишер');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && npx jest admin-export.service.spec.ts`
Expected: FAIL — cannot find module `./admin-export.service`

- [ ] **Step 3: Implement `AdminExportService`**

```typescript
// api/src/modules/admin/admin-export.service.ts
import { Injectable } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';
import { AdminStoresQueryDto } from './dto/admin-stores-query.dto';

const EXPORT_ROW_CAP = 10000;

@Injectable()
export class AdminExportService {
  constructor(private prisma: PrismaService) {}

  async exportUsers(query: AdminUsersQueryDto): Promise<Buffer> {
    const where: Prisma.UserWhereInput = {};
    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { phone: { contains: query.search, mode: 'insensitive' } },
        { email: { contains: query.search, mode: 'insensitive' } },
      ];
    }
    if (query.isAdmin !== undefined) where.isAdmin = query.isAdmin;
    if (query.isActive !== undefined) where.isActive = query.isActive;

    const users = await this.prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_ROW_CAP,
      select: {
        name: true,
        phone: true,
        email: true,
        isAdmin: true,
        isActive: true,
        createdAt: true,
      },
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Users');
    ws.columns = [
      { header: 'Name', key: 'name', width: 24 },
      { header: 'Phone', key: 'phone', width: 18 },
      { header: 'Email', key: 'email', width: 24 },
      { header: 'Admin', key: 'isAdmin', width: 10 },
      { header: 'Active', key: 'isActive', width: 10 },
      { header: 'Created', key: 'createdAt', width: 20 },
    ];
    for (const u of users) {
      ws.addRow({
        name: u.name ?? '',
        phone: u.phone,
        email: u.email ?? '',
        isAdmin: u.isAdmin,
        isActive: u.isActive,
        createdAt: u.createdAt.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  async exportStores(query: AdminStoresQueryDto): Promise<Buffer> {
    const where: Prisma.StoreWhereInput = {};
    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { owner: { name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }
    if (query.category) where.category = query.category;
    if (query.isActive !== undefined) where.isActive = query.isActive;
    if (query.plan) where.subscription = { plan: query.plan };

    const stores = await this.prisma.store.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_ROW_CAP,
      select: {
        name: true,
        category: true,
        isActive: true,
        createdAt: true,
        owner: { select: { name: true, phone: true } },
        subscription: { select: { plan: true, status: true } },
      },
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Stores');
    ws.columns = [
      { header: 'Name', key: 'name', width: 28 },
      { header: 'Category', key: 'category', width: 16 },
      { header: 'Owner', key: 'ownerName', width: 24 },
      { header: 'Owner phone', key: 'ownerPhone', width: 18 },
      { header: 'Plan', key: 'plan', width: 12 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Active', key: 'isActive', width: 10 },
      { header: 'Created', key: 'createdAt', width: 20 },
    ];
    for (const s of stores) {
      ws.addRow({
        name: s.name,
        category: s.category ?? '',
        ownerName: s.owner?.name ?? '',
        ownerPhone: s.owner?.phone ?? '',
        plan: s.subscription?.plan ?? '',
        status: s.subscription?.status ?? '',
        isActive: s.isActive,
        createdAt: s.createdAt.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  async exportSubscriptions(filters: { plan?: string; status?: string }): Promise<Buffer> {
    const where: Prisma.SubscriptionWhereInput = {};
    if (filters.plan) where.plan = filters.plan as any;
    if (filters.status) where.status = filters.status as any;

    const subs = await this.prisma.subscription.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_ROW_CAP,
      select: {
        plan: true,
        status: true,
        currentPeriodStart: true,
        currentPeriodEnd: true,
        createdAt: true,
        store: { select: { name: true, owner: { select: { name: true, phone: true } } } },
      },
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Subscriptions');
    ws.columns = [
      { header: 'Store', key: 'storeName', width: 28 },
      { header: 'Owner', key: 'ownerName', width: 24 },
      { header: 'Owner phone', key: 'ownerPhone', width: 18 },
      { header: 'Plan', key: 'plan', width: 12 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Period start', key: 'periodStart', width: 20 },
      { header: 'Period end', key: 'periodEnd', width: 20 },
    ];
    for (const s of subs) {
      ws.addRow({
        storeName: s.store?.name ?? '',
        ownerName: s.store?.owner?.name ?? '',
        ownerPhone: s.store?.owner?.phone ?? '',
        plan: s.plan,
        status: s.status,
        periodStart: s.currentPeriodStart.toISOString(),
        periodEnd: s.currentPeriodEnd.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && npx jest admin-export.service.spec.ts`
Expected: PASS

- [ ] **Step 5: Register `AdminExportService` in the module and export it**

In `api/src/modules/admin/admin.module.ts`:

```typescript
import { AdminExportService } from './admin-export.service';
```

```typescript
  providers: [AdminService, AuditInterceptor, AdminExportService],
  exports: [AdminService, AdminExportService],
```

`SubscriptionsModule` needs to import `AdminModule` to use `AdminExportService` in its controller — check `api/src/modules/subscriptions/subscriptions.module.ts` and add `AdminModule` to its `imports` array if not already present (verify there's no circular-import issue first: `AdminModule` currently imports `NotificationsModule` and `StoresModule`, not `SubscriptionsModule`, so this is safe).

- [ ] **Step 6: Add the export endpoints**

In `api/src/modules/admin/admin-users.controller.ts`, add the import and inject the new service:

```typescript
import { AdminExportService } from './admin-export.service';
```

```typescript
  constructor(
    private readonly adminService: AdminService,
    private readonly exportService: AdminExportService,
  ) {}
```

Add this endpoint (place it right after the `listUsers` method):

```typescript
  @Get('export')
  @ApiOperation({ summary: 'Export the current filtered user list as .xlsx' })
  async exportUsers(@Query() query: AdminUsersQueryDto, @Res() res: Response) {
    const buffer = await this.exportService.exportUsers(query);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="dukonpro-users-${new Date().toISOString().slice(0, 10)}.xlsx"`,
    });
    res.send(buffer);
  }
```

Add `Res` to the `@nestjs/common` import list and add `import { Response } from 'express';` at the top of the file.

Apply the identical pattern (adjusting entity name) to `admin-stores.controller.ts` (`GET /admin/stores/export` calling `exportService.exportStores(query)`), injecting `AdminExportService` the same way.

For subscriptions, in `api/src/modules/subscriptions/subscriptions.controller.ts`, inject `AdminExportService` into `AdminSubscriptionsController`'s constructor and add:

```typescript
  @Get('export')
  @ApiOperation({ summary: 'Export the current filtered subscription list as .xlsx' })
  async exportSubscriptions(
    @Query('plan') plan: string | undefined,
    @Query('status') status: string | undefined,
    @Res() res: Response,
  ) {
    const buffer = await this.exportService.exportSubscriptions({ plan, status });
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="dukonpro-subscriptions-${new Date().toISOString().slice(0, 10)}.xlsx"`,
    });
    res.send(buffer);
  }
```

- [ ] **Step 7: Run the full backend test suite for touched modules**

Run: `cd api && npx jest src/modules/admin src/modules/subscriptions`
Expected: PASS

- [ ] **Step 8: Commit backend**

```bash
cd api
git add src/modules/admin/admin-export.service.ts \
        src/modules/admin/admin-export.service.spec.ts \
        src/modules/admin/admin.module.ts \
        src/modules/admin/admin-users.controller.ts \
        src/modules/admin/admin-stores.controller.ts \
        src/modules/subscriptions/subscriptions.controller.ts \
        src/modules/subscriptions/subscriptions.module.ts
git commit -m "feat(admin): add xlsx export for users, stores, subscriptions honoring current list filters"
```

- [ ] **Step 9: Add "Экспорт" buttons to the three admin list pages**

On each of `admin/app/(admin)/users/page.tsx`, `admin/app/(admin)/stores/page.tsx`, `admin/app/(admin)/subscriptions/page.tsx`, add a button next to the existing search/filter controls:

```tsx
<Button
  variant="outline"
  onClick={() => {
    const params = new URLSearchParams(/* reuse this page's existing filter state variables */);
    window.location.href = `${process.env.NEXT_PUBLIC_API_URL}/admin/<entity>/export?${params.toString()}`;
  }}
>
  <Download className="mr-2 h-4 w-4" />
  Экспорт
</Button>
```

Replace `<entity>` with `users`/`stores`/`subscriptions` and populate `params` from whatever filter state variables that specific page already tracks (e.g. `search`, `isAdmin` for users; `search`, `category`, `plan` for stores). Import `Download` from `lucide-react`.

**Note:** exports go through `window.location.href` (full navigation), not the `api` client wrapper, because the response is a binary file download, not JSON — this bypasses whatever auth-header injection `lib/api.ts` does for XHR/fetch calls. Before wiring this, check `admin/lib/api.ts` for how the admin JWT is attached (cookie vs `Authorization` header). If it's an httpOnly cookie sent automatically by the browser, direct navigation works as-is. If it's a bearer token attached only in JS (not a cookie), the export route needs to go through `admin/app/api/proxy/[...path]/route.ts` (the existing proxy) instead of hitting the NestJS API's public origin directly, so the browser's cookie-based session which the proxy layer uses is preserved on the request.

- [ ] **Step 10: Manual verification**

Run `cd admin && npm run dev`, open `/users`, apply a search filter, click "Экспорт", confirm a `.xlsx` file downloads and that opening it shows only the filtered rows. Repeat for `/stores` and `/subscriptions`.

- [ ] **Step 11: Commit frontend**

```bash
git add admin/app/\(admin\)/users/page.tsx admin/app/\(admin\)/stores/page.tsx admin/app/\(admin\)/subscriptions/page.tsx
git commit -m "feat(admin): add Excel export buttons to users, stores, subscriptions list pages"
```

---

## Task 4: Diff «было → стало» в аудит-логе

**Files:**
- Modify: `api/src/common/interceptors/audit.interceptor.ts`
- Test: `api/src/common/interceptors/audit.interceptor.spec.ts` (new file — none exists yet for this interceptor)
- Modify: `admin/app/(admin)/audit-log/page.tsx` (update `ExpandableDetails` to render diffs)

- [ ] **Step 1: Write the failing test**

```typescript
// api/src/common/interceptors/audit.interceptor.spec.ts
import 'reflect-metadata';
import { of } from 'rxjs';
import { AuditInterceptor } from './audit.interceptor';
import { PrismaService } from '../../prisma/prisma.service';
import { CallHandler, ExecutionContext } from '@nestjs/common';

function makeContext(overrides: {
  method: string;
  url: string;
  routePath?: string;
  params?: Record<string, string>;
  body?: any;
  user?: { id: string };
}): ExecutionContext {
  const request = {
    method: overrides.method,
    url: overrides.url,
    route: { path: overrides.routePath ?? overrides.url },
    params: overrides.params ?? {},
    body: overrides.body ?? {},
    user: overrides.user,
    ip: '127.0.0.1',
    headers: {},
  };
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as any;
}

function makeCallHandler(response: any): CallHandler {
  return { handle: () => of(response) };
}

describe('AuditInterceptor — before/after diff', () => {
  let prisma: { user: any; subscriptionPlanConfig: any; auditLog: { create: jest.Mock } };
  let interceptor: AuditInterceptor;

  beforeEach(() => {
    prisma = {
      user: { findUnique: jest.fn() },
      subscriptionPlanConfig: { findUnique: jest.fn() },
      auditLog: { create: jest.fn(async () => undefined) },
    };
    interceptor = new AuditInterceptor(prisma as unknown as PrismaService);
  });

  it('captures before and after snapshots for an UPDATE on a known entity', (done) => {
    (prisma.user.findUnique as jest.Mock)
      .mockResolvedValueOnce({ id: 'u1', isAdmin: false })
      .mockResolvedValueOnce({ id: 'u1', isAdmin: true });

    const context = makeContext({
      method: 'PUT',
      url: '/admin/users/u1/toggle-admin',
      routePath: '/admin/users/:id/toggle-admin',
      params: { id: 'u1' },
      user: { id: 'admin-1' },
    });

    interceptor.intercept(context, makeCallHandler({ id: 'u1', isAdmin: true })).subscribe({
      complete: () => {
        setImmediate(() => {
          expect(prisma.auditLog.create).toHaveBeenCalledWith(
            expect.objectContaining({
              data: expect.objectContaining({
                details: {
                  before: { id: 'u1', isAdmin: false },
                  after: { id: 'u1', isAdmin: true },
                },
              }),
            }),
          );
          done();
        });
      },
    });
  });

  it('uses the plan config pkField "plan" (not "id") when capturing subscription-plan snapshots', (done) => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock)
      .mockResolvedValueOnce({ plan: 'START', maxProducts: 500 })
      .mockResolvedValueOnce({ plan: 'START', maxProducts: 600 });

    const context = makeContext({
      method: 'PUT',
      url: '/admin/plans/START',
      routePath: '/admin/plans/:plan',
      params: { plan: 'START' },
      user: { id: 'admin-1' },
    });

    interceptor.intercept(context, makeCallHandler({ plan: 'START', maxProducts: 600 })).subscribe({
      complete: () => {
        setImmediate(() => {
          expect(prisma.subscriptionPlanConfig.findUnique).toHaveBeenCalledWith({
            where: { plan: 'START' },
          });
          expect(prisma.auditLog.create).toHaveBeenCalledWith(
            expect.objectContaining({
              data: expect.objectContaining({
                details: {
                  before: { plan: 'START', maxProducts: 500 },
                  after: { plan: 'START', maxProducts: 600 },
                },
              }),
            }),
          );
          done();
        });
      },
    });
  });

  it('falls back to the response body as "after" (and null "before") for CREATE routes with no entityId', (done) => {
    const context = makeContext({
      method: 'POST',
      url: '/admin/users',
      routePath: '/admin/users',
      params: {},
      body: { name: 'Новый', phone: '+992900000009' },
      user: { id: 'admin-1' },
    });

    const responseBody = { id: 'u-new', name: 'Новый' };

    interceptor.intercept(context, makeCallHandler(responseBody)).subscribe({
      complete: () => {
        setImmediate(() => {
          expect(prisma.auditLog.create).toHaveBeenCalledWith(
            expect.objectContaining({
              data: expect.objectContaining({
                details: {
                  before: null,
                  after: responseBody,
                },
              }),
            }),
          );
          done();
        });
      },
    });
  });

  it('redacts sensitive fields inside both before and after', (done) => {
    (prisma.user.findUnique as jest.Mock)
      .mockResolvedValueOnce({ id: 'u1', password: 'old-hash' })
      .mockResolvedValueOnce({ id: 'u1', password: 'new-hash' });

    const context = makeContext({
      method: 'PUT',
      url: '/admin/users/u1/block',
      routePath: '/admin/users/:id/block',
      params: { id: 'u1' },
      user: { id: 'admin-1' },
    });

    interceptor.intercept(context, makeCallHandler({ id: 'u1' })).subscribe({
      complete: () => {
        setImmediate(() => {
          const call = (prisma.auditLog.create as jest.Mock).mock.calls[0][0];
          expect(call.data.details.before.password).toBe('[REDACTED]');
          expect(call.data.details.after.password).toBe('[REDACTED]');
          done();
        });
      },
    });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && npx jest audit.interceptor.spec.ts`
Expected: FAIL — current interceptor writes `details: this.redact(request.body)`, a flat shape, not `{before, after}`

- [ ] **Step 3: Rewrite `AuditInterceptor`**

Replace the full contents of `api/src/common/interceptors/audit.interceptor.ts`:

```typescript
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

// Field names redacted from audit_log.details before persisting. Keyed by
// exact property name (not path) — request bodies in this app are shallow
// DTOs, so a top-level check is sufficient today. Extend this set rather
// than adding per-route special-casing if a new sensitive field shows up.
const SENSITIVE_FIELDS = new Set([
  'password',
  'newPassword',
  'currentPassword',
  'oldPassword',
  'token',
  'accessToken',
  'refreshToken',
]);

// Maps the entityType string derived from the route (admin/users/:id ->
// "users") to the Prisma delegate + primary-key field name needed to read
// a before/after snapshot. Only entities admins actually mutate through
// these routes need an entry here — anything else falls back to using the
// response body as "after" with a null "before" (see CREATE-route handling
// below), which is correct behavior, not a gap.
const ENTITY_MODELS: Record<string, { model: string; pkField: string }> = {
  users: { model: 'user', pkField: 'id' },
  stores: { model: 'store', pkField: 'id' },
  subscriptions: { model: 'subscription', pkField: 'id' },
  plans: { model: 'subscriptionPlanConfig', pkField: 'plan' },
};

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const method: string = request.method;

    const isAdminRoute: boolean =
      (request.url as string).includes('/admin/') ||
      (request.url as string).startsWith('/admin');

    const shouldAudit =
      isAdminRoute && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method);

    if (!shouldAudit) {
      return next.handle();
    }

    const routePath: string = request.route?.path ?? request.url ?? '';
    const entityType = this.deriveEntityType(routePath);
    const entityId: string | undefined =
      request.params?.id ?? request.params?.plan ?? undefined;

    const beforeSnapshot = this.captureSnapshot(entityType, entityId);

    return next.handle().pipe(
      tap((response) => {
        const userId: string = request.user?.id ?? 'unknown';
        const action = this.deriveAction(routePath, method);
        const ip: string =
          request.ip ?? request.headers?.['x-forwarded-for'] ?? undefined;

        const afterSnapshot = entityId
          ? this.captureSnapshot(entityType, entityId)
          : Promise.resolve(response ?? request.body);

        // Fire-and-forget — never block the response
        Promise.all([beforeSnapshot, afterSnapshot])
          .then(([before, after]) =>
            this.prisma.auditLog.create({
              data: {
                userId,
                action,
                entityType,
                entityId,
                details: {
                  before: this.redactObject(before),
                  after: this.redactObject(after),
                },
                ip,
              },
            }),
          )
          .catch(() => {
            // silently ignore audit write errors
          });
      }),
    );
  }

  private async captureSnapshot(
    entityType: string,
    entityId?: string,
  ): Promise<Record<string, unknown> | null> {
    const config = ENTITY_MODELS[entityType];
    if (!config || !entityId) return null;
    try {
      const delegate = (this.prisma as any)[config.model];
      return await delegate.findUnique({ where: { [config.pkField]: entityId } });
    } catch {
      return null;
    }
  }

  // Shallow-clones an object and replaces any top-level sensitive field
  // with a fixed marker, so the audit trail records that a value was
  // present without persisting the value itself. Applied independently to
  // both the "before" and "after" snapshots.
  private redactObject(obj: unknown): any {
    if (!obj || typeof obj !== 'object') return obj;
    const clone: Record<string, unknown> = {
      ...(obj as Record<string, unknown>),
    };
    for (const key of Object.keys(clone)) {
      if (SENSITIVE_FIELDS.has(key)) {
        clone[key] = '[REDACTED]';
      }
    }
    return clone;
  }

  private deriveAction(routePath: string, method: string): string {
    const segment = routePath.split('/').filter(Boolean).slice(0, 3).join('/');
    const methodMap: Record<string, string> = {
      POST: 'CREATE',
      PUT: 'UPDATE',
      PATCH: 'UPDATE',
      DELETE: 'DELETE',
    };
    return `${methodMap[method] ?? method}:${segment}`;
  }

  private deriveEntityType(routePath: string): string {
    const parts = routePath.split('/').filter(Boolean);
    // admin/users/:id -> users, admin/stores/:id/suspend -> stores
    return parts[1] ?? parts[0] ?? 'unknown';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && npx jest audit.interceptor.spec.ts`
Expected: PASS (4 tests)

- [ ] **Step 5: Run the full backend suite to check nothing else depended on the old flat `details` shape**

Run: `cd api && npx jest`
Expected: PASS. If any other spec asserts on `details` being the raw request body (flat), update that assertion to the new `{before, after}` shape — do not change the interceptor to accommodate an outdated test.

- [ ] **Step 6: Commit backend**

```bash
cd api
git add src/common/interceptors/audit.interceptor.ts src/common/interceptors/audit.interceptor.spec.ts
git commit -m "feat(audit): capture before/after snapshots in admin audit log instead of raw request body"
```

- [ ] **Step 7: Update `ExpandableDetails` in the audit-log page to render diffs**

In `admin/app/(admin)/audit-log/page.tsx`, replace the `ExpandableDetails` function (currently right after the `ACTIONS` array) with:

```tsx
function getChangedKeys(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
): string[] {
  const keys = new Set([
    ...Object.keys(before ?? {}),
    ...Object.keys(after ?? {}),
  ]);
  const changed: string[] = [];
  for (const key of keys) {
    if (JSON.stringify(before?.[key]) !== JSON.stringify(after?.[key])) {
      changed.push(key);
    }
  }
  return changed;
}

function formatValue(value: unknown): string {
  if (value == null) return '—';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function ExpandableDetails({ details }: { details?: unknown }) {
  const [expanded, setExpanded] = useState(false);
  if (details == null) return <span className="text-muted-foreground text-xs">—</span>;

  const isDiffShape =
    typeof details === 'object' &&
    details !== null &&
    ('before' in (details as object) || 'after' in (details as object));

  if (isDiffShape) {
    const { before, after } = details as {
      before: Record<string, unknown> | null;
      after: Record<string, unknown> | null;
    };
    const changedKeys = getChangedKeys(before, after);

    if (changedKeys.length === 0) {
      return <span className="text-muted-foreground text-xs">Без изменений</span>;
    }

    return (
      <div className="max-w-xs">
        <button
          onClick={(e) => { e.stopPropagation(); setExpanded(!expanded); }}
          className="flex items-start gap-1 text-xs text-muted-foreground hover:text-foreground"
        >
          {expanded ? <ChevronDown className="h-3 w-3 mt-0.5 shrink-0" /> : <ChevronRight className="h-3 w-3 mt-0.5 shrink-0" />}
          {!expanded && <span>{changedKeys.length} изм.</span>}
        </button>
        {expanded && (
          <div className="mt-1 space-y-1 font-mono text-xs">
            {changedKeys.map((key) => (
              <div key={key} className="flex flex-wrap gap-1">
                <span className="text-muted-foreground">{key}:</span>
                <span className="text-red-600 line-through">{formatValue(before?.[key])}</span>
                <span>→</span>
                <span className="text-green-700">{formatValue(after?.[key])}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  // Legacy flat format — records written before this feature shipped
  const text = typeof details === 'string' ? details : JSON.stringify(details, null, 2);
  if (!text) return <span className="text-muted-foreground text-xs">—</span>;
  const short = text.length > 60 ? text.slice(0, 60) + '...' : text;

  return (
    <div className="max-w-xs">
      <button
        onClick={(e) => { e.stopPropagation(); setExpanded(!expanded); }}
        className="flex items-start gap-1 text-xs text-muted-foreground hover:text-foreground"
      >
        {expanded ? <ChevronDown className="h-3 w-3 mt-0.5 shrink-0" /> : <ChevronRight className="h-3 w-3 mt-0.5 shrink-0" />}
        <pre className="whitespace-pre-wrap font-mono text-left">
          {expanded ? text : short}
        </pre>
      </button>
    </div>
  );
}
```

Also update the free-text search's `detailsText` extraction (in `AuditLogPage`, the `filtered` computation) to search inside the new shape too — change:

```tsx
    const detailsText =
      typeof l.details === 'string'
        ? l.details
        : l.details != null
          ? JSON.stringify(l.details)
          : '';
```

This line already calls `JSON.stringify(l.details)` for any non-string object, which naturally covers the new `{before, after}` shape too (stringifies the whole thing including nested keys) — **no change needed here**, leave as-is.

- [ ] **Step 8: Manual verification**

Run `cd admin && npm run dev`, perform an admin mutation (e.g. toggle-admin on a test user), open `/audit-log`, confirm the new row shows "N изм." and expands to a field-by-field before→after diff. Confirm an old pre-existing audit-log row (written before this change) still renders as raw JSON without crashing.

- [ ] **Step 9: Commit frontend**

```bash
git add admin/app/\(admin\)/audit-log/page.tsx
git commit -m "feat(admin): render before/after diff in audit log, falling back to raw JSON for legacy records"
```

---

## Task 5: In-app баннеры

**Files:**
- Modify: `api/prisma/schema.prisma` (add `Banner` model)
- Create: Prisma migration (via `npx prisma migrate dev`)
- Modify: `api/src/modules/admin/admin.service.ts` (generalize `_resolveAnnouncementAudience` → `_resolveAudience`, add banner CRUD methods)
- Create: `api/src/modules/admin/dto/create-banner.dto.ts`
- Create: `api/src/modules/admin/admin-banners.controller.ts`
- Create: `api/src/modules/banners/banners.module.ts`, `api/src/modules/banners/banners.controller.ts`, `api/src/modules/banners/banners.service.ts` (public store-facing endpoint)
- Modify: `api/src/modules/admin/admin.module.ts`
- Test: `api/src/modules/admin/admin-banners.service.spec.ts`, `api/src/modules/banners/banners.service.spec.ts`
- Create: `admin/app/(admin)/banners/page.tsx`
- Modify: `admin/components/sidebar.tsx` (add nav entry)
- Modify (Flutter): `app/lib/presentation/pages/home/home_page.dart` (or wherever the Home screen root widget lives — locate via `grep -rn "class HomePage" app/lib`) to show the banner
- Create (Flutter): `app/lib/presentation/widgets/home/active_banner.dart`

- [ ] **Step 1: Add the `Banner` model to the schema**

In `api/prisma/schema.prisma`, add (near `Announcement`, find it via `grep -n "^model Announcement" api/prisma/schema.prisma` first and place `Banner` directly after it for locality):

```prisma
model Banner {
  id           String               @id @default(uuid())
  title        String
  body         String
  targetPlan   SubscriptionPlan?
  targetStatus SubscriptionStatus?
  startDate    DateTime
  endDate      DateTime
  active       Boolean              @default(true)
  createdAt    DateTime             @default(now())

  @@map("banners")
}
```

- [ ] **Step 2: Generate and run the migration**

Run: `cd api && npx prisma migrate dev --name add_banners`
Expected: Migration file created under `api/prisma/migrations/`, applies cleanly against the dev database, `npx prisma generate` runs automatically as part of `migrate dev` and regenerates the Prisma client with `prisma.banner`.

- [ ] **Step 3: Generalize the audience resolver**

In `api/src/modules/admin/admin.service.ts`, rename `_resolveAnnouncementAudience` to `_resolveAudience` and change its parameter type from `CreateAnnouncementDto` to a narrower shape both announcements and banners can supply:

```typescript
  private async _resolveAudience(
    filter: { targetPlan?: SubscriptionPlan; targetStatus?: SubscriptionStatus },
  ): Promise<
    Array<{
      userId: string;
      storeId: string;
      vars: AnnouncementVars;
    }>
  > {
    const stores = await this.prisma.store.findMany({
      where: {
        isActive: true,
        owner: { isActive: true, isAdmin: false },
        ...(filter.targetPlan || filter.targetStatus
          ? {
              subscription: {
                ...(filter.targetPlan && { plan: filter.targetPlan }),
                ...(filter.targetStatus && { status: filter.targetStatus }),
              },
            }
          : {}),
      },
      include: {
        owner: { select: { id: true, name: true, phone: true } },
        subscription: { select: { plan: true, currentPeriodEnd: true } },
      },
    });

    const seen = new Set<string>();
    const audience: Array<{ userId: string; storeId: string; vars: AnnouncementVars }> = [];

    for (const store of stores) {
      if (seen.has(store.ownerId)) continue;
      seen.add(store.ownerId);

      audience.push({
        userId: store.ownerId,
        storeId: store.id,
        vars: {
          user: { name: store.owner.name, phone: store.owner.phone ?? '' },
          store: {
            name: store.name,
            currency: store.currency,
            subscription: {
              plan: store.subscription?.plan ?? 'START',
              currentPeriodEnd: store.subscription?.currentPeriodEnd
                ? store.subscription.currentPeriodEnd.toISOString().slice(0, 10)
                : '—',
            },
          },
        },
      });
    }

    return audience;
  }
```

Update the two call sites (`createAnnouncement`, `previewAnnouncement`) from `this._resolveAnnouncementAudience(dto)` to `this._resolveAudience(dto)` (the DTO already has `targetPlan`/`targetStatus`, structurally compatible with the new narrower parameter type).

- [ ] **Step 4: Write the failing test for banner CRUD + active-banner resolution**

```typescript
// api/src/modules/admin/admin-banners.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake() {
  return {
    banner: {
      create: jest.fn(async ({ data }: any) => ({ id: 'b1', ...data })),
      findMany: jest.fn(async () => [] as any[]),
      update: jest.fn(async ({ where, data }: any) => ({ id: where.id, ...data })),
    },
  };
}

describe('AdminService — banners', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('createBanner persists the row as given', async () => {
    const dto = {
      title: 'Скидка',
      body: '20% на все товары',
      targetPlan: 'PREMIUM' as const,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    };

    const result = await service.createBanner(dto as any);

    expect(prisma.banner.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        title: 'Скидка',
        body: '20% на все товары',
        targetPlan: 'PREMIUM',
      }),
    });
    expect((result as any).id).toBe('b1');
  });
});
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd api && npx jest admin-banners.service.spec.ts`
Expected: FAIL — `service.createBanner is not a function`

- [ ] **Step 6: Implement banner CRUD in `AdminService`**

Add the import:

```typescript
import { CreateBannerDto } from './dto/create-banner.dto';
```

Add this section right after `// ============ ANNOUNCEMENTS ============` closes:

```typescript
  // ============ BANNERS ============

  async createBanner(dto: CreateBannerDto) {
    return this.prisma.banner.create({
      data: {
        title: dto.title,
        body: dto.body,
        targetPlan: dto.targetPlan,
        targetStatus: dto.targetStatus,
        startDate: new Date(dto.startDate),
        endDate: new Date(dto.endDate),
      },
    });
  }

  async listBanners() {
    return this.prisma.banner.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async setBannerActive(id: string, active: boolean) {
    return this.prisma.banner.update({ where: { id }, data: { active } });
  }
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd api && npx jest admin-banners.service.spec.ts`
Expected: PASS

- [ ] **Step 8: Write the DTO**

```typescript
// api/src/modules/admin/dto/create-banner.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsEnum, IsDateString } from 'class-validator';
import { SubscriptionPlan, SubscriptionStatus } from '@prisma/client';

export class CreateBannerDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  body: string;

  @ApiPropertyOptional({ enum: SubscriptionPlan })
  @IsOptional()
  @IsEnum(SubscriptionPlan)
  targetPlan?: SubscriptionPlan;

  @ApiPropertyOptional({ enum: SubscriptionStatus })
  @IsOptional()
  @IsEnum(SubscriptionStatus)
  targetStatus?: SubscriptionStatus;

  @ApiProperty({ example: '2026-08-01' })
  @IsDateString()
  startDate: string;

  @ApiProperty({ example: '2026-08-31' })
  @IsDateString()
  endDate: string;
}
```

- [ ] **Step 9: Write the admin controller**

```typescript
// api/src/modules/admin/admin-banners.controller.ts
import { Controller, Get, Post, Put, Body, Param, UseGuards, UseInterceptors } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';
import { AdminService } from './admin.service';
import { CreateBannerDto } from './dto/create-banner.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AuditInterceptor)
@Controller('admin/banners')
export class AdminBannersController {
  constructor(private readonly adminService: AdminService) {}

  @Post()
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @ApiOperation({ summary: 'Create a new in-app banner' })
  createBanner(@Body() dto: CreateBannerDto) {
    return this.adminService.createBanner(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List all banners' })
  listBanners() {
    return this.adminService.listBanners();
  }

  @Put(':id/active')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Toggle a banner active/inactive' })
  setBannerActive(@Param('id') id: string, @Body('active') active: boolean) {
    return this.adminService.setBannerActive(id, active);
  }
}
```

Register in `admin.module.ts` the same way as Task 1 Step 7 (import + add to `controllers` array).

- [ ] **Step 10: Write the failing test for the public "active banner" resolver**

```typescript
// api/src/modules/banners/banners.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BannersService } from './banners.service';
import { PrismaService } from '../../prisma/prisma.service';

function makePrismaFake() {
  return {
    banner: { findMany: jest.fn(async () => [] as any[]) },
    store: { findUnique: jest.fn(async () => ({ subscription: { plan: 'PREMIUM', status: 'ACTIVE' } })) },
  };
}

describe('BannersService — getActiveBanner', () => {
  let service: BannersService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [BannersService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(BannersService);
  });

  it('returns null when no banners are active/in-range', async () => {
    (prisma.banner.findMany as jest.Mock).mockResolvedValue([]);
    const result = await service.getActiveBanner('store-1');
    expect(result).toBeNull();
  });

  it('returns the most recently created matching banner when several qualify', async () => {
    (prisma.banner.findMany as jest.Mock).mockResolvedValue([
      { id: 'b-newer', title: 'Newer', createdAt: new Date('2026-07-02') },
      { id: 'b-older', title: 'Older', createdAt: new Date('2026-07-01') },
    ]);
    const result = await service.getActiveBanner('store-1');
    expect(result?.id).toBe('b-newer');
  });
});
```

- [ ] **Step 11: Run test to verify it fails**

Run: `cd api && npx jest banners.service.spec.ts`
Expected: FAIL — cannot find module `./banners.service`

- [ ] **Step 12: Implement `BannersService`, `BannersController`, `BannersModule`**

```typescript
// api/src/modules/banners/banners.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class BannersService {
  constructor(private prisma: PrismaService) {}

  async getActiveBanner(storeId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { subscription: { select: { plan: true, status: true } } },
    });
    if (!store) return null;

    const now = new Date();
    const candidates = await this.prisma.banner.findMany({
      where: {
        active: true,
        startDate: { lte: now },
        endDate: { gte: now },
        ...(store.subscription?.plan && {
          OR: [{ targetPlan: null }, { targetPlan: store.subscription.plan }],
        }),
      },
      orderBy: { createdAt: 'desc' },
    });

    const matching = candidates.filter(
      (b) => !b.targetStatus || b.targetStatus === store.subscription?.status,
    );

    return matching[0] ?? null;
  }
}
```

```typescript
// api/src/modules/banners/banners.controller.ts
import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { BannersService } from './banners.service';

@ApiTags('Banners')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/banners')
export class BannersController {
  constructor(private readonly bannersService: BannersService) {}

  @Get('active')
  @ApiOperation({ summary: 'Get the currently active banner for this store, if any' })
  getActive(@Param('storeId') storeId: string) {
    return this.bannersService.getActiveBanner(storeId);
  }
}
```

```typescript
// api/src/modules/banners/banners.module.ts
import { Module } from '@nestjs/common';
import { BannersService } from './banners.service';
import { BannersController } from './banners.controller';

@Module({
  controllers: [BannersController],
  providers: [BannersService],
})
export class BannersModule {}
```

Register `BannersModule` in the root `api/src/app.module.ts` imports array (find its existing `imports: [...]` list via `grep -n "AppModule" -A 40 api/src/app.module.ts` and add `BannersModule` alongside the other feature modules).

- [ ] **Step 13: Run test to verify it passes**

Run: `cd api && npx jest banners.service.spec.ts`
Expected: PASS

- [ ] **Step 14: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 15: Commit backend**

```bash
cd api
git add prisma/schema.prisma prisma/migrations \
        src/modules/admin/admin.service.ts \
        src/modules/admin/dto/create-banner.dto.ts \
        src/modules/admin/admin-banners.controller.ts \
        src/modules/admin/admin.module.ts \
        src/modules/admin/admin-banners.service.spec.ts \
        src/modules/banners/ \
        src/app.module.ts
git commit -m "feat(banners): add Banner model, admin CRUD, and public active-banner endpoint"
```

- [ ] **Step 16: Add the admin `/banners` page**

Create `admin/app/(admin)/banners/page.tsx` following the exact structure of `admin/app/(admin)/announcements/page.tsx` (Task grounding already has its full content): compose form (title, body, targetPlan select, targetStatus select, startDate/endDate date inputs) + `useMutation` posting to `/admin/banners` + a table listing existing banners with an active/inactive toggle `Switch` wired to `PUT /admin/banners/:id/active`. Reuse the same `Card`/`Table`/`Select`/`Dialog` component imports as the announcements page.

Add the nav entry in `admin/components/sidebar.tsx` — find the existing array of `{ href, label, icon }` entries (referenced earlier as defining the 7 sidebar sections) and add one more entry for `/banners` with an appropriate `lucide-react` icon (e.g. `Megaphone` or `Flag` — pick one not already used by another sidebar entry, verify by checking the existing imports in that file).

- [ ] **Step 17: Commit admin frontend**

```bash
git add admin/app/\(admin\)/banners/page.tsx admin/components/sidebar.tsx
git commit -m "feat(admin): add banners management page and sidebar entry"
```

- [ ] **Step 18: Add the banner widget to the Flutter Home screen**

First locate the exact Home page file: run `grep -rln "class HomePage" app/lib` to confirm the path (referenced elsewhere in this session as `app/lib/presentation/pages/home/home_page.dart` — verify before editing, do not assume).

Create the banner widget:

```dart
// app/lib/presentation/widgets/home/active_banner.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../injection.dart';

class ActiveBanner extends StatefulWidget {
  final String storeId;
  const ActiveBanner({super.key, required this.storeId});

  @override
  State<ActiveBanner> createState() => _ActiveBannerState();
}

class _ActiveBannerState extends State<ActiveBanner> {
  Map<String, dynamic>? _banner;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = sl<DioClient>();
      final response = await client.get('/stores/${widget.storeId}/banners/active');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;

      final prefs = await SharedPreferences.getInstance();
      final dismissedIds = prefs.getStringList('dismissed_banner_ids') ?? [];
      if (dismissedIds.contains(data['id'])) return;

      if (mounted) {
        setState(() => _banner = data);
      }
    } catch (_) {
      // Banner is non-critical — never block the home screen on failure.
    }
  }

  Future<void> _dismiss() async {
    if (_banner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissedIds = prefs.getStringList('dismissed_banner_ids') ?? [];
    dismissedIds.add(_banner!['id'] as String);
    await prefs.setStringList('dismissed_banner_ids', dismissedIds);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_banner == null || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg, vertical: AppConstants.spacingMd),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_banner!['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(_banner!['body'] as String, style: TextStyle(fontSize: 13, color: context.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _dismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
```

**Before wiring this in**, verify the exact DI-lookup pattern for `DioClient` (`sl<DioClient>()` is a guess based on the `sl<...>()` service-locator pattern seen elsewhere in this codebase this session — confirm the actual pattern via `grep -n "sl<DioClient>\|sl<Dio" app/lib -r` and adjust if the real accessor differs) and the exact `AppColors`/`AppConstants`/`context.textSecondary` names (already confirmed to exist and match this style from prior work this session on `delivery_list_page.dart` and others).

In the Home page's build method, insert `ActiveBanner(storeId: <the store id already in scope on that screen>)` directly below the app bar / greeting header, before the existing dashboard content.

- [ ] **Step 19: Run `flutter analyze` on the touched files**

Run: `cd app && flutter analyze lib/presentation/widgets/home/active_banner.dart lib/presentation/pages/home/home_page.dart`
Expected: No issues found.

- [ ] **Step 20: Manual verification**

Create a test banner via the admin `/banners` page targeting the tier of a test mobile account, relaunch the mobile app on that account, confirm the banner appears on Home, dismiss it, relaunch again, confirm it does not reappear (persisted in `SharedPreferences`).

- [ ] **Step 21: Commit mobile app changes**

```bash
git add app/lib/presentation/widgets/home/active_banner.dart app/lib/presentation/pages/home/home_page.dart
git commit -m "feat(mobile): show active in-app banner on Home screen with local dismiss persistence"
```

---

## Task 6: Impersonate

**Files:**
- Modify: `api/prisma/schema.prisma` (add `ImpersonationRequest` model)
- Create: Prisma migration
- Create: `api/src/modules/impersonation/impersonation.module.ts`, `impersonation.service.ts`, `impersonation-admin.controller.ts`, `impersonation.controller.ts`
- Create: `api/src/modules/impersonation/dto/respond-impersonation.dto.ts`
- Modify: `api/src/common/guards/jwt-auth.guard.ts` (surface `impersonatedBy` claim onto `request.user`, if not already passthrough — verify first)
- Modify: `api/src/common/interceptors/audit.interceptor.ts` (tag `viaImpersonation`)
- Test: `api/src/modules/impersonation/impersonation.service.spec.ts`
- Create: `admin/app/(admin)/users/[id]/page.tsx` modification (impersonate button + status polling)
- Create (Flutter): consent screen + persistent banner for active impersonation session

**Design note:** This task is the largest and most security-sensitive; it is intentionally the last task so Tasks 1–5 ship independently first. Do not start this task until Tasks 1–5 are each already committed and verified — if time runs short, stopping after Task 5 still delivers 5 complete, independently useful features.

- [ ] **Step 1: Add the `ImpersonationRequest` model**

In `api/prisma/schema.prisma`, add near `Banner`:

```prisma
model ImpersonationRequest {
  id           String    @id @default(uuid())
  adminId      String
  targetUserId String
  status       String    @default("PENDING") // PENDING | APPROVED | REJECTED | EXPIRED | ENDED
  requestedAt  DateTime  @default(now())
  respondedAt  DateTime?
  expiresAt    DateTime?
  endedAt      DateTime?

  @@index([targetUserId])
  @@map("impersonation_requests")
}
```

- [ ] **Step 2: Generate and run the migration**

Run: `cd api && npx prisma migrate dev --name add_impersonation_requests`
Expected: Applies cleanly, Prisma client regenerated with `prisma.impersonationRequest`.

- [ ] **Step 3: Write the failing test for the request→approve→token flow**

```typescript
// api/src/modules/impersonation/impersonation.service.spec.ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ImpersonationService } from './impersonation.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { JwtService } from '@nestjs/jwt';

function makePrismaFake() {
  return {
    impersonationRequest: {
      create: jest.fn(async ({ data }: any) => ({ id: 'req-1', status: 'PENDING', ...data })),
      findUnique: jest.fn(async () => null as any),
      update: jest.fn(async ({ where, data }: any) => ({ id: where.id, ...data })),
    },
    user: { findUnique: jest.fn(async () => ({ id: 'target-1' })) },
  };
}

describe('ImpersonationService', () => {
  let service: ImpersonationService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendPush: jest.Mock };
  let jwt: { sign: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendPush: jest.fn(async () => undefined) };
    jwt = { sign: jest.fn(() => 'signed-token') };
    const moduleRef = await Test.createTestingModule({
      providers: [
        ImpersonationService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: JwtService, useValue: jwt },
      ],
    }).compile();
    service = moduleRef.get(ImpersonationService);
  });

  it('request() creates a PENDING request and notifies the target user', async () => {
    const result = await service.request('admin-1', 'target-1');

    expect(prisma.impersonationRequest.create).toHaveBeenCalledWith({
      data: { adminId: 'admin-1', targetUserId: 'target-1', status: 'PENDING' },
    });
    expect(notifications.sendPush).toHaveBeenCalled();
    expect((result as any).status).toBe('PENDING');
  });

  it('respond("APPROVED") sets status, respondedAt, and a 30-minute expiresAt', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
    });

    const result = await service.respond('req-1', 'target-1', 'APPROVED');

    const updateCall = (prisma.impersonationRequest.update as jest.Mock).mock.calls[0][0];
    expect(updateCall.data.status).toBe('APPROVED');
    expect(updateCall.data.expiresAt).toBeInstanceOf(Date);
    const minutes =
      (updateCall.data.expiresAt.getTime() - updateCall.data.respondedAt.getTime()) / 60000;
    expect(minutes).toBeCloseTo(30, 0);
  });

  it('respond() throws when the responding user does not own the request', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
    });

    await expect(service.respond('req-1', 'someone-else', 'APPROVED')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('issueToken() throws when the request is not APPROVED', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'PENDING',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 60000),
    });

    await expect(service.issueToken('req-1')).rejects.toThrow(BadRequestException);
  });

  it('issueToken() throws when the approval has expired', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() - 60000),
    });

    await expect(service.issueToken('req-1')).rejects.toThrow(BadRequestException);
  });

  it('issueToken() signs a JWT carrying impersonatedBy and the impersonation request id', async () => {
    (prisma.impersonationRequest.findUnique as jest.Mock).mockResolvedValue({
      id: 'req-1',
      status: 'APPROVED',
      adminId: 'admin-1',
      targetUserId: 'target-1',
      expiresAt: new Date(Date.now() + 60000),
    });

    const token = await service.issueToken('req-1');

    expect(jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({
        sub: 'target-1',
        impersonatedBy: 'admin-1',
        impersonationRequestId: 'req-1',
      }),
      expect.objectContaining({ expiresIn: '30m' }),
    );
    expect(token).toBe('signed-token');
  });
});
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd api && npx jest impersonation.service.spec.ts`
Expected: FAIL — cannot find module `./impersonation.service`

- [ ] **Step 5: Implement `ImpersonationService`**

```typescript
// api/src/modules/impersonation/impersonation.service.ts
import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const IMPERSONATION_SESSION_MINUTES = 30;

@Injectable()
export class ImpersonationService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private jwt: JwtService,
  ) {}

  async request(adminId: string, targetUserId: string) {
    const request = await this.prisma.impersonationRequest.create({
      data: { adminId, targetUserId, status: 'PENDING' },
    });

    // storeId is not required here — sendPush needs one, so we look up the
    // target's oldest store the same way Task 1's sendDirectNotification does.
    const store = await this.prisma.store.findFirst({
      where: { ownerId: targetUserId },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });
    if (store) {
      await this.notifications.sendPush(
        targetUserId,
        'Запрос доступа от поддержки',
        'Поддержка Dukon запросила временный доступ к вашему аккаунту для диагностики. Откройте приложение, чтобы разрешить или отклонить.',
        'IMPERSONATION_REQUEST',
        store.id,
      );
    }

    return request;
  }

  async respond(requestId: string, respondingUserId: string, decision: 'APPROVED' | 'REJECTED') {
    const request = await this.prisma.impersonationRequest.findUnique({
      where: { id: requestId },
    });
    if (!request) throw new NotFoundException('Impersonation request not found');
    if (request.targetUserId !== respondingUserId) {
      throw new BadRequestException('This request does not belong to the current user');
    }
    if (request.status !== 'PENDING') {
      throw new BadRequestException('This request has already been responded to');
    }

    const respondedAt = new Date();
    const expiresAt =
      decision === 'APPROVED'
        ? new Date(respondedAt.getTime() + IMPERSONATION_SESSION_MINUTES * 60000)
        : undefined;

    return this.prisma.impersonationRequest.update({
      where: { id: requestId },
      data: { status: decision, respondedAt, expiresAt },
    });
  }

  async issueToken(requestId: string): Promise<string> {
    const request = await this.prisma.impersonationRequest.findUnique({
      where: { id: requestId },
    });
    if (!request) throw new NotFoundException('Impersonation request not found');
    if (request.status !== 'APPROVED') {
      throw new BadRequestException('Request is not approved');
    }
    if (!request.expiresAt || request.expiresAt < new Date()) {
      throw new BadRequestException('Approval has expired — request access again');
    }

    return this.jwt.sign(
      {
        sub: request.targetUserId,
        impersonatedBy: request.adminId,
        impersonationRequestId: request.id,
      },
      { expiresIn: '30m' },
    );
  }

  async end(requestId: string) {
    return this.prisma.impersonationRequest.update({
      where: { id: requestId },
      data: { status: 'ENDED', endedAt: new Date() },
    });
  }
}
```

**Before finalizing:** confirm the exact JWT payload shape and signing options the rest of this codebase's `JwtAuthGuard`/`AuthService` already use (run `grep -n "JwtService\|jwt.sign\|sub:" api/src/modules/auth -r`) and align field names (`sub` vs `userId`, etc.) with whatever `JwtAuthGuard` already reads to populate `request.user` — the guard must recognize this token as a valid session for `request.targetUserId`, just with the extra `impersonatedBy` claim riding along. Adjust the `sign()` payload shape to match exactly; the test above encodes the payload shape this plan assumes, update both together if they don't match the existing auth module's convention.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd api && npx jest impersonation.service.spec.ts`
Expected: PASS (6 tests)

- [ ] **Step 7: Wire `impersonatedBy` into the audit trail**

In `api/src/common/interceptors/audit.interceptor.ts`, inside the `tap((response) => { ... })` callback, add:

```typescript
        const viaImpersonation: boolean = !!request.user?.impersonatedBy;
```

And add `viaImpersonation` to the `data` object passed to `this.prisma.auditLog.create`:

```typescript
              data: {
                userId,
                action,
                entityType,
                entityId,
                details: {
                  before: this.redactObject(before),
                  after: this.redactObject(after),
                  ...(viaImpersonation && { viaImpersonation: true }),
                },
                ip,
              },
```

Update `audit.interceptor.spec.ts` with one more test confirming `viaImpersonation: true` appears in `details` when `request.user.impersonatedBy` is set, and is absent otherwise — follow the existing `makeContext`/`makeCallHandler` helpers already in that file, just add `user: { id: 'target-1', impersonatedBy: 'admin-1' }` to a new test's context.

- [ ] **Step 8: Create the admin-facing controller (request + poll status + get token)**

```typescript
// api/src/modules/impersonation/impersonation-admin.controller.ts
import { Controller, Post, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ImpersonationService } from './impersonation.service';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class ImpersonationAdminController {
  constructor(private readonly impersonationService: ImpersonationService) {}

  @Post('users/:id/impersonate')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @ApiOperation({ summary: 'Request impersonation access to a user account (requires their in-app approval)' })
  request(@Param('id') targetUserId: string, @CurrentUser('id') adminId: string) {
    return this.impersonationService.request(adminId, targetUserId);
  }

  @Get('impersonation/:id/token')
  @ApiOperation({ summary: 'Fetch the impersonation token once the request has been approved' })
  getToken(@Param('id') id: string) {
    return this.impersonationService.issueToken(id).then((token) => ({ token }));
  }

  @Post('impersonation/:id/end')
  @ApiOperation({ summary: 'End an active impersonation session immediately' })
  end(@Param('id') id: string) {
    return this.impersonationService.end(id);
  }
}
```

**Note:** this plan does not add a "poll status" GET endpoint distinct from `getToken` — `getToken` itself throws a clear `BadRequestException` while still `PENDING`, which the frontend polling loop (Step 12) treats as "not ready yet" and keeps polling; this avoids a redundant third endpoint. If review feedback prefers an explicit `GET /admin/impersonation/:id` status endpoint returning `{status}` instead of relying on `getToken`'s error as a signal, that is a reasonable one-line addition — not required for correctness.

- [ ] **Step 9: Create the user-facing controller (respond to a request)**

```typescript
// api/src/modules/impersonation/impersonation.controller.ts
import { Controller, Put, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ImpersonationService } from './impersonation.service';
import { RespondImpersonationDto } from './dto/respond-impersonation.dto';

@ApiTags('Impersonation')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('impersonation-requests')
export class ImpersonationController {
  constructor(private readonly impersonationService: ImpersonationService) {}

  @Put(':id/respond')
  @ApiOperation({ summary: 'Approve or reject a pending impersonation request targeting the current user' })
  respond(
    @Param('id') id: string,
    @Body() dto: RespondImpersonationDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.impersonationService.respond(id, userId, dto.decision);
  }
}
```

```typescript
// api/src/modules/impersonation/dto/respond-impersonation.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty } from 'class-validator';

export class RespondImpersonationDto {
  @ApiProperty({ enum: ['APPROVED', 'REJECTED'] })
  @IsNotEmpty()
  @IsIn(['APPROVED', 'REJECTED'])
  decision: 'APPROVED' | 'REJECTED';
}
```

- [ ] **Step 10: Wire the module**

```typescript
// api/src/modules/impersonation/impersonation.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ImpersonationService } from './impersonation.service';
import { ImpersonationAdminController } from './impersonation-admin.controller';
import { ImpersonationController } from './impersonation.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule, JwtModule.register({})],
  controllers: [ImpersonationAdminController, ImpersonationController],
  providers: [ImpersonationService],
})
export class ImpersonationModule {}
```

Register `ImpersonationModule` in `api/src/app.module.ts` alongside `BannersModule` from Task 5. Verify whether `JwtModule` is already globally configured elsewhere (`grep -n "JwtModule" api/src -r`) — if a global `JwtModule.registerAsync(...)` with the app's real secret already exists (likely, since the app already issues JWTs for normal login), use that shared configuration instead of `JwtModule.register({})` so the impersonation token is signed with the same secret `JwtAuthGuard` verifies against. This is a correctness-critical detail: an impersonation token signed with a different secret than the one `JwtAuthGuard` checks will always fail auth.

- [ ] **Step 11: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS

- [ ] **Step 12: Commit backend**

```bash
cd api
git add prisma/schema.prisma prisma/migrations \
        src/modules/impersonation/ \
        src/common/interceptors/audit.interceptor.ts \
        src/common/interceptors/audit.interceptor.spec.ts \
        src/app.module.ts
git commit -m "feat(impersonation): add consent-gated support impersonation with 30-minute scoped tokens"
```

- [ ] **Step 13: Add the admin UI (request + poll + QR/deep-link display)**

In `admin/app/(admin)/users/[id]/page.tsx`, add another button next to "Отправить сообщение" (from Task 1 Step 10):

```tsx
            <Button
              variant="outline"
              onClick={() => impersonateMutation.mutate()}
              disabled={impersonateMutation.isPending}
            >
              <UserCog className="mr-2 h-4 w-4" />
              Войти как пользователь
            </Button>
```

Add state, the request mutation, and a polling query above the return statement:

```tsx
  const [impersonationRequestId, setImpersonationRequestId] = useState<string | null>(null);

  const impersonateMutation = useMutation({
    mutationFn: () => api.post(`/admin/users/${id}/impersonate`),
    onSuccess: (data: any) => {
      setImpersonationRequestId(data.id);
      toast.success('Запрос отправлен пользователю, ожидаем подтверждения');
    },
    onError: () => toast.error('Не удалось отправить запрос'),
  });

  const { data: tokenData } = useQuery({
    queryKey: ['impersonation-token', impersonationRequestId],
    queryFn: () => api.get(`/admin/impersonation/${impersonationRequestId}/token`),
    enabled: !!impersonationRequestId,
    refetchInterval: (query) => (query.state.data ? false : 4000),
    retry: false,
  });
```

Add a dialog (or inline card) shown when `tokenData?.token` is present, rendering the deep link as text plus a QR code. This plan does not pin a specific QR-code React library — check `admin/package.json` for one already installed (search for `qrcode`); if none exists, add `qrcode.react` as a new dependency (`npm install qrcode.react` in `admin/`) and use its `<QRCodeSVG value={deepLink} />` component. The deep link value is:

```tsx
const deepLink = `dukonpro://impersonate?token=${tokenData?.token}`;
```

- [ ] **Step 14: Commit admin frontend**

```bash
git add admin/app/\(admin\)/users/\[id\]/page.tsx admin/package.json admin/package-lock.json
git commit -m "feat(admin): add impersonate button with request polling and QR/deep-link handoff"
```

- [ ] **Step 15: Add the mobile consent screen and active-session banner**

This step requires two new Flutter pieces:

1. **Consent screen** — triggered when the app receives an `IMPERSONATION_REQUEST` push (or, more simply for v1, a new item in the existing Notifications list screen that the user already sees, with "Разрешить"/"Отклонить" buttons calling `PUT /impersonation-requests/:id/respond`). Locate the existing notification list screen via `grep -rln "class NotificationsPage\|notification_list" app/lib` and add conditional action buttons when a notification's `type == 'IMPERSONATION_REQUEST'`.

2. **Persistent session banner** — when the app is running with an impersonation-flavored access token (received via the deep link `dukonpro://impersonate?token=...`, handled by whatever deep-link router this app already uses — locate via `grep -rln "uni_links\|app_links\|onGenerateRoute.*scheme" app/lib`), show a non-dismissible top banner "Вы вошли как поддержка Dukon" with an "Завершить сессию" button calling `POST /admin/impersonation/:id/end` then logging out.

**This step is deliberately left less prescriptive than the others** because it depends on two pieces of existing app infrastructure (deep-link handling, notification-type routing) that were not part of this session's verified research — locate and read those exact files first (as instructed above), then implement following their existing patterns, rather than guessing their shape here.

- [ ] **Step 16: Manual end-to-end verification**

Using two devices/sessions (admin panel + a test mobile account): request impersonation from `/users/[id]`, confirm the push/notification arrives on the test account, approve it, confirm the admin panel's polling picks up the token within ~4 seconds, confirm any request made with that token is tagged `viaImpersonation: true` in `/audit-log`, confirm the session banner appears on the mobile app, end the session from the mobile banner, confirm the admin-side token immediately stops working (re-verify via `issueToken` throwing after `end()`).

- [ ] **Step 17: Commit mobile app changes**

```bash
git add app/lib
git commit -m "feat(mobile): add impersonation consent flow and active-session banner"
```

---

## Final check

- [ ] Run `cd api && npx jest` — full backend suite green.
- [ ] Run `cd admin && npm run build` — Next.js production build succeeds with no type errors.
- [ ] Run `cd app && flutter analyze` — no new issues introduced by Task 5/6 mobile changes.
- [ ] Confirm all 6 feature commits are present on the current branch via `git log --oneline` since this plan's first commit.
