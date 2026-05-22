# OWASP Top-10 sweep — 2026-05-22 (Spec G E)

## Scope

Code-only audit of `api/src/`. No penetration testing. Cross-referenced with:
- Sprint C RBAC audit (2026-05-06): `qa/2026-05-06-api-audit.md`
- Spec F D.1 dead-code sweep: `qa/2026-05-16-dead-code/REPORT.md`
- Spec F C.1 deps audit: `qa/2026-05-16-deps-audit/REPORT.md`
- Spec G A–D: Sentry PII hardening, throttler tightening, postgres slow-log

## Severity counts

- **0 P0** (critical — fix immediately)
- **0 P1** (high — fix in next sprint)
- **1 P2** (medium — deferred with mitigation): A06 npm advisories (carried from Spec F C.1)
- **2 P3** (informational): A01 currencies auth posture; A10 unauthenticated rate-fetch trigger

## Matrix

| Cat | Title | Status | Note |
|-----|-------|--------|------|
| A01 | Broken Access Control | PASS (1 P3) | Every store-scoped controller gated; currencies endpoints intentionally public — see A01 detail |
| A02 | Cryptographic Failures | PASS | bcrypt rounds=12 everywhere; no MD5/SHA1 found; JWT secrets env-only with placeholder guard; Sentry `sendDefaultPii=false` + `beforeSend` scrub (Spec G A.1) |
| A03 | Injection | PASS | 0 `$queryRaw` / `$executeRaw` in `api/src/`; all DB access via Prisma parameterized queries |
| A04 | Insecure Design | PASS | localId idempotency on Sale, StockMovement, DebtPayment, SupplierPayment, ZakatPayment, Investment; `@Min` guards on all money DTOs; server re-derives totals |
| A05 | Security Misconfiguration | PASS | helmet + explicit CSP/HSTS; CORS_ORIGIN required in prod (throws on wildcard/empty); JWT secrets validated against placeholder list on boot; only non-secret env fallbacks present |
| A06 | Vulnerable Components | PARTIAL (1 P2) | 18 npm advisories (4 trees) documented in Spec F C.1; mitigations in place — see A06 detail |
| A07 | Identification & Auth Failures | PASS | Throttle 3–10/min on all auth endpoints; `tokensRevokedAt` check in both JWT strategies forces re-login on secret rotation; bcrypt.compare for all password checks |
| A08 | Software & Data Integrity Failures | PASS | AuditLog on refund/sub/staff/inv/zakat; `@Min(0.01)` DTO guards on payment amounts; localId idempotency keys |
| A09 | Security Logging & Monitoring | PASS | `audit_logs` table for forensic trail (admin-queryable); Sentry breadcrumbs in 5 critical flows; postgres slow-log (Spec G C); stack traces stripped in production |
| A10 | SSRF | PASS (1 P3) | No user-supplied URL ever fetched server-side; see A10 detail |

---

## Detailed findings

### A01 — Broken Access Control

Every store-scoped controller carries `@UseGuards(JwtAuthGuard, StoreAccessGuard)` at minimum. Controllers with write operations additionally carry `PermissionsGuard` + `@Permissions(...)`:

- `products.controller.ts:35` — `JwtAuthGuard, StoreAccessGuard, PermissionsGuard`
- `sales.controller.ts:15` — `JwtAuthGuard, StoreAccessGuard, PermissionsGuard`
- `expenses.controller.ts:16` — `JwtAuthGuard, StoreAccessGuard, PermissionsGuard`

Controllers using only `JwtAuthGuard + StoreAccessGuard` (no `PermissionsGuard`):

| Controller | Justification |
|------------|---------------|
| `customers.controller.ts:12` | All staff roles can view/record customer debts; no sub-permission needed. Consistent with Sprint C matrix. |
| `suppliers.controller.ts:12` | Same pattern — supplier CRUD access scoped to authenticated store members. |
| `shifts.controller.ts:12` | Shift read/write available to all authenticated store staff. |
| `categories.controller.ts:12` | Category CRUD treated as general store data. |
| `finances.controller.ts:11` | Finance overview read-only aggregation per store. |
| `subscriptions.controller.ts:54` | Owner-level subscription actions; second controller at `:135` uses `AdminGuard`. |

**P3 informational — currencies endpoints unauthenticated:**
`currencies.controller.ts` has no guards at all. Three endpoints (`GET /rates`, `GET /rates/history`, `POST /rates/fetch`) are publicly reachable without a JWT. Flagged in Sprint C audit (2026-05-06) as likely intentional (mobile app fetches exchange rates before login) but never formally documented in code or resolved.

`POST /rates/fetch` triggers an outbound HTTP call to `https://nbt.tj/en/` (hardcoded URL). An unauthenticated caller can invoke it repeatedly; the global throttler (300/min) is the only rate-limit defense. Recommend: add `@UseGuards(JwtAuthGuard)` to `POST /rates/fetch`, or a dedicated `@Throttle` decorator, and document the GET endpoints as intentionally public in the OpenAPI description.

---

### A02 — Cryptographic Failures

bcrypt rounds=12 confirmed at all six password hash sites:

```
auth/auth.service.ts:38    bcrypt.hash(dto.password, 12)
auth/auth.service.ts:75    bcrypt.compare(dto.password, user.password)
auth/auth.service.ts:175   bcrypt.hash(newPassword, 12)
users/users.service.ts:60  bcrypt.compare(currentPassword, user.password)
users/users.service.ts:64  bcrypt.hash(newPassword, 12)
staff/staff.service.ts:45  bcrypt.hash(randomPassword, 12)
```

No MD5 or SHA1 found. JWT secrets validated at boot via `validate-config.ts` with placeholder-set detection, 32-char minimum, and access≠refresh enforcement. Sentry `sendDefaultPii: false` + `beforeSend: scrubEventPii` confirmed (`sentry.ts:25–26`).

---

### A03 — Injection

```bash
$ grep -rn "\$queryRaw\|\$executeRaw" api/src/
(no output)
```

Zero raw SQL. All database access via Prisma typed query builder. PASS.

---

### A04 — Insecure Design (money integrity)

localId idempotency verified across all six financial write paths:

| Module | File:line | Check pattern |
|--------|-----------|---------------|
| Sale | `sales/sales.service.ts:46` | `where: { storeId, localId: dto.localId }` |
| StockMovement | `products/stock-movements.service.ts:19` | `where: { localId: dto.localId }` |
| DebtPayment | `customers/customers.service.ts:151` | `where: { localId: dto.localId, sale: { storeId, customerId } }` |
| SupplierPayment | `suppliers/suppliers.service.ts:101` | `where: { storeId_localId: { storeId, localId: dto.localId } }` |
| ZakatPayment | `zakat/zakat.service.ts:278` | `where: { storeId_localId: { storeId, localId: dto.localId } }` |
| Investment | `investments/investments.service.ts:23` | `where: { storeId_localId: { storeId, localId: dto.localId } }` |

DTO-level `@Min` guards confirmed on all payment amount fields (`@Min(0.01)` for payments; `@Min(0)` for prices, costs, quantities).

---

### A05 — Security Misconfiguration

`validate-config.ts` throws on startup if:
- `JWT_ACCESS_SECRET` or `JWT_REFRESH_SECRET` is empty, shorter than 32 chars, or matches the known-placeholder set (includes `'access-secret-dev'`, `'dukonpro-access-secret-change-in-production-32chars'`, etc.)
- `JWT_ACCESS_SECRET === JWT_REFRESH_SECRET`
- `NODE_ENV=production` and `CORS_ORIGIN` is empty or `*`

Only two `||` fallbacks in source — both benign (non-secrets):
- `otel.ts:16` — `process.env.OTEL_SERVICE_NAME || 'dukon-api'` (telemetry label)
- `sentry.ts:7` — `process.env.NODE_ENV || 'development'` (environment label)

Helmet at `main.ts:47` with explicit CSP/HSTS overrides. PASS.

---

### A06 — Vulnerable Components (PARTIAL — P2 carried from Spec F C.1)

18 npm advisories across 4 dependency trees. No new advisories since Spec F C.1 (2026-05-16). Full table in `qa/2026-05-16-deps-audit/REPORT.md`.

| Tree | Direct dep | Top severity | Count | Mitigation |
|------|-----------|-------------|-------|------------|
| 1 | `firebase-admin@11.x` | low | 8 | Upgrade to 12+ tracked |
| 2 | `node-telegram-bot-api@0.67.0` | critical × 2 (SSRF in `request`; unsafe random in `form-data`) | 7 | Reachable only via outbound to `api.telegram.org`; no untrusted URL input. Library swap (grammy/Telegraf) tracked. |
| 3 | `bcrypt@5.1.1` → `tar@6` | high | 2 | Install-time only; production runtime unaffected. `bcrypt@6` upgrade tracked. |
| 4 | `xlsx@0.18.5` | high | 1 | No npm fix available; size-capped uploads + class-validator mitigates ReDoS surface. `exceljs` migration tracked. |

---

### A07 — Identification & Authentication Failures

Per-endpoint throttle decorators on all auth routes (`auth.controller.ts`):

```
:29   @Throttle({ default: { limit: 3,  ttl: 60000 } })  // register
:37   @Throttle({ default: { limit: 5,  ttl: 60000 } })  // login
:45   @Throttle({ default: { limit: 10, ttl: 60000 } })  // refresh
:79   @Throttle({ default: { ttl: 60000, limit: 3 } })   // request-otp
:87   @Throttle({ default: { ttl: 60000, limit: 5 } })   // verify-otp
:95   @Throttle({ default: { ttl: 60000, limit: 3 } })   // request-password-reset
:103  @Throttle({ default: { ttl: 60000, limit: 3 } })   // reset-password
```

Token revocation active in both strategies:
- `jwt-access.strategy.ts:42` — `payload.iat` (sec) vs `tokensRevokedAt` (ms, floor-converted)
- `jwt-refresh.strategy.ts:41` — same pattern

Password minimum 6 chars via `@MinLength(6)` in reset DTO. PASS.

---

### A08 — Software & Data Integrity Failures

`AuditLogService` injected and active in:
- `sales/sales.service.ts` (refund path)
- `customers/customers.service.ts` (debt payment)
- `stores/stores.service.ts` (subscription events)

`AuditLogModule` registered globally in `app.module.ts:52`. Admin-queryable via `AdminAuditLogController` (gated by `AdminGuard`). Idempotency keys (localId) prevent duplicate financial records on retry. PASS.

---

### A09 — Security Logging & Monitoring

- `audit_logs` Prisma table populated on all critical financial write paths.
- Sentry `sendDefaultPii: false` + `beforeSend: scrubEventPii` (`sentry.ts:25–26`).
- Production filter (`http-exception.filter.ts:14`) — `isProduction = process.env.NODE_ENV === 'production'` — suppresses stack traces in error responses.
- Postgres slow-log referenced in Spec G C (infrastructure config, not in source tree).

PASS.

---

### A10 — SSRF

Grep for user-supplied URL fields:

```
products/dto/create-product.dto.ts:85    imageUrl?: string   — stored to DB only
products/products.service.ts:61           imageUrl: dto.imageUrl — DB write, never fetched
sales/sales.service.ts:382                product.imageUrl — read from DB for response, never fetched
```

No `axios`, `fetch(`, `http.get`, or `http.post` calls found anywhere in `api/src/` (grep returned zero results).

The only outbound HTTP in the codebase:

| Location | Target URL | URL origin |
|----------|-----------|-----------|
| `currencies/currencies.service.ts:78` | `https://nbt.tj/en/` | Hardcoded — not user-supplied |
| `telegram/telegram.service.ts` via `node-telegram-bot-api` | `https://api.telegram.org/` | Hardcoded SDK — not user-supplied |

**P3 informational:** `POST /api/currencies/rates/fetch` is unauthenticated and causes the server to fetch `nbt.tj`. This is not SSRF (hardcoded target, no user input redirects the URL), but it is an unauthenticated endpoint that triggers an external network call. See A01 recommendation.

PASS — no SSRF surface identified.

---

## Recommendations (prioritised)

1. **(P3 — low effort)** Add `@UseGuards(JwtAuthGuard)` to `POST /rates/fetch` in `currencies.controller.ts` (`api/src/modules/currencies/currencies.controller.ts:19`). Document GET endpoints as intentionally public in OpenAPI `@ApiOperation` summary.
2. **(P2 — next sprint)** Swap `node-telegram-bot-api` for grammy or Telegraf — closes 7 advisories including 2 critical in the `request` dependency tree.
3. **(P2)** `firebase-admin` 11 → 12+ — closes 8 low advisories.
4. **(P2)** `bcrypt` 5 → 6 — closes 2 high advisories in `tar@6`; requires CI prebuild verification across Linux glibc/Alpine/macOS arm64.
5. **(infra)** Confirm Cloudflare/WAF in front of API for additional DDoS protection on unauthenticated currencies endpoints and general A10/DDoS coverage.
6. **(future)** Consider Sentry alert rule: errors tagged `category: sales` or `subscription.approve` failures → on-call page (referenced in Spec G SECURITY.md).

## Conclusion

**0 P0 / 0 P1 findings.** 1 PARTIAL category (A06 — 18 npm advisories, all documented with mitigations in Spec F C.1, carried unchanged). 2 P3 informational items: unauthenticated `POST /rates/fetch` (A01/A10 overlap) and the unresolved currencies auth posture question from Sprint C 2026-05-06. All other nine categories PASS.
