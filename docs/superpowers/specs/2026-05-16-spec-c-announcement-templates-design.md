# Design — Spec C "Announcement Templates"

**Date:** 2026-05-16
**Scope:** Replace `previewAnnouncement` stub with a real template
engine + audience parity with `createAnnouncement` + per-user
personalization. Firebase Admin SDK is ALREADY integrated in
`NotificationsService.sendPush` — not in scope to "build from
scratch".
**Decisions:** Template syntax = custom `{{path.to.field}}` regex
substitution (no new dep). Per-user render. Audience resolver
shared across both methods.

## Summary

The TODO in `admin.service.ts` framed this as "build Firebase
template engine". Reality is narrower: Firebase already sends
real pushes via `NotificationsService.sendPush`, the announcement
flow already targets users by plan/status. What's missing is
(a) template variable substitution so `{{user.name}}` works,
(b) audience parity between preview and create (preview ignores
`targetStatus` today), and (c) realistic delivery time estimate.

One sub-section, ~1.5 days, no schema changes.

## Problem

In `api/src/modules/admin/admin.service.ts`:

```typescript
async previewAnnouncement(dto: CreateAnnouncementDto) {
  // TODO(admin-panel): replace stub with real Firebase template
  // expansion + proper targeting by plan/status once the delivery
  // pipeline exists.
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

Three issues:
1. **No template expansion**: `{{user.name}}` in title/body is sent
   to recipients verbatim, breaking personalization.
2. **Audience drift**: `previewAnnouncement` filters by `targetPlan`
   only; `createAnnouncement` filters by `targetPlan` AND
   `targetStatus`. Preview overestimates audience when status filter
   is active.
3. **Hardcoded delivery estimate**: always 1 minute regardless of
   recipient count.

## Architecture

### A. Template engine

**New file:** `api/src/modules/admin/announcements-template.ts`

Pure function, no NestJS DI:

```typescript
export interface AnnouncementVars {
  user: { name: string; phone: string };
  store: {
    name: string;
    currency: string;
    subscription: { plan: string; currentPeriodEnd: string };
  };
}

/**
 * Substitutes {{path.to.field}} placeholders in `template` with
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
    const value = path.split('.').reduce<unknown>(
      (acc, key) => (acc && typeof acc === 'object'
        ? (acc as Record<string, unknown>)[key]
        : undefined),
      vars,
    );
    return value === undefined || value === null ? match : String(value);
  });
}
```

Edge cases handled:
- Unknown path → literal pass-through (no throw)
- `null`/`undefined` → literal pass-through
- Numeric/boolean → coerced via `String()`
- Single-pass — `{{user.name}}` containing `{{`-syntax in its value
  is NOT recursively expanded (prevents injection)

### B. Audience resolver

**Refactor in `admin.service.ts`:** new private method
`_resolveAnnouncementAudience(dto: CreateAnnouncementDto)`.

Returns:
```typescript
Array<{
  userId: string;
  storeId: string;  // primary store for sendPush()
  vars: AnnouncementVars;  // pre-built for renderTemplate
}>
```

Logic:
1. If `targetPlan` OR `targetStatus` set:
   - `prisma.subscription.findMany({ where: { plan?, status? }, include: { store: { include: { owner: true } } } })`
2. Else:
   - `prisma.user.findMany({ where: { isActive: true, isAdmin: false }, include: { ownedStores: { take: 1, include: { subscription: true } } } })`
3. Dedupe by `userId` (a user with multiple stores on the target
   plan should only receive one notification)
4. Build `vars` from the user + their primary store + subscription

Both `createAnnouncement` AND `previewAnnouncement` call this
helper. Drift becomes structurally impossible.

### C. `previewAnnouncement` refactor

```typescript
async previewAnnouncement(dto: CreateAnnouncementDto) {
  const audience = await this._resolveAnnouncementAudience(dto);
  const sample = audience[0]?.vars ?? this._fakeVarsForEmptyAudience();

  const renderedTitle = renderTemplate(dto.title, sample);
  const renderedBody = renderTemplate(dto.body, sample);

  // Estimate: FCM Admin SDK batches 500 tokens per call but practical
  // throughput on a single Node process is ~10 parallel batches at
  // ~50ms each = 100 users / sec. Round up to whole minutes.
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

private _fakeVarsForEmptyAudience(): AnnouncementVars {
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

Empty-audience case: preview still renders something meaningful so
admin sees what placeholder substitution looks like.

### D. `createAnnouncement` refactor

```typescript
async createAnnouncement(dto: CreateAnnouncementDto, adminId: string) {
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
      title: dto.title,        // raw template
      body: dto.body,          // raw template
      targetPlan: dto.targetPlan,
      targetStatus: dto.targetStatus,
      sentBy: adminId,
      recipientCount: audience.length,
    },
  });
}
```

Key change: each user gets THEIR rendered title/body, not the same
text. DB stores the raw template (so admin can see what was sent
without per-user explosion).

## Files touched

**Create:**
- `api/src/modules/admin/announcements-template.ts` — pure template helper
- `api/src/modules/admin/announcements-template.spec.ts` — unit tests for substitution

**Modify:**
- `api/src/modules/admin/admin.service.ts`:
  - new private method `_resolveAnnouncementAudience`
  - new private method `_fakeVarsForEmptyAudience`
  - refactor `previewAnnouncement` to use template + resolver
  - refactor `createAnnouncement` to use template + resolver + per-user render
  - replace literal-stub TODO with one-line comment pointing to the new helper
- `api/src/modules/admin/admin.service.spec.ts` — extend with:
  - audience parity test (preview count == create count)
  - per-user render test (different recipients get different rendered text)
  - empty-audience preview returns sample with fake vars

**Schema:** no changes. `Announcement` table stores raw templates as before.

## Acceptance

- `npm test` ≥207 unit (was 205, +2: template + audience tests)
- `npm run test:e2e` ≥11 (no new e2e — endpoints unchanged shape)
- 0 tsc errors
- Live probe:
  - `POST /admin/announcements/preview {title:"Привет {{user.name}}", body:"План {{store.subscription.plan}}", targetPlan:"BUSINESS"}` returns `renderedTitle: "Привет <real-name>"` + accurate count
  - `POST /admin/announcements {title:"Привет {{user.name}}", body:"...", targetPlan:"BUSINESS"}` actually sends personalized FCM (visible in `dukon-api.log` with `FCM sent to N/M devices`)
  - DB `announcements.title` retains the raw template (`'Привет {{user.name}}'`) not rendered text

## Out of scope

- Handlebars / Lodash template engine (custom regex is sufficient
  for our `{{path.to.field}}` needs; no loops, no conditionals)
- HTML escaping (FCM displays plain text — no XSS surface)
- A/B testing templates
- Scheduled / delayed announcements
- Per-user opt-in for promotional vs. transactional categories
  (already handled at FCM level via topic subscriptions if needed
  later)
- Rate limiting (firebase-admin SDK handles its own throttling)
- Recursive template expansion (security gap; explicitly single-pass)

## Risks

- **`targetStatus` filter change in preview is technically a behavior
  change.** Today preview reports MORE users than create actually
  notifies (when status filter active). After fix, preview matches
  create exactly. Mitigation: this is the BUG, not a regression —
  document in the commit message.
- **`Announcement.recipientCount` snapshot stays the same** — counted
  from `audience.length` at create time. No migration. Old rows keep
  their existing counts.
- **Template variables drift** — if a future field rename
  (`store.name` → `store.title`) breaks `{{store.name}}`, existing
  drafted templates render the literal placeholder. Mitigation:
  test asserting all 6 documented placeholders resolve against a
  realistic vars shape.

## Test results gate

After implementation:
- API: `npm test` (≥207 unit) + `npm run test:e2e` (≥11)
- 0 tsc errors
- Manual: 2 admin curls (preview + send) demonstrate per-user render
- Audit doc remains untouched (no schema migration)
