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
