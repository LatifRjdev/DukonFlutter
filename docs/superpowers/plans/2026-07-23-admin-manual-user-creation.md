# Admin Manual User Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an admin create a user account (and optionally a first store for them) directly from the admin panel, for support/onboarding and QA use cases.

**Architecture:** New `POST /admin/users` endpoint in the existing `admin` NestJS module, reusing `StoresService.create()` (extended to accept an optional transaction client so user+store creation is atomic) and the existing `IsStrongPassword`/`RegisterDto`/`CreateStoreDto` validation conventions. A pre-existing security gap in `AuditInterceptor` (logs raw request bodies, including any password field) is fixed first since this feature is the first admin write with a password in its body. Frontend: a new dialog on the existing `admin/app/(admin)/users/page.tsx`, following the codebase's established `useState` + shadcn `Dialog` + TanStack Query `useMutation` pattern (no react-hook-form/zod in this codebase — plain controlled inputs).

**Tech Stack:** NestJS + Prisma (backend, `api/`), Next.js 16 (App Router) + TanStack Query + shadcn/ui + Vitest/RTL/MSW (frontend, `admin/`).

---

### Task 1: Redact sensitive fields in `AuditInterceptor`

**Files:**
- Modify: `api/src/common/interceptors/audit.interceptor.ts`
- Test: `api/src/common/interceptors/audit.interceptor.spec.ts` (new)

`AuditInterceptor` currently writes `request.body` verbatim into `audit_log.details` for every admin `POST/PUT/PATCH/DELETE`. No admin endpoint has ever accepted a password field in its body before — Task 4 in this plan introduces the first one (`POST /admin/users`, where an admin can type a password manually). Without this fix, that password would be persisted in plaintext in the audit log, violating the project's own security rule ("Never log tokens, passwords, or PII"). Fixing this first, standalone, keeps it independently testable and reviewable before it's ever exercised by real traffic.

- [ ] **Step 1: Write the failing test**

```typescript
// api/src/common/interceptors/audit.interceptor.spec.ts
import 'reflect-metadata';
import { of } from 'rxjs';
import { CallHandler, ExecutionContext } from '@nestjs/common';
import { AuditInterceptor } from './audit.interceptor';
import { PrismaService } from '../../prisma/prisma.service';

function makeContext(opts: {
  method: string;
  url: string;
  body?: Record<string, unknown>;
  routePath?: string;
  userId?: string;
}): ExecutionContext {
  const request = {
    method: opts.method,
    url: opts.url,
    body: opts.body,
    route: { path: opts.routePath ?? opts.url },
    params: {},
    user: opts.userId ? { id: opts.userId } : undefined,
    headers: {},
  };
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

function makeCallHandler(): CallHandler {
  return { handle: () => of({ ok: true }) };
}

describe('AuditInterceptor — sensitive field redaction', () => {
  let prisma: { auditLog: { create: jest.Mock } };
  let interceptor: AuditInterceptor;

  beforeEach(() => {
    prisma = { auditLog: { create: jest.fn(async () => ({})) } };
    interceptor = new AuditInterceptor(prisma as unknown as PrismaService);
  });

  it('should redact a password field before writing to the audit log', (done) => {
    const ctx = makeContext({
      method: 'POST',
      url: '/admin/users',
      routePath: '/admin/users',
      userId: 'admin-1',
      body: { name: 'Али', phone: '+992901234567', password: 'SuperSecret123' },
    });

    interceptor.intercept(ctx, makeCallHandler()).subscribe(() => {
      setImmediate(() => {
        const call = prisma.auditLog.create.mock.calls[0][0];
        expect(call.data.details.password).toBe('[REDACTED]');
        expect(call.data.details.name).toBe('Али');
        expect(call.data.details.phone).toBe('+992901234567');
        done();
      });
    });
  });

  it('should leave a body with no sensitive fields untouched', (done) => {
    const ctx = makeContext({
      method: 'PUT',
      url: '/admin/subscriptions/sub-1/extend',
      routePath: '/admin/subscriptions/:id/extend',
      userId: 'admin-1',
      body: { days: 30 },
    });

    interceptor.intercept(ctx, makeCallHandler()).subscribe(() => {
      setImmediate(() => {
        const call = prisma.auditLog.create.mock.calls[0][0];
        expect(call.data.details).toEqual({ days: 30 });
        done();
      });
    });
  });

  it('should pass through a null body unchanged', (done) => {
    const ctx = makeContext({
      method: 'DELETE',
      url: '/admin/users/u1',
      routePath: '/admin/users/:id',
      userId: 'admin-1',
    });

    interceptor.intercept(ctx, makeCallHandler()).subscribe(() => {
      setImmediate(() => {
        const call = prisma.auditLog.create.mock.calls[0][0];
        expect(call.data.details).toBeNull();
        done();
      });
    });
  });
});
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/common/interceptors/audit.interceptor.spec.ts --no-coverage
```

Expected: FAIL on the first test — `details.password` is currently `'SuperSecret123'`, not `'[REDACTED]'`.

- [ ] **Step 3: Implement**

Replace the full content of `api/src/common/interceptors/audit.interceptor.ts` with:

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
  'token',
  'accessToken',
  'refreshToken',
]);

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

    return next.handle().pipe(
      tap(() => {
        const userId: string = request.user?.id ?? 'unknown';
        const routePath: string = request.route?.path ?? request.url ?? '';
        const action = this.deriveAction(routePath, method);
        const entityType = this.deriveEntityType(routePath);
        const entityId: string | undefined =
          request.params?.id ?? request.params?.plan ?? undefined;
        const ip: string =
          request.ip ?? request.headers?.['x-forwarded-for'] ?? undefined;

        // Fire-and-forget — never block the response
        this.prisma.auditLog
          .create({
            data: {
              userId,
              action,
              entityType,
              entityId,
              details: this.redact(request.body) ?? null,
              ip,
            },
          })
          .catch(() => {
            // silently ignore audit write errors
          });
      }),
    );
  }

  // Shallow-clones the request body and replaces any top-level sensitive
  // field with a fixed marker, so the audit trail records that a value
  // was present without persisting the value itself.
  private redact(body: unknown): unknown {
    if (!body || typeof body !== 'object') return body;
    const clone: Record<string, unknown> = { ...(body as Record<string, unknown>) };
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

The only change from the current file: the new `SENSITIVE_FIELDS` set, the new private `redact()` method, and `details: this.redact(request.body) ?? null` replacing the old `details: request.body ?? null`. Everything else (route matching, action/entityType derivation, fire-and-forget error swallowing) is unchanged.

- [ ] **Step 4: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/common/interceptors/audit.interceptor.spec.ts --no-coverage
```

Expected: PASS, 3/3.

- [ ] **Step 5: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/common/interceptors/audit.interceptor.ts api/src/common/interceptors/audit.interceptor.spec.ts
git commit -m "fix(admin): redact password/token fields from audit log details"
```

---

### Task 2: `StoresService.create()` accepts an optional transaction client

**Files:**
- Modify: `api/src/modules/stores/stores.service.ts`
- Test: `api/src/modules/stores/stores.service.spec.ts`

Task 4 needs to create a `User` and (optionally) a `Store` atomically — if store creation fails, the user must not be left orphaned with a phone number that's now permanently "taken" but has no usable account behind it. `StoresService.create()` is the single existing place that knows how to build a store + trial subscription + OWNER staff row correctly; rather than duplicating that logic, this task makes it transaction-aware so it can be called from inside `prisma.$transaction(async (tx) => ...)` while remaining fully backward compatible for its existing caller (`StoresController`, which doesn't pass a `tx`).

- [ ] **Step 1: Write the failing test**

Add to `api/src/modules/stores/stores.service.spec.ts`, inside the existing `describe('create', ...)` block (find it and add this test alongside the two existing ones there):

```typescript
    it('should use the provided transaction client instead of the default prisma client when one is passed', async () => {
      const txStoreCreate = jest.fn(async ({ data }: any) => ({
        id: 'tx-store-1',
        ownerId: data.owner.connect.id,
        name: data.name,
        category: data.category,
        currency: data.currency ?? 'TJS',
        address: data.address ?? null,
        phone: data.phone ?? null,
        isActive: true,
        settings: null,
        createdAt: new Date(),
        subscription: null,
      }));
      const fakeTx = { store: { create: txStoreCreate } };

      const dto = { name: 'Tx Store', category: 'GROCERY' } as any;
      const result = await service.create('owner-1', dto, fakeTx as any);

      expect(txStoreCreate).toHaveBeenCalledTimes(1);
      expect(result.id).toBe('tx-store-1');
      // The default prisma fake's store.create must NOT have been called —
      // proves the tx client was actually used, not just accepted and ignored.
      expect(prisma.store.create).not.toHaveBeenCalled();
    });
```

Read the existing two tests in that `describe('create', ...)` block first (`makePrismaFake()`'s `store.create` fake, and how `service`/`prisma` are set up in the outer `describe('StoresService', ...)`'s `beforeEach`) to make sure this new test's assertions on `prisma.store.create` reference the correct fake object — match whatever variable name the existing tests use.

- [ ] **Step 2: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/stores/stores.service.spec.ts -t "transaction client" --no-coverage
```

Expected: FAIL — `service.create` currently only accepts 2 arguments, so the 3rd argument is silently ignored and `prisma.store.create` (the default, non-tx one) is called instead.

- [ ] **Step 3: Implement**

In `api/src/modules/stores/stores.service.ts`, add `Prisma` to the imports:

```typescript
import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { CreateStoreDto } from './dto/create-store.dto';
import { UpdateStoreDto } from './dto/update-store.dto';
import { ReceiptTemplateDto } from './dto/receipt-template.dto';
```

Change the `create` method signature and body:

```typescript
  async create(
    ownerId: string,
    dto: CreateStoreDto,
    tx?: Prisma.TransactionClient,
  ) {
    const client = tx ?? this.prisma;
    const now = new Date();
    const trialEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    return client.store.create({
      data: {
        owner: { connect: { id: ownerId } },
        name: dto.name,
        category: dto.category as any,
        currency: (dto.currency as any) || 'TJS',
        address: dto.address,
        phone: dto.phone,
        subscription: {
          create: {
            plan: 'PREMIUM',
            status: 'TRIAL',
            trialEndsAt: trialEnd,
            currentPeriodStart: now,
            currentPeriodEnd: trialEnd,
          },
        },
        staff: {
          create: {
            user: { connect: { id: ownerId } },
            role: 'OWNER',
          },
        },
      },
      include: {
        subscription: true,
      },
    });
  }
```

The only change from the current method: the new `tx?: Prisma.TransactionClient` parameter and the `const client = tx ?? this.prisma;` line, with every `this.prisma.store.create` in this method changed to `client.store.create`. Nothing else in the method body changes.

- [ ] **Step 4: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/stores/stores.service.spec.ts --no-coverage
```

Expected: PASS, all tests in the file including the 1 new one.

- [ ] **Step 5: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/stores/stores.service.ts api/src/modules/stores/stores.service.spec.ts
git commit -m "feat(stores): allow StoresService.create to run inside an external transaction"
```

---

### Task 3: `CreateUserByAdminDto`

**Files:**
- Create: `api/src/modules/admin/dto/create-user-by-admin.dto.ts`

No dedicated test file — this codebase has no precedent for unit-testing DTOs standalone (validated implicitly by NestJS's global `ValidationPipe` and exercised through the service/controller tests in Task 4/5, consistent with how `RegisterDto` and `CreateStoreDto` are handled).

- [ ] **Step 1: Create the DTO**

```typescript
// api/src/modules/admin/dto/create-user-by-admin.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsBoolean,
  IsEnum,
  Matches,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { IsStrongPassword } from '../../../common/validators/strong-password.validator';
import { IsSafeText } from '../../../common/validators/safe-text.validator';

const STORE_CATEGORIES = [
  'GROCERY',
  'CLOTHING',
  'ELECTRONICS',
  'HARDWARE',
  'PHARMACY',
  'OTHER',
];

export class CreateUserByAdminDto {
  @ApiProperty({ example: 'Али Рахимов' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(80)
  @IsSafeText()
  name: string;

  @ApiProperty({ example: '+992901234567' })
  @IsNotEmpty()
  @Matches(/^\+992\d{9}$/, {
    message: 'Phone must be a valid Tajik number (+992XXXXXXXXX)',
  })
  phone: string;

  @ApiPropertyOptional({ example: 'ali@example.com' })
  @IsOptional()
  @IsString()
  email?: string;

  @ApiPropertyOptional({
    description:
      'If omitted, a strong password is generated server-side and returned once in the response.',
    example: 'CorrectHorseBatteryStaple8',
  })
  @IsOptional()
  @IsStrongPassword(['phone', 'email'])
  password?: string;

  @ApiPropertyOptional({
    description: 'Also create a first store for this user in the same request.',
  })
  @IsOptional()
  @IsBoolean()
  createStore?: boolean;

  @ApiPropertyOptional({ example: 'Мой магазин' })
  @ValidateIf((o) => o.createStore === true)
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  @IsSafeText()
  storeName?: string;

  @ApiPropertyOptional({ enum: STORE_CATEGORIES })
  @ValidateIf((o) => o.createStore === true)
  @IsNotEmpty()
  @IsEnum(STORE_CATEGORIES)
  storeCategory?: string;

  @ApiPropertyOptional({ enum: ['TJS', 'USD', 'RUB'], default: 'TJS' })
  @IsOptional()
  @IsEnum(['TJS', 'USD', 'RUB'], {
    message: 'storeCurrency must be one of: TJS, USD, RUB',
  })
  storeCurrency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @IsSafeText()
  storeAddress?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^\+?\d{9,15}$/)
  storePhone?: string;
}
```

- [ ] **Step 2: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit
```

Expected: 0 errors (this file isn't imported anywhere yet, so it just needs to compile standalone).

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/admin/dto/create-user-by-admin.dto.ts
git commit -m "feat(admin): add CreateUserByAdminDto"
```

---

### Task 4: `AdminService.createUserManually()` + `AdminModule` wiring

**Files:**
- Modify: `api/src/modules/admin/admin.service.ts`
- Modify: `api/src/modules/admin/admin.module.ts`
- Modify: `api/src/modules/admin/admin.service.spec.ts` (existing `Test.createTestingModule` needs a `StoresService` fake added to its providers, since `AdminService`'s constructor gains a new required dependency)
- Test: `api/src/modules/admin/admin.users-create.spec.ts` (new)

- [ ] **Step 1: Update `admin.service.spec.ts`'s existing providers list so it keeps compiling**

`AdminService`'s constructor is about to gain a `StoresService` dependency. `admin.service.spec.ts` already constructs `AdminService` via `Test.createTestingModule` with only `PrismaService` and `NotificationsService` provided — without an update, NestJS will fail to resolve `StoresService` and every test in that file will start failing at `beforeEach`, even though none of them touch the new method. Add a fake:

In `api/src/modules/admin/admin.service.spec.ts`, add an import and a provider:

```typescript
import { StoresService } from '../stores/stores.service';
```

And in the `providers` array inside `Test.createTestingModule`:

```typescript
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
```

- [ ] **Step 2: Run, verify existing tests still pass with the new fake in place**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/admin/admin.service.spec.ts --no-coverage
```

Expected: PASS, all existing tests (this step alone shouldn't change behavior — it's just keeping the module compilable ahead of Step 4's constructor change). If this fails right now with "Nest can't resolve dependencies", that confirms the fix is necessary and correctly targeted; if it fails for some other reason, stop and investigate before continuing.

- [ ] **Step 3: Write the failing tests for the new method**

```typescript
// api/src/modules/admin/admin.users-create.spec.ts
import 'reflect-metadata';
import { ConflictException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake() {
  const users = new Map<string, any>();
  let userSeq = 0;

  return {
    _users: users,
    user: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.phone) {
          return [...users.values()].find((u) => u.phone === where.phone) ?? null;
        }
        return users.get(where.id) ?? null;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `user-${++userSeq}`;
        const row = {
          id,
          phone: data.phone,
          name: data.name,
          email: data.email ?? null,
          isAdmin: false,
          isActive: true,
          password: data.password,
          createdAt: new Date(),
        };
        users.set(id, row);
        return row;
      }),
    },
    $transaction: jest.fn(async (fn: any) => fn({
      user: {
        create: jest.fn(async ({ data }: any) => {
          const id = `user-${++userSeq}`;
          const row = {
            id,
            phone: data.phone,
            name: data.name,
            email: data.email ?? null,
            isAdmin: false,
            isActive: true,
            password: data.password,
            createdAt: new Date(),
          };
          users.set(id, row);
          return row;
        }),
      },
    })),
  } as any;
}

describe('AdminService.createUserManually', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let storesService: { create: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    storesService = {
      create: jest.fn(async (ownerId: string, dto: any) => ({
        id: 'store-1',
        ownerId,
        name: dto.name,
        category: dto.category,
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

  it('should create a user with the admin-provided password and not generate one', async () => {
    const result = await service.createUserManually({
      name: 'Али',
      phone: '+992901234567',
      password: 'CorrectHorseBatteryStaple8',
    } as any);

    expect(result.user.phone).toBe('+992901234567');
    expect(result.generatedPassword).toBeNull();
    expect(result.store).toBeNull();
    expect(storesService.create).not.toHaveBeenCalled();
  });

  it('should generate a strong password and return it once when none is provided', async () => {
    const result = await service.createUserManually({
      name: 'Зарина',
      phone: '+992901234568',
    } as any);

    expect(typeof result.generatedPassword).toBe('string');
    expect(result.generatedPassword!.length).toBeGreaterThanOrEqual(12);
  });

  it('should throw ConflictException when the phone is already taken', async () => {
    await service.createUserManually({
      name: 'Первый',
      phone: '+992901234569',
      password: 'CorrectHorseBatteryStaple8',
    } as any);

    await expect(
      service.createUserManually({
        name: 'Второй',
        phone: '+992901234569',
        password: 'AnotherStrongOne9',
      } as any),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('should create a store via StoresService.create when createStore is true, inside the same transaction', async () => {
    const result = await service.createUserManually({
      name: 'Владелец',
      phone: '+992901234570',
      password: 'CorrectHorseBatteryStaple8',
      createStore: true,
      storeName: 'Мой магазин',
      storeCategory: 'GROCERY',
    } as any);

    expect(storesService.create).toHaveBeenCalledTimes(1);
    const [ownerIdArg, dtoArg, txArg] = storesService.create.mock.calls[0];
    expect(ownerIdArg).toBe(result.user.id);
    expect(dtoArg.name).toBe('Мой магазин');
    expect(dtoArg.category).toBe('GROCERY');
    // Proves the transaction client (not the top-level prisma) was passed through.
    expect(txArg).toBeDefined();
    expect(txArg).not.toBe(prisma);
    expect(result.store).toEqual({ id: 'store-1', name: 'Мой магазин' });
  });

  it('should not include the raw or hashed password anywhere in the returned user object', async () => {
    const result = await service.createUserManually({
      name: 'Секьюр',
      phone: '+992901234571',
      password: 'CorrectHorseBatteryStaple8',
    } as any);

    expect(result.user).not.toHaveProperty('password');
  });
});
```

- [ ] **Step 4: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/admin/admin.users-create.spec.ts --no-coverage
```

Expected: FAIL — `service.createUserManually` is not a function.

- [ ] **Step 5: Implement**

In `api/src/modules/admin/admin.service.ts`, add imports:

```typescript
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { ConflictException } from '@nestjs/common';
import { StoresService } from '../stores/stores.service';
import { CreateUserByAdminDto } from './dto/create-user-by-admin.dto';
```

(`ConflictException` joins the existing `Injectable, NotFoundException, BadRequestException` import from `@nestjs/common` — merge into that same import statement rather than adding a second one.)

Update the constructor:

```typescript
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly storesService: StoresService,
  ) {}
```

Add this method to the `// ============ USERS ============` section, right after `listUsers`:

```typescript
  async createUserManually(dto: CreateUserByAdminDto) {
    const existing = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new ConflictException('User with this phone already exists');
    }

    const passwordWasGenerated = !dto.password;
    const rawPassword = dto.password ?? this.generateRandomPassword();
    const hashedPassword = await bcrypt.hash(rawPassword, 12);

    const { user, store } = await this.prisma.$transaction(async (tx) => {
      const createdUser = await tx.user.create({
        data: {
          phone: dto.phone,
          password: hashedPassword,
          name: dto.name,
          email: dto.email,
        },
      });

      let createdStore: { id: string; name: string } | null = null;
      if (dto.createStore) {
        const storeResult = await this.storesService.create(
          createdUser.id,
          {
            name: dto.storeName!,
            category: dto.storeCategory!,
            currency: dto.storeCurrency,
            address: dto.storeAddress,
            phone: dto.storePhone,
          },
          tx,
        );
        createdStore = { id: storeResult.id, name: storeResult.name };
      }

      return { user: createdUser, store: createdStore };
    });

    return {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        email: user.email,
        isAdmin: user.isAdmin,
      },
      store,
      generatedPassword: passwordWasGenerated ? rawPassword : null,
    };
  }

  // Used only when the admin leaves the password field blank — generates
  // a password that trivially satisfies IsStrongPassword (length >= 8,
  // not a common password, doesn't match phone/email) without needing
  // any coordination with that validator. 16 chars from a mixed
  // alphanumeric+symbol set is far above the minimum bar on purpose:
  // this password is shown to the admin once and handed to the end user,
  // it's never chosen or memorized by a human, so there's no usability
  // cost to making it long.
  private generateRandomPassword(): string {
    const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
    const bytes = crypto.randomBytes(16);
    let password = '';
    for (let i = 0; i < 16; i++) {
      password += chars[bytes[i] % chars.length];
    }
    return password;
  }
```

In `api/src/modules/admin/admin.module.ts`, import `StoresModule`:

```typescript
import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminStoresController } from './admin-stores.controller';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminPlansController } from './admin-plans.controller';
import { AdminAnnouncementsController } from './admin-announcements.controller';
import { AdminAuditLogController } from './admin-audit-log.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { StoresModule } from '../stores/stores.module';
import { AuditInterceptor } from '../../common/interceptors/audit.interceptor';

@Module({
  imports: [NotificationsModule, StoresModule],
  controllers: [
    AdminUsersController,
    AdminStoresController,
    AdminDashboardController,
    AdminPlansController,
    AdminAnnouncementsController,
    AdminAuditLogController,
  ],
  providers: [AdminService, AuditInterceptor],
  exports: [AdminService],
})
export class AdminModule {}
```

- [ ] **Step 6: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest src/modules/admin/admin.users-create.spec.ts src/modules/admin/admin.service.spec.ts --no-coverage
```

Expected: PASS, 5/5 in the new file, all existing tests in `admin.service.spec.ts` still passing.

- [ ] **Step 7: Full suite + typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit && npx jest --no-coverage
```

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/admin/admin.service.ts api/src/modules/admin/admin.module.ts api/src/modules/admin/admin.service.spec.ts api/src/modules/admin/admin.users-create.spec.ts
git commit -m "feat(admin): add AdminService.createUserManually with optional atomic store creation"
```

---

### Task 5: `POST /admin/users` endpoint

**Files:**
- Modify: `api/src/modules/admin/admin-users.controller.ts`

No new test file — thin wiring over the already-tested `AdminService.createUserManually`, consistent with how the other mutating routes in this same controller (`toggle-admin`, `block`, `unblock`, `delete`) have no dedicated controller-level tests.

- [ ] **Step 1: Add the import and route**

In `api/src/modules/admin/admin-users.controller.ts`, add one import:

```typescript
import { Post, Body } from '@nestjs/common';
```

Merge this into the existing `@nestjs/common` import at the top of the file (it currently imports `Controller, Get, Put, Delete, Param, Query, UseGuards, UseInterceptors` — add `Post, Body` to that same list rather than a second import statement) and add:

```typescript
import { CreateUserByAdminDto } from './dto/create-user-by-admin.dto';
```

Then add the new route, right after the `listUsers` handler (before `getUserDetail`):

```typescript
  @Post()
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @ApiOperation({ summary: 'Manually create a user account (optionally with a first store)' })
  createUser(@Body() dto: CreateUserByAdminDto) {
    return this.adminService.createUserManually(dto);
  }
```

(Throttle limit of 30/min rather than the 60/min used on `toggle-admin`/`block`/`unblock` — those are single-field toggles on existing rows, this creates new accounts, so a tighter cap is the more conservative default. Not a hard requirement from the design doc, just a sensible choice consistent with this being a heavier, harder-to-undo action.)

- [ ] **Step 2: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx tsc --noEmit
```

Expected: 0 errors.

- [ ] **Step 3: Full suite**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npx jest --no-coverage
```

Expected: all suites still pass (no test exercises this new route directly — that's fine, `AdminService.createUserManually` already has full coverage from Task 4).

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add api/src/modules/admin/admin-users.controller.ts
git commit -m "feat(admin): wire POST /admin/users endpoint"
```

---

### Task 6: Frontend types

**Files:**
- Modify: `admin/lib/types.ts`

- [ ] **Step 1: Add the request/response types**

In `admin/lib/types.ts`, add these two interfaces near the existing `User` interface (read the file first to place them sensibly relative to `User`/`Store`):

```typescript
export interface CreateUserByAdminInput {
  name: string;
  phone: string;
  email?: string;
  password?: string;
  createStore?: boolean;
  storeName?: string;
  storeCategory?: string;
  storeCurrency?: string;
  storeAddress?: string;
  storePhone?: string;
}

export interface CreateUserByAdminResult {
  user: {
    id: string;
    phone: string;
    name: string;
    email: string | null;
    isAdmin: boolean;
  };
  store: { id: string; name: string } | null;
  generatedPassword: string | null;
}
```

- [ ] **Step 2: Typecheck**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/admin && npx tsc --noEmit
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add admin/lib/types.ts
git commit -m "feat(admin-web): add types for manual user creation"
```

---

### Task 7: "Создать пользователя" dialog on the Users page

**Files:**
- Modify: `admin/app/(admin)/users/page.tsx`
- Test: `admin/app/(admin)/users/page.test.tsx`

**Before starting this task**: this Next.js version has breaking changes vs. standard Next.js per `admin/AGENTS.md` — read `node_modules/next/dist/docs/` for anything touching routing/middleware conventions before writing code, though this task only touches an existing client component (`page.tsx`) and doesn't add new routes/middleware, so the risk surface is small. Still worth a quick check on `Dialog`/form-related API changes if any are suspected.

- [ ] **Step 1: Read the current file and existing dialog/mutation patterns**

Read `admin/app/(admin)/users/page.tsx` in full (already-known shape: `useQuery` for the list, `useMutation` + `toast` for `toggleAdminMutation`/`toggleBlockMutation`, a `DataTable` with `Column<User>[]`). Also read the "Extend Dialog" and "Change Plan Dialog" blocks in `admin/app/(admin)/subscriptions/page.tsx` (lines ~364-430) as the exact structural template for the new dialog: `Dialog`/`DialogContent`/`DialogHeader`/`DialogTitle`, a `div.space-y-3.py-2` body with `Label`+`Input`/`Select` pairs, `DialogFooter` with a Cancel `Button` (`variant="outline"`) and a primary `Button` disabled while the mutation is pending.

- [ ] **Step 2: Write the failing tests**

Add to `admin/app/(admin)/users/page.test.tsx`, as new `describe` blocks after the existing ones (keep all existing tests/mocks/helpers in the file exactly as they are — this only adds to the file):

```typescript
describe('UsersPage — manual user creation', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('opens the create-user dialog, submits a manual password, and shows a success toast (no password dialog)', async () => {
    mockSingleUser({ name: 'Existing User' });

    const createCalls: any[] = [];
    server.use(
      http.post(`${API_URL}/admin/users`, async ({ request }) => {
        const body = await request.json();
        createCalls.push(body);
        return HttpResponse.json({
          user: { id: 'u-new', phone: body.phone, name: body.name, email: null, isAdmin: false },
          store: null,
          generatedPassword: null,
        });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));

    await user.type(screen.getByLabelText(/имя/i), 'Новый Пользователь');
    await user.type(screen.getByLabelText(/телефон/i), '+992901112233');

    // Switch to manual password entry and type a password.
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'CorrectHorseBatteryStaple8');

    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() => expect(createCalls).toHaveLength(1));
    expect(createCalls[0]).toMatchObject({
      name: 'Новый Пользователь',
      phone: '+992901112233',
      password: 'CorrectHorseBatteryStaple8',
    });
    await waitFor(() =>
      expect(toastSuccess).toHaveBeenCalledWith('Пользователь создан'),
    );
    // No password-reveal dialog when the admin typed the password themselves.
    expect(screen.queryByText(/скопируйте/i)).not.toBeInTheDocument();
  });

  it('shows a one-time password dialog with a copy button when the server generates the password', async () => {
    mockSingleUser({ name: 'Existing User' });

    server.use(
      http.post(`${API_URL}/admin/users`, async ({ request }) => {
        const body = await request.json();
        return HttpResponse.json({
          user: { id: 'u-new', phone: body.phone, name: body.name, email: null, isAdmin: false },
          store: null,
          generatedPassword: 'gEnErAt3d!Pass9xYz',
        });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Сгенерированный');
    await user.type(screen.getByLabelText(/телефон/i), '+992901112244');
    // Password mode defaults to "generate" — submit without touching the switch.
    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() =>
      expect(screen.getByText('gEnErAt3d!Pass9xYz')).toBeInTheDocument(),
    );
    expect(screen.getByText(/больше не будет показан/i)).toBeInTheDocument();
  });

  it('reveals store fields when "Создать магазин сразу" is toggled on, and sends them on submit', async () => {
    mockSingleUser({ name: 'Existing User' });

    const createCalls: any[] = [];
    server.use(
      http.post(`${API_URL}/admin/users`, async ({ request }) => {
        const body = await request.json();
        createCalls.push(body);
        return HttpResponse.json({
          user: { id: 'u-new', phone: body.phone, name: body.name, email: null, isAdmin: false },
          store: { id: 'store-new', name: body.storeName },
          generatedPassword: null,
        });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Владелец');
    await user.type(screen.getByLabelText(/телефон/i), '+992901112255');
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'CorrectHorseBatteryStaple8');

    // Store fields must not be visible before the toggle.
    expect(screen.queryByLabelText(/название магазина/i)).not.toBeInTheDocument();

    await user.click(screen.getByRole('switch', { name: /создать магазин сразу/i }));
    expect(screen.getByLabelText(/название магазина/i)).toBeInTheDocument();
    await user.type(screen.getByLabelText(/название магазина/i), 'Магазин Алиевых');

    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() => expect(createCalls).toHaveLength(1));
    expect(createCalls[0]).toMatchObject({
      createStore: true,
      storeName: 'Магазин Алиевых',
    });
  });

  it('shows an error toast when the phone is already taken (409)', async () => {
    mockSingleUser({ name: 'Existing User' });

    server.use(
      http.post(`${API_URL}/admin/users`, () =>
        HttpResponse.json({ message: 'User with this phone already exists' }, { status: 409 }),
      ),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Дубликат');
    await user.type(screen.getByLabelText(/телефон/i), '+992900000001');
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'CorrectHorseBatteryStaple8');

    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() => expect(toastError).toHaveBeenCalled());
  });
});
```

- [ ] **Step 3: Run, verify it fails**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/admin && npx vitest run "app/(admin)/users/page.test.tsx"
```

Expected: FAIL — there's no "Создать пользователя" button yet.

- [ ] **Step 4: Implement**

In `admin/app/(admin)/users/page.tsx`, add these imports (merge into the existing import blocks where the same module is already imported — don't duplicate an import from a module already listed):

```typescript
import { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import { CreateUserByAdminInput, CreateUserByAdminResult } from '@/lib/types';
```

(`useState` is already imported in this file — merge `Dialog`/etc. imports in as new statements, don't re-import `useState`.)

Inside the `UsersPage` component function, add state and the create mutation, right after the existing `toggleBlockMutation`:

```typescript
  const STORE_CATEGORIES = [
    { value: 'GROCERY', label: 'Продукты' },
    { value: 'CLOTHING', label: 'Одежда' },
    { value: 'ELECTRONICS', label: 'Электроника' },
    { value: 'HARDWARE', label: 'Хозтовары' },
    { value: 'PHARMACY', label: 'Аптека' },
    { value: 'OTHER', label: 'Другое' },
  ];

  const [createOpen, setCreateOpen] = useState(false);
  const [createName, setCreateName] = useState('');
  const [createPhone, setCreatePhone] = useState('');
  const [createEmail, setCreateEmail] = useState('');
  const [manualPassword, setManualPassword] = useState(false);
  const [createPassword, setCreatePassword] = useState('');
  const [createStore, setCreateStore] = useState(false);
  const [storeName, setStoreName] = useState('');
  const [storeCategory, setStoreCategory] = useState('');
  const [revealedPassword, setRevealedPassword] = useState<string | null>(null);

  const resetCreateForm = () => {
    setCreateName('');
    setCreatePhone('');
    setCreateEmail('');
    setManualPassword(false);
    setCreatePassword('');
    setCreateStore(false);
    setStoreName('');
    setStoreCategory('');
  };

  const createUserMutation = useMutation({
    mutationFn: (input: CreateUserByAdminInput) =>
      api.post('/admin/users', input) as Promise<CreateUserByAdminResult>,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      setCreateOpen(false);
      resetCreateForm();
      if (result.generatedPassword) {
        setRevealedPassword(result.generatedPassword);
      } else {
        toast.success('Пользователь создан');
      }
    },
    onError: (error: Error) => toast.error(error.message || 'Ошибка создания пользователя'),
  });

  const handleCreateSubmit = () => {
    const input: CreateUserByAdminInput = {
      name: createName,
      phone: createPhone,
      email: createEmail || undefined,
      password: manualPassword ? createPassword : undefined,
      createStore,
      storeName: createStore ? storeName : undefined,
      storeCategory: createStore ? storeCategory : undefined,
    };
    createUserMutation.mutate(input);
  };
```

Update the header block (currently just an `<h1>`/`<p>`) to add the trigger button, right after the closing `</div>` of that header block and before the search/filter `<div>`:

```typescript
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Пользователи</h1>
          <p className="text-muted-foreground text-sm mt-1">
            {users.length} пользователей всего
          </p>
        </div>
        <Button onClick={() => setCreateOpen(true)}>Создать пользователя</Button>
      </div>
```

(Read the current file first — this replaces the existing plain `<div><h1>...</h1><p>...</p></div>` block with the `flex items-center justify-between` wrapper shown above, adding the button as a sibling. Don't duplicate the `<h1>`/`<p>`.)

Add the two dialogs at the end of the component's returned JSX, right after the closing `<DataTable ... />` tag and before the final closing `</div>`:

```typescript
      {/* Create User Dialog */}
      <Dialog
        open={createOpen}
        onOpenChange={(open) => {
          setCreateOpen(open);
          if (!open) resetCreateForm();
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Создать пользователя</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <div className="space-y-2">
              <Label htmlFor="create-name">Имя</Label>
              <Input
                id="create-name"
                value={createName}
                onChange={(e) => setCreateName(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-phone">Телефон</Label>
              <Input
                id="create-phone"
                placeholder="+992XXXXXXXXX"
                value={createPhone}
                onChange={(e) => setCreatePhone(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-email">Email</Label>
              <Input
                id="create-email"
                type="email"
                value={createEmail}
                onChange={(e) => setCreateEmail(e.target.value)}
              />
            </div>

            <div className="flex items-center justify-between">
              <Label htmlFor="manual-password-switch">Ввести самому</Label>
              <Switch
                id="manual-password-switch"
                checked={manualPassword}
                onCheckedChange={(checked) => setManualPassword(checked as boolean)}
              />
            </div>
            {manualPassword && (
              <div className="space-y-2">
                <Label htmlFor="create-password">Пароль</Label>
                <Input
                  id="create-password"
                  type="text"
                  value={createPassword}
                  onChange={(e) => setCreatePassword(e.target.value)}
                />
              </div>
            )}
            {!manualPassword && (
              <p className="text-sm text-muted-foreground">
                Пароль будет сгенерирован автоматически и показан один раз после создания.
              </p>
            )}

            <div className="flex items-center justify-between">
              <Label htmlFor="create-store-switch">Создать магазин сразу</Label>
              <Switch
                id="create-store-switch"
                checked={createStore}
                onCheckedChange={(checked) => setCreateStore(checked as boolean)}
              />
            </div>
            {createStore && (
              <>
                <div className="space-y-2">
                  <Label htmlFor="store-name">Название магазина</Label>
                  <Input
                    id="store-name"
                    value={storeName}
                    onChange={(e) => setStoreName(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Категория</Label>
                  <Select value={storeCategory} onValueChange={(v) => v != null && setStoreCategory(v)}>
                    <SelectTrigger>
                      <SelectValue placeholder="Выберите категорию" />
                    </SelectTrigger>
                    <SelectContent>
                      {STORE_CATEGORIES.map((c) => (
                        <SelectItem key={c.value} value={c.value}>
                          {c.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>
              Отмена
            </Button>
            <Button onClick={handleCreateSubmit} disabled={createUserMutation.isPending}>
              Создать
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* One-time generated password reveal */}
      <Dialog open={!!revealedPassword} onOpenChange={() => setRevealedPassword(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Пользователь создан</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Сохраните этот пароль — больше не будет показан.
            </p>
            <div className="flex items-center gap-2">
              <Input readOnly value={revealedPassword ?? ''} className="font-mono" />
              <Button
                variant="outline"
                onClick={() => {
                  if (revealedPassword) {
                    navigator.clipboard.writeText(revealedPassword);
                    toast.success('Пароль скопирован');
                  }
                }}
              >
                Копировать
              </Button>
            </div>
          </div>
          <DialogFooter>
            <Button onClick={() => setRevealedPassword(null)}>Готово</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
```

Read the actual current file structure before making this edit — the exact insertion points (where the header `<div>` block is, where `<DataTable ... />` closes) must match reality; the code above shows the intended final shape, adapt the surrounding JSX to fit precisely rather than guessing at line numbers.

- [ ] **Step 5: Run, verify it passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/admin && npx vitest run "app/(admin)/users/page.test.tsx"
```

Expected: PASS, all tests in the file including the 4 new ones.

- [ ] **Step 6: Typecheck + lint**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/admin && npx tsc --noEmit && npm run lint
```

Expected: 0 errors on both.

- [ ] **Step 7: Full test suite**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/admin && npm test
```

Expected: all suites pass, no regressions in other pages.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon && git add "admin/app/(admin)/users/page.tsx" "admin/app/(admin)/users/page.test.tsx"
git commit -m "feat(admin-web): add manual user creation dialog to Users page"
```

---

## Final check

- [ ] Backend: `cd api && npx tsc --noEmit && npx jest --no-coverage` — full suite green, 0 tsc errors.
- [ ] Frontend: `cd admin && npx tsc --noEmit && npm run lint && npm test` — all green.
- [ ] Manually walk through in the running admin panel (`http://localhost:3000/users`, logged in as an admin):
  1. Click "Создать пользователя" → fill name/phone → leave password on "generate" → submit → confirm a password-reveal dialog appears with a working "Копировать" button, and the new user shows up in the table on close.
  2. Repeat with "Ввести самому" toggled on and a manual password → confirm no reveal dialog, just a success toast, and the account can actually log in with that password (via the mobile app or `POST /api/auth/login`).
  3. Repeat with "Создать магазин сразу" toggled on → confirm the store fields appear, and after creation the new user's detail page (`/users/:id`) shows one owned store.
  4. Try creating a user with a phone number that already exists → confirm an error toast, no duplicate row created.
  5. Check `/audit-log` after a manual-password creation → confirm the `password` field shows `[REDACTED]`, not the real value.
