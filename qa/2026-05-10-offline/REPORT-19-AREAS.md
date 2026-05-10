# 19 Risk-Area Sweep — 2026-05-10

Systematic probe of all 19 areas listed in `RISK-AREAS.md`. Found
**6 new bugs** (+15 already documented previously), of which **5 fixed
in this pass** and 1 P3 deferred.

## Bug catalog this pass

### 🔴 #15 — Currency change without sales-data guard
Store currency mutable via `PUT /stores/:id` even when sales exist.
Historical Decimal amounts kept their numeric values but UI re-labels
them — e.g. 5 TJS becomes "5 USD" (10× inflation).

**Fix:** `stores.service.update` now blocks currency change when
`sale.count > 0`. Migration is admin-tool work.

### 🔴 #16 — Sale with bogus `shiftId`/`staffId`/`customerId` → 500
Sending invalid FK values surfaces as Prisma constraint errors that
Nest maps to opaque 500. No validation that shift is OPEN, or that
the staff/customer/shift belongs to the same store.

**Fix:** pre-transaction validation in `sales.service.create`.
- shiftId → must exist + status=OPEN + same store
- staffId → must exist + isActive + same store
- customerId → must exist + same store

All three now return **400 with friendly Russian-friendly message**.

### 🔴 #17 — Concurrent debt payments overpay (TOCTOU)
Same TOCTOU pattern as the sale stock race (#12). 5 parallel
payments of 5 TJS against a 5-TJS debt: 5 `debt_payment` rows
created for 25 TJS total; sale.debtAmount clamped to 0 by the
"belt-and-braces" fallback. Customer overpaid by 20 TJS, 4 orphan
payment rows.

**Fix:** atomic conditional `updateMany WHERE debt >= amount` in
`addPayment`. If 0 rows affected → ConflictException. Customer.debt
gets the same conditional decrement.

### 🟠 #18 — Telegram webhook had no signature verification
`POST /api/telegram/webhook` accepted any anonymous JSON body. An
attacker could feed fake "messages" through the bot processing
pipeline.

**Fix:** if `TELEGRAM_WEBHOOK_SECRET` env is set, controller verifies
the `X-Telegram-Bot-Api-Secret-Token` header matches before processing.
Telegram passes that header when registered with `setWebhook(secret_token=...)`.

### 🟠 #19 — Sync replay → duplicate sale on retry
The new `localId` (Phase 1 #4) is stored but not deduped. If a sync
write succeeds server-side but the client times out, the next retry
creates a second sale.

**Fix:** at the top of `sales.service.create`, if `localId` matches
an existing sale in this store, return that sale unchanged. Idempotent
replay is now safe.

### 🟠 #20 — Products import endpoint had no fileSize / mimetype limits
`@UseInterceptors(FileInterceptor('file'))` with NestJS defaults =
unlimited size, no type filter. Any user with `products.manage`
could OOM the server with a large upload, or smuggle non-Excel
content through the parser.

**Fix:** capped at 5MB; mimetype filter accepts only
`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`,
`application/vnd.ms-excel`, `text/csv`.

### 📌 Deferred to P3

- **JWT password-change revocation** — strategy validates user.isActive
  on every request (immediate revoke on deactivate ✓), but does NOT
  invalidate tokens after password change. Requires `User.tokensRevokedAt`
  timestamp + JWT `iat` comparison. Standard JWT behaviour but
  worth fixing for a money-handling app.

## Probe results — area by area

| # | Area | Result | Bug |
|---|------|--------|-----|
| 7 | Sync engine failure paths | partial — retry/backoff/cleanup verified, idempotency added | #19 |
| 8 | Offline flows beyond CASH | 4/7 repos have offline support; **shift, stock_intake, debt have NO offline path** | doc-only |
| 9 | Multi-currency sales | currency mutable post-sale | #15 |
| 10 | Shift module | one-OPEN-shift constraint exists; FK validation missing on sale-create | #16 |
| 11 | Loyalty/debt edges | overpayment race | #17 |
| 12 | Receipt printing | code thin on timeout/disconnect handling — needs hardware test | doc-only |
| 13 | Excel import / file uploads | no size/type limits | #20 |
| 14 | JWT edge cases | deactivation works; password-change does not revoke | P3 deferred |
| 15 | N+1 queries | not measured (no profiler attached) — code uses `include`, not lazy loads | doc-only |
| 16 | Notifications | sale create does NOT trigger push — feature missing or by design | doc-only |
| 17 | Telegram webhook security | no signature check | #18 |
| 18 | Subscription lifecycle | PAST_DUE / CANCELLED / EXPIRED all → 403 on feature endpoints | PASS |
| 19 | Audit log coverage | only admin module emits audit logs; refund/sub-change/inventory-apply not logged | doc-only |
| 20 | Data export / backup | no `/export` endpoints — feature unimplemented (UI flag `hasExport` is dead) | doc-only |
| 21 | i18n missing translations | ru=381, tg=375, uz=375 — only metadata key differs, real translations complete | PASS |
| 22 | Receipt template customisation | settings JSON-stored, default fallback works | PASS |
| 23 | Investments / Zakat modules | endpoints exist, not deeply probed | doc-only |
| 24 | Admin panel auth | edge middleware verifies JWT signature + isAdmin claim | PASS |
| 25 | App lifecycle | CartBloc not persisted (cart lost on restart, intentional UX) | doc-only |

## Findings still open as documentation only

These were probed enough to classify but not fixed in this session:

1. **Area 8** — Add offline support to shift/stock_intake/debt repos
   so the entire offline experience is consistent.
2. **Area 12** — Receipt printing needs an integration test with a
   real BLE thermal printer to validate disconnect handling.
3. **Area 15** — Plug pg `pg_stat_statements` into a perf-test branch
   to count actual query counts on `/sales` and `/products` lists.
4. **Area 16** — Decide whether sale notifications should fire (e.g.
   "your shift cashier just rang up X"). Currently no push events
   on sale creation.
5. **Area 19** — Extend audit log to refund, subscription transitions,
   inventory-apply, and currency change.
6. **Area 20** — Implement actual export endpoints for the
   PREMIUM-tier `hasExport` feature, or remove the dead flag.
7. **Area 23** — Investments and zakat modules deserve a focused
   audit pass (especially zakat math at year-boundary).
8. **Area 25** — Decide whether cart should survive process death
   (POS UX argument: maybe a "draft cart" flag, not auto-restore).

## Test results

- **API:** 183 unit + 6 e2e ✓
- **Build:** tsc 0 errors

## Session totals (cumulative)

20 bugs found across the day, 18 fixed and committed, 2 deferred:

| Phase | Bugs | Status |
|-------|------|--------|
| Sprint C P3 | 7 | committed cabee90 |
| Offline + matrix | 9 | committed 1e41faf |
| Money correctness | 3 | committed 86d1927 |
| 19-area sweep | 6 (5 fixed, 1 deferred) | this commit |

Plus 1 additional architectural deferral (#11 class-level
@RequiresFeature, logged in REPORT-PHASE2.md).
