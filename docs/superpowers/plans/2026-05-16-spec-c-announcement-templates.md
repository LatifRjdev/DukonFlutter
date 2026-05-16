# Spec C "Announcement Templates" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `previewAnnouncement` stub with real `{{path.to.field}}` template substitution + audience parity with `createAnnouncement` + per-user personalized render on send.

**Architecture:** Custom regex-based template helper (no new dep), shared `_resolveAnnouncementAudience` helper used by BOTH preview and create methods, per-user render before each `sendPush` call. No schema changes.

**Tech Stack:** NestJS 10 + Prisma 6.19 + Postgres 16. Firebase Admin SDK already integrated in `NotificationsService.sendPush`.

**Spec:** `docs/superpowers/specs/2026-05-16-spec-c-announcement-templates-design.md` (commit bf5ec2b).

---

## File Structure

**Create:**
- `api/src/modules/admin/announcements-template.ts` — pure `renderTemplate(template, vars)` helper + `AnnouncementVars` type
- `api/src/modules/admin/announcements-template.spec.ts` — unit tests for substitution edge cases

**Modify:**
- `api/src/modules/admin/admin.service.ts`:
  - extract private method `_resolveAnnouncementAudience(dto)` (returns array of `{userId, storeId, vars}`)
  - extract private method `_fakeVarsForEmptyAudience()` (returns synthetic vars for empty-audience preview)
  - refactor `previewAnnouncement` → use template + resolver
  - refactor `createAnnouncement` → use template + resolver + per-user render
- `api/src/modules/admin/admin.service.spec.ts` — add 3 tests:
  - audience parity (preview audienceCount equals createAnnouncement recipientCount given same dto)
  - per-user render (each FCM call gets a different rendered title when `{{user.name}}` differs across audience)
  - empty-audience preview returns sample with fake vars

**No schema changes. No new Prisma migration.**

---

## Task 1 — Template helper file + unit tests

**Files:**
- Create: `api/src/modules/admin/announcements-template.ts`
- Create: `api/src/modules/admin/announcements-template.spec.ts`

- [ ] **Step 1: Write failing tests first (TDD)**

Create `api/src/modules/admin/announcements-template.spec.ts`:

```typescript
import { renderTemplate, AnnouncementVars } from './announcements-template';

const sampleVars: AnnouncementVars = {
  user: { name: 'Алишер', phone: '+992900111222' },
  store: {
    name: 'Магазин №1',
    currency: 'TJS',
    subscription: { plan: 'BUSINESS', currentPeriodEnd: '2026-06-15' },
  },
};

describe('renderTemplate', () => {
  it('substitutes a single placeholder', () => {
    expect(renderTemplate('Hello {{user.name}}', sampleVars)).toBe(
      'Hello Алишер',
    );
  });

  it('substitutes multiple placeholders', () => {
    expect(
      renderTemplate('{{user.name}} → {{store.name}}', sampleVars),
    ).toBe('Алишер → Магазин №1');
  });

  it('walks nested paths', () => {
    expect(
      renderTemplate('Plan: {{store.subscription.plan}}', sampleVars),
    ).toBe('Plan: BUSINESS');
  });

  it('passes unknown placeholders through verbatim', () => {
    expect(renderTemplate('Hi {{user.email}}', sampleVars)).toBe(
      'Hi {{user.email}}',
    );
  });

  it('passes null / undefined leaves through verbatim', () => {
    const vars: any = { user: { name: null } };
    expect(renderTemplate('Hi {{user.name}}', vars)).toBe('Hi {{user.name}}');
  });

  it('handles a template with no placeholders', () => {
    expect(renderTemplate('plain text', sampleVars)).toBe('plain text');
  });

  it('does NOT recursively expand placeholders in substituted values', () => {
    const vars: any = { user: { name: '{{secret}}' }, secret: 'leaked' };
    // Single-pass: the literal '{{secret}}' is inserted, not expanded
    expect(renderTemplate('Hi {{user.name}}', vars)).toBe('Hi {{secret}}');
  });

  it('coerces numeric values to string', () => {
    const vars: any = { count: 42 };
    expect(renderTemplate('You have {{count}} items', vars)).toBe(
      'You have 42 items',
    );
  });
});
```

- [ ] **Step 2: Run tests, expect FAIL (file does not exist)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- announcements-template 2>&1 | tail -10
```
Expected: cannot find module `./announcements-template`.

- [ ] **Step 3: Write the implementation**

Create `api/src/modules/admin/announcements-template.ts`:

```typescript
// api/src/modules/admin/announcements-template.ts
//
// Spec C: pure template helper for {{path.to.field}} substitution
// in admin announcements. Single-pass (no recursive expansion to
// prevent injection from substituted values). No new dep.
export interface AnnouncementVars {
  user: { name: string; phone: string };
  store: {
    name: string;
    currency: string;
    subscription: { plan: string; currentPeriodEnd: string };
  };
}

/**
 * Substitutes `{{path.to.field}}` placeholders in `template` with
 * values from `vars`. Single-pass (no recursive expansion).
 * Unknown placeholders pass through verbatim.
 *
 *   renderTemplate('Hello {{user.name}}', { user: { name: 'Alisher' } })
 *     === 'Hello Alisher'
 */
export function renderTemplate(
  template: string,
  vars: Record<string, unknown>,
): string {
  return template.replace(/\{\{([\w.]+)\}\}/g, (match, path: string) => {
    const value = path
      .split('.')
      .reduce<unknown>(
        (acc, key) =>
          acc && typeof acc === 'object'
            ? (acc as Record<string, unknown>)[key]
            : undefined,
        vars,
      );
    if (value === undefined || value === null) return match;
    return String(value);
  });
}
```

- [ ] **Step 4: Run tests, expect PASS**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- announcements-template 2>&1 | tail -10
```
Expected: 8 passed.

- [ ] **Step 5: Verify TS compiles cleanly**

```bash
npx tsc --noEmit 2>&1 | grep "announcements-template" | head
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/announcements-template.ts api/src/modules/admin/announcements-template.spec.ts
git commit -m "feat(admin): renderTemplate helper for announcement placeholders

Spec C: pure {{path.to.field}} substitution. Single-pass to
prevent injection from substituted values. Unknown placeholders
pass through verbatim. 8 unit tests covering edge cases."
```

---

## Task 2 — Audience resolver helper

**Files:**
- Modify: `api/src/modules/admin/admin.service.ts`

- [ ] **Step 1: Read the current createAnnouncement to understand existing audience logic**

```bash
sed -n '430,495p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/admin/admin.service.ts
```

Note:
- Existing logic filters `subscription` by `targetPlan + targetStatus` if either set, OR all active non-admin users
- Already has dedup via `[...new Set(userIds)]`
- Already maps `userId → storeId` via separate query

- [ ] **Step 2: Add the helper method**

Add this method as a private method inside `AdminService` class (place it just BEFORE `createAnnouncement`):

```typescript
  // Spec C: shared audience resolver — used by both preview and
  // create. Returns one record per recipient with userId, primary
  // storeId (for sendPush), and pre-built vars (for renderTemplate).
  // Dedupes by userId in case a user owns multiple stores matching
  // the filter.
  private async _resolveAnnouncementAudience(
    dto: CreateAnnouncementDto,
  ): Promise<
    Array<{
      userId: string;
      storeId: string;
      vars: import('./announcements-template').AnnouncementVars;
    }>
  > {
    const hasFilter = dto.targetPlan || dto.targetStatus;

    // 1. Fetch the candidate stores with their owner + subscription.
    const stores = hasFilter
      ? await this.prisma.store.findMany({
          where: {
            isActive: true,
            subscription: {
              ...(dto.targetPlan && { plan: dto.targetPlan }),
              ...(dto.targetStatus && { status: dto.targetStatus }),
            },
            owner: { isActive: true, isAdmin: false },
          },
          include: {
            owner: { select: { id: true, name: true, phone: true } },
            subscription: {
              select: { plan: true, currentPeriodEnd: true },
            },
          },
        })
      : await this.prisma.store.findMany({
          where: {
            isActive: true,
            owner: { isActive: true, isAdmin: false },
          },
          include: {
            owner: { select: { id: true, name: true, phone: true } },
            subscription: {
              select: { plan: true, currentPeriodEnd: true },
            },
          },
        });

    // 2. Dedupe by ownerId — pick FIRST store per user as the
    // primary (sendPush requires a storeId; if user has multiple,
    // we just need one).
    const seen = new Set<string>();
    const audience: Array<{
      userId: string;
      storeId: string;
      vars: import('./announcements-template').AnnouncementVars;
    }> = [];

    for (const store of stores) {
      if (seen.has(store.ownerId)) continue;
      seen.add(store.ownerId);

      audience.push({
        userId: store.ownerId,
        storeId: store.id,
        vars: {
          user: {
            name: store.owner.name,
            phone: store.owner.phone,
          },
          store: {
            name: store.name,
            currency: store.currency,
            subscription: {
              plan: store.subscription?.plan ?? 'START',
              currentPeriodEnd: store.subscription?.currentPeriodEnd
                ? store.subscription.currentPeriodEnd.toISOString().slice(0, 10)
                : '—',
            },
          },
        },
      });
    }

    return audience;
  }

  private _fakeVarsForEmptyAudience(): import('./announcements-template').AnnouncementVars {
    return {
      user: { name: 'Имя', phone: '+992XXXXXXXXX' },
      store: {
        name: 'Магазин',
        currency: 'TJS',
        subscription: { plan: 'START', currentPeriodEnd: '—' },
      },
    };
  }
```

Add the import at the top of the file (alongside existing imports):
```typescript
import { renderTemplate, AnnouncementVars } from './announcements-template';
```

(Then the inline `import('./announcements-template').AnnouncementVars` types in the method signatures can be simplified to `AnnouncementVars` — do the cleanup.)

- [ ] **Step 3: Verify TS compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "admin.service" | head
```
Expected: no output (helpers don't break anything; not used yet).

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/admin.service.ts
git commit -m "feat(admin): _resolveAnnouncementAudience helper

Spec C prep: shared audience resolver to be used by both preview
and create. Returns userId, primary storeId, and pre-built vars
for renderTemplate. Dedupes by ownerId. Filters by plan AND
status (preview today only filters by plan — that drift fix
ships in Tasks 3-4)."
```

---

## Task 3 — Refactor `previewAnnouncement`

**Files:**
- Modify: `api/src/modules/admin/admin.service.ts`

- [ ] **Step 1: Replace the body of `previewAnnouncement`**

Find the existing method:
```typescript
async previewAnnouncement(dto: CreateAnnouncementDto) {
  // TODO(admin-panel): replace stub with real Firebase template expansion
  // + proper targeting by plan/status once the delivery pipeline exists.
  const whereClause: any = { isAdmin: false, isActive: true };
  if (dto.targetPlan) {
    whereClause.ownedStores = {
      some: { subscription: { plan: dto.targetPlan } },
    };
  }
  const audienceCount = await this.prisma.user.count({ where: whereClause });
  return {
    renderedTitle: dto.title,
    renderedBody: dto.body,
    audienceCount,
    estimatedDeliveryMinutes: 1,
  };
}
```

Replace ENTIRELY with:
```typescript
async previewAnnouncement(dto: CreateAnnouncementDto) {
  // Spec C: real audience resolver + template expansion.
  const audience = await this._resolveAnnouncementAudience(dto);
  const sample = audience[0]?.vars ?? this._fakeVarsForEmptyAudience();

  const renderedTitle = renderTemplate(dto.title, sample);
  const renderedBody = renderTemplate(dto.body, sample);

  // FCM Admin SDK throughput on a single Node process: ~100 users/sec
  // (10 parallel batches at ~50ms each). 6000 users/min, rounded up.
  // Min 1 minute so the UI never shows 0.
  const estimatedDeliveryMinutes = Math.max(
    1,
    Math.ceil(audience.length / 6000),
  );

  return {
    renderedTitle,
    renderedBody,
    audienceCount: audience.length,
    estimatedDeliveryMinutes,
  };
}
```

- [ ] **Step 2: Verify TS compiles**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "admin.service" | head
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/admin.service.ts
git commit -m "fix(admin): previewAnnouncement uses real template + audience

Spec C: replaces the cheap-approximation stub. Audience now
matches createAnnouncement exactly (plan AND status filters).
Title/body run through renderTemplate against the first
audience member's vars (or synthetic vars when empty).
estimatedDeliveryMinutes scales with audience size."
```

---

## Task 4 — Refactor `createAnnouncement` with per-user render

**Files:**
- Modify: `api/src/modules/admin/admin.service.ts`

- [ ] **Step 1: Replace the body of `createAnnouncement`**

Find the existing `createAnnouncement(dto, adminId)`. Replace its body with:

```typescript
async createAnnouncement(dto: CreateAnnouncementDto, adminId: string) {
  // Spec C: shared audience resolver + per-user template render.
  // Each recipient gets THEIR rendered title/body via FCM. The
  // raw template is stored on Announcement so the row mirrors
  // what the admin typed (not the personalized expansion).
  const audience = await this._resolveAnnouncementAudience(dto);

  await Promise.allSettled(
    audience.map(({ userId, storeId, vars }) => {
      const renderedTitle = renderTemplate(dto.title, vars);
      const renderedBody = renderTemplate(dto.body, vars);
      return this.notifications.sendPush(
        userId,
        renderedTitle,
        renderedBody,
        'ANNOUNCEMENT',
        storeId,
      );
    }),
  );

  return this.prisma.announcement.create({
    data: {
      title: dto.title,        // raw template — admin sees what was authored
      body: dto.body,
      targetPlan: dto.targetPlan,
      targetStatus: dto.targetStatus,
      sentBy: adminId,
      recipientCount: audience.length,
    },
  });
}
```

Delete the dead helper code that previously built `userIds` + `storeByUser` (the resolver replaces all of it).

- [ ] **Step 2: Verify TS compiles + audit log call still wired**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "admin.service" | head
```
Expected: no output.

If the original `createAnnouncement` had an `audit.record(...)` call AT THE END (it might), preserve it — add it after the `prisma.announcement.create` and use `recipientCount` from `audience.length`.

```bash
grep -n "audit.record\|AuditLogService" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/admin/admin.service.ts | head
```
If grep shows audit calls in the original `createAnnouncement` body, port them over.

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/admin.service.ts
git commit -m "refactor(admin): createAnnouncement renders per-user

Spec C: each recipient gets their rendered title/body via FCM
(was: same plain text for everyone, placeholders unsubstituted).
DB row stores the raw template so admin can see what was
authored, not 1000 personalized expansions."
```

---

## Task 5 — Service spec tests for audience parity + per-user render

**Files:**
- Modify: `api/src/modules/admin/admin.service.spec.ts`

- [ ] **Step 1: Inspect existing spec to find the right pattern**

```bash
grep -n "describe\|it(\|previewAnnouncement\|createAnnouncement\|notifications\.sendPush" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/admin/admin.service.spec.ts | head -30
```

Look for an existing announcement-related describe block, OR for the test setup pattern (Prisma mock + NotificationsService mock).

- [ ] **Step 2: Add 3 tests in a new describe block**

If there's no existing announcements describe block, add one. Otherwise extend it.

Add this block inside the spec file (before the closing `});` of the top-level `describe`):

```typescript
describe('announcements (Spec C)', () => {
  // Test scaffold mirrors the existing pattern in this spec file —
  // adapt to the actual mock helper names if they differ.

  it('preview audienceCount matches createAnnouncement recipientCount', async () => {
    // Setup: 2 BUSINESS-plan stores owned by 2 different users
    const fakeStores = [
      {
        id: 's1', name: 'Store 1', currency: 'TJS', ownerId: 'u1',
        owner: { id: 'u1', name: 'Алишер', phone: '+992900000001' },
        subscription: { plan: 'BUSINESS', currentPeriodEnd: new Date('2026-06-01') },
      },
      {
        id: 's2', name: 'Store 2', currency: 'TJS', ownerId: 'u2',
        owner: { id: 'u2', name: 'Зарина', phone: '+992900000002' },
        subscription: { plan: 'BUSINESS', currentPeriodEnd: new Date('2026-06-01') },
      },
    ];
    (prisma.store.findMany as jest.Mock).mockResolvedValue(fakeStores);
    (prisma.announcement.create as jest.Mock).mockResolvedValue({ id: 'a1' });

    const dto = { title: 'Hi {{user.name}}', body: 'Plan {{store.subscription.plan}}', targetPlan: 'BUSINESS' as const };

    const preview = await service.previewAnnouncement(dto as any);
    const created = await service.createAnnouncement(dto as any, 'admin-1');

    expect(preview.audienceCount).toBe(2);
    expect((created as any).id).toBe('a1');
    // The Prisma create call's recipientCount must match preview audienceCount
    const createCall = (prisma.announcement.create as jest.Mock).mock.calls[0][0];
    expect(createCall.data.recipientCount).toBe(preview.audienceCount);
  });

  it('createAnnouncement renders title/body per user (different names)', async () => {
    const fakeStores = [
      {
        id: 's1', name: 'Store 1', currency: 'TJS', ownerId: 'u1',
        owner: { id: 'u1', name: 'Алишер', phone: '+992900000001' },
        subscription: { plan: 'BUSINESS', currentPeriodEnd: new Date('2026-06-01') },
      },
      {
        id: 's2', name: 'Store 2', currency: 'TJS', ownerId: 'u2',
        owner: { id: 'u2', name: 'Зарина', phone: '+992900000002' },
        subscription: { plan: 'BUSINESS', currentPeriodEnd: new Date('2026-06-01') },
      },
    ];
    (prisma.store.findMany as jest.Mock).mockResolvedValue(fakeStores);
    (prisma.announcement.create as jest.Mock).mockResolvedValue({ id: 'a1' });

    const sendPushSpy = notifications.sendPush as jest.Mock;
    sendPushSpy.mockClear();

    await service.createAnnouncement(
      { title: 'Hi {{user.name}}', body: 'Hello', targetPlan: 'BUSINESS' as const } as any,
      'admin-1',
    );

    expect(sendPushSpy).toHaveBeenCalledTimes(2);
    // First call: user u1 → 'Hi Алишер'
    expect(sendPushSpy.mock.calls[0]).toEqual(
      expect.arrayContaining(['u1', 'Hi Алишер']),
    );
    // Second call: user u2 → 'Hi Зарина'
    expect(sendPushSpy.mock.calls[1]).toEqual(
      expect.arrayContaining(['u2', 'Hi Зарина']),
    );
  });

  it('preview returns sample with fake vars when audience is empty', async () => {
    (prisma.store.findMany as jest.Mock).mockResolvedValue([]);

    const preview = await service.previewAnnouncement({
      title: 'Hello {{user.name}}',
      body: 'plan {{store.subscription.plan}}',
      targetPlan: 'PREMIUM' as const,
    } as any);

    expect(preview.audienceCount).toBe(0);
    // Synthetic vars: user.name = 'Имя', store.subscription.plan = 'START'
    expect(preview.renderedTitle).toBe('Hello Имя');
    expect(preview.renderedBody).toBe('plan START');
  });
});
```

**ADAPT** to the actual test scaffold — variable names like `prisma`, `notifications`, `service` may differ. Read the file's existing setup first and use the same names.

- [ ] **Step 3: Run the tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- admin.service 2>&1 | tail -10
```
Expected: 3 new tests pass, existing tests unchanged.

If tests fail because of mock-shape mismatch, fix the mock setup to match what the new code calls. The most likely failure: the new `_resolveAnnouncementAudience` calls `prisma.store.findMany` but the existing spec mocked `prisma.user.findMany` and `prisma.subscription.findMany`. Update the mock to also stub `prisma.store.findMany`.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/admin/admin.service.spec.ts
git commit -m "test(admin): announcements audience parity + per-user render

Spec C: 3 new tests prove (1) preview.audienceCount matches
create.recipientCount on the same dto, (2) createAnnouncement
sends a different rendered title to each user when {{user.name}}
varies, (3) empty-audience preview falls back to synthetic vars
so the admin still sees what placeholders look like."
```

---

## Task 6 — Final verification gate

**Files:**
- None (verification only)

- [ ] **Step 1: Full test gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v "\.spec\." | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail
```
Expected:
- 0 tsc errors (non-spec)
- ≥215 unit tests pass (was 205, +8 template + 3 service = 11 new — total ≥216)
- ≥11 e2e tests pass (no new e2e — endpoints unchanged shape)

- [ ] **Step 2: Live probe — preview shows real personalization**

```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done

# Find admin phone
ADMIN_PHONE=$(docker exec dukonpro-db psql -U dukonpro -d dukonpro -t -A -c \
  "SELECT phone FROM users WHERE \"isAdmin\"=true LIMIT 1;")
echo "Admin: $ADMIN_PHONE"

T_ADMIN=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"phone\":\"$ADMIN_PHONE\",\"password\":\"admin123\"}" | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')

# Preview with placeholder
curl -s -X POST http://localhost:4455/api/admin/announcements/preview \
  -H "Authorization: Bearer $T_ADMIN" -H 'Content-Type: application/json' \
  -d '{"title":"Привет {{user.name}}","body":"Ваш план: {{store.subscription.plan}}","targetPlan":"BUSINESS"}' \
  -w "\nHTTP=%{http_code}\n" | python3 -m json.tool 2>&1 | head -10
```
Expected:
- HTTP 200
- `renderedTitle: "Привет <real-name>"` (NOT "Привет {{user.name}}")
- `renderedBody: "Ваш план: BUSINESS"`
- `audienceCount: <integer>` matching the count of BUSINESS-plan store owners

- [ ] **Step 3: Live probe — preview audienceCount equals create recipientCount**

(Skip the actual create — just verify both methods are called against same dto and counts match. Already covered by Task 5 unit test, but as a smoke verify:)

```bash
# Re-run preview to capture audienceCount
PREVIEW_COUNT=$(curl -sf -X POST http://localhost:4455/api/admin/announcements/preview \
  -H "Authorization: Bearer $T_ADMIN" -H 'Content-Type: application/json' \
  -d '{"title":"x","body":"y","targetPlan":"BUSINESS"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("audienceCount",-1))')
echo "Preview reports $PREVIEW_COUNT BUSINESS users"

# Compare to a direct DB count
DB_COUNT=$(docker exec dukonpro-db psql -U dukonpro -d dukonpro -t -A -c \
  "SELECT COUNT(DISTINCT s.\"ownerId\")
   FROM stores s
   JOIN subscriptions sub ON sub.\"storeId\" = s.id
   JOIN users u ON u.id = s.\"ownerId\"
   WHERE sub.plan = 'BUSINESS' AND s.\"isActive\" = true
     AND u.\"isActive\" = true AND u.\"isAdmin\" = false;")
echo "DB direct count: $DB_COUNT"
```
Expected: `PREVIEW_COUNT == DB_COUNT` (both numbers match).

- [ ] **Step 4: Final commit (only if anything uncommitted)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git status --short
git log --oneline bf5ec2b..HEAD | head -10
```

If clean, just print the commit list.

---

## Self-Review

**Spec coverage:**
- ✅ Template helper (Spec section A) — Task 1 (write+test)
- ✅ Audience resolver (Spec section B) — Task 2
- ✅ `previewAnnouncement` refactor (Spec section C) — Task 3
- ✅ `createAnnouncement` refactor with per-user render (Spec section D) — Task 4
- ✅ Audience parity + per-user render tests — Task 5
- ✅ Final test gate — Task 6
- ✅ Acceptance criteria from spec mapped:
  - audience parity → Task 5 test 1
  - per-user render → Task 5 test 2
  - empty-audience preview sample → Task 5 test 3
  - Live probe matches DB count → Task 6 step 3

**Type / name consistency:**
- `renderTemplate(template, vars)` defined Task 1 → consumed Task 3 + Task 4 ✓
- `AnnouncementVars` type defined Task 1 → used in Task 2 helper signatures ✓
- `_resolveAnnouncementAudience` defined Task 2 → consumed Task 3 + Task 4 ✓
- `_fakeVarsForEmptyAudience` defined Task 2 → consumed Task 3 ✓

**Placeholders:** none. Each step has concrete code or shell commands. The "ADAPT to the actual test scaffold" note in Task 5 is a guardrail, not a placeholder — the test code IS shown, with explicit instruction to rename mock vars if needed.

Plan complete and saved to `docs/superpowers/plans/2026-05-16-spec-c-announcement-templates.md`.
