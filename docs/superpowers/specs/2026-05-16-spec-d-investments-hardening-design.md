# Design — Spec D "Investments Data Integrity Hardening"

**Date:** 2026-05-16
**Scope:** Apply the zakat-hardening pattern (Spec A G.2) to the
investments module. Address all 7 P2 findings from the G.2 audit.
**Decisions:** tier-gated via `hasInvestments` flag (BIZ + PREMIUM
only, START → 403). Same pattern as `hasZakat`.

## Summary

The G.2 audit (`a6cd50e`) flagged 7 P2 findings on
`investments/` — all data-integrity / discipline gaps with no real
correctness bugs. We already applied the exact same pattern to the
zakat module (commits `9e41d68`, `aa3191b`, `2557f6d`,
`30e83e3`), so this spec is a templated re-application.

One sub-section, ~1 day.

## Findings addressed (from G.2 audit)

1. ❌ → ✅ No `localId` idempotency on `Investment.create`
2. ❌ → ✅ No `$transaction` on update / delete (TOCTOU race)
3. ❌ → ✅ No `AuditLogService` on money writes
4. ❌ → ✅ Missing `@@index([storeId, createdAt(sort:Desc)])`
5. ❌ → ✅ No DB CHECK constraints on `amount` / `returnAmount`
6. ❌ → ✅ `create` and `update` zero unit tests
7. ❌ → ✅ Tier-gating: `hasInvestments` flag (decision: tier-gated)

## Architecture

### A. Schema migration

**File:** `api/prisma/migrations/20260516XXXXXX_investments_hardening/migration.sql`

```sql
-- Spec D: data integrity hardening for Investment.

-- 1. Idempotent create: client-supplied UUID for offline-replay
-- safety. Per-store unique because clients may reset UUIDs on
-- re-install (multi-tenant collision-safe).
ALTER TABLE "investments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "investments_storeId_localId_key"
  ON "investments"("storeId", "localId");

-- 2. List performance: covering index for the default sort order.
CREATE INDEX "investments_storeId_createdAt_idx"
  ON "investments"("storeId", "createdAt" DESC);

-- 3. DB-level non-negative guard.
ALTER TABLE "investments"
  ADD CONSTRAINT investments_amount_non_negative
    CHECK ("amount" >= 0),
  ADD CONSTRAINT investments_return_amount_non_negative
    CHECK ("returnAmount" IS NULL OR "returnAmount" >= 0);

-- 4. Tier-gating flag on SubscriptionPlanConfig.
ALTER TABLE "subscription_plan_configs"
  ADD COLUMN "hasInvestments" BOOLEAN NOT NULL DEFAULT false;

UPDATE "subscription_plan_configs" SET "hasInvestments" = false WHERE plan = 'START';
UPDATE "subscription_plan_configs" SET "hasInvestments" = true  WHERE plan = 'BUSINESS';
UPDATE "subscription_plan_configs" SET "hasInvestments" = true  WHERE plan = 'PREMIUM';
```

Apply via psql + register in `_prisma_migrations` (same workaround
as previous migrations due to prior drift).

### B. Schema model edits (`schema.prisma`)

```prisma
model Investment {
  ...existing fields...
  localId    String?  // Spec D
  createdAt  DateTime @default(now())

  @@index([storeId])
  @@index([status])
  @@index([storeId, createdAt(sort: Desc)])  // Spec D
  @@unique([storeId, localId])               // Spec D
  @@map("investments")
}

model SubscriptionPlanConfig {
  ...existing fields...
  hasZakat        Boolean @default(false)
  hasInvestments  Boolean @default(false)  // Spec D
  @@map("subscription_plan_configs")
}
```

### C. DTO + Service refactor

**`api/src/modules/investments/dto/create-investment.dto.ts`:**
- Add optional `localId?: string` field with `@IsOptional()` `@IsString()`

**`api/src/modules/investments/investments.service.ts`:**
- Inject `AuditLogService` in constructor
- `create(storeId, dto, userId)`:
  - Idempotency: if `dto.localId` provided, `findUnique({ where: { storeId_localId: ... } })`; if exists, return existing
  - Pass `localId: dto.localId ?? null` in `prisma.investment.create.data`
  - Audit `investment.create` with `userId, entityId, metadata: {amount, name}`
- `update(storeId, id, dto, userId)`:
  - Wrap `findOne + update` in `prisma.$transaction([...])`
  - Audit `investment.update` with `userId, entityId, metadata: {before: {amount}, after: {amount}}`
- `remove(storeId, id, userId)`:
  - Wrap `findOne + delete` in `prisma.$transaction([...])`
  - Audit `investment.delete` with `userId, entityId, metadata: {amount, name}`
- Method signatures changed: all 3 mutation methods now take `userId: string` arg

**`api/src/modules/investments/investments.controller.ts`:**
- Add to `@UseGuards(...)` chain: `SubscriptionGuard`
- Add class-level `@RequiresFeature('hasInvestments')`
- Inject `@CurrentUser('id') userId: string` into create/update/remove handlers
- Pass `userId` through to service methods

**`api/src/modules/subscriptions/subscriptions.service.ts` `seedPlanConfigs`:**
- Add `hasInvestments` field to all 3 plan configs (START=false, BIZ=true, PREMIUM=true)

### D. Tests

**`api/src/modules/investments/investments.service.spec.ts`:**
- Add `AuditLogService` mock to providers
- Update existing tests to pass `userId` arg to mutation calls
- Add 6 new tests:
  1. `create` happy path — investment row created, audit logged
  2. `create` idempotent — same `localId` returns existing without duplicate insert
  3. `update` happy path — fields mutated, audit logged with before/after
  4. `update` 404 wraps cleanly — TOCTOU race protected
  5. `remove` happy path — row deleted, audit logged
  6. `create` audit failure does NOT block creation (best-effort log)

## Files touched

**Modify:**
- `api/prisma/schema.prisma`
- `api/src/modules/investments/dto/create-investment.dto.ts`
- `api/src/modules/investments/investments.service.ts`
- `api/src/modules/investments/investments.service.spec.ts`
- `api/src/modules/investments/investments.controller.ts`
- `api/src/modules/subscriptions/subscriptions.service.ts` (seed config)

**Create:**
- `api/prisma/migrations/20260516XXXXXX_investments_hardening/migration.sql`

## Out of scope

- Refactoring `InvestmentStatus` enum (not flagged)
- Sync-queue offline support for Investment writes (separate concern)
- REST routing changes (audit confirmed verbs are clean)
- Backfilling `localId` on existing rows (NULL is exempt from unique
  index per Postgres semantics)
- Migrating historical investments off START-tier stores when the
  flag flips them off (existing rows stay accessible to read; only
  NEW writes are gated by the guard)
- Migrating audit-log shape to include before/after for OTHER
  modules (just investments here; consistent pattern is its own spec)

## Acceptance

- `npm test` ≥222 unit (was 216, +6 investments)
- `npm run test:e2e` ≥11 (no new e2e — tier gate verified live in step below)
- 0 tsc errors
- Live probe:
  - `GET /api/stores/<START-store>/investments` → HTTP 403
  - `GET /api/stores/<BIZ-store>/investments` → HTTP 200
  - `POST /api/stores/<BIZ-store>/investments` with same `localId` twice → 1 row, both responses identical
  - `SELECT * FROM audit_logs WHERE action LIKE 'investment%'` returns rows after create/update/delete
  - `pg_constraint` shows 2 new CHECK + the new unique + the new index

## Risks

- **`hasInvestments` flag flip closes existing endpoint for START
  merchants.** Mitigation: investments is a paid-feature category;
  START tier never had it formally promised in product copy. If
  merchants complain, we can flip the flag for grandfathered stores.
- **Migration drift workaround** — same `_prisma_migrations` manual
  insert pattern used in the last 3 spec migrations.
- **Audit log explosion on bulk update** — investments are typed
  one at a time by the merchant; no bulk endpoint. Audit volume
  scales with human action rate, not data size.
- **Existing 5 unit tests must keep passing** with new `userId`
  param. Mitigation: spec test file refactor includes signature
  updates for all existing mutation calls.

## Test results gate

- API: `npm test` (≥222) + `npm run test:e2e` (≥11)
- 0 tsc errors
- 1 new schema migration committed
- Live: 5 curl probes covering tier gate + idempotency + audit
