# Design — Spec G "Production Readiness"

**Date:** 2026-05-22
**Scope:** Sentry hardening (audit + extend, NOT add-from-scratch),
OpenTelemetry latency (real add), Postgres slow query log config,
throttler audit + tighten, OWASP-focused sweep, JWT rotation
runbook.
**Decisions:** auto-mode picks based on reality check; major prior
assumptions corrected.

## Summary

Context-reset findings:
- **Sentry**: fully integrated on both API + Flutter with `sendDefaultPii: false`, env-gated DSN, 10% prod tracing
- **Throttler**: global 300/min + per-endpoint on auth (register 3/min, login 5/min, refresh 10/min, OTP 3/min)
- **`$queryRaw`**: 0 usages anywhere (D.4 memory was stale — already cleared)

Real scope is narrower than initially planned: ~1.5 days, mostly
audit + extend. OTel is the only big add. Postgres slow log is
config-only. JWT rotation is docs.

## Sub-section A — Sentry hardening

### Problem

Both Sentry SDKs ship with `sendDefaultPii: false`, but neither
has a `beforeSend` hook to scrub PII from custom request payload
captures. Authenticated requests get no user context (Sentry can't
tie an error to a merchant). Critical money-flow operations (sale,
refund, subscription approve) don't emit breadcrumbs, so
post-mortem is blind.

### Fix

**API `api/src/sentry.ts`:**

Add `beforeSend` hook that walks request body / additional context
and scrubs sensitive keys:
- `password`, `currentPassword`, `oldPassword`, `newPassword`
- `phone` (Tajik numbers are PII)
- `token`, `accessToken`, `refreshToken`, `authorization`
- `cardNumber`, `cvv` (we don't accept cards but defense-in-depth)
- `otp`, `code` (when in auth context)

```typescript
beforeSend(event) {
  scrubEventPii(event);   // walks event.request.data + extra
  return event;
}
```

**API `api/src/common/interceptors/sentry-user-context.interceptor.ts` (new):**

NestJS interceptor that runs AFTER JwtAuthGuard and binds the
authenticated user to Sentry scope:
```typescript
Sentry.getCurrentScope().setUser({ id: user.id });
Sentry.getCurrentScope().setTag('storeId', request.params.storeId);
```

`user.id` is our own UUID, not PII. `storeId` is a tenant tag,
useful for filtering Sentry by merchant.

Wire as `APP_INTERCEPTOR` after `QueryCounterInterceptor`.

**Breadcrumbs in critical flows:**

Add `Sentry.addBreadcrumb({ category, message, data })` calls in:
- `sales.service.create` — `{ saleId, total, paymentType, localId }`
- `sales.service.refund` — `{ saleId, refundAmount }`
- `subscriptions.service.adminApprovePayment` — `{ subId, payId, approvedBy }`
- `subscriptions.service.adminRejectPayment` — same
- `zakat.service.createPayment` — `{ paymentId, amount }`
- `auth.service.login` — `{ userId, success }`

Each breadcrumb fires whether or not Sentry captures (no-op in dev).

**Flutter `app/lib/core/sentry.dart`:**

Same `beforeSend` pattern. Scrub keys list mirrors API.

After successful login (in `AuthBloc._onLoginSuccess` or equivalent):
```dart
await Sentry.configureScope((scope) {
  scope.setUser(SentryUser(id: user.id));
});
```

After logout:
```dart
await Sentry.configureScope((scope) {
  scope.setUser(null);
});
```

## Sub-section B — OpenTelemetry latency

### Problem

QueryCounter (D.4) measures per-request Prisma query count. No
latency tracking — we can't say "p95 of `POST /sales` is 230ms"
without instrumenting. Sentry tracing exists but at 10% sample
rate, no aggregations.

### Fix

**API `api/src/otel.ts` (new):**

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

export function initOtel(): void {
  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  if (!endpoint) {
    // No-op in dev without an endpoint configured.
    return;
  }

  const sdk = new NodeSDK({
    serviceName: process.env.OTEL_SERVICE_NAME || 'dukon-api',
    traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
    instrumentations: [
      getNodeAutoInstrumentations({
        // Suppress noisy fs spans
        '@opentelemetry/instrumentation-fs': { enabled: false },
      }),
    ],
  });
  sdk.start();
}
```

Wire in `api/src/main.ts` BEFORE `initSentry()` (OTel context must
exist before Sentry attaches its tracer).

**Env-gated:** `OTEL_EXPORTER_OTLP_ENDPOINT` not set → no-op. Local
dev and unit tests stay fast.

**Documentation:** README mentions OTLP-compatible backends:
- Grafana Tempo (open source)
- Honeycomb (cloud)
- SigNoz (self-hosted)
- Sentry Spotlight (local dev — local UI)

### Out of scope

- Deploying an OTLP backend. Just the API export side.
- Flutter OTel (separate SDK, separate add — not in this spec).
- Custom span instrumentation beyond auto. Add later if specific
  flows need fine-grained.

## Sub-section C — Postgres slow query log

### Fix

Edit `docker-compose.yml` (dev) — add to postgres service:

```yaml
postgres:
  image: postgres:16
  command:
    - postgres
    - -c
    - log_min_duration_statement=500
    - -c
    - log_statement=ddl
    - -c
    - log_lock_waits=on
  # ...
```

`log_min_duration_statement=500` logs any query taking ≥ 500ms.
`log_statement=ddl` logs schema changes for audit.
`log_lock_waits=on` logs when a query waits > 1s for a lock.

**Production:** document the equivalent in `SECURITY.md` (or new
`OPERATIONS.md`) — set these via Postgres configuration in whatever
managed-Postgres service we use.

**Weekly digest job:** deferred to Spec L (Background Queue).
Until then: ad-hoc query of `pg_stat_statements` by ops.

## Sub-section D — Throttler audit

### Current state (verified)

```
Global:       300 req / 60s
register:       3 req / 60s
login:          5 req / 60s
refresh:       10 req / 60s
sendOtp:        3 req / 60s
```

### Fix

**Add throttle on admin endpoints** — currently relies on global
300/min. Admin work is bursty (approve 20 payments at once) but
should not match POS traffic.

In each `admin.controller.ts` mutation handler (or class-level if
applied uniformly):
```typescript
@Throttle({ default: { limit: 60, ttl: 60000 } })
```

Tightens admin to 60/min — generous for human ops, defends against
compromised admin credential bursting.

**Verify**: forgot-password / password reset flow if exists. If
exists with high limit, tighten to 3/min same as register.

**Document** all throttle values in `CONTRIBUTING.md`:

| Endpoint | Limit | TTL | Reason |
|----------|------:|-----|--------|
| Global default | 300 | 60s | Normal POS rate |
| Auth /register | 3 | 60s | Account creation abuse |
| Auth /login | 5 | 60s | Password brute-force |
| Auth /refresh | 10 | 60s | Token cycling |
| Auth /send-otp | 3 | 60s | SMS spam |
| Admin mutations | 60 | 60s | Compromised admin |

## Sub-section E — OWASP-focused sweep

### Method

Read each Top-10 category, find spots in our code that match the
attack surface, document PASS/FAIL with note.

### Categories scanned

1. **A01 Broken Access Control**: RBAC matrix already audited (Sprint C). Verify no recent regressions: `PermissionsGuard` applied per controller, OWNER/ADMIN/CASHIER/WAREHOUSE matrix unchanged.
2. **A02 Cryptographic Failures**: passwords bcrypt, tokens HS256+rotated, no PII in logs (Sentry scrubbed).
3. **A03 Injection**: 0 `$queryRaw` (verified). All Prisma calls use parameterized queries. No string-templated SQL anywhere.
4. **A04 Insecure Design**: idempotent localId pattern protects against replay (Sale/Stock/Debt/Investment/Zakat). Server re-derives money values where client-supplied (zakat).
5. **A05 Security Misconfiguration**: dev DSN-less Sentry by design; prod requires env. JWT secrets env-only.
6. **A06 Vulnerable Components**: 18 npm advisories (Spec F C.1 documented). Critical 2 reachable only via outbound to telegram.org.
7. **A07 Auth Failures**: throttler on auth, tokensRevokedAt for forced logout, OTP rate-limited.
8. **A08 Data Integrity**: audit log on sale.refund / subscription / staff.role / investment / zakat. CHECK constraints on Decimal columns (≥0).
9. **A09 Logging**: Sentry + (new) OTel. Audit log table for forensic trail.
10. **A10 SSRF**: **The one to check carefully.** Find any endpoint that fetches a URL from user input. Likely candidates:
    - `productImageUrl` — is it just stored, or does backend ever fetch it (e.g. to generate thumbnails)?
    - Telegram webhook callback URL setting (admin-only)
    - Receipt image upload (file path stored, not fetched)

### Output

`qa/2026-05-22-owasp-sweep/REPORT.md` with the 10-row table +
findings list. Any P0/P1 finding gets inline fix (separate commit).

## Sub-section F — JWT rotation runbook

### Fix

Create `SECURITY.md` at repo root with:

1. **Reporting a vulnerability** — email + GPG key + 90-day disclosure window
2. **Secret rotation procedure** — exact commands:
   ```
   # 1. Generate new secrets
   openssl rand -hex 32   # → new JWT_ACCESS_SECRET
   openssl rand -hex 32   # → new JWT_REFRESH_SECRET
   # 2. Update deployment env (Heroku/Railway/Fly/etc.)
   # 3. Restart API
   # 4. All existing tokens reject immediately; clients see 401, refresh fails, redirect to login
   ```
3. **Incident response for suspected leak** —
   ```
   UPDATE users SET "tokensRevokedAt" = NOW();
   ```
   forces every user to re-login on next API call (per F.1 fix).
4. **Throttle bypass / DDoS** — short-term rule on infra-side (Cloudflare, deployment WAF).
5. **Critical Sentry alert routing** — config link to Sentry project settings.

## Files touched

**Created:**
- `api/src/otel.ts`
- `api/src/common/interceptors/sentry-user-context.interceptor.ts`
- `api/src/common/sentry/scrub-pii.ts` (helper used by `beforeSend`)
- `api/src/common/sentry/scrub-pii.spec.ts`
- `SECURITY.md`
- `qa/2026-05-22-owasp-sweep/REPORT.md`

**Modified:**
- `api/src/sentry.ts` — add `beforeSend` calling `scrubEventPii`
- `api/src/app.module.ts` — wire `SentryUserContextInterceptor`
- `api/src/main.ts` — call `initOtel()` before `initSentry()`
- `api/package.json` — `@opentelemetry/*` deps (env-gated, no-op without OTLP endpoint)
- `api/src/modules/sales/sales.service.ts` — breadcrumbs in `create`/`refund`
- `api/src/modules/subscriptions/subscriptions.service.ts` — breadcrumbs in admin paths
- `api/src/modules/zakat/zakat.service.ts` — breadcrumb in `createPayment`
- `api/src/modules/auth/auth.service.ts` — breadcrumb in `login`
- `api/src/modules/admin/admin.controller.ts` — `@Throttle({limit:60, ttl:60000})` on mutation paths
- `app/lib/core/sentry.dart` — add `beforeSend` PII scrub
- `app/lib/presentation/blocs/auth/auth_bloc.dart` — `Sentry.configureScope.setUser` on login/logout
- `docker-compose.yml` — postgres slow-log args
- `CONTRIBUTING.md` — throttle table

## Acceptance

- API: `npm test` ≥226 + new scrub-pii spec (≥3 cases) → ≥229.
  e2e ≥11.
- Flutter: `flutter test` ≥441 (no new tests; scrub is unit-tested
  separately if needed)
- 0 tsc errors, 0 dart issues
- `SECURITY.md` exists
- `qa/2026-05-22-owasp-sweep/REPORT.md` has 10 categories + ≥1
  finding (PASS or FAIL) per row
- Live probe: `curl /api/auth/login -d '...'` 6 times in a row →
  6th returns 429 Too Many Requests (login throttle = 5/min)
- Live probe: posting a fake payload with `password: 'secret123'`
  causes a Sentry capture; verify `event.request.data.password` is
  `[Filtered]` in Sentry UI (or in Sentry SDK debug logs)

## Out of scope

- Deploying Grafana / Tempo / SigNoz / Honeycomb (infra concern;
  the API just exports OTLP)
- Flutter OTel (separate SDK, separate spec if needed)
- WAF / Cloudflare rules (infra)
- pg_stat_statements weekly digest job (deferred to Spec L)
- External pen test
- Sentry alert rule configuration (Sentry-UI concern)

## Risks

- **OTel SDK boot overhead.** Mitigation: env-gated, no-op when
  `OTEL_EXPORTER_OTLP_ENDPOINT` unset (dev + tests stay fast).
- **Sentry breadcrumb noise.** Sentry has a 100-breadcrumb cap per
  event by default; we're adding ~5 categories. Acceptable.
- **Throttler tightening admin to 60/min could surprise.** Mitigation:
  admin bulk ops should not exceed 1/sec anyway; document.
- **`beforeSend` scrub regex** may miss novel field names. Mitigation:
  unit tests covering known shapes + new ones added as we discover.

## Test results gate

After implementation:
- API: `npm test` (≥229) + `npm run test:e2e` (≥11)
- App: `flutter test` (≥441) + `dart analyze lib/` (0)
- 0 tsc errors
- 6th `curl /api/auth/login` returns 429
- `SECURITY.md` exists, includes rotation steps + disclosure email
- OWASP REPORT has 10 categories filled in
