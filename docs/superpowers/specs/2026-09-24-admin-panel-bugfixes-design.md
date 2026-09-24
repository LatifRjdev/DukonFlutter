# Admin Panel — Critical Action Bugs — Design

**Context.** Immediately after merging `feature/admin-panel-real-data` (which fixed
the panel's *read* paths — dashboard stats, list pages, announcements history),
a full click-through of every *write* action in the admin panel (`admin/`)
was performed against the real backend (Playwright + direct API calls to
cross-check every UI-reported success/failure against the actual HTTP
response). Five defects were found and root-caused by reproducing each one
with `curl` against the real running backend — not guessed.

**Goal.** Fix all five so that every mutating action in the admin panel
(tariffs, announcements, store transfer, subscription plan changes, direct
messages) actually performs the change it claims to, and the admin sees an
accurate success/failure signal.

## Findings and fixes

### 1. Critical: Tariffs page — blank plan names, Save always fails

`admin/lib/types.ts`'s `Plan` interface declares `id: string`, `name: string`,
`maxStores: number`. The actual backend response
(`GET /admin/plans` → `admin.service.ts` `listPlans()`) returns rows shaped
`{ plan: SubscriptionPlan, price, maxProducts, maxStaff, maxDiscounts,
has*... }` — there is no `id` field, no `name` field (the plan identifier is
called `plan`), and `maxStores` was deliberately dropped from the schema in
Sprint D.1 (comment in `update-plan.dto.ts`: "maxStores dropped in 2026-05").

Two independent symptoms follow from this one type mismatch:

- `PlanCard` renders `<CardTitle>{plan.name}</CardTitle>` — `plan.name` is
  `undefined` for all three cards, so every card header is blank. Confirmed
  visually: the "Тарифы" page shows three cards with no START/BUSINESS/PREMIUM
  label at all.
- `saveMutation` does `api.put(`/admin/plans/${plan.id}`, plan)` — `plan.id`
  is `undefined`, so every save request is literally
  `PUT /admin/plans/undefined`, and the body is the *entire* stale `Plan`
  object, including `id`, `name`, `maxStores` — none of which exist on
  `UpdatePlanDto`. The backend's global `RuValidationPipe` runs with
  `whitelist: true, forbidNonWhitelisted: true` (`api/src/main.ts:114`), so
  the request always 400s:
  `["Поле «id» не разрешено...", "Поле «name» не разрешено...",
  "Поле «maxStores» не разрешено..."]`. Reproduced directly with `curl`.

**Fix:**
- `admin/lib/types.ts`: rewrite `Plan` to match the real response —
  `{ plan: SubscriptionPlan, price, maxProducts, maxStaff, maxDiscounts,
  hasReportsAll, hasExport, hasTelegram, hasAllPush, hasDelivery,
  hasInventory, hasEcommerceIntegration, hasZakat, hasInvestments,
  hasLoyalty, hasBatchProfitability }`. No `id`, no `name`, no `maxStores`.
- `admin/app/(admin)/subscriptions/plans/page.tsx`:
  - `PlanCard`'s title renders `plan.plan` instead of `plan.name`.
  - `config` lookup (`PLAN_CONFIGS.find((c) => c.key === plan.name)`) keys
    off `plan.plan`.
  - Remove the "Макс. магазинов" input entirely — it edits a field
    (`maxStores`) that no longer exists on the backend; keeping a dead input
    that silently does nothing is worse than not having it (matches the
    project's "no half-finished implementations" rule).
  - `saveMutation` PUTs to `/admin/plans/${plan.plan}` and sends **only**
    the fields `UpdatePlanDto` accepts — build the body explicitly
    (`{ price, maxProducts, maxStaff, maxDiscounts, hasReportsAll, ...
    }`), not a spread of the whole local state object, so a future stray
    field on `Plan` can't silently reintroduce this same bug.

### 2. Critical: Announcements — preview (and therefore send) always fails

`admin/app/(admin)/announcements/page.tsx`'s `previewMutation` calls
`api.post('/admin/announcements/preview', { targetPlan, targetStatus })` —
omitting `title` and `body`, even though the admin has already typed both
into the form and they're available in component state. The backend's
`CreateAnnouncementDto` (used by both `/preview` and the real send) requires
`title` and `body` (`@IsNotEmpty()`). Every preview call 400s
(`"title should not be empty"` / `"body should not be empty"`, translated),
which fires *before* the actual `POST /admin/announcements` — the admin
never reaches the real send. Reproduced directly with `curl`.

**Fix:** include `title` and `body` in the preview payload, matching what
`handleSend` already validates non-empty just above the call:
```ts
api.post('/admin/announcements/preview', {
  title,
  body,
  targetPlan: targetPlan === 'all' ? undefined : targetPlan,
  targetStatus: targetStatus === 'all' ? undefined : targetStatus,
})
```

### 3. Critical: Store transfer — wrong field name, always fails

Both places "Передать владение" exists —
`admin/app/(admin)/stores/page.tsx:91` and
`admin/app/(admin)/stores/[id]/page.tsx:79` — call
`api.put(`/admin/stores/${id}/transfer`, { userId })`. The backend's
`TransferStoreDto` requires `newOwnerId`. Every transfer 400s
(`"Поле «userId» не разрешено", "Поле «newOwnerId» не должно быть пустым"`).
Reproduced directly with `curl` (payload `{userId}` → 400; identical request
with `{newOwnerId}` → 200, store ownership actually changes).

**Fix:** rename the payload key to `newOwnerId` in both mutation calls. No
other change — the rest of each mutation (dialog state, invalidation,
toasts) is already correct, since it was never reached.

### 4. Critical: Subscription plan change — wrong field name, always fails

`admin/app/(admin)/subscriptions/page.tsx:110`'s `changePlanMutation` calls
`api.put(`/admin/subscriptions/${id}/change-plan`, { planId })`. The
backend's `ChangePlanDto` requires `plan`. Every change-plan action 400s the
same way as #3. Reproduced directly with `curl` (payload `{planId}` → 400;
`{plan}` → 200, plan actually changes).

**Fix:** rename the payload key to `plan` in the mutation call, and rename
the local variable/type it's built from (`{ id, planId }` →
`{ id, plan }`) so the mismatch can't silently come back if someone edits
one side without the other.

### 5. Medium: "Отправить сообщение" always shows an error toast despite succeeding

`admin/lib/api.ts:38`'s `apiFetch` unconditionally does `return res.json();`
on any `res.ok` response. `POST /admin/notifications/direct`
(`admin.service.ts` `sendDirectNotification()`) returns `Promise<void>` —
NestJS sends an empty 201 body for a controller method that returns
`undefined`. Parsing an empty body as JSON throws
(`SyntaxError: Unexpected end of JSON input`), which `apiFetch` propagates
as a rejected promise, so every caller's `onError` fires
("Ошибка отправки сообщения") even though the notification was actually
sent (confirmed: the HTTP request completes with 201, and re-running the
exact request via `curl` returns 201 with an empty body every time).
Because the admin sees a false error, they may reasonably retry and send
the same message to the user twice.

**Fix:** `apiFetch` must not assume every successful response has a JSON
body. Read the body as text first and only parse it as JSON when it's
non-empty:
```ts
const text = await res.text();
return text ? JSON.parse(text) : undefined;
```
(Checked empirically: a `Response` constructed with a `null` body — what
NestJS sends for a controller method returning `void` — has no
`Content-Length` header at all in Node's `fetch` implementation, not
`"0"`; relying on that header to detect an empty body is unreliable. Reading
`res.text()` and checking for an empty string works regardless of which
headers happen to be present.) This is a general robustness fix (not
special-cased to the notifications endpoint), since any future
void-returning admin endpoint would hit the exact same failure mode. No
other caller of `api.post`/`api.put` in the codebase currently depends on
always receiving a parsed body from an empty response (checked: every other
admin mutation's backend method returns a Prisma record or an explicit
object).

## Testing approach

Each fix gets a regression test at the layer where the bug actually lived —
matching the pattern already established in `feature/admin-panel-real-data`
(e.g. `route.test.ts` spinning up a real compressed HTTP response to catch
the proxy bug, rather than a mocked-fetch test that can't see it):

- **#1 (Plans):** component test rendering `PlansPage` with MSW returning
  the *real* response shape (`{plan: 'START', price: 200, ...}`, no `id`/
  `name`/`maxStores`) — assert the card title renders "START" (not blank),
  and assert the PUT request body captured by the MSW handler contains only
  whitelisted `UpdatePlanDto` fields (no `id`/`name`/`maxStores` keys) when
  Save is clicked.
- **#2 (Announcements):** extend the existing MSW handler for
  `/admin/announcements/preview` to assert the captured request body
  includes non-empty `title`/`body` matching what was typed.
- **#3 (Store transfer):** assert the captured PUT body key is
  `newOwnerId`, not `userId`, for both the list-page and detail-page
  dialogs.
- **#4 (Change plan):** assert the captured PUT body key is `plan`, not
  `planId`.
- **#5 (apiFetch):** unit test for `apiFetch` itself (new file,
  `admin/lib/api.test.ts` — this file has no test coverage today) using a
  mocked `fetch` that returns a 201 with an empty body (`content-length: 0`,
  no body text) — assert `apiFetch` resolves (does not throw) and returns
  `undefined`, plus a second case with a normal JSON 200 body — assert it
  still parses and returns the parsed object (no regression on the common
  path).

## Live re-verification

After implementation and merge, re-run the exact live checks that found
each bug (Playwright + `curl` cross-check, same methodology as this
audit): edit and save a tariff price and confirm it persists after reload;
send a real announcement and confirm it appears in history with the correct
recipient count; transfer a test store and confirm the owner actually
changes; change a test subscription's plan and confirm it actually changes;
send a direct message and confirm a *success* toast appears (not error).

## Out of scope

- The four "чего не хватает / шероховатости" items (missing delete-user UI,
  raw-UUID store-transfer input, no confirmation on destructive actions,
  the pre-existing React key-prop warning on the Tariffs page) are a
  separate, explicitly deferred follow-up — planned separately, not
  implemented in this cycle.
- No change to the audit log's double-row-per-mutation logging pattern
  (one semantic-action row + one generic `UPDATE:api/...` row) — confirmed
  pre-existing, cosmetic-only noise, not requested.
- No broader `apiFetch`/`lib/api.ts` redesign (e.g. typed error classes,
  retry logic) — only the minimal fix for the empty-body crash.
