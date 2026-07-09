# TypeScript Test Error Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all 15 pre-existing TypeScript errors in 4 API spec files so `npx tsc --noEmit` exits with code 0.

**Architecture:** Four independent surgical fixes — optional chaining (health), remove `as any` cast (notifications), hoist type aliases + explicit return type (payroll), delete duplicate object key (products). No production code touched.

**Tech Stack:** TypeScript 5.x, Jest, NestJS test utilities

---

## File map

| Task | File | Lines touched | Error type |
|---|---|---|---|
| 1 | `api/src/modules/products/products.service.spec.ts` | 72–78 (delete) | Duplicate object key |
| 2 | `api/src/modules/health/health.controller.spec.ts` | 69 | Optional property access |
| 3 | `api/src/modules/notifications/notifications.service.spec.ts` | 153 | `as any` erases Map types |
| 4 | `api/src/modules/payroll/payroll.service.spec.ts` | 12–70 (hoist + return type) | `const api: any` erases Map types |

---

## Task 1: Remove duplicate `count` key in products spec

**Files:**
- Modify: `api/src/modules/products/products.service.spec.ts:72-78`

**Context:** The `product` object literal has two `count` keys. The first (lines 72–78) only filters by `storeId`. The second (lines 105–113) filters by both `storeId` and `isActive` — it is a strict superset. TypeScript error TS1117 fires on the second one because the first key shadows it. Deleting the first key fixes the error without changing any test behaviour.

- [ ] **Step 1: Confirm both `count` keys**

```bash
grep -n "count:" api/src/modules/products/products.service.spec.ts
```

Expected output — two lines:
```
72:      count: jest.fn(async ({ where }: any = {}) => {
105:      count: jest.fn(async ({ where }: any) => {
```

- [ ] **Step 2: Delete the first (simpler) `count` block — lines 72–78**

Remove these 7 lines from `api/src/modules/products/products.service.spec.ts`:

```ts
      count: jest.fn(async ({ where }: any = {}) => {
        return Array.from(rows.values()).filter((r) => {
          if (where?.storeId && r.storeId !== where.storeId) return false;
          return true;
        }).length;
      }),
```

The `create` block that immediately follows becomes the next method in the object literal. Nothing else changes.

- [ ] **Step 3: Verify no TS errors remain in this file**

```bash
cd api && npx tsc --noEmit 2>&1 | grep products.service.spec
```

Expected: no output (no errors in that file).

- [ ] **Step 4: Run tests**

```bash
cd api && npx jest products.service.spec --no-coverage 2>&1 | tail -5
```

Expected: all tests pass, same count as before.

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/products/products.service.spec.ts
git commit -m "fix(test): remove duplicate count key in products fake (TS1117)"
```

---

## Task 2: Fix optional property access in health spec

**Files:**
- Modify: `api/src/modules/health/health.controller.spec.ts:69`

**Context:** `controller.check()` returns `HealthCheckResult` from `@nestjs/terminus`. That type declares `error` as optional (`error?: HealthIndicatorResult`). Line 69 accesses `result.error.database.status` without narrowing — TS18048. The fix uses optional chaining, which is type-safe and preserves the assertion: if `error` is unexpectedly undefined at runtime, Jest reports `Expected: 'down', Received: undefined` and the test fails correctly.

- [ ] **Step 1: Apply optional chaining on line 69**

Current line 69:
```ts
    expect(result.error.database.status).toBe('down');
```

Replace with:
```ts
    expect(result.error?.database?.status).toBe('down');
```

- [ ] **Step 2: Verify no TS errors remain in this file**

```bash
cd api && npx tsc --noEmit 2>&1 | grep health.controller.spec
```

Expected: no output.

- [ ] **Step 3: Run tests**

```bash
cd api && npx jest health.controller.spec --no-coverage 2>&1 | tail -5
```

Expected: both tests pass.

- [ ] **Step 4: Commit**

```bash
git add api/src/modules/health/health.controller.spec.ts
git commit -m "fix(test): use optional chaining for result.error in health spec (TS18048)"
```

---

## Task 3: Remove `as any` cast in notifications spec

**Files:**
- Modify: `api/src/modules/notifications/notifications.service.spec.ts:153`

**Context:** `makePrismaFake()` ends with `} as any`. This cast erases all inferred types on the return value. Consequently `prisma.__notifications` and `prisma.__fcmTokens` are typed as `any`, and `Array.from(any.values())[0]` resolves to `unknown` via TypeScript's `Array.from` overloads — causing errors on lines 249, 261, 315, 327, 339. The three Map types (`NotificationRow`, `FcmTokenRow`, `StoreRow`) are already declared in the file. Removing `as any` makes TypeScript infer `__notifications: Map<string, NotificationRow>` etc. from the return literal.

The `useValue: prisma` in `Test.createTestingModule` accepts `any`, so the fake does not need to satisfy the full `PrismaService` interface.

- [ ] **Step 1: Remove `as any` from the return statement**

Find this block (around line 146–153):
```ts
  return {
    notification,
    fcmToken,
    store,
    __notifications: notifications,
    __fcmTokens: fcmTokens,
    __stores: stores,
  } as any;
```

Change to:
```ts
  return {
    notification,
    fcmToken,
    store,
    __notifications: notifications,
    __fcmTokens: fcmTokens,
    __stores: stores,
  };
```

- [ ] **Step 2: Verify no TS errors remain in this file**

```bash
cd api && npx tsc --noEmit 2>&1 | grep notifications.service.spec
```

Expected: no output.

- [ ] **Step 3: Run tests**

```bash
cd api && npx jest notifications.service.spec --no-coverage 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add api/src/modules/notifications/notifications.service.spec.ts
git commit -m "fix(test): remove as-any cast in notifications fake — restores Map types (TS18046)"
```

---

## Task 4: Hoist type aliases and add explicit return type in payroll spec

**Files:**
- Modify: `api/src/modules/payroll/payroll.service.spec.ts:12–70`

**Context:** `$transaction` closes over `api` itself (`return cb(api)`), so the author wrote `const api: any = {...}` to avoid a self-reference error. This erases the types of all exposed Maps (`_periods`, `_payrolls`, etc.), causing 7 TS18046 errors. 

The fix has two parts:
1. **Hoist** the 6 type aliases (`Period`, `StaffRow`, `PayrollRow`, `AdjRow`, `SaleRow`, `ShiftRow`) from inside `makePrismaFake` to module scope so they can be used in the function's return type annotation.
2. **Add an explicit return type** to `makePrismaFake()`. With a declared return type, TypeScript trusts it — `prisma._periods` is `Map<string, PeriodRow>` at all call sites, regardless of `const api: any` inside the body.

Note: the type `Period` conflicts with a common name, so rename it `PeriodRow` when hoisting (or keep `Period` — just be consistent). The spec uses `PeriodRow` to avoid collisions.

- [ ] **Step 1: Remove the 6 `type` declarations from inside `makePrismaFake`**

Delete these lines from inside `makePrismaFake` (currently lines ~14–70):

```ts
  type Period = {
    id: string;
    storeId: string;
    month: number;
    year: number;
    status: string;
    totalAmount: number;
    paidAmount: number;
  };
  type StaffRow = {
    id: string;
    storeId: string;
    salary: number;
    commission: number;
    isActive: boolean;
    user: { name: string; phone: string; avatar: string | null };
  };
  type PayrollRow = {
    id: string;
    payrollPeriodId: string;
    staffId: string;
    baseSalary: number;
    commission: number;
    commissionRate: number;
    salesTotal: number;
    shiftsWorked: number;
    shiftsExpected: number;
    totalAmount: number;
    isPaid: boolean;
    paidAt: Date | null;
  };
  type AdjRow = {
    id: string;
    payrollId: string;
    type: 'BONUS' | 'DEDUCTION';
    amount: number;
    description: string;
    date: Date;
  };
  type SaleRow = {
    id: string;
    storeId: string;
    staffId: string;
    total: number;
    createdAt: Date;
  };
  type ShiftRow = {
    id: string;
    staffId: string;
    status: 'OPEN' | 'CLOSED';
    openedAt: Date;
  };
```

- [ ] **Step 2: Add the same type declarations at module scope (before `function makePrismaFake`)**

Insert immediately after the last `import` line and before the `// Behavioral fake` comment:

```ts
type PeriodRow = {
  id: string;
  storeId: string;
  month: number;
  year: number;
  status: string;
  totalAmount: number;
  paidAmount: number;
};
type StaffRow = {
  id: string;
  storeId: string;
  salary: number;
  commission: number;
  isActive: boolean;
  user: { name: string; phone: string; avatar: string | null };
};
type PayrollRow = {
  id: string;
  payrollPeriodId: string;
  staffId: string;
  baseSalary: number;
  commission: number;
  commissionRate: number;
  salesTotal: number;
  shiftsWorked: number;
  shiftsExpected: number;
  totalAmount: number;
  isPaid: boolean;
  paidAt: Date | null;
};
type AdjRow = {
  id: string;
  payrollId: string;
  type: 'BONUS' | 'DEDUCTION';
  amount: number;
  description: string;
  date: Date;
};
type SaleRow = {
  id: string;
  storeId: string;
  staffId: string;
  total: number;
  createdAt: Date;
};
type ShiftRow = {
  id: string;
  staffId: string;
  status: 'OPEN' | 'CLOSED';
  openedAt: Date;
};
```

Also update the one remaining internal `type Period` reference — the body uses `const p: Period = {`. Change it to `const p: PeriodRow = {`.

- [ ] **Step 3: Add explicit return type to `makePrismaFake`**

Change the function signature from:
```ts
function makePrismaFake() {
```

To:
```ts
function makePrismaFake(): {
  _periods: Map<string, PeriodRow>;
  _staff: Map<string, StaffRow>;
  _payrolls: Map<string, PayrollRow>;
  _adjustments: Map<string, AdjRow>;
  _sales: Map<string, SaleRow>;
  _shifts: Map<string, ShiftRow>;
  payrollPeriod: {
    findFirst: jest.Mock;
    findMany: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
  };
  staff: { findMany: jest.Mock };
  shift: { count: jest.Mock };
  sale: { aggregate: jest.Mock };
  payroll: {
    findFirst: jest.Mock;
    findUnique: jest.Mock;
    findMany: jest.Mock;
    upsert: jest.Mock;
    update: jest.Mock;
    updateMany: jest.Mock;
  };
  payrollAdjustment: {
    create: jest.Mock;
    findFirst: jest.Mock;
    delete: jest.Mock;
  };
  $transaction: jest.Mock;
} {
```

The body is unchanged — `const api: any = {...}; return api;` stays as-is. TypeScript enforces the declared return type at the call site without needing to resolve the self-referential `api`.

- [ ] **Step 4: Verify no TS errors remain in this file**

```bash
cd api && npx tsc --noEmit 2>&1 | grep payroll.service.spec
```

Expected: no output.

- [ ] **Step 5: Run tests**

```bash
cd api && npx jest payroll.service.spec --no-coverage 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add api/src/modules/payroll/payroll.service.spec.ts
git commit -m "fix(test): hoist payroll type aliases + explicit return type — removes as-any (TS18046)"
```

---

## Final verification

- [ ] **Full TS check — 0 errors**

```bash
cd api && npx tsc --noEmit 2>&1
```

Expected: no output, exit code 0.

- [ ] **Full test suite — 241 passing**

```bash
cd api && npx jest --no-coverage 2>&1 | grep "Tests:"
```

Expected: `Tests: 241 passed, 241 total`

- [ ] **Commit if anything was missed**

```bash
git add -p  # review any unstaged hunks
```
