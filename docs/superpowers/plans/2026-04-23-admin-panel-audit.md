# Admin Panel Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every page of the DukonPro Admin Next.js panel (`admin/app/(admin)/**`) loads without error, hits real API endpoints, and renders correct data.

**Architecture:** 4 phases. Phase 0 seeds a minimal test dataset. Phase 1 audits all 11 pages via curl + browser. Phase 2 fixes every mismatch case-by-case (frontend URL rename OR backend route add/rename OR DTO field addition). Phase 3 re-verifies.

**Tech Stack:** NestJS 10, Prisma 6, Next.js 16 (Turbopack), shadcn/ui, TanStack Query, JWT auth with `AdminGuard`.

**Spec:** [docs/superpowers/specs/2026-04-22-admin-panel-audit-design.md](../specs/2026-04-22-admin-panel-audit-design.md)

---

## Pre-work: mismatch matrix (verified from static grep on 2026-04-23)

| # | Admin call | API route | Verdict |
|---|---|---|---|
| 1 | `GET /admin/stats` | `GET /admin/dashboard` | Frontend rename |
| 2 | `GET /admin/stats/revenue` | `GET /admin/revenue` | Frontend rename |
| 3 | `GET /admin/stats/registrations` | `GET /admin/dashboard/registrations` | Frontend rename |
| 4 | `GET /admin/subscriptions/pending` | `GET /admin/subscriptions/pending-payments` | Frontend rename (3 call-sites) |
| 5 | `PUT /admin/subscriptions/:id/discount` | `PUT /admin/subscriptions/:id/set-discount` | Frontend rename |
| 6 | `PUT /admin/subscriptions/payments/:id/approve` | `PUT /admin/subscriptions/:subId/approve-payment/:paymentId` | Backend ADD shortcut OR restructure frontend |
| 7 | `PUT /admin/subscriptions/payments/:id/reject` | `PUT /admin/subscriptions/:subId/reject-payment/:paymentId` | Same |
| 8 | `GET /admin/users/:id/stores` | — (not implemented) | Backend ADD |
| 9 | `GET /admin/stores/:id/subscription` | — (not implemented) | Backend ADD |
| 10 | `POST /admin/announcements/preview` | — (not implemented) | Backend ADD (minimal stub) |
| 11 | Admin reads `user.isActive` | API returns `blockedAt`/`isActive` — TBV during audit | Likely DTO addition |
| 12 | Admin reads `store.status === 'suspended'` | API may return `suspendedAt` — TBV | Likely DTO addition |

Items 1–5 are pure frontend URL renames. Items 6–7 need a decision during fix (prefer backend ADD of shortcut). Items 8–10 need new backend endpoints. Items 11–12 are verified during audit and likely fixed by adding Prisma `select` fields + DTO updates.

---

## File Structure

**Created:**
- `api/scripts/seed-admin-test.ts` — idempotent seed script (Task 1).
- `docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md` — audit log (Task 2).

**Modified (expected — actual set depends on audit findings):**
- `admin/app/(admin)/dashboard/page.tsx` — 4 URL renames.
- `admin/app/(admin)/subscriptions/page.tsx` — 2 URL renames + 2 payload restructurings.
- `admin/app/(admin)/users/[id]/page.tsx` — depends on field audit.
- `admin/app/(admin)/stores/[id]/page.tsx` — depends on endpoint availability.
- `admin/app/(admin)/announcements/page.tsx` — depends on preview stub shape.
- `api/src/modules/admin/admin-users.controller.ts` — add `GET :id/stores` endpoint.
- `api/src/modules/admin/admin-stores.controller.ts` — add `GET :id/subscription` endpoint.
- `api/src/modules/admin/admin-announcements.controller.ts` — add `POST /preview` stub.
- `api/src/modules/subscriptions/subscriptions.controller.ts` — add `payments/:id/approve` + `payments/:id/reject` shortcuts.
- `api/src/modules/admin/admin.service.ts` — select additions + new service methods.

---

## Task 1: Phase 0 — Seed test dataset

**Files:**
- Create: `api/scripts/seed-admin-test.ts`

Creates idempotent test data: 2 regular users, 2 stores (one active subscription, one pending-payment), 1 announcement.

- [ ] **Step 1: Create seed script**

```typescript
// api/scripts/seed-admin-test.ts
import { PrismaClient, SubscriptionPlan, SubscriptionStatus, PaymentStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const hashedPassword = await bcrypt.hash('test12345', 10);

  // --- Users ---
  const user1 = await prisma.user.upsert({
    where: { phone: '+992900000010' },
    update: {},
    create: {
      phone: '+992900000010',
      password: hashedPassword,
      name: 'Тестовый Клиент 1',
      isAdmin: false,
    },
  });

  const user2 = await prisma.user.upsert({
    where: { phone: '+992900000011' },
    update: {},
    create: {
      phone: '+992900000011',
      password: hashedPassword,
      name: 'Тестовый Клиент 2',
      isAdmin: false,
    },
  });

  // --- Stores ---
  const store1 = await prisma.store.upsert({
    where: { id: 'seed-store-1' },
    update: {},
    create: {
      id: 'seed-store-1',
      ownerId: user1.id,
      name: 'Тестовый магазин 1 (активная подписка)',
      currency: 'TJS',
    },
  });

  const store2 = await prisma.store.upsert({
    where: { id: 'seed-store-2' },
    update: {},
    create: {
      id: 'seed-store-2',
      ownerId: user2.id,
      name: 'Тестовый магазин 2 (ожидает подтверждения)',
      currency: 'TJS',
    },
  });

  // --- Subscriptions ---
  await prisma.subscription.upsert({
    where: { storeId: store1.id },
    update: {},
    create: {
      storeId: store1.id,
      plan: SubscriptionPlan.business,
      status: SubscriptionStatus.active,
      startedAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });

  await prisma.subscription.upsert({
    where: { storeId: store2.id },
    update: {},
    create: {
      storeId: store2.id,
      plan: SubscriptionPlan.start,
      status: SubscriptionStatus.pending,
      startedAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });

  // --- Pending payment on store2 ---
  await prisma.subscriptionPayment.create({
    data: {
      storeId: store2.id,
      plan: SubscriptionPlan.start,
      amount: 50,
      receiptUrl: 'https://placeholder.example.com/receipt.jpg',
      status: PaymentStatus.pending_review,
    },
  }).catch(() => { /* already exists, ignore */ });

  // --- Announcement ---
  await prisma.announcement.upsert({
    where: { id: 'seed-announcement-1' },
    update: {},
    create: {
      id: 'seed-announcement-1',
      title: 'Добро пожаловать!',
      body: 'Это тестовое объявление для QA админ-панели.',
      targetPlan: null,
      sentAt: new Date(),
    },
  });

  console.log('Seed complete:');
  console.log(`  Users:          ${user1.phone}, ${user2.phone}`);
  console.log(`  Stores:         ${store1.id}, ${store2.id}`);
  console.log(`  Announcements:  1`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
```

- [ ] **Step 2: Verify Prisma model names match**

Run: `cd /Users/latifrjdev/Downloads/Dukon/api && grep -E "^model (User|Store|Subscription|SubscriptionPayment|Announcement) " prisma/schema.prisma`

Expected: each model exists. If a model name differs (e.g. `Announce` vs `Announcement`), update the seed script to match.

- [ ] **Step 3: Verify enum names**

Run: `cd /Users/latifrjdev/Downloads/Dukon/api && grep -B1 -A10 "enum SubscriptionPlan" prisma/schema.prisma`

Expected: shows enum values. If they're `BUSINESS`/`START` instead of `business`/`start`, update the seed script accordingly.

- [ ] **Step 4: Run seed**

Run: `cd /Users/latifrjdev/Downloads/Dukon/api && npx ts-node scripts/seed-admin-test.ts`

Expected output:
```
Seed complete:
  Users:          +992900000010, +992900000011
  Stores:         seed-store-1, seed-store-2
  Announcements:  1
```

If error about unknown field / enum, fix the script and re-run. It's idempotent.

- [ ] **Step 5: Verify rows landed**

Run:
```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT phone FROM \"User\" WHERE phone LIKE '+99290%';"
```
Expected: 2 rows (`+992900000010`, `+992900000011`) plus your admin user.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add api/scripts/seed-admin-test.ts
git commit -m "chore(api): seed-admin-test script for admin panel QA

Idempotent upsert-based seed for admin panel audit:
  - 2 regular users (+992900000010, +992900000011, password test12345)
  - 2 stores (one active business sub, one pending start sub)
  - 1 pending subscription payment on store 2
  - 1 past announcement

Run via: npx ts-node scripts/seed-admin-test.ts"
```

---

## Task 2: Phase 1 — Full audit, produce results doc

**Files:**
- Create: `docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md`

For each of 11 admin pages, run curl against every endpoint the page calls, then open the page in a browser, record findings.

- [ ] **Step 1: Create audit results skeleton**

```bash
mkdir -p /Users/latifrjdev/Downloads/Dukon/docs/superpowers/qa
```

```markdown
<!-- /Users/latifrjdev/Downloads/Dukon/docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md -->
# Admin Panel Audit Results — 2026-04-23

## Setup

- API running on `http://localhost:4455`
- Admin panel running on `http://localhost:3000`
- Seed loaded via `api/scripts/seed-admin-test.ts`
- Admin user: `+992900000001` (from `create-admin.ts` earlier)

## Admin JWT

```bash
ADMIN_JWT=$(curl -s -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992900000001","password":"fwr123456"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")
echo "JWT: ${ADMIN_JWT:0:40}..."
```

## Findings

Legend: ✅ pass · ❌ fail (needs fix) · ⚠️ pass with warning (empty state, shape smell, …)

### 1. `/login`
Already verified in prior session.

### 2. `/` (entry redirect)
TBA.

### 3. `/dashboard`
TBA.

### 4. `/users`
TBA.

### 5. `/users/[id]`
TBA.

### 6. `/stores`
TBA.

### 7. `/stores/[id]`
TBA.

### 8. `/subscriptions`
TBA.

### 9. `/subscriptions/plans`
TBA.

### 10. `/announcements`
TBA.

### 11. `/audit-log`
TBA.

## Summary

- Pages passing: _N/11_
- Pages failing: _N/11_
- Issues open: _N_
```

- [ ] **Step 2: Obtain admin JWT for the audit session**

Run:
```bash
ADMIN_JWT=$(curl -s -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992900000001","password":"fwr123456"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")
echo "$ADMIN_JWT"
```

Expected: a long JWT. If error, adjust phone/password. Keep `$ADMIN_JWT` in env for subsequent steps.

- [ ] **Step 3: Dashboard — 4 endpoints**

Run each and record the HTTP status + first 200 chars of body in the results file.

```bash
for path in /admin/stats /admin/stats/revenue /admin/stats/registrations /admin/subscriptions/pending; do
  echo "=== $path ==="
  curl -s -o /tmp/body.json -w "%{http_code}\n" \
    -H "Authorization: Bearer $ADMIN_JWT" \
    "http://localhost:4455/api$path"
  head -c 200 /tmp/body.json
  echo
done
```

Expected: 4 × `404 Cannot GET` — all are frontend mismatches from the pre-work matrix. Mark page ❌ in results.

Then open `http://localhost:3000/dashboard` in browser. Record console errors.

- [ ] **Step 4: Users list**

```bash
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/users" | head -c 500
```

Expected: 200 with `{items: [...], total: N, ...}` or similar. Verify the 3 seeded users appear.

Check: does the response include `isActive`, `isAdmin`, `blockedAt` per user? If frontend reads `user.isActive` but API returns `isBlocked`, flag DTO mismatch.

Open `http://localhost:3000/users`. Verify list renders, toggle-admin/block buttons visible.

- [ ] **Step 5: Users detail (pick seed-user-1 id from list response)**

Get the id from step 4's JSON, substitute `<ID>`:
```bash
USER_ID=<paste-user-id-from-step-4>
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/users/$USER_ID"
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/users/$USER_ID/stores"
```

Expected: first 200, second probably 404 (not implemented). Record both.

Open `http://localhost:3000/users/$USER_ID`.

- [ ] **Step 6: Stores list + detail**

```bash
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/stores" | head -c 500

STORE_ID=seed-store-1
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/stores/$STORE_ID"
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/stores/$STORE_ID/subscription"
```

Record status + check for `status` / `suspendedAt` fields.

Open `/stores` and `/stores/seed-store-1`.

- [ ] **Step 7: Subscriptions + plans**

```bash
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/subscriptions" | head -c 500
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/subscriptions/pending" | head -c 200
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/subscriptions/pending-payments" | head -c 500
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/plans" | head -c 500
```

Expected: `/pending` = 404 (frontend mismatch), `/pending-payments` = 200 with 1 pending payment row. Record.

Open `/subscriptions` and `/subscriptions/plans`.

- [ ] **Step 8: Announcements + audit-log**

```bash
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/announcements" | head -c 500
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/audit-log" | head -c 500
```

Expected: both 200. Announcements has 1 seeded row. Audit-log has rows from earlier admin actions (if any).

Open both pages in browser.

- [ ] **Step 9: Fill the results doc with observations from steps 3-8**

Edit `docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md`. Under each page heading, record:
- HTTP status per endpoint
- First-line summary of response shape
- Browser observations: render OK / console errors / missing data

Summary table at bottom with issue count.

- [ ] **Step 10: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md
git commit -m "docs(admin-panel-audit): Phase 1 audit results

Curl + browser audit of all 11 admin pages. See file for per-page
status, HTTP responses, and flagged mismatches. Phase 2 will fix each."
```

---

## Task 3: Fix dashboard URL mismatches (frontend only)

**Files:**
- Modify: `admin/app/(admin)/dashboard/page.tsx`

All 4 dashboard mismatches are pure URL renames.

- [ ] **Step 1: Apply 4 URL renames**

Open `admin/app/(admin)/dashboard/page.tsx`. Replace:

```
api.get('/admin/stats')                       →  api.get('/admin/dashboard')
api.get('/admin/stats/revenue')               →  api.get('/admin/revenue')
api.get('/admin/stats/registrations')         →  api.get('/admin/dashboard/registrations')
api.get('/admin/subscriptions/pending')       →  api.get('/admin/subscriptions/pending-payments')
```

- [ ] **Step 2: Typecheck**

Run: `cd /Users/latifrjdev/Downloads/Dukon/admin && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Browser verify**

Reload `http://localhost:3000/dashboard`. Expected: page renders with stats. Console has no 404s.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add admin/app/\(admin\)/dashboard/page.tsx
git commit -m "fix(admin-panel): align dashboard endpoints with backend

- /admin/stats → /admin/dashboard
- /admin/stats/revenue → /admin/revenue
- /admin/stats/registrations → /admin/dashboard/registrations
- /admin/subscriptions/pending → /admin/subscriptions/pending-payments

Part of admin panel audit Phase 2."
```

---

## Task 4: Fix subscriptions URL mismatches (frontend only)

**Files:**
- Modify: `admin/app/(admin)/subscriptions/page.tsx`

Payment approve/reject routes on the API are `:subId/approve-payment/:paymentId` but admin uses `payments/:id/approve`. Frontend needs both the subscription id and the payment id. The pending-payments response includes the parent subscription id, so the frontend already has both.

- [ ] **Step 1: Inspect the response shape the frontend expects**

Run: `grep -nE "pendingPayments|approveMutation|rejectMutation" admin/app/\(admin\)/subscriptions/page.tsx | head -20`

This shows current variable names. Each pending payment object should contain both `id` (payment id) and `subscriptionId` (parent subscription). Confirm by checking the response of `/admin/subscriptions/pending-payments` from the audit log.

- [ ] **Step 2: Apply URL renames**

```
api.get('/admin/subscriptions/pending')                         →  api.get('/admin/subscriptions/pending-payments')
api.put(`/admin/subscriptions/${id}/discount`, { discount })    →  api.put(`/admin/subscriptions/${id}/set-discount`, { discount })
api.put(`/admin/subscriptions/payments/${id}/approve`)          →  api.put(`/admin/subscriptions/${payment.subscriptionId}/approve-payment/${payment.id}`)
api.put(`/admin/subscriptions/payments/${id}/reject`, { reason })  →  api.put(`/admin/subscriptions/${payment.subscriptionId}/reject-payment/${payment.id}`, { reason })
```

The approve/reject mutations need `payment` (the whole row) instead of just `id`. Update the `mutationFn: (id)` → `mutationFn: (payment)` signature, and update call-sites (`.mutate(payment.id)` → `.mutate(payment)`).

- [ ] **Step 3: Typecheck + browser**

```bash
cd /Users/latifrjdev/Downloads/Dukon/admin && npx tsc --noEmit
```
Expected: no errors.

Open `http://localhost:3000/subscriptions`. Verify list loads. Click "Approve" on the seeded pending payment — expect 200.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add admin/app/\(admin\)/subscriptions/page.tsx
git commit -m "fix(admin-panel): align subscription endpoints with backend

- /admin/subscriptions/pending → /admin/subscriptions/pending-payments
- /admin/subscriptions/:id/discount → /admin/subscriptions/:id/set-discount
- /admin/subscriptions/payments/:id/approve → /admin/subscriptions/:subId/approve-payment/:payId
- /admin/subscriptions/payments/:id/reject → /admin/subscriptions/:subId/reject-payment/:payId

Approve/reject mutations now require the parent subscription id, which
is already present in the pending-payments response."
```

---

## Task 5: Add backend endpoints for missing user/store detail views

**Files:**
- Modify: `api/src/modules/admin/admin-users.controller.ts`
- Modify: `api/src/modules/admin/admin-stores.controller.ts`
- Modify: `api/src/modules/admin/admin.service.ts`

Admin's `/users/[id]` calls `GET /admin/users/:id/stores`, `/stores/[id]` calls `GET /admin/stores/:id/subscription`. Both missing. Implement as thin wrappers over existing queries.

- [ ] **Step 1: Add listUserStores to AdminService**

Open `api/src/modules/admin/admin.service.ts` and add a method (place after existing `getUserDetail`):

```typescript
async listUserStores(userId: string) {
  return this.prisma.store.findMany({
    where: { ownerId: userId },
    select: {
      id: true,
      name: true,
      currency: true,
      suspendedAt: true,
      createdAt: true,
      subscription: {
        select: { plan: true, status: true, expiresAt: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  });
}
```

If `suspendedAt` doesn't exist in schema, replace with whatever field represents suspend state (check `prisma/schema.prisma`).

- [ ] **Step 2: Add route handler to admin-users.controller.ts**

Insert after `getUserDetail`:

```typescript
@Get(':id/stores')
@ApiOperation({ summary: 'List stores owned by a user' })
listUserStores(@Param('id') id: string) {
  return this.adminService.listUserStores(id);
}
```

- [ ] **Step 3: Add getStoreSubscription to AdminService**

```typescript
async getStoreSubscription(storeId: string) {
  const sub = await this.prisma.subscription.findUnique({
    where: { storeId },
    include: {
      payments: {
        orderBy: { createdAt: 'desc' },
        take: 10,
      },
    },
  });
  if (!sub) throw new NotFoundException('Subscription not found for store');
  return sub;
}
```

Add `NotFoundException` to imports from `@nestjs/common` if missing.

- [ ] **Step 4: Add route handler to admin-stores.controller.ts**

After `getStoreDetail`:

```typescript
@Get(':id/subscription')
@ApiOperation({ summary: 'Get subscription for a store with recent payments' })
getStoreSubscription(@Param('id') id: string) {
  return this.adminService.getStoreSubscription(id);
}
```

- [ ] **Step 5: Typecheck**

Run: `cd /Users/latifrjdev/Downloads/Dukon/api && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Hot-restart API**

API already runs with `--watch`. Confirm it restarted cleanly:
```bash
tail -20 /tmp/api.log | grep "Nest application successfully started"
```
Expected: fresh "successfully started" line after your save.

- [ ] **Step 7: Smoke-test new endpoints**

```bash
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/users/<USER_ID>/stores" | head -c 300

curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/stores/seed-store-1/subscription" | head -c 500
```

Expected: both 200, with arrays/objects matching the service shapes.

- [ ] **Step 8: Browser verify**

Open `http://localhost:3000/users/<USER_ID>` and `http://localhost:3000/stores/seed-store-1`. Expected: both tabs render without error.

- [ ] **Step 9: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add api/src/modules/admin/admin-users.controller.ts \
        api/src/modules/admin/admin-stores.controller.ts \
        api/src/modules/admin/admin.service.ts
git commit -m "feat(admin-api): add user/stores and store/subscription endpoints

GET /admin/users/:id/stores returns all stores owned by the user.
GET /admin/stores/:id/subscription returns the subscription with the
last 10 payments. Both are consumed by the corresponding detail pages
in the admin panel."
```

---

## Task 6: Add announcement preview stub

**Files:**
- Modify: `api/src/modules/admin/admin-announcements.controller.ts`
- Modify: `api/src/modules/admin/admin.service.ts` (or wherever the service lives)

Admin posts to `/admin/announcements/preview` to render the message before sending. Real implementation needs Firebase template expansion; for audit purposes we return a deterministic stub that matches the shape.

- [ ] **Step 1: Inspect existing announcement controller**

Run: `cat api/src/modules/admin/admin-announcements.controller.ts | head -40`

Confirm there's no `/preview` route.

- [ ] **Step 2: Add preview handler**

In the announcements controller, after the existing `@Post()`:

```typescript
@Post('preview')
@ApiOperation({ summary: 'Preview an announcement — returns audience count and rendered text' })
async previewAnnouncement(@Body() dto: CreateAnnouncementDto) {
  return this.adminService.previewAnnouncement(dto);
}
```

- [ ] **Step 3: Add service stub**

In `admin.service.ts`:

```typescript
async previewAnnouncement(dto: CreateAnnouncementDto) {
  // TODO(admin-panel): replace stub with real Firebase template expansion + targeting count
  const audienceCount = await this.prisma.user.count({
    where: { isAdmin: false, blockedAt: null },
  });
  return {
    renderedTitle: dto.title,
    renderedBody: dto.body,
    audienceCount,
    estimatedDeliveryMinutes: 1,
  };
}
```

If `blockedAt` doesn't exist, drop that condition and count all non-admin users.

If `CreateAnnouncementDto` is in a different path, `import` it from there.

- [ ] **Step 4: Typecheck**

`cd /Users/latifrjdev/Downloads/Dukon/api && npx tsc --noEmit` — no errors.

- [ ] **Step 5: Smoke**

```bash
curl -s -w "\n%{http_code}\n" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H 'Content-Type: application/json' \
  -X POST "http://localhost:4455/api/admin/announcements/preview" \
  -d '{"title":"Hello","body":"Test preview","targetPlan":null}'
```
Expected: 200 with `{renderedTitle, renderedBody, audienceCount, estimatedDeliveryMinutes}`.

- [ ] **Step 6: Browser verify**

Open `http://localhost:3000/announcements`. Click preview on a draft. Expected: preview panel populates.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add api/src/modules/admin/admin-announcements.controller.ts \
        api/src/modules/admin/admin.service.ts
git commit -m "feat(admin-api): stub POST /admin/announcements/preview

Returns deterministic preview shape (renderedTitle, renderedBody,
audienceCount, estimatedDeliveryMinutes). Marked TODO for real Firebase
template expansion + targeting count."
```

---

## Task 7: Fix response DTO gaps flagged during audit

**Files (depend on audit findings — adjust per Phase 1 results):**
- Likely modify: `api/src/modules/admin/admin.service.ts` (Prisma select additions)
- Likely modify: `api/src/modules/admin/dto/admin-user-response.dto.ts` (if exists)
- Possibly modify: `admin/lib/types.ts` (if frontend types were stricter than response)

During audit, if a page reads `user.isActive` but the API returns `isBlocked` (or vice versa), align them here.

- [ ] **Step 1: Cross-reference audit findings**

Open `docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md`. For each ⚠️/❌ row tagged "DTO mismatch", list the missing field and the page that reads it.

- [ ] **Step 2: Add fields to Prisma select (in AdminService.listUsers / getUserDetail etc)**

Example: if users list page reads `user.isActive` but API select omits it, and schema has `blockedAt: DateTime?`:

```typescript
// admin.service.ts — inside listUsers select clause
select: {
  id: true,
  phone: true,
  name: true,
  email: true,
  isAdmin: true,
  blockedAt: true,        // ← add
  createdAt: true,
  _count: { select: { stores: true } },
},
```

Then map `isActive: !user.blockedAt` either in the service or in the frontend adapter. Prefer doing it server-side once.

Apply the same pattern for any other flagged mismatches (e.g. `store.status` derived from `suspendedAt`).

- [ ] **Step 3: Typecheck**

`cd /Users/latifrjdev/Downloads/Dukon/api && npx tsc --noEmit` — no errors.

- [ ] **Step 4: Smoke the affected endpoint**

Example:
```bash
curl -s -H "Authorization: Bearer $ADMIN_JWT" \
  "http://localhost:4455/api/admin/users" \
  | python3 -m json.tool | head -30
```
Expected: response now includes the new field.

- [ ] **Step 5: Browser verify**

Reload the affected page(s). Rows should now show the correct active/suspended/etc. state.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add api/src/modules/admin/admin.service.ts
git commit -m "fix(admin-api): expose blockedAt/suspendedAt to admin response DTOs

Admin panel list pages derive user.isActive and store.status from these
fields. They were omitted from Prisma select clauses. Added."
```

If no DTO gaps were found during audit, this task is a no-op — skip to Task 8.

---

## Task 8: Phase 3 — Final verification pass

**Files:**
- Modify: `docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md` (flip ❌ → ✅ rows)

Re-run every curl from Task 2, re-open every browser page, confirm all green.

- [ ] **Step 1: Refresh JWT**

```bash
ADMIN_JWT=$(curl -s -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992900000001","password":"fwr123456"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")
```

- [ ] **Step 2: Re-curl every endpoint from Task 2, steps 3–8**

All must return 200 (no 404, no 500). If any still fail, loop back to the appropriate fix task.

- [ ] **Step 3: Browser sweep**

Open every page in order:
- `/dashboard` — graphs + metric cards populated
- `/users` — list with the 3 users; toggle-admin + block buttons work
- `/users/<seed-user-1-id>` — user detail + their stores
- `/stores` — list with 2 stores
- `/stores/seed-store-1` — detail + subscription panel
- `/subscriptions` — active + pending tables
- `/subscriptions/plans` — plans editor form
- `/announcements` — list + preview panel
- `/audit-log` — recent admin actions from the session

In DevTools Network tab, confirm every XHR is 200. In Console, confirm no errors.

- [ ] **Step 4: Update audit results doc**

Flip every row to ✅. Update summary: `11/11 passing`. Add a final "Verified complete — 2026-04-23" section noting that the 4-phase audit is closed.

- [ ] **Step 5: Final commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/qa/2026-04-23-admin-panel-audit-results.md
git commit -m "docs(admin-panel-audit): mark complete — all 11 pages green

Phase 3 verification pass: every page loads, every endpoint returns 200,
no console errors. Seed data renders correctly across list + detail
views. Closes admin panel audit."
```

- [ ] **Step 6: Optional — push**

```bash
git push origin main
```

(Run only if you're happy pushing straight to main. Otherwise open a PR manually.)

---

## Execution notes

- **Hot restart is free on both sides.** NestJS runs with `--watch`; Next.js uses Turbopack. Just save and reload.
- **Don't commit ephemeral JWTs.** `$ADMIN_JWT` lives in your shell only; none of the commits reference it.
- **If Task 4's approve/reject refactor touches tests:** none exist for the admin panel yet — frontend has no test harness. Safe to skip test step.
- **If audit (Task 2) reveals significantly more than the pre-work matrix:** either add inline tasks here or split into a Task 7.1 / 7.2 per findings group. Don't try to cram 20 mismatches into one commit.
- **Don't run migrations during this sprint.** If audit reveals missing schema fields (rare — we didn't spot any in pre-work), scope it to a follow-up ticket. The plan assumes schema is already correct.
- **Commits tagged `fix(admin-panel):` or `feat(admin-api):`** for easy grep/revert later.
