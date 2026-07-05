# Spec I — Carry-Forward Closures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close 3 verification gaps with tests-only changes — multi-currency coverage, subscription lifecycle edge cases, and CartBloc persistence behaviour — plus one manual QA doc. No migrations, no new endpoints, no UI changes.

**Architecture:** All work is additive tests. API tests follow the behavioral-fake pattern already established in the project (Map-backed Prisma fakes, not mocks). Flutter tests follow the `blocTest` pattern from `checkout_bloc_test.dart`.

**Tech Stack:** NestJS + Prisma 6.19 + Jest (API); Flutter 3.x + bloc_test ^10.0.0 + SharedPreferences (app)

**Baseline:** 231 API tests (all green), 441 Flutter tests (all green).

---

## File map

| Task | Action | Path |
|---|---|---|
| 1 | Create | `api/src/modules/currencies/currencies.service.spec.ts` |
| 2 | Modify | `api/src/modules/sales/sales.service.spec.ts` |
| 3 | Modify | `api/src/modules/subscriptions/subscriptions.service.spec.ts` |
| 4 | Modify | `api/src/modules/subscriptions/subscriptions.service.spec.ts` |
| 5 | Modify | `api/src/common/guards/subscription.guard.spec.ts` |
| 6 | Create | `app/test/presentation/blocs/pos/cart_bloc_persistence_test.dart` |
| 7 | Create | `qa/2026-07-05-app-lifecycle/REPORT.md` |

---

## Task 1: CurrenciesService spec

**Files:**
- Create: `api/src/modules/currencies/currencies.service.spec.ts`

**Context:** `CurrenciesService` (at `api/src/modules/currencies/currencies.service.ts`) exposes two query methods: `getLatestRates()` uses `prisma.currencyRate.findMany({ orderBy: { date: 'desc' }, distinct: ['currency'] })` to return the latest row per currency. `getRateHistory(currency, days)` computes a cutoff date (`new Date() - N days`), then calls `findMany({ where: { currency: upper, date: { gte: cutoff } }, orderBy: { date: 'asc' } })`. The constructor takes only `PrismaService`. No other DI dependencies.

- [ ] **Step 1: Write the failing spec**

Create `api/src/modules/currencies/currencies.service.spec.ts`:

```ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { CurrenciesService } from './currencies.service';
import { PrismaService } from '../../prisma/prisma.service';

const MS_DAY = 86_400_000;
const d = (daysAgo: number) => new Date(Date.now() - daysAgo * MS_DAY);

function makePrismaFake() {
  // Seed: two USD rows (today + yesterday) and one RUB row (today)
  // plus a USD row 9 days ago (outside 7-day window).
  const allRates = [
    { id: 'r1', currency: 'USD', nbtRate: 10.5, buyRate: 10.4, sellRate: 10.6, date: d(0) },
    { id: 'r2', currency: 'USD', nbtRate: 10.4, buyRate: 10.3, sellRate: 10.5, date: d(1) },
    { id: 'r3', currency: 'USD', nbtRate: 10.3, buyRate: 10.2, sellRate: 10.4, date: d(9) },
    { id: 'r4', currency: 'RUB', nbtRate: 0.11, buyRate: 0.109, sellRate: 0.111, date: d(0) },
  ];

  return {
    currencyRate: {
      findMany: jest.fn(async (args: any = {}) => {
        let result = [...allRates];
        const where = args.where ?? {};
        if (where.currency) {
          result = result.filter((r) => r.currency === where.currency);
        }
        if (where.date?.gte) {
          result = result.filter((r) => r.date >= where.date.gte);
        }
        // Sort
        if (args.orderBy?.date === 'asc') {
          result.sort((a, b) => +a.date - +b.date);
        } else if (args.orderBy?.date === 'desc') {
          result.sort((a, b) => +b.date - +a.date);
        }
        // Distinct (Prisma returns first-match-per-group after ORDER BY)
        if (args.distinct) {
          const seen = new Set<string>();
          result = result.filter((r) => {
            const key = (args.distinct as string[])
              .map((f) => `${f}:${(r as any)[f]}`)
              .join('|');
            if (seen.has(key)) return false;
            seen.add(key);
            return true;
          });
        }
        return result;
      }),
    },
  };
}

describe('CurrenciesService', () => {
  let service: CurrenciesService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        CurrenciesService,
        { provide: PrismaService, useValue: makePrismaFake() },
      ],
    }).compile();
    service = module.get(CurrenciesService);
  });

  describe('getLatestRates', () => {
    it('should return one row per distinct currency (the most recent)', async () => {
      const rates = await service.getLatestRates();

      // 2 distinct currencies: USD (d0) and RUB (d0)
      expect(rates).toHaveLength(2);
      const usd = rates.find((r) => r.currency === 'USD');
      const rub = rates.find((r) => r.currency === 'RUB');
      expect(usd).toBeDefined();
      expect(rub).toBeDefined();
      // Latest USD rate is r1 (d0, nbtRate=10.5) — not r2 (d1) or r3 (d9)
      expect(Number(usd!.nbtRate)).toBeCloseTo(10.5);
    });
  });

  describe('getRateHistory', () => {
    it('should return ascending history within the requested day window', async () => {
      // 7-day window: r1 (d0) and r2 (d1) qualify; r3 (d9) does not
      const history = await service.getRateHistory('USD', 7);

      expect(history).toHaveLength(2);
      // Ascending date order
      expect(history[0].date <= history[1].date).toBe(true);
      // Older entry is r2 (d1 ~= yesterday)
      expect(Number(history[0].nbtRate)).toBeCloseTo(10.4);
      // Newer entry is r1 (d0 ~= today)
      expect(Number(history[1].nbtRate)).toBeCloseTo(10.5);
    });

    it('should return an empty array when no rates exist for the given currency', async () => {
      const history = await service.getRateHistory('EUR', 30);
      expect(history).toHaveLength(0);
    });
  });
});
```

- [ ] **Step 2: Confirm test fails**

```bash
cd api && npx jest currencies.service.spec --no-coverage 2>&1 | tail -10
```

Expected: `FAIL` — file not found or compilation error until the spec exists.

- [ ] **Step 3: Run tests to verify they pass**

```bash
cd api && npx jest currencies.service.spec --no-coverage 2>&1 | tail -15
```

Expected: `Tests: 3 passed, 3 total`

- [ ] **Step 4: Commit**

```bash
git add api/src/modules/currencies/currencies.service.spec.ts
git commit -m "test(currencies): add getLatestRates + getRateHistory service specs (Spec I)"
```

---

## Task 2: SalesService — big-sale notification for USD store

**Files:**
- Modify: `api/src/modules/sales/sales.service.spec.ts`

**Context:** `maybeNotifyBigSale` fires when `sale.total >= 1000` (DEFAULT_BIG_SALE_THRESHOLD). It calls `prisma.store.findUnique(...)` to get `{ ownerId, name, currency }` and then `notificationsService.sendPush(ownerId, title, body, 'BIG_SALE', storeId)`. The body text includes `store.currency`. The existing `makePrismaFake()` has no `store` property. The `maybeNotifyBigSale` call is `void` (fire-and-forget), so after `await service.create(...)` the push hasn't fired yet — drain with `await new Promise<void>(r => setImmediate(r))`.

- [ ] **Step 1: Add new describe block at end of file**

Append to `api/src/modules/sales/sales.service.spec.ts` (after the last closing `});`):

```ts
// ─── Big-sale notification — multi-currency ───────────────────────────────

function makeUsdSaleFake() {
  // Minimal Prisma fake for a single USD-currency store sale.
  // Product price is 1100 (above DEFAULT_BIG_SALE_THRESHOLD=1000) so the
  // notification path is exercised.
  const tx = {
    product: {
      findMany: jest.fn(async () => [
        {
          id: 'p-luxury',
          storeId: 'store-usd',
          name: 'Luxury Item',
          sellPrice: new Prisma.Decimal('1100'),
          costPrice: new Prisma.Decimal('900'),
          quantity: 50,
        },
      ]),
      updateMany: jest.fn(async () => ({ count: 1 })),
    },
    sale: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'sale-usd-1',
        storeId: 'store-usd',
        cashierId: 'cashier-1',
        receiptNo: data.receiptNo,
        subtotal: new Prisma.Decimal('1100'),
        discount: new Prisma.Decimal('0'),
        discountType: 'FIXED',
        total: new Prisma.Decimal('1100'),
        paymentType: 'CASH',
        paidAmount: new Prisma.Decimal('1100'),
        change: new Prisma.Decimal('0'),
        debtAmount: new Prisma.Decimal('0'),
        customerId: null,
        status: 'COMPLETED',
        createdAt: new Date(),
        items: [
          {
            id: 'si-usd-1',
            saleId: 'sale-usd-1',
            productId: 'p-luxury',
            quantity: 1,
            sellPrice: new Prisma.Decimal('1100'),
            total: new Prisma.Decimal('1100'),
          },
        ],
        debtPayments: [],
      })),
    },
    stockMovement: { createMany: jest.fn(async () => ({ count: 1 })) },
    customer: { update: jest.fn(async () => ({})) },
  };

  return {
    store: {
      findUnique: jest.fn(async () => ({
        id: 'store-usd',
        ownerId: 'owner-usd',
        name: 'USD Shop',
        currency: 'USD',
        settings: {},
      })),
    },
    $transaction: jest.fn(async (cb: (tx: any) => Promise<any>) => cb(tx)),
    sale: {
      findFirst: jest.fn(async () => null),
      findMany: jest.fn(async () => []),
      count: jest.fn(async () => 0),
    },
  };
}

describe('SalesService — big-sale notification (USD store)', () => {
  let service: SalesService;
  let sendPushMock: jest.Mock;

  beforeEach(async () => {
    sendPushMock = jest.fn(async () => undefined);
    const module = await Test.createTestingModule({
      providers: [
        SalesService,
        { provide: PrismaService, useValue: makeUsdSaleFake() },
        { provide: RedisService, useValue: fakeRedis() },
        { provide: NotificationsService, useValue: { sendPush: sendPushMock } },
        { provide: AuditLogService, useValue: { record: jest.fn(async () => undefined) } },
      ],
    }).compile();
    service = module.get(SalesService);
  });

  it('should include store currency in big-sale push body when sale total exceeds threshold', async () => {
    await service.create('store-usd', 'cashier-1', {
      items: [{ productId: 'p-luxury', quantity: 1 }],
      paymentType: 'CASH',
      paidAmount: 1100,
    } as any);

    // maybeNotifyBigSale is void — drain the microtask queue to let the
    // async chain (store lookup + sendPush) complete before asserting.
    await new Promise<void>((r) => setImmediate(r));

    expect(sendPushMock).toHaveBeenCalledWith(
      'owner-usd',            // ownerId
      expect.any(String),     // title
      expect.stringContaining('USD'), // body must mention store currency
      'BIG_SALE',
      'store-usd',
    );
  });
});
```

- [ ] **Step 2: Run tests**

```bash
cd api && npx jest sales.service.spec --no-coverage 2>&1 | tail -15
```

Expected: all previous tests still pass + 1 new passing test.

- [ ] **Step 3: Commit**

```bash
git add api/src/modules/sales/sales.service.spec.ts
git commit -m "test(sales): add USD-store big-sale notification currency assertion (Spec I)"
```

---

## Task 3: adminChangePlan — missing edge-case tests

**Files:**
- Modify: `api/src/modules/subscriptions/subscriptions.service.spec.ts`

**Context:** The existing admin describe block already has an `adminChangePlan` audit log test. Two gaps remain: (1) NotFoundException when subscription not found, and (2) proof that `update` is called with `{ plan }` only — NOT `currentPeriodEnd` (common misconception about what adminChangePlan does). The existing `makeAdminPrismaFake()` returns `null` for any `where.id !== 'sub-audit'`, so gap (1) can be tested in the existing describe block. For gap (2), we need to capture the prisma fake to inspect the `update` call args — add a new sibling describe block.

- [ ] **Step 1: Add NotFoundException test to existing admin describe block**

Inside `describe('SubscriptionsService — admin audit logs', ...)` (after the last `it(...)` and before the closing `});`), add:

```ts
  it('should throw NotFoundException when subscription does not exist', async () => {
    await expect(
      service.adminChangePlan(
        'no-such-sub',
        { plan: SubscriptionPlanEnum.BUSINESS },
        'admin-1',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
```

- [ ] **Step 2: Add new describe block for plan-field-only assertion**

After the admin audit logs describe block (after its closing `});`), add:

```ts
describe('SubscriptionsService — adminChangePlan field guard', () => {
  let service: SubscriptionsService;
  let prisma: ReturnType<typeof makeAdminPrismaFake>;

  beforeEach(async () => {
    prisma = makeAdminPrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: NotificationsService,
          useValue: { sendPush: jest.fn(async () => undefined) },
        },
        { provide: AuditLogService, useValue: { record: jest.fn(async () => undefined) } },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('should update ONLY the plan field — not currentPeriodEnd or other fields', async () => {
    await service.adminChangePlan(
      'sub-audit',
      { plan: SubscriptionPlanEnum.PREMIUM },
      'admin-1',
    );

    // Drain fire-and-forget audit call
    await new Promise<void>((r) => setImmediate(r));

    expect(prisma.subscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { plan: SubscriptionPlanEnum.PREMIUM },
      }),
    );

    // The data object must not include currentPeriodEnd — this confirms
    // adminChangePlan does NOT reset the billing period (a common assumption
    // from the old spec). Only plan changes; renewal is separate.
    const updateArg = (prisma.subscription.update as jest.Mock).mock.calls[0][0];
    expect(updateArg.data).not.toHaveProperty('currentPeriodEnd');
  });
});
```

- [ ] **Step 3: Run tests**

```bash
cd api && npx jest subscriptions.service.spec --no-coverage 2>&1 | tail -15
```

Expected: all previous tests pass + 2 new passing tests.

- [ ] **Step 4: Commit**

```bash
git add api/src/modules/subscriptions/subscriptions.service.spec.ts
git commit -m "test(subscriptions): add adminChangePlan NotFoundException + field-guard tests (Spec I)"
```

---

## Task 4: checkExpiredSubscriptions — behaviour tests

**Files:**
- Modify: `api/src/modules/subscriptions/subscriptions.service.spec.ts`

**Context:** `checkExpiredSubscriptions` queries ACTIVE/TRIAL subs with `currentPeriodEnd < now`, calls `subscription.updateMany({ data: { status: 'EXPIRED' } })`, then calls `notificationsService.sendPush(ownerId, title, body, 'SUBSCRIPTION_EXPIRED', storeId)` for each. The existing spec only tests the mathematical predicate (`expiredEnd < now` is `true`), not the actual service method. The new tests call the method with a faked Prisma that returns expired subs.

- [ ] **Step 1: Add new describe block at end of file**

After the last describe block in `subscriptions.service.spec.ts`, append:

```ts
// ─── checkExpiredSubscriptions behaviour ─────────────────────────────────

describe('SubscriptionsService — checkExpiredSubscriptions', () => {
  let service: SubscriptionsService;
  let prisma: any;
  let sendPushMock: jest.Mock;

  beforeEach(async () => {
    sendPushMock = jest.fn(async () => undefined);
    prisma = {
      // Only methods checkExpiredSubscriptions touches:
      subscription: {
        findMany: jest.fn(async () => []),
        updateMany: jest.fn(async () => ({ count: 0 })),
      },
      // Other methods needed by SubscriptionsService constructor / onModuleInit
      // are not called in these tests — leave them absent so any unexpected
      // call throws immediately (fast failure, not silent pass).
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: sendPushMock } },
        { provide: AuditLogService, useValue: { record: jest.fn(async () => undefined) } },
      ],
    }).compile();
    service = moduleRef.get(SubscriptionsService);
  });

  it('should flip ACTIVE subscription to EXPIRED and send push when period has ended', async () => {
    const pastEnd = new Date(Date.now() - 86_400_000); // yesterday
    prisma.subscription.findMany = jest.fn(async () => [
      {
        id: 'sub-expired',
        status: 'ACTIVE',
        currentPeriodEnd: pastEnd,
        store: { ownerId: 'owner-1', id: 'store-1', name: 'My Shop' },
      },
    ]);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['sub-expired'] } },
      data: { status: 'EXPIRED' },
    });
    expect(sendPushMock).toHaveBeenCalledWith(
      'owner-1',
      expect.any(String),
      expect.stringContaining('My Shop'),
      'SUBSCRIPTION_EXPIRED',
      'store-1',
    );
  });

  it('should send a push for each expired subscription individually', async () => {
    const pastEnd = new Date(Date.now() - 86_400_000);
    prisma.subscription.findMany = jest.fn(async () => [
      { id: 'sub-a', status: 'ACTIVE', currentPeriodEnd: pastEnd, store: { ownerId: 'o1', id: 's1', name: 'Shop A' } },
      { id: 'sub-b', status: 'TRIAL', currentPeriodEnd: pastEnd, store: { ownerId: 'o2', id: 's2', name: 'Shop B' } },
    ]);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['sub-a', 'sub-b'] } },
      data: { status: 'EXPIRED' },
    });
    expect(sendPushMock).toHaveBeenCalledTimes(2);
    expect(sendPushMock).toHaveBeenCalledWith('o1', expect.any(String), expect.stringContaining('Shop A'), 'SUBSCRIPTION_EXPIRED', 's1');
    expect(sendPushMock).toHaveBeenCalledWith('o2', expect.any(String), expect.stringContaining('Shop B'), 'SUBSCRIPTION_EXPIRED', 's2');
  });

  it('should not call updateMany or sendPush when no subscriptions have expired', async () => {
    // findMany returns [] — the if (expired.length > 0) guard short-circuits
    prisma.subscription.findMany = jest.fn(async () => []);

    await service.checkExpiredSubscriptions();

    expect(prisma.subscription.updateMany).not.toHaveBeenCalled();
    expect(sendPushMock).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run tests**

```bash
cd api && npx jest subscriptions.service.spec --no-coverage 2>&1 | tail -15
```

Expected: all previous tests pass + 3 new passing tests.

- [ ] **Step 3: Commit**

```bash
git add api/src/modules/subscriptions/subscriptions.service.spec.ts
git commit -m "test(subscriptions): add checkExpiredSubscriptions behaviour tests (Spec I)"
```

---

## Task 5: SubscriptionGuard — explicit downgrade test

**Files:**
- Modify: `api/src/common/guards/subscription.guard.spec.ts`

**Context:** The guard spec (`subscription.guard.spec.ts`) already has tests for: class-level metadata fallback, feature-flag rejection (START plan + reports=false), and method-level override (BUSINESS + PREMIUM required). The spec requires one more explicit test: store plan = START, endpoint requires PREMIUM → `ForbiddenException`. This is the canonical "downgrade" scenario — after a user downgrades to START, PREMIUM-gated endpoints must throw. The `makePrisma` and `makeContext` helpers already exist in the file.

- [ ] **Step 1: Add downgrade test inside the existing describe block**

Inside `describe('SubscriptionGuard', ...)` (after the last `it(...)` and before the closing `});`), add:

```ts
  it('rejects START plan subscriber when endpoint requires PREMIUM (explicit downgrade guard)', async () => {
    // Documents the downgrade-access-denial path: a store that was on
    // PREMIUM and downgraded to START must be blocked from PREMIUM features
    // even if they previously had access. The guard is plan-agnostic (no
    // hard-coded tiers) — it reads REQUIRED_PLAN_KEY metadata and compares.
    const prisma = makePrisma({
      subscription: { storeId: 's1', status: 'ACTIVE', plan: 'START' },
    });
    const guard = new SubscriptionGuard(reflector, prisma as never);

    const ctx = makeContext({
      storeId: 's1',
      classMetadata: { [REQUIRED_PLAN_KEY]: 'PREMIUM' },
    });

    await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
```

- [ ] **Step 2: Run tests**

```bash
cd api && npx jest subscription.guard.spec --no-coverage 2>&1 | tail -10
```

Expected: all 4 tests pass (3 existing + 1 new).

- [ ] **Step 3: Run full API suite to verify count**

```bash
cd api && npx jest --no-coverage 2>&1 | grep -E "Tests:|Test Suites:" | tail -5
```

Expected: `Tests: 240 passed` (231 baseline + 3 currencies + 1 sales + 2 adminChangePlan + 3 expiry + 1 guard = 241). If the count differs slightly, record actual number.

- [ ] **Step 4: Commit**

```bash
git add api/src/common/guards/subscription.guard.spec.ts
git commit -m "test(guards): add explicit START→PREMIUM downgrade ForbiddenException test (Spec I)"
```

---

## Task 6: CartBloc persistence tests

**Files:**
- Create: `app/test/presentation/blocs/pos/cart_bloc_persistence_test.dart`

**Context:** `CartBloc` (at `app/lib/presentation/blocs/pos/cart_bloc.dart`) accepts `CartLocalDatasource? persistence` in its constructor. Every state change schedules a `Timer(Duration(milliseconds: 400), ...)` to call `_persistence.save(state)`. `CartLocalDatasource` (at `app/lib/data/datasources/local/cart_local_datasource.dart`) takes `SharedPreferences` in its constructor and persists cart JSON to key `pos.cart.v1`. Use `SharedPreferences.setMockInitialValues({})` then `SharedPreferences.getInstance()` to get a test instance. Tests use real `Future.delayed(Duration(milliseconds: 450))` to advance past the 400ms debounce. Package name is `dukonpro`.

- [ ] **Step 1: Write the test file**

Create `app/test/presentation/blocs/pos/cart_bloc_persistence_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukonpro/data/datasources/local/cart_local_datasource.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';

Product _makeProduct({
  String id = 'p1',
  String name = 'Apple',
  double sellPrice = 5.0,
}) {
  return Product(
    id: id,
    storeId: 'store-1',
    name: name,
    sellPrice: sellPrice,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('CartBloc persistence', () {
    late CartLocalDatasource datasource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      datasource = CartLocalDatasource(prefs);
    });

    test('should not persist before the 400ms debounce fires', () async {
      final bloc = CartBloc(persistence: datasource);
      bloc.add(CartItemAdded(product: _makeProduct()));

      // Immediately after the event — debounce timer hasn't fired yet
      final loaded = await datasource.load();
      expect(loaded, isNull);

      await bloc.close();
    });

    test('should persist cart to SharedPreferences after 400ms debounce', () async {
      final bloc = CartBloc(persistence: datasource);
      bloc.add(CartItemAdded(product: _makeProduct()));

      // Advance past the 400ms debounce
      await Future<void>.delayed(const Duration(milliseconds: 450));

      final loaded = await datasource.load();
      expect(loaded, isNotNull);
      expect(loaded!.state.items, hasLength(1));
      expect(loaded.state.items.first.productId, 'p1');

      await bloc.close();
    });

    test('should emit restored items after CartRestored event', () async {
      // Pre-populate the datasource (simulates a prior app session)
      const savedItem = CartItem(
        productId: 'p-restore',
        productName: 'Restored Product',
        unitPrice: 15.0,
        quantity: 3,
        unit: 'PCS',
        discount: 0,
      );
      await datasource.save(const CartState(items: [savedItem]));

      blocTest<CartBloc, CartState>(
        'emits state with restored items on CartRestored',
        build: () => CartBloc(persistence: datasource),
        act: (bloc) => bloc.add(
          const CartRestored(CartState(items: [savedItem])),
        ),
        expect: () => [
          isA<CartState>().having(
            (s) => s.items,
            'items',
            [isA<CartItem>().having((i) => i.productId, 'productId', 'p-restore')],
          ),
        ],
      );
    });
  });
}
```

- [ ] **Step 2: Confirm test file compiles**

```bash
cd app && dart analyze test/presentation/blocs/pos/cart_bloc_persistence_test.dart 2>&1 | tail -10
```

Expected: no errors. If import paths fail, check `package:dukonpro/` is the correct prefix by looking at `app/pubspec.yaml` `name:` field.

- [ ] **Step 3: Run new tests only**

```bash
cd app && flutter test test/presentation/blocs/pos/cart_bloc_persistence_test.dart --reporter=expanded 2>&1 | tail -20
```

Expected: `3 tests passed`.

- [ ] **Step 4: Run full Flutter suite**

```bash
cd app && flutter test --reporter=compact 2>&1 | tail -5
```

Expected: `444 tests passed` (441 baseline + 3 new).

- [ ] **Step 5: Commit**

```bash
git add app/test/presentation/blocs/pos/cart_bloc_persistence_test.dart
git commit -m "test(cart): add CartBloc persistence debounce + restore tests (Spec I)"
```

---

## Task 7: Manual QA doc

**Files:**
- Create: `qa/2026-07-05-app-lifecycle/REPORT.md`

**Context:** Same format as `qa/2026-05-12-app-lifecycle/REPORT.md`. Four scenarios covering OS process kill, Doze mode, device sleep, and low-memory kill. Result column is left blank — the human tester fills it in after running on a physical or emulator device.

- [ ] **Step 1: Create directory and file**

```bash
mkdir -p qa/2026-07-05-app-lifecycle
```

Create `qa/2026-07-05-app-lifecycle/REPORT.md`:

```markdown
# App Lifecycle QA — Cart Persistence Under System Pressure

**Date:** 2026-07-05  
**Spec:** Spec I — App Lifecycle Stress  
**Build:** run `flutter build apk --debug` and install  
**Device:** Android emulator (API 34) or physical Android device  
**Prereq:** Enable developer options. For scenario 4: enable "Don't keep activities" in developer options.

---

## Scenarios

| # | Scenario | Steps | Expected | Result |
|---|---|---|---|---|
| 1 | OS process kill mid-sale | 1. Open POS → add 3 items to cart<br>2. Force-stop app (adb shell am force-stop com.dukonpro.app)<br>3. Reopen app<br>4. Observe cart restore prompt | Cart restore prompt appears with 3 items. Accepting restores cart exactly. Declining clears cart cleanly. No crash. | — |
| 2 | Doze mode (10-min background) | 1. Open POS → add 2 items to cart<br>2. Lock screen, wait 10 minutes<br>3. Unlock → foreground app | Session still valid (no auth prompt). Cart intact. No crash. | — |
| 3 | Device sleep during active sale | 1. Open POS cart with items<br>2. Lock screen immediately<br>3. Unlock immediately (< 30s) | App resumes without restart. Cart state unchanged. | — |
| 4 | Low-memory process kill | 1. Enable "Don't keep activities" in Developer Options<br>2. Open POS → add items to cart<br>3. Press Home (background)<br>4. Reopen app | App restores to POS. Cart restore prompt shown with saved items. No corrupt state. | — |

---

## Pass criteria

All 4 scenarios must show no crash and correct cart state. Scenarios 1 and 4 must show the restore prompt.

---

## Notes

_Fill in after manual run. Include device model, Android API level, and any deviations from expected._
```

- [ ] **Step 2: Commit**

```bash
git add qa/2026-07-05-app-lifecycle/REPORT.md
git commit -m "docs(qa): add app lifecycle cart persistence manual QA template (Spec I)"
```

---

## Final verification

- [ ] **Run full API suite**

```bash
cd api && npx jest --no-coverage 2>&1 | grep "Tests:" | tail -3
```

Expected: ≥ 240 tests passed (target 241 from spec — actual depends on exact coverage overlap; record actual count).

- [ ] **Run full Flutter suite**

```bash
cd app && flutter test --reporter=compact 2>&1 | tail -3
```

Expected: 444 tests passed.

- [ ] **TypeScript check**

```bash
cd api && npx tsc --noEmit 2>&1 | head -20
```

Expected: no new errors (pre-existing TS errors are documented and not introduced by this spec).
