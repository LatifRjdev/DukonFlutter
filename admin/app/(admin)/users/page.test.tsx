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

import UsersPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

function mockSingleUser(
  user: Partial<{
    id: string;
    name: string;
    phone: string;
    isAdmin: boolean;
    isActive: boolean;
  }> = {},
) {
  server.use(
    http.get(`${API_URL}/admin/users`, () =>
      HttpResponse.json({
        data: [
          {
            id: user.id ?? 'u1',
            name: user.name ?? 'Alice',
            phone: user.phone ?? '+992900000001',
            email: 'a@x.tj',
            isAdmin: user.isAdmin ?? false,
            isActive: user.isActive ?? true,
            createdAt: '2026-01-01T00:00:00Z',
            _count: { ownedStores: 2 },
          },
        ],
        total: 1,
        page: 1,
        pageSize: 50,
      }),
    ),
  );
}

describe('UsersPage — paginated envelope rendering (regression for 69662d7 / 0ce5cfd)', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('unwraps {data,total,page,pageSize} envelope and shows the row', async () => {
    mockSingleUser({ name: 'Alice Envelope' });
    renderWithQuery(<UsersPage />);

    await waitFor(() =>
      expect(screen.getByText('Alice Envelope')).toBeInTheDocument(),
    );
    // Phone column rendered alongside.
    expect(screen.getByText('+992900000001')).toBeInTheDocument();
    // Total counter ("1 пользователей всего") proves we read .data.length, not the envelope.
    expect(screen.getByText(/1 пользователей всего/i)).toBeInTheDocument();
  });
});

describe('UsersPage — destructive action: block / unblock', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
  it('clicking "Заблокировать" PUTs /admin/users/:id/block and toasts success', async () => {
    mockSingleUser({ id: 'u1', name: 'Alice', isActive: true });

    const blockCalls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/users/u1/block`, () => {
        blockCalls.push('block');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Alice'));

    // Open the row's action dropdown.
    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    expect(trigger).toBeTruthy();
    await user.click(trigger);

    const blockItem = await screen.findByText('Заблокировать');
    await user.click(blockItem);

    await waitFor(() => expect(blockCalls).toContain('block'));
    await waitFor(() =>
      expect(toastSuccess).toHaveBeenCalledWith('Статус пользователя обновлён'),
    );
  });

  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
  it('clicking "Разблокировать" on a blocked user PUTs /admin/users/:id/unblock', async () => {
    mockSingleUser({ id: 'u1', name: 'Bob Blocked', isActive: false });

    const unblockCalls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/users/u1/unblock`, () => {
        unblockCalls.push('unblock');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Bob Blocked'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const unblockItem = await screen.findByText('Разблокировать');
    await user.click(unblockItem);

    await waitFor(() => expect(unblockCalls).toContain('unblock'));
    expect(toastSuccess).toHaveBeenCalledWith('Статус пользователя обновлён');
  });
});

describe('UsersPage — destructive action: revoke admin role', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
  it('clicking "Снять права admin" PUTs /admin/users/:id/toggle-admin and toasts success', async () => {
    mockSingleUser({ id: 'u1', name: 'Carol Admin', isAdmin: true });

    const toggleCalls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/users/u1/toggle-admin`, () => {
        toggleCalls.push('toggle');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Carol Admin'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const revokeItem = await screen.findByText('Снять права admin');
    await user.click(revokeItem);

    await waitFor(() => expect(toggleCalls).toContain('toggle'));
    expect(toastSuccess).toHaveBeenCalledWith('Роль пользователя обновлена');
  });
});
