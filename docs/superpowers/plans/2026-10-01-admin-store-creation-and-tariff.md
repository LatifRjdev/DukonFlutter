# Admin Store Creation and Tariff Assignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an admin create a store for an existing user, and assign or change a store's subscription plan — neither is currently possible from the admin panel.

**Architecture:** Two endpoints added to the existing `admin/stores` controller, which already carries `JwtAuthGuard`, `AdminGuard` and `AuditInterceptor` at class level, so both inherit authorization and audit logging with no new wiring. Store creation delegates to `StoresService.create` rather than duplicating it. The UI extends the existing stores page, which already owns comparable suspend and transfer dialogs.

**Tech Stack:** NestJS + Prisma + Jest (`api/`), Next.js + React Query + Vitest + MSW (`admin/`). Postgres runs on `localhost:5435` (container `dukonpro-db`); the API serves on `:4455` under global prefix `api`; the admin dev server is on `:3000`.

**Spec:** `docs/superpowers/specs/2026-10-01-admin-store-creation-and-tariff-design.md`

---

## Facts established before writing this plan

Verified against the live tree. Re-verify any number you rely on, but these are the shape of the work.

- `api/src/modules/admin/admin-stores.controller.ts` has `@UseGuards(JwtAuthGuard, AdminGuard)` and `@UseInterceptors(AuditInterceptor)` at **class** level (lines 25–26), on `@Controller('admin/stores')`. Anything added there is admin-only and audit-logged automatically.
- `AuditInterceptor` logs any `POST`/`PUT`/`PATCH`/`DELETE` whose URL contains `/admin/` (line 61), deriving entity type and action from the route. **No audit code to write.**
- `StoresService.create(ownerId, dto, tx?)` (`api/src/modules/stores/stores.service.ts:20`) creates the store, a `Subscription` with `plan: 'PREMIUM'`, `status: 'TRIAL'` and a 7-day window, **and** a `Staff` row with `role: 'OWNER'`. It returns the store with `subscription` included.
- `AdminService` already injects `StoresService` — `createUserManually` calls it at `admin.service.ts:100`. **No constructor change needed.**
- `transferStore` (`admin.service.ts:376-389`) is the nearest analogue for "validate a related entity, then mutate": it throws `NotFoundException('New owner user not found')`.
- `Subscription.storeId` is `@unique`, so `prisma.subscription.upsert({ where: { storeId } })` is valid.
- `admin/components/user-picker.tsx` exports `UserPicker` with props `{ value: string; onSelect: (id: string, label: string) => void }`. The transfer dialog already uses it (`stores/page.tsx:33`, and in the dialog body). **Reuse it; do not write a second picker.**
- Backend tests use a hand-written Prisma fake plus `Test.createTestingModule({ providers: [AdminService, {provide: PrismaService, useValue: prisma}, {provide: NotificationsService, useValue: {sendPush: jest.fn()}}, {provide: StoresService, useValue: storesService}] })` — see `api/src/modules/admin/admin.users-create.spec.ts:79-88`. Mirror it.
- Admin tests use Vitest + MSW with `server` from `../../../test/msw/server` and an `API_URL` constant — see `admin/app/(admin)/stores/page.test.tsx`.
- Commands: `api/` → `npm test` (jest), `npm run lint`; `admin/` → `npm test` (`vitest run`), `npm run lint`.

## File structure

| File | Responsibility | Task |
|---|---|---|
| `api/src/modules/admin/dto/create-store-by-admin.dto.ts` | **new** — validates the create-store body | 1 |
| `api/src/modules/admin/dto/update-store-subscription.dto.ts` | **new** — validates the tariff body | 2 |
| `api/src/modules/admin/admin.service.ts` | gains `createStoreForOwner` and `updateStoreSubscription` | 1, 2 |
| `api/src/modules/admin/admin-stores.controller.ts` | gains `POST /` and `PUT /:id/subscription` | 1, 2 |
| `api/src/modules/admin/admin.stores-create.spec.ts` | **new** — store creation tests | 1 |
| `api/src/modules/admin/admin.store-subscription.spec.ts` | **new** — tariff tests | 2 |
| `admin/app/(admin)/stores/page.tsx` | gains both dialogs | 3, 4 |
| `admin/app/(admin)/stores/page.test.tsx` | gains tests for both dialogs | 3, 4 |

---

## Hard constraints

- **Do NOT touch `app/`.** This work is API + admin only. Task 5 asserts it.
- **Do NOT modify `api/prisma/schema.prisma`** and do not create a migration. `Store` and `Subscription` already carry every field needed.
- **Do NOT add a second user-creation path.** `POST /admin/users` already creates a user with an optional first store.
- **Do NOT touch `adminDiscount` or `Payment`** — explicitly out of scope; they carry financial-reporting semantics needing their own decision.
- **Do NOT run `dart format`** (irrelevant here, but the repo-wide rule stands: Dart 3.10 tall style rewrites this repo wholesale).
- **Never touch `trialEndsAt`** when changing a subscription — it records when the original trial ended, which an admin grant should not rewrite.

---

## Task 1: `POST /admin/stores`

**Files:**
- Create: `api/src/modules/admin/dto/create-store-by-admin.dto.ts`
- Create: `api/src/modules/admin/admin.stores-create.spec.ts`
- Modify: `api/src/modules/admin/admin.service.ts`
- Modify: `api/src/modules/admin/admin-stores.controller.ts`

- [ ] **Step 1: Write the failing test**

Create `api/src/modules/admin/admin.stores-create.spec.ts`:

```ts
import 'reflect-metadata';
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

describe('AdminService.createStoreForOwner', () => {
  let service: AdminService;
  let storesService: { create: jest.Mock };
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(async ({ where }: any) =>
          where.id === 'user-1'
            ? { id: 'user-1', phone: '+992901234567', name: 'Али' }
            : null,
        ),
      },
    };
    // The real StoresService.create also makes the subscription and the OWNER
    // staff row; the fake returns the same shape so the assertions below are
    // about delegation, not about re-testing StoresService.
    storesService = {
      create: jest.fn(async (ownerId: string, dto: any) => ({
        id: 'store-1',
        ownerId,
        name: dto.name,
        category: dto.category,
        currency: dto.currency ?? 'TJS',
        subscription: {
          id: 'sub-1',
          storeId: 'store-1',
          plan: 'PREMIUM',
          status: 'TRIAL',
        },
      })),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: storesService },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('should create a store for an existing owner and return it with its subscription', async () => {
    const result = await service.createStoreForOwner({
      ownerId: 'user-1',
      name: 'Тестовый магазин',
      category: 'GROCERY',
    } as any);

    expect(result.id).toBe('store-1');
    expect(result.ownerId).toBe('user-1');
    expect(result.subscription.plan).toBe('PREMIUM');
    expect(result.subscription.status).toBe('TRIAL');
  });

  it('should delegate to StoresService.create rather than writing the store itself', async () => {
    // Delegation is the point: StoresService.create is the single path that
    // also creates the subscription and the OWNER staff row. A second creation
    // path would silently skip those.
    await service.createStoreForOwner({
      ownerId: 'user-1',
      name: 'Тестовый магазин',
      category: 'GROCERY',
      currency: 'USD',
      address: 'Душанбе',
      phone: '+992900000000',
    } as any);

    expect(storesService.create).toHaveBeenCalledTimes(1);
    expect(storesService.create).toHaveBeenCalledWith('user-1', {
      name: 'Тестовый магазин',
      category: 'GROCERY',
      currency: 'USD',
      address: 'Душанбе',
      phone: '+992900000000',
    });
  });

  it('should throw NotFoundException when the owner does not exist', async () => {
    await expect(
      service.createStoreForOwner({
        ownerId: 'nope',
        name: 'Тестовый магазин',
        category: 'GROCERY',
      } as any),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(storesService.create).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd api
npm test -- admin.stores-create.spec.ts
```
Expected: FAIL — `service.createStoreForOwner is not a function`.

If it fails for any other reason, read the error before proceeding; a fake that is wrong in shape will produce confusing passes later.

- [ ] **Step 3: Create the DTO**

Create `api/src/modules/admin/dto/create-store-by-admin.dto.ts`. Field rules are copied verbatim from `api/src/modules/stores/dto/create-store.dto.ts` so the admin path cannot be laxer than self-service:

```ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsEnum,
  IsUUID,
  Matches,
  MaxLength,
} from 'class-validator';
import { IsSafeText } from '../../../common/validators/safe-text.validator';

const STORE_CATEGORIES = [
  'GROCERY',
  'CLOTHING',
  'ELECTRONICS',
  'HARDWARE',
  'PHARMACY',
  'OTHER',
];

export class CreateStoreByAdminDto {
  @ApiProperty({ description: 'Existing user who will own the store' })
  @IsNotEmpty()
  @IsUUID()
  ownerId: string;

  @ApiProperty({ example: 'Мой магазин' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  @IsSafeText()
  name: string;

  @ApiProperty({ enum: STORE_CATEGORIES })
  @IsNotEmpty()
  @IsEnum(STORE_CATEGORIES)
  category: string;

  @ApiPropertyOptional({ enum: ['TJS', 'USD', 'RUB'], default: 'TJS' })
  @IsOptional()
  @IsEnum(['TJS', 'USD', 'RUB'], {
    message: 'currency must be one of: TJS, USD, RUB',
  })
  currency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @IsSafeText()
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^\+?\d{9,15}$/)
  phone?: string;
}
```

- [ ] **Step 4: Add the service method**

In `api/src/modules/admin/admin.service.ts`, add the import beside the other DTO imports (near line 13, where `TransferStoreDto` is imported):

```ts
import { CreateStoreByAdminDto } from './dto/create-store-by-admin.dto';
```

Then add the method immediately after `transferStore` (which ends around line 389), keeping store operations together:

```ts
  /// Creates a store for an EXISTING user.
  ///
  /// Delegates to StoresService.create rather than writing the store here:
  /// that single path also creates the PREMIUM/TRIAL subscription and the
  /// OWNER staff row, and a second creation path would silently skip both.
  /// New-user creation already has its own route (POST /admin/users), which
  /// can create a first store in the same transaction.
  async createStoreForOwner(dto: CreateStoreByAdminDto) {
    const owner = await this.prisma.user.findUnique({
      where: { id: dto.ownerId },
    });
    if (!owner) throw new NotFoundException('Owner user not found');

    return this.storesService.create(dto.ownerId, {
      name: dto.name,
      category: dto.category,
      currency: dto.currency,
      address: dto.address,
      phone: dto.phone,
    } as any);
  }
```

`NotFoundException` is already imported in this file (used by `transferStore`). If your editor says otherwise, check the import block at the top rather than adding a duplicate.

- [ ] **Step 5: Add the controller route**

In `api/src/modules/admin/admin-stores.controller.ts`, add `Post` to the `@nestjs/common` import list (line 1–11), add the DTO import beside `TransferStoreDto` (line 21):

```ts
import { CreateStoreByAdminDto } from './dto/create-store-by-admin.dto';
```

Then add the route. Place it **after** `@Get('export')` and **before** `@Get(':id')` is not required — `@Post()` and `@Get(':id')` cannot collide — so put it first in the class body, right after the constructor, since creation reads naturally before listing:

```ts
  @Post()
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Create a store for an existing user' })
  createStore(@Body() dto: CreateStoreByAdminDto) {
    return this.adminService.createStoreForOwner(dto);
  }
```

- [ ] **Step 6: Run the tests**

```bash
npm test -- admin.stores-create.spec.ts
```
Expected: **3 passed**.

- [ ] **Step 7: Lint and typecheck**

```bash
npm run lint
npx tsc --noEmit
```
Expected: both clean.

- [ ] **Step 8: Commit**

```bash
git add api/src/modules/admin/dto/create-store-by-admin.dto.ts \
        api/src/modules/admin/admin.stores-create.spec.ts \
        api/src/modules/admin/admin.service.ts \
        api/src/modules/admin/admin-stores.controller.ts
git commit -m "feat(admin): create a store for an existing user

POST /admin/stores. Delegates to StoresService.create, which is the
single path that also creates the PREMIUM/TRIAL subscription and the
OWNER staff row — a second creation path would silently skip both.
Inherits AdminGuard and audit logging from the controller class.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `PUT /admin/stores/:id/subscription`

**Files:**
- Create: `api/src/modules/admin/dto/update-store-subscription.dto.ts`
- Create: `api/src/modules/admin/admin.store-subscription.spec.ts`
- Modify: `api/src/modules/admin/admin.service.ts`
- Modify: `api/src/modules/admin/admin-stores.controller.ts`

- [ ] **Step 1: Write the failing test**

Create `api/src/modules/admin/admin.store-subscription.spec.ts`:

```ts
import 'reflect-metadata';
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake(opts: { withSubscription: boolean }) {
  const subscriptions = new Map<string, any>();
  if (opts.withSubscription) {
    subscriptions.set('store-1', {
      id: 'sub-1',
      storeId: 'store-1',
      plan: 'PREMIUM',
      status: 'TRIAL',
      trialEndsAt: new Date('2026-01-08T00:00:00.000Z'),
      currentPeriodStart: new Date('2026-01-01T00:00:00.000Z'),
      currentPeriodEnd: new Date('2026-01-08T00:00:00.000Z'),
    });
  }
  return {
    _subscriptions: subscriptions,
    store: {
      findUnique: jest.fn(async ({ where }: any) =>
        where.id === 'store-1' ? { id: 'store-1', name: 'Магазин' } : null,
      ),
    },
    subscription: {
      upsert: jest.fn(async ({ where, update, create }: any) => {
        const existing = subscriptions.get(where.storeId);
        const row = existing
          ? { ...existing, ...update }
          : { id: 'sub-new', storeId: where.storeId, ...create };
        subscriptions.set(where.storeId, row);
        return row;
      }),
    },
  };
}

async function buildService(prisma: any) {
  const moduleRef = await Test.createTestingModule({
    providers: [
      AdminService,
      { provide: PrismaService, useValue: prisma },
      { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
      { provide: StoresService, useValue: { create: jest.fn() } },
    ],
  }).compile();
  return moduleRef.get(AdminService);
}

describe('AdminService.updateStoreSubscription', () => {
  it('should set plan, status and period together', async () => {
    // Setting plan alone is the obvious minimal design and it is wrong: the
    // server-side guards consult status and period, so granting BUSINESS to an
    // EXPIRED subscription would change the plan and still deny every feature.
    const prisma = makePrismaFake({ withSubscription: true });
    const service = await buildService(prisma);

    const result = await service.updateStoreSubscription('store-1', {
      plan: 'BUSINESS',
      status: 'ACTIVE',
      currentPeriodEnd: '2027-01-01T00:00:00.000Z',
    } as any);

    expect(result.plan).toBe('BUSINESS');
    expect(result.status).toBe('ACTIVE');
    expect(new Date(result.currentPeriodEnd).toISOString()).toBe(
      '2027-01-01T00:00:00.000Z',
    );
  });

  it('should leave trialEndsAt untouched', async () => {
    // trialEndsAt records when the original trial ended. An admin grant is not
    // a trial and must not rewrite that history.
    const prisma = makePrismaFake({ withSubscription: true });
    const service = await buildService(prisma);

    const result = await service.updateStoreSubscription('store-1', {
      plan: 'BUSINESS',
      status: 'ACTIVE',
      currentPeriodEnd: '2027-01-01T00:00:00.000Z',
    } as any);

    expect(new Date(result.trialEndsAt).toISOString()).toBe(
      '2026-01-08T00:00:00.000Z',
    );
    const updateArg = prisma.subscription.upsert.mock.calls[0][0].update;
    expect(updateArg).not.toHaveProperty('trialEndsAt');
  });

  it('should create a subscription when the store has none', async () => {
    // Every store made by StoresService.create has one, but a store from an
    // older path or a half-failed migration might not. An admin tool that
    // cannot repair that state is less useful than one that can.
    const prisma = makePrismaFake({ withSubscription: false });
    const service = await buildService(prisma);

    const result = await service.updateStoreSubscription('store-1', {
      plan: 'START',
      status: 'ACTIVE',
      currentPeriodEnd: '2027-01-01T00:00:00.000Z',
    } as any);

    expect(result.plan).toBe('START');
    const createArg = prisma.subscription.upsert.mock.calls[0][0].create;
    expect(createArg.currentPeriodStart).toBeInstanceOf(Date);
  });

  it('should throw NotFoundException when the store does not exist', async () => {
    const prisma = makePrismaFake({ withSubscription: true });
    const service = await buildService(prisma);

    await expect(
      service.updateStoreSubscription('nope', {
        plan: 'BUSINESS',
        status: 'ACTIVE',
        currentPeriodEnd: '2027-01-01T00:00:00.000Z',
      } as any),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.subscription.upsert).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd api
npm test -- admin.store-subscription.spec.ts
```
Expected: FAIL — `service.updateStoreSubscription is not a function`.

- [ ] **Step 3: Create the DTO**

Create `api/src/modules/admin/dto/update-store-subscription.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsNotEmpty } from 'class-validator';

const PLANS = ['START', 'BUSINESS', 'PREMIUM'];
const STATUSES = ['TRIAL', 'ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED'];

export class UpdateStoreSubscriptionDto {
  @ApiProperty({ enum: PLANS })
  @IsNotEmpty()
  @IsEnum(PLANS)
  plan: string;

  // status and currentPeriodEnd are REQUIRED, not optional. The server-side
  // entitlement guards consult both, so a plan set on an EXPIRED or lapsed
  // subscription grants nothing — the admin would see the new plan and no
  // change in behaviour. Requiring all three makes the grant take effect.
  @ApiProperty({ enum: STATUSES })
  @IsNotEmpty()
  @IsEnum(STATUSES)
  status: string;

  @ApiProperty({ example: '2027-01-01T00:00:00.000Z' })
  @IsNotEmpty()
  @IsDateString()
  currentPeriodEnd: string;
}
```

- [ ] **Step 4: Add the service method**

In `api/src/modules/admin/admin.service.ts`, add the import beside the other DTO imports:

```ts
import { UpdateStoreSubscriptionDto } from './dto/update-store-subscription.dto';
```

Add the method immediately after `createStoreForOwner` from Task 1:

```ts
  /// Assigns or changes a store's subscription plan.
  ///
  /// Sets plan, status and period together on purpose. The entitlement guards
  /// (common/guards/plan-limit.helper.ts and feature-flag.helper.ts) consult
  /// status and currentPeriodEnd as well as plan, so changing only the plan on
  /// an EXPIRED or lapsed subscription would record the grant and change
  /// nothing the user can see.
  ///
  /// Upserts rather than 404ing on a missing subscription: every store created
  /// through StoresService.create has one, but a store from an older path or a
  /// half-failed migration might not, and repairing that is exactly what an
  /// admin tool is for. trialEndsAt is never written — it records when the
  /// original trial ended.
  async updateStoreSubscription(id: string, dto: UpdateStoreSubscriptionDto) {
    const store = await this.prisma.store.findUnique({ where: { id } });
    if (!store) throw new NotFoundException('Store not found');

    const periodEnd = new Date(dto.currentPeriodEnd);

    return this.prisma.subscription.upsert({
      where: { storeId: id },
      update: {
        plan: dto.plan as any,
        status: dto.status as any,
        currentPeriodEnd: periodEnd,
      },
      create: {
        storeId: id,
        plan: dto.plan as any,
        status: dto.status as any,
        currentPeriodStart: new Date(),
        currentPeriodEnd: periodEnd,
      },
    });
  }
```

- [ ] **Step 5: Add the controller route**

In `api/src/modules/admin/admin-stores.controller.ts`, add the DTO import:

```ts
import { UpdateStoreSubscriptionDto } from './dto/update-store-subscription.dto';
```

Add the route after `@Get(':id/subscription')`, keeping the read and the write adjacent:

```ts
  @Put(':id/subscription')
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @ApiOperation({ summary: 'Assign or change a store subscription plan' })
  updateStoreSubscription(
    @Param('id') id: string,
    @Body() dto: UpdateStoreSubscriptionDto,
  ) {
    return this.adminService.updateStoreSubscription(id, dto);
  }
```

- [ ] **Step 6: Run both backend test files**

```bash
npm test -- admin.store-subscription.spec.ts admin.stores-create.spec.ts
```
Expected: **7 passed** (4 + 3).

- [ ] **Step 7: Run the whole API suite, lint and typecheck**

```bash
npm test
npm run lint
npx tsc --noEmit
```
Expected: all green. Record the pass/fail counts. **If anything was failing before your change, say so rather than attributing it to this work** — check by stashing and re-running if unsure.

- [ ] **Step 8: Commit**

```bash
git add api/src/modules/admin/dto/update-store-subscription.dto.ts \
        api/src/modules/admin/admin.store-subscription.spec.ts \
        api/src/modules/admin/admin.service.ts \
        api/src/modules/admin/admin-stores.controller.ts
git commit -m "feat(admin): assign or change a store subscription plan

PUT /admin/stores/:id/subscription. Sets plan, status and period
together: the entitlement guards consult status and period as well as
plan, so changing only the plan on an EXPIRED subscription would record
the grant and change nothing the user can see.

Upserts rather than 404ing when a store has no subscription, so an admin
can repair that state. trialEndsAt is never rewritten.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Create-store dialog in the admin UI

**Files:**
- Modify: `admin/app/(admin)/stores/page.tsx`
- Modify: `admin/app/(admin)/stores/page.test.tsx`

- [ ] **Step 1: Read the existing transfer dialog first**

```bash
cd admin
grep -n "transferDialog\|transferMutation\|UserPicker" "app/(admin)/stores/page.tsx"
```
It is the closest precedent: a dialog that picks a user with `UserPicker` and PUTs. Mirror its structure — state held in `useState`, mutation via `useMutation`, `queryClient.invalidateQueries` on success. Do **not** introduce a different pattern.

- [ ] **Step 2: Write the failing test**

Append to `admin/app/(admin)/stores/page.test.tsx`:

```tsx
describe('StoresPage — create store for an existing user', () => {
  it('POSTs { ownerId, name, category } to /admin/stores and invalidates the list', async () => {
    const user = userEvent.setup();
    let posted: Record<string, unknown> | null = null;
    server.use(
      http.post(`${API_URL}/admin/stores`, async ({ request }) => {
        posted = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: 's2', name: 'Новый магазин' });
      }),
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({
          data: [{ id: 'u1', name: 'Али', phone: '+992901234567' }],
          total: 1,
        }),
      ),
    );

    mockSingleStore(true);
    renderWithQuery(<StoresPage />);
    await user.click(await screen.findByRole('button', { name: 'Создать магазин' }));

    await user.type(screen.getByLabelText('Название'), 'Новый магазин');
    await user.click(screen.getByLabelText('Владелец'));
    await user.type(screen.getByLabelText('Владелец'), '+992901234567');
    await user.click(await screen.findByText(/Али/));

    await user.click(screen.getByRole('button', { name: 'Создать' }));

    await waitFor(() => expect(posted).not.toBeNull());
    expect(posted).toMatchObject({
      ownerId: 'u1',
      name: 'Новый магазин',
      category: 'GROCERY',
    });
  });

  it('shows a server validation error inline instead of only as a toast', async () => {
    // An unknown ownerId and a malformed field are both recoverable mistakes
    // the admin should see next to the field, not just in a toast that fades.
    const user = userEvent.setup();
    server.use(
      http.post(`${API_URL}/admin/stores`, () =>
        HttpResponse.json(
          { statusCode: 404, message: ['Owner user not found'] },
          { status: 404 },
        ),
      ),
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({
          data: [{ id: 'u1', name: 'Али', phone: '+992901234567' }],
          total: 1,
        }),
      ),
    );

    mockSingleStore(true);
    renderWithQuery(<StoresPage />);
    await user.click(await screen.findByRole('button', { name: 'Создать магазин' }));
    await user.type(screen.getByLabelText('Название'), 'Новый магазин');
    await user.click(screen.getByLabelText('Владелец'));
    await user.type(screen.getByLabelText('Владелец'), '+992901234567');
    await user.click(await screen.findByText(/Али/));
    await user.click(screen.getByRole('button', { name: 'Создать' }));

    expect(await screen.findByText('Owner user not found')).toBeInTheDocument();
  });
});
```

Two helpers already exist in this file and must be reused rather than reinvented: `renderWithQuery(ui)` (line 27) wraps the component in a `QueryClientProvider`, and `mockSingleStore(isActive)` seeds the store list. The existing transfer test also resets `toastSuccess`/`toastError` mocks in `beforeEach` — do the same. The test code below already uses both helpers.

- [ ] **Step 3: Run it and confirm it fails**

```bash
npm test -- stores/page.test.tsx
```
Expected: FAIL — no button named `Создать магазин`.

- [ ] **Step 4: Implement the dialog**

In `admin/app/(admin)/stores/page.tsx`, add state beside the existing dialog state (near line 73):

```tsx
  const [createOpen, setCreateOpen] = useState(false);
  const [newStore, setNewStore] = useState({
    ownerId: '',
    name: '',
    category: 'GROCERY',
    currency: 'TJS',
    address: '',
    phone: '',
  });
  const [createError, setCreateError] = useState<string | null>(null);
```

Add the mutation beside `transferMutation` (near line 97):

```tsx
  const createMutation = useMutation({
    mutationFn: (body: typeof newStore) =>
      api.post('/admin/stores', {
        ownerId: body.ownerId,
        name: body.name,
        category: body.category,
        currency: body.currency,
        address: body.address || undefined,
        phone: body.phone || undefined,
      }),
    onSuccess: () => {
      toast.success('Магазин создан');
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      setCreateOpen(false);
      setCreateError(null);
      setNewStore({
        ownerId: '',
        name: '',
        category: 'GROCERY',
        currency: 'TJS',
        address: '',
        phone: '',
      });
    },
    onError: (e: unknown) => {
      // Surface the server's message inline — an unknown ownerId is a
      // recoverable mistake the admin should see next to the field.
      //
      // NOTE the error shape: lib/api.ts is a fetch wrapper, NOT axios. It
      // throws `new Error(data.message || 'HTTP <status>')`, so the message is
      // on `.message` directly. There is no `e.response.data`; reaching for it
      // yields undefined and the inline error never renders.
      setCreateError(e instanceof Error ? e.message : 'Не удалось создать магазин');
    },
  });
```

The invalidation key is `['stores']` — verified against the page's `useQuery` at `page.tsx:78`, which the existing suspend and transfer mutations also invalidate. Invalidating a key nothing uses fails silently: the list just looks stale.

Add the header button next to the existing Экспорт button, and the dialog beside the transfer dialog:

```tsx
      <Button onClick={() => setCreateOpen(true)}>Создать магазин</Button>
```

```tsx
      <Dialog open={createOpen} onOpenChange={(o) => { setCreateOpen(o); if (!o) setCreateError(null); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Создать магазин</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <div className="space-y-2">
              <Label htmlFor="create-owner">Владелец</Label>
              <UserPicker
                value={newStore.ownerId}
                onSelect={(id) => setNewStore((s) => ({ ...s, ownerId: id }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-name">Название</Label>
              <Input
                id="create-name"
                value={newStore.name}
                onChange={(e) => setNewStore((s) => ({ ...s, name: e.target.value }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-category">Категория</Label>
              <select
                id="create-category"
                className="w-full rounded-md border px-3 py-2 text-sm"
                value={newStore.category}
                onChange={(e) => setNewStore((s) => ({ ...s, category: e.target.value }))}
              >
                <option value="GROCERY">Продукты</option>
                <option value="CLOTHING">Одежда</option>
                <option value="ELECTRONICS">Электроника</option>
                <option value="HARDWARE">Хозтовары</option>
                <option value="PHARMACY">Аптека</option>
                <option value="OTHER">Другое</option>
              </select>
            </div>
            {createError && (
              <p className="text-sm text-destructive">{createError}</p>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => createMutation.mutate(newStore)}
              disabled={!newStore.ownerId || !newStore.name || createMutation.isPending}
            >
              Создать
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
```

The `UserPicker` needs a label association for the test's `getByLabelText('Владелец')` to work. If `UserPicker` does not forward an `id`, wrap it so the `Label` points at its input — check `admin/components/user-picker.tsx` and adapt the test selector to what the component actually renders rather than forcing the component to change.

- [ ] **Step 5: Run the tests**

```bash
npm test -- stores/page.test.tsx
```
Expected: all pass, including the pre-existing suspend/transfer/export tests, which must not have been disturbed.

- [ ] **Step 6: Commit**

```bash
git add "admin/app/(admin)/stores/page.tsx" "admin/app/(admin)/stores/page.test.tsx"
git commit -m "feat(admin-ui): create a store for an existing user

Reuses the existing UserPicker the transfer dialog already uses rather
than adding a second owner-selection control. Server validation errors
render inline next to the field, since an unknown owner is a recoverable
mistake rather than a transient failure.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Change-tariff dialog in the admin UI

**Files:**
- Modify: `admin/app/(admin)/stores/page.tsx`
- Modify: `admin/app/(admin)/stores/page.test.tsx`

- [ ] **Step 1: Write the failing test**

Append to `admin/app/(admin)/stores/page.test.tsx`:

```tsx
describe('StoresPage — change tariff', () => {
  it('preloads the current subscription and PUTs plan, status and period together', async () => {
    const user = userEvent.setup();
    let put: Record<string, unknown> | null = null;
    server.use(
      http.get(`${API_URL}/admin/stores/s1/subscription`, () =>
        HttpResponse.json({
          plan: 'PREMIUM',
          status: 'TRIAL',
          currentPeriodEnd: '2026-01-08T00:00:00.000Z',
        }),
      ),
      http.put(`${API_URL}/admin/stores/s1/subscription`, async ({ request }) => {
        put = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ plan: 'BUSINESS', status: 'ACTIVE' });
      }),
    );

    mockSingleStore(true);
    renderWithQuery(<StoresPage />);
    await user.click(await screen.findByRole('button', { name: /Действия|menu/i }));
    await user.click(await screen.findByText('Тариф'));

    // The dialog must show what the plan is changing FROM.
    expect(await screen.findByText(/PREMIUM/)).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Тариф'), 'BUSINESS');
    await user.selectOptions(screen.getByLabelText('Статус'), 'ACTIVE');
    await user.clear(screen.getByLabelText('Действует до'));
    await user.type(screen.getByLabelText('Действует до'), '2027-01-01');
    await user.click(screen.getByRole('button', { name: 'Сохранить' }));

    await waitFor(() => expect(put).not.toBeNull());
    expect(put).toMatchObject({ plan: 'BUSINESS', status: 'ACTIVE' });
    expect(String((put as Record<string, string>).currentPeriodEnd)).toContain('2027-01-01');
  });
});
```

The row-action trigger name depends on how the existing dropdown renders — read the suspend test in the same file and copy its way of opening the menu rather than guessing.

- [ ] **Step 2: Run it and confirm it fails**

```bash
npm test -- stores/page.test.tsx
```
Expected: FAIL — no `Тариф` action.

- [ ] **Step 3: Implement the dialog**

Add state and mutation in `admin/app/(admin)/stores/page.tsx`:

```tsx
  const [tariffDialog, setTariffDialog] = useState<Store | null>(null);
  const [tariff, setTariff] = useState({ plan: '', status: '', currentPeriodEnd: '' });
  const [tariffError, setTariffError] = useState<string | null>(null);

  const { data: currentSub } = useQuery({
    queryKey: ['admin-store-subscription', tariffDialog?.id],
    // api.get already returns parsed JSON — there is no axios `{ data }`
    // envelope to unwrap.
    queryFn: () => api.get(`/admin/stores/${tariffDialog!.id}/subscription`),
    enabled: !!tariffDialog,
  });

  useEffect(() => {
    if (currentSub) {
      setTariff({
        plan: currentSub.plan ?? 'START',
        status: currentSub.status ?? 'ACTIVE',
        currentPeriodEnd: (currentSub.currentPeriodEnd ?? '').slice(0, 10),
      });
    }
  }, [currentSub]);

  const tariffMutation = useMutation({
    mutationFn: (body: { plan: string; status: string; currentPeriodEnd: string }) =>
      api.put(`/admin/stores/${tariffDialog!.id}/subscription`, {
        plan: body.plan,
        status: body.status,
        // The API expects a full ISO datetime; the date input gives YYYY-MM-DD.
        currentPeriodEnd: new Date(`${body.currentPeriodEnd}T00:00:00.000Z`).toISOString(),
      }),
    onSuccess: () => {
      toast.success('Тариф обновлён');
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      setTariffDialog(null);
      setTariffError(null);
    },
    onError: (e: unknown) => {
      // Same shape note as the create dialog: lib/api.ts throws a plain Error.
      setTariffError(e instanceof Error ? e.message : 'Не удалось обновить тариф');
    },
  });
```

Add `useEffect` to the React import at the top of the file if it is not already there.

Add the row action inside the existing dropdown, beside the suspend and transfer items:

```tsx
                <DropdownMenuItem onClick={() => setTariffDialog(s)}>
                  Тариф
                </DropdownMenuItem>
```

Add the dialog beside the others:

```tsx
      <Dialog
        open={!!tariffDialog}
        onOpenChange={(o) => { if (!o) { setTariffDialog(null); setTariffError(null); } }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Тариф магазина</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{tariffDialog?.name}</strong>
              {currentSub?.plan && <> · текущий тариф: <strong>{currentSub.plan}</strong></>}
            </p>
            <div className="space-y-2">
              <Label htmlFor="tariff-plan">Тариф</Label>
              <select
                id="tariff-plan"
                className="w-full rounded-md border px-3 py-2 text-sm"
                value={tariff.plan}
                onChange={(e) => setTariff((t) => ({ ...t, plan: e.target.value }))}
              >
                <option value="START">START</option>
                <option value="BUSINESS">BUSINESS</option>
                <option value="PREMIUM">PREMIUM</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="tariff-status">Статус</Label>
              <select
                id="tariff-status"
                className="w-full rounded-md border px-3 py-2 text-sm"
                value={tariff.status}
                onChange={(e) => setTariff((t) => ({ ...t, status: e.target.value }))}
              >
                <option value="TRIAL">TRIAL</option>
                <option value="ACTIVE">ACTIVE</option>
                <option value="PAST_DUE">PAST_DUE</option>
                <option value="CANCELLED">CANCELLED</option>
                <option value="EXPIRED">EXPIRED</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="tariff-until">Действует до</Label>
              <Input
                id="tariff-until"
                type="date"
                value={tariff.currentPeriodEnd}
                onChange={(e) => setTariff((t) => ({ ...t, currentPeriodEnd: e.target.value }))}
              />
            </div>
            {tariffError && <p className="text-sm text-destructive">{tariffError}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTariffDialog(null)}>
              Отмена
            </Button>
            <Button
              onClick={() => tariffMutation.mutate(tariff)}
              disabled={!tariff.plan || !tariff.status || !tariff.currentPeriodEnd || tariffMutation.isPending}
            >
              Сохранить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
```

- [ ] **Step 4: Run the tests**

```bash
npm test -- stores/page.test.tsx
```
Expected: all pass, including everything from Task 3 and the pre-existing suites.

- [ ] **Step 5: Lint and typecheck the admin app**

```bash
npm run lint
npx tsc --noEmit
```
Expected: both clean.

- [ ] **Step 6: Commit**

```bash
git add "admin/app/(admin)/stores/page.tsx" "admin/app/(admin)/stores/page.test.tsx"
git commit -m "feat(admin-ui): assign or change a store tariff

The dialog preloads the current subscription and shows which plan the
change starts from. Plan, status and period are sent together because
the entitlement guards consult all three — sending the plan alone would
look like it worked and change nothing.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Whole-feature verification

**Files:** none modified unless a defect is found.

- [ ] **Step 1: API suite, lint, typecheck**

```bash
cd api
npm test
npm run lint
npx tsc --noEmit
```
Expected: green. Report the test counts.

- [ ] **Step 2: Admin suite, lint, typecheck**

```bash
cd ../admin
npm test
npm run lint
npx tsc --noEmit
```
Expected: green. Report the test counts.

- [ ] **Step 3: Assert the Flutter app was not touched**

```bash
cd ..
git diff --stat main...HEAD -- app/
```
Expected: **empty output**. This work is API + admin only; any `app/` change is out of scope and must be explained or reverted.

- [ ] **Step 4: Assert the Prisma schema was not touched**

```bash
git diff --stat main...HEAD -- api/prisma/
```
Expected: **empty output**. `Store` and `Subscription` already carry every field used, so a schema change here would mean the design was misread.

- [ ] **Step 5: Exercise both routes against the running API**

The API is on `:4455` under prefix `api`, Postgres on `:5435`. Get an admin token the same way the admin panel does, then:

```bash
# replace $TOKEN and $OWNER_ID with real values
curl -s -X POST http://localhost:4455/api/admin/stores \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"ownerId":"'$OWNER_ID'","name":"Проверочный магазин","category":"GROCERY"}' | head -c 400
```
Expected: the created store with a `subscription` of `PREMIUM`/`TRIAL`.

```bash
curl -s -X PUT http://localhost:4455/api/admin/stores/$STORE_ID/subscription \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"plan":"BUSINESS","status":"ACTIVE","currentPeriodEnd":"2027-01-01T00:00:00.000Z"}' | head -c 400
```
Expected: the subscription with `plan: BUSINESS`, `status: ACTIVE`, and the new period end.

- [ ] **Step 6: Confirm both routes produced audit entries**

```bash
curl -s "http://localhost:4455/api/admin/audit-log?limit=10" \
  -H "Authorization: Bearer $TOKEN" | head -c 600
```
Expected: entries for the `POST /admin/stores` and `PUT /admin/stores/:id/subscription` calls from Step 5. **If they are absent, that is a finding** — the audit interceptor was supposed to cover these for free, and its absence would mean the routes were declared somewhere that bypasses the class-level interceptor.

- [ ] **Step 7: Confirm the entitlement change is real, not cosmetic**

Pick a `PREMIUM`-only feature flag from `SubscriptionPlanConfig` (for example `hasEcommerceIntegration`) and confirm the store you just moved to `BUSINESS` is now refused it by the API, where it would have been allowed on `PREMIUM`.

This is the check that distinguishes "the plan field changed" from "the tariff actually changed". If the guard still allows it, the plan/status/period triple is not being consulted the way this plan assumes, and that is a defect worth finding here rather than during account testing.

- [ ] **Step 8: Commit only if something needed fixing**

If Steps 1–7 are clean there is nothing to commit. Otherwise fix, re-run Steps 1–7, and commit with a message naming what was wrong.

---

## Notes for the executor

- **Delegation is the point of Task 1.** `StoresService.create` also creates the subscription and the `OWNER` staff row. If you find yourself writing `prisma.store.create` in `AdminService`, stop — you are building the second creation path this plan exists to avoid.
- **Requiring status and period in Task 2 is deliberate, not over-engineering.** Making them optional is the natural instinct and it produces a feature that appears to work and silently does not, because the entitlement guards read all three.
- **Reuse `UserPicker`.** The transfer dialog already solves owner selection. A second picker would be two components to keep in sync for no gain.
- **The invalidation key is `['stores']`**, verified at `page.tsx:78` where the page's `useQuery` declares it and where the existing suspend and transfer mutations invalidate it. Invalidating a key nothing uses fails silently — the list just looks stale.
- **`lib/api.ts` is a fetch wrapper, not axios.** It routes through `/api/proxy/<path>` and throws `new Error(data.message || 'HTTP <status>')`. So error messages live on `.message`, there is no `e.response.data`, and `api.get` returns parsed JSON with no `{ data }` envelope to unwrap. Writing axios-shaped code here compiles and silently never renders the error.
- **The existing tests in `stores/page.test.tsx` are a contract.** Suspend, transfer and export tests must keep passing untouched. Needing to edit one means your change altered behaviour they pin.
- **Out of scope by decision, not oversight:** `adminDiscount`, `Payment` records, creating a user inline from the store dialog, and any Prisma schema change.
