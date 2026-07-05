# Spec H — Load Testing & Perf Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 4 k6 load-test scenarios (POS happy path, reports read-heavy, admin bulk approve, auth throttle proof) with a shared auth helper and a filled baseline REPORT.

**Architecture:** Each k6 script is standalone JS — no TypeScript, no bundler. `lib/auth.js` exports pure functions imported by every scenario. `setup()` in each scenario runs once before VUs start and returns a data object (token, storeId, any IDs) that k6 passes to every VU invocation. All scenarios read credentials from env vars with sane defaults for local dev. No new Prisma migrations; tests run against the existing dev database.

**Tech Stack:** k6 (Grafana load testing framework), plain JavaScript (ES module syntax supported by k6), NestJS API at `http://localhost:4455/api`, Postgres 16.

**Prerequisites for the live run:**
- `brew install k6` (or Docker: `docker run --rm --network host grafana/k6 run ...`)
- Dev API running (`cd api && npm run start:dev` or docker-compose)
- At least one store in the dev DB with ≥ 3 active products
- Owner user credentials (phone + password) for that store
- Admin user credentials (phone + password, `isAdmin: true`) for scenario 03
- At least one PENDING payment in the DB for scenario 03 (or the idempotent approve still measures throughput if there are none — it returns 404, which is acceptable to document)

---

## File Map

| File | Responsibility |
|------|---------------|
| `tests/load/k6/lib/auth.js` | `login()` + `authHeaders()` helpers shared by all scenarios |
| `tests/load/k6/01-pos-happy-path.js` | 50→100 VU ramp: login → list products → create sale → refund → logout |
| `tests/load/k6/02-reports-read-heavy.js` | 20 VU steady: GET sales + profit + products reports |
| `tests/load/k6/03-admin-bulk-approve.js` | 5 VU: 30 sequential approve-payment calls (idempotent OK) |
| `tests/load/k6/04-auth-throttle-proof.js` | 10 VU hammering login with wrong creds — inverted threshold expects >95% 429 |
| `tests/load/README.md` | How to run, env vars, prerequisites, cleanup, threshold meaning |
| `qa/2026-07-04-load-baseline/REPORT.md` | p50/p95/p99 table + findings filled in after live run |
| `CONTRIBUTING.md` | One-liner added under "Where things live" |

---

## Task 1: Directory scaffold + `lib/auth.js`

**Files:**
- Create: `tests/load/k6/lib/auth.js`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/tests/load/k6/lib
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-07-04-load-baseline
```

- [ ] **Step 2: Create `tests/load/k6/lib/auth.js`**

```js
// Shared auth helpers for k6 load scenarios.
// Import with: import { login, authHeaders } from './lib/auth.js';
import http from 'k6/http';
import { check } from 'k6';

/**
 * POST /api/auth/login and return the accessToken.
 * Calls check() so k6 tracks this request in metrics.
 * Throws (via check failure) if login returns non-200.
 */
export function login(baseUrl, phone, password) {
  const res = http.post(
    `${baseUrl}/api/auth/login`,
    JSON.stringify({ phone, password }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(res, { 'setup: login 200': (r) => r.status === 200 });
  return JSON.parse(res.body).accessToken;
}

/**
 * Returns a k6 params object with Authorization + Content-Type headers.
 * Pass as the third argument to any http.* call that needs auth.
 */
export function authHeaders(token) {
  return {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
  };
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add tests/load/k6/lib/auth.js
git commit -m "test(load): scaffold k6 directory + shared auth helper"
```

---

## Task 2: Scenario 01 — POS happy path

**Files:**
- Create: `tests/load/k6/01-pos-happy-path.js`

This is the most representative scenario: a full cashier session — login, browse products, ring up a 3-item sale, refund 1 item, logout.

- [ ] **Step 1: Create `tests/load/k6/01-pos-happy-path.js`**

```js
/**
 * Scenario 01 — POS happy path
 *
 * Simulates a cashier completing a full sale + refund cycle.
 * Ramp: 50 VU → 100 VU over 2 min, hold 3 min, ramp down 30s.
 * Thresholds: p(95) < 500ms, error rate < 1%.
 *
 * Required env vars:
 *   K6_BASE_URL          Default: http://localhost:4455
 *   K6_OWNER_PHONE       Default: +992900000001
 *   K6_OWNER_PASSWORD    Default: password123
 *   K6_QA_STORE_ID       Required: UUID of the store to test against
 */
import http from 'k6/http';
import { check, sleep } from 'k6';
import { login, authHeaders } from './lib/auth.js';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '3m', target: 100 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export function setup() {
  const phone = __ENV.K6_OWNER_PHONE || '+992900000001';
  const password = __ENV.K6_OWNER_PASSWORD || 'password123';
  const storeId = __ENV.K6_QA_STORE_ID;
  if (!storeId) {
    throw new Error('K6_QA_STORE_ID env var is required');
  }

  const token = login(BASE_URL, phone, password);

  // Fetch first page of products to get real product IDs.
  const productsRes = http.get(
    `${BASE_URL}/api/stores/${storeId}/products?take=10`,
    authHeaders(token),
  );
  check(productsRes, { 'setup: products 200': (r) => r.status === 200 });

  const products = JSON.parse(productsRes.body).data || [];
  if (products.length < 3) {
    throw new Error(
      `Need at least 3 active products in store ${storeId}, found ${products.length}`,
    );
  }

  return {
    token,
    storeId,
    productIds: products.slice(0, 3).map((p) => p.id),
  };
}

export default function (data) {
  const { token, storeId, productIds } = data;
  const headers = authHeaders(token);

  // Step 1: List products (simulates cashier browsing/searching)
  const productsRes = http.get(
    `${BASE_URL}/api/stores/${storeId}/products?take=20`,
    headers,
  );
  check(productsRes, { 'products list 200': (r) => r.status === 200 });

  // Step 2: Create a 3-item cash sale
  const saleBody = JSON.stringify({
    paymentType: 'CASH',
    paidAmount: 9999,
    localId: `k6-vu${__VU}-iter${__ITER}`,
    items: productIds.map((id) => ({ productId: id, quantity: 1 })),
  });
  const saleRes = http.post(
    `${BASE_URL}/api/stores/${storeId}/sales`,
    saleBody,
    headers,
  );
  check(saleRes, { 'sale create 201': (r) => r.status === 201 });

  if (saleRes.status !== 201) {
    sleep(1);
    return;
  }

  const sale = JSON.parse(saleRes.body);

  // Step 3: Refund the first item
  const refundBody = JSON.stringify({
    items: [{ saleItemId: sale.items[0].id, quantity: 1 }],
    reason: 'k6 load test refund',
  });
  const refundRes = http.post(
    `${BASE_URL}/api/stores/${storeId}/sales/${sale.id}/refund`,
    refundBody,
    headers,
  );
  check(refundRes, { 'refund 2xx': (r) => r.status >= 200 && r.status < 300 });

  // Step 4: Logout (simulates end of shift)
  const logoutRes = http.post(
    `${BASE_URL}/api/auth/logout`,
    null,
    headers,
  );
  check(logoutRes, { 'logout 200': (r) => r.status === 200 });

  sleep(1);
}
```

- [ ] **Step 2: Smoke-test the script locally (1 VU, 10s)**

```bash
# Ensure dev API is running, then:
k6 run \
  -e K6_QA_STORE_ID=<your-store-uuid> \
  -e K6_OWNER_PHONE=+992900000001 \
  -e K6_OWNER_PASSWORD=password123 \
  --vus 1 --duration 10s \
  tests/load/k6/01-pos-happy-path.js
```

Expected: 0 check failures, no script errors. Ignore threshold violations at 1 VU.

- [ ] **Step 3: Commit**

```bash
git add tests/load/k6/01-pos-happy-path.js
git commit -m "test(load): scenario 01 — POS happy path (login→sale→refund→logout)"
```

---

## Task 3: Scenario 02 — Reports read-heavy

**Files:**
- Create: `tests/load/k6/02-reports-read-heavy.js`

Tests the raw-SQL aggregation paths in ReportsService under 20 concurrent readers.

- [ ] **Step 1: Create `tests/load/k6/02-reports-read-heavy.js`**

```js
/**
 * Scenario 02 — Reports read-heavy
 *
 * 20 VUs each hitting 3 report endpoints (sales, profit, products) in a loop.
 * Duration: 5 min. Threshold: p(95) < 800ms.
 *
 * Required env vars:
 *   K6_BASE_URL          Default: http://localhost:4455
 *   K6_OWNER_PHONE       Default: +992900000001
 *   K6_OWNER_PASSWORD    Default: password123
 *   K6_QA_STORE_ID       Required: UUID of the store to test against
 */
import http from 'k6/http';
import { check, sleep } from 'k6';
import { login, authHeaders } from './lib/auth.js';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  vus: 20,
  duration: '5m',
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.02'],
  },
};

export function setup() {
  const phone = __ENV.K6_OWNER_PHONE || '+992900000001';
  const password = __ENV.K6_OWNER_PASSWORD || 'password123';
  const storeId = __ENV.K6_QA_STORE_ID;
  if (!storeId) {
    throw new Error('K6_QA_STORE_ID env var is required');
  }
  const token = login(BASE_URL, phone, password);
  return { token, storeId };
}

export default function (data) {
  const { token, storeId } = data;
  const headers = authHeaders(token);
  const query = '?startDate=2026-01-01&endDate=2026-12-31';
  const base = `${BASE_URL}/api/stores/${storeId}/reports`;

  const salesRes = http.get(`${base}/sales${query}`, headers);
  check(salesRes, { 'reports/sales 200': (r) => r.status === 200 });

  const profitRes = http.get(`${base}/profit${query}`, headers);
  check(profitRes, { 'reports/profit 200': (r) => r.status === 200 });

  const productsRes = http.get(`${base}/products${query}`, headers);
  check(productsRes, { 'reports/products 200': (r) => r.status === 200 });

  sleep(0.5);
}
```

- [ ] **Step 2: Smoke-test (1 VU, 10s)**

```bash
k6 run \
  -e K6_QA_STORE_ID=<your-store-uuid> \
  -e K6_OWNER_PHONE=+992900000001 \
  -e K6_OWNER_PASSWORD=password123 \
  --vus 1 --duration 10s \
  tests/load/k6/02-reports-read-heavy.js
```

Expected: all 3 checks pass, no 403/404 (store has the PREMIUM subscription feature `hasReportsAll`). If you see 403, the store's subscription plan doesn't include reports — use a store on BUSINESS or PREMIUM plan.

- [ ] **Step 3: Commit**

```bash
git add tests/load/k6/02-reports-read-heavy.js
git commit -m "test(load): scenario 02 — reports read-heavy (20 VU concurrent readers)"
```

---

## Task 4: Scenario 03 — Admin bulk approve

**Files:**
- Create: `tests/load/k6/03-admin-bulk-approve.js`

Tests `$transaction` + audit log throughput when an admin hammers approve-payment in a burst. The approve endpoint is idempotent, so repeated calls on the same payment ID are valid.

- [ ] **Step 1: Create `tests/load/k6/03-admin-bulk-approve.js`**

```js
/**
 * Scenario 03 — Admin bulk approve
 *
 * 5 VUs each calling approve-payment 30 times sequentially.
 * The endpoint is idempotent — approving the same payment twice returns
 * the already-approved state without error. This tests $transaction +
 * audit log write throughput under burst admin ops.
 *
 * Threshold: p(95) < 300ms.
 *
 * Required env vars:
 *   K6_BASE_URL            Default: http://localhost:4455
 *   K6_ADMIN_PHONE         Default: +992900000099
 *   K6_ADMIN_PASSWORD      Default: admin123
 *   K6_SUB_ID              Required: subscription UUID with a PENDING payment
 *   K6_PAYMENT_ID          Required: payment UUID to approve (PENDING or already APPROVED)
 */
import http from 'k6/http';
import { check } from 'k6';
import { login, authHeaders } from './lib/auth.js';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  vus: 5,
  duration: '2m',
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.05'],
  },
};

export function setup() {
  const phone = __ENV.K6_ADMIN_PHONE || '+992900000099';
  const password = __ENV.K6_ADMIN_PASSWORD || 'admin123';
  const subId = __ENV.K6_SUB_ID;
  const paymentId = __ENV.K6_PAYMENT_ID;
  if (!subId || !paymentId) {
    throw new Error('K6_SUB_ID and K6_PAYMENT_ID env vars are required');
  }
  const token = login(BASE_URL, phone, password);
  return { token, subId, paymentId };
}

export default function (data) {
  const { token, subId, paymentId } = data;
  const headers = authHeaders(token);

  // 30 sequential approve calls (matches spec: 30 per VU)
  for (let i = 0; i < 30; i++) {
    const res = http.put(
      `${BASE_URL}/api/admin/subscriptions/${subId}/approve-payment/${paymentId}`,
      null,
      headers,
    );
    // 200 on first approve, 200 on subsequent (idempotent)
    check(res, { 'approve 200': (r) => r.status === 200 });
  }
}
```

- [ ] **Step 2: Find a subscription + payment ID in dev DB**

```bash
# In api/ directory, connect to dev DB and find a pending or approved payment:
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma studio
# Navigate to Payment table, find any PENDING or APPROVED payment.
# Note its id and its subscriptionId.
```

Or via psql (dev DB at localhost:5435):
```bash
psql postgresql://dukonpro:dukonpro@localhost:5435/dukonpro \
  -c "SELECT p.id AS payment_id, p.\"subscriptionId\" AS sub_id, p.status FROM \"Payment\" p LIMIT 5;"
```

- [ ] **Step 3: Smoke-test (1 VU, 10s)**

```bash
k6 run \
  -e K6_ADMIN_PHONE=+992900000099 \
  -e K6_ADMIN_PASSWORD=admin123 \
  -e K6_SUB_ID=<sub-uuid> \
  -e K6_PAYMENT_ID=<payment-uuid> \
  --vus 1 --duration 10s \
  tests/load/k6/03-admin-bulk-approve.js
```

Expected: all checks pass with 200 (first approve activates, rest idempotent 200).

- [ ] **Step 4: Commit**

```bash
git add tests/load/k6/03-admin-bulk-approve.js
git commit -m "test(load): scenario 03 — admin bulk approve ($transaction throughput)"
```

---

## Task 5: Scenario 04 — Auth throttle proof

**Files:**
- Create: `tests/load/k6/04-auth-throttle-proof.js`

**Inverted scenario**: proves the NestJS `@Throttle({ limit: 5, ttl: 60000 })` on `POST /api/auth/login` actually fires 429s. With 10 VUs hammering from the same host, the first 5 succeed and the rest get throttled.

Threshold is **inverted**: `http_req_failed rate > 0.95` means the test PASSES when >95% of requests receive a non-2xx response (the 429s). k6 counts any non-2xx as "failed" by default.

- [ ] **Step 1: Create `tests/load/k6/04-auth-throttle-proof.js`**

```js
/**
 * Scenario 04 — Auth throttle proof
 *
 * 10 VUs each hammering POST /api/auth/login with wrong credentials.
 * The throttler allows 5/min per IP globally across all VUs (since they
 * share the runner machine's IP). After 5 requests, every subsequent login
 * attempt returns 429 Too Many Requests.
 *
 * INVERTED threshold: http_req_failed rate > 0.95 — the test PASSES only
 * when > 95% of requests are 429'd, proving the throttler is working.
 *
 * Duration: 1 min (one full throttle window).
 *
 * No env vars needed — uses intentionally wrong passwords.
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  vus: 10,
  duration: '1m',
  thresholds: {
    // Inverted: test passes when the FAILURE rate exceeds 95%
    // (meaning the throttler is firing 429 on > 95% of requests).
    'http_req_failed': ['rate>0.95'],
  },
};

// No setup() needed — all VUs send bad credentials.

export default function () {
  // Use __VU to rotate phones slightly (still wrong creds either way).
  const phone = `+99290000${String(__VU).padStart(4, '0')}`;
  const res = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ phone, password: 'definitely-wrong-password' }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  // Accept 401 (bad creds) or 429 (throttled) — both are expected.
  // 401 fires in the first few requests; 429 takes over quickly.
  check(res, {
    'throttled or rejected': (r) => r.status === 401 || r.status === 429,
  });

  sleep(0.1);
}
```

- [ ] **Step 2: Smoke-test (1 VU, 30s)**

```bash
k6 run --vus 1 --duration 30s tests/load/k6/04-auth-throttle-proof.js
```

Expected: first 5 iterations return 401, remaining 25 return 429. The `throttled or rejected` check should be 100% passing.

- [ ] **Step 3: Verify inverted threshold behaviour**

Run for 60s with 10 VUs and check the summary table at the end:

```bash
k6 run tests/load/k6/04-auth-throttle-proof.js
```

Expected output at the end:
```
✓ http_req_failed............: rate>0.95  ✓ [threshold met]
```

If you see `✗` for the inverted threshold, it means the throttler is NOT firing — check `CONTRIBUTING.md` for throttle config or ensure ThrottlerGuard is wired globally in `app.module.ts`.

- [ ] **Step 4: Commit**

```bash
git add tests/load/k6/04-auth-throttle-proof.js
git commit -m "test(load): scenario 04 — auth throttle proof (inverted 429 rate threshold)"
```

---

## Task 6: README + CONTRIBUTING.md update

**Files:**
- Create: `tests/load/README.md`
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Create `tests/load/README.md`**

```markdown
# Load Tests

k6-based performance baseline scenarios for the Dukon API.

## Install k6

```bash
brew install k6        # macOS
# or Docker (no install needed):
# docker run --rm --network host grafana/k6 run <script>
```

## Prerequisites

1. Dev API running at `http://localhost:4455` (or override `K6_BASE_URL`)
2. Dev Postgres running at `localhost:5435` (via docker-compose)
3. A store with ≥ 3 active products in the DB (used by scenario 01)
4. Owner user credentials (scenarios 01, 02)
5. Admin user credentials + a payment ID (scenario 03)

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `K6_BASE_URL` | `http://localhost:4455` | API base URL |
| `K6_OWNER_PHONE` | `+992900000001` | Tajik-format phone of the owner user |
| `K6_OWNER_PASSWORD` | `password123` | Owner password |
| `K6_QA_STORE_ID` | *(required)* | UUID of the store under test |
| `K6_ADMIN_PHONE` | `+992900000099` | Phone of an admin user (`isAdmin = true`) |
| `K6_ADMIN_PASSWORD` | `admin123` | Admin password |
| `K6_SUB_ID` | *(required for 03)* | UUID of a subscription with a payment |
| `K6_PAYMENT_ID` | *(required for 03)* | UUID of the payment to approve |

## Running scenarios

```bash
# Scenario 01 — POS happy path (5m30s total, up to 100 VUs)
k6 run -e K6_QA_STORE_ID=<uuid> tests/load/k6/01-pos-happy-path.js

# Scenario 02 — Reports read-heavy (5m, 20 VUs)
k6 run -e K6_QA_STORE_ID=<uuid> tests/load/k6/02-reports-read-heavy.js

# Scenario 03 — Admin bulk approve (2m, 5 VUs)
k6 run -e K6_SUB_ID=<uuid> -e K6_PAYMENT_ID=<uuid> tests/load/k6/03-admin-bulk-approve.js

# Scenario 04 — Auth throttle proof (1m, 10 VUs — expects 429s)
k6 run tests/load/k6/04-auth-throttle-proof.js
```

## Thresholds

| Scenario | Metric | Threshold | Pass means |
|---|---|---|---|
| 01 POS | `http_req_duration p(95)` | < 500ms | Sale round-trip under 500ms at 100 VU |
| 01 POS | `http_req_failed rate` | < 1% | < 1% of requests error |
| 02 Reports | `http_req_duration p(95)` | < 800ms | Report aggregation under 800ms at 20 VU |
| 03 Admin | `http_req_duration p(95)` | < 300ms | Admin approve under 300ms |
| 04 Throttle | `http_req_failed rate` | **> 95%** | **Inverted** — throttler must fire on >95% |

k6 exits with code 1 if any threshold fails, making it CI-friendly once integrated.

## Data cleanup

Scenarios 01 creates real sales in the dev DB. To clean up after a load run:

```bash
psql postgresql://dukonpro:dukonpro@localhost:5435/dukonpro \
  -c "DELETE FROM \"Sale\" WHERE notes LIKE 'k6%' OR \"localId\" LIKE 'k6-%';"
```

Or just reset the dev DB: `docker-compose down -v && docker-compose up -d`.

## CI integration

Load tests are **not** in CI — they're too slow and flaky on shared runners. Run them manually before major releases or after perf-relevant changes. See Spec H design doc for the rationale.
```

- [ ] **Step 2: Add one line to `CONTRIBUTING.md` under "Where things live"**

In [CONTRIBUTING.md](../CONTRIBUTING.md), find the section:
```
## Where things live

- `api/` — NestJS + Prisma backend
- `app/` — Flutter mobile app
- `docs/superpowers/specs/` — design docs
- `docs/superpowers/plans/` — implementation plans
- `qa/<date>-<topic>/` — verification artefacts (REPORT.md, scripts, screenshots)
```

Add after the `qa/` line:
```
- `tests/load/` — k6 load scenarios (run manually, not in CI); see `tests/load/README.md`
```

- [ ] **Step 3: Commit**

```bash
git add tests/load/README.md CONTRIBUTING.md
git commit -m "docs(load): README for k6 load tests + CONTRIBUTING.md update"
```

---

## Task 7: Live run + fill in REPORT

**Files:**
- Create: `qa/2026-07-04-load-baseline/REPORT.md`

This task runs all 4 scenarios against the dev API and records the actual numbers.

- [ ] **Step 1: Start the dev stack**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
docker-compose up -d
# Wait for healthy: docker-compose ps
# Then verify:
curl -s http://localhost:4455/api/health | jq .
```

- [ ] **Step 2: Run all 4 scenarios and capture output**

Run each scenario and copy the summary table printed at the end of the k6 output. Note p50, p95, p99 from `http_req_duration` and the pass/fail of each threshold.

```bash
# 01
k6 run -e K6_QA_STORE_ID=<uuid> tests/load/k6/01-pos-happy-path.js 2>&1 | tee /tmp/k6-01.txt

# 02
k6 run -e K6_QA_STORE_ID=<uuid> tests/load/k6/02-reports-read-heavy.js 2>&1 | tee /tmp/k6-02.txt

# 03
k6 run -e K6_SUB_ID=<uuid> -e K6_PAYMENT_ID=<uuid> tests/load/k6/03-admin-bulk-approve.js 2>&1 | tee /tmp/k6-03.txt

# 04
k6 run tests/load/k6/04-auth-throttle-proof.js 2>&1 | tee /tmp/k6-04.txt
```

- [ ] **Step 3: Create `qa/2026-07-04-load-baseline/REPORT.md`**

Fill in the actual numbers from the k6 output. Template:

```markdown
# Load Baseline Report — Spec H

**Date:** 2026-07-05
**API version:** commit `$(git rev-parse --short HEAD)`
**Machine:** MacBook Pro M-series (local dev, single instance)
**DB:** Postgres 16 (docker-compose, no connection pool tuning)

## Results

| Scenario | VUs | Duration | p50 | p95 | p99 | Error rate | Threshold |
|---|---|---|---|---|---|---|---|
| 01 POS happy path | 0→100 | 5m30s | _ms | _ms | _ms | _% | ✅ / ❌ p95<500ms |
| 02 Reports read-heavy | 20 | 5m | _ms | _ms | _ms | _% | ✅ / ❌ p95<800ms |
| 03 Admin bulk approve | 5 | 2m | _ms | _ms | _ms | _% | ✅ / ❌ p95<300ms |
| 04 Auth throttle proof | 10 | 1m | n/a | n/a | n/a | _% | ✅ / ❌ rate>95% |

## Findings

| # | Scenario | Finding | Severity | Action |
|---|---|---|---|---|
| 1 | 01 | _describe what you see_ | P3 / INFO | _inline fix / follow-up spec_ |

## Bottleneck analysis

**DB-bound vs API-bound:** If p95 on scenario 02 (reports) is high, check
`docker logs dukon-postgres-1` for slow query log entries (threshold: 500ms).
Raw SQL aggregation in ReportsService at `api/src/modules/reports/reports.service.ts`
is the most likely DB bottleneck.

**If scenario 03 p95 > 300ms:** The `$transaction` write path in
`subscriptions.service.ts:adminApprovePayment` + audit log insert is the
critical path. Check for missing index on `Payment.subscriptionId`.

## Out of scope

- Stress test until failure (cliff-finding). This is a baseline under expected load.
- Browser-side performance.
- Grafana k6 Cloud dashboards.
```

- [ ] **Step 4: Commit the REPORT**

```bash
git add qa/2026-07-04-load-baseline/REPORT.md
git commit -m "test(load): run all 4 k6 scenarios + baseline REPORT (Spec H)"
```

---

## Final verification gate

After all tasks:

- [ ] `npm test` in `api/` — still ≥ 231 passing
- [ ] `flutter test` in `app/` — still 441 passing
- [ ] `npx tsc --noEmit` in `api/` — 0 errors
- [ ] All 4 k6 scripts exist at `tests/load/k6/`
- [ ] `k6 run --vus 1 --duration 5s tests/load/k6/01-pos-happy-path.js -e K6_QA_STORE_ID=<uuid>` — runs without JavaScript errors
- [ ] `qa/2026-07-04-load-baseline/REPORT.md` has filled-in p50/p95/p99 table

---

## Self-review notes

**Spec coverage check:**
- ✅ `lib/auth.js` shared helper (spec: "login + cache token across VUs")
- ✅ Scenario 01: login→products→sale→refund→logout, 50→100 VU, p95<500ms threshold (spec match)
- ✅ Scenario 02: GET 3 report endpoints, 20 VU, p95<800ms threshold (spec match)
- ✅ Scenario 03: 30 approve calls per VU, 5 VU, p95<300ms threshold (spec match)
- ✅ Scenario 04: wrong-password hammering, inverted threshold rate>0.95 (spec match)
- ✅ `tests/load/README.md` with env vars, how-to-run, cleanup, threshold meaning
- ✅ `CONTRIBUTING.md` one-liner update
- ✅ `qa/2026-07-04-load-baseline/REPORT.md` template
- ✅ No migrations (using existing store data)
- ✅ Data isolation via `localId: k6-vu${__VU}-iter${__ITER}` + cleanup SQL documented

**Deviations from spec:**
- Spec mentions `setup()` with "1 login per scenario, reused by all VUs" — implemented exactly this way. All VUs receive the token via k6's data-passing mechanism.
- Spec says "dedicated `qa-loadtest` store + teardown DELETE" — args override says use existing store. Teardown documented as manual SQL in README instead.
- Scenario 03 uses idempotent approve (spec's intent: test `$transaction` throughput) — idempotency is by design as documented in `admin.payments.spec.ts`.
