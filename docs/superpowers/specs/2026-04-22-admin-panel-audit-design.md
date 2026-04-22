# DukonPro Admin Panel Audit — Design

**Date:** 2026-04-22
**Status:** Approved

## Goal

Pass through every page of the Next.js admin panel (`admin/`) and verify it works end-to-end: correct API endpoints, valid data shapes, rendered UI, working mutations. Fix every mismatch as we find it.

## Context

The admin panel (Next.js 16, `admin/` directory) landed on `main` as part of PR #71, but was never fully tested against the actual NestJS API. A first smoke (login flow) already surfaced 3 bugs:

1. `admin/lib/api.ts` default base URL missing `/api` prefix — **fixed**.
2. `/users/me` response missing `isAdmin` field — **fixed**.
3. `SubscriptionBloc` missing from mobile-app DI — **fixed**.

A quick grep across `admin/app/**` shows more known mismatches:

| Admin calls | API has | Status |
|---|---|---|
| `GET /admin/stats` | `GET /admin/dashboard` | ❌ 404 |
| `GET /admin/stats/registrations` | `GET /admin/dashboard/registrations` | ❌ 404 |
| `GET /admin/stats/revenue` | `GET /admin/revenue` | ❌ 404 |
| `GET /admin/subscriptions/pending` | `GET /admin/subscriptions/pending-payments` | ❌ 404 |
| `POST /admin/announcements/preview` | — (not implemented) | ❌ 404 |

There are probably more. This spec is the plan to find and fix all of them.

## Non-goals

- UI polish (spacing, typography, colors). Only functional correctness.
- New admin features (new filters, new admin-only endpoints).
- i18n of the admin panel (tg/uz).
- Rewriting `middleware.ts` (Next.js 16 deprecated it in favor of `proxy.ts`). That's a separate migration.
- Full production security audit (rate limits, audit-log completeness, token refresh). Scope is functional correctness, not security hardening.

## Strategy

User chose:

- **Fix side:** case-by-case — each mismatch is fixed on whichever side makes more sense (frontend URL rename, backend rename/add, DTO field).
- **Verification:** hybrid — `curl` with an admin JWT for API smoke, browser for UI render.
- **Test data:** minimal seed via a one-shot TS script (2-3 users, 1-2 stores, 1 pending subscription payment, 1 announcement).

## Architecture

4 phases, executed sequentially.

### Phase 0 — Seed

**File:** `api/scripts/seed-admin-test.ts` (new, based on `create-admin.ts`)

Idempotent (uses `upsert`):

- 2 regular users (`+992900000010`, `+992900000011`) with `isAdmin=false`, known passwords.
- 1 store owned by user #1, with active `business` plan subscription.
- 1 store owned by user #2, with pending subscription payment (status `PENDING_RECEIPT_REVIEW` or similar).
- 1 past `Announcement` targeting all plans.

Invocation: `npx ts-node scripts/seed-admin-test.ts`.

Commit: `chore(api): seed-admin-test script for admin panel QA`.

### Phase 1 — Audit

For each of 11 admin pages, produce a row in an audit table:

| # | Page | Method + path admin calls | Expected on API | Status | Observed error | Fix-side |
|---|---|---|---|---|---|---|

For each **GET**: `curl -H "Authorization: Bearer $ADMIN_JWT" http://localhost:4455/api<path>` → expected 200 + parse JSON.

For each **mutation**: curl with minimal valid payload (or a `&dry-run`-style probe for destructive ops). Safe writes (toggle-admin, suspend, unsuspend) can go real. Destructive writes (delete user, cancel subscription) are probed with a synthesized seed id and reverted immediately after.

For each page, also open `http://localhost:3000/<path>` in browser and check:

- Page renders without crash.
- Console has no error.
- Data shown matches what curl returned.
- Empty states render correctly when no data.

Output: `docs/superpowers/qa/2026-04-22-admin-panel-audit-results.md` with the filled audit table.

### Phase 2 — Fix

Group issues from Phase 1 by fix-side, commit per group:

- **Frontend URL renames** (one commit): edit `admin/app/**/page.tsx` to use the right paths. No new API calls, no new components.
- **Backend renames / new endpoints** (one commit per feature area): add missing endpoints, rename existing ones if that's cleaner. Prefer renaming to match admin panel's expectation where either works.
- **DTO additions** (one commit): add missing fields like `isAdmin`, `blockedAt`, `suspendedAt` to response DTOs. Verify Prisma `select` also includes them.
- **Data-shape adapters** (rare): if API returns `{items, total}` but admin expects `[...]`, adjust one side to match.

Rules during fix:

- Every commit passes `cd api && npx tsc --noEmit` and `cd admin && npm run build`.
- If an endpoint requires substantial business logic that doesn't exist (e.g., `announcements/preview` rendering logic), ship a **minimal stub** that returns a valid shape, flagged `// TODO(admin-panel): replace stub with real preview`.
- Commits tagged with `fix(admin-panel):` prefix for easy revert.

### Phase 3 — Verification

Repeat Phase 1's curl + browser checks. All rows in the audit table should turn green. Record final results in the same results doc.

Final commit: `docs(admin-panel-audit): mark complete — all 11 pages verified`.

## Risks / mitigations

| Risk | Mitigation |
|---|---|
| Some endpoint requires real business logic (e.g. `announcements/preview`) not yet written | Ship stub with TODO marker; defer real impl to separate ticket. |
| Prisma schema missing fields the admin panel expects (e.g. `blockedAt`) | Check schema first; if missing, skip that field from audit. Adding new schema fields is out of scope. |
| Admin page reads a field from response that service doesn't return | Update `select` in service + add field to DTO. Prisma schema has the field; just not exposed. |
| Browser test blocked by CORS | API main.ts already has CORS handling for dev; if `admin/` origin (`localhost:3000`) is not in allowlist, add it. Local-only change. |
| Seed script fails because of FK constraints | Run in right order: users → stores → subscriptions → announcements. Wrap in try/catch so partial seed doesn't leave broken state. |

## Success criteria

- All 11 pages load without crash when Latif (admin) opens `http://localhost:3000/<path>`.
- All 11 pages show correct data for the seeded state (exact values may differ, but the shape matches).
- No 404/500 in browser DevTools console during normal navigation.
- All read endpoints return 200 via curl; all (safe) mutation endpoints return 200.
- `cd api && npx tsc --noEmit` passes.
- `cd admin && npm run build` passes (with or without `middleware → proxy` warning).
- Audit results doc committed.

## Testing strategy

Per user: hybrid curl + browser (no Playwright). Manual verification. Documented in Phase 3 results doc.

## Files expected to change

- `api/scripts/seed-admin-test.ts` — new file.
- `api/src/modules/admin/*.controller.ts` — new/renamed routes.
- `api/src/modules/admin/*.service.ts` — new logic for stubs.
- `api/src/modules/users/dto/user-response.dto.ts` — field additions.
- `api/src/modules/users/users.service.ts` — Prisma `select` additions.
- `admin/app/(admin)/**/page.tsx` — URL renames.
- `admin/lib/types.ts` — response type refinements.
- `docs/superpowers/qa/2026-04-22-admin-panel-audit-results.md` — new audit results doc.

## Follow-ups (out of scope)

- Replace `announcements/preview` stub with real rendering.
- Migrate `admin/middleware.ts` to Next.js 16 `proxy.ts` convention.
- Add Playwright e2e harness for admin panel.
- Audit-log correctness (are all admin mutations being logged?).
- Rate-limit + role-checks on admin routes.
