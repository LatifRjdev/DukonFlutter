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

  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
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
    const trialOption = await screen.findByRole('option', { name: 'Trial' });
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
