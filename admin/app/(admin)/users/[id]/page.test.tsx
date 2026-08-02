import { Suspense } from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
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

import UserDetailPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

async function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  // UserDetailPage reads its `id` param via React's use(params), which
  // suspends on first render until the params Promise resolves — needs a
  // Suspense boundary here since the real app's route tree provides one
  // implicitly (Next.js wraps page components in Suspense for async
  // params) but a bare render() in a test does not. Wrapping in an async
  // act() flushes that suspend-then-resolve cycle before the first
  // assertion runs, instead of relying on waitFor to catch an update that
  // happens outside any tracked act() call.
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

function mockUser() {
  server.use(
    http.get(`${API_URL}/admin/users/u1`, () =>
      HttpResponse.json({
        id: 'u1',
        name: 'Alice',
        phone: '+992900000001',
        isAdmin: false,
        isActive: true,
        createdAt: '2026-01-01T00:00:00Z',
      }),
    ),
    http.get(`${API_URL}/admin/users/u1/stores`, () =>
      HttpResponse.json([]),
    ),
  );
}

function renderPage() {
  return renderWithQuery(
    <UserDetailPage params={Promise.resolve({ id: 'u1' })} />,
  );
}

describe('UserDetailPage — impersonation flow', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
    mockUser();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('clicking "Войти как пользователь" POSTs /admin/users/:id/impersonate and opens the waiting dialog', async () => {
    const user = userEvent.setup();
    let impersonateCalls = 0;
    server.use(
      http.post(`${API_URL}/admin/users/u1/impersonate`, () => {
        impersonateCalls++;
        return HttpResponse.json({ id: 'req-1', status: 'PENDING' });
      }),
      // Token not ready yet — the polling query treats any non-2xx as
      // "not approved yet" and keeps the waiting state on screen.
      http.get(`${API_URL}/admin/impersonation/req-1/token`, () =>
        HttpResponse.json({ message: 'Request is not approved' }, { status: 400 }),
      ),
    );

    await renderPage();
    await waitFor(() => expect(screen.getByText('Alice')).toBeInTheDocument());

    await user.click(screen.getByText('Войти как пользователь'));

    await waitFor(() => expect(impersonateCalls).toBe(1));
    expect(
      await screen.findByText('Вход от имени пользователя'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('Ожидаем подтверждения от пользователя в приложении…'),
    ).toBeInTheDocument();
    expect(toastSuccess).toHaveBeenCalledWith(
      'Запрос отправлен пользователю, ожидаем подтверждения',
    );
  });

  it('renders the QR code and deep link once the token arrives, and stops polling', async () => {
    const user = userEvent.setup();
    let tokenCalls = 0;
    server.use(
      http.post(`${API_URL}/admin/users/u1/impersonate`, () =>
        HttpResponse.json({ id: 'req-1', status: 'PENDING' }),
      ),
      http.get(`${API_URL}/admin/impersonation/req-1/token`, () => {
        tokenCalls++;
        return HttpResponse.json({ token: 'signed-jwt-token' });
      }),
    );

    await renderPage();
    await waitFor(() => expect(screen.getByText('Alice')).toBeInTheDocument());
    await user.click(screen.getByText('Войти как пользователь'));

    // First poll fires immediately (query becomes enabled) and succeeds —
    // deep link + QR should render.
    await waitFor(() => expect(tokenCalls).toBe(1));
    await waitFor(() =>
      expect(
        screen.getByText('dukonpro://impersonate?token=signed-jwt-token'),
      ).toBeInTheDocument(),
    );

    // refetchInterval returns false once query.state.data is set — advance
    // well past the 4s interval and confirm no further requests happened.
    vi.useFakeTimers();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(15000);
    });
    expect(tokenCalls).toBe(1);
  });

  it('"Завершить сессию" (admin side) POSTs /admin/impersonation/:id/end and closes the dialog', async () => {
    const user = userEvent.setup();
    let endCalls = 0;
    server.use(
      http.post(`${API_URL}/admin/users/u1/impersonate`, () =>
        HttpResponse.json({ id: 'req-1', status: 'PENDING' }),
      ),
      http.get(`${API_URL}/admin/impersonation/req-1/token`, () =>
        HttpResponse.json({ token: 'signed-jwt-token' }),
      ),
      http.post(`${API_URL}/admin/impersonation/req-1/end`, () => {
        endCalls++;
        return HttpResponse.json({ id: 'req-1', status: 'ENDED' });
      }),
    );

    await renderPage();
    await waitFor(() => expect(screen.getByText('Alice')).toBeInTheDocument());
    await user.click(screen.getByText('Войти как пользователь'));
    await waitFor(() =>
      expect(screen.getByText('Завершить сессию')).toBeInTheDocument(),
    );

    await user.click(screen.getByText('Завершить сессию'));

    await waitFor(() => expect(endCalls).toBe(1));
    await waitFor(() =>
      expect(
        screen.queryByText('Вход от имени пользователя'),
      ).not.toBeInTheDocument(),
    );
    expect(toastSuccess).toHaveBeenCalledWith('Сессия поддержки завершена');
  });

  it('closing the dialog via "Закрыть" resets state so a fresh click sends a new request', async () => {
    const user = userEvent.setup();
    let impersonateCalls = 0;
    server.use(
      http.post(`${API_URL}/admin/users/u1/impersonate`, () => {
        impersonateCalls++;
        return HttpResponse.json({
          id: `req-${impersonateCalls}`,
          status: 'PENDING',
        });
      }),
      http.get(`${API_URL}/admin/impersonation/req-1/token`, () =>
        HttpResponse.json({ message: 'Request is not approved' }, { status: 400 }),
      ),
      http.get(`${API_URL}/admin/impersonation/req-2/token`, () =>
        HttpResponse.json({ message: 'Request is not approved' }, { status: 400 }),
      ),
    );

    await renderPage();
    await waitFor(() => expect(screen.getByText('Alice')).toBeInTheDocument());

    await user.click(screen.getByText('Войти как пользователь'));
    await waitFor(() => expect(impersonateCalls).toBe(1));
    expect(
      await screen.findByText('Вход от имени пользователя'),
    ).toBeInTheDocument();

    await user.click(screen.getByText('Закрыть'));
    await waitFor(() =>
      expect(
        screen.queryByText('Вход от имени пользователя'),
      ).not.toBeInTheDocument(),
    );

    await user.click(screen.getByText('Войти как пользователь'));
    await waitFor(() => expect(impersonateCalls).toBe(2));
  });
});
