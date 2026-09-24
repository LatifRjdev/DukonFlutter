# Admin Panel Bugfixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the five confirmed admin-panel action bugs (tariffs save/display, announcement sending, store-ownership transfer, subscription plan change, false error toast on direct messages) so every mutating action actually performs what it claims and reports an accurate result.

**Architecture:** Each bug is a payload/type contract mismatch between the Next.js admin frontend (`admin/`) and the already-correct NestJS backend (`api/`) — the backend is never touched in this plan, only the frontend is brought into agreement with it. Each task fixes one bug and adds a regression test that inspects the *actual request body/behavior*, not just "a mutation fired."

**Tech Stack:** Next.js 16 (App Router), React, TanStack Query, shadcn/ui, Vitest + Testing Library + MSW.

**Working directory for all tasks:** `/Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/admin-panel-bugfixes` (branch `feature/admin-panel-bugfixes`). `.env.local` is already copied into `admin/`, `.env` into `api/`, and `npm install` has already been run in both. All file paths below are relative to the repo root (i.e. `.worktrees/admin-panel-bugfixes/admin/...`).

**Running admin tests:** `cd admin && npm test` runs the full Vitest suite once. To run a single file: `cd admin && npx vitest run <path>`.

---

### Task 1: Fix the `Plan` type to match the real backend shape

**Files:**
- Modify: `admin/lib/types.ts:70-89`

The backend's `GET /admin/plans` (`api/src/modules/admin/admin.service.ts` `listPlans()`) returns rows shaped like:
```json
{"plan":"START","price":200,"maxProducts":500,"maxStaff":2,"maxDiscounts":0,"hasReportsAll":false,"hasExport":false,"hasTelegram":false,"hasAllPush":false,"hasDelivery":false,"hasInventory":false,"hasZakat":false,"hasInvestments":false,"hasLoyalty":false,"hasBatchProfitability":false,"hasEcommerceIntegration":false}
```
There is no `id`, no `name`, no `maxStores` — the current `Plan` interface has all three and is missing nothing else. This task only changes the type; Task 2 fixes the page that uses it (changing them together would make Task 2's diff harder to review).

- [ ] **Step 1: Update the `Plan` interface**

Open `admin/lib/types.ts` and replace lines 70-89:

```ts
export interface Plan {
  id: string;
  name: string;
  price: number;
  maxStores: number;
  maxProducts: number;
  maxStaff: number;
  maxDiscounts: number;
  hasReportsAll: boolean;
  hasExport: boolean;
  hasTelegram: boolean;
  hasAllPush: boolean;
  hasDelivery: boolean;
  hasInventory: boolean;
  hasEcommerceIntegration: boolean;
  hasZakat: boolean;
  hasInvestments: boolean;
  hasLoyalty: boolean;
  hasBatchProfitability: boolean;
}
```

with:

```ts
export interface Plan {
  plan: 'START' | 'BUSINESS' | 'PREMIUM';
  price: number;
  maxProducts: number;
  maxStaff: number;
  maxDiscounts: number;
  hasReportsAll: boolean;
  hasExport: boolean;
  hasTelegram: boolean;
  hasAllPush: boolean;
  hasDelivery: boolean;
  hasInventory: boolean;
  hasEcommerceIntegration: boolean;
  hasZakat: boolean;
  hasInvestments: boolean;
  hasLoyalty: boolean;
  hasBatchProfitability: boolean;
}
```

- [ ] **Step 2: Confirm the rest of the codebase doesn't reference the removed fields yet**

Run: `cd admin && npx tsc --noEmit`

Expected: FAILS — `admin/app/(admin)/subscriptions/plans/page.tsx` still references `plan.id`, `plan.name`, `plan.maxStores` (that's exactly what Task 2 fixes). This confirms the type change took effect and that `plans/page.tsx` is the only consumer.

- [ ] **Step 3: Commit**

```bash
git add admin/lib/types.ts
git commit -m "fix(admin): Plan type matches real /admin/plans response shape"
```

---

### Task 2: Fix the Tariffs page (blank titles + save always failing)

**Files:**
- Modify: `admin/app/(admin)/subscriptions/plans/page.tsx` (full rewrite of the parts touching `id`/`name`/`maxStores`)
- Test: `admin/app/(admin)/subscriptions/plans/page.test.tsx` (new file — this page has no test coverage today)

`PlanCard` renders `plan.name` (now removed from the type, and never existed on the real response) as its title, keys elements off `plan.id` (also removed/never existed), and `saveMutation` PUTs the *entire* local `Plan` object to `/admin/plans/${plan.id}` — sending `id`/`name`/`maxStores` that the backend's `UpdatePlanDto` rejects (`whitelist: true, forbidNonWhitelisted: true` in `api/src/main.ts`), and hitting `/admin/plans/undefined` since `id` doesn't exist.

- [ ] **Step 1: Write the failing test**

Create `admin/app/(admin)/subscriptions/plans/page.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../../test/msw/server';

import PlansPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

const REAL_PLAN_SHAPE = {
  plan: 'START',
  price: 200,
  maxProducts: 500,
  maxStaff: 2,
  maxDiscounts: 0,
  hasReportsAll: false,
  hasExport: false,
  hasTelegram: false,
  hasAllPush: false,
  hasDelivery: false,
  hasInventory: false,
  hasZakat: false,
  hasInvestments: false,
  hasLoyalty: false,
  hasBatchProfitability: false,
  hasEcommerceIntegration: false,
};

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('PlansPage reads/writes the real backend shape (no id/name/maxStores)', () => {
  it('renders the plan name from the "plan" field, not the nonexistent "name" field', async () => {
    server.use(
      http.get(`${API_URL}/admin/plans`, () => HttpResponse.json([REAL_PLAN_SHAPE])),
    );

    renderWithQuery(<PlansPage />);

    await waitFor(() => expect(screen.getByText('START')).toBeInTheDocument());
  });

  it('Save PUTs only UpdatePlanDto fields to /admin/plans/<plan>, never id/name/maxStores', async () => {
    server.use(
      http.get(`${API_URL}/admin/plans`, () => HttpResponse.json([REAL_PLAN_SHAPE])),
    );

    const captured: { url?: string; body?: unknown } = {};
    server.use(
      http.put(`${API_URL}/admin/plans/:plan`, async ({ request, params }) => {
        captured.url = `/admin/plans/${params.plan}`;
        captured.body = await request.json();
        return HttpResponse.json({ ...REAL_PLAN_SHAPE, price: 999 });
      }),
    );

    renderWithQuery(<PlansPage />);
    await waitFor(() => expect(screen.getByText('START')).toBeInTheDocument());

    const priceInput = screen.getByLabelText('Цена (сом/месяц)');
    await userEvent.clear(priceInput);
    await userEvent.type(priceInput, '999');
    await userEvent.click(screen.getByRole('button', { name: /Сохранить/i }));

    await waitFor(() => expect(captured.url).toBe('/admin/plans/START'));
    expect(captured.body).not.toHaveProperty('id');
    expect(captured.body).not.toHaveProperty('name');
    expect(captured.body).not.toHaveProperty('maxStores');
    expect(captured.body).toMatchObject({ price: 999, maxProducts: 500 });
  });

  it('does not render a "Макс. магазинов" field (maxStores no longer exists on the backend)', async () => {
    server.use(
      http.get(`${API_URL}/admin/plans`, () => HttpResponse.json([REAL_PLAN_SHAPE])),
    );

    renderWithQuery(<PlansPage />);
    await waitFor(() => expect(screen.getByText('START')).toBeInTheDocument());

    expect(screen.queryByText('Макс. магазинов')).not.toBeInTheDocument();
  });
});
```

The `Label` components in `plans/page.tsx` aren't yet wired to their `Input` via `htmlFor`/`id`, so `getByLabelText('Цена (сом/месяц)')` will fail even after the type/field fixes unless Step 3 also adds that wiring — this is called out explicitly in Step 3 below.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run app/\(admin\)/subscriptions/plans/page.test.tsx`
Expected: FAIL (compile error or missing "START" text — `plan.name` is `undefined` today).

- [ ] **Step 3: Rewrite `plans/page.tsx`**

Replace the entire file content with:

```tsx
'use client';

import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import { api } from '@/lib/api';
import { Plan } from '@/lib/types';
import { toast } from 'sonner';

const PLAN_CONFIGS = [
  { key: 'START', label: 'START', color: 'border-gray-300' },
  { key: 'BUSINESS', label: 'BUSINESS', color: 'border-blue-300' },
  { key: 'PREMIUM', label: 'PREMIUM', color: 'border-purple-400' },
];

const FEATURE_LABELS: Record<string, string> = {
  hasReportsAll: 'Расширенные отчёты',
  hasExport: 'Экспорт данных',
  hasTelegram: 'Telegram бот',
  hasAllPush: 'Push-уведомления',
  hasDelivery: 'Доставка',
  hasInventory: 'Инвентаризация',
  hasEcommerceIntegration: 'Интернет-магазин',
  hasZakat: 'Закят',
  hasInvestments: 'Инвестиции',
  hasLoyalty: 'Программа лояльности',
  hasBatchProfitability: 'Прибыльность по партиям',
};

// Fields UpdatePlanDto (api/src/modules/admin/dto/update-plan.dto.ts) accepts.
// Built explicitly (not a spread of the whole edited object) so a future
// field added to the Plan type can't silently reintroduce a
// forbidNonWhitelisted 400 the way `id`/`name`/`maxStores` once did.
function toUpdatePayload(plan: Plan) {
  return {
    price: plan.price,
    maxProducts: plan.maxProducts,
    maxStaff: plan.maxStaff,
    maxDiscounts: plan.maxDiscounts,
    hasReportsAll: plan.hasReportsAll,
    hasExport: plan.hasExport,
    hasTelegram: plan.hasTelegram,
    hasAllPush: plan.hasAllPush,
    hasDelivery: plan.hasDelivery,
    hasInventory: plan.hasInventory,
    hasEcommerceIntegration: plan.hasEcommerceIntegration,
    hasZakat: plan.hasZakat,
    hasInvestments: plan.hasInvestments,
    hasLoyalty: plan.hasLoyalty,
    hasBatchProfitability: plan.hasBatchProfitability,
  };
}

function PlanCard({ plan, onSave }: { plan: Plan; onSave: (p: Plan) => void }) {
  const [edited, setEdited] = useState<Plan>(plan);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    setEdited(plan);
    setDirty(false);
  }, [plan]);

  const update = <K extends keyof Plan>(key: K, value: Plan[K]) => {
    setEdited((prev) => ({ ...prev, [key]: value }));
    setDirty(true);
  };

  const config = PLAN_CONFIGS.find((c) => c.key === plan.plan) || PLAN_CONFIGS[0];

  return (
    <Card className={`border-2 ${config.color}`}>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">{plan.plan}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Numeric fields */}
        <div className="space-y-3">
          {(
            [
              ['price', 'Цена (сом/месяц)'],
              ['maxProducts', 'Макс. товаров'],
              ['maxStaff', 'Макс. сотрудников'],
              ['maxDiscounts', 'Макс. скидок'],
            ] as [keyof Plan, string][]
          ).map(([key, label]) => (
            <div key={key} className="grid grid-cols-2 items-center gap-2">
              <Label htmlFor={`${plan.plan}-${key}`} className="text-sm">
                {label}
              </Label>
              <Input
                id={`${plan.plan}-${key}`}
                type="number"
                min="0"
                value={edited[key] as number}
                onChange={(e) => update(key, Number(e.target.value) as Plan[keyof Plan])}
                className="h-8"
              />
            </div>
          ))}
        </div>

        <Separator />

        {/* Feature toggles */}
        <div className="space-y-3">
          {Object.entries(FEATURE_LABELS).map(([key, label]) => (
            <div key={key} className="flex items-center justify-between">
              <Label className="text-sm cursor-pointer" htmlFor={`${plan.plan}-${key}`}>
                {label}
              </Label>
              <Switch
                id={`${plan.plan}-${key}`}
                checked={edited[key as keyof Plan] as boolean}
                onCheckedChange={(checked) =>
                  update(key as keyof Plan, checked as Plan[keyof Plan])
                }
              />
            </div>
          ))}
        </div>

        <Button
          className="w-full"
          disabled={!dirty}
          onClick={() => onSave(edited)}
        >
          <Save className="mr-2 h-4 w-4" />
          Сохранить
        </Button>
      </CardContent>
    </Card>
  );
}

export default function PlansPage() {
  const queryClient = useQueryClient();

  const { data: plans = [], isLoading } = useQuery<Plan[]>({
    queryKey: ['plans'],
    queryFn: () => api.get('/admin/plans'),
  });

  const saveMutation = useMutation({
    mutationFn: (plan: Plan) => api.put(`/admin/plans/${plan.plan}`, toUpdatePayload(plan)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['plans'] });
      toast.success('Тариф сохранён');
    },
    onError: () => toast.error('Ошибка сохранения тарифа'),
  });

  if (isLoading) {
    return (
      <div className="grid grid-cols-3 gap-6">
        {[1, 2, 3].map((i) => (
          <div key={i} className="h-96 animate-pulse rounded-lg bg-slate-100" />
        ))}
      </div>
    );
  }

  // If no plans from API, show placeholders (same shape as the real response).
  const displayPlans: Plan[] =
    plans.length > 0
      ? plans
      : PLAN_CONFIGS.map((c, i) => ({
          plan: c.key as Plan['plan'],
          price: i === 0 ? 49 : i === 1 ? 99 : 199,
          maxProducts: i === 0 ? 100 : i === 1 ? 500 : 99999,
          maxStaff: i === 0 ? 2 : i === 1 ? 5 : 20,
          maxDiscounts: i === 0 ? 5 : i === 1 ? 20 : 99999,
          hasReportsAll: i > 0,
          hasExport: i > 0,
          hasTelegram: i > 1,
          hasAllPush: i > 1,
          hasDelivery: i > 1,
          hasInventory: i === 2,
          hasEcommerceIntegration: i === 2,
          hasZakat: i === 2,
          hasInvestments: i === 2,
          hasLoyalty: i === 2,
          hasBatchProfitability: i === 2,
        }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Тарифы</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Настройка параметров тарифных планов
        </p>
      </div>

      {saveMutation.isPending && (
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          Сохранение...
        </div>
      )}

      <div className="grid grid-cols-3 gap-6">
        {displayPlans.map((plan) => (
          <PlanCard
            key={plan.plan}
            plan={plan}
            onSave={(p) => saveMutation.mutate(p)}
          />
        ))}
      </div>
    </div>
  );
}
```

Note what changed from the original: `plan.name` → `plan.plan` (title + config lookup + `key=`), `plan.id` → `plan.plan` (mutation URL + `htmlFor`/`id` wiring + fallback array key), the "Макс. магазинов" row deleted from the numeric-fields array, `saveMutation` now sends `toUpdatePayload(plan)` instead of the raw `plan` object, and the loading-placeholder fallback array now matches the real `Plan` shape (no `id`/`name`/`maxStores`). Every `Input` now has a matching `id`/`htmlFor` pair so `getByLabelText` works in tests (and so clicking the visible `<Label>` focuses the field for real users — a correctness fix that happened to be needed for the test).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run app/\(admin\)/subscriptions/plans/page.test.tsx`
Expected: PASS (3 tests)

- [ ] **Step 5: Full type-check**

Run: `cd admin && npx tsc --noEmit`
Expected: PASS (no errors)

- [ ] **Step 6: Commit**

```bash
git add "admin/app/(admin)/subscriptions/plans/page.tsx" "admin/app/(admin)/subscriptions/plans/page.test.tsx"
git commit -m "fix(admin): tariffs page renders real plan name and saves only whitelisted fields"
```

---

### Task 3: Fix announcements preview payload (missing title/body)

**Files:**
- Modify: `admin/app/(admin)/announcements/page.tsx:53-58`
- Modify: `admin/app/(admin)/announcements/page.test.tsx` (extend with a new test)

`previewMutation` (called by `handleSend`, which is what the "Отправить" button triggers) posts only `{ targetPlan, targetStatus }` to `/admin/announcements/preview`. The backend's `CreateAnnouncementDto` requires non-empty `title` and `body`, so this 400s before the real send is ever attempted, even though `title`/`body` are already validated non-empty by `handleSend` one line above the `previewMutation.mutate()` call.

- [ ] **Step 1: Write the failing test**

Add to the bottom of `admin/app/(admin)/announcements/page.test.tsx` (new `describe` block, same file, same imports already present):

```tsx
describe('AnnouncementsPage preview request includes title and body', () => {
  it('POSTs title and body (not just targetPlan/targetStatus) to /admin/announcements/preview', async () => {
    server.use(
      http.get(`${API_URL}/admin/announcements`, () =>
        HttpResponse.json({ data: [], total: 0, page: 1, limit: 20 }),
      ),
    );

    const captured: { body?: unknown } = {};
    server.use(
      http.post(`${API_URL}/admin/announcements/preview`, async ({ request }) => {
        captured.body = await request.json();
        return HttpResponse.json({ count: 3 });
      }),
    );

    renderWithQuery(<AnnouncementsPage />);

    await userEvent.type(
      screen.getByPlaceholderText(/Новые функции/i),
      'QA Title',
    );
    await userEvent.type(
      screen.getByPlaceholderText(/Введите текст объявления/i),
      'QA Body',
    );
    await userEvent.click(screen.getByRole('button', { name: /Отправить/i }));

    await waitFor(() => expect(captured.body).toMatchObject({
      title: 'QA Title',
      body: 'QA Body',
    }));
  });
});
```

This test file doesn't import `userEvent` yet — add it to the existing import block at the top:

```tsx
import userEvent from '@testing-library/user-event';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run app/\(admin\)/announcements/page.test.tsx`
Expected: FAIL — `captured.body` is `{targetPlan: undefined, targetStatus: undefined}`, missing `title`/`body`.

- [ ] **Step 3: Fix the preview payload**

In `admin/app/(admin)/announcements/page.tsx`, find:

```ts
  const previewMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/announcements/preview', {
        targetPlan: targetPlan === 'all' ? undefined : targetPlan,
        targetStatus: targetStatus === 'all' ? undefined : targetStatus,
      }),
```

Replace with:

```ts
  const previewMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/announcements/preview', {
        title,
        body,
        targetPlan: targetPlan === 'all' ? undefined : targetPlan,
        targetStatus: targetStatus === 'all' ? undefined : targetStatus,
      }),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run app/\(admin\)/announcements/page.test.tsx`
Expected: PASS (3 tests total in the file)

- [ ] **Step 5: Commit**

```bash
git add "admin/app/(admin)/announcements/page.tsx" "admin/app/(admin)/announcements/page.test.tsx"
git commit -m "fix(admin): announcement preview sends title/body so sending actually works"
```

---

### Task 4: Fix store-transfer field name in both locations

**Files:**
- Modify: `admin/app/(admin)/stores/page.tsx:89-96` (mutation) and `:322-326` (call site)
- Modify: `admin/app/(admin)/stores/[id]/page.tsx:76-79` (mutation) and `:279` (call site)
- Modify: `admin/app/(admin)/stores/page.test.tsx` (extend)
- Test: `admin/app/(admin)/stores/[id]/page.test.tsx` (new file — this page has no test coverage today)

Both dialogs call `api.put(.../transfer, { userId })`. The backend's `TransferStoreDto` requires `newOwnerId`. Every transfer 400s with `"Поле «userId» не разрешено"`.

- [ ] **Step 1: Write the failing test for the list page**

`admin/app/(admin)/stores/page.test.tsx` already has a `mockSingleStore(active)` helper, a `renderWithQuery` helper, an `API_URL` const, and mocks `sonner`'s `toast` via `toastSuccess`/`toastError` spies (see its existing "destructive action: suspend / activate" describe block) — reuse all of these rather than redefining them. The row's action menu is opened via `document.querySelector('[data-slot="dropdown-menu-trigger"]')`, exactly like the existing suspend/restore tests. Add this new `describe` block to the bottom of the file:

```tsx
describe('StoresPage — transfer ownership sends newOwnerId, not userId', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('PUTs { newOwnerId } to /admin/stores/:id/transfer', async () => {
    mockSingleStore(true);

    const captured: { body?: unknown } = {};
    server.use(
      http.put(`${API_URL}/admin/stores/s1/transfer`, async ({ request }) => {
        captured.body = await request.json();
        return HttpResponse.json({ id: 's1', ownerId: 'owner-2', name: 'Active Mart' });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const transferItem = await screen.findByText('Передать владение');
    await user.click(transferItem);

    await user.type(screen.getByPlaceholderText('Введите ID пользователя'), 'owner-2');
    // Exact-string match (default for getByRole's `name`) so this doesn't
    // also match the "Передать владение" dropdown item from above.
    await user.click(screen.getByRole('button', { name: 'Передать' }));

    await waitFor(() => expect(captured.body).toEqual({ newOwnerId: 'owner-2' }));
    expect(toastSuccess).toHaveBeenCalledWith('Владелец магазина изменён');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run app/\(admin\)/stores/page.test.tsx`
Expected: FAIL — `captured.body` is `{ userId: 'owner-2' }`, not `{ newOwnerId: 'owner-2' }`.

- [ ] **Step 3: Fix `stores/page.tsx`**

Find:

```ts
  const transferMutation = useMutation({
    mutationFn: ({ storeId, userId }: { storeId: string; userId: string }) =>
      api.put(`/admin/stores/${storeId}/transfer`, { userId }),
```

Replace with:

```ts
  const transferMutation = useMutation({
    mutationFn: ({ storeId, newOwnerId }: { storeId: string; newOwnerId: string }) =>
      api.put(`/admin/stores/${storeId}/transfer`, { newOwnerId }),
```

Find the call site:

```ts
                transferMutation.mutate({
                  storeId: transferDialog.id,
                  userId: newOwnerId,
                })
```

Replace with:

```ts
                transferMutation.mutate({
                  storeId: transferDialog.id,
                  newOwnerId,
                })
```

(`newOwnerId` here is the existing local state variable holding the input's value — only the object *key* it's assigned to changes, from `userId` to the shorthand `newOwnerId`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run app/\(admin\)/stores/page.test.tsx`
Expected: PASS

- [ ] **Step 5: Write the failing test for the store detail page**

`StoreDetailPage` reads its route param via React's `use(params)`
(`params: Promise<{ id: string }>`), the same pattern
`admin/app/(admin)/users/[id]/page.tsx` uses — **not** `useParams()` from
`next/navigation`. That means rendering it in a test needs a `<Suspense>`
boundary and an async `act()` around the initial render, exactly like
`admin/app/(admin)/users/[id]/page.test.tsx` already does. Create
`admin/app/(admin)/stores/[id]/page.test.tsx` by copying that file's
`renderWithQuery` helper verbatim:

```tsx
import { Suspense } from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, act } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

const toastSuccess = vi.fn();
const toastError = vi.fn();
vi.mock('sonner', () => ({
  toast: {
    success: (msg: string) => toastSuccess(msg),
    error: (msg: string) => toastError(msg),
  },
}));

import StoreDetailPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

async function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  // StoreDetailPage reads its `id` param via React's use(params), which
  // suspends on first render until the params Promise resolves (see the
  // identical comment/pattern in users/[id]/page.test.tsx).
  let result!: ReturnType<typeof render>;
  await act(async () => {
    result = render(
      <QueryClientProvider client={qc}>
        <Suspense fallback={null}>{ui}</Suspense>
      </QueryClientProvider>,
    );
  });
  return result;
}

function mockStore() {
  server.use(
    http.get(`${API_URL}/admin/stores/s1`, () =>
      HttpResponse.json({
        id: 's1',
        name: 'Test Store',
        category: 'OTHER',
        isActive: true,
        owner: { id: 'owner-1', name: 'Owner One', phone: '+992900000001' },
      }),
    ),
    http.get(`${API_URL}/admin/stores/s1/subscription`, () =>
      HttpResponse.json({ plan: 'START', status: 'ACTIVE', currentPeriodEnd: '2026-12-01' }),
    ),
  );
}

function renderPage() {
  return renderWithQuery(<StoreDetailPage params={Promise.resolve({ id: 's1' })} />);
}

describe('StoreDetailPage — transfer ownership sends newOwnerId, not userId', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('PUTs { newOwnerId } to /admin/stores/:id/transfer', async () => {
    mockStore();

    const captured: { body?: unknown } = {};
    server.use(
      http.put(`${API_URL}/admin/stores/s1/transfer`, async ({ request }) => {
        captured.body = await request.json();
        return HttpResponse.json({ id: 's1', ownerId: 'owner-2', name: 'Test Store' });
      }),
    );

    const user = userEvent.setup();
    await renderPage();
    await waitFor(() => screen.getByText('Test Store'));

    await user.click(screen.getByRole('button', { name: 'Передать владение' }));
    await user.type(screen.getByPlaceholderText('Введите ID пользователя'), 'owner-2');
    await user.click(screen.getByRole('button', { name: 'Передать' }));

    await waitFor(() => expect(captured.body).toEqual({ newOwnerId: 'owner-2' }));
    expect(toastSuccess).toHaveBeenCalledWith('Владелец магазина изменён');
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd admin && npx vitest run "app/(admin)/stores/[id]/page.test.tsx"`
Expected: FAIL — `captured.body` is `{ userId: 'owner-2' }`.

- [ ] **Step 7: Fix `stores/[id]/page.tsx`**

Find:

```ts
  const transferMutation = useMutation({
    mutationFn: (userId: string) =>
      api.put(`/admin/stores/${id}/transfer`, { userId }),
```

Replace with:

```ts
  const transferMutation = useMutation({
    mutationFn: (newOwnerId: string) =>
      api.put(`/admin/stores/${id}/transfer`, { newOwnerId }),
```

(The call site `transferMutation.mutate(newOwnerId)` at line 279 needs no change — it already passes the raw string; only the mutation's internal parameter name and payload key needed fixing, and renaming the parameter is purely cosmetic/for-clarity here since it's positional.)

- [ ] **Step 8: Run test to verify it passes**

Run: `cd admin && npx vitest run "app/(admin)/stores/[id]/page.test.tsx"`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add "admin/app/(admin)/stores/page.tsx" "admin/app/(admin)/stores/page.test.tsx" "admin/app/(admin)/stores/[id]/page.tsx" "admin/app/(admin)/stores/[id]/page.test.tsx"
git commit -m "fix(admin): store transfer sends newOwnerId matching TransferStoreDto"
```

---

### Task 5: Fix subscription change-plan field name

**Files:**
- Modify: `admin/app/(admin)/subscriptions/page.tsx:108-116` (mutation) and `:489` (call site)
- Modify: `admin/app/(admin)/subscriptions/page.test.tsx` (extend)

`changePlanMutation` sends `{ planId }`. The backend's `ChangePlanDto` requires `plan`.

- [ ] **Step 1: Write the failing test**

`admin/app/(admin)/subscriptions/page.test.tsx` already has a `mockSubscriptionsAndPending()` helper (note: `/admin/subscriptions` returns a **raw array**, not a `{data: [...]}` envelope — see the comment above that helper), `renderWithQuery`/`API_URL`, and `toastSuccess`/`toastError` spies on `sonner`. The row menu opens the same way as the existing "cancel subscription" test: `document.querySelector('[data-slot="dropdown-menu-trigger"]')`. Add this new `describe` block to the bottom of the file:

```tsx
describe('SubscriptionsPage — change-plan sends { plan }, not { planId }', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('PUTs { plan } to /admin/subscriptions/:id/change-plan', async () => {
    mockSubscriptionsAndPending();

    const captured: { body?: unknown } = {};
    server.use(
      http.put(`${API_URL}/admin/subscriptions/sub1/change-plan`, async ({ request }) => {
        captured.body = await request.json();
        return HttpResponse.json({ id: 'sub1', plan: 'PREMIUM', status: 'ACTIVE' });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<SubscriptionsPage />);
    await waitFor(() => screen.getByText('Demo Store'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const changePlanItem = await screen.findByText('Изменить тариф');
    await user.click(changePlanItem);

    await user.click(screen.getByRole('combobox'));
    await user.click(await screen.findByRole('option', { name: 'PREMIUM' }));
    await user.click(screen.getByRole('button', { name: 'Изменить' }));

    await waitFor(() => expect(captured.body).toEqual({ plan: 'PREMIUM' }));
    expect(toastSuccess).toHaveBeenCalledWith('Тариф изменён');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run app/\(admin\)/subscriptions/page.test.tsx`
Expected: FAIL — `captured.body` is `{ planId: 'PREMIUM' }`.

- [ ] **Step 3: Fix the mutation**

Find:

```ts
  const changePlanMutation = useMutation({
    mutationFn: ({ id, planId }: { id: string; planId: string }) =>
      api.put(`/admin/subscriptions/${id}/change-plan`, { planId }),
```

Replace with:

```ts
  const changePlanMutation = useMutation({
    mutationFn: ({ id, plan }: { id: string; plan: string }) =>
      api.put(`/admin/subscriptions/${id}/change-plan`, { plan }),
```

Find the call site:

```ts
                changePlanMutation.mutate({ id: changePlanStore.id, planId: newPlan })
```

Replace with:

```ts
                changePlanMutation.mutate({ id: changePlanStore.id, plan: newPlan })
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run app/\(admin\)/subscriptions/page.test.tsx`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "admin/app/(admin)/subscriptions/page.tsx" "admin/app/(admin)/subscriptions/page.test.tsx"
git commit -m "fix(admin): subscription plan-change sends plan matching ChangePlanDto"
```

---

### Task 6: Fix `apiFetch` crashing on empty-body responses

**Files:**
- Modify: `admin/lib/api.ts:34-38`
- Modify: `admin/lib/api.test.ts` (extend)

`apiFetch` always does `return res.json();` on a successful response. `POST /admin/notifications/direct` (and any future controller method returning `Promise<void>`) sends an empty body with its 2xx status, so `res.json()` throws `SyntaxError: Unexpected end of JSON input`. This rejects the promise, so React Query's `onError` fires even though the request fully succeeded — the admin always sees "Ошибка отправки сообщения" for a message that was actually sent.

- [ ] **Step 1: Write the failing test**

Add to `admin/lib/api.test.ts` (inside the existing top-level `describe('lib/api', ...)` block, alongside the other `it(...)`s):

```ts
  it('api.post resolves (does not throw) when the response body is empty', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async () => {
      // Mirrors a NestJS controller method returning Promise<void>: 201,
      // empty body — matches POST /admin/notifications/direct. Verified
      // empirically that `new Response(null, {...})` has NO Content-Length
      // header in Node's fetch (not "0" — absent), so the fix must not
      // rely on that header to detect an empty body.
      return new Response(null, { status: 201 });
    });

    await expect(api.post('/admin/notifications/direct', { userId: 'u1' })).resolves.toBeUndefined();

    fetchSpy.mockRestore();
  });

  it('api.post still parses a normal JSON body on success (no regression)', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async () => {
      return new Response(JSON.stringify({ id: 'sub-1', plan: 'PREMIUM' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });

    const result = await api.post('/admin/subscriptions/sub-1/change-plan', { plan: 'PREMIUM' });
    expect(result).toEqual({ id: 'sub-1', plan: 'PREMIUM' });

    fetchSpy.mockRestore();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run lib/api.test.ts`
Expected: The first new test FAILS — `api.post(...)` rejects with a `SyntaxError` instead of resolving to `undefined`. The second new test passes already (no regression to guard yet, but it locks in current correct behavior before the fix).

- [ ] **Step 3: Fix `apiFetch`**

In `admin/lib/api.ts`, find:

```ts
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.message || `HTTP ${res.status}`);
  }
  return res.json();
}
```

Replace with:

```ts
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.message || `HTTP ${res.status}`);
  }
  // Some admin endpoints (e.g. POST /admin/notifications/direct) return a
  // controller method typed Promise<void> — NestJS sends an empty 2xx body
  // for those. res.json() throws SyntaxError on an empty body, which would
  // otherwise surface as a false "error" toast for a request that actually
  // succeeded. Read as text first (no Content-Length header can be relied
  // on to detect this — an empty-bodied Response has none at all) and only
  // parse when there's something to parse.
  const text = await res.text();
  return text ? JSON.parse(text) : undefined;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run lib/api.test.ts`
Expected: PASS (5 tests total in the file)

- [ ] **Step 5: Commit**

```bash
git add admin/lib/api.ts admin/lib/api.test.ts
git commit -m "fix(admin): apiFetch no longer throws on empty-body 2xx responses"
```

---

### Task 7: Full suite + type-check, then final review prep

**Files:** none (verification only)

- [ ] **Step 1: Run the full admin test suite**

Run: `cd admin && npm test`
Expected: All tests PASS (the pre-existing suite plus every test added in Tasks 2-6).

- [ ] **Step 2: Full type-check**

Run: `cd admin && npx tsc --noEmit`
Expected: PASS, no errors.

- [ ] **Step 3: Lint**

Run: `cd admin && npm run lint` (check `admin/package.json` for the exact script name if this differs)
Expected: PASS, no new warnings introduced by these changes.

No commit for this task — it's a checkpoint before the live-verification pass and final code review described in the project's standard subagent-driven-development flow (final whole-branch reviewer, then live Playwright re-verification against the real backend per the spec's "Live re-verification" section, then `superpowers:finishing-a-development-branch`).
