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

Scenario 01 creates real sales in the dev DB. To clean up after a load run:

```bash
psql postgresql://dukonpro:dukonpro@localhost:5435/dukonpro \
  -c "DELETE FROM \"Sale\" WHERE \"localId\" LIKE 'k6-%';"
```

Or just reset the dev DB: `docker-compose down -v && docker-compose up -d`.

## CI integration

Load tests are **not** in CI — they're too slow and flaky on shared runners. Run them manually before major releases or after perf-relevant changes. See Spec H design doc for the rationale.
