# Design — Spec B "Offline Parity" (Stock + Debt)

**Date:** 2026-05-16
**Scope:** E.2 StockRepository offline-aware writes, E.3 DebtRepository
new abstraction + offline-aware writes. E.1 (ShiftRepository) was
already shipped earlier — confirmed by inspecting the repo, dropped
from this spec.
**Decisions:** scope per inline brainstorm 2026-05-16.

## Summary

Two repositories on the Flutter side gain offline-write parity with
the existing Sale/Customer pattern: queue on offline, idempotent
replay on reconnect, server-side dedup via `(storeId, localId)`
unique constraint. One Prisma migration adds `localId` to two (or
three, depending on supplier debt payments existing) tables.
DebtRepository is a new abstraction — currently `DebtBloc` calls
`DioClient` directly, no repo layer.

## Sub-section A — E.2: StockRepository offline-aware

### Problem

`app/lib/data/repositories/stock_repository_impl.dart` is a
direct-DioClient pass-through:
- `createStockMovement(storeId, productId, data)` POSTs synchronously
- No `NetworkInfo` injection, no `SyncQueue`, no `localId`
- Offline write throws `NetworkException` immediately, UI shows error
- After-the-fact replay is impossible without repo-side queue

The sync-engine endpoint resolver (`sync_engine.dart`
`_resolveEndpoint`) does NOT have a `case 'stock_movement'` mapping
yet — endpoint string would need to be assembled from `storeId` +
`productId` (compound entityId).

### Fix

**Repo refactor:**
- Inject `NetworkInfo` + `SyncQueue` (same pattern as
  `SaleRepositoryImpl`)
- `createStockMovement` flow:
  1. Generate `payload['localId'] ??= Uuid().v4()` if not present
  2. `if (await _networkInfo.isConnected)` → POST, return real model
  3. On `NetworkException` OR offline → enqueue
     - `entityType: 'stock_movement'`
     - `entityId: '$storeId:$productId:$tempId'` (compound — sync
       engine parses)
     - `operation: 'CREATE'`
     - payload = the data Map with localId
  4. Return temp `StockMovement` with `id = 'temp_<timestamp>'` so UI
     reflects the change immediately

**Sync engine:**
- Add `case 'stock_movement'` in `_resolveEndpoint`. Parse
  compound entityId `storeId:productId:tempId`, return endpoint
  `/api/stores/$storeId/products/$productId/stock-movements`. Drop
  `tempId` from payload before send.

**Backend:**
- Prisma `StockMovement` model: add `localId String?` + `@@unique([storeId, localId])`
- Migration adds column + unique index. Existing rows `localId = NULL`
  (Postgres treats multiple NULLs as distinct → preserved)
- `stock-movements.controller.ts` (or wherever the create endpoint
  lives): accept `localId` in DTO
- Service: if `localId` provided AND row exists → return existing.
  Else create. (Same `F-IDEMPOTENT-1` pattern as
  `sales.service.ts`.)

### Files touched

**Modify:**
- `app/lib/data/repositories/stock_repository_impl.dart` — refactor
- `app/lib/data/sync/sync_engine.dart` — add `_resolveEndpoint` case
- `app/lib/injection.dart` — pass `NetworkInfo` + `SyncQueue` to
  `StockRepositoryImpl` constructor
- `api/prisma/schema.prisma` — `StockMovement.localId`
- `api/src/modules/stock-movements/dto/create-stock-movement.dto.ts`
  (or wherever) — add optional `localId`
- `api/src/modules/stock-movements/stock-movements.service.ts` (or
  wherever) — idempotent upsert

**Create:**
- `api/prisma/migrations/<ts>_offline_parity_localid/migration.sql`
  (combined with E.3)

**Test:**
- `app/test/data/repositories/stock_repository_test.dart` — add
  offline-queue scenario test (mock NetworkInfo offline → queue
  called)
- `api/test/stock-movements.e2e-spec.ts` (or extend existing) — POST
  same `localId` twice → 1 row inserted, both responses identical

### Acceptance

- `flutter test` passes (existing 417 + ~3 new offline tests)
- `npm test` + `npm run test:e2e` pass with new idempotency test
- Manual: airplane mode on emulator → "Приход" stock movement →
  reconnect → row appears once on server
- `dart analyze lib/` 0 issues, `npx tsc --noEmit` 0 errors

---

## Sub-section B — E.3: DebtRepository abstraction + offline-aware

### Problem

`app/lib/presentation/blocs/debt/debt_bloc.dart` line 50 does:
```dart
await _dioClient.post(
  ApiEndpoints.customerPayments(event.storeId, event.customerId),
  data: event.data,
);
```
Same for supplier payments at line 104. There is **no repository
abstraction** — bloc owns IO directly. This breaks:
- Testability (bloc is hard to unit-test without mocking Dio)
- Offline support (no queue layer)
- Consistency (every other write path goes through a repo)

### Fix

**New repo (this is the bigger surgical change):**

Create `app/lib/domain/repositories/debt_repository.dart`:
```dart
abstract class DebtRepository {
  Future<void> addCustomerPayment(
      String storeId, String customerId, Map<String, dynamic> data);
  Future<void> addSupplierPayment(
      String storeId, String supplierId, Map<String, dynamic> data);
}
```

Create `app/lib/data/repositories/debt_repository_impl.dart`:
- Inject `DioClient`, `NetworkInfo`, `SyncQueue`
- Both methods follow the same offline-aware pattern as
  StockRepository above
- Online → POST, return void on success
- Offline → enqueue with `entityType: 'debt_payment'` (already
  mapped in `_resolveEndpoint` per existing grep) OR
  `'supplier_debt_payment'` for the supplier side. Verify mapping
  exists; if not, add.

**Bloc refactor:**
- `DebtBloc` constructor: replace `DioClient` with `DebtRepository`
- Update both event handlers to call repo methods
- Error handling: network failure path now silently queues; bloc
  surfaces `DebtPaymentQueued` state (new) so UI can show
  "Платёж сохранён офлайн, отправится при подключении" snackbar

**Service locator:**
- `injection.dart` — register `DebtRepository` as
  `LazySingleton<DebtRepository>(() => DebtRepositoryImpl(...))`
- Update `DebtBloc` factory registration to inject the repo

**Backend:**
- Verify whether `customer_debt_payments` table has `localId` column
  already (sync_engine has the case → maybe. Verify in schema.)
- If missing: add `localId String?` + `@@unique([storeId, localId])`
  on `CustomerDebtPayment` (and `SupplierDebtPayment` if exists)
- `customers.controller.ts` `@Post(':id/payments')`: accept `localId`,
  pass to service
- `customers.service.ts` `addPayment` (or whatever it's named):
  idempotent return if `(storeId, localId)` row exists
- Same for supplier endpoint

### Files touched

**Create:**
- `app/lib/domain/repositories/debt_repository.dart`
- `app/lib/data/repositories/debt_repository_impl.dart`
- `app/test/data/repositories/debt_repository_test.dart`
- `app/test/presentation/blocs/debt/debt_bloc_test.dart` (if absent —
  the bloc has no tests today per G.2 audit pattern)

**Modify:**
- `app/lib/presentation/blocs/debt/debt_bloc.dart` — DioClient →
  DebtRepository injection
- `app/lib/presentation/blocs/debt/debt_state.dart` — add
  `DebtPaymentQueued` state
- `app/lib/presentation/pages/debt/customer_debts_page.dart` (and
  any consumer) — handle the new state for snackbar
- `app/lib/injection.dart` — register repo
- `app/lib/data/sync/sync_engine.dart` — verify `_resolveEndpoint`
  for `'debt_payment'` (already exists per grep) + add
  `'supplier_debt_payment'` if missing
- `api/prisma/schema.prisma` — `CustomerDebtPayment.localId` (if
  missing); `SupplierDebtPayment.localId` (if missing)
- `api/src/modules/customers/customers.controller.ts` + service —
  accept + dedupe localId
- `api/src/modules/suppliers/suppliers.controller.ts` + service —
  same
- `api/src/modules/customers/dto/add-customer-payment.dto.ts` (or
  whatever) — add optional `@IsString() @IsOptional() localId`

### Acceptance

- `flutter test` passes (existing + new repo tests + bloc tests)
- `npm test` + e2e — new test: POST same payment with same
  `localId` twice → debt decremented once
- Manual: airplane mode → mark customer payment paid → reconnect →
  customer debt updated correctly server-side, no double-charge
- `dart analyze` 0, `npx tsc` 0
- DebtBloc no longer imports `DioClient` (fully repo-abstracted)

---

## Schema migration (combined for E.2 + E.3)

One migration, applied manually if Prisma resists due to prior drift
(same workaround as `20260516000000_g2_zakat_tier_flag`):

```sql
-- E.2: idempotent stock movements
ALTER TABLE "stock_movements" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "stock_movements_storeId_localId_key"
  ON "stock_movements"("storeId", "localId");

-- E.3: idempotent customer + supplier debt payments
-- (verify table names — may be `customer_debt_payments` or `debt_payments`)
ALTER TABLE "customer_debt_payments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "customer_debt_payments_storeId_localId_key"
  ON "customer_debt_payments"("storeId", "localId");

ALTER TABLE "supplier_debt_payments" ADD COLUMN "localId" TEXT;
CREATE UNIQUE INDEX "supplier_debt_payments_storeId_localId_key"
  ON "supplier_debt_payments"("storeId", "localId");
```

Existing rows keep `localId = NULL`. Postgres allows multiple NULLs
in a unique index → backwards compat is preserved.

If a `localId` column already exists on any of these tables (likely
on `CustomerDebtPayment` since the sync engine has the case mapping)
— skip that ALTER. Final migration only contains the missing pieces.

## Order of execution

E.2 first (smaller, simpler — no new repo). E.3 second (bigger,
includes bloc refactor + new abstraction). Final E.1 verification
gate runs both sets of tests + a manual airplane-mode probe.

## Out of scope

- Offline READ for stock movements / debt history (UI shows "no
  connection" state, server is source of truth for reads)
- Conflict resolution beyond last-write-wins (covered by existing
  `conflict_resolver.dart`)
- Migrating historical rows to backfill `localId` — keep NULL,
  exempted from unique index by Postgres NULL semantics
- Replacing `_dioClient` calls in OTHER blocs (debt is the only one
  flagged; others either already use repos or are intentionally
  thin)

## Risks

- **Stock intake math drift on replay** — if a queued intake replays
  AFTER an online sale of the same product, server quantity should
  end up correct because intake adds (not sets) and `localId` dedup
  prevents double-add. Mitigation: server applies stock movement as
  delta; localId is the safety net.
- **DebtBloc consumer surface change** — adding `DebtPaymentQueued`
  state means existing `BlocBuilder` consumers may not match the
  state and fall through to a default branch. Mitigation: audit
  consumers in the bloc refactor task; update each to emit a
  snackbar on the new state.
- **localId already partially shipped** — if `CustomerDebtPayment`
  already has `localId` from an earlier sprint we missed (sync engine
  maps debt_payment → customers/payments endpoint, suggesting prior
  intent), the migration would no-op and we'd skip the schema change
  for that table. Verify before running.
- **Test bloat** — adding offline scenarios for 2 repos + a new bloc
  test means ~15-20 new test cases. Expected; budgeted.

## Test results gate

After implementation:
- API: `npm test` (≥205 unit) + `npm run test:e2e` (≥10 e2e — was
  8, +2 idempotency tests)
- App: `flutter test` (≥420 — was 417, +3-5 new repo + bloc tests)
- `dart analyze lib/` 0 issues
- `npx tsc --noEmit` 0 errors
- 1 new schema migration committed
- 1 new domain repo + 1 new data repo committed
