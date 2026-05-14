# D.4 — N+1 Query Measurement + Fix-Pass — 2026-05-13

## Setup
QueryCounter Prisma extension (`$extends.$allOperations` callback)
counts every model query inside the request-scoped AsyncLocalStorage.
A NestJS global interceptor wraps each HTTP request, runs the
handler inside the counter context, and logs at end-of-request:
- warn if count > 10
- error if count > 25

Measured against qa-business store
(d169d2e8-0a24-4a23-844a-5d5e7b690d8c) with normal seeded data
(11 products, 24 sales, 1 shift, 3 customers), authenticated as
qa-business OWNER (+992910001002). Admin endpoint measured with
admin user (+992000000000 / admin123).

For the baseline pass the interceptor's `WARN_THRESHOLD` was
temporarily lowered from `10` to `0` so every request would log
its count (otherwise endpoints with <=10 queries print nothing).
The threshold was restored to `10` before committing this report —
only `qa/2026-05-12-quick-wins/REPORT.md` is part of this commit.

## Result — top 5 endpoints

| # | Endpoint | Queries | Action | Reason |
|---|----------|--------:|--------|--------|
| 1 | GET /api/stores/:id/reports/sales | 2 | SKIP | already batched; raw SQL handles aggregation |
| 2 | GET /api/stores/:id/products | 2 | SKIP | findMany+count in `Promise.all`, scalar category select |
| 3 | GET /api/stores/:id/sales | 2 | SKIP | findMany already includes customer + items |
| 4 | GET /api/stores/:id/shifts | 2 | SKIP | findMany already includes nested staff.user.name |
| 5 | GET /api/admin/subscriptions | 1 | SKIP | listStores includes owner+subscription+_count in one query |

**Verdict: 0 fixes needed. All 5 targets confirmed clean by direct code inspection (post-baseline pass).**

## Code-inspection summary

After the surprising 1–2 query baseline, each target was opened
and inspected for the suspected N+1 pattern. Results:

- **reports.service** — `getStaffReport` uses the canonical batched
  pattern: `groupBy → collect IDs → ONE findMany({id:{in:ids}}) → Map lookup`.
  No per-row `findFirst` in any loop. Same pattern in
  `admin.listAuditLogs`. **Already optimal.**
- **products.service** — `findAll` runs `findMany` (with scalar
  `category` select) and `count` in parallel via `Promise.all`. No
  per-row enrichment after the list. **Already optimal.**
- **sales.service** — `findAll` `findMany` includes `customer`
  (id+name) and `items` (4 scalar fields) in one query. `staff` is
  intentionally NOT included — list response shape doesn't expose
  staff name. **Already optimal.**
- **shifts.service** — `findAll` includes `staff.user.name` via
  nested include; `staffName` everywhere comes from this one join.
  **Already optimal.**
- **admin.service** — `listStores` selects `owner`, `subscription`,
  and `_count: { products, staff }` in one query. There is no
  separate "list all subscriptions" endpoint — subscriptions
  surface inline on store list and detail-fetch per store.
  **Already optimal.**

## Bystander observations (NOT N+1, flagged for future work)

1. **`$queryRaw` invisible to counter.** `reports.service` uses 2
   `$queryRaw` blocks (sales-by-date histogram in `getSalesReport`,
   total stock value in `getProductsReport`). The Prisma extension
   only intercepts model operations; raw SQL bypasses the counter.
   Real DB work for reports is ≥ counted+2. If accurate query
   counting matters for the perf budget, instrument `$queryRaw`
   separately.
2. **Sequential awaits that could be `Promise.all`.** Two spots —
   neither is N+1, both 1–2 query latency wins:
   - `shifts.getZReport`: 3 sequential awaits → could be one
     `Promise.all`
   - `shifts.closeShift`: 2 sequential `sale.findMany` on the same
     shiftId → could be one
3. **In-memory aggregation of full sale rows.** `shifts.closeShift`
   and `shifts.getZReport` load every sale row into memory and
   reduce in JS. With small shifts this is fine; at scale (1000s
   sales/shift) consider `groupBy({by:['paymentType'], _sum:{total:true}})`.
4. **Count+findMany not in `$transaction`.** `products.findAll`,
   `sales.findAll`, `shifts.findAll`, `admin.listStores`,
   `admin.listUsers`, `admin.listAnnouncements`, `admin.listAuditLogs`
   all use `Promise.all([findMany, count])` instead of
   `prisma.$transaction([...])`. Micro-optimization (one fewer
   round-trip, snapshot-isolated count), not an N+1.

## What this means for the spec

The D.4 spec required "5 top offenders measurably reduced". The
inspection shows the predicted offenders don't exist — the
codebase already follows the batching patterns we'd have applied.
The QueryCounter middleware itself remains the durable artefact:
any FUTURE PR that introduces an N+1 (per-row findFirst in a
loop, missing include where the response shape demands a relation,
etc.) will trip the WARN/ERROR threshold and surface in logs.

**Recommendation accepted by spec's "Risks" section:** "if a
finding suggests a fix isn't needed, document and don't make
unnecessary changes." 5 SKIPs documented.

## Notes

- The query counter sees model operations inside controller bodies,
  not auth/guard queries (those run before the interceptor wraps).
  That is the intended scope.
- Raw SQL (`$queryRaw`, `$executeRaw`) is NOT counted (see
  bystander observation #1).
- Admin endpoint does NOT accept `page` / `limit` query params
  (returns HTTP 400 "Поле «page» не разрешено"). Measured without
  pagination params.
