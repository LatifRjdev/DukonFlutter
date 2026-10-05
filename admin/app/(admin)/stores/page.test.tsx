import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

const toastSuccess = vi.fn();
const toastError = vi.fn();
const toastWarning = vi.fn();
vi.mock('sonner', () => ({
  toast: {
    success: (msg: string) => toastSuccess(msg),
    error: (msg: string) => toastError(msg),
    warning: (msg: string) => toastWarning(msg),
  },
}));

import StoresPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

function mockSingleStore(active: boolean) {
  server.use(
    http.get(`${API_URL}/admin/stores`, () =>
      HttpResponse.json({
        data: [
          {
            id: 's1',
            name: active ? 'Active Mart' : 'Suspended Mart',
            category: 'food',
            ownerId: 'u1',
            owner: { id: 'u1', name: 'Owner', phone: '+992900000001' },
            isActive: active,
            subscription: { plan: 'BUSINESS', status: 'ACTIVE' },
            _count: { products: 3, staff: 1 },
            monthlySalesCount: 5,
            createdAt: '2026-01-01T00:00:00Z',
          },
        ],
        total: 1,
        page: 1,
        pageSize: 50,
      }),
    ),
  );
}

describe('StoresPage — destructive action: suspend / activate', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

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

  it('clicking "Восстановить" on a suspended store PUTs /admin/stores/:id/unsuspend', async () => {
    mockSingleStore(false);

    const calls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/stores/s1/unsuspend`, () => {
        calls.push('unsuspend');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Suspended Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const restoreItem = await screen.findByText('Восстановить');
    await user.click(restoreItem);

    await waitFor(() => expect(calls).toContain('unsuspend'));
    expect(toastSuccess).toHaveBeenCalledWith('Статус магазина обновлён');
  });
});

describe('StoresPage — Экспорт button vs. subscription-status filter', () => {
  const originalLocation = window.location;

  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
    toastWarning.mockReset();
    mockSingleStore(true);
    // jsdom throws "Not implemented: navigation" on a real assignment to
    // window.location.href — stub it out so we can just assert on the
    // value the component tried to navigate to. `origin` is preserved
    // because lib/api.ts's apiFetch reads window.location.origin to build
    // the proxy URL the initial store list is fetched from.
    // @ts-expect-error - intentionally replacing the read-only jsdom Location
    delete window.location;
    // @ts-expect-error - minimal stand-in, only `origin`/`href` are used
    window.location = { origin: originalLocation.origin, href: '' };
  });

  afterEach(() => {
    // @ts-expect-error - restoring the real jsdom Location object
    window.location = originalLocation;
  });

  it('warns and exports ALL stores (no isActive param) when statusFilter is an unsupported subscription status', async () => {
    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const statusTrigger = screen.getAllByRole('combobox')[2];
    await user.click(statusTrigger);
    const trialOption = await screen.findByRole('option', { name: 'Пробная' });
    await user.click(trialOption);

    const exportButton = screen.getByRole('button', { name: /Экспорт/ });
    await user.click(exportButton);

    expect(toastWarning).toHaveBeenCalledWith(
      'Экспорт по статусу подписки пока не поддерживается — будут выгружены все магазины',
    );
    expect(window.location.href).toContain('/api/proxy/admin/stores/export?');
    expect(window.location.href).not.toContain('isActive');
  });

  it('does not warn and maps SUSPENDED to isActive=false in the export link', async () => {
    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const statusTrigger = screen.getAllByRole('combobox')[2];
    await user.click(statusTrigger);
    const suspendedOption = await screen.findByRole('option', { name: 'Приостановлен' });
    await user.click(suspendedOption);

    const exportButton = screen.getByRole('button', { name: /Экспорт/ });
    await user.click(exportButton);

    expect(toastWarning).not.toHaveBeenCalled();
    expect(window.location.href).toContain('isActive=false');
  });

  it('does not warn when statusFilter is left at "all"', async () => {
    const user = userEvent.setup();
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const exportButton = screen.getByRole('button', { name: /Экспорт/ });
    await user.click(exportButton);

    expect(toastWarning).not.toHaveBeenCalled();
    expect(window.location.href).toContain('/api/proxy/admin/stores/export?');
  });
});

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
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({
          data: [{ id: 'owner-2', name: 'New Owner', phone: '+992900000099' }],
        }),
      ),
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

    await user.type(screen.getByPlaceholderText(/Поиск по имени или телефону/i), 'New Owner');
    await user.click(await screen.findByText('New Owner'));
    // Exact-string match (default for getByRole's `name`) so this doesn't
    // also match the "Передать владение" dropdown item from above.
    await user.click(screen.getByRole('button', { name: 'Передать' }));

    await waitFor(() => expect(captured.body).toEqual({ newOwnerId: 'owner-2' }));
    expect(toastSuccess).toHaveBeenCalledWith('Владелец магазина изменён');
  });
});

describe('StoresPage requests enough rows for client-side filtering to be accurate', () => {
  it('fetches /admin/stores with a limit large enough to not silently drop rows past page 1', async () => {
    const captured: { url?: string } = {};
    server.use(
      http.get(`${API_URL}/admin/stores`, ({ request }) => {
        captured.url = request.url;
        return HttpResponse.json({ data: [], total: 0 });
      }),
    );

    renderWithQuery(<StoresPage />);
    await waitFor(() => expect(captured.url).toBeDefined());

    const limit = Number(new URL(captured.url!).searchParams.get('limit'));
    expect(limit).toBeGreaterThanOrEqual(1000);
  });
});

describe('StoresPage — create store for an existing user', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('POSTs { ownerId, name, category } to /admin/stores and invalidates the list', async () => {
    const user = userEvent.setup();
    const captured: { body?: Record<string, unknown> } = {};
    let listFetches = 0;
    server.use(
      http.get(`${API_URL}/admin/stores`, () => {
        listFetches += 1;
        return HttpResponse.json({ data: [], total: 0 });
      }),
      http.post(`${API_URL}/admin/stores`, async ({ request }) => {
        captured.body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: 's2', name: 'Новый магазин' });
      }),
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({
          data: [{ id: 'u1', name: 'Али', phone: '+992901234567' }],
          total: 1,
        }),
      ),
    );

    renderWithQuery(<StoresPage />);
    await waitFor(() => expect(listFetches).toBe(1));

    await user.click(await screen.findByRole('button', { name: 'Создать магазин' }));

    await user.type(screen.getByLabelText('Название'), 'Новый магазин');
    // UserPicker renders a search Input with no id, so it cannot be reached by
    // label — the transfer test addresses it by placeholder for the same reason.
    await user.type(
      screen.getByPlaceholderText(/Поиск по имени или телефону/i),
      '+992901234567',
    );
    await user.click(await screen.findByText(/Али/));

    await user.click(screen.getByRole('button', { name: 'Создать' }));

    await waitFor(() => expect(captured.body).toBeDefined());
    expect(captured.body).toMatchObject({
      ownerId: 'u1',
      name: 'Новый магазин',
      category: 'GROCERY',
    });
    expect(toastSuccess).toHaveBeenCalledWith('Магазин создан');
    // The list must be refetched — invalidating any other key fails silently.
    await waitFor(() => expect(listFetches).toBe(2));
  });

  it('shows a server validation error inline instead of only as a toast', async () => {
    // An unknown ownerId and a malformed field are both recoverable mistakes
    // the admin should see next to the field, not just in a toast that fades.
    const user = userEvent.setup();
    server.use(
      http.post(`${API_URL}/admin/stores`, () =>
        HttpResponse.json(
          { statusCode: 404, message: ['Owner user not found'] },
          { status: 404 },
        ),
      ),
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({
          data: [{ id: 'u1', name: 'Али', phone: '+992901234567' }],
          total: 1,
        }),
      ),
    );

    mockSingleStore(true);
    renderWithQuery(<StoresPage />);
    await user.click(await screen.findByRole('button', { name: 'Создать магазин' }));
    await user.type(screen.getByLabelText('Название'), 'Новый магазин');
    await user.type(
      screen.getByPlaceholderText(/Поиск по имени или телефону/i),
      '+992901234567',
    );
    await user.click(await screen.findByText(/Али/));
    await user.click(screen.getByRole('button', { name: 'Создать' }));

    expect(await screen.findByText('Owner user not found')).toBeInTheDocument();
    // Still open, so the admin can fix the field without re-entering everything.
    expect(screen.getByRole('button', { name: 'Создать' })).toBeInTheDocument();
  });
});

describe('StoresPage — change tariff', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('preloads the current subscription and PUTs plan, status and period together', async () => {
    const user = userEvent.setup();
    const captured: { body?: Record<string, unknown> } = {};
    let listFetches = 0;
    server.use(
      http.get(`${API_URL}/admin/stores`, () => {
        listFetches += 1;
        return HttpResponse.json({
          data: [
            {
              id: 's1',
              name: 'Active Mart',
              category: 'food',
              ownerId: 'u1',
              owner: { id: 'u1', name: 'Owner', phone: '+992900000001' },
              isActive: true,
              subscription: { plan: 'BUSINESS', status: 'ACTIVE' },
              _count: { products: 3, staff: 1 },
              monthlySalesCount: 5,
              createdAt: '2026-01-01T00:00:00Z',
            },
          ],
          total: 1,
        });
      }),
      http.get(`${API_URL}/admin/stores/s1/subscription`, () =>
        HttpResponse.json({
          plan: 'PREMIUM',
          status: 'TRIAL',
          currentPeriodEnd: '2026-01-08T00:00:00.000Z',
        }),
      ),
      http.put(`${API_URL}/admin/stores/s1/subscription`, async ({ request }) => {
        captured.body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ plan: 'BUSINESS', status: 'ACTIVE' });
      }),
    );

    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);
    // Not findByText('Тариф'): the plan column header and the plan filter
    // trigger both render that same string outside the menu.
    await user.click(await screen.findByRole('menuitem', { name: 'Тариф' }));

    // The dialog must show what the plan is changing FROM — the fetched
    // PREMIUM, not the BUSINESS the list row carries. Scoped to the <strong>
    // because the plan <select> also contains a PREMIUM option.
    expect(await screen.findByText('PREMIUM', { selector: 'strong' })).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Тариф'), 'BUSINESS');
    await user.selectOptions(screen.getByLabelText('Статус'), 'ACTIVE');
    await user.clear(screen.getByLabelText('Действует до'));
    await user.type(screen.getByLabelText('Действует до'), '2027-01-01');
    await user.click(screen.getByRole('button', { name: 'Сохранить' }));

    await waitFor(() => expect(captured.body).toBeDefined());
    expect(captured.body).toMatchObject({ plan: 'BUSINESS', status: 'ACTIVE' });
    expect(String(captured.body?.currentPeriodEnd)).toContain('2027-01-01');
    expect(toastSuccess).toHaveBeenCalledWith('Тариф обновлён');
    await waitFor(() => expect(listFetches).toBe(2));
  });

  it('shows a server error inline and keeps the dialog open', async () => {
    const user = userEvent.setup();
    server.use(
      http.get(`${API_URL}/admin/stores/s1/subscription`, () =>
        HttpResponse.json({
          plan: 'START',
          status: 'ACTIVE',
          currentPeriodEnd: '2026-02-01T00:00:00.000Z',
        }),
      ),
      http.put(`${API_URL}/admin/stores/s1/subscription`, () =>
        HttpResponse.json({ statusCode: 404, message: 'Store not found' }, { status: 404 }),
      ),
    );

    mockSingleStore(true);
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);
    await user.click(await screen.findByRole('menuitem', { name: 'Тариф' }));

    await user.click(await screen.findByRole('button', { name: 'Сохранить' }));

    expect(await screen.findByText('Store not found')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Сохранить' })).toBeInTheDocument();
  });

  it('falls back to editable defaults when the store has no subscription yet', async () => {
    // getStoreSubscription 404s when no Subscription row exists; the PUT
    // upserts, so the dialog must stay usable instead of locking the admin out.
    const user = userEvent.setup();
    const captured: { body?: Record<string, unknown> } = {};
    server.use(
      // A store with no Subscription row at all — the list row carries none
      // either, so there is nothing to fall back to but the defaults.
      http.get(`${API_URL}/admin/stores`, () =>
        HttpResponse.json({
          data: [
            {
              id: 's1',
              name: 'Active Mart',
              ownerId: 'u1',
              owner: { id: 'u1', name: 'Owner', phone: '+992900000001' },
              isActive: true,
              subscription: null,
              _count: { products: 0, staff: 1 },
              createdAt: '2026-01-01T00:00:00Z',
            },
          ],
          total: 1,
        }),
      ),
      http.get(`${API_URL}/admin/stores/s1/subscription`, () =>
        HttpResponse.json(
          { statusCode: 404, message: 'Subscription not found for store' },
          { status: 404 },
        ),
      ),
      http.put(`${API_URL}/admin/stores/s1/subscription`, async ({ request }) => {
        captured.body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ plan: 'START', status: 'ACTIVE' });
      }),
    );

    // No mockSingleStore here: its row carries a BUSINESS subscription, which
    // the handler above deliberately replaces (MSW uses the last handler added).
    renderWithQuery(<StoresPage />);
    await waitFor(() => screen.getByText('Active Mart'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);
    await user.click(await screen.findByRole('menuitem', { name: 'Тариф' }));

    await user.type(screen.getByLabelText('Действует до'), '2027-03-01');
    await user.click(screen.getByRole('button', { name: 'Сохранить' }));

    await waitFor(() => expect(captured.body).toBeDefined());
    expect(captured.body).toMatchObject({ plan: 'START', status: 'ACTIVE' });
    expect(String(captured.body?.currentPeriodEnd)).toContain('2027-03-01');
  });
});
