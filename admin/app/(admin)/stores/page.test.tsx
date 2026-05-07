import { describe, it, expect, vi, beforeEach } from 'vitest';
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
vi.mock('sonner', () => ({
  toast: {
    success: (msg: string) => toastSuccess(msg),
    error: (msg: string) => toastError(msg),
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
