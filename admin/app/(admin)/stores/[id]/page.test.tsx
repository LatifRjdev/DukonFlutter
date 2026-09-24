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

describe('StoreDetailPage — destructive action: suspend', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('clicking "Приостановить" opens a confirmation dialog before PUTting suspend', async () => {
    mockStore();

    const calls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/stores/s1/suspend`, () => {
        calls.push('suspend');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    await renderPage();
    await waitFor(() => screen.getByText('Test Store'));

    await user.click(screen.getByRole('button', { name: 'Приостановить' }));

    // Dialog open, mutation not fired yet.
    expect(await screen.findByRole('button', { name: 'Приостановить' })).toBeInTheDocument();
    expect(calls).not.toContain('suspend');

    await user.click(screen.getByRole('button', { name: 'Приостановить' }));

    await waitFor(() => expect(calls).toContain('suspend'));
    expect(toastSuccess).toHaveBeenCalledWith('Статус магазина обновлён');
  });
});

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
