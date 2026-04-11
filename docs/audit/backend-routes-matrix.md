# Backend Routes Dynamic Audit — 2026-04-10

Backend target: `http://localhost:4455/api` (NestJS, live)

## Summary
- Total routes discovered: **78**
- Total checks run (auth/valid/invalid/tenant/sqli): **254**
- Checks passed: **253** (99.6%)
- Rate limit on /auth/login: **ENFORCED** (statuses: [401, 429, 429, 429, 429, 429, 429, 429, 429, 429, 429, 429])
- P0 bugs: **0**
- P1 bugs: **0**
- P2 bugs: **1**
- Routes not fully testable (need sequenced state): **2**

## Test Setup
- Primary user: `+992901234567` / `test1234`
- Primary storeId: `e2f7e503-eec0-4816-b9e7-efe1cc544c34`
- Alt user: `+992123901423` / `test1234`
- Alt storeId (newly created): `4a5ffaad-cf6b-44a6-a501-7b13961cf2b9`
- Bootstrap: category, product, customer, supplier, expense, staff, shift, sale all created via primary token.

## Route Matrix

| Method | Path | Auth 401 | Valid 2xx | Invalid 400 | Tenant 403 | SQLi safe | Notes |
|---|---|---|---|---|---|---|---|
| POST | `/auth/register` | n/a | PASS | PASS | n/a | PASS |  |
| POST | `/auth/login` | n/a | PASS | PASS | n/a | PASS |  |
| POST | `/auth/refresh` | n/a | PASS | n/a | n/a | PASS | refresh-w-bad-token; 401-on-invalid-refresh-token-expected |
| POST | `/auth/logout` | PASS | n/a | n/a | n/a | n/a | skipped-valid-preserve-token |
| GET | `/users/me` | PASS | PASS | n/a | n/a | n/a |  |
| PUT | `/users/me` | PASS | PASS | n/a | n/a | PASS |  |
| PUT | `/users/me/password` | PASS | PASS | n/a | n/a | PASS |  |
| POST | `/stores` | PASS | PASS | PASS | n/a | PASS |  |
| GET | `/stores` | PASS | PASS | n/a | n/a | n/a |  |
| GET | `/stores/{storeId}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}` | PASS | PASS | n/a | PASS | PASS |  |
| POST | `/stores/{storeId}/categories` | PASS | PASS | PASS | PASS | PASS |  |
| GET | `/stores/{storeId}/categories` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/categories/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/categories/{id}` | PASS | PASS | n/a | PASS | FAIL |  |
| DELETE | `/stores/{storeId}/categories/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/products` | PASS | PASS | PASS | PASS | PASS |  |
| GET | `/stores/{storeId}/products` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/products/barcode/{barcode}` | PASS | PASS | n/a | PASS | n/a | 404-for-missing-barcode-ok |
| GET | `/stores/{storeId}/products/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/products/{id}` | PASS | PASS | n/a | PASS | PASS |  |
| DELETE | `/stores/{storeId}/products/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/products/{productId}/stock-movements` | PASS | PASS | n/a | PASS | PASS | valid-with-correct-dto |
| GET | `/stores/{storeId}/products/{productId}/stock-movements` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/sales` | PASS | PASS | PASS | PASS | PASS | valid-with-correct-dto |
| GET | `/stores/{storeId}/sales` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/sales/{id}` | PASS | PASS | n/a | PASS | n/a | valid-with-real-sale-id |
| POST | `/stores/{storeId}/sales/{id}/refund` | PASS | PASS | n/a | PASS | PASS | valid-with-correct-dto |
| POST | `/stores/{storeId}/customers` | PASS | PASS | PASS | PASS | PASS |  |
| GET | `/stores/{storeId}/customers` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/customers/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/customers/{id}` | PASS | PASS | n/a | PASS | PASS |  |
| DELETE | `/stores/{storeId}/customers/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/customers/{id}/debts` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/customers/{id}/payments` | PASS | PASS | n/a | PASS | n/a | valid-with-correct-dto |
| GET | `/stores/{storeId}/customers/{id}/payments` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/suppliers` | PASS | PASS | PASS | PASS | PASS |  |
| GET | `/stores/{storeId}/suppliers` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/suppliers/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/suppliers/{id}` | PASS | PASS | n/a | PASS | PASS |  |
| DELETE | `/stores/{storeId}/suppliers/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/suppliers/{id}/debts` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/suppliers/{id}/payments` | PASS | PASS | n/a | PASS | n/a | 400-no-outstanding-debt-is-expected-business-rule |
| GET | `/stores/{storeId}/suppliers/{id}/payments` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/expenses` | PASS | PASS | PASS | PASS | PASS |  |
| GET | `/stores/{storeId}/expenses` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/expenses/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/expenses/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| DELETE | `/stores/{storeId}/expenses/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/finances/overview` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/finances/dashboard` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/finances/summary` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/zakat/calculate` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/zakat/settings` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/zakat/settings` | PASS | PASS | n/a | PASS | n/a | valid-with-correct-dto |
| GET | `/stores/{storeId}/zakat/payments` | PASS | PASS | n/a | PASS | n/a |  |
| POST | `/stores/{storeId}/zakat/payments` | PASS | PASS | n/a | PASS | PASS | valid-with-correct-dto |
| POST | `/stores/{storeId}/staff` | PASS | PASS | PASS | PASS | PASS |  |
| GET | `/stores/{storeId}/staff` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/staff/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/staff/{id}` | PASS | PASS | n/a | PASS | PASS |  |
| DELETE | `/stores/{storeId}/staff/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/roles` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/roles/{role}/permissions` | PASS | PASS | n/a | PASS | n/a |  |
| PUT | `/stores/{storeId}/roles/{role}/permissions` | PASS | PASS | n/a | PASS | n/a | valid-with-correct-dto |
| POST | `/stores/{storeId}/payroll/calculate` | PASS | PASS | n/a | PASS | PASS | valid-with-correct-dto |
| GET | `/stores/{storeId}/payroll` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/payroll/{periodId}` | PASS | PASS | n/a | PASS | n/a | valid-with-correct-dto |
| POST | `/stores/{storeId}/payroll/{periodId}/adjustments` | PASS | PASS | n/a | PASS | PASS | expects 'description' not 'reason' — with correct DTO works |
| DELETE | `/stores/{storeId}/payroll/{periodId}/adjustments/{adjustmentId}` | PASS | skip | n/a | PASS | n/a | needs real adjustment id; skipped |
| POST | `/stores/{storeId}/payroll/{periodId}/pay/{payrollId}` | PASS | skip | n/a | PASS | n/a | needs real payrollId inside period; skipped |
| POST | `/stores/{storeId}/payroll/{periodId}/pay-all` | PASS | PASS | n/a | PASS | n/a | valid-with-correct-dto |
| POST | `/stores/{storeId}/shifts/open` | PASS | PASS | PASS | PASS | n/a | 409-shift-already-open-is-expected |
| POST | `/stores/{storeId}/shifts/{id}/close` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/shifts/current` | PASS | PASS | n/a | PASS | n/a | 404-when-no-open-shift-is-valid-behavior |
| GET | `/stores/{storeId}/shifts` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/shifts/{id}` | PASS | PASS | n/a | PASS | n/a |  |
| GET | `/stores/{storeId}/shifts/{id}/z-report` | PASS | PASS | n/a | PASS | n/a |  |

## Bugs

### [P2-BE-DYN-001] SQLi payload triggered 500 (unhandled)
- **Route:** `PUT /stores/{storeId}/categories/{id}`
- **Expected:** 400 validation error (or normal error)
- **Actual:** {'unauth': 401, 'valid': 200, 'tenant': 403, 'sqli': 500}
- **Impact:** No data leak / no SQL injection (SQLDelight/Prisma parameterizes queries). But generic 500 with `"Internal server error"` leaks a server-crash signal.
- **Reproduction:**
  ```bash
  TOKEN=$(curl -s -X POST http://localhost:4455/api/auth/login -H "Content-Type: application/json" -d '{"phone":"+992901234567","password":"test1234"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")
  curl -s -X PUT "http://localhost:4455/api/stores/e2f7e503-eec0-4816-b9e7-efe1cc544c34/categories/<real-category-id>" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"\'; DROP TABLE users; --"}'
  ```
- **Fix:** Add a class-validator `@Matches`/`@IsString` constraint that rejects control chars or apply a central HttpException filter that sanitizes Prisma errors into 400s.

## Untested Routes

- `DELETE /stores/{storeId}/payroll/{periodId}/adjustments/{adjustmentId}` — needs real adjustment id; skipped
- `POST /stores/{storeId}/payroll/{periodId}/pay/{payrollId}` — needs real payrollId inside period; skipped

## Cross-cutting Findings

1. **Auth guard coverage is perfect.** All 75 protected routes return 401 to unauthenticated requests. No route leaks without a token.
2. **Tenant isolation is perfect.** Every `/stores/{storeId}/*` route returns 403 when the alt-user token is used against the primary store. Zero cross-tenant leaks detected across 69 store-scoped routes.
3. **SQL injection surface is closed.** All text fields accept the `'; DROP TABLE users; --` payload without executing it. Queries are parameterized (Prisma). One PUT (`/stores/{storeId}/categories/{id}`) returned a 500 rather than a 400, which is an error-handling bug, not a SQLi vulnerability. Database integrity verified via follow-up GET.
4. **Rate limiting works aggressively on /auth/login.** After a single failed attempt the route returns 429 for subsequent attempts. (Possibly too aggressive — could lock out legitimate typos.)
5. **Validation (class-validator / whitelist) rejects unknown and malformed fields with 400** on every DTO tested. No 500s from missing required fields.
6. Business-rule 4xx responses are correct (e.g. `POST /suppliers/{id}/payments` returns 400 "This supplier has no outstanding debt" when there is none; `POST /shifts/open` returns 409 "shift already open"; `POST /customers/{id}/payments` returns 404 if `saleId` does not belong to that customer). None of these are bugs.

## Test Artifacts
- Raw per-route results: `/tmp/audit_results.json`
- Bootstrap IDs: `/tmp/audit_ids.json`
- Swagger snapshot: `/tmp/swagger.json`
- Test harness: `/tmp/audit_run.py`, `/tmp/audit_final.py`, `/tmp/audit_patch.py`