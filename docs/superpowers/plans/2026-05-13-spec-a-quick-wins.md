# Spec A "Quick Wins" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close 3 deferred backlog items in one umbrella: D.4 query-counter middleware + fix top 5 N+1 offenders, F.2 class-level `@RequiresFeature` refactor + audit, G.2 Investments/Zakat module deep audit with inline P0/P1 fixes.

**Architecture:** Three independent sub-sections sharing only `qa/2026-05-12-quick-wins/` for artefacts. D.4 adds a Prisma middleware + NestJS interceptor; F.2 modifies one guard + 3-5 controllers; G.2 is audit-then-fix. Each sub-section ships as its own commits; final E.1 task is the verification gate.

**Tech Stack:** NestJS 10 + Prisma 6.19 + Postgres 16 (API); Flutter 3.x with Bloc (mobile); Jest (API tests); flutter_test + golden_toolkit (mobile tests).

**Spec:** `docs/superpowers/specs/2026-05-12-spec-a-quick-wins-design.md` (commit 0ce93a9).

---

## File Structure

**Created (D.4):**
- `api/src/common/prisma/query-counter.context.ts` — AsyncLocalStorage wrapper exporting `runWithCounter()` and `incrementCounter()`.
- `api/src/common/prisma/query-counter.middleware.ts` — Prisma `$use` middleware that calls `incrementCounter()` on each query.
- `api/src/common/interceptors/query-counter.interceptor.ts` — NestJS interceptor that calls `runWithCounter()` per request and logs the final count.
- `api/test/common/prisma/query-counter.spec.ts` — unit test of the counter context + middleware behaviour.
- `qa/2026-05-12-quick-wins/REPORT.md` — D.4 before/after table.

**Modified (D.4):**
- `api/src/prisma/prisma.service.ts` — wire the middleware in `onModuleInit`.
- `api/src/app.module.ts` — register the interceptor as `APP_INTERCEPTOR`.
- `api/src/modules/reports/reports.service.ts` — fix #1.
- `api/src/modules/products/products.service.ts` — fix #2.
- `api/src/modules/sales/sales.service.ts` — fix #3.
- `api/src/modules/shifts/shifts.service.ts` — fix #4.
- `api/src/modules/admin/admin.service.ts` — fix #5.

**Created (F.2):**
- `qa/2026-05-12-quick-wins/F2-AUDIT.md` — mixed-coverage findings.

**Modified (F.2):**
- `api/src/common/guards/subscription.guard.ts` — switch to `getAllAndOverride`.
- `api/src/common/guards/subscription.guard.spec.ts` — add class-level fallback test.
- 3-5 controller files in `api/src/modules/*/` (identified by grep in F.2.3).

**Created (G.2):**
- `qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md` — audit matrix + findings + P0/P1 fix commit list.

**Modified (G.2):**
- Per-finding files in `api/src/modules/investments/`, `api/src/modules/zakat/`, `app/lib/presentation/pages/zakat/`, `app/lib/presentation/blocs/investment/`. Exact list emerges from the audit pass.

---

## Sub-section D.4 — N+1 query measurement + fix top 5 offenders

### Task D.4.1: Write the query-counter context (AsyncLocalStorage wrapper)

**Files:**
- Create: `api/src/common/prisma/query-counter.context.ts`

- [ ] **Step 1: Create the file**

```typescript
// api/src/common/prisma/query-counter.context.ts
//
// AsyncLocalStorage-backed per-request query counter for Prisma.
// The interceptor calls runWithCounter() at the top of each HTTP
// request; the Prisma middleware calls incrementCounter() on each
// query; the interceptor reads the final count at end-of-request.
import { AsyncLocalStorage } from 'node:async_hooks';

export interface QueryCounterStore {
  count: number;
  endpoint: string;
}

const storage = new AsyncLocalStorage<QueryCounterStore>();

export function runWithCounter<T>(
  endpoint: string,
  fn: () => Promise<T>,
): Promise<T> {
  return storage.run({ count: 0, endpoint }, fn);
}

export function incrementCounter(): void {
  const store = storage.getStore();
  if (store) store.count += 1;
}

export function readCounter(): QueryCounterStore | undefined {
  return storage.getStore();
}
```

- [ ] **Step 2: Verify compiles**

Run from `/Users/latifrjdev/Downloads/01_Проекты/Dukon/api`:
```bash
npx tsc --noEmit src/common/prisma/query-counter.context.ts 2>&1 | tail
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/prisma/query-counter.context.ts
git commit -m "feat(perf): query counter AsyncLocalStorage context"
```

---

### Task D.4.2: Write the Prisma middleware

**Files:**
- Create: `api/src/common/prisma/query-counter.middleware.ts`

- [ ] **Step 1: Create the file**

```typescript
// api/src/common/prisma/query-counter.middleware.ts
//
// Prisma client middleware that increments the per-request query
// counter for every query operation. Attached in
// PrismaService.onModuleInit via prisma.$use().
import { Prisma } from '@prisma/client';
import { incrementCounter } from './query-counter.context';

export const queryCounterMiddleware: Prisma.Middleware = async (
  params,
  next,
) => {
  incrementCounter();
  return next(params);
};
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "query-counter" | head
```
Expected: no errors mentioning query-counter files.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/prisma/query-counter.middleware.ts
git commit -m "feat(perf): Prisma middleware that counts queries per request"
```

---

### Task D.4.3: Write the NestJS interceptor

**Files:**
- Create: `api/src/common/interceptors/query-counter.interceptor.ts`

- [ ] **Step 1: Create the file**

```typescript
// api/src/common/interceptors/query-counter.interceptor.ts
//
// Wraps every HTTP request in the query-counter AsyncLocalStorage
// context. Logs a warning at end-of-request if count > 10, error
// if count > 25.
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, from, switchMap, tap } from 'rxjs';
import {
  readCounter,
  runWithCounter,
} from '../prisma/query-counter.context';

const WARN_THRESHOLD = 10;
const ERROR_THRESHOLD = 25;

@Injectable()
export class QueryCounterInterceptor implements NestInterceptor {
  private readonly logger = new Logger('QueryCounter');

  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const req = context.switchToHttp().getRequest<{
      method: string;
      url: string;
    }>();
    const endpoint = `${req.method} ${req.url}`;
    return from(
      runWithCounter(endpoint, () =>
        next.handle().toPromise() as Promise<unknown>,
      ),
    ).pipe(
      tap(() => {
        const store = readCounter();
        if (!store) return;
        if (store.count > ERROR_THRESHOLD) {
          this.logger.error(
            `${endpoint} fired ${store.count} queries (> ${ERROR_THRESHOLD})`,
          );
        } else if (store.count > WARN_THRESHOLD) {
          this.logger.warn(
            `${endpoint} fired ${store.count} queries (> ${WARN_THRESHOLD})`,
          );
        }
      }),
      switchMap((v) => from(Promise.resolve(v))),
    );
  }
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "query-counter.interceptor" | head
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/interceptors/query-counter.interceptor.ts
git commit -m "feat(perf): NestJS interceptor logs per-request query count"
```

---

### Task D.4.4: Wire middleware + interceptor

**Files:**
- Modify: `api/src/prisma/prisma.service.ts`
- Modify: `api/src/app.module.ts`

- [ ] **Step 1: Inspect existing PrismaService**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/prisma/prisma.service.ts
```

Locate `onModuleInit` (or `enableShutdownHooks`). If `$use` is called for some other purpose already, add a second `$use` after — Prisma chains them in order.

- [ ] **Step 2: Add middleware call in PrismaService**

Edit `api/src/prisma/prisma.service.ts`. Add import at top:
```typescript
import { queryCounterMiddleware } from '../common/prisma/query-counter.middleware';
```

In `onModuleInit` (creating it if it doesn't exist), add:
```typescript
this.$use(queryCounterMiddleware);
```

- [ ] **Step 3: Wire interceptor in AppModule**

Edit `api/src/app.module.ts`. Add import:
```typescript
import { APP_INTERCEPTOR } from '@nestjs/core';
import { QueryCounterInterceptor } from './common/interceptors/query-counter.interceptor';
```

In the `providers` array, add:
```typescript
{ provide: APP_INTERCEPTOR, useClass: QueryCounterInterceptor },
```

- [ ] **Step 4: Verify boot**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
```
Expected: 0 errors.

Restart API:
```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done
echo "API READY"
```

Hit `/api/health` and inspect log:
```bash
curl -sf http://localhost:4455/api/health >/dev/null
sleep 1
grep "QueryCounter\|fired" /tmp/dukon-api.log | tail -3
```
Expected: either no warning (health is < 10 queries) OR a debug line showing count for the health endpoint. If you don't see any QueryCounter log lines, the warn threshold is fine — just exercise an expensive endpoint:
```bash
T_BIZ=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001002","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
curl -sf "http://localhost:4455/api/stores/d169d2e8-0a24-4a23-844a-5d5e7b690d8c/reports/sales" \
  -H "Authorization: Bearer $T_BIZ" >/dev/null
sleep 1
grep "QueryCounter" /tmp/dukon-api.log | tail -3
```
Expected: at least one warning. If still nothing — the interceptor isn't catching the request. Verify it's listed in AppModule providers.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/prisma/prisma.service.ts api/src/app.module.ts
git commit -m "feat(perf): wire query-counter middleware + interceptor"
```

---

### Task D.4.5: Unit test the counter

**Files:**
- Create: `api/test/common/prisma/query-counter.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
// api/test/common/prisma/query-counter.spec.ts
import {
  incrementCounter,
  readCounter,
  runWithCounter,
} from '../../../src/common/prisma/query-counter.context';

describe('query-counter context', () => {
  it('starts at 0 inside runWithCounter', async () => {
    await runWithCounter('test', async () => {
      const store = readCounter();
      expect(store?.count).toBe(0);
    });
  });

  it('incrementCounter increments inside the context', async () => {
    await runWithCounter('test', async () => {
      incrementCounter();
      incrementCounter();
      incrementCounter();
      expect(readCounter()?.count).toBe(3);
    });
  });

  it('two parallel runs have independent counters', async () => {
    const p1 = runWithCounter('a', async () => {
      incrementCounter();
      await new Promise((r) => setImmediate(r));
      incrementCounter();
      return readCounter()?.count;
    });
    const p2 = runWithCounter('b', async () => {
      incrementCounter();
      await new Promise((r) => setImmediate(r));
      return readCounter()?.count;
    });
    const [c1, c2] = await Promise.all([p1, p2]);
    expect(c1).toBe(2);
    expect(c2).toBe(1);
  });

  it('incrementCounter is a no-op outside context', () => {
    expect(() => incrementCounter()).not.toThrow();
    expect(readCounter()).toBeUndefined();
  });
});
```

- [ ] **Step 2: Run the test**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- query-counter 2>&1 | tail -8
```
Expected: 4 passed.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/test/common/prisma/query-counter.spec.ts
git commit -m "test(perf): query-counter context behaves per AsyncLocalStorage"
```

---

### Task D.4.6: Baseline measurement on top 5 endpoints

**Files:**
- Create: `qa/2026-05-12-quick-wins/REPORT.md` (skeleton — values filled after fixes)

- [ ] **Step 1: Restart API + truncate log**

```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
: > /tmp/dukon-api.log
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done
```

- [ ] **Step 2: Hit each endpoint once + read counts**

```bash
T_BIZ=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001002","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
T_ADMIN=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992909000001","password":"admin123"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
SID="d169d2e8-0a24-4a23-844a-5d5e7b690d8c"

# Endpoint 1: reports sales
curl -sf "http://localhost:4455/api/stores/$SID/reports/sales" \
  -H "Authorization: Bearer $T_BIZ" >/dev/null
# Endpoint 2: products list
curl -sf "http://localhost:4455/api/stores/$SID/products?page=1&limit=20" \
  -H "Authorization: Bearer $T_BIZ" >/dev/null
# Endpoint 3: sales list
curl -sf "http://localhost:4455/api/stores/$SID/sales?page=1&limit=20" \
  -H "Authorization: Bearer $T_BIZ" >/dev/null
# Endpoint 4: shifts list
curl -sf "http://localhost:4455/api/stores/$SID/shifts?page=1&limit=20" \
  -H "Authorization: Bearer $T_BIZ" >/dev/null
# Endpoint 5: admin payments (or admin subscriptions list if no /payments)
curl -sf "http://localhost:4455/api/admin/subscriptions?page=1&limit=20" \
  -H "Authorization: Bearer $T_ADMIN" >/dev/null 2>&1 || \
curl -sf "http://localhost:4455/api/admin/payments?page=1&limit=20" \
  -H "Authorization: Bearer $T_ADMIN" >/dev/null

sleep 2
grep "QueryCounter" /tmp/dukon-api.log
```

Record the count for each endpoint. These are the "BEFORE" numbers.

- [ ] **Step 3: Write REPORT.md skeleton**

Create `qa/2026-05-12-quick-wins/REPORT.md`:

```markdown
# D.4 — N+1 Query Measurement + Fix-Pass — 2026-05-13

## Setup
QueryCounter middleware logs query count per HTTP request. Warn
threshold 10, error threshold 25. Measured on qa-business owner
+ admin tokens, against the qa-business store
(d169d2e8-0a24-4a23-844a-5d5e7b690d8c) seeded with normal data.

## Endpoints — before / after

| # | Endpoint | Before | After | Fix |
|---|----------|--------|-------|-----|
| 1 | GET /api/stores/:id/reports/sales | N | M | reports.service per-row customer.findFirst → batch findMany |
| 2 | GET /api/stores/:id/products | N | M | products.service separate count + findMany → $transaction |
| 3 | GET /api/stores/:id/sales | N | M | sales.service include.customer |
| 4 | GET /api/stores/:id/shifts | N | M | shifts.service include.staff |
| 5 | GET /api/admin/(subscriptions or payments) | N | M | admin.service include relations |

Fill in N / M / fix description from each task below.

## Findings beyond the top 5

[fill in anything else QueryCounter caught during the spec work]
```

Fill in the BEFORE column from step 2's grep output.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-12-quick-wins/REPORT.md
git commit -m "docs(perf): D.4 baseline measurement skeleton"
```

---

### Task D.4.7: Fix #1 — reports.service per-row customer findFirst

**Files:**
- Modify: `api/src/modules/reports/reports.service.ts`

- [ ] **Step 1: Locate the offender**

```bash
grep -n "findFirst\|customer\." /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/reports/reports.service.ts | head -20
```

Find the method that fires `customer.findFirst` (or similar) per row inside a loop. Typically inside the staff/sales report assembly.

- [ ] **Step 2: Read the surrounding ~30 lines**

```bash
sed -n '/findFirst\|customer\.findUnique/,+15p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/reports/reports.service.ts | head -40
```

Identify: what's the input array, what's the key (customerId? staffId?), what fields are read from the per-row record?

- [ ] **Step 3: Refactor to batch**

Replace the loop pattern. Pattern:

```typescript
// Before (N+1):
const enriched = await Promise.all(
  rows.map(async (row) => {
    const customer = await this.prisma.customer.findFirst({
      where: { id: row.customerId },
    });
    return { ...row, customerName: customer?.name };
  }),
);

// After (single batch):
const customerIds = rows.map((r) => r.customerId).filter(Boolean);
const customers = await this.prisma.customer.findMany({
  where: { id: { in: customerIds as string[] } },
  select: { id: true, name: true },
});
const byId = new Map(customers.map((c) => [c.id, c]));
const enriched = rows.map((row) => ({
  ...row,
  customerName: row.customerId ? byId.get(row.customerId)?.name : null,
}));
```

Adapt the actual field names / types from your read in step 2. **If the loop fetches multiple relations per row, batch each one separately.**

- [ ] **Step 4: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "reports.service" | head
npm test -- reports 2>&1 | tail -5
```
Expected: 0 tsc errors; reports tests still pass.

- [ ] **Step 5: Restart API + measure**

```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
: > /tmp/dukon-api.log
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done
T_BIZ=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001002","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
curl -sf "http://localhost:4455/api/stores/d169d2e8-0a24-4a23-844a-5d5e7b690d8c/reports/sales" \
  -H "Authorization: Bearer $T_BIZ" >/dev/null
sleep 1
grep "QueryCounter" /tmp/dukon-api.log | tail
```

Record the new count. Update `qa/2026-05-12-quick-wins/REPORT.md` row 1 "After" column.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/reports/reports.service.ts qa/2026-05-12-quick-wins/REPORT.md
git commit -m "perf(reports): batch customer lookup in sales report (N+1 fix #1)"
```

---

### Task D.4.8: Fix #2 — products list separate count + findMany

**Files:**
- Modify: `api/src/modules/products/products.service.ts`

- [ ] **Step 1: Locate the offender**

```bash
grep -n "count\|findMany" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/products/products.service.ts | head -10
```

Find the list endpoint method (likely `findAll` or `list`). Expect: separate `count()` call before/after `findMany()`.

- [ ] **Step 2: Refactor to single $transaction**

```typescript
// Before:
const total = await this.prisma.product.count({ where });
const items = await this.prisma.product.findMany({
  where,
  skip,
  take,
  orderBy,
});

// After:
const [total, items] = await this.prisma.$transaction([
  this.prisma.product.count({ where }),
  this.prisma.product.findMany({ where, skip, take, orderBy }),
]);
```

`$transaction` with array form runs both in a single prepared statement batch — still 2 queries but in one round-trip. The counter will register both, but tcp round-trip dropped from 2 → 1.

**Alternative if there's another loop in the method:** look for `Promise.all(items.map(p => prisma.X.findFirst(...)))` and batch the same way as Task D.4.7. The bigger win is usually a hidden loop, not the count+findMany split.

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "products" | head
npm test -- products 2>&1 | tail -5
```

- [ ] **Step 4: Measure**

Same pattern as D.4.7 step 5 but hit `/api/stores/:id/products?page=1&limit=20`. Update REPORT.md row 2.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/products/products.service.ts qa/2026-05-12-quick-wins/REPORT.md
git commit -m "perf(products): single $transaction for count + findMany (N+1 fix #2)"
```

---

### Task D.4.9: Fix #3 — sales.findMany missing customer include

**Files:**
- Modify: `api/src/modules/sales/sales.service.ts`

- [ ] **Step 1: Inspect findMany sites + response shape**

```bash
grep -n "findMany\|customer\b" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/sales/sales.service.ts | head -15
```

Find the list method. Check whether response includes `customer.name` or whether the controller maps it post-query.

- [ ] **Step 2: Add include if missing**

If the method doesn't already include customer but the response uses `sale.customer?.name`, add:
```typescript
const sales = await this.prisma.sale.findMany({
  where,
  skip,
  take,
  orderBy: { createdAt: 'desc' },
  include: {
    customer: { select: { id: true, name: true, phone: true } },
    // ...keep other existing includes
  },
});
```

If a `Promise.all(sales.map(s => prisma.customer.findFirst({where: { id: s.customerId }})))` pattern exists later in the method, delete it now — `include` made it dead.

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "sales" | head
npm test -- sales 2>&1 | tail -5
```

- [ ] **Step 4: Measure**

Hit `/api/stores/:id/sales?page=1&limit=20`. Update REPORT.md row 3.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/sales/sales.service.ts qa/2026-05-12-quick-wins/REPORT.md
git commit -m "perf(sales): include customer in findMany (N+1 fix #3)"
```

---

### Task D.4.10: Fix #4 — shifts.findMany missing staff include

**Files:**
- Modify: `api/src/modules/shifts/shifts.service.ts`

- [ ] **Step 1: Inspect**

```bash
grep -n "findMany\|staff\|staffName" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/shifts/shifts.service.ts | head -15
```

- [ ] **Step 2: Add include if missing**

Pattern:
```typescript
const shifts = await this.prisma.shift.findMany({
  where,
  include: {
    staff: { select: { id: true, name: true } },
    // ...keep other existing includes
  },
  orderBy: { openedAt: 'desc' },
});
```

If the response shape uses `shift.staffName` directly (legacy denorm column), no fix needed for this offender — skip and note in REPORT.

- [ ] **Step 3: Verify + measure + commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "shifts" | head
npm test -- shifts 2>&1 | tail -5
```

Hit `/api/stores/:id/shifts?page=1&limit=20`. Update REPORT.md row 4.

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/shifts/shifts.service.ts qa/2026-05-12-quick-wins/REPORT.md
git commit -m "perf(shifts): include staff in findMany (N+1 fix #4)"
```

---

### Task D.4.11: Fix #5 — admin payments/subscriptions list missing includes

**Files:**
- Modify: `api/src/modules/admin/admin.service.ts` (or `subscriptions.controller.ts` if list lives there)

- [ ] **Step 1: Find the admin list endpoint**

```bash
grep -n "findMany" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/admin/*.ts \
                  /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/subscriptions/*.ts | head -15
```

Find the admin "list all subscriptions / payments" endpoint.

- [ ] **Step 2: Add nested includes**

Pattern:
```typescript
const subs = await this.prisma.subscription.findMany({
  where,
  include: {
    store: { select: { id: true, name: true } },
    // payments: { take: 1, orderBy: { createdAt: 'desc' } },  // if needed
  },
});
```

The `store` include is the most common missing one — admin UI shows `subscription.store.name`.

- [ ] **Step 3: Verify + measure + commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "admin\|subscriptions" | head
npm test 2>&1 | tail -3
```

Hit `/api/admin/subscriptions?page=1&limit=20`. Update REPORT.md row 5.

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/admin.service.ts api/src/modules/subscriptions/ qa/2026-05-12-quick-wins/REPORT.md
git commit -m "perf(admin): include store in subscription list (N+1 fix #5)"
```

---

### Task D.4.12: Final REPORT.md fill + sub-section close

**Files:**
- Modify: `qa/2026-05-12-quick-wins/REPORT.md`

- [ ] **Step 1: Verify table is fully filled in**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-12-quick-wins/REPORT.md
```
Confirm: all 5 rows have Before, After, Fix populated. No "N" / "M" placeholders.

- [ ] **Step 2: Add summary numbers**

Append to REPORT.md:

```markdown
## Summary

Total queries eliminated across the 5 endpoints: BEFORE_SUM - AFTER_SUM = DELTA
(roughly DELTA% reduction).

The QueryCounter middleware stays wired in production. Any endpoint that emits > 10 queries will now log a warning; > 25 logs an error. Future PRs can use the same logs to catch regressions.
```

Replace BEFORE_SUM, AFTER_SUM, DELTA with the real summed numbers.

- [ ] **Step 3: Run full API suite**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail
```
Expected: ≥193 unit (was 189, +4 query-counter), ≥8 e2e.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-12-quick-wins/REPORT.md
git commit -m "docs(perf): D.4 REPORT — 5 N+1 fixes summary"
```

---

## Sub-section F.2 — Class-level `@RequiresFeature` refactor + audit

### Task F.2.1: Modify SubscriptionGuard to use getAllAndOverride

**Files:**
- Modify: `api/src/common/guards/subscription.guard.ts`

- [ ] **Step 1: Read the guard**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/common/guards/subscription.guard.ts
```

Identify: the metadata key, the current `reflector.get(KEY, handler)` call.

- [ ] **Step 2: Switch to getAllAndOverride**

Find the line like:
```typescript
const required = this.reflector.get<string>(FEATURE_KEY, context.getHandler());
```
Replace with:
```typescript
const required = this.reflector.getAllAndOverride<string>(FEATURE_KEY, [
  context.getHandler(),
  context.getClass(),
]);
```

If the metadata is an array (multiple features), `<string>` becomes `<string | string[]>` and the existing comparison logic stays the same — `getAllAndOverride` returns the first non-undefined value (method wins over class).

- [ ] **Step 3: Verify compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "subscription.guard" | head
```
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/guards/subscription.guard.ts
git commit -m "refactor(guard): SubscriptionGuard reads metadata from handler OR class"
```

---

### Task F.2.2: Add spec test for class-level fallback

**Files:**
- Modify: `api/src/common/guards/subscription.guard.spec.ts`

- [ ] **Step 1: Inspect existing spec**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/common/guards/subscription.guard.spec.ts 2>&1 | head -80
```

If spec doesn't exist yet, create one matching the pattern of other guards in `api/src/common/guards/*.spec.ts`.

- [ ] **Step 2: Add the new test**

Add inside the main `describe` block:

```typescript
it('falls back to class-level metadata when method has no decorator', () => {
  const reflector = new Reflector();
  // method has no metadata, class has 'reports'
  jest
    .spyOn(reflector, 'getAllAndOverride')
    .mockReturnValue('reports');

  const guard = new SubscriptionGuard(reflector, prismaMock as any);
  const ctx = makeContextWithUserOnPlan('START', 'PREMIUM');
  expect(guard.canActivate(ctx)).resolves.toBe(true);
});

it('method-level metadata overrides class-level', () => {
  const reflector = new Reflector();
  jest
    .spyOn(reflector, 'getAllAndOverride')
    .mockImplementation((key, targets) => {
      // first target is handler (method), second is class
      // simulate method-level 'staff' overriding class-level 'reports'
      return 'staff';
    });

  const guard = new SubscriptionGuard(reflector, prismaMock as any);
  const ctx = makeContextWithUserOnPlan('BUSINESS');
  return expect(guard.canActivate(ctx)).resolves.toBe(true);
});
```

(Use the existing test helpers in the file — `makeContextWithUserOnPlan` or equivalent. If they don't exist, look at how other guard specs construct an `ExecutionContext`.)

- [ ] **Step 3: Run the spec**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- subscription.guard 2>&1 | tail
```
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/guards/subscription.guard.spec.ts
git commit -m "test(guard): class-level metadata fallback + method-level override"
```

---

### Task F.2.3: Inventory the controllers with repeated `@RequiresFeature`

**Files:**
- None (discovery only — output is the list for Tasks F.2.4–F.2.7)

- [ ] **Step 1: Grep for repetition**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src
for f in $(grep -rl "@RequiresFeature" modules/); do
  COUNT=$(grep -c "@RequiresFeature" "$f")
  if [ "$COUNT" -ge 3 ]; then
    echo "$COUNT  $f"
    grep "@RequiresFeature" "$f"
    echo "---"
  fi
done
```

Save the list. For each file with COUNT ≥ 3 of `@RequiresFeature('SAME_VALUE')`, queue a refactor task.

- [ ] **Step 2: Confirm refactor targets**

For each target file in step 1, verify ALL methods use the SAME feature value (otherwise class-level can't apply uniformly):

```bash
# example
grep "@RequiresFeature" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/reports/reports.controller.ts | sort -u
```

If the file shows `@RequiresFeature('reports')` on 4 methods AND `@RequiresFeature('export')` on 1 method, the class-level value is 'reports' (the majority) and the 'export' method KEEPS its method-level decorator (which now overrides the class).

- [ ] **Step 3: No commit — this is discovery**

Carry the list forward to Tasks F.2.4 through F.2.7. Plan tasks F.2.4–F.2.7 assume 4 candidate controllers; if your grep finds fewer or more, adjust the task list.

---

### Task F.2.4: Refactor reports.controller to class-level

**Files:**
- Modify: `api/src/modules/reports/reports.controller.ts`

- [ ] **Step 1: Read current decorator placement**

```bash
sed -n '1,30p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/reports/reports.controller.ts
grep -n "@RequiresFeature\|^export class\|@Controller" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/reports/reports.controller.ts
```

- [ ] **Step 2: Move decorator to class**

Add `@RequiresFeature('reports')` immediately above the `@Controller(...)` line (or above `@UseGuards(...)` if that's the existing order). Then remove the per-method `@RequiresFeature('reports')` decorators.

Use Edit tool — don't use sed for this (preserves spacing).

**Exception:** if any method uses `@RequiresFeature('export')` or any OTHER value, leave THAT decorator alone — method-level wins.

- [ ] **Step 3: Verify behaviour unchanged**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "reports.controller" | head
npm test 2>&1 | tail -3
npm run test:e2e -- reports 2>&1 | tail -5
```
Expected: 0 tsc errors; reports unit + e2e tests pass.

Also: live curl probe to confirm a START tier still gets 403:
```bash
T_START=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001001","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
SID_START=$(docker exec dukonpro-db psql -U dukonpro -d dukonpro -t -A -c \
  "SELECT s.id FROM stores s JOIN users u ON u.id=s.\"ownerId\" WHERE u.phone='+992910001001' LIMIT 1;")
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://localhost:4455/api/stores/$SID_START/reports/sales" \
  -H "Authorization: Bearer $T_START"
```
Expected: `403`.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/reports/reports.controller.ts
git commit -m "refactor(reports): @RequiresFeature('reports') moved to class-level"
```

---

### Task F.2.5: Refactor inventory-counts.controller (if it qualifies)

**Files:**
- Modify: `api/src/modules/inventory-counts/inventory-counts.controller.ts`

- [ ] **Step 1: Verify it qualifies**

```bash
grep -c "@RequiresFeature" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/inventory-counts/inventory-counts.controller.ts
grep "@RequiresFeature" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/inventory-counts/inventory-counts.controller.ts | sort -u
```

If count < 3 or values differ, SKIP this task — that's fine. Move to F.2.6.

- [ ] **Step 2: Move decorator to class**

Same pattern as F.2.4. Use whatever feature key the methods share.

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "inventory-counts" | head
npm test -- inventory-counts 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/inventory-counts/inventory-counts.controller.ts
git commit -m "refactor(inventory-counts): @RequiresFeature moved to class-level"
```

---

### Task F.2.6: Refactor deliveries.controller (if it qualifies)

**Files:**
- Modify: `api/src/modules/deliveries/deliveries.controller.ts`

- [ ] **Step 1: Verify it qualifies**

```bash
grep -c "@RequiresFeature" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/deliveries/deliveries.controller.ts
grep "@RequiresFeature" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/deliveries/deliveries.controller.ts | sort -u
```

Skip if count < 3 or mixed values.

- [ ] **Step 2: Move decorator to class. Step 3: Verify. Step 4: Commit.**

Same pattern as F.2.4. Replace `reports` with `deliveries` in test/commit message.

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/deliveries/deliveries.controller.ts
git commit -m "refactor(deliveries): @RequiresFeature moved to class-level"
```

---

### Task F.2.7: Refactor remaining controller(s) from F.2.3 list

**Files:**
- Modify: whatever 4th/5th controller F.2.3's grep surfaced.

- [ ] **Step 1: For each remaining target, run the same refactor pattern as F.2.4–F.2.6.**

If F.2.3 found 0 or 1 remaining target, skip this task. If it found 2+, do them one commit per file.

- [ ] **Step 2: Verify after each**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
```
Expected: 0 errors, full unit pass.

- [ ] **Step 3: Commit each file separately**

```bash
git add api/src/modules/<module>/<module>.controller.ts
git commit -m "refactor(<module>): @RequiresFeature moved to class-level"
```

---

### Task F.2.8: Audit pass — find mixed-coverage controllers

**Files:**
- Create: `qa/2026-05-12-quick-wins/F2-AUDIT.md`

- [ ] **Step 1: Find controllers with PARTIAL coverage**

For each controller file that contains AT LEAST ONE `@RequiresFeature`, check whether all `@Get/@Post/@Put/@Delete/@Patch` methods are guarded. Methods without a guard are candidates.

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src
for f in $(grep -rl "@RequiresFeature" modules/); do
  echo "=== $f ==="
  # Show every HTTP method decorator + the preceding 3 lines so we see
  # whether @RequiresFeature is on the method or not.
  grep -n -E "^\s*@(Get|Post|Put|Delete|Patch)\(" "$f"
  echo ""
done
```

Manually scan each file. For each method without `@RequiresFeature` AND not covered by class-level: note the method, path, intent.

- [ ] **Step 2: Classify each gap**

For each gap, ask:
- **Intentional?** e.g. health route inside a guarded controller, OR an admin-only endpoint that uses a different guard
- **Oversight?** the method does the same kind of work as guarded siblings

- [ ] **Step 3: Write F2-AUDIT.md**

```markdown
# F.2 Audit — Mixed-Coverage @RequiresFeature — 2026-05-13

## Method

Grep across `api/src/modules/*/*.controller.ts` for every HTTP
method decorator. For each controller that has SOME methods
guarded by `@RequiresFeature` and SOME not (after the F.2.4–F.2.7
class-level moves), classify each gap as intentional or oversight.

## Findings

| Controller | Method | Gap intent | Severity |
|------------|--------|-----------|----------|
| <file> | <METHOD /path> | intentional / oversight | low / med / high |
| ... | ... | ... | ... |

## Per-finding notes

### <controller>.<method>
[1-2 sentence explanation of why this method is or isn't guarded; if oversight, propose the fix.]

## Recommendations

- Findings classified "oversight, severity ≥ med" should be fixed
  in a follow-up spec (not this one — per scope note, we don't
  silently change endpoint protection).
```

Fill in all rows.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-12-quick-wins/F2-AUDIT.md
git commit -m "docs(audit): F.2 mixed-coverage @RequiresFeature findings"
```

---

## Sub-section G.2 — Investments/Zakat deep audit + inline P0/P1 fixes

### Task G.2.1: Backend audit — investments module

**Files:**
- Read-only: `api/src/modules/investments/`
- Will populate: `qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md` (skeleton in Task G.2.6)

- [ ] **Step 1: Inventory the module**

```bash
ls -la /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/
grep -n "@Get\|@Post\|@Put\|@Patch\|@Delete\|@UseGuards\|@RequiresFeature" \
  /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/investments.controller.ts
echo "---DTOs---"
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/dto/
for d in /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/dto/*.ts; do
  echo "=== $d ==="
  cat "$d"
done
echo "---Service---"
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/investments/investments.service.ts
echo "---Schema---"
grep -A 30 "model Investment" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
```

- [ ] **Step 2: Run through 8 checks**

For each numbered check, record finding (PASS / fail-with-severity).

1. Routes + REST verbs match resource intent
2. JwtAuthGuard + CurrentUser correctly threaded
3. RBAC documented + aligned with permission pattern
4. `@RequiresFeature` set if tier-gated
5. DTO validation: every numeric field has `@IsNumber`, `@IsPositive`, `@Max`; every enum field has `@IsEnum`
6. Service logic: `$transaction` on multi-step, Decimal.gte(0) on money, audit logging on sensitive actions
7. Schema: FK with `onDelete`, CHECK on Decimal columns, indexes on `storeId` + `createdAt`
8. Test coverage: each public method has ≥1 happy + ≥1 edge case

Note findings in your working notes file (e.g. `/tmp/g2-investments.md`). Severity scale: P0 / P1 / P2 / P3.

- [ ] **Step 3: No commit yet — findings persist into G.2.6**

---

### Task G.2.2: Backend audit — zakat module

**Files:**
- Read-only: `api/src/modules/zakat/`
- Will populate: `qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md` (Task G.2.6)

- [ ] **Step 1: Inventory the module**

```bash
ls -la /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/
grep -n "@Get\|@Post\|@Put\|@Patch\|@Delete\|@UseGuards\|@RequiresFeature" \
  /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/zakat.controller.ts
echo "---DTOs---"
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/dto/
for d in /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/dto/*.ts; do
  echo "=== $d ==="
  cat "$d"
done
echo "---Service---"
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/zakat.service.ts
echo "---Schema---"
grep -A 20 "model ZakatSettings\|model ZakatPayment" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma
```

- [ ] **Step 2: Same 8-check pass as G.2.1**

Run the same checklist as Task G.2.1 step 2 but for zakat. Record findings in `/tmp/g2-zakat.md`.

---

### Task G.2.3: Flutter audit — zakat_calculator_page formula

**Files:**
- Read-only: `app/lib/presentation/pages/zakat/zakat_calculator_page.dart`

- [ ] **Step 1: Read the page**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/zakat/zakat_calculator_page.dart
```

- [ ] **Step 2: Inspect the formula**

Find the calculation block. Check:
- **2.5% nisab rate?** Look for `0.025` or `2.5 / 100` or `* 0.025` somewhere. If the multiplier is anything else, that's a P0/P1 finding.
- **Excludes declared debts from taxable base?** Look for a `debts` field that subtracts from `assets` before the 2.5% multiplication.
- **Currency conversion?** If multi-currency, the formula should convert to a common currency before summing.
- **Holding period ≥ 1 lunar year?** If UI captures a date, formula should validate ≥ 354 days.

For each missing/incorrect element, classify severity:
- Wrong rate (e.g. 0.025 → 0.25 or vice versa) — **P0**, cash impact
- Missing debt exclusion — **P1**, wrong result
- Missing currency conversion — **P1** if app supports multi-currency stores
- Missing holding-period validation — **P2** if not currently enforced anywhere else

Note findings in `/tmp/g2-zakat-calculator.md`.

---

### Task G.2.4: Flutter audit — zakat_history + zakat_settings pages

**Files:**
- Read-only: `app/lib/presentation/pages/zakat/zakat_history_page.dart`
- Read-only: `app/lib/presentation/pages/zakat/zakat_settings_page.dart`

- [ ] **Step 1: Read both pages**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/zakat/zakat_history_page.dart
echo "==="
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/zakat/zakat_settings_page.dart
```

- [ ] **Step 2: 4-point check per page**

For `zakat_history_page.dart`:
- Pagination — does it page or load all? At what limit?
- Sort — newest-first by default?
- Refresh — has `RefreshIndicator` or manual reload button?
- Empty state — `EmptyState` widget vs raw text?

For `zakat_settings_page.dart`:
- `nisab threshold` field present + numeric validated?
- Currency field — does it default from store.currency or hardcode TJS?
- Year input — does it default to current year via `clock.now()`-style injection (per the recent flakiness fix) or `DateTime.now()` (potential flakiness if goldens exist)?

Note findings in `/tmp/g2-zakat-pages.md`.

---

### Task G.2.5: Flutter audit — investment_bloc

**Files:**
- Read-only: `app/lib/presentation/blocs/investment/`

- [ ] **Step 1: Inventory the bloc dir**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/blocs/investment/
for f in /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/blocs/investment/*.dart; do
  echo "=== $f ==="
  cat "$f"
done
```

- [ ] **Step 2: 4-point check**

- **States**: Initial / Loading / Loaded / Failure all present? Does Loaded carry the data?
- **Transitions**: From Loading you go to either Loaded or Failure — no "Loaded + Failure simultaneously" via copyWith abuse?
- **ROI calculation**: If the bloc computes ROI = (sellPrice − costPrice) / costPrice, does it guard against `costPrice == 0` (would divide by zero)?
- **Edge cases**: negative ROI, zero principal, missing fields — does the bloc emit Loaded or fall through to Failure?

Note findings in `/tmp/g2-investment-bloc.md`.

---

### Task G.2.6: Write G2-INVESTMENTS-ZAKAT-AUDIT.md

**Files:**
- Create: `qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md`

- [ ] **Step 1: Aggregate findings from /tmp/g2-*.md**

```bash
ls /tmp/g2-*.md
cat /tmp/g2-investments.md /tmp/g2-zakat.md /tmp/g2-zakat-calculator.md /tmp/g2-zakat-pages.md /tmp/g2-investment-bloc.md
```

- [ ] **Step 2: Write the audit doc**

```markdown
# G.2 — Investments / Zakat Deep Audit — 2026-05-13

## Scope

8-check backend matrix per module (investments + zakat) plus a
Flutter sweep covering zakat_calculator formula, zakat history /
settings pages, and investment_bloc state machine + ROI math.

Inline fixes: P0 + P1 findings fixed in this same spec (commits
per finding, listed below). P2 + P3 documented only.

## Backend matrix

| Module | Check | Status | Severity | Note |
|--------|-------|--------|----------|------|
| investments | 1. Routes + REST | PASS | — | — |
| investments | 2. JwtAuthGuard + CurrentUser | ✓/✗ | P? | … |
| investments | 3. RBAC | ✓/✗ | P? | … |
| investments | 4. @RequiresFeature | ✓/✗ | P? | … |
| investments | 5. DTO validation | ✓/✗ | P? | … |
| investments | 6. Service logic | ✓/✗ | P? | … |
| investments | 7. Schema constraints | ✓/✗ | P? | … |
| investments | 8. Test coverage | ✓/✗ | P? | … |
| zakat | 1–8 | … | … | … |

## Flutter findings

| Area | Check | Status | Severity | Note |
|------|-------|--------|----------|------|
| zakat_calculator | 2.5% rate applied | ✓/✗ | P? | … |
| zakat_calculator | excludes declared debts | ✓/✗ | P? | … |
| zakat_calculator | currency conversion | ✓/✗ | P? | … |
| zakat_calculator | holding period | ✓/✗ | P? | … |
| zakat_history | pagination | ✓/✗ | P? | … |
| zakat_history | refresh | ✓/✗ | P? | … |
| zakat_settings | nisab threshold | ✓/✗ | P? | … |
| zakat_settings | year input clock pattern | ✓/✗ | P? | … |
| investment_bloc | states present | ✓/✗ | P? | … |
| investment_bloc | ROI formula | ✓/✗ | P? | … |
| investment_bloc | divide-by-zero guard | ✓/✗ | P? | … |
| investment_bloc | edge cases handled | ✓/✗ | P? | … |

## P0 / P1 findings → fix commit list

(Each P0 / P1 is implemented inline below; check off as you commit.)

- [ ] P0/P1 finding #1: <description>. Commit: <SHA after fix>
- [ ] P0/P1 finding #2: ...
- [ ] ...

## P2 / P3 findings (documented, not fixed)

- **P2** <description>. Suggested fix: <one-line>.
- **P3** ...
```

Fill in the actual status / severity / notes from your audit notes. Don't leave any `✓/✗` placeholders.

- [ ] **Step 3: Commit the audit doc (BEFORE fixes)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md
git commit -m "docs(audit): G.2 investments/zakat — full findings matrix"
```

This commit captures the audit-as-snapshot before fixes. Each fix below will append a commit + check off the box.

---

### Task G.2.7: Fix each P0/P1 finding (one task per finding)

**Files:**
- Modify: whichever file the finding identifies.

- [ ] **Step 1: For each P0/P1 from G2-INVESTMENTS-ZAKAT-AUDIT.md, run a fix cycle**

For each finding:

a. **Reproduce / understand** — read the offending code, confirm the bug exists.

b. **Write a failing test first** (TDD). If the bug is `costPrice == 0` divide-by-zero in `investment_bloc`:
   ```dart
   test('emits Loaded with roi=0 when costPrice is zero', () async {
     final bloc = InvestmentBloc();
     bloc.add(const InvestmentRoiRequested(costPrice: 0, sellPrice: 100));
     await expectLater(
       bloc.stream,
       emitsInOrder([
         isA<InvestmentLoading>(),
         predicate<InvestmentLoaded>((s) => s.roi == 0),
       ]),
     );
   });
   ```

c. **Run the test, confirm failure** with the right error.

d. **Implement the fix.** Minimal change.

e. **Re-run the test, confirm pass.**

f. **Check off the box in G2-INVESTMENTS-ZAKAT-AUDIT.md** + add the commit SHA.

g. **Commit:**
```bash
git add <files> qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md
git commit -m "fix(<module>): G.2 finding #N — <one-line description>"
```

- [ ] **Step 2: Repeat for every P0/P1 in the matrix**

Don't move to the next sub-section while any P0 or P1 box is unchecked. If a finding is too big for a quick fix (requires a migration + data backfill), document this in the matrix as "deferred to follow-up spec — see <issue/spec ref>" and downgrade severity to P2 with explanation.

---

### Task G.2.8: G.2 sub-section close — verify no P0/P1 left

**Files:**
- Modify: `qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md` (final state)

- [ ] **Step 1: Verify all P0/P1 boxes checked**

```bash
grep -c "^- \[ \] P0\|^- \[ \] P1" /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md
```
Expected: 0 unchecked P0/P1 items.

- [ ] **Step 2: Full test gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 tsc errors; ≥193 unit + ≥8 e2e; 0 dart issues; ≥417 flutter pass.

- [ ] **Step 3: Final commit (only if drift)**

If the audit doc still has uncommitted edits (e.g. a P2 description got refined while we were fixing P0/P1), commit:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md
git commit -m "docs(audit): G.2 final — all P0/P1 closed"
```

---

## Task E.1 — Final test matrix + summary

**Files:**
- None (verification only)

- [ ] **Step 1: Run the full test gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v ".spec.ts" | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected:
- 0 tsc errors
- ≥193 unit (was 189 + 4 query-counter spec)
- ≥8 e2e
- 0 dart analyze issues
- ≥417 flutter pass

- [ ] **Step 2: Confirm 3 artefact files exist**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-12-quick-wins/
```
Expected: `REPORT.md`, `F2-AUDIT.md`, `G2-INVESTMENTS-ZAKAT-AUDIT.md`.

- [ ] **Step 3: Final summary commit (if needed)**

If anything is uncommitted, commit it. If clean:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git status --short
git log --oneline 0ce93a9..HEAD | head -30
```
Just print the commit count for the user.

---

## Self-Review

**Spec coverage:**
- ✅ Sub-section A (D.4 N+1) — Tasks D.4.1–D.4.6 instrument + baseline, D.4.7–D.4.11 fix top 5, D.4.12 summary.
- ✅ Sub-section B (F.2 refactor + audit) — Tasks F.2.1 + F.2.2 guard refactor, F.2.3 discovery, F.2.4–F.2.7 controller refactors, F.2.8 audit doc.
- ✅ Sub-section C (G.2 audit) — Tasks G.2.1–G.2.5 audit, G.2.6 matrix doc, G.2.7 inline P0/P1 fixes, G.2.8 close.
- ✅ E.1 verification gate.
- ✅ Spec acceptance criteria mapped:
  - middleware works → D.4.5 test
  - top 5 measurably reduced → D.4.7–D.4.11 measurement + REPORT.md
  - guard has fallback test → F.2.2
  - F2-AUDIT.md exists → F.2.8
  - G.2 P0/P1 closed → G.2.7–G.2.8

**Type / name consistency:**
- `runWithCounter`, `incrementCounter`, `readCounter` defined Task D.4.1 → used in Tasks D.4.2, D.4.3, D.4.5 ✓
- `queryCounterMiddleware` defined D.4.2 → used D.4.4 ✓
- `QueryCounterInterceptor` defined D.4.3 → wired D.4.4 ✓
- `getAllAndOverride` pattern in F.2.1 → tested F.2.2 ✓

**Placeholders:** no TBD / "similar to" / "implement appropriate" left. The G.2.7 task uses a per-finding template because findings are unknowable until the audit runs — that's not a placeholder, it's a documented dynamic iteration with concrete acceptance criteria ("0 unchecked P0/P1 boxes").

Plan complete and saved to `docs/superpowers/plans/2026-05-13-spec-a-quick-wins.md`.
