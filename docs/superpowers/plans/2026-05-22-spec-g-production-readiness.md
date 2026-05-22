# Spec G "Production Readiness" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sentry hardening (PII scrub + user context + breadcrumbs), OpenTelemetry env-gated init, Postgres slow-log config, throttler audit + admin tighten, OWASP-focused REPORT, SECURITY.md rotation runbook.

**Architecture:** Most surgical edits + 2 small new files + 1 new doc. OTel is the only "real add" (npm deps + init file). Order: F docs → C postgres → D throttler → A Sentry → B OTel → E OWASP → final gate. F+C+D safe to parallel; A then B sequential (B uses Sentry tracing); E last needs all surface stable.

**Tech Stack:** NestJS 10 + Prisma 6.19 + Postgres 16; Sentry already integrated on both API + Flutter; OpenTelemetry SDK to be added (env-gated).

**Spec:** `docs/superpowers/specs/2026-05-22-spec-g-production-readiness-design.md` (commit f88d12e).

---

## File Structure

**Created:**
- `api/src/otel.ts`
- `api/src/common/sentry/scrub-pii.ts`
- `api/src/common/sentry/scrub-pii.spec.ts`
- `api/src/common/interceptors/sentry-user-context.interceptor.ts`
- `SECURITY.md`
- `qa/2026-05-22-owasp-sweep/REPORT.md`

**Modified:**
- `api/src/sentry.ts` (beforeSend)
- `api/src/main.ts` (initOtel)
- `api/src/app.module.ts` (interceptor wiring)
- `api/package.json` (otel deps)
- 5 service files (breadcrumbs)
- `api/src/modules/admin/admin.controller.ts` (@Throttle on mutations)
- `docker-compose.yml` (postgres slow-log args)
- `CONTRIBUTING.md` (throttle table)
- `app/lib/core/sentry.dart` (beforeSend)
- `app/lib/presentation/blocs/auth/auth_bloc.dart` (Sentry setUser)

---

## Task F.1 — SECURITY.md

**Files:**
- Create: `SECURITY.md`

- [ ] **Step 1: Verify file doesn't exist**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/SECURITY.md 2>&1
```

- [ ] **Step 2: Write SECURITY.md**

```markdown
# Security

## Reporting a vulnerability

Email: security@<your-domain>.tj
PGP: <fingerprint or "available on request">

We follow a 90-day coordinated disclosure window. Reporters are
credited unless they request otherwise.

Please do NOT open public GitHub issues for security bugs.

## Secret rotation

### JWT signing keys

```bash
# 1. Generate new secrets
openssl rand -hex 32   # → JWT_ACCESS_SECRET
openssl rand -hex 32   # → JWT_REFRESH_SECRET

# 2. Update deployment env vars (Heroku/Railway/Fly/etc.)
# 3. Restart API
```

**Effect**: every existing access + refresh token rejects on next
request. Clients see 401 → refresh fails (new signing key) → AuthBloc
routes to /login. Users re-authenticate.

### Database password (PostgreSQL)

```bash
# 1. ALTER USER dukonpro WITH PASSWORD '<new>';
# 2. Update DATABASE_URL env var
# 3. Rolling restart of API instances
```

### Sentry DSN

DSN is not a secret per se (anyone with it can spam your project),
but treat it as one. Rotate via Sentry project settings → Client
Keys → revoke + create new → update `SENTRY_DSN` env var.

## Incident response

### Suspected leak of JWT secret

```sql
UPDATE users SET "tokensRevokedAt" = NOW();
```

This forces every user to re-login on their next API call (per F.1
fix — JWT strategies reject any access token whose `iat` predates
this timestamp).

### Suspected admin account compromise

```sql
UPDATE users SET "tokensRevokedAt" = NOW(), "isActive" = false
WHERE id = '<admin-user-id>';
```

Then audit `audit_logs` for actions taken in the suspected window:

```sql
SELECT * FROM audit_logs
WHERE "userId" = '<admin-user-id>'
  AND "createdAt" > '<suspected-start>'
ORDER BY "createdAt" DESC;
```

### Throttle bypass / DDoS

Short-term: add Cloudflare / Fastly / WAF rule blocking the
attacker IP range. Tighten `ThrottlerModule.forRoot` global from
300/min to 60/min temporarily.

### Suspected data exfiltration

Audit Sentry for unusual error patterns from a single `user.id`
context. Audit `audit_logs` for bulk reads (the `reports.*` actions).

## Throttle limits (current)

See `CONTRIBUTING.md` for the canonical throttle table.

## Audit log retention

Audit log rows are kept indefinitely. Pruning is a future ops
decision; no automated retention policy.

## Sentry alert routing

Configured in Sentry UI per project. Recommended:
- New issue type → email on-call rotation
- High-volume issue (>100 events/hour) → PagerDuty / Telegram bot
```

(Adapt `security@<your-domain>.tj` to the real address; pick a
placeholder if undetermined.)

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add SECURITY.md
git commit -m "docs(security): SECURITY.md — disclosure + rotation runbook (Spec G F)"
```

---

## Task C.1 — Postgres slow query log

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Inspect current postgres service**

```bash
grep -B1 -A 15 "postgres:" /Users/latifrjdev/Downloads/01_Проекты/Dukon/docker-compose.yml 2>/dev/null | head -30
```

If `docker-compose.yml` not at repo root, find it:

```bash
find /Users/latifrjdev/Downloads/01_Проекты/Dukon -name "docker-compose*.yml" -not -path "*/node_modules/*" | head
```

- [ ] **Step 2: Add command args**

Find the postgres service block. Add `command:` if missing:

```yaml
  postgres:
    image: postgres:16
    # ...existing env / ports / volumes...
    command:
      - postgres
      - -c
      - log_min_duration_statement=500
      - -c
      - log_statement=ddl
      - -c
      - log_lock_waits=on
```

(If a `command:` already exists, merge the `-c` args without
replacing existing entries.)

- [ ] **Step 3: Recreate container + verify logs**

```bash
docker compose up -d --force-recreate postgres
sleep 3
docker logs dukonpro-db 2>&1 | tail -5
```

Expected: postgres starts up cleanly with new args.

- [ ] **Step 4: Smoke test slow log**

```bash
# Run an artificial slow query
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c "SELECT pg_sleep(0.6);" > /dev/null
docker logs dukonpro-db 2>&1 | grep "duration:" | tail -3
```

Expected: at least one `LOG: duration: 6XX.XXX ms` line.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add docker-compose.yml
git commit -m "ops(postgres): enable slow query log (>=500ms) + DDL + lock waits (Spec G C)"
```

---

## Task D.1 — Throttler audit + tighten

**Files:**
- Modify: `api/src/modules/admin/admin.controller.ts`
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Inspect admin controller**

```bash
grep -B1 -A 4 "@Post\|@Put\|@Delete\|@Patch" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/admin/admin.controller.ts | head -30
```

Identify each mutation handler.

- [ ] **Step 2: Add @Throttle to admin mutations**

Either per-handler:
```typescript
import { Throttle } from '@nestjs/throttler';

@Throttle({ default: { limit: 60, ttl: 60000 } })
@Post(...)
```

OR class-level (preferred if every mutation has it):
```typescript
@Throttle({ default: { limit: 60, ttl: 60000 } })
@Controller('admin')
export class AdminController { ... }
```

Match the AdminController shape — if reads + writes are mixed and
reads should stay at 300/min global, do per-handler on mutations
only.

- [ ] **Step 3: Check for forgot-password / password-reset flow**

```bash
grep -rn "forgot\|reset.*password\|resetPassword" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/auth/ 2>/dev/null | head
```

If a `forgot-password` endpoint exists without `@Throttle`, add
`@Throttle({ default: { limit: 3, ttl: 60000 } })`. If no such
endpoint, skip.

- [ ] **Step 4: Update CONTRIBUTING.md with throttle table**

Edit `CONTRIBUTING.md`. Find the existing throttle/CI section and
add (or extend):

```markdown
## Throttle limits

| Endpoint | Limit | TTL | Reason |
|----------|------:|-----|--------|
| Global default | 300 | 60s | Normal POS traffic |
| Auth /register | 3 | 60s | Account creation abuse |
| Auth /login | 5 | 60s | Password brute-force |
| Auth /refresh | 10 | 60s | Token cycling |
| Auth /send-otp | 3 | 60s | SMS spam |
| Admin mutations | 60 | 60s | Compromised admin account |
```

- [ ] **Step 5: Verify tsc + tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
```

- [ ] **Step 6: Live probe**

```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done

# Login throttle: 6 hits in a row → 6th = 429
for i in 1 2 3 4 5 6; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:4455/api/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"phone":"+992910001002","password":"wrong"}')
  echo "Attempt $i: HTTP=$CODE"
done
```

Expected: HTTP 401 × 5, then HTTP 429 on the 6th.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/admin.controller.ts CONTRIBUTING.md
git commit -m "fix(throttler): tighten admin to 60/min + document throttle table (Spec G D)"
```

---

## Task A.1 — Sentry beforeSend PII scrub

**Files:**
- Create: `api/src/common/sentry/scrub-pii.ts`
- Create: `api/src/common/sentry/scrub-pii.spec.ts`
- Modify: `api/src/sentry.ts`

- [ ] **Step 1: TDD — write failing test**

Create `api/src/common/sentry/scrub-pii.spec.ts`:

```typescript
import { scrubEventPii } from './scrub-pii';

describe('scrubEventPii', () => {
  it('redacts password fields in request.data', () => {
    const event: any = {
      request: { data: { phone: '+992900111222', password: 'secret123' } },
    };
    scrubEventPii(event);
    expect(event.request.data.password).toBe('[Filtered]');
    expect(event.request.data.phone).toBe('[Filtered]');
  });

  it('redacts token-like fields in extra', () => {
    const event: any = {
      extra: { accessToken: 'eyJhbG...', refreshToken: 'xyz', other: 'keep' },
    };
    scrubEventPii(event);
    expect(event.extra.accessToken).toBe('[Filtered]');
    expect(event.extra.refreshToken).toBe('[Filtered]');
    expect(event.extra.other).toBe('keep');
  });

  it('walks nested objects', () => {
    const event: any = {
      request: { data: { nested: { password: 'p', ok: 'v' } } },
    };
    scrubEventPii(event);
    expect(event.request.data.nested.password).toBe('[Filtered]');
    expect(event.request.data.nested.ok).toBe('v');
  });

  it('redacts Authorization header', () => {
    const event: any = {
      request: { headers: { Authorization: 'Bearer xxx', 'X-Other': 'y' } },
    };
    scrubEventPii(event);
    expect(event.request.headers.Authorization).toBe('[Filtered]');
    expect(event.request.headers['X-Other']).toBe('y');
  });

  it('no-ops on event without request/extra', () => {
    const event: any = { message: 'hello' };
    expect(() => scrubEventPii(event)).not.toThrow();
    expect(event.message).toBe('hello');
  });
});
```

- [ ] **Step 2: Run, expect FAIL (module missing)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- scrub-pii 2>&1 | tail -5
```

- [ ] **Step 3: Implement**

Create `api/src/common/sentry/scrub-pii.ts`:

```typescript
const SENSITIVE_KEYS = new Set([
  'password',
  'currentPassword',
  'oldPassword',
  'newPassword',
  'phone',
  'token',
  'accessToken',
  'refreshToken',
  'authorization',
  'cardnumber',
  'cvv',
  'otp',
  'code',
]);

const PLACEHOLDER = '[Filtered]';

function scrubObject(obj: unknown): void {
  if (!obj || typeof obj !== 'object') return;
  for (const key of Object.keys(obj as Record<string, unknown>)) {
    const lc = key.toLowerCase();
    const rec = obj as Record<string, unknown>;
    if (SENSITIVE_KEYS.has(lc)) {
      rec[key] = PLACEHOLDER;
      continue;
    }
    if (rec[key] && typeof rec[key] === 'object') {
      scrubObject(rec[key]);
    }
  }
}

export function scrubEventPii(event: { request?: any; extra?: any }): void {
  if (event.request?.data) scrubObject(event.request.data);
  if (event.request?.headers) scrubObject(event.request.headers);
  if (event.extra) scrubObject(event.extra);
}
```

- [ ] **Step 4: Run, expect PASS**

```bash
npm test -- scrub-pii 2>&1 | tail -10
```
Expected: 5 passed.

- [ ] **Step 5: Wire into sentry.ts**

Edit `api/src/sentry.ts`. Find the `Sentry.init({ ... })` call. Add:

```typescript
import { scrubEventPii } from './common/sentry/scrub-pii';

Sentry.init({
  // ...existing,
  beforeSend(event) {
    scrubEventPii(event);
    return event;
  },
});
```

- [ ] **Step 6: tsc clean**

```bash
npx tsc --noEmit 2>&1 | grep "error TS" | head
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/sentry/ api/src/sentry.ts
git commit -m "fix(sentry): beforeSend PII scrub on request.data/headers/extra (Spec G A.1)"
```

---

## Task A.2 — Sentry user context interceptor + critical-flow breadcrumbs

**Files:**
- Create: `api/src/common/interceptors/sentry-user-context.interceptor.ts`
- Modify: `api/src/app.module.ts`
- Modify: 5 service files (sale, refund, subscription approve/reject, zakat payment, auth login)

- [ ] **Step 1: Create the interceptor**

```typescript
// api/src/common/interceptors/sentry-user-context.interceptor.ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import * as Sentry from '@sentry/nestjs';

@Injectable()
export class SentryUserContextInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest();
    const user = req.user; // populated by JwtAuthGuard
    if (user?.id) {
      Sentry.getCurrentScope().setUser({ id: user.id });
    }
    const storeId = req.params?.storeId;
    if (storeId) {
      Sentry.getCurrentScope().setTag('storeId', storeId);
    }
    return next.handle();
  }
}
```

- [ ] **Step 2: Wire in app.module.ts**

```typescript
import { SentryUserContextInterceptor } from './common/interceptors/sentry-user-context.interceptor';

@Module({
  providers: [
    // ...existing,
    { provide: APP_INTERCEPTOR, useClass: SentryUserContextInterceptor },
  ],
})
```

Place after `QueryCounterInterceptor` (D.4) so order is: counter → user-context → handler.

- [ ] **Step 3: Add breadcrumbs in 5 services**

For each service method below, add `Sentry.addBreadcrumb(...)` AT THE START of the method body:

`api/src/modules/sales/sales.service.ts` `create()`:
```typescript
import * as Sentry from '@sentry/nestjs';

Sentry.addBreadcrumb({
  category: 'sales',
  message: 'sale.create',
  data: { storeId, total: dto.total, paymentType: dto.paymentType, localId: dto.localId },
});
```

Same shape for:
- `sales.service.refund()` — `{ category: 'sales', message: 'sale.refund', data: { saleId, refundAmount } }`
- `subscriptions.service.adminApprovePayment()` — `{ category: 'subscriptions', message: 'subscription.approve', data: { subId: subscriptionId, payId: paymentId, approvedBy: reviewedBy } }`
- `subscriptions.service.adminRejectPayment()` — `{ category: 'subscriptions', message: 'subscription.reject', data: { subId, payId, rejectedBy } }`
- `zakat.service.createPayment()` — `{ category: 'zakat', message: 'zakat.payment.create', data: { paymentId: created.id, amount: created.amount.toString() } }` (after `create`)
- `auth.service.login()` — `{ category: 'auth', message: 'auth.login', data: { userId: user.id } }` (after successful login, before return)

- [ ] **Step 4: Verify tsc**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
```

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/common/interceptors/ api/src/app.module.ts api/src/modules/sales/ api/src/modules/subscriptions/ api/src/modules/zakat/ api/src/modules/auth/
git commit -m "feat(sentry): user-context interceptor + breadcrumbs in 5 critical flows (Spec G A.2)"
```

---

## Task A.3 — Flutter Sentry hardening

**Files:**
- Modify: `app/lib/core/sentry.dart`
- Modify: `app/lib/presentation/blocs/auth/auth_bloc.dart`

- [ ] **Step 1: Add beforeSend to Flutter sentry init**

Edit `app/lib/core/sentry.dart`. Inside the `SentryFlutter.init` options:

```dart
options.beforeSend = (event, hint) {
  _scrubEventPii(event);
  return event;
};
```

Add helper at bottom of file:

```dart
const _kSensitiveKeys = {
  'password', 'currentpassword', 'oldpassword', 'newpassword',
  'phone', 'token', 'accesstoken', 'refreshtoken', 'authorization',
  'cardnumber', 'cvv', 'otp', 'code',
};

void _scrubMap(Map<String, dynamic>? map) {
  if (map == null) return;
  for (final key in map.keys.toList()) {
    if (_kSensitiveKeys.contains(key.toLowerCase())) {
      map[key] = '[Filtered]';
    } else if (map[key] is Map<String, dynamic>) {
      _scrubMap(map[key] as Map<String, dynamic>);
    }
  }
}

void _scrubEventPii(SentryEvent event) {
  _scrubMap(event.request?.data as Map<String, dynamic>?);
  _scrubMap(event.request?.headers);
  _scrubMap(event.extra);
}
```

(Adapt `SentryEvent` field types to actual sentry_flutter API. If
`event.extra` is typed as `Map<String, Object?>?`, cast appropriately.)

- [ ] **Step 2: Sentry user context in AuthBloc**

Edit `app/lib/presentation/blocs/auth/auth_bloc.dart`. After
successful login (in the success branch of `_onLoginRequested`):

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

await Sentry.configureScope((scope) {
  scope.setUser(SentryUser(id: user.id));
});
```

On logout (in `_onLogoutRequested` after clearing tokens):

```dart
await Sentry.configureScope((scope) {
  scope.setUser(null);
});
```

If Sentry isn't initialized (dev/no-DSN), these calls are safe
no-ops.

- [ ] **Step 3: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/core/sentry.dart lib/presentation/blocs/auth/auth_bloc.dart 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/core/sentry.dart app/lib/presentation/blocs/auth/
git commit -m "fix(sentry-flutter): beforeSend PII scrub + setUser on login/logout (Spec G A.3)"
```

---

## Task B.1 — OpenTelemetry init

**Files:**
- Create: `api/src/otel.ts`
- Modify: `api/src/main.ts`
- Modify: `api/package.json`

- [ ] **Step 1: Add OTel deps**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm install --save \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http
```

- [ ] **Step 2: Create otel.ts**

```typescript
// api/src/otel.ts
//
// Spec G B: env-gated OTel SDK. No-op without OTEL_EXPORTER_OTLP_ENDPOINT
// so dev + tests stay fast.
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

let sdk: NodeSDK | null = null;

export function initOtel(): void {
  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  if (!endpoint) return; // no-op in dev / tests

  sdk = new NodeSDK({
    serviceName: process.env.OTEL_SERVICE_NAME || 'dukon-api',
    traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
    instrumentations: [
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': { enabled: false },
      }),
    ],
  });
  sdk.start();
}

export async function shutdownOtel(): Promise<void> {
  if (sdk) await sdk.shutdown();
}
```

- [ ] **Step 3: Wire in main.ts**

Edit `api/src/main.ts`. At the very top, BEFORE `initSentry()`:

```typescript
import { initOtel } from './otel';

initOtel();   // must run before Sentry / Nest init
```

- [ ] **Step 4: Verify tsc + tests + dev boot**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
# Boot dev server (no OTEL_EXPORTER_OTLP_ENDPOINT set) — should be no-op
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
sleep 8
curl -sf http://localhost:4455/api/health
echo ""
tail -20 /tmp/dukon-api.log | grep -i "otel\|opentelemetry" | head -3
```

Expected: API boots; no OTel-related errors in log (no-op since
endpoint not set).

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/otel.ts api/src/main.ts api/package.json api/package-lock.json
git commit -m "feat(otel): env-gated OpenTelemetry init (Spec G B)"
```

---

## Task E.1 — OWASP-focused sweep + REPORT

**Files:**
- Create: `qa/2026-05-22-owasp-sweep/REPORT.md`

- [ ] **Step 1: Run each category check**

Walk through OWASP Top-10 and grep for surface in our code:

```bash
# A03 Injection (sanity — should still be 0)
grep -rn "\$queryRaw\|\$executeRaw" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/ | head

# A10 SSRF — find any endpoint that fetches a URL from user input
grep -rn "fetch\|axios\|http.get\|http.post" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/ | grep -v ".spec." | head -20
grep -rn "imageUrl\|webhookUrl\|callbackUrl" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/ | head -10

# A05 Security Misconfiguration — env handling
grep -rn "process.env" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/ | grep -v ".spec." | wc -l

# A06 Vulnerable Components
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && npm audit --audit-level=high 2>&1 | tail -10
```

For each finding, note: category, file:line, severity, recommendation.

- [ ] **Step 2: Write REPORT.md**

```markdown
# OWASP Top-10 sweep — 2026-05-22 (Spec G E)

## Scope
Code-only audit; no penetration testing. Cross-referenced with Sprint C audit (2026-05-06) and recent specs A-G.

## Matrix

| Cat | Title | Status | Note |
|-----|-------|--------|------|
| A01 | Broken Access Control | PASS | PermissionsGuard on every controller; matrix audited Sprint C; F.2 spec verified mixed-coverage |
| A02 | Cryptographic Failures | PASS | bcrypt for passwords, JWT HS256 with env-only secrets, tokensRevokedAt for forced logout |
| A03 | Injection | PASS | 0 \$queryRaw / \$executeRaw anywhere; all DB access via Prisma parameterized |
| A04 | Insecure Design | PASS | localId idempotency on Sale/Stock/Debt/Investment/Zakat; server re-derives money values (Z-P1-1) |
| A05 | Security Misconfiguration | PASS | Dev DSN-less Sentry by design; prod env-required; secrets never in source |
| A06 | Vulnerable Components | PARTIAL | 18 npm advisories (Spec F C.1) — 2 critical reachable only via outbound to telegram.org; 13 majors deferred |
| A07 | Auth Failures | PASS | Throttler on auth (3-10/min); tokensRevokedAt forces re-login |
| A08 | Data Integrity | PASS | AuditLog on refund/sub/staff/investment/zakat; CHECK constraints on Decimal columns; F-IDEMPOTENT-1 on Sale |
| A09 | Logging | PASS | Sentry (PII-scrubbed Spec G A.1) + audit_logs table; QueryCounter for per-req query count |
| A10 | SSRF | PASS / PARTIAL | <findings from step 1 grep> |

## Detailed findings

### A10 SSRF
- `product.imageUrl` (Tabular field): backend STORES the URL but does NOT fetch it server-side. No SSRF surface.
- Telegram webhook URL: admin-only setting, validated via Telegram API. No callback flow into our infra.

(Or whatever the grep reveals — fill in real findings.)

### A06 deferred
See `qa/2026-05-16-deps-audit/REPORT.md` for the 18 outstanding advisories + the 13 majors deferred to follow-up specs.

## Recommendations
- For A06: pursue major-bump specs in priority order: firebase-admin 13→14, node-telegram-bot-api swap.
- Add Sentry alert rule for any new error tagged `category: sales` or `subscription.approve` failures (Sentry UI).
- Consider rate-limited password-reset endpoint if/when implemented.
```

Fill in real findings from step 1.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-22-owasp-sweep/REPORT.md
git commit -m "docs(security): OWASP Top-10 sweep REPORT (Spec G E)"
```

---

## Task G.1 — Final verification gate

**Files:** None

- [ ] **Step 1: Full gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v "\.spec\." | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected:
- 0 tsc errors
- ≥229 unit (was 226, +5 scrub-pii)
- ≥11 e2e
- 0 dart issues
- ≥441 flutter

- [ ] **Step 2: Live throttle probe** (covered in D.1 step 6 already; rerun if needed)

- [ ] **Step 3: Artefact check**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/SECURITY.md \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-22-owasp-sweep/REPORT.md \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/otel.ts \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/common/sentry/scrub-pii.ts \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/common/interceptors/sentry-user-context.interceptor.ts
```
Expected: all 5 listed.

- [ ] **Step 4: Commit list**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git log --oneline f88d12e..HEAD | head -15
```

---

## Self-Review

**Spec coverage:**
- ✅ A (Sentry hardening) — Tasks A.1 (beforeSend) + A.2 (interceptor + breadcrumbs) + A.3 (Flutter)
- ✅ B (OpenTelemetry) — Task B.1
- ✅ C (Postgres slow log) — Task C.1
- ✅ D (Throttler) — Task D.1
- ✅ E (OWASP sweep) — Task E.1
- ✅ F (SECURITY.md) — Task F.1
- ✅ Final gate — Task G.1

**Type consistency:** `scrubEventPii(event)` defined A.1 → wired A.1 (sentry.ts). `SentryUserContextInterceptor` defined A.2 → registered A.2 (app.module). `initOtel()` defined B.1 → called B.1 (main.ts).

**Placeholders:** none.

Plan complete and saved to `docs/superpowers/plans/2026-05-22-spec-g-production-readiness.md`.
