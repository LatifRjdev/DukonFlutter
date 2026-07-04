# Design — Spec H "Load Testing & Perf Baseline"

**Date:** 2026-07-04
**Scope:** 4 k6 scenarios exercising POS + reports + admin + auth-throttle paths against local dev API. Produces p50/p95/p99 baseline REPORT. Inline-fixes only clear bottlenecks; ambiguous findings become follow-up specs.

## Summary

Load testing establishes performance baselines under 100-concurrent-cashier assumption. k6 exercises the observability stack shipped in D.4 (QueryCounter) + G.B (OTel) + G.A (Sentry) — the load run itself validates that instrumentation captures p95 correctly. Threshold-based scenarios exit non-zero on regressions, making the tests CI-friendly if we later want them there.

## Architecture

**Tool:** k6 (Grafana). Chosen over Artillery for JS scripting DX, native OTLP/Prom output, threshold-as-exit-code CI-friendliness.

**Scenarios:**
- `01-pos-happy-path.js` — login → list products → create sale (3 items, cash) → refund half → logout. 50 VU ramp to 100 over 2 min, hold 3 min. Threshold: `http_req_duration p(95)<500`, `http_req_failed rate<0.01`.
- `02-reports-read-heavy.js` — login → GET `/reports/sales` + `/reports/profit` + `/reports/products`. 20 VU, 5 min. Tests raw-SQL aggregation paths. Threshold: `http_req_duration p(95)<800`.
- `03-admin-bulk-approve.js` — admin token → 30 sequential `subscription.approve` calls per VU. 5 VU, 2 min. Tests `$transaction` + audit log throughput. Threshold: `http_req_duration p(95)<300`.
- `04-auth-throttle-proof.js` — 200 RPS login with rotating wrong passwords from 10 distinct VU-IDs. 1 min. Inverted threshold: `http_req_failed rate>0.95` after warmup — proves 429s from the throttler.

**Shared helper:** `tests/load/k6/lib/auth.js` — login + cache token across VUs. Uses `setup()` hook so 1 login per scenario, reused by all VUs.

**Env vars:**
- `K6_BASE_URL` (default `http://localhost:4455`)
- `K6_QA_STORE_ID` (default hardcoded qa-business store id)
- `K6_ADMIN_PHONE` / `K6_ADMIN_PASSWORD`
- `OTEL_EXPORTER_OTLP_ENDPOINT` (optional — if set, load run also emits traces)

**Data isolation:** each scenario uses a dedicated `qa-loadtest` store. Teardown does `DELETE FROM sales WHERE storeId='<loadtest>'` to keep dev DB clean.

## Files touched

**Create:**
- `tests/load/k6/lib/auth.js`
- `tests/load/k6/01-pos-happy-path.js`
- `tests/load/k6/02-reports-read-heavy.js`
- `tests/load/k6/03-admin-bulk-approve.js`
- `tests/load/k6/04-auth-throttle-proof.js`
- `tests/load/README.md` — how to run, env vars, threshold meaning, cleanup
- `qa/2026-07-04-load-baseline/REPORT.md` — p50/p95/p99 table + findings + recommendations
- `api/prisma/migrations/<ts>_qa_loadtest_store/migration.sql` — seed the loadtest store + one admin + throttle-exempt entry if needed

**Modify:**
- `CONTRIBUTING.md` — mention `tests/load/` folder in "Where things live"

## Acceptance

- 4 k6 scripts exist under `tests/load/k6/` and run cleanly locally (`k6 run tests/load/k6/01-pos-happy-path.js`)
- All 4 scenarios complete within their threshold expectations (or thresholds documented as expected-fail with reason)
- `qa/2026-07-04-load-baseline/REPORT.md` has p50/p95/p99 table per scenario + ≥1 finding row
- 0 P0/P1 perf issues OR inline-fixed before REPORT commit
- `npm test` ≥231, `npm run test:e2e` ≥11, `flutter test` ≥441 remain green

## Out of scope

- Stress test until break (find the cliff). Baselining under 100-concurrent-cashier load, not finding the wall.
- Browser-side perf (Lighthouse, Flutter frame rate). Backend only.
- Grafana k6 cloud dashboards.
- CI integration of load tests (too slow + flaky for every PR — separate spec).
- Auto-scale tuning. Just produces numbers.

## Risks

- **k6 binary install.** Mitigation: `brew install k6` documented; Docker one-liner alternative in README.
- **Dev Postgres on laptop is bottleneck, not API.** Mitigation: REPORT distinguishes DB-bound vs API-bound findings; only inline-fix the latter.
- **Throttler test hits 429 by design.** Mitigation: inverted threshold documented explicitly.
- **Load-test data pollution.** Mitigation: dedicated `qa-loadtest` store + teardown DELETE.

## Ship plan

~1.5 days:
1. README + `tests/load/` scaffold + `auth.js` helper
2. Scenario 1 POS happy path (biggest, most informative)
3. Scenarios 2-4 in parallel after framework proven
4. Live run + REPORT
5. Any inline fixes if clear bottlenecks surface

## Test results gate

After implementation:
- API: `npm test` (≥231) + `npm run test:e2e` (≥11)
- App: `flutter test` (≥441) + `dart analyze lib/` (0)
- 0 tsc errors
- 4 k6 scripts run locally (exit 0 or documented threshold-inversion)
- `REPORT.md` has p50/p95/p99 numbers + findings section
