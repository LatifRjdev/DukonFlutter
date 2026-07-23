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

interface CreateUserRequestBody {
  name: string;
  phone: string;
  email?: string;
  password?: string;
  createStore?: boolean;
  storeName?: string;
  storeCategory?: string;
}

describe('UsersPage — manual user creation', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('opens the create-user dialog, submits a manual password, and shows a success toast (no password dialog)', async () => {
    mockSingleUser({ name: 'Existing User' });

    const createCalls: CreateUserRequestBody[] = [];
    server.use(
      http.post(`${API_URL}/admin/users`, async ({ request }) => {
        const body = (await request.json()) as CreateUserRequestBody;
        createCalls.push(body);
        return HttpResponse.json({
          user: { id: 'u-new', phone: body.phone, name: body.name, email: null, isAdmin: false },
          store: null,
          generatedPassword: null,
        });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));

    await user.type(screen.getByLabelText(/имя/i), 'Новый Пользователь');
    await user.type(screen.getByLabelText(/телефон/i), '+992901112233');

    // Switch to manual password entry and type a password.
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'CorrectHorseBatteryStaple8');

    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() => expect(createCalls).toHaveLength(1));
    expect(createCalls[0]).toMatchObject({
      name: 'Новый Пользователь',
      phone: '+992901112233',
      password: 'CorrectHorseBatteryStaple8',
    });
    await waitFor(() =>
      expect(toastSuccess).toHaveBeenCalledWith('Пользователь создан'),
    );
    // No password-reveal dialog when the admin typed the password themselves.
    expect(screen.queryByText(/скопируйте/i)).not.toBeInTheDocument();
  });

  it('shows a one-time password dialog with a copy button when the server generates the password', async () => {
    mockSingleUser({ name: 'Existing User' });

    server.use(
      http.post(`${API_URL}/admin/users`, async ({ request }) => {
        const body = (await request.json()) as CreateUserRequestBody;
        return HttpResponse.json({
          user: { id: 'u-new', phone: body.phone, name: body.name, email: null, isAdmin: false },
          store: null,
          generatedPassword: 'gEnErAt3d!Pass9xYz',
        });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Сгенерированный');
    await user.type(screen.getByLabelText(/телефон/i), '+992901112244');
    // Password mode defaults to "generate" — submit without touching the switch.
    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() =>
      expect(screen.getByText('gEnErAt3d!Pass9xYz')).toBeInTheDocument(),
    );
    expect(screen.getByText(/больше не будет показан/i)).toBeInTheDocument();
  });

  it('reveals store fields when "Создать магазин сразу" is toggled on, and sends them on submit', async () => {
    mockSingleUser({ name: 'Existing User' });

    const createCalls: CreateUserRequestBody[] = [];
    server.use(
      http.post(`${API_URL}/admin/users`, async ({ request }) => {
        const body = (await request.json()) as CreateUserRequestBody;
        createCalls.push(body);
        return HttpResponse.json({
          user: { id: 'u-new', phone: body.phone, name: body.name, email: null, isAdmin: false },
          store: { id: 'store-new', name: body.storeName },
          generatedPassword: null,
        });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Владелец');
    await user.type(screen.getByLabelText(/телефон/i), '+992901112255');
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'CorrectHorseBatteryStaple8');

    // Store fields must not be visible before the toggle.
    expect(screen.queryByLabelText(/название магазина/i)).not.toBeInTheDocument();

    await user.click(screen.getByRole('switch', { name: /создать магазин сразу/i }));
    expect(screen.getByLabelText(/название магазина/i)).toBeInTheDocument();
    await user.type(screen.getByLabelText(/название магазина/i), 'Магазин Алиевых');

    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() => expect(createCalls).toHaveLength(1));
    expect(createCalls[0]).toMatchObject({
      createStore: true,
      storeName: 'Магазин Алиевых',
    });
  });

  it('shows an error toast when the phone is already taken (409)', async () => {
    mockSingleUser({ name: 'Existing User' });

    server.use(
      http.post(`${API_URL}/admin/users`, () =>
        HttpResponse.json({ message: 'User with this phone already exists' }, { status: 409 }),
      ),
    );

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Дубликат');
    await user.type(screen.getByLabelText(/телефон/i), '+992900000001');
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'CorrectHorseBatteryStaple8');

    await user.click(screen.getByRole('button', { name: /^создать$/i }));

    await waitFor(() => expect(toastError).toHaveBeenCalled());
  });

  it('clears the form when "Отмена" is clicked, not just on Escape/overlay close', async () => {
    mockSingleUser({ name: 'Existing User' });

    const user = userEvent.setup();
    renderWithQuery(<UsersPage />);
    await waitFor(() => screen.getByText('Existing User'));

    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    await user.type(screen.getByLabelText(/имя/i), 'Забытый Черновик');
    await user.click(screen.getByRole('switch', { name: /ввести самому/i }));
    await user.type(screen.getByLabelText(/^пароль$/i), 'ShouldNotLinger9');

    await user.click(screen.getByRole('button', { name: /^отмена$/i }));

    // Reopen the dialog — stale name/password must not be pre-filled.
    await user.click(screen.getByRole('button', { name: /создать пользователя/i }));
    expect(screen.getByLabelText(/имя/i)).toHaveValue('');
    // Password mode must also reset to "generate", hiding the password field
    // (and with it, any lingering manually-typed password).
    expect(screen.queryByLabelText(/^пароль$/i)).not.toBeInTheDocument();
  });
});
