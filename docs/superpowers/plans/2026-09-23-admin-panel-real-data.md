# Admin Panel Real-Data Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six confirmed defects so the admin panel's dashboard, lists, and history tables show real, correct data instead of empty tables, `NaN`, stale field-name mismatches, or fabricated random fallbacks.

**Architecture:** Each defect is an independent data-plumbing bug (proxy header handling, frontend/backend type mismatches, a missing batch lookup, a client-only-read anti-pattern) — no new components, no schema migrations, no architectural changes. Every fix mirrors an existing, already-correct pattern elsewhere in the same codebase (e.g. the announcements sender-name fix copies `listAuditLog()`'s existing user-batch-lookup pattern verbatim).

**Tech Stack:** Next.js 16 (`admin/`), NestJS + Prisma (`api/`), Vitest + Testing Library + MSW (admin tests), Jest (backend tests).

**Spec:** `docs/superpowers/specs/2026-09-23-admin-panel-real-data-design.md`

---

### Task 1: Fix the proxy's stale `content-encoding` header

**Files:**
- Modify: `admin/app/api/proxy/[...path]/route.ts`
- Test: `admin/app/api/proxy/[...path]/route.test.ts` (new)

- [ ] **Step 1: Write the failing test**

Create `admin/app/api/proxy/[...path]/route.test.ts`:

```ts
import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import { createServer, type Server } from 'node:http';
import { gzipSync } from 'node:zlib';
import type { NextRequest } from 'next/server';

// route.ts reads API_INTERNAL_URL into a top-level const at module import
// time, so this test sets the env var and re-imports the module fresh
// (vi.resetModules) rather than importing it at the top of the file —
// otherwise it would already be bound to whatever URL was set before this
// test file ran.
function makeProxyRequest(): NextRequest {
  const headers = new Headers({ 'content-type': 'application/json' });
  return {
    url: 'http://localhost:3000/api/proxy/some/path',
    method: 'GET',
    headers,
    cookies: {
      get: (name: string) =>
        name === 'token' ? { name, value: 'fake-token' } : undefined,
    },
  } as unknown as NextRequest;
}

describe('admin proxy route: content-encoding handling', () => {
  let upstream: Server;
  let upstreamUrl: string;
  const payload = { hello: 'world', items: [1, 2, 3] };

  beforeAll(async () => {
    upstream = createServer((_req, res) => {
      const body = gzipSync(Buffer.from(JSON.stringify(payload)));
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Content-Encoding': 'gzip',
      });
      res.end(body);
    });
    await new Promise<void>((resolve) => upstream.listen(0, resolve));
    const address = upstream.address();
    if (address && typeof address === 'object') {
      upstreamUrl = `http://localhost:${address.port}`;
    }
  });

  afterAll(() => {
    upstream.close();
    delete process.env.API_INTERNAL_URL;
  });

  it('does not forward a stale content-encoding header for an already-decompressed body', async () => {
    process.env.API_INTERNAL_URL = upstreamUrl;
    vi.resetModules();
    const { GET } = await import('./route');

    const res = await GET(makeProxyRequest(), {
      params: Promise.resolve({ path: ['some', 'path'] }),
    });

    expect(res.headers.get('content-encoding')).toBeNull();
    const body = await res.json();
    expect(body).toEqual(payload);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `admin/`): `npm test -- app/api/proxy/\[...path\]/route.test.ts`

Expected: FAIL — `res.headers.get('content-encoding')` is `'gzip'`, not `null` (the current code forwards it verbatim).

- [ ] **Step 3: Fix the header set**

In `admin/app/api/proxy/[...path]/route.ts`, find:

```ts
const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  // Don't forward host — upstream sees its own origin.
  'host',
  // Don't forward client cookies — we replace with Bearer.
  'cookie',
  // Length is recomputed by fetch.
  'content-length',
]);
```

and change it to:

```ts
const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  // Don't forward host — upstream sees its own origin.
  'host',
  // Don't forward client cookies — we replace with Bearer.
  'cookie',
  // Length is recomputed by fetch.
  'content-length',
  // fetch() already transparently decompresses the upstream body before we
  // see it (upstream.body below is plain, not gzip bytes), but the original
  // Content-Encoding header survives on upstream.headers. Forwarding it
  // verbatim tells the browser "this body is still gzip", so it tries to
  // gunzip already-plain JSON and fails with ERR_CONTENT_DECODING_FAILED.
  'content-encoding',
]);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- app/api/proxy/\[...path\]/route.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/api/proxy/\[...path\]/route.ts app/api/proxy/\[...path\]/route.test.ts
git commit -m "fix(admin): stop forwarding a stale content-encoding header in the proxy

fetch() already decompresses gzip upstream responses before the proxy
re-forwards them, but the original Content-Encoding: gzip header was
being passed through unchanged, so browsers tried to gunzip
already-plain JSON and failed with ERR_CONTENT_DECODING_FAILED. This
broke every list page (Users, Stores, Subscriptions) whose response
was large enough to cross the backend's compression threshold, while
small aggregate responses (dashboard stats) stayed under it and
appeared to work."
```

(Run from `admin/`.)

---

### Task 2: Fix the dashboard stats contract mismatch

**Files:**
- Modify: `admin/lib/types.ts` (`DashboardStats` interface)
- Modify: `admin/app/(admin)/dashboard/page.tsx` (`cardData` mapping)
- Test: `admin/app/(admin)/dashboard/page.test.tsx` (new)

- [ ] **Step 1: Write the failing test**

Create `admin/app/(admin)/dashboard/page.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

import DashboardPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('DashboardPage reads the real backend stats shape', () => {
  it('renders subscriptionsByStatus and approvedPaymentsThisMonth correctly, not the old flat field names', async () => {
    server.use(
      http.get(`${API_URL}/admin/dashboard`, () =>
        HttpResponse.json({
          totalUsers: 13,
          totalStores: 10,
          subscriptionsByStatus: { ACTIVE: 2, EXPIRED: 7, PAST_DUE: 1 },
          approvedPaymentsThisMonth: { total: 450, count: 3 },
          newUsersThisMonth: 4,
          newStoresThisMonth: 3,
        }),
      ),
      http.get(`${API_URL}/admin/revenue`, () => HttpResponse.json([])),
      http.get(`${API_URL}/admin/dashboard/registrations`, () =>
        HttpResponse.json([]),
      ),
      http.get(`${API_URL}/admin/subscriptions/pending-payments`, () =>
        HttpResponse.json([]),
      ),
    );

    renderWithQuery(<DashboardPage />);

    // Active subscriptions: real value (2), not the old always-0 fallback.
    await waitFor(() => expect(screen.getByText('2')).toBeInTheDocument());
    // Expired subscriptions: real value (7).
    expect(screen.getByText('7')).toBeInTheDocument();
    // Revenue: formatted currency, never "не число" (NaN-in-currency).
    expect(screen.queryByText(/не число/)).not.toBeInTheDocument();
    expect(screen.getByText(/450/)).toBeInTheDocument();
    // Monthly counts (renamed from the nonexistent "ThisWeek" fields) —
    // both labels must be present, proving the cards read
    // newUsersThisMonth/newStoresThisMonth rather than the old
    // nonexistent newUsersThisWeek/newStoresThisWeek fields.
    expect(screen.getByText('Новые за месяц')).toBeInTheDocument();
    expect(screen.getByText('Новые магазины')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `admin/`): `npm test -- app/\(admin\)/dashboard/page.test.tsx`

Expected: FAIL — active subscriptions renders "0" (reads the nonexistent `stats.activeSubscriptions`), revenue renders "не число TJS".

- [ ] **Step 3: Fix the type**

In `admin/lib/types.ts`, find:

```ts
export interface DashboardStats {
  totalUsers: number;
  totalStores: number;
  activeSubscriptions: number;
  trialSubscriptions: number;
  expiredSubscriptions: number;
  monthlyRevenue: number;
  newUsersThisWeek: number;
  newStoresThisWeek: number;
}
```

and change it to:

```ts
export interface DashboardStats {
  totalUsers: number;
  totalStores: number;
  subscriptionsByStatus: Record<string, number>;
  approvedPaymentsThisMonth: { total: number; count: number };
  newUsersThisMonth: number;
  newStoresThisMonth: number;
}
```

- [ ] **Step 4: Fix the card mapping**

In `admin/app/(admin)/dashboard/page.tsx`, find the `cardData` array (currently the block starting `const cardData = [` through its closing `];`) and replace the six affected entries — leave the "Пользователи" and "Магазины" cards untouched:

```ts
    {
      title: 'Активные подписки',
      value: stats?.subscriptionsByStatus?.ACTIVE ?? 0,
      icon: CreditCard,
      description: 'Оплаченные подписки',
      href: '/subscriptions?status=ACTIVE',
    },
    {
      title: 'Trial',
      value: stats?.subscriptionsByStatus?.TRIAL ?? 0,
      icon: Clock,
      description: 'Пробный период',
      href: '/subscriptions?status=TRIAL',
    },
    {
      title: 'Истекшие',
      value: stats?.subscriptionsByStatus?.EXPIRED ?? 0,
      icon: XCircle,
      description: 'Подписки истекли',
      href: '/subscriptions?status=EXPIRED',
    },
    {
      title: 'Выручка за месяц',
      value: stats
        ? new Intl.NumberFormat('ru-TJ', {
            style: 'currency',
            currency: 'TJS',
            maximumFractionDigits: 0,
          }).format(stats.approvedPaymentsThisMonth.total)
        : '—',
      icon: TrendingUp,
      description: 'Текущий месяц',
      href: '/subscriptions',
    },
    {
      title: 'Новые за месяц',
      value: stats?.newUsersThisMonth ?? 0,
      icon: UserPlus,
      description: 'Новые пользователи',
      href: '/users',
    },
    {
      title: 'Новые магазины',
      value: stats?.newStoresThisMonth ?? 0,
      icon: Building2,
      description: 'За последний месяц',
      href: '/stores',
    },
```

(Only the `title`/`value`/`description` of the "Новые за неделю" card change — it's renamed to "Новые за месяц" since the backend only ever measured a month, never a week.)

- [ ] **Step 5: Run test to verify it passes**

Run: `npm test -- app/\(admin\)/dashboard/page.test.tsx`

Expected: PASS.

- [ ] **Step 6: Run `tsc` to confirm no other file references the removed fields**

Run (from `admin/`): `npx tsc --noEmit`

Expected: no errors. (If any other file references `activeSubscriptions`/`trialSubscriptions`/`expiredSubscriptions`/`monthlyRevenue`/`newUsersThisWeek`/`newStoresThisWeek` on `DashboardStats`, this catches it — fix any such reference the same way as Step 4.)

- [ ] **Step 7: Commit**

```bash
git add lib/types.ts app/\(admin\)/dashboard/page.tsx app/\(admin\)/dashboard/page.test.tsx
git commit -m "fix(admin): dashboard stats now read the real backend response shape

DashboardStats declared activeSubscriptions/trialSubscriptions/
expiredSubscriptions/monthlyRevenue/newUsersThisWeek/newStoresThisWeek
— none of which the backend has ever sent. Every card except
Пользователи/Магазины silently fell back to 0 (or NaN, formatted as
'не число' for revenue). Backend actually returns
subscriptionsByStatus/approvedPaymentsThisMonth/newUsersThisMonth/
newStoresThisMonth; the frontend now reads those."
```

(Run from `admin/`.)

---

### Task 3: Remove the fabricated-random-data chart fallback

**Files:**
- Modify: `admin/app/(admin)/dashboard/page.tsx` (remove `generateMockRevenue`/`generateMockRegistrations` and their usage)
- Test: `admin/app/(admin)/dashboard/page.test.tsx` (extend the file from Task 2)

- [ ] **Step 1: Write the failing test**

In `admin/app/(admin)/dashboard/page.test.tsx` (same file created in Task 2), find the existing mocks at the top of the file:

```tsx
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));
```

and add two more mocks directly below it (`vi.mock` calls are hoisted by Vitest regardless of position, but keeping them together at the top matches this file's own convention):

```tsx
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));
vi.mock('@/components/charts/revenue-chart', () => ({
  RevenueChart: ({ data }: { data: unknown }) => (
    <div data-testid="revenue-chart-data">{JSON.stringify(data)}</div>
  ),
}));
vi.mock('@/components/charts/registrations-chart', () => ({
  RegistrationsChart: ({ data }: { data: unknown }) => (
    <div data-testid="registrations-chart-data">{JSON.stringify(data)}</div>
  ),
}));
```

Then add this new `describe` block at the end of the file, after the one from Task 2:

```tsx
describe('DashboardPage never shows fabricated chart data', () => {
  it('passes an empty array to the charts while the real queries are loading, never Math.random() output', () => {
    // Stub the other two queries so they don't attempt a real network
    // request during this test (MSW's onUnhandledRequest is 'bypass',
    // which would otherwise try to actually connect). Deliberately do NOT
    // register a handler for /admin/revenue or /admin/dashboard/registrations
    // — those two queries must stay pending, so revenueData/registrationData
    // are undefined on first render. Before this fix, that undefined state
    // fell back to Math.random()-generated arrays; after, it must fall back
    // to [].
    server.use(
      http.get(`${API_URL}/admin/dashboard`, () => HttpResponse.json({})),
      http.get(`${API_URL}/admin/subscriptions/pending-payments`, () =>
        HttpResponse.json([]),
      ),
    );

    renderWithQuery(<DashboardPage />);

    expect(screen.getByTestId('revenue-chart-data').textContent).toBe('[]');
    expect(screen.getByTestId('registrations-chart-data').textContent).toBe(
      '[]',
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `admin/`): `npm test -- app/\(admin\)/dashboard/page.test.tsx`

Expected: FAIL — `revenue-chart-data`'s text content is a 30-element array of random numbers, not `'[]'`.

- [ ] **Step 3: Remove the mock generators and their usage**

In `admin/app/(admin)/dashboard/page.tsx`, delete these two functions entirely:

```ts
function generateMockRevenue(): RevenuePoint[] {
  const data: RevenuePoint[] = [];
  const now = new Date();
  for (let i = 29; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    data.push({
      date: d.toISOString().slice(0, 10),
      revenue: Math.floor(Math.random() * 5000 + 2000),
    });
  }
  return data;
}

function generateMockRegistrations(): RegistrationPoint[] {
  const data: RegistrationPoint[] = [];
  const now = new Date();
  for (let i = 29; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    data.push({
      date: d.toISOString().slice(0, 10),
      users: Math.floor(Math.random() * 20 + 5),
      stores: Math.floor(Math.random() * 10 + 2),
    });
  }
  return data;
}
```

Then find, inside `DashboardPage`:

```ts
  const mockRevenue = generateMockRevenue();
  const mockRegistrations = generateMockRegistrations();

```

and delete those two lines entirely.

Then find:

```tsx
        <RevenueChart data={revenueData ?? mockRevenue} />
        <RegistrationsChart data={registrationData ?? mockRegistrations} />
```

and change to:

```tsx
        <RevenueChart data={revenueData ?? []} />
        <RegistrationsChart data={registrationData ?? []} />
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- app/\(admin\)/dashboard/page.test.tsx`

Expected: PASS (both describe blocks — Task 2's and this one).

- [ ] **Step 5: Run `tsc` to confirm no dangling references**

Run: `npx tsc --noEmit`

Expected: no errors (confirms `RevenuePoint`/`RegistrationPoint` imports are still used elsewhere in the file via the type annotations on `useQuery`, so no unused-import warnings either).

- [ ] **Step 6: Commit**

```bash
git add app/\(admin\)/dashboard/page.tsx app/\(admin\)/dashboard/page.test.tsx
git commit -m "fix(admin): dashboard charts never fall back to fabricated data

generateMockRevenue()/generateMockRegistrations() produced
Math.random() output that rendered whenever the real query hadn't
resolved yet (every page load) or returned undefined (on error) —
visually indistinguishable from real data. Charts now fall back to
an empty array, which is honest about there being nothing to show
yet."
```

(Run from `admin/`.)

---

### Task 4: Fix the sidebar hydration mismatch

**Files:**
- Modify: `admin/components/sidebar.tsx`
- Test: `admin/components/sidebar.test.tsx` (new)

- [ ] **Step 1: Write the failing test**

Create `admin/components/sidebar.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';

vi.mock('next/navigation', () => ({
  usePathname: () => '/dashboard',
  useRouter: () => ({ push: vi.fn() }),
}));

import { Sidebar } from './sidebar';

describe('Sidebar username display', () => {
  it('shows the stored username once mounted, without branching on typeof window', async () => {
    window.localStorage.setItem('userName', 'Admin');

    render(<Sidebar />);

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument());
  });

  it('falls back to "Администратор" when nothing is stored', async () => {
    window.localStorage.clear();

    render(<Sidebar />);

    await waitFor(() =>
      expect(screen.getByText('Администратор')).toBeInTheDocument(),
    );
  });
});
```

NOTE: this test proves the fix preserves correct final behavior (real username once available, fallback otherwise). It does NOT and cannot prove the hydration-mismatch console warning is gone — jsdom has no separate server-render pass to compare against, so that specific class of bug can only be observed in a real browser. Task 6's live-verification pass checks the browser console directly for the absence of the hydration warning.

- [ ] **Step 2: Run test to verify it fails or passes for the wrong reason**

Run (from `admin/`): `npm test -- components/sidebar.test.tsx`

Expected: PASS already, since the current `typeof window !== 'undefined'` code happens to produce the correct value once the component is mounted in jsdom (jsdom always has `window`). This test doesn't fail before the fix — it's here to pin the correct behavior so Step 3's refactor can't silently break it. Proceed to Step 3 regardless.

- [ ] **Step 3: Replace the `typeof window` branch with a mount-effect**

In `admin/components/sidebar.tsx`, add `useState`/`useEffect` to the import:

```tsx
import { useState, useEffect } from 'react';
import Link from 'next/link';
```

Then find:

```tsx
export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = () => {
    localStorage.removeItem('token');
    document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    router.push('/login');
  };

  const userName =
    typeof window !== 'undefined' ? localStorage.getItem('userName') : null;
```

and change it to:

```tsx
export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [userName, setUserName] = useState<string | null>(null);

  useEffect(() => {
    setUserName(localStorage.getItem('userName'));
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('token');
    document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    router.push('/login');
  };
```

`userName` is now `null` on both the server render and the client's first render (matching, so no hydration mismatch), and updates to the real stored value in a `useEffect` that only runs post-mount, client-side.

- [ ] **Step 4: Run test to verify it still passes**

Run: `npm test -- components/sidebar.test.tsx`

Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add components/sidebar.tsx components/sidebar.test.tsx
git commit -m "fix(admin): eliminate sidebar hydration mismatch

typeof window !== 'undefined' ? localStorage.getItem(...) : null is
the exact anti-pattern React's own hydration-mismatch error message
names — server render always sees null (window doesn't exist),
client render sees the real stored value, so React discards and
re-renders the whole tree on every page load. Replaced with a
useState defaulting to null plus a mount-only useEffect, so both the
server and the client's first render agree."
```

(Run from `admin/`.)

---

### Task 5: Fix announcements history — resolved sender name and real date field

**Files:**
- Modify: `api/src/modules/admin/admin.service.ts` (`listAnnouncements`)
- Modify: `api/src/modules/admin/admin.service.spec.ts` (extend the shared fake, add tests)
- Modify: `admin/lib/types.ts` (`Announcement` interface)
- Modify: `admin/app/(admin)/announcements/page.tsx` (render `senderName`/`createdAt`)
- Test: `admin/app/(admin)/announcements/page.test.tsx` (new)

- [ ] **Step 1: Write the failing backend test**

In `api/src/modules/admin/admin.service.spec.ts`, find `makePrismaFake()`:

```ts
function makePrismaFake() {
  return {
    store: {
      findMany: jest.fn(async () => [] as any[]),
    },
    announcement: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'a-generated',
        ...data,
      })),
    },
  };
}
```

and extend it to:

```ts
function makePrismaFake() {
  return {
    store: {
      findMany: jest.fn(async () => [] as any[]),
    },
    announcement: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'a-generated',
        ...data,
      })),
      findMany: jest.fn(async () => [] as any[]),
      count: jest.fn(async () => 0),
    },
    user: {
      findMany: jest.fn(async () => [] as any[]),
    },
  };
}
```

Then add this new `describe` block at the end of the file (after the existing `describe('AdminService — updatePlan', ...)` block):

```ts
describe('AdminService — listAnnouncements attaches senderName', () => {
  let service: AdminService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
        { provide: StoresService, useValue: { create: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(AdminService);
  });

  it('resolves sentBy to the sending admin\'s name via a batch lookup', async () => {
    prisma.announcement.findMany.mockResolvedValueOnce([
      {
        id: 'ann1',
        title: 'Hello',
        body: 'World',
        targetPlan: null,
        targetStatus: null,
        sentBy: 'admin-1',
        recipientCount: 5,
        createdAt: new Date('2026-04-01T00:00:00Z'),
      },
    ]);
    prisma.announcement.count.mockResolvedValueOnce(1);
    prisma.user.findMany.mockResolvedValueOnce([
      { id: 'admin-1', name: 'Алишер Админ' },
    ]);

    const result = await service.listAnnouncements({
      page: 1,
      limit: 20,
    } as any);

    expect(result.data[0].senderName).toBe('Алишер Админ');
    expect(prisma.user.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['admin-1'] } },
      select: { id: true, name: true },
    });
  });

  it('falls back to null senderName when the sending admin no longer exists', async () => {
    prisma.announcement.findMany.mockResolvedValueOnce([
      {
        id: 'ann1',
        title: 'Hello',
        body: 'World',
        targetPlan: null,
        targetStatus: null,
        sentBy: 'deleted-admin',
        recipientCount: 0,
        createdAt: new Date('2026-04-01T00:00:00Z'),
      },
    ]);
    prisma.announcement.count.mockResolvedValueOnce(1);
    prisma.user.findMany.mockResolvedValueOnce([]);

    const result = await service.listAnnouncements({
      page: 1,
      limit: 20,
    } as any);

    expect(result.data[0].senderName).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `api/`): `npx jest src/modules/admin/admin.service.spec.ts`

Expected: FAIL — `result.data[0].senderName` is `undefined` (the field doesn't exist yet), and `prisma.user.findMany` was never called.

- [ ] **Step 3: Fix `listAnnouncements`**

In `api/src/modules/admin/admin.service.ts`, find:

```ts
  async listAnnouncements(query: AnnouncementsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.announcement.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.announcement.count(),
    ]);

    return { data, total, page, limit };
  }
```

and change it to:

```ts
  async listAnnouncements(query: AnnouncementsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const [announcements, total] = await Promise.all([
      this.prisma.announcement.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.announcement.count(),
    ]);

    // Announcement.sentBy is a bare String column, not a Prisma relation,
    // so there's nothing to `include` — batch-fetch names the same way
    // listAuditLog() already does for its identical userId problem.
    const senderIds = [...new Set(announcements.map((a) => a.sentBy))];
    const senders = await this.prisma.user.findMany({
      where: { id: { in: senderIds } },
      select: { id: true, name: true },
    });
    const senderMap = new Map(senders.map((s) => [s.id, s.name]));

    const data = announcements.map((a) => ({
      ...a,
      senderName: senderMap.get(a.sentBy) ?? null,
    }));

    return { data, total, page, limit };
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `api/`): `npx jest src/modules/admin/admin.service.spec.ts`

Expected: PASS (all tests in the file, including the pre-existing "Spec C" and `updatePlan` blocks — extending the shared fake must not break them).

- [ ] **Step 5: Write the failing frontend test**

Create `admin/app/(admin)/announcements/page.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

import AnnouncementsPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('AnnouncementsPage history table shows real sender name and date', () => {
  it('renders the resolved sender name and formatted date, not a raw UUID or dash', async () => {
    server.use(
      http.get(`${API_URL}/admin/announcements`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'ann1',
              title: 'Добро пожаловать!',
              body: 'Текст',
              targetPlan: null,
              targetStatus: null,
              recipientCount: 5,
              createdAt: '2026-04-01T10:00:00Z',
              sentBy: 'bf774704-c8b4-4622-8cdb-985750b654e0',
              senderName: 'Admin',
            },
          ],
          total: 1,
          page: 1,
          limit: 20,
        }),
      ),
    );

    renderWithQuery(<AnnouncementsPage />);

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument());
    expect(
      screen.queryByText('bf774704-c8b4-4622-8cdb-985750b654e0'),
    ).not.toBeInTheDocument();
    expect(screen.getByText('01.04.2026 10:00')).toBeInTheDocument();
  });

  it('falls back to the raw id when senderName is null (sending admin deleted)', async () => {
    server.use(
      http.get(`${API_URL}/admin/announcements`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'ann2',
              title: 'Old announcement',
              body: 'Текст',
              targetPlan: null,
              targetStatus: null,
              recipientCount: 0,
              createdAt: '2026-01-01T00:00:00Z',
              sentBy: 'deleted-admin-id',
              senderName: null,
            },
          ],
          total: 1,
          page: 1,
          limit: 20,
        }),
      ),
    );

    renderWithQuery(<AnnouncementsPage />);

    await waitFor(() =>
      expect(screen.getByText('deleted-admin-id')).toBeInTheDocument(),
    );
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run (from `admin/`): `npm test -- app/\(admin\)/announcements/page.test.tsx`

Expected: FAIL — the table renders the raw `sentBy` UUID (`bf774704-...`) instead of `'Admin'` in the first test, and "01.04.2026 10:00" doesn't appear (current code reads the nonexistent `a.sentAt`, rendering "—" instead).

- [ ] **Step 7: Fix the type and the page**

In `admin/lib/types.ts`, find:

```ts
export interface Announcement {
  id: string;
  title: string;
  body: string;
  targetPlan?: string;
  targetStatus?: string;
  recipientCount: number;
  sentAt: string;
  sentBy: string;
}
```

and change it to:

```ts
export interface Announcement {
  id: string;
  title: string;
  body: string;
  targetPlan?: string;
  targetStatus?: string;
  recipientCount: number;
  createdAt: string;
  sentBy: string;
  senderName?: string | null;
}
```

In `admin/app/(admin)/announcements/page.tsx`, find:

```tsx
                    <TableCell className="text-sm text-muted-foreground">
                      {a.sentAt ? format(new Date(a.sentAt), 'dd.MM.yyyy HH:mm') : '—'}
                    </TableCell>
                    <TableCell className="text-sm">{a.sentBy}</TableCell>
```

and change it to:

```tsx
                    <TableCell className="text-sm text-muted-foreground">
                      {a.createdAt ? format(new Date(a.createdAt), 'dd.MM.yyyy HH:mm') : '—'}
                    </TableCell>
                    <TableCell className="text-sm">{a.senderName ?? a.sentBy}</TableCell>
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm test -- app/\(admin\)/announcements/page.test.tsx`

Expected: PASS (both tests).

- [ ] **Step 9: Run `tsc` to confirm no other file references the removed `sentAt` field**

Run (from `admin/`): `npx tsc --noEmit`

Expected: no errors.

- [ ] **Step 10: Commit**

```bash
cd api
git add src/modules/admin/admin.service.ts src/modules/admin/admin.service.spec.ts
git commit -m "fix(admin-api): listAnnouncements resolves sentBy to a real admin name

Announcement.sentBy is a bare String column (no Prisma relation), so
listAnnouncements() returned it as a raw UUID. Batch-fetch names for
the page's distinct sentBy values, mirroring the exact pattern
listAuditLog() already uses for its identical problem."

cd ../admin
git add lib/types.ts app/\(admin\)/announcements/page.tsx app/\(admin\)/announcements/page.test.tsx
git commit -m "fix(admin): announcements history shows resolved sender name and date

Frontend read a.sentAt (field doesn't exist — model only has
createdAt) and rendered the raw sentBy UUID directly. Now reads
createdAt and the backend-resolved senderName, falling back to the
raw id only if the sending admin was since deleted."
```

---

### Task 6: Full regression run, live re-verification, and the final readiness summary

**Files:** None modified — verification and reporting only.

- [ ] **Step 1: Run the full admin test suite**

Run (from `admin/`): `npm test`

Expected: all tests pass, including the 39 pre-existing tests and the new ones from Tasks 1–5 (should be roughly 39 + 2 + 2 + 2 + 2 + 2 = ~49, exact count depends on how many assertions per `it` — confirm no failures, don't worry about matching this exact number).

- [ ] **Step 2: Run the full backend admin module tests**

Run (from `api/`): `npx jest src/modules/admin/`

Expected: all pass, including the extended `admin.service.spec.ts`.

- [ ] **Step 3: Rebuild and restart the admin dev server**

```bash
cd admin
# Kill any existing dev server on :3000 first if one is running.
npm run dev
```

Wait for "Ready" in the output before proceeding.

- [ ] **Step 4: Re-verify the six fixes live, using Playwright against the real backend**

With the backend running on `:4455` (with the seed data from `api/scripts/seed-admin-test.ts` already applied) and the admin dev server on `:3000`, log in as `+992000000000` / `admin123` and check, for each fix:

1. **Proxy fix**: navigate to `/users`, `/stores`, `/subscriptions` — all three must show real rows (13 users, 10 stores, 2 subscriptions), not "не найдено". Check the browser console for the absence of `ERR_CONTENT_DECODING_FAILED`.
2. **Dashboard contract fix**: on `/dashboard`, "Активные подписки" shows 2 (not 0), "Истекшие" shows 7, "Выручка за месяц" shows a formatted TJS amount (not "не число").
3. **Mock-data fix**: on `/dashboard`, reload with the network tab open — confirm the revenue/registrations charts never flash a populated random-looking series before settling on the real (possibly sparse) data.
4. **Hydration fix**: open the browser devtools console on any admin page — confirm no "Hydration failed" / "server rendered text didn't match the client" warning appears.
5. **Announcements fix**: on `/announcements`, the seeded "Добро пожаловать!" row shows "Admin" (or whatever the seed admin's name is) in "Отправитель", not a raw UUID, and a real date in "Отправлено", not "—".

- [ ] **Step 5: Broader live audit of remaining admin actions (not fixed this round, just verified)**

Per the spec's "Live re-verification" section, exercise what wasn't tested in the original discovery pass, to inform the final summary:
- Extend a subscription / change a store's tariff from `/subscriptions` (now that the list loads).
- Save a tariff change on `/subscriptions/plans` and confirm it persists (reload the page).
- Block/unblock a user and impersonate ("Войти как пользователь") from a user detail page.
- Create a banner on `/banners` and confirm it appears in "Все баннеры".
- Send an announcement from `/announcements` and confirm the history table updates.
- Check `/audit-log` after performing one of the above actions — confirm a row now appears (or note if it still doesn't, as a new finding).

- [ ] **Step 6: Write the final summary**

Produce a plain-text (not a file — respond directly) summary covering: which of the 6 fixes are confirmed working live, results of the Step 5 broader audit (what works, any new findings), and an overall admin-panel readiness verdict. This directly answers the user's original two-part request ("план... потом протестируй... и сделай сводку").

---

## Self-Review Notes

- **Spec coverage:** all 6 spec items map 1:1 to Tasks 1–5 (Task 5 covers both halves of item 5 — backend batch-lookup and frontend render — since they're one logical fix across two files). Task 6 covers both the spec's "Live re-verification" section and the user's explicit "test + summary" follow-up ask.
- **No placeholders:** every step shows complete, exact code; no "add appropriate handling" shortcuts anywhere.
- **Type consistency:** `senderName?: string | null` is used identically in the backend's returned object shape (Task 5, Step 3), the `Announcement` TS interface (Task 5, Step 7), and the frontend render/test (Task 5, Steps 5 and 7). `DashboardStats`'s `subscriptionsByStatus`/`approvedPaymentsThisMonth`/`newUsersThisMonth`/`newStoresThisMonth` names are used identically across Task 2's type change, card mapping, and test's MSW handler payload.
