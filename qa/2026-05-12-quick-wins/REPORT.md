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

## Baseline (BEFORE fixes) — top 5 endpoints

| # | Endpoint | Before | After | Fix |
|---|----------|-------:|------:|-----|
| 1 | GET /api/stores/:id/reports/sales | 2 | TBD | reports.service per-row customer.findFirst → batch findMany |
| 2 | GET /api/stores/:id/products | 2 | TBD | products.service separate count + findMany → $transaction |
| 3 | GET /api/stores/:id/sales | 2 | TBD | sales.service include.customer |
| 4 | GET /api/stores/:id/shifts | 2 | TBD | shifts.service include.staff |
| 5 | GET /api/admin/subscriptions | 1 | TBD | admin.service include relations |

(TBD in "After" column is filled in by Tasks D.4.7–D.4.11.)

## Notes

- The query counter sees model operations inside controller bodies,
  not auth/guard queries (those run before the interceptor wraps).
  That is the intended scope.
- Raw SQL (`$queryRaw`, `$executeRaw`) is NOT counted. The reports
  endpoint in particular leans on raw aggregation SQL, which is why
  its model-query count is low (2) despite returning grouped/joined
  data.
- The five baselines all came in BELOW the planned fix targets.
  This means the originally-anticipated N+1s (per-row
  customer.findFirst in reports, separate count+findMany in
  products list, missing customer/staff includes in sales/shifts,
  missing relation includes in admin subscriptions) are NOT
  actually present in the current code paths against this dataset
  — or they're hidden behind `$queryRaw` which the counter does
  not see.
- Tasks D.4.7–D.4.11 should therefore (a) re-confirm by reading
  the service code directly, (b) decide per-endpoint whether a fix
  is still warranted (e.g. defensive include consolidation, or a
  raw→Prisma rewrite so the counter can audit), and (c) update the
  "After" column with the post-fix re-measurement.
- Admin endpoint does NOT accept `page` / `limit` query params
  (returns HTTP 400 "Поле «page» не разрешено"). Measured without
  pagination params; returned 9 subscriptions in a single
  `findMany` call.
