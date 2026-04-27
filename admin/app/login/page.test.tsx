import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { server } from '../../test/msw/server';

const pushMock = vi.fn();
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: pushMock, replace: vi.fn(), refresh: vi.fn() }),
}));

// sonner reaches into matchMedia / portals which we don't need to assert on.
vi.mock('sonner', () => ({
  toast: { success: vi.fn(), error: vi.fn() },
}));

import LoginPage from './page';

describe('LoginPage', () => {
  beforeEach(() => {
    pushMock.mockReset();
    localStorage.clear();
  });

  it('renders phone and password fields and a submit button', () => {
    render(<LoginPage />);
    expect(
      screen.getByLabelText(/Номер телефона/i),
    ).toBeInTheDocument();
    expect(screen.getByLabelText(/Пароль/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Войти/i })).toBeInTheDocument();
  });

  it('on success calls /api/auth/login and routes to /', async () => {
    const user = userEvent.setup();
    render(<LoginPage />);

    await user.type(
      screen.getByLabelText(/Номер телефона/i),
      '+992900000000',
    );
    await user.type(screen.getByLabelText(/Пароль/i), 'correct');
    await user.click(screen.getByRole('button', { name: /Войти/i }));

    await waitFor(() => expect(pushMock).toHaveBeenCalledWith('/'));
    expect(localStorage.getItem('userName')).toBe('Admin User');
  });

  it('on isAdmin=false shows access-denied error and calls /api/auth/logout', async () => {
    let logoutCalled = false;
    server.use(
      http.post('http://localhost:3000/api/auth/login', () =>
        HttpResponse.json({
          user: {
            id: 'u9',
            phone: '+992900000099',
            name: 'Regular User',
            isAdmin: false,
          },
        }),
      ),
      http.post('http://localhost:3000/api/auth/logout', () => {
        logoutCalled = true;
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    render(<LoginPage />);
    await user.type(
      screen.getByLabelText(/Номер телефона/i),
      '+992900000099',
    );
    await user.type(screen.getByLabelText(/Пароль/i), 'correct');
    await user.click(screen.getByRole('button', { name: /Войти/i }));

    await waitFor(() =>
      expect(
        screen.getByText(/Доступ запрещён\. Только для администраторов\./i),
      ).toBeInTheDocument(),
    );
    expect(logoutCalled).toBe(true);
    expect(pushMock).not.toHaveBeenCalled();
  });

  it('on 401 from upstream surfaces the error message', async () => {
    server.use(
      http.post('http://localhost:3000/api/auth/login', () =>
        HttpResponse.json(
          { message: 'Неверный телефон или пароль' },
          { status: 401 },
        ),
      ),
    );

    const user = userEvent.setup();
    render(<LoginPage />);
    await user.type(screen.getByLabelText(/Номер телефона/i), 'fail');
    await user.type(screen.getByLabelText(/Пароль/i), 'wrong');
    await user.click(screen.getByRole('button', { name: /Войти/i }));

    await waitFor(() =>
      expect(
        screen.getByText(/Неверный телефон или пароль/i),
      ).toBeInTheDocument(),
    );
    expect(pushMock).not.toHaveBeenCalled();
  });
});
