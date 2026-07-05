# Design — TypeScript Test Error Fixes

**Date:** 2026-07-06  
**Scope:** Fix 15 pre-existing TypeScript errors across 4 API test files. No production code changes, no migrations, no new tests.

## Summary

All errors are in `*.spec.ts` files and fall into four categories: optional-property access without narrowing (health), type erasure via `as any` on a return (notifications), type erasure via `const api: any` with self-referential `$transaction` (payroll), and a duplicate object key (products). All 241 API tests continue to pass after the fixes.

---

## File 1 — `health.controller.spec.ts` (2 errors)

**Root cause:** `HealthCheckResult` from `@nestjs/terminus` declares `error` as an optional field (`error?: HealthIndicatorResult`). TypeScript refuses direct access without a null check.

**Fix:** Replace direct property access with optional chaining.

```ts
// Before (TS18048):
expect(result.error.database.status).toBe('down');

// After:
expect(result.error?.database?.status).toBe('down');
```

The test assertion is semantically equivalent — if `error` is unexpectedly `undefined`, Jest will report `Expected: 'down', Received: undefined` and the test fails correctly.

---

## File 2 — `notifications.service.spec.ts` (5 errors)

**Root cause:** `makePrismaFake()` ends with `return { ..., __notifications: notifications, ... } as any`. The `as any` cast erases all inferred types on the returned object. As a result `prisma.__notifications` resolves to `any`, and `Array.from(any.values())[0]` is inferred as `unknown` by TypeScript's `Array.from` overloads.

**Fix:** Remove `as any` from the `return` statement. The type aliases `NotificationRow`, `FcmTokenRow`, and `StoreRow` are already declared at the top of `makePrismaFake()`. With the cast removed, TypeScript infers:

- `__notifications: Map<string, NotificationRow>`
- `__fcmTokens: Map<string, FcmTokenRow>`
- `__stores: Map<string, StoreRow>`

The `useValue: prisma` in `Test.createTestingModule` accepts `any`, so removing the cast does not require the fake to satisfy the full `PrismaService` interface.

---

## File 3 — `payroll.service.spec.ts` (7 errors)

**Root cause:** `$transaction` closes over `api` itself (`return cb(api)`) — a self-referential value. TypeScript cannot infer the type of an object that references itself before its construction completes, so the author wrote `const api: any = { ... }`. This erases the types of all exposed maps (`_periods`, `_payrolls`, etc.).

**Fix:** Keep `const api: any` internally (required for the self-reference), but add an **explicit return type** to `makePrismaFake()`. TypeScript trusts the declared return type and will type `prisma._periods` and `prisma._payrolls` correctly at all call sites.

The return type uses the locally-declared type aliases (`Period`, `PayrollRow`, `AdjRow`, `SaleRow`, `ShiftRow`, `StaffRow`) that are already defined inside the function body. To make them accessible in the return type signature, they must be hoisted to the module scope (outside the function).

Declared return type (abridged):
```ts
type PeriodRow = { id: string; storeId: string; month: number; year: number; status: string; totalAmount: number; paidAmount: number };
type PayrollRow = { id: string; payrollPeriodId: string; staffId: string; baseSalary: number; commission: number; commissionRate: number; salesTotal: number; shiftsWorked: number; shiftsExpected: number; totalAmount: number; isPaid: boolean; paidAt: Date | null };
// ... AdjRow, SaleRow, ShiftRow, StaffRow ...

function makePrismaFake(): {
  _periods: Map<string, PeriodRow>;
  _staff: Map<string, StaffRow>;
  _payrolls: Map<string, PayrollRow>;
  _adjustments: Map<string, AdjRow>;
  _sales: Map<string, SaleRow>;
  _shifts: Map<string, ShiftRow>;
  payrollPeriod: { findFirst: jest.Mock; findMany: jest.Mock; create: jest.Mock; update: jest.Mock };
  staff: { findMany: jest.Mock };
  shift: { count: jest.Mock };
  sale: { aggregate: jest.Mock };
  payroll: { findFirst: jest.Mock; findUnique: jest.Mock; findMany: jest.Mock; upsert: jest.Mock; update: jest.Mock; updateMany: jest.Mock };
  payrollAdjustment: { create: jest.Mock; findFirst: jest.Mock; delete: jest.Mock };
  $transaction: jest.Mock;
} {
  // body unchanged — const api: any remains for self-reference
}
```

---

## File 4 — `products.service.spec.ts` (1 error)

**Root cause:** The `product` object in `makePrismaFake()` has two `count` keys. The first (simpler) version filters only by `storeId`. A second `count` was added later that also filters by `isActive` — but neither key was removed.

**Fix:** Delete the first `count` implementation. The second is a strict superset — it handles both `storeId` and `isActive` filtering, so all existing tests remain valid.

---

## Acceptance

- `cd api && npx tsc --noEmit` exits with code 0 (0 errors)
- `cd api && npx jest --no-coverage` passes with 241 tests (no regression)
- No production files modified
