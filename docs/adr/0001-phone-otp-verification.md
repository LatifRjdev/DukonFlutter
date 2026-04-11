# ADR-0001 — Phone OTP verification for registration

**Status:** Proposed — 2026-04-11
**Related issue:** #28 BE-P1-008
**Related PRs:** #44 (bootstrap hardening), #15 (per-route throttle)

## Context

`POST /auth/register` currently accepts any phone number and issues access
+ refresh tokens immediately. Combined with the global 3/min throttle
added in BE-P1-003 (#15), an attacker can still mass-register junk
accounts at 180/hour/IP — or worse, squat real Tajik mobile numbers
before their owners sign up, then wait for a staff-invite flow to collide
with the squatted account.

No phone-ownership check exists. There is no SMS provider integration
yet.

## Decision

Introduce an OTP handshake on the registration path:

```
POST /auth/request-otp     { phone }               →  204 (OTP sent via SMS)
POST /auth/verify-otp      { phone, code }         →  200 { verificationToken }
POST /auth/register        { phone, password, name, verificationToken } → 201
```

- `verificationToken` is a short-lived (5 min) single-use JWT signed with
  `JWT_ACCESS_SECRET` carrying `{ phone, purpose: 'otp-verified' }`.
- `/auth/register` refuses to issue tokens unless the `verificationToken`
  is valid, unexpired, and its `phone` field matches the DTO phone.
- OTP codes are 6 digits, 60s resend cooldown, 5 attempts per code,
  stored in Redis with key `otp:{phone}` (TTL = 5 min).
- `/auth/request-otp` is throttled at **1/min per phone** AND
  **5/min per IP** to kill both phone-squatting and IP-level abuse.

## SMS provider

Tajik market: shortlist `Kavkom SMS`, `SMS.tj`, or international
`Twilio` / `Infobip`. Blocker: pricing and regulatory requirements for
Tajikistan — needs stakeholder decision. Until then a **no-op SMS
provider** behind a feature flag (`OTP_PROVIDER=console`) will log codes
to the server console so the backend API can still be developed.

## Out of scope for this ADR

- Re-verification for existing users (password reset, change phone)
- Rate-limit backoff beyond fixed windows
- Blocking VoIP / disposable-number ranges
- Multi-factor second factor for privileged operations

## Migration plan (new Prisma tables)

```prisma
model PhoneOtpAttempt {
  id         String   @id @default(uuid())
  phone      String
  codeHash   String   // sha256(code) — never store plaintext
  attempts   Int      @default(0)
  expiresAt  DateTime
  createdAt  DateTime @default(now())
  @@unique([phone])
  @@index([expiresAt])
}
```

No changes needed to `User` — `verificationToken` is ephemeral and lives
only for the 5 min between `/verify-otp` and `/register`.

## Rollout steps

1. Land this ADR (this PR — doc only, no code).
2. Add `OtpModule` (console provider) + Redis-backed store.
3. Wire `verificationToken` into `/auth/register` as *optional* during
   the transition, guarded by `REQUIRE_OTP=false` env.
4. Migrate the Flutter onboarding screen to the two-step flow.
5. Flip `REQUIRE_OTP=true` in prod after SMS provider picked.
6. Retire the escape hatch.

## Consequences

Positive:
- Closes BE-P1-008, BE-P1-001 partial (replay on stolen register token),
  and fronts the squatting vector in #2 (BE-P0-001 staff invite flow).
- Produces a reusable `OtpModule` that the password-reset flow can
  consume later.

Negative:
- One extra round-trip during onboarding.
- SMS cost per registration — needs budget conversation.
- Requires Redis, which is already in the stack but only used for
  throttling today.

## Why this is not just code in this PR

Three decisions need human input before any code can land:
1. SMS provider selection (regulatory + price).
2. Whether to retire the existing `POST /auth/register` or dual-run it
   during transition.
3. Flutter onboarding redesign — currently Phone → OTP screen → PIN,
   but the PIN step is not wired to the backend.

Opening #28 with this ADR attached so the conversation happens in the
issue before a feature branch lands.
