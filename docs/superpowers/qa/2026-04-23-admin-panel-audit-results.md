# Admin Panel Audit Results — 2026-04-23

## Setup
- API: `http://localhost:4455` (prefix `/api`)
- Admin panel: `http://localhost:3000`
- Seed: `api/scripts/seed-admin-test.ts`
- Admin user: `+992900000001` / `fwr123456`
- Regular test users: `+992900000010`, `+992900000011` / `test12345`
- Stores: `seed-store-1` (ACTIVE BUSINESS sub), `seed-store-2` (PAST_DUE START sub + PENDING payment)
- Announcement: `seed-announcement-1`
- Browser verification deferred to Task 8 — this audit is curl-only (subagents cannot open a browser).

Login works (`HTTP 200`, accessToken returned). `GET /api/users/me` also works and **does** return `isAdmin: true`, confirming the DB record is correct.

## CRITICAL blocker found before per-page audit

**Issue #0 — `JwtAccessStrategy` drops `isAdmin` from `request.user`.**

`api/src/modules/auth/strategies/jwt-access.strategy.ts` (lines 20-31):
```ts
async validate(payload: { sub: string; phone: string }) {
  const user = await this.prisma.user.findUnique({
    where: { id: payload.sub },
    select: { id: true, phone: true, name: true, isActive: true },
  });
  if (!user || !user.isActive) throw new UnauthorizedException(...);
  return { id: user.id, phone: user.phone, name: user.name };
}
```

`isAdmin` is neither selected nor returned. `AdminGuard`
(`api/src/common/guards/admin.guard.ts`) requires `request.user?.isAdmin === true`.

**Effect:** every controller protected by `AdminGuard` returns **HTTP 403
"Admin access required"** for every caller, including the seed admin. This
affects 8 of 11 pages (all the `/admin/*` resource routes). Dashboard (3 of 4
calls) and announcements-preview (1) return 404 on top of this due to route
name mismatches.

Fix proposal (single line): add `isAdmin: true` to the `select` and to the
returned object in `JwtAccessStrategy.validate`.

Until that fix lands, the per-page findings below capture:
1. Actual HTTP status we observed (mostly 403 or 404).
2. Frontend endpoint vs backend route mismatches discovered by reading the
   frontend pages and backend controllers.
3. DTO-shape mismatches read from `admin.service.ts` / `subscriptions.service.ts`
   vs what the admin pages consume. These cannot be curl-confirmed until Issue
   #0 is fixed, but the static analysis is unambiguous.

## Findings

Legend: ✅ pass · ❌ fail (needs fix) · ⚠️ pass with warning · 🔒 blocked by Issue #0

### 1. `/login` (verified earlier, re-verified here)

- `POST /api/auth/login` — **HTTP 200** ✅
- Response: `{user:{id,phone,name,email}, accessToken, refreshToken}`.
- Frontend then calls `GET /api/users/me` which returns `isAdmin: true` ✅.
- No issue at login. Seed admin works.

### 2. `/` (entry redirect)

- Static Next.js route with no backend call. The middleware redirects based on
  cookie. Not separately curl-testable.
- ✅ pass (covered implicitly by /login working).

### 3. `/dashboard` ❌

Frontend (`admin/app/(admin)/dashboard/page.tsx`) calls 4 endpoints:

| Frontend path | Method | Observed | Backend actually exposes | Fix |
|---|---|---|---|---|
| `/admin/stats` | GET | **404** ❌ | `GET /admin/dashboard` | frontend-rename |
| `/admin/stats/revenue` | GET | **404** ❌ | `GET /admin/revenue` | frontend-rename |
| `/admin/stats/registrations` | GET | **404** ❌ | `GET /admin/dashboard/registrations` | frontend-rename |
| `/admin/subscriptions/pending` | GET | **404** ❌ | `GET /admin/subscriptions/pending-payments` | frontend-rename |

All four paths are wrong in the frontend. After fix they will still 🔒 until
Issue #0 is fixed (they use `AdminGuard`).

### 4. `/users` 🔒❌

- Frontend calls: `GET /admin/users`, `PUT /admin/users/:id/toggle-admin`,
  `PUT /admin/users/:id/{block|unblock}`.
- `GET /admin/users` — **HTTP 403** 🔒 (Issue #0).
- Backend route exists: `admin-users.controller.ts @Get()`.
- Backend service (`admin.service.ts listUsers`) returns
  `{data, total, page, limit}` with each user containing
  `{id, phone, name, email, isAdmin, isActive, createdAt, _count.ownedStores}`.
- Frontend (`admin/app/(admin)/users/page.tsx`) reads: `user.isActive` ✅,
  `user.isAdmin` ✅, `user.createdAt` ✅, `user._count?.stores` ❌
  (backend uses `_count.ownedStores`), `user.blockedAt` ❌ (no such column;
  block state lives on `isActive`).
- **Fix proposals:**
  - backend-add: alias `_count.stores` to `ownedStores` in the select (or
    rename the field on the service mapper), so the frontend's `_count.stores`
    works. Alternatively frontend-rename to `_count.ownedStores`.
  - frontend-rename or dto-field: remove `blockedAt` usage; use `!isActive` as
    the "blocked" signal. Prisma schema has no `blockedAt` column.

### 5. `/users/[id]` 🔒❌

- Frontend calls: `GET /admin/users/:id` and `GET /admin/users/:id/stores`.
- `GET /admin/users/:id` — **HTTP 403** 🔒.
- `GET /admin/users/:id/stores` — **HTTP 404** ❌ (route does not exist).
- Backend `admin.service.ts getUserDetail` already includes `ownedStores` in
  the payload for the primary detail call, so the separate `/stores` call is
  redundant.
- Frontend reads: `user.name` ✅, `user.phone` ✅, `user.email` ✅,
  `user.isAdmin` ✅, `user.createdAt` ✅, `user.blockedAt` ❌ (same gap as
  page 4), `user.isActive` ✅.
- **Fix proposals:**
  - frontend-rename: drop the separate `/stores` fetch, read
    `user.ownedStores` from the detail payload.
  - frontend-rename: replace `blockedAt` with `isActive` derivation.

### 6. `/stores` 🔒❌

- Frontend calls: `GET /admin/stores`, `PUT /admin/stores/:id/{suspend|unsuspend}`, `PUT /admin/stores/:id/transfer`.
- `GET /admin/stores` — **HTTP 403** 🔒.
- Backend route exists; `admin.service.ts listStores` returns
  `{data, total, page, limit}` with each store:
  `{id, name, category, isActive, createdAt, owner:{id,name,phone}, subscription:{plan,status}, _count:{products,staff}}`.
- Frontend (`admin/app/(admin)/stores/page.tsx`) reads:
  - `store.id` ✅
  - `store.name` ✅
  - `store.status` ❌ — backend has `isActive` boolean only; no `status`
    field (no `suspendedAt` column either). Frontend toggles on
    `store.status === 'suspended'`.
  - `store.ownerName` ❌ — backend has `store.owner.name` (nested).
  - `store.plan` ❌ — backend has `store.subscription.plan` (nested).
- **Fix proposals:**
  - dto-field (backend): add computed `status: 'active'|'suspended'` mapper on
    the service (derived from `isActive`), flatten `ownerName` and `plan` in
    the response DTO.
  - OR frontend-rename: read `!store.isActive ? 'suspended' : 'active'`,
    `store.owner?.name`, `store.subscription?.plan` directly.
  - Decide per DTO policy — doc recommends frontend-rename (backend already
    ships nested relations, which are fine).

### 7. `/stores/[id]` 🔒❌

- Frontend calls: `GET /admin/stores/:id`, `GET /admin/stores/:id/subscription`, `PUT /admin/stores/:id/{suspend|unsuspend}`, `PUT /admin/stores/:id/transfer`.
- `GET /admin/stores/seed-store-1` — **HTTP 403** 🔒.
- `GET /admin/stores/seed-store-1/subscription` — **HTTP 404** ❌ (route does not exist under `/admin/stores/*`). There is a related but differently guarded route `GET /stores/:storeId/subscription` on the tenant side.
- Backend `admin.service.ts getStoreDetail` already returns the full store
  including `subscription` nested — so the separate `/subscription` call is
  redundant.
- Frontend reads: `store.owner` (nested) ✅, `store.subscription` (nested) ✅,
  `store.stats` ❌ — backend puts stats flat: `monthlySalesTotal`,
  `monthlySalesCount`, `lastSaleDate`.
- **Fix proposals:**
  - frontend-rename: drop the extra `/subscription` call; read nested
    `store.subscription` from the detail response.
  - backend-add or frontend-rename: wrap stats in `stats: {monthlySalesTotal, monthlySalesCount, lastSaleDate}` OR update frontend to read the flat fields. Recommend frontend-rename (simpler).

### 8. `/subscriptions` 🔒❌

- Frontend calls: `GET /admin/subscriptions`, `GET /admin/subscriptions/pending`, plus several PUT mutations.
- `GET /admin/subscriptions` — **HTTP 403** 🔒.
- `GET /admin/subscriptions/pending` — **HTTP 404** ❌ (frontend path wrong).
- Mutation path mismatches confirmed by static inspection (not curled — all
  blocked by 🔒):

| Frontend PUT | Backend actually exposes |
|---|---|
| `/admin/subscriptions/:id/extend` | ✅ `/admin/subscriptions/:id/extend` |
| `/admin/subscriptions/:id/change-plan` | ✅ `/admin/subscriptions/:id/change-plan` |
| `/admin/subscriptions/:id/discount` | ❌ `/admin/subscriptions/:id/set-discount` |
| `/admin/subscriptions/:id/cancel` | ✅ `/admin/subscriptions/:id/cancel` |
| `/admin/subscriptions/payments/:id/approve` | ❌ `/admin/subscriptions/:id/approve-payment/:paymentId` |
| `/admin/subscriptions/payments/:id/reject` | ❌ `/admin/subscriptions/:id/reject-payment/:paymentId` |

- Backend `adminGetAll` returns an **array** (not wrapped in `{data}`); each
  item is `{...subscription, store:{id,name}, payments:[latest]}`.
- Frontend reads: `subscription.store.name` ✅, `subscription.plan` ✅,
  `subscription.status` ✅, `subscription.expiresAt` ❌ — Prisma schema uses
  `currentPeriodEnd`.
- Backend `adminGetPendingPayments` returns Payment rows with
  `subscription.store.name` (nested two deep) and the column is `receiptImage`
  not `receiptUrl`.
- Frontend reads: `payment.id` ✅, `payment.subscriptionId` ✅,
  `payment.store.name` ❌ (actually `payment.subscription.store.name`),
  `payment.amount` ✅, `payment.receiptUrl` ❌ (actually `receiptImage`),
  `payment.status` ✅.
- **Fix proposals:**
  - frontend-rename: `/discount` → `/set-discount`.
  - frontend-rename: payment approve/reject paths to the `:id/approve-payment/:paymentId` shape (requires frontend to pass the subscriptionId alongside paymentId in the query).
  - frontend-rename: `expiresAt` → `currentPeriodEnd`.
  - dto-field (backend) or frontend-rename: flatten `payment.store` (either alias in service or read `payment.subscription.store`); rename `receiptImage` → `receiptUrl` in response DTO.

### 9. `/subscriptions/plans` 🔒

- Frontend calls: `GET /admin/plans`, `PUT /admin/plans/:id`.
- `GET /admin/plans` — **HTTP 403** 🔒.
- Backend route exists (`admin-plans.controller.ts`). Expected to work once
  Issue #0 is fixed. No static DTO mismatches detected in a pass.
- Re-verify after Issue #0 fix.

### 10. `/announcements` 🔒❌

- Frontend calls: `GET /admin/announcements`, `POST /admin/announcements/preview`, `POST /admin/announcements`.
- `GET /admin/announcements` — **HTTP 403** 🔒.
- `POST /admin/announcements/preview` — **HTTP 404** ❌ (route does not exist on the backend — only `POST /admin/announcements` and `GET /admin/announcements` are implemented).
- Static DTO check: `listAnnouncements`/`createAnnouncement` return the Prisma
  `Announcement` model (`id, title, body, targetPlan, targetStatus, sentBy,
  recipientCount, createdAt`). Admin page should consume these directly — no
  obvious rename gap besides the missing `/preview` route.
- **Fix proposals:**
  - backend-add: implement `POST /admin/announcements/preview` that runs
    `createAnnouncement`'s user-filter logic **without** sending or persisting,
    returning `{recipientCount}`. OR frontend-remove: drop the preview feature
    if out of scope.

### 11. `/audit-log` 🔒

- Frontend calls: `GET /admin/audit-log?<params>`.
- **HTTP 403** 🔒.
- Backend route exists (`admin-audit-log.controller.ts`). Expected to work
  after Issue #0. No static DTO gap detected.

## Summary
- Pages passing: **1 / 11** (only `/login`).
- Pages failing (will still fail after Issue #0 due to additional frontend/backend gaps): **9 / 11**
  (dashboard, users list, users detail, stores list, stores detail, subscriptions, announcements — plus any DTO renames required on others).
- Pages that should flip to ✅ just from fixing Issue #0 alone: **2** (`/subscriptions/plans`, `/audit-log`).
- Issues open: **1 critical (Issue #0) + 13 page-specific discrepancies** enumerated above.

### Top-line issue categories
1. **JWT strategy drops `isAdmin`** — single root cause for all 403s. ONE-line fix.
2. **Frontend route-name drift vs backend** — dashboard stats paths, `subscriptions/pending`, `subscriptions/.../discount`, payment approve/reject paths, `announcements/preview`, `users/:id/stores`, `stores/:id/subscription`. Most fixable frontend-side.
3. **DTO-shape drift** — `blockedAt` (doesn't exist, should be `!isActive`), `_count.stores` (is `_count.ownedStores`), `store.status`/`ownerName`/`plan` (flat vs nested), `subscription.expiresAt` (is `currentPeriodEnd`), `payment.store.name`/`receiptUrl` (wrong nesting + renamed column), `store.stats` (flat vs nested).
4. **Redundant frontend fetches** — `/users/:id/stores` and `/stores/:id/subscription` duplicate data already in the primary detail responses; simplest fix is frontend-only.

## Next-task pointers

Phase 2 (Task 3+) suggested order of operations:
1. Fix Issue #0 (`JwtAccessStrategy.validate` must include `isAdmin`).
2. Fix dashboard path renames (frontend) — unblocks 4 curls to 200.
3. Decide DTO policy (backend-flatten vs frontend-read-nested) and apply.
4. Add `POST /admin/announcements/preview` or remove the feature.
5. Re-curl every endpoint; the audit doc's "Fix" columns are the checklist.
6. Task 8 opens the browser and re-verifies visually.
