# Design — Spec A "Quick Wins"

**Date:** 2026-05-12
**Scope:** 3 short independent items from the carry-forward
backlog: D.4 (N+1 query measurement + fix), F.2 (class-level
`@RequiresFeature` refactor + audit), G.2 (Investments/Zakat
module deep audit + inline P0/P1 fixes).
**Decisions:** D.4=B, F.2=B, G.2=B.

## Summary

One umbrella spec, three independent sub-sections. Each ships as
its own commits with its own REPORT.md. The three together close
~3 days of carry-forward backlog. Order is mechanical — they don't
share files. Suggested execution: D.4 first (perf measurement
makes downstream PR reviews easier), F.2 second (cheap refactor),
G.2 third (audit work — produces findings that may feed future
sprints).

## Sub-section A — D.4: N+1 query measurement + fix top offenders

### Problem

Prisma logs nothing per-request about how many queries a single
HTTP call fired. Several endpoints likely have N+1 patterns:
- `reports.service` per-row `customer.findFirst` for staff names
- `products.controller` separate `count()` + `findMany()` instead
  of `_count` selector
- `sales.findMany` without `include.customer` causing follow-up
  per-row fetch
- `shifts.findMany` without `include.staff` causing per-row
  `user.findFirst`
- Payments list missing `include.subscription`

We have no observability to confirm OR refute. Need both
instrumentation + a baseline fix-pass on the worst offenders.

### Fix

**Instrumentation:**
- `api/src/common/prisma/query-counter.context.ts` — wraps
  `AsyncLocalStorage<{count: number, endpoint: string}>`.
- `api/src/common/prisma/query-counter.middleware.ts` — Prisma
  middleware (`prisma.$use()`) that increments the counter on each
  query.
- `api/src/common/interceptors/query-counter.interceptor.ts` —
  NestJS interceptor that runs each request inside the
  AsyncLocalStorage context, logs a warning at end-of-request if
  `count > 10`, error-log if `count > 25`.
- Wire interceptor globally in `AppModule.providers` as
  `APP_INTERCEPTOR`.

**Fix-pass (top 5 offenders):**
1. `reports.service` — replace per-row `customer.findFirst` with
   single `findMany({ where: { id: { in: ids } } })` + Map lookup.
2. `products.controller` list endpoint — replace separate count +
   findMany with `findMany({ include: { _count } })` or single
   `$transaction([count, findMany])`.
3. `sales.findMany` — add `include: { customer: true }` when the
   response shape includes customer.name.
4. `shifts.findMany` — add `include: { staff: true }` (or whichever
   relation gives staffName).
5. `payments.findMany` (admin) — add
   `include: { subscription: { include: { store: true } } }` if
   the response shape needs it.

Per fix: run the endpoint once, log query count before/after,
record both in REPORT.md.

### Files touched

**Create:**
- `api/src/common/prisma/query-counter.context.ts`
- `api/src/common/prisma/query-counter.middleware.ts`
- `api/src/common/interceptors/query-counter.interceptor.ts`
- `api/test/common/prisma/query-counter.spec.ts` — unit test that
  the counter increments per-query and resets per-request.
- `qa/2026-05-12-quick-wins/REPORT.md` — before/after table for 5
  endpoints.

**Modify:**
- `api/src/app.module.ts` — wire `APP_INTERCEPTOR`.
- `api/src/prisma/prisma.service.ts` — call `$use()` with the
  query-counter middleware in `onModuleInit`.
- `api/src/modules/reports/reports.service.ts` — fix #1.
- `api/src/modules/products/products.controller.ts` or
  `products.service.ts` — fix #2.
- `api/src/modules/sales/sales.service.ts` — fix #3.
- `api/src/modules/shifts/shifts.service.ts` — fix #4.
- `api/src/modules/admin/admin.service.ts` (or payments
  controller wherever the list lives) — fix #5.

### Acceptance

- Middleware works: spec test passes (5 queries → count=5).
- Per-request log shows query count for `/api/health` (should be
  ~1), `/api/stores/:id/sales` (should be `<10` after fixes).
- 5 top offenders measurably reduced (e.g. 35 queries → 4).
- REPORT.md table filled in with real numbers.
- All existing API tests pass (`npm test` ≥189, `npm run test:e2e`
  ≥8).

---

## Sub-section B — F.2: class-level `@RequiresFeature` refactor + audit

### Problem

`@RequiresFeature('X')` is applied per-method in 4+ controllers,
sometimes on every method with the same flag. This is:
- Noisy — `reports.controller.ts` has 5+ methods each decorated
  with `@RequiresFeature('reports')`.
- A potential security gap — if a controller has `@RequiresFeature`
  on most methods but missed one, that endpoint silently bypasses
  the tier check.

`SubscriptionGuard` currently reads method-level metadata only.
Standard NestJS pattern is to use `Reflector.getAllAndOverride`
which checks both method and class.

### Fix

**Refactor:**
- `api/src/common/guards/subscription.guard.ts` — switch
  `reflector.get(METADATA_KEY, handler)` to
  `reflector.getAllAndOverride(METADATA_KEY, [handler, klass])`.
  Method-level still takes precedence; class-level is the fallback.
- Add a spec test: "class-level metadata applies to a method that
  has no method-level decorator".

**Apply class-level on controllers with repeated decorator:**
- `reports.controller.ts` — move `@RequiresFeature('reports')` to
  the class, remove from each method.
- `inventory-counts.controller.ts` — same for whatever feature key
  it uses.
- `deliveries.controller.ts` — same.
- `telegram.controller.ts` — same.

(Exact list will be confirmed by grep in the implementation pass —
the criterion is "decorator repeats on 3+ methods with the same
flag".)

**Audit:**
- Grep for controllers where `@RequiresFeature` appears on SOME
  methods but not all. These are possible security gaps.
- For each match, list in `F2-AUDIT.md`:
  - Controller + which methods are guarded vs not
  - Whether the unguarded methods are intentionally free (e.g. a
    public health route) or oversight
- **DO NOT silently fix** — output findings, let the user decide
  per-finding whether to lock down the unguarded methods.

### Files touched

**Create:**
- `qa/2026-05-12-quick-wins/F2-AUDIT.md` — list of mixed-coverage
  controllers + intent vs gap analysis.
- `api/src/common/guards/subscription.guard.spec.ts` — extend with
  class-level fallback test.

**Modify:**
- `api/src/common/guards/subscription.guard.ts` — switch to
  `getAllAndOverride`.
- 3-5 controller files — move `@RequiresFeature` from per-method
  to class-level.

### Acceptance

- `subscription.guard.spec.ts` covers class-level fallback +
  method-level override.
- All API tests pass — no behavior change for any existing
  endpoint.
- F2-AUDIT.md lists 0 or more mixed-coverage findings.
- Lines of code: net negative (removing repeated decorators).

### Not in scope

- Adding `@RequiresFeature` to currently-unguarded controllers
  (would close previously-open endpoints — needs explicit user
  approval per finding, not a silent change).

---

## Sub-section C — G.2: Investments/Zakat deep audit + inline P0/P1 fixes

### Problem

The `investments/` and `zakat/` modules exist on both API and
Flutter sides but were never deep-audited like other modules in
the `2026-05-06-api-audit.md` and `2026-05-06-mobile-clickpath.md`
sweeps. Unknown unknowns: route auth, RBAC, feature gates, DTO
validation, transaction boundaries, money-clamp, audit logging,
schema constraints, test coverage, Flutter business logic
(specifically the zakat calculator formula).

### Fix

**Backend audit (for each of `investments/` and `zakat/`):**
1. Routes + REST verbs match resource intent
2. `@UseGuards(JwtAuthGuard)` present, `@CurrentUser('id')`
   threaded correctly
3. RBAC: who can read/write? Documented in matrix. Aligns with
   `store.manage` or `staff.manage` permission patterns?
4. `@RequiresFeature` set if tier-gated; which tier
   (START/BIZ/PREMIUM)?
5. DTO validation: `@IsNumber`, `@IsPositive`, `@Max`, `@IsEnum`
   on all numeric/enum fields?
6. Service logic:
   - Transaction boundaries (`$transaction` where multi-step)
   - Money clamp (`Decimal.gte(0)` for sums)
   - Idempotency on creation paths (localId where applicable)
   - Audit logging on admin/sensitive actions
7. Schema:
   - Foreign keys with `onDelete` set explicitly
   - CHECK constraints on Decimal columns (non-negative)
   - Indexes on `storeId` + `createdAt` for list endpoints
8. Test coverage per service file (target: each public method has
   ≥1 happy-path + ≥1 edge case)

**Flutter audit:**
1. `zakat_calculator_page.dart` — read the formula. Does it:
   - Apply 2.5% nisab rate?
   - Exclude declared debts from the taxable base?
   - Handle currency conversion if multi-currency?
   - Validate that holding period is ≥ 1 lunar year (if the UI
     captures that)?
2. `zakat_history_page.dart` — pagination, refresh, sort patterns
   consistent with other history pages
3. `zakat_settings_page.dart` — nisab threshold field, currency
   field, year input
4. `investment_bloc/` — states, transitions, ROI calculation
   formula correctness, edge cases (negative ROI, zero principal)

**Severity scale:**
- **P0** — data corruption risk, security bypass, money math bug
  with cash impact
- **P1** — wrong API result returned, missing audit log, wrong
  feature gate
- **P2** — code-smell, missing edge case in test, weak typing
- **P3** — cosmetic, doc gap, naming inconsistency

**Inline fixes:** P0 + P1 findings get fixed in this same spec
(commits per finding). P2 + P3 findings get documented with a
proposed fix in REPORT but NOT implemented here.

### Files touched

**Create:**
- `qa/2026-05-12-quick-wins/G2-INVESTMENTS-ZAKAT-AUDIT.md` — full audit
  matrix (24+ rows: 8 backend checks × 2 modules + 8 Flutter
  checks), severity-tagged findings, P0/P1 fix commit list.

**Modify:**
- Whichever backend service/controller/dto/schema files have P0
  or P1 findings.
- Whichever Flutter page/bloc files have P0 or P1 findings.

### Acceptance

- G2-INVESTMENTS-ZAKAT-AUDIT.md fully filled in (no "TBD" rows).
- All P0 findings fixed inline (0 left open).
- All P1 findings fixed inline (0 left open).
- P2/P3 findings documented with proposed fix (NOT fixed).
- All API tests pass after fixes.
- All Flutter tests pass after fixes.

### Not in scope

- Shariah-rules validation of the zakat formula — requires domain
  expert. If a finding suggests the formula is wrong, document as
  P2 ("formula assertion: 2.5% applied to gross assets; need
  shariah review") rather than self-validating.
- New features in either module.
- Migration of historical zakat/investment records (data fixes
  only if a P0 corruption finding requires it).

---

## Order of execution

D.4 → F.2 → G.2. They don't share files, but D.4 first because the
query-counter instrumentation will make G.2's perf-finding column
easier to fill. F.2 second because it's the smallest and lowest-
risk. G.2 third because it's the most open-ended.

Each ships independently — if G.2 surfaces a deep P0 we can punt
to a follow-up spec rather than block D.4 + F.2 from merging.

## Test results gate

After implementation:
- API: `npm test` (≥189 unit) + `npm run test:e2e` (≥8 e2e) — must
  pass.
- App: `flutter test` (≥417) + `dart analyze lib/` (0 issues) —
  must pass.
- `npx tsc --noEmit` (0 errors) — must pass.
- 4 new artefacts in `qa/2026-05-12-quick-wins/`:
  - REPORT.md (D.4 before/after table)
  - F2-AUDIT.md (mixed-coverage findings)
  - G2-INVESTMENTS-ZAKAT-AUDIT.md (full audit + P0/P1 fix list)

## Risks

- **D.4 middleware adds per-query overhead.** Mitigation:
  `process.env.NODE_ENV === 'test'` short-circuit, or
  `AsyncLocalStorage.getStore() ?? noop` — measure cost in
  benchmark; expected ~1µs/query, negligible for HTTP scale.
- **F.2 grep miss.** If our grep misses a controller where
  `@RequiresFeature` should cascade to class-level but doesn't,
  the refactor leaves it unchanged — that's safe (no behavior
  change), just an incomplete refactor. Acceptable.
- **G.2 audit finds a P0 we can't fix in scope.** Mitigation: if
  a P0 requires schema migration or business decision, downgrade
  scope to "document P0 + immediate workaround if any" + raise
  visibility in the REPORT's executive summary. Don't block the
  spec on it.
