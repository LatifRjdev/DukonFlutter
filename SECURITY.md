# Security

## Reporting a vulnerability

Email: security@dukonpro.tj
PGP: available on request.

We follow a 90-day coordinated disclosure window. Reporters are credited unless they request otherwise.

Please do NOT open public GitHub issues for security bugs.

## Secret rotation

### JWT signing keys

```bash
# 1. Generate new secrets
openssl rand -hex 32   # → JWT_ACCESS_SECRET
openssl rand -hex 32   # → JWT_REFRESH_SECRET

# 2. Update deployment env vars
# 3. Restart API
```

**Effect**: every existing access + refresh token rejects on next request. Clients see 401 → refresh fails (new signing key) → AuthBloc routes to /login. Users re-authenticate.

### Database password (PostgreSQL)

```sql
ALTER USER dukonpro WITH PASSWORD '<new>';
```

Then update `DATABASE_URL` env var and roll the API instances.

### Sentry DSN

Rotate via Sentry project settings → Client Keys → revoke + create new → update `SENTRY_DSN` (API) and `SENTRY_DSN_MOBILE` (Flutter `--dart-define`).

## Incident response

### Suspected JWT secret leak

```sql
UPDATE users SET "tokensRevokedAt" = NOW();
```

This forces every user to re-login on their next API call (per F.1 — JWT strategies reject any access token whose `iat` predates this timestamp).

### Suspected admin account compromise

```sql
UPDATE users SET "tokensRevokedAt" = NOW(), "isActive" = false
WHERE id = '<admin-user-id>';

-- Audit trail
SELECT * FROM audit_logs
WHERE "userId" = '<admin-user-id>'
  AND "createdAt" > '<suspected-start>'
ORDER BY "createdAt" DESC;
```

### Throttle bypass / DDoS

Short-term: WAF/Cloudflare rule blocking attacker IP range. Tighten `ThrottlerModule.forRoot` global from 300/min → 60/min temporarily; redeploy.

### Suspected data exfiltration

Audit Sentry for unusual error patterns from a single `user.id` context. Audit `audit_logs` for bulk reads (action like `reports.*`).

## Throttle limits

Canonical table lives in `CONTRIBUTING.md` → "Throttle limits" section.

## Audit log retention

Indefinite. Pruning policy is a future ops decision; no automated retention.

## Sentry alert routing

Configured in Sentry UI per project. Recommended:

- New issue type → email on-call rotation
- High-volume issue (>100 events/hour) → PagerDuty / Telegram bot
- Errors tagged `category: sales` or `subscription.approve` failure → immediate

## Backups

PostgreSQL daily snapshot retained 30 days. Restore procedure documented separately in ops-runbook (not in repo).
