# Admin Panel Rough Edges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a delete-user action, replace the raw-UUID store-transfer input with a name/phone picker, and add a confirmation step to the panel's 9 one-click destructive actions.

**Architecture:** Two new small, reusable components (`ConfirmDialog`, `UserPicker`) built on the `Dialog`/`Input` primitives already in this codebase (no new dependencies), then wired into the existing pages at each call site. Every wiring change follows the identical shape: an existing `onClick={() => xMutation.mutate(...)}` becomes `onClick={() => setConfirmOpen(true)}`, and the mutate call moves into `<ConfirmDialog onConfirm={() => xMutation.mutate(...)}>`.

**Tech Stack:** Next.js 16 (App Router), React, TanStack Query, shadcn/ui (`Dialog`, `Button`, `Input`), Vitest + Testing Library + MSW.

**Working directory:** create a new worktree per `superpowers:using-git-worktrees` (branch e.g. `feature/admin-panel-rough-edges`) before starting Task 1 — do not implement on `main`.

**Running admin tests:** `cd admin && npm test` (full suite). Single file: `cd admin && npx vitest run <path>`.

---

### Task 1: Build the reusable `ConfirmDialog` component

**Files:**
- Create: `admin/components/confirm-dialog.tsx`
- Test: `admin/components/confirm-dialog.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `admin/components/confirm-dialog.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConfirmDialog } from './confirm-dialog';

describe('ConfirmDialog', () => {
  it('renders nothing visible when open=false', () => {
    render(
      <ConfirmDialog
        open={false}
        onOpenChange={vi.fn()}
        title="Заблокировать пользователя?"
        description="Пользователь потеряет доступ немедленно."
        confirmLabel="Заблокировать"
        onConfirm={vi.fn()}
      />,
    );
    expect(screen.queryByText('Заблокировать пользователя?')).not.toBeInTheDocument();
  });

  it('shows title/description and calls onConfirm (not before) when confirm is clicked', async () => {
    const onConfirm = vi.fn();
    const onOpenChange = vi.fn();
    render(
      <ConfirmDialog
        open={true}
        onOpenChange={onOpenChange}
        title="Заблокировать пользователя?"
        description="Пользователь потеряет доступ немедленно."
        confirmLabel="Заблокировать"
        onConfirm={onConfirm}
      />,
    );

    expect(screen.getByText('Заблокировать пользователя?')).toBeInTheDocument();
    expect(screen.getByText('Пользователь потеряет доступ немедленно.')).toBeInTheDocument();
    expect(onConfirm).not.toHaveBeenCalled();

    await userEvent.click(screen.getByRole('button', { name: 'Заблокировать' }));
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  it('calls onOpenChange(false) and not onConfirm when "Отмена" is clicked', async () => {
    const onConfirm = vi.fn();
    const onOpenChange = vi.fn();
    render(
      <ConfirmDialog
        open={true}
        onOpenChange={onOpenChange}
        title="Отменить подписку?"
        description="Магазин потеряет доступ к платным функциям."
        confirmLabel="Отменить подписку"
        onConfirm={onConfirm}
      />,
    );

    await userEvent.click(screen.getByRole('button', { name: 'Отмена' }));
    expect(onConfirm).not.toHaveBeenCalled();
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });

  it('renders the confirm button in the destructive style when variant="destructive"', () => {
    render(
      <ConfirmDialog
        open={true}
        onOpenChange={vi.fn()}
        title="Удалить пользователя?"
        description="Это действие нельзя отменить."
        confirmLabel="Удалить"
        onConfirm={vi.fn()}
        variant="destructive"
      />,
    );
    expect(screen.getByRole('button', { name: 'Удалить' })).toHaveAttribute(
      'data-variant',
      'destructive',
    );
  });
});
```

Read `admin/components/ui/button.tsx` first to confirm shadcn's `Button` actually exposes `data-variant` (it does in this codebase's shadcn version — every `Button` usage sets `data-slot="button"` and the variant classnames are driven off a `cva` call keyed by a `variant` prop; if `data-variant` isn't literally present as a DOM attribute, adjust the last test to instead assert on the presence of the destructive variant's class, e.g. `toHaveClass(/destructive/)`, matching however this codebase's `Button` actually surfaces its variant — check one existing destructive `Button` usage such as `admin/app/(admin)/users/[id]/page.tsx`'s `variant={user.isActive ? 'destructive' : 'outline'}` button for the exact rendered markup).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run components/confirm-dialog.test.tsx`
Expected: FAIL (module `./confirm-dialog` doesn't exist yet).

- [ ] **Step 3: Create the component**

Create `admin/components/confirm-dialog.tsx`:

```tsx
'use client';

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  onConfirm,
  variant = 'default',
  pending = false,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: string;
  confirmLabel: string;
  onConfirm: () => void;
  variant?: 'default' | 'destructive';
  pending?: boolean;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Отмена
          </Button>
          <Button
            variant={variant === 'destructive' ? 'destructive' : 'default'}
            onClick={onConfirm}
            disabled={pending}
          >
            {confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

Note this component does NOT close itself on confirm — callers are responsible for calling `onOpenChange(false)` from their mutation's `onSuccess` (exactly like every existing dialog in this codebase already does, e.g. `subscriptions/page.tsx`'s `cancelMutation.onSuccess`). This keeps the dialog open with the button disabled while the mutation is in flight if the caller passes `pending`, rather than optimistically closing before success is confirmed.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run components/confirm-dialog.test.tsx`
Expected: PASS (4 tests). If the destructive-variant test fails because `data-variant` isn't the real attribute name, fix the test (not the component) to match whatever `admin/components/ui/button.tsx` actually renders — the component itself just needs to pass `variant="destructive"` through to `Button`, which is standard shadcn usage already proven correct elsewhere in this codebase.

- [ ] **Step 5: Commit**

```bash
git add admin/components/confirm-dialog.tsx admin/components/confirm-dialog.test.tsx
git commit -m "feat(admin): add reusable ConfirmDialog component"
```

---

### Task 2: Build the reusable `UserPicker` component

**Files:**
- Create: `admin/components/user-picker.tsx`
- Test: `admin/components/user-picker.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `admin/components/user-picker.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../test/msw/server';
import { UserPicker } from './user-picker';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

function mockUsers() {
  server.use(
    http.get(`${API_URL}/admin/users`, () =>
      HttpResponse.json({
        data: [
          { id: 'u1', name: 'Alice Owner', phone: '+992900000001', isAdmin: false, isActive: true },
          { id: 'u2', name: 'Bob Owner', phone: '+992900000002', isAdmin: false, isActive: true },
          { id: 'u3', name: 'Carol Admin', phone: '+992900000003', isAdmin: true, isActive: true },
        ],
      }),
    ),
  );
}

describe('UserPicker', () => {
  it('filters the user list by typed name and calls onSelect with the matched id', async () => {
    mockUsers();
    const onSelect = vi.fn();
    renderWithQuery(<UserPicker value="" onSelect={onSelect} />);

    await userEvent.type(screen.getByPlaceholderText(/Поиск по имени или телефону/i), 'Alice');

    await waitFor(() => expect(screen.getByText('Alice Owner')).toBeInTheDocument());
    expect(screen.queryByText('Bob Owner')).not.toBeInTheDocument();

    await userEvent.click(screen.getByText('Alice Owner'));
    expect(onSelect).toHaveBeenCalledWith('u1', 'Alice Owner');
  });

  it('filters by phone number too', async () => {
    mockUsers();
    renderWithQuery(<UserPicker value="" onSelect={vi.fn()} />);

    await userEvent.type(screen.getByPlaceholderText(/Поиск по имени или телефону/i), '900000002');

    await waitFor(() => expect(screen.getByText('Bob Owner')).toBeInTheDocument());
    expect(screen.queryByText('Alice Owner')).not.toBeInTheDocument();
  });

  it('shows no dropdown when the search box is empty', async () => {
    mockUsers();
    renderWithQuery(<UserPicker value="" onSelect={vi.fn()} />);
    expect(screen.queryByText('Alice Owner')).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run components/user-picker.test.tsx`
Expected: FAIL (module doesn't exist).

- [ ] **Step 3: Create the component**

Create `admin/components/user-picker.tsx`:

```tsx
'use client';

import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { Input } from '@/components/ui/input';

interface PickerUser {
  id: string;
  name: string;
  phone: string;
}

export function UserPicker({
  value,
  onSelect,
  placeholder = 'Поиск по имени или телефону...',
}: {
  value: string;
  onSelect: (id: string, label: string) => void;
  placeholder?: string;
}) {
  const [search, setSearch] = useState(value);

  // Same client-side-filter-over-the-full-list approach the Users list page
  // (admin/app/(admin)/users/page.tsx) already uses for its own search box —
  // not a new server-side query, and no new dependency for a dropdown widget.
  const { data: users = [] } = useQuery<PickerUser[]>({
    queryKey: ['users'],
    queryFn: () => api.get('/admin/users').then((r) => r.data ?? []),
  });

  const matches = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return users
      .filter((u) => u.name?.toLowerCase().includes(q) || u.phone.includes(q))
      .slice(0, 8);
  }, [search, users]);

  return (
    <div className="relative">
      <Input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder={placeholder}
      />
      {matches.length > 0 && (
        <div className="absolute z-10 mt-1 w-full rounded-md border bg-popover shadow-md">
          {matches.map((u) => (
            <button
              key={u.id}
              type="button"
              className="block w-full px-3 py-2 text-left text-sm hover:bg-muted"
              onClick={() => {
                onSelect(u.id, u.name);
                setSearch(u.name);
              }}
            >
              {u.name}{' '}
              <span className="text-muted-foreground">{u.phone}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run components/user-picker.test.tsx`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add admin/components/user-picker.tsx admin/components/user-picker.test.tsx
git commit -m "feat(admin): add reusable UserPicker component (search by name/phone)"
```

---

### Task 3: Confirm dialog on store suspend (list + detail pages)

**Files:**
- Modify: `admin/app/(admin)/stores/page.tsx`
- Modify: `admin/app/(admin)/stores/[id]/page.tsx`
- Modify: `admin/app/(admin)/stores/page.test.tsx` (remove the 2 `TODO` comments, update the 2 tests they precede)

- [ ] **Step 1: Update the failing tests**

In `admin/app/(admin)/stores/page.test.tsx`, find both tests carrying `// TODO: when confirmation dialog is added` (the "Приостановить" and "Восстановить" tests). Per the spec, only suspend (not restore/unsuspend) gets a confirmation — restore is a non-destructive undo. Update ONLY the suspend test:

Replace:
```tsx
  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
  it('clicking "Приостановить" PUTs /admin/stores/:id/suspend and toasts success', async () => {
    mockSingleStore(true);

    const calls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/stores/s1/suspend`, () => {
        calls.push('suspend');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const suspendItem = await screen.findByText('Приостановить');
    await user.click(suspendItem);

    await waitFor(() => expect(calls).toContain('suspend'));
    expect(toastSuccess).toHaveBeenCalledWith('Статус магазина обновлён');
  });
```

with:

```tsx
  it('clicking "Приостановить" opens a confirmation dialog before PUTting suspend', async () => {
    mockSingleStore(true);

    const calls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/stores/s1/suspend`, () => {
        calls.push('suspend');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const suspendItem = await screen.findByText('Приостановить');
    await user.click(suspendItem);

    // Dialog open, mutation not fired yet.
    expect(await screen.findByRole('button', { name: 'Приостановить' })).toBeInTheDocument();
    expect(calls).not.toContain('suspend');

    await user.click(screen.getByRole('button', { name: 'Приостановить' }));

    await waitFor(() => expect(calls).toContain('suspend'));
    expect(toastSuccess).toHaveBeenCalledWith('Статус магазина обновлён');
  });
```

(The dropdown item and the dialog's confirm button now share the label "Приостановить" — `screen.findByRole('button', {name: 'Приостановить'})` after the dropdown item was already clicked correctly resolves to the dialog's confirm button since the dropdown closes on selection, same pattern the codebase already relies on elsewhere for post-click state.)

Leave the "Восстановить" test (`admin/app/(admin)/stores/page.test.tsx`) untouched except deleting its now-stale `// TODO` comment line — unsuspend stays a direct one-click action per the spec.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run "app/(admin)/stores/page.test.tsx"`
Expected: FAIL — clicking "Приостановить" still fires the PUT immediately, no dialog appears.

- [ ] **Step 3: Wire `ConfirmDialog` into `stores/page.tsx`**

Add state near the top of the component (alongside the existing `transferDialog`/`newOwnerId` state):

```ts
  const [suspendConfirm, setSuspendConfirm] = useState<Store | null>(null);
```

Find the dropdown menu item (in the per-row actions column) — its loop variable is `s`, not `store`:

```tsx
              onClick={(e) => {
                e.stopPropagation();
                suspendMutation.mutate(s);
              }}
              className={!s.isActive ? 'text-green-600' : 'text-red-600'}
            >
              {!s.isActive ? 'Восстановить' : 'Приостановить'}
            </DropdownMenuItem>
```

Replace the `onClick` body with a branch: unsuspend fires directly, suspend opens the dialog (keep the `e.stopPropagation()` and the `className` line unchanged):

```tsx
              onClick={(e) => {
                e.stopPropagation();
                s.isActive ? setSuspendConfirm(s) : suspendMutation.mutate(s);
              }}
              className={!s.isActive ? 'text-green-600' : 'text-red-600'}
            >
              {!s.isActive ? 'Восстановить' : 'Приостановить'}
            </DropdownMenuItem>
```

Add the dialog JSX near the file's other dialogs (near the existing "Transfer dialog"):

```tsx
      <ConfirmDialog
        open={!!suspendConfirm}
        onOpenChange={(open) => !open && setSuspendConfirm(null)}
        title="Приостановить магазин?"
        description={`Магазин «${suspendConfirm?.name}» станет недоступен владельцу до восстановления.`}
        confirmLabel="Приостановить"
        variant="destructive"
        pending={suspendMutation.isPending}
        onConfirm={() => {
          if (suspendConfirm) suspendMutation.mutate(suspendConfirm);
        }}
      />
```

Add the import: `import { ConfirmDialog } from '@/components/confirm-dialog';`

In `suspendMutation`'s `onSuccess`, add `setSuspendConfirm(null);` alongside the existing `queryClient.invalidateQueries(...)` and `toast.success(...)` calls, so the dialog closes once the suspend actually succeeds.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run "app/(admin)/stores/page.test.tsx"`
Expected: PASS (all tests in the file, including the unchanged "Восстановить" one and the updated "Приостановить" one).

- [ ] **Step 5: Repeat for the store detail page**

`admin/app/(admin)/stores/[id]/page.tsx` has a single "Приостановить"/"Восстановить" `Button` (not a dropdown item) calling `suspendMutation.mutate()`. This page has no test file yet covering suspend specifically (only the transfer test added in the previous bugfix cycle) — add one. First read the file's current suspend button JSX in full, then apply the same pattern: a `suspendConfirm: boolean` state, the button's `onClick` branches on `store.isActive` the same way, and a `ConfirmDialog` reusing the same copy as Step 3. Add a test to `admin/app/(admin)/stores/[id]/page.test.tsx` (the file created in the previous bugfix cycle — extend it, following its existing `mockStore()`/`renderPage()` helpers) mirroring Step 1's assertions (dialog appears, mutation doesn't fire until confirmed).

- [ ] **Step 6: Run the full file's tests**

Run: `cd admin && npx vitest run "app/(admin)/stores/[id]/page.test.tsx"`
Expected: PASS.

- [ ] **Step 7: Type-check and commit**

Run: `cd admin && npx tsc --noEmit` — expect clean.

```bash
git add "admin/app/(admin)/stores/page.tsx" "admin/app/(admin)/stores/page.test.tsx" "admin/app/(admin)/stores/[id]/page.tsx" "admin/app/(admin)/stores/[id]/page.test.tsx"
git commit -m "feat(admin): confirm before suspending a store (list + detail pages)"
```

---

### Task 4: Confirm dialog on subscription cancel + payment approve

**Files:**
- Modify: `admin/app/(admin)/subscriptions/page.tsx`
- Modify: `admin/app/(admin)/subscriptions/page.test.tsx` (remove the 2 `TODO` comments, update the 2 tests)

- [ ] **Step 1: Update the failing tests**

In `admin/app/(admin)/subscriptions/page.test.tsx`, update the "Отменить" test (remove its `TODO` comment) the same way as Task 3 Step 1 — dialog appears first, mutation fires only after clicking the dialog's confirm button (reuse the label "Отменить подписку" for the dialog's confirm button so it's unambiguous from the dropdown item's plain "Отменить", since both would otherwise collide on `getByRole('button', {name: 'Отменить'})`):

```tsx
  it('clicking "Отменить" opens a confirmation dialog before PUTting cancel', async () => {
    mockSubscriptionsAndPending();

    const calls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/subscriptions/sub1/cancel`, () => {
        calls.push('cancel');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<SubscriptionsPage />);
    await waitFor(() => screen.getByText('Demo Store'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const cancelItem = await screen.findByText('Отменить');
    await user.click(cancelItem);

    expect(calls).not.toContain('cancel');
    await user.click(screen.getByRole('button', { name: 'Отменить подписку' }));

    await waitFor(() => expect(calls).toContain('cancel'));
    expect(toastSuccess).toHaveBeenCalledWith('Подписка отменена');
  });
```

Similarly update the "Подтвердить" (approve-payment) test, confirm button label "Подтвердить платёж":

```tsx
  it('clicking "Подтвердить" opens a confirmation dialog before approving the payment', async () => {
    mockSubscriptionsAndPending();

    const calls: string[] = [];
    server.use(
      http.put(
        `${API_URL}/admin/subscriptions/sub1/approve-payment/pay1`,
        () => {
          calls.push('approve');
          return HttpResponse.json({ ok: true });
        },
      ),
    );

    const user = userEvent.setup();
    renderWithQuery(<SubscriptionsPage />);

    const pendingTab = await screen.findByRole('tab', { name: /Ожидают оплаты/i });
    await user.click(pendingTab);

    const approveBtn = await screen.findByRole('button', { name: /Подтвердить/i });
    await user.click(approveBtn);

    expect(calls).not.toContain('approve');
    await user.click(screen.getByRole('button', { name: 'Подтвердить платёж' }));

    await waitFor(() => expect(calls).toContain('approve'));
    expect(toastSuccess).toHaveBeenCalledWith('Платёж подтверждён');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd admin && npx vitest run "app/(admin)/subscriptions/page.test.tsx"`
Expected: FAIL on both updated tests.

- [ ] **Step 3: Wire `ConfirmDialog` for cancel**

Add state: `const [cancelConfirm, setCancelConfirm] = useState<Subscription | null>(null);`

Find the "Отменить" `DropdownMenuItem` (currently `onClick={() => cancelMutation.mutate(s.id)}`) and change it to `onClick={() => setCancelConfirm(s)}`.

Add the dialog:

```tsx
      <ConfirmDialog
        open={!!cancelConfirm}
        onOpenChange={(open) => !open && setCancelConfirm(null)}
        title="Отменить подписку?"
        description={`Магазин «${cancelConfirm?.store?.name}» немедленно потеряет доступ к платным функциям тарифа.`}
        confirmLabel="Отменить подписку"
        variant="destructive"
        pending={cancelMutation.isPending}
        onConfirm={() => {
          if (cancelConfirm) cancelMutation.mutate(cancelConfirm.id);
        }}
      />
```

Add `setCancelConfirm(null);` to `cancelMutation`'s `onSuccess`.

- [ ] **Step 4: Wire `ConfirmDialog` for approve-payment**

Add state: `const [approveConfirm, setApproveConfirm] = useState<{ id: string; subscriptionId: string; storeName?: string } | null>(null);` (match whatever shape the pending-payment row object actually has — read the file's `pendingPayments` rendering block first for the exact fields available, e.g. `p.subscription?.store?.name` for the store name to show in the dialog description).

Find the "Подтвердить" button (currently `onClick={() => approveMutation.mutate(payment)}`) and change it to open the dialog with that payment's data instead.

Add the dialog:

```tsx
      <ConfirmDialog
        open={!!approveConfirm}
        onOpenChange={(open) => !open && setApproveConfirm(null)}
        title="Подтвердить платёж?"
        description="Подписка будет немедленно активирована на срок оплаченного периода."
        confirmLabel="Подтвердить платёж"
        pending={approveMutation.isPending}
        onConfirm={() => {
          if (approveConfirm) approveMutation.mutate(approveConfirm);
        }}
      />
```

Add dialog-close to `approveMutation`'s `onSuccess`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd admin && npx vitest run "app/(admin)/subscriptions/page.test.tsx"`
Expected: PASS (full file).

- [ ] **Step 6: Type-check and commit**

```bash
cd admin && npx tsc --noEmit
git add "admin/app/(admin)/subscriptions/page.tsx" "admin/app/(admin)/subscriptions/page.test.tsx"
git commit -m "feat(admin): confirm before cancelling a subscription or approving a payment"
```

---

### Task 5: Confirm dialog on user block + toggle-admin (list + detail pages)

**Files:**
- Modify: `admin/app/(admin)/users/page.tsx`
- Modify: `admin/app/(admin)/users/[id]/page.tsx`
- Modify: `admin/app/(admin)/users/page.test.tsx` (remove the 3 `TODO` comments, update the 3 tests)

- [ ] **Step 1: Update the failing tests**

Same pattern as Tasks 3-4. In `admin/app/(admin)/users/page.test.tsx`:
- "Заблокировать" test: dialog first, confirm label "Заблокировать пользователя", assert PUT doesn't fire until confirmed.
- "Снять права admin" test: dialog first, confirm label "Снять права admin" — this collides with the dropdown item's own label again; disambiguate the SAME way as Task 4 by giving the dialog's confirm button a slightly more specific label, e.g. `confirmLabel="Подтвердить"` for this one specifically (toggling admin off is reversible by clicking the same toggle again, so a generic confirm label is fine — it doesn't need the "which one did I click" disambiguation the destructive dialogs need, since there's only one admin-toggle action per row).
- Leave "Разблокировать" (unblock) untouched except deleting its stale TODO comment — non-destructive undo, per spec.

Write these three updated tests following the exact structure already shown in Task 3/4 Step 1 (open dropdown trigger via `[data-slot="dropdown-menu-trigger"]`, click the item, assert no call yet, click the dialog's confirm button, assert the call happened). Read `admin/app/(admin)/users/page.test.tsx` in full first for its exact existing helper names (`mockSingleUser` or similar) before writing these.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd admin && npx vitest run "app/(admin)/users/page.test.tsx"`

- [ ] **Step 3: Wire `ConfirmDialog` into `users/page.tsx`**

Add state:
```ts
  const [blockConfirm, setBlockConfirm] = useState<User | null>(null);
  const [adminToggleConfirm, setAdminToggleConfirm] = useState<User | null>(null);
```

Change the "Сделать admin"/"Снять права admin" `DropdownMenuItem`'s `onClick` from `toggleAdminMutation.mutate(u.id)` to `setAdminToggleConfirm(u)`.

Change the block/unblock `DropdownMenuItem`'s `onClick` (currently `toggleBlockMutation.mutate(u)`) to branch: `u.isActive ? setBlockConfirm(u) : toggleBlockMutation.mutate(u)` (unblock stays direct).

Add both dialogs:

```tsx
      <ConfirmDialog
        open={!!adminToggleConfirm}
        onOpenChange={(open) => !open && setAdminToggleConfirm(null)}
        title={
          adminToggleConfirm?.isAdmin
            ? 'Снять права администратора?'
            : 'Назначить администратором?'
        }
        description={`Пользователь «${adminToggleConfirm?.name}» ${adminToggleConfirm?.isAdmin ? 'потеряет' : 'получит'} доступ к админ-панели.`}
        confirmLabel="Подтвердить"
        pending={toggleAdminMutation.isPending}
        onConfirm={() => {
          if (adminToggleConfirm) toggleAdminMutation.mutate(adminToggleConfirm.id);
        }}
      />
      <ConfirmDialog
        open={!!blockConfirm}
        onOpenChange={(open) => !open && setBlockConfirm(null)}
        title="Заблокировать пользователя?"
        description={`Пользователь «${blockConfirm?.name}» немедленно потеряет доступ и все его текущие сессии будут завершены.`}
        confirmLabel="Заблокировать"
        variant="destructive"
        pending={toggleBlockMutation.isPending}
        onConfirm={() => {
          if (blockConfirm) toggleBlockMutation.mutate(blockConfirm);
        }}
      />
```

Add dialog-close to both mutations' `onSuccess`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd admin && npx vitest run "app/(admin)/users/page.test.tsx"`

- [ ] **Step 5: Repeat for the user detail page**

`admin/app/(admin)/users/[id]/page.tsx` has the same two actions as direct `Button`s (see the exact JSX already read for this plan — `toggleAdminMutation.mutate()` and `toggleBlockMutation.mutate()`, both zero-argument since `id` is already in the closure). Apply the identical pattern: two boolean confirm states, branch the block button's `onClick` on `user.isActive` (unblock stays direct), always confirm the admin-toggle. Add tests to `admin/app/(admin)/users/[id]/page.test.tsx` (extend the existing file — it already exists from the impersonation-flow work) mirroring Step 1's assertions, using that file's existing `renderPage()`/`mockUser()` helpers (note this file's `renderWithQuery` is async and needs the `Suspense`+`act()` wrapper — reuse it exactly as already established, don't redefine).

- [ ] **Step 6: Run tests, type-check, commit**

```bash
cd admin && npx vitest run "app/(admin)/users/[id]/page.test.tsx"
cd admin && npx tsc --noEmit
git add "admin/app/(admin)/users/page.tsx" "admin/app/(admin)/users/page.test.tsx" "admin/app/(admin)/users/[id]/page.tsx" "admin/app/(admin)/users/[id]/page.test.tsx"
git commit -m "feat(admin): confirm before blocking a user or toggling admin rights"
```

---

### Task 6: Replace the raw-UUID transfer input with `UserPicker`

**Files:**
- Modify: `admin/app/(admin)/stores/page.tsx`
- Modify: `admin/app/(admin)/stores/[id]/page.tsx`
- Modify: `admin/app/(admin)/stores/page.test.tsx` (update the transfer test added in the previous bugfix cycle)
- Modify: `admin/app/(admin)/stores/[id]/page.test.tsx` (same)

- [ ] **Step 1: Update the failing tests**

In both test files, the transfer test currently does:
```tsx
    await user.type(screen.getByPlaceholderText('Введите ID пользователя'), 'owner-2');
```
Change this interaction to go through `UserPicker` instead — mock `/admin/users` with a matching user, type a partial name, click the dropdown match:

```tsx
    server.use(
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({ data: [{ id: 'owner-2', name: 'New Owner', phone: '+992900000099' }] }),
      ),
    );
    // ... open the transfer dialog as before ...
    await user.type(screen.getByPlaceholderText(/Поиск по имени или телефону/i), 'New Owner');
    await user.click(await screen.findByText('New Owner'));
```

The rest of each test (asserting `captured.body` equals `{ newOwnerId: 'owner-2' }`, clicking the "Передать" submit button) stays the same.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd admin && npx vitest run "app/(admin)/stores/page.test.tsx" "app/(admin)/stores/[id]/page.test.tsx"`
Expected: FAIL — the placeholder text `Введите ID пользователя` still exists (old input not yet replaced).

- [ ] **Step 3: Replace the input in `stores/page.tsx`**

Find:
```tsx
            <div className="space-y-2">
              <Label>ID нового владельца</Label>
              <Input
                value={newOwnerId}
                onChange={(e) => setNewOwnerId(e.target.value)}
                placeholder="Введите ID пользователя"
              />
            </div>
```

Replace with:
```tsx
            <div className="space-y-2">
              <Label>Новый владелец</Label>
              <UserPicker value={newOwnerId} onSelect={(id) => setNewOwnerId(id)} />
            </div>
```

Add the import: `import { UserPicker } from '@/components/user-picker';`. The `Input`/`Label` imports may now be unused in this file if nothing else uses them — check before removing (this file has other `Input`/`Label` usages for search/filters, so they almost certainly stay imported; only remove if `tsc`/lint flags them as unused).

- [ ] **Step 4: Repeat for `stores/[id]/page.tsx`**

Same replacement — find its "ID нового владельца" `Label`/`Input` pair (already located earlier in this plan's Task 3-era investigation) and swap in `UserPicker` identically.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd admin && npx vitest run "app/(admin)/stores/page.test.tsx" "app/(admin)/stores/[id]/page.test.tsx"`

- [ ] **Step 6: Type-check and commit**

```bash
cd admin && npx tsc --noEmit
git add "admin/app/(admin)/stores/page.tsx" "admin/app/(admin)/stores/page.test.tsx" "admin/app/(admin)/stores/[id]/page.tsx" "admin/app/(admin)/stores/[id]/page.test.tsx"
git commit -m "feat(admin): replace raw-UUID store-transfer input with UserPicker"
```

---

### Task 7: Add delete-user action to the user detail page

**Files:**
- Modify: `admin/app/(admin)/users/[id]/page.tsx`
- Modify: `admin/app/(admin)/users/[id]/page.test.tsx`

- [ ] **Step 1: Write the failing test**

Add to `admin/app/(admin)/users/[id]/page.test.tsx` (using its existing `renderPage()`/`mockUser()` helpers and mocked `useRouter`):

```tsx
describe('UserDetailPage — delete user', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('clicking "Удалить пользователя" opens a confirmation, then DELETEs and navigates to /users', async () => {
    mockUser();

    const calls: string[] = [];
    server.use(
      http.delete(`${API_URL}/admin/users/u1`, () => {
        calls.push('delete');
        return HttpResponse.json({ ok: true });
      }),
    );

    const push = vi.fn();
    vi.mocked(await import('next/navigation')).useRouter = () => ({
      push,
      replace: vi.fn(),
      refresh: vi.fn(),
    });

    const user = userEvent.setup();
    await renderPage();

    await user.click(screen.getByRole('button', { name: 'Удалить пользователя' }));
    expect(calls).not.toContain('delete');

    await user.click(screen.getByRole('button', { name: 'Удалить' }));

    await waitFor(() => expect(calls).toContain('delete'));
    expect(toastSuccess).toHaveBeenCalledWith('Пользователь удалён');
    expect(push).toHaveBeenCalledWith('/users');
  });
});
```

Check how this file's existing `vi.mock('next/navigation', ...)` at the top is structured before writing the `push` assertion — if `useRouter` is already a fixed `vi.fn()`-returning mock shared across all tests in the file (likely, matching the established pattern), reuse that reference directly (e.g. a module-level `const routerPush = vi.fn();` used inside the existing `vi.mock` factory) rather than re-mocking `next/navigation` inside this one test, which would conflict with the file-level mock. Adjust the test to fit whatever the file already does — the assertion that matters is "a delete confirmation gates the DELETE call, and success navigates away," not the exact mocking mechanics.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd admin && npx vitest run "app/(admin)/users/[id]/page.test.tsx"`
Expected: FAIL — no "Удалить пользователя" button exists yet.

- [ ] **Step 3: Add the delete action**

In `admin/app/(admin)/users/[id]/page.tsx`, add near the other mutations:

```ts
  const [deleteConfirm, setDeleteConfirm] = useState(false);

  const deleteMutation = useMutation({
    mutationFn: () => api.delete(`/admin/users/${id}`),
    onSuccess: () => {
      setDeleteConfirm(false);
      toast.success('Пользователь удалён');
      router.push('/users');
    },
    onError: () => toast.error('Ошибка удаления пользователя'),
  });
```

(`router` is already in scope — this page already calls `useRouter()` for its "Назад" link.)

Add a fifth button alongside the existing "Сделать admin"/"Заблокировать"/"Отправить сообщение"/"Войти как пользователь" row:

```tsx
            <Button
              variant="destructive"
              onClick={() => setDeleteConfirm(true)}
            >
              <Trash2 className="mr-2 h-4 w-4" />
              Удалить пользователя
            </Button>
```

Add the `Trash2` import to the existing `lucide-react` import line at the top of the file.

Add the dialog near the file's other dialogs:

```tsx
      <ConfirmDialog
        open={deleteConfirm}
        onOpenChange={setDeleteConfirm}
        title="Удалить пользователя?"
        description={`Аккаунт «${user.name}» будет анонимизирован (телефон и email обезличены). Это действие нельзя отменить.`}
        confirmLabel="Удалить"
        variant="destructive"
        pending={deleteMutation.isPending}
        onConfirm={() => deleteMutation.mutate()}
      />
```

Add the import: `import { ConfirmDialog } from '@/components/confirm-dialog';` (if Task 3/5 didn't already add it to this file — check first, don't duplicate the import).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd admin && npx vitest run "app/(admin)/users/[id]/page.test.tsx"`

- [ ] **Step 5: Type-check and commit**

```bash
cd admin && npx tsc --noEmit
git add "admin/app/(admin)/users/[id]/page.tsx" "admin/app/(admin)/users/[id]/page.test.tsx"
git commit -m "feat(admin): add delete-user action to the user detail page"
```

---

### Task 8: Full suite + type-check + lint

**Files:** none (verification only)

- [ ] **Step 1: Full suite**

Run: `cd admin && npm test`
Expected: all tests pass, including every test added/updated in Tasks 1-7.

- [ ] **Step 2: Type-check**

Run: `cd admin && npx tsc --noEmit`
Expected: clean.

- [ ] **Step 3: Lint**

Run: `cd admin && npm run lint`
Expected: no NEW warnings/errors beyond the two pre-existing `react-hooks/set-state-in-effect` findings already confirmed pre-existing (in `admin/components/sidebar.tsx` and `admin/app/(admin)/subscriptions/plans/page.tsx`) during the previous bugfix cycle's Task 7 — do not attempt to fix those here, out of scope.

No commit for this task — checkpoint before the final whole-branch review, live Playwright re-verification against the real backend (per the spec's "Live re-verification" section), and `superpowers:finishing-a-development-branch`.
