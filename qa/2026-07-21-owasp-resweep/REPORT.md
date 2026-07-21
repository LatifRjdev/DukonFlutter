# OWASP Top-10 re-sweep — 2026-07-21

## Scope

Code-only re-audit of `api/src/`, re-running the same A01–A10 scope as
`qa/2026-05-22-owasp-sweep/REPORT.md` (~2 months prior), with extra scrutiny
on the three modules that had zero test coverage until this week —
`deliveries/`, `staff/`, `telegram/` — plus a fresh look at the Telegram
webhook (`telegram.controller.ts`), which was not explicitly in scope for
the May sweep.

Findings below are cross-referenced against the May report; unchanged PASS
verdicts are not re-derived from scratch, only reconfirmed.

## Severity counts

- **0 P0**
- **1 P1 (new)** — Telegram webhook accepts unauthenticated requests when
  `TELEGRAM_WEBHOOK_SECRET` is unset. **Fixed same day**, see below.
- **3 P2** — 1 carried (npm advisories, improved), 2 new (staff last-owner
  gap; `staff.role_change` audit misattribution)
- **2 P3** — both carried unchanged from May (currencies endpoints public,
  `POST /rates/fetch` outbound call)

## What changed since May

1. **NEW P1 — Telegram webhook auth is optional and unenforced at boot**
   (`telegram.controller.ts`). `TELEGRAM_WEBHOOK_SECRET` was not in
   `api/.env.example` and not checked by `validate-config.ts` (unlike JWT
   secrets, which fail closed on boot). If unset in a production deploy,
   `handleWebhook` accepts any POST body as a genuine Telegram `Update`.
   Traced impact: a forged update with `contact.phone_number = <victim
   phone>` and an attacker-controlled `chat.id` causes
   `telegram.service.ts` to rebind `Customer.telegramChatId` or
   `User.telegramChatId` — including store owners — to the attacker,
   silently redirecting future receipts and notifications (which contain
   purchase data) to them.

   **Fixed same session**: `validate-config.ts` now requires
   `TELEGRAM_WEBHOOK_SECRET` (≥16 chars) whenever `NODE_ENV=production`,
   in both `validateEnvBeforeBoot` (pre-Nest-bootstrap) and
   `validateBootConfig` (post-bootstrap belt-and-braces check), mirroring
   the existing `CORS_ORIGIN` production gate. Documented in
   `.env.example`. 6 new tests in
   `api/src/common/bootstrap/validate-config.spec.ts`. Dev/test
   environments are unaffected (check only fires in production).

2. **NEW P2 — `staff.role_change` audit entries always attributed to the
   literal string `'system'`**, never the real actor
   (`staff.service.ts:188`, pre-fix), because `StaffService.update()`
   didn't receive caller identity. Breaks accountability for the one audit
   path where attribution matters most (role escalation).

   **Fixed same session**: `StaffController` now threads
   `@CurrentUser('id')` through to `StaffService.update()`/`.remove()`;
   audit entries attribute the real caller when available, falling back to
   `'system'` only when none is provided (covered by
   `staff.service.spec.ts`).

3. **A06 composition changed, net improvement**: `xlsx` (unfixable
   critical, and confirmed *unused* — the actual Excel import/export uses
   `exceljs`) was removed entirely; `firebase-admin` bumped 13→14;
   `bcrypt` bumped 5→6, which also cleared the `@mapbox/node-pre-gyp`/`tar`
   critical chain. `npm audit --omit=dev`: **59 → 41 vulnerabilities, 4 → 2
   critical** (both remaining critical are `request`/`form-data`, transitive
   through `node-telegram-bot-api`'s `@cypress/request-promise` dependency
   — a major version bump (0.67→1.2) was deliberately deferred rather than
   forced same-day, given the telegram module just received its first test
   coverage this week and a major bump risks breaking that API surface
   without dedicated regression time). Full backend suite (371 tests) and
   `tsc --noEmit` both green after all dependency changes.

## Independent verdict: staff last-OWNER gap

Verified directly rather than taking the originating finding at face value.
`staff.service.ts` `update()`/`remove()` (pre-fix) indeed had no
last-remaining-OWNER guard and no self-action guard — confirmed by reading
the code, not just the framing.

However, tracing `StoreAccessGuard` and `PermissionsGuard` shows both check
`Store.ownerId === userId` **first and independently of the `Staff` table**.
Since `CreateStaffDto`/`UpdateStaffDto`'s `role` field is typed
`StaffRoleEnum`, which structurally excludes `OWNER` (confirmed: `@IsEnum`
enforces this at runtime too), the sole `OWNER`-role `Staff` row is always
the literal `Store.ownerId` user and **cannot** actually be demoted or
removed via this API path to the point of locking the real owner out — that
would require also changing `Store.ownerId`, which this module never
touches.

**Verdict: P2, not P0/P1.** Real impact was bounded to data-integrity
corruption (the `Staff` row's displayed role/visibility diverging from
`Store.ownerId`, e.g. a store showing "0 OWNER-role staff" while still
having a fully-functional owner) and a minor `maxStaff` plan-limit
undercount — not privilege escalation or actual owner lockout. Worth fixing
as defense-in-depth (which it now is), but didn't meet the P0/P1 bar this
finding was initially flagged at.

**Fixed same session regardless**: `StaffService` now has
`assertNotLastOwner()`, called from both `update()` (blocking a role
downgrade away from `OWNER` when no other active `OWNER` staff row remains
in the store) and `remove()` (same guard, plus a separate self-removal
guard using the newly-threaded caller id). 8 new tests.

## Matrix (A01–A10)

| Cat | Title | Status | Note |
|-----|-------|--------|------|
| A01 | Broken Access Control | PASS (1 P2 new, 1 P3 carried) | Staff last-owner gap (fixed, see above); currencies P3 unchanged from May |
| A02 | Cryptographic Failures | PASS | bcrypt now v6, rounds=12 unchanged; JWT secret validation unchanged and still enforced |
| A03 | Injection | PASS | Still 0 `$queryRaw`/`$executeRaw`; Telegram webhook body is never interpolated into a query — parsed and matched via Prisma only |
| A04 | Insecure Design | PASS | localId idempotency pattern unchanged; `deliveries`/`staff` reviewed this pass, no design gaps found beyond the fixed items above |
| A05 | Security Misconfiguration | **Changed from PASS to a fixed P1** | Telegram webhook secret now enforced in production — see above. Everything else (helmet/CSP/HSTS, CORS, JWT placeholder guard) unchanged and still PASS |
| A06 | Vulnerable Components | PARTIAL (1 P2, improved) | 59→41 vulns, 4→2 critical; see above for detail and the deliberate telegram-bot-api deferral |
| A07 | Identification & Auth Failures | PASS | Unchanged — throttle limits, `tokensRevokedAt` re-login-on-rotation, bcrypt.compare everywhere |
| A08 | Software & Data Integrity Failures | PASS | Unchanged; audit-log attribution gap for staff role changes fixed (see above) |
| A09 | Security Logging & Monitoring | PASS | Unchanged |
| A10 | SSRF | PASS (1 P3 carried) | Currencies `POST /rates/fetch` P3 unchanged from May. Telegram webhook itself doesn't fetch any user-supplied URL — no new SSRF vector found there, only the auth gap under A05 |

## Recommendations (remaining, not yet done)

1. Consider a scheduled follow-up to bump `node-telegram-bot-api` 0.67→1.2
   (clears the last 2 critical npm advisories) once there's room for
   dedicated regression testing against the new major version's API.
2. Re-run `npm audit` periodically — 39 moderate advisories remain
   unreviewed in detail (mostly transitive noise from `firebase-admin`'s
   Google Cloud SDK tree); none were individually triaged this pass beyond
   confirming they're not in the critical/high band.
