# Admin Panel — Make It Actually Work With Real Data — Design

**Context.** Live-tested the admin panel (`admin/`, Next.js 16) against the real
backend with seeded data (Playwright, logged in as `+992000000000`). Found six
defects, all confirmed via direct source inspection — not guessed. None of
these are missing features; the panel's UI, forms, and backend endpoints all
exist and mostly work — these are data-plumbing bugs between the two.

**Goal.** Fix all six so the panel's dashboards, lists, and history tables
show real, correct data instead of empty tables, `NaN`, stale contract
mismatches, or fabricated `Math.random()` fallbacks.

## Findings and fixes

### 1. Critical: proxy strips no `content-encoding`, breaking every list page

`admin/app/api/proxy/[...path]/route.ts` forwards every upstream response
header except a fixed `HOP_BY_HOP` set (`connection`, `keep-alive`,
`transfer-encoding`, `content-length`, etc.). It does **not** include
`content-encoding`. The backend runs `app.use(compression())`
(`api/src/main.ts:72`), which gzips any response over its size threshold.
Node's `fetch()` (used by the proxy to call the backend) transparently
decompresses gzip bodies — so `upstream.body`, forwarded verbatim to the
browser, is already plain JSON. But the forwarded `content-encoding: gzip`
header tells the browser to gunzip it anyway, which fails
(`net::ERR_CONTENT_DECODING_FAILED`), so the fetch throws, and every list
page (Users, Stores, Subscriptions — anything returning enough rows to cross
the compression threshold) renders its empty state. Small aggregate
responses (dashboard stats) stay under the threshold and work today, which
is why this wasn't obvious from the dashboard alone.

**Fix:** add `'content-encoding'` to `HOP_BY_HOP` in that file. Same
one-line shape as the existing `content-length` entry (which is already
stripped for the equivalent reason — length is recomputed by `fetch`).

### 2. Dashboard stats: the whole contract is stale

`admin/lib/types.ts`'s `DashboardStats` declares `activeSubscriptions`,
`trialSubscriptions`, `expiredSubscriptions`, `monthlyRevenue`,
`newUsersThisWeek`, `newStoresThisWeek`. The backend
(`api/src/modules/admin/admin.service.ts:376`, `getDashboard()`) returns
`subscriptionsByStatus: Record<string, number>` (keyed by `TRIAL`/`ACTIVE`/
`PAST_DUE`/`CANCELLED`/`EXPIRED`), `approvedPaymentsThisMonth: {total, count}`,
`newUsersThisMonth`, `newStoresThisMonth`. Only `totalUsers`/`totalStores`
happen to match by name. Every other card silently reads a field that was
never sent and falls back to its `?? 0` default — "Активные подписки: 0"
isn't really 0 (2 exist), it's a name that doesn't exist on the response.
The revenue card's `Intl.NumberFormat(...).format(undefined)` is why it
renders "не число TJS" — Russian's NaN-in-currency-format string.

**Fix:** rewrite `DashboardStats` to the real shape and update
`dashboard/page.tsx`'s `cardData` to read `stats?.subscriptionsByStatus?.ACTIVE
?? 0` / `.TRIAL ?? 0` / `.EXPIRED ?? 0`, `stats?.approvedPaymentsThisMonth?.total`,
`stats?.newUsersThisMonth`, `stats?.newStoresThisMonth`. Rename the "за
неделю" card labels to "за месяц" — the backend has no weekly breakdown, so
the old labels were never accurate regardless of the field-name bug.

### 3. Charts fall back to fabricated random data

`dashboard/page.tsx` defines `generateMockRevenue()`/
`generateMockRegistrations()` (`Math.floor(Math.random() * ...)`) and wires
them as `<RevenueChart data={revenueData ?? mockRevenue} />` /
`<RegistrationsChart data={registrationData ?? mockRegistrations} />`. Since
`revenueData`/`registrationData` are `undefined` while their query is
loading (and on error), the chart renders fabricated numbers — visually
indistinguishable from real data — during every page load, before quietly
swapping to the real (possibly empty) series.

**Fix:** delete both generator functions and both `?? mock*` fallbacks
entirely. Charts render `revenueData ?? []` / `registrationData ?? []` —
genuinely empty while loading, never invented.

### 4. Hydration mismatch in the sidebar

`admin/components/sidebar.tsx`: `const userName = typeof window !==
'undefined' ? localStorage.getItem('userName') : null;` — the exact
`if (typeof window !== 'undefined')` anti-pattern React's own hydration-
mismatch error message calls out by name. Server render (no `window`) always
produces `null` → shows "Администратор"; client render (has `window`)
reads the real stored name → shows "Admin" (or whatever was saved at
login). React detects the mismatch, discards the SSR tree, and re-renders
client-side — harmless in outcome but a real, avoidable warning-generating
bug that also means the first paint briefly shows one value and swaps.

**Fix:** `const [userName, setUserName] = useState<string | null>(null);` +
`useEffect(() => setUserName(localStorage.getItem('userName')), [])`. First
render (server and client) both show `null` → "Администратор"; the real
name swaps in one tick post-mount, which is the standard fix for this exact
pattern.

### 5. Announcements history: raw UUID sender, missing sent-at

`admin.service.ts`'s `listAnnouncements()` does a plain
`this.prisma.announcement.findMany(...)` with no join — `Announcement.sentBy`
is a bare `String` column, not a Prisma relation (checked
`prisma/schema.prisma`), so there's nothing to `include`. The frontend
renders `{a.sentBy}` directly (`announcements/page.tsx:232`) — the raw
admin user ID. Separately, the frontend also reads `a.sentAt`
(`announcements/page.tsx:230`) but the `Announcement` model has no `sentAt`
field at all, only `createdAt` — hence the "Отправлено: —" dash on every
row. Both are in the same file/table and part of the same "make this
history table show correct real data" fix, so both are covered here rather
than as a separate finding.

**Fix, backend:** mirror the exact pattern `listAuditLog()` already uses for
the identical problem (`admin.service.ts` around line 770 — batch-fetch
`user.findMany({where: {id: {in: userIds}}, select: {id, name}})`, build a
`Map`, merge into each row). Apply the same to `listAnnouncements()`:
collect distinct `sentBy` IDs from the page of results, batch-fetch
`{id, name}`, attach as `senderName` (`?? null` if the admin was since
deleted — frontend falls back to the raw ID string in that edge case, never
crashes).

**Fix, frontend:** add `senderName?: string | null` to the `Announcement`
type (`lib/types.ts`); render `a.senderName ?? a.sentBy` for "Отправитель".
For "Отправлено", read `a.createdAt` instead of the nonexistent `a.sentAt`
(also add `createdAt: string` to the type, remove the nonexistent `sentAt`).

### 6. Test gap: nothing exercises the proxy against a real compressed response

The admin suite is 39/39 green today, but every existing test mocks `fetch`
directly (MSW) or mocks the proxy's own `fetch` call — none of them
exercise the actual route handler against a *really* gzip-compressed
upstream response, so finding #1 slipped through untested.

**Fix:** new test, `admin/app/api/proxy/[...path]/route.test.ts`. Spin up a
minimal local Node HTTP server (`node:http`) that responds with a real
`zlib.gzipSync()`-compressed JSON body and `Content-Encoding: gzip`. Point
`API_INTERNAL_URL` at it for the duration of the test. Call the route
handler directly with a `NextRequest`. Assert: the returned response has no
`content-encoding` header, and its body — read directly, no manual
decompression — parses as the original JSON. This reproduces the exact
failure class a mocked-fetch test can't catch, and is a genuine regression
guard against anyone re-introducing this exact bug.

## Testing approach (items 2–5)

The repo already has an established pattern for exactly this kind of bug —
`admin/test/regression/audit-log-shape.test.tsx` — which renders a page
inside `QueryClientProvider` with MSW (`test/msw/server.ts`) serving a
handler that returns the *real* backend response shape, then asserts the
correct value renders. Each of items 2, 3, 4, 5 gets a same-shaped
regression test:

- **Item 2**: MSW handler for `/admin/dashboard` returns the real shape
  (`subscriptionsByStatus`, `approvedPaymentsThisMonth`, etc.); assert the
  dashboard renders the correct numbers (e.g. "2" for active, not "0"; the
  formatted revenue, not "не число").
- **Item 3**: assert the rendered chart never receives a fixed/known
  "impossible" set of values that only the mock generator could produce, by
  simply confirming the mock functions no longer exist in the bundle
  (a `grep`/import check) plus a component test that an empty/loading query
  result renders an empty chart, not populated bars.
- **Item 4**: render `Sidebar` with a mocked `localStorage`; assert the
  *first* render shows "Администратор" (matching SSR) and it updates to the
  stored name only after `waitFor` (post-effect) — proving no
  branch-on-`window` remains.
- **Item 5**: MSW handler for `/admin/announcements` returns a row with
  `senderName` and `createdAt`; assert the resolved name and formatted date
  render, not a raw UUID or a dash. Separate backend unit test, added to the
  existing `api/src/modules/admin/admin.service.spec.ts` (which already has
  a `describe('AdminService — announcements (Spec C)', ...)` block and its
  own minimal `makePrismaFake()` — extend that fake with
  `announcement.findMany`/`announcement.count`/`user.findMany` rather than
  writing a new file), verifying `listAnnouncements()` attaches `senderName`
  from the batch lookup. Neither `listAnnouncements()` nor `listAuditLog()`
  has existing test coverage today, so this is new coverage, not an
  extension of a pre-existing test.

## Live re-verification (after implementation, before the final summary)

Per your two-step framing — plan+fix first, then test+summarize — the
comprehensive live pass (Playwright against the real backend) happens
*after* this plan's tasks are implemented and merged, as its own step. It
will re-check the six fixes above plus exercise the actions I haven't yet
tested this round (extend subscription, save a tariff change, block/
unblock a user, impersonate, create a banner, send an announcement, and
whether the audit log populates once an action is actually taken) to
produce the final readiness summary.

## Out of scope

- No Prisma migration — `Announcement.sentBy` stays a bare `String`; the fix
  is a service-layer batch lookup, matching the existing `listAuditLog()`
  precedent exactly, not a schema change.
- No change to `compression()` on the backend — it's correct and used by
  the mobile app too; the bug is entirely in how the proxy re-forwards its
  effects.
- No broader redesign of the dashboard's card layout, chart library, or
  visual design — numbers and data sources only.
- The other four admin pages not yet exercised this round (subscription
  extend/tariff save actions, user block/impersonate, banners, audit log
  after a real action) are deferred to the post-implementation live-testing
  step described above, not fixed speculatively here.
