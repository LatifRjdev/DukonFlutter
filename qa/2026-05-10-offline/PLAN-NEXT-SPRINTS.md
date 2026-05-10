# Plan — Next Sprints (D / E / F / G)

After today's work (20 bugs found, 18 fixed) the remaining backlog is
**11 items** across 4 sprints. Order is chosen so each sprint stands
on its own — no cross-sprint dependencies — and so the
release-blocker class items land first.

## Sprint D — Quick wins (~1 day total)

Small, well-scoped cleanups that don't touch the offline-sync
architecture.

### D.1 — Resolve `maxStores` ambiguity (architectural #10)

**Problem.** `subscription_plan_configs.maxStores` exists but is never
enforced. Architecture gives each store its own subscription, so
"5 stores per PREMIUM" has no anchor.

**Decision needed.** Pick one:

- **Option A** — Drop `maxStores` from the schema + plan config seed.
  Honest "no per-merchant cap." Migration: `ALTER TABLE
  subscription_plan_configs DROP COLUMN max_stores`. Update
  `seedPlanConfigs` and TypeScript types. Update Premium pricing
  page to remove "5 stores" claim if listed.
- **Option B** — Cap stores per *user* by their primary subscription
  (any active sub). Requires `users.primaryStoreId` or a "billing
  store" concept. New endpoint to switch billing store.

**Recommend A.** Option B is a real billing redesign; option A is
honest about the current model.

**Files.** `prisma/schema.prisma`, `prisma/migrations/<new>`,
`src/modules/subscriptions/subscriptions.service.ts` (seedPlanConfigs),
`src/common/guards/plan-limit.helper.ts` (drop 'maxStores' from union),
admin marketing pages.

**AC.** `npx prisma migrate dev` clean; tsc 0 errors; no reference
to `maxStores` in `src/`; deploy notes call out "no per-account
store cap" so support has the right answer.

**Effort.** 2 hours.

### D.2 — Resolve `hasExport` flag (Area 20)

**Problem.** `subscription_plan_configs.hasExport=true` only on PREMIUM,
but no `/export` endpoint exists. Flag is dead — UI may show "Export"
button that 404s.

**Decision needed.**

- **Option A** — Implement Excel export for sales / products / customers.
  Reuse the existing import library (xlsx) for output. Endpoints under
  `/stores/:storeId/reports/export?type={sales|products|customers}&format=xlsx`.
  Stream the file. Apply `@RequiresFeature('hasExport')`.
- **Option B** — Drop `hasExport` from schema + seed. Hide UI button
  on PREMIUM if it only ever rendered.

**Recommend A.** Export is a common premium-tier feature merchants
ask for; existing customers use email screenshots which is brittle.

**Files.** New `src/modules/reports/export.service.ts`,
`reports.controller.ts` (3 routes), app-side download UI on more page.

**AC.** Premium account can download xlsx for each entity; START/BIZ
get 403; file opens in Excel/Numbers without warnings; rows match
the in-app list.

**Effort.** 1 day (mostly format + streaming).

### D.3 — Audit log expansion (Area 19)

**Problem.** Only admin module emits audit log entries. Sensitive
non-admin actions are untracked: refund, subscription transition,
inventory apply, currency change, staff role change, debt payment.

**Approach.** Extract a thin `AuditLogService.record(actorId, action,
entityType, entityId, before, after, reason?)` and call it from each
sensitive write path. Reuse the existing `audit_logs` table.

**Files.**
- `src/common/audit/audit-log.service.ts` (new, app-wide)
- `sales.service.ts` refund() — emit AUDIT.SALE.REFUND
- `subscriptions.service.ts` adminApprove/Reject + change — emit AUDIT.SUB.*
- `inventory-counts.service.ts` apply() — emit AUDIT.INVENTORY.APPLY
- `stores.service.ts` update() with currency — emit AUDIT.STORE.CURRENCY_CHANGE
- `staff.service.ts` updateRole() — emit AUDIT.STAFF.ROLE_CHANGE
- `customers.service.ts` addPayment() — emit AUDIT.DEBT.PAYMENT

**AC.** Admin panel `/audit-logs` page shows all six new event types;
each row links to entity; spec covers the emit-on-success path.

**Effort.** 4 hours.

### D.4 — N+1 query measurement (Area 15)

**Problem.** No measurement. Likely hot paths: `/sales` list with
`include items + customer + staff`, `/products` with category include,
dashboard aggregates.

**Approach.**
1. Enable Prisma's `log: ['query']` in dev; generate test data of
   100 sales × 5 items each.
2. Hit each endpoint once; count SQL statements per request.
3. Anything over 5 queries per response = candidate for a
   `select+include` audit or batched aggregate.

**Likely fixes.**
- Replace per-row `findFirst` in service layers with `findMany` + map.
- Use Prisma `_count` selector instead of separate `count()` calls.
- Eager-load `customer` on `Sale.findMany` rather than per-sale fetch.

**Files.** `src/prisma/prisma.service.ts` (toggle query log via env),
top 3 services after measurement.

**AC.** Document per-endpoint query count in
`docs/perf/2026-05-XX-baseline.md`; cut top three by ≥50%.

**Effort.** 4 hours.

## Sprint E — Offline parity (~2 days)

Sale offline already works (Phase 1). Three repos still hard-fail
when offline. Cart persistence is a UX call.

### E.1 — Offline support for `ShiftRepository`

**Problem.** Shift open/close hits API directly; offline → exception.
A cashier opening a shift on a flaky network gets stuck.

**Approach.** Mirror the Sale pattern:
- Store local Shift rows in SQLDelight.
- Repo checks `_networkInfo.isConnected`; offline writes go to
  local + `_syncQueue.enqueue('shift', tempId, 'CREATE'|'UPDATE',
  payload)`.
- On reconnect, sync engine replays. Server already supports `localId`
  on Sale; add `localId` to Shift schema for the same idempotency
  pattern as Sale.
- Cash counts on close need careful merge — merchant can't sell while
  shift is closed, so race risk is low.

**Files.**
- `prisma/schema.prisma` — add `localId String?` on Shift, with
  unique index `[storeId, localId]`.
- `prisma/migrations/<new>/migration.sql`.
- `app/lib/data/repositories/shift_repository_impl.dart` — add
  online/offline branching.
- `app/lib/data/sync/sync_engine.dart` `_resolveEndpoint` — add
  shift case.
- `api/src/modules/shifts/shifts.service.ts` — idempotent on `localId`.

**AC.** Open shift offline → succeeds locally with `OFF-...` ID;
reconnect → server has the shift with the `localId` we sent;
re-sync of the same item is a no-op (returns existing).

**Effort.** 4 hours.

### E.2 — Offline support for `StockIntakeRepository`

**Problem.** Same as E.1 but for stock intake (incoming inventory).

**Approach.** Same pattern. Stock intake increments product quantity
on success, so the offline path needs to:
- Apply local quantity increment immediately so POS shows the new
  stock.
- Queue the API call for replay.
- On API success, no double-increment (server is the source of truth
  on next pull).

**Risk.** If replay fails (e.g. supplier deleted), local quantity is
out of sync. Mitigation: on replay rejection, reverse the local
increment + show a notification.

**Files.** `app/lib/data/repositories/stock_intake_repository_impl.dart`,
`prisma/schema.prisma` (StockIntake.localId), shift_movement schema if
needed, sync_engine.dart.

**AC.** Receive stock offline → POS shows new qty immediately; reconnect
→ server reflects the intake; failed replay reverses local inc with a
user notification.

**Effort.** 4 hours.

### E.3 — Offline support for `DebtRepository` (debt payments)

**Problem.** Customer debt payment hits API only. Cashier can't record
that the customer paid in cash if signal is down.

**Approach.** Same pattern. With the new conditional `gte` decrement
(today's #17 fix), the server will correctly reject overpayments on
replay if another payment landed first — surface that to the user as
"this debt was already paid; no further entry recorded."

**Files.** `app/lib/data/repositories/debt_repository_impl.dart`,
sync_engine.dart, prisma schema if `localId` needed on DebtPayment.

**AC.** Pay debt offline → local debt decremented + queue entry; reconnect
→ server reflects payment; concurrent overpayment from another device
shows a friendly "already paid" toast on this device after sync.

**Effort.** 4 hours.

### E.4 — Cart persistence decision + implement

**Problem.** CartBloc state lost on app kill. Cashier mid-cart who has
the OS swipe-kill the app loses their work.

**Decision needed.**

- **Option A** — Auto-restore cart silently. Risk: customer sees
  yesterday's cart on first launch.
- **Option B** — Persist cart to SharedPreferences + on cold start,
  show "Restore cart from {time ago}?" prompt with restore/discard
  buttons.

**Recommend B.** Explicit user control, no surprise.

**Files.** `app/lib/data/datasources/local/cart_local_datasource.dart`
(new), `app/lib/presentation/blocs/pos/cart_bloc.dart` (load on init,
persist on every change with debounce, clear on checkout).

**AC.** Cart persisted across app kill; cold start with stale cart
prompts user; checkout clears the persisted cart; never restores
silently.

**Effort.** 4 hours.

## Sprint F — Security hardening (~1 day)

### F.1 — JWT password-change revocation (P3 #14)

**Problem.** Password reset doesn't invalidate previously-issued JWTs.
A leaked token stays valid until natural expiry.

**Approach.**
- Add `users.tokens_revoked_at TIMESTAMP NULL`.
- On password change: `tokens_revoked_at = NOW()`.
- JWT strategy: read user, compare token's `iat` (seconds) with
  `floor(tokens_revoked_at / 1000)`; reject if `iat <= revokedAt`.
- Optional: a `revokeAllTokens` endpoint for users-me and admin.

**Files.** `prisma/schema.prisma` + migration,
`src/modules/users/users.service.ts` (changePassword + revokeAll),
`src/modules/auth/strategies/jwt-access.strategy.ts` (compare iat),
`src/modules/auth/strategies/jwt-refresh.strategy.ts` (same).

**AC.** Get token, change password, retry old token → 401.
Admin "force logout" on user → all their tokens 401 immediately.

**Effort.** 3 hours.

### F.2 — Class-level `@RequiresFeature` (architectural #11)

**Problem.** During Phase 2 we tried elevating the decorator to the
class for cleaner code; reflector silently ignored class metadata
even though `getAllAndOverride([handler, class])` should pick it up.
Fell back to per-method decoration. Worth a focused fix so future
controllers don't sprout 10 copies of the same decorator.

**Approach.**
1. Reproduce the failure in a unit test against `SubscriptionGuard`.
2. Likely cause is decorator ordering with `@Controller(...)` —
   `SetMetadata` applied to a class via decorator function may need
   to be the *last* decorator before `@Controller`, OR Nest's
   discovery may strip class-level metadata that's not on the route.
3. Fix may be `getAllAndMerge` instead of `getAllAndOverride`, or
   adding an explicit `MetadataAccessor` helper.
4. Migrate one controller (deliveries) to class-only decoration as
   the canonical pattern; keep the others method-level for now.

**Files.** `src/common/guards/subscription.guard.ts`,
`src/common/decorators/requires-feature.decorator.ts`,
new spec under `test/unit/`, deliveries.controller.ts as the canary.

**AC.** Spec asserts that a class-level `@RequiresFeature(...)`
without per-method decoration triggers the guard correctly. Live
probe against deliveries returns START=403 / BIZ=200 with method-level
decorators removed.

**Effort.** 3 hours.

### F.3 — Sale-create notification dispatch (Area 16 — decide first)

**Problem.** Sale creation doesn't trigger any push notification.
Likely intentional but undocumented. If owner wants "you got a sale"
push when a cashier rings up something, the wire isn't there.

**Decision needed.**

- **Option A** — Wire FCM push on sale create to store owner if
  amount ≥ store-config threshold (e.g. 1000 TJS) and notification
  setting `bigSaleAlerts=true`. Already gated by `hasAllPush`.
- **Option B** — Do nothing; document that only stock-low and
  end-of-day push exist.

**Recommend A** for PREMIUM-tier owners — it's a delight feature.

**Files.** `sales.service.ts` (post-create hook),
`notifications.service.ts` (sendBigSaleAlert), settings DTO + UI.

**AC.** Cashier rings up 1500 TJS sale → store owner gets push;
amounts under threshold are silent; setting toggleable in app.

**Effort.** 4 hours.

## Sprint G — Hardware + module-deep audits (~2-3 days)

### G.1 — Receipt printing integration test (Area 12)

**Problem.** Code exists for thermal printer (`thermal_printer_service.dart`)
but no test of disconnect/timeout/format-edge cases. Production
merchants on flaky BLE will hit issues we haven't seen.

**Approach.**
- Procure a cheap 80mm BLE thermal printer (~$30) or use an emulator
  (esc-pos-test).
- Write integration tests:
  - Print receipt with normal sale.
  - Print with very long product names (line wrap).
  - Disconnect mid-print → recover state.
  - Print queue flushed when reconnect.
  - Cyrillic + Tajik character rendering.
- Document supported printer models + paper widths.

**Files.** `app/integration_test/printer_test.dart`,
`docs/printers/SUPPORTED.md`.

**AC.** All 5 tests pass against real printer or emulator; supported-
models doc published.

**Effort.** 1-2 days (hardware procurement + cycles).

### G.2 — Investments / Zakat module deep audit

**Problem.** Modules exist but never live-tested in this session.
Zakat math is religion-sensitive — a 0.025× rounding bug is
unacceptable to the audience.

**Approach.**
- Read all endpoints; sketch the calculator logic.
- Write spec cases:
  - Zakat at exactly nisab threshold (260 g silver / 87.48 g gold equivalent).
  - Multi-currency wealth (TJS + USD) — does it convert?
  - Year-boundary (lunar vs solar — Dukon uses which?).
  - Investments with partial-year holding.
- Live-probe with the qa-business account + seeded data.
- Fix any math/edge cases; document the model.

**Files.** Investments + Zakat services + spec, `docs/zakat/MODEL.md`.

**AC.** Spec covers nisab threshold, multi-currency, year boundary.
Live probe matches a hand-calculated reference.

**Effort.** 1 day (read + spec + 2-3 likely fixes).

## Order of execution

```
Day 1  →  D.1 (maxStores)         2h  ──┐
          D.2 (hasExport)         1d   │
          D.3 (audit log)         4h   │  Sprint D wraps day 1
          D.4 (N+1)               4h ──┘

Day 2  →  E.1 (shift offline)     4h  ──┐
          E.2 (stock_intake offl) 4h   │  Sprint E day 2
          E.3 (debt offline)      4h ──┘

Day 3  →  E.4 (cart persist)      4h  ──┐
          F.1 (JWT revoke)        3h   │  Sprint F day 3
          F.2 (class decorator)   3h   │
          F.3 (sale notif)        4h ──┘

Day 4-5 → G.1 (printer test)    1-2d  ──┐  Sprint G
          G.2 (zakat audit)       1d ──┘
```

Total: **5 working days for the full backlog**, or 3 days if Sprint G
is deferred (it has external hardware dependency).

## Risk + rollback notes

- All Sprint D items are tightly scoped — single-PR each, can revert
  without affecting other code.
- Sprint E items each touch the same `sync_engine.dart` `_resolveEndpoint`
  — ship in the listed order to avoid merge conflicts.
- Sprint F.1 (JWT revocation) needs careful rollout: deploy server side
  first (handles both old + new tokens), then app side (new tokens
  carry the iat field properly). Otherwise existing logged-in users
  get logged out on deploy.
- Sprint G.1 has external dependency (printer hardware procurement);
  G.2 has none.

## Acceptance for the whole backlog

A "done" run of all 11 items leaves the codebase with:
- Zero unhandled architectural flags (`maxStores`, `hasExport` resolved)
- Audit-logged sensitive writes
- Performance baseline documented
- Full offline parity (Sale, Customer, Product already work; Shift,
  StockIntake, DebtPayment join them)
- Cart resilience to app kills
- Token revocation on password change
- Cleaner subscription decorator pattern
- Optional sale push notifications
- Validated thermal printer flow
- Audited zakat math

That covers everything still open from today's audits.
