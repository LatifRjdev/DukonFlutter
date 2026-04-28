# ADR-0003 — Staff invite / onboarding flow

**Status:** Proposed — 2026-04-11
**Related issue:** #2 (BE-P0-001 follow-up)
**Supersedes:** the "phone-as-password" behaviour removed in PR #20

## Context

PR #20 closed the BE-P0-001 account-takeover vulnerability by:
- Replacing `bcrypt(phone)` with a random 32-byte hex secret when
  `StaffService.create` auto-provisions a User.
- Setting `isActive: false` so the new user cannot log in at all.

This was the minimum safe fix. It leaves a UX hole: owners can add a
staff member but that staff member has no way to actually sign in.

## Decision

Add a first-class **staff invite** flow.

### High-level sequence

1. Owner submits the staff form (`POST /stores/:storeId/staff`) with
   name, phone, role, optional salary/commission.
2. Backend auto-provisions the User as today (random password,
   isActive=false) and **additionally** creates a `StaffInvite` row:
   ```prisma
   model StaffInvite {
     id         String   @id @default(uuid())
     storeId    String
     staffId    String
     userId     String
     tokenHash  String   @unique  // sha256(token)
     expiresAt  DateTime
     usedAt     DateTime?
     createdAt  DateTime @default(now())
     @@index([expiresAt])
   }
   ```
   The raw `token` is returned **once** in the API response so the owner
   can share it over WhatsApp/Telegram/SMS. No reconstruction later.
3. `GET /auth/invite/:token` — sanity check endpoint, returns
   `{ storeName, roleName, staffName }` so the accept screen can render
   context. Public route (no JWT).
4. `POST /auth/accept-invite` — body `{ token, password }`. Server:
   - Validates token hash matches an unused, unexpired invite row.
   - Sets User.password via bcrypt, User.isActive = true.
   - Marks the invite row usedAt = now().
   - Returns the normal login response `{ user, accessToken, refreshToken }`.
5. TTL: 7 days. Expired invites are a 410 Gone with a helpful error.

### Rate limiting

- `POST /auth/accept-invite`: 5/min per IP, 3 failed attempts per token
  then burn the row.
- `GET /auth/invite/:token`: 20/min per IP (low risk, read-only).

### Flutter changes

- Deep link `dukonpro://invite?token=...` and matching https universal
  link for future.
- Accept screen in `lib/presentation/pages/auth/accept_invite_page.dart`:
  shows store/role/name, PIN-style password field, submit.
- Owner UI shows "Скопировать ссылку-приглашение" button on the staff
  form's success state with the raw token appended.

## Why this is an ADR not code

Three owner decisions needed before implementation:

1. **Delivery channel.** WhatsApp/Telegram share vs native SMS. Native
   SMS requires the same provider as BE-P1-008 OTP (ADR-0001). Reusing
   the same `OtpModule` post-code-rename is feasible.
2. **Token length.** 32 bytes hex (64 chars) is safe but ugly in
   WhatsApp. 16 bytes (32 chars) is marginally nicer. Pick one.
3. **Can the owner resend?** If yes, what happens to the old token —
   revoke immediately or let both work until one is used?

After those answers, the backend PR is ~2 days of work:
- migration + model
- `StaffInviteService` + `AuthController` endpoints
- update `StaffController.create` to return the invite token
- tests

Flutter PR is ~1 day:
- accept screen
- deep-link handler
- copy-invite-link button on staff form success

## Out of scope

- Existing staff who already got a random password via PR #20 —
  they'll need a manual reset by the owner, or a subsequent
  "resend invite" endpoint that nukes their current password and
  issues a new StaffInvite row. Tracked as a follow-up in #2.
- Password reset for the owner themselves — separate flow, ADR TBD.
- Multi-store staff members — orthogonal to invites.

## Acceptance for closing #2

- [ ] Prisma migration merged.
- [ ] `GET /auth/invite/:token` + `POST /auth/accept-invite` land with tests.
- [ ] `StaffController.create` response includes `inviteToken`.
- [ ] Flutter accept screen + deep link handler.
- [ ] Manual: create staff → copy token → log out → accept → log in.
- [ ] Manual: token used twice → second attempt is 410.
- [ ] Manual: token expired → 410 with clear message.
