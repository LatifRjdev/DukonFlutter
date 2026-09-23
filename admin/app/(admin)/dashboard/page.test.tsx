import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

import DashboardPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('DashboardPage reads the real backend stats shape', () => {
  it('renders subscriptionsByStatus and approvedPaymentsThisMonth correctly, not the old flat field names', async () => {
    server.use(
      http.get(`${API_URL}/admin/dashboard`, () =>
        HttpResponse.json({
          totalUsers: 13,
          totalStores: 10,
          subscriptionsByStatus: { ACTIVE: 2, EXPIRED: 7, PAST_DUE: 1 },
          approvedPaymentsThisMonth: { total: 450, count: 3 },
          newUsersThisMonth: 4,
          newStoresThisMonth: 3,
        }),
      ),
      http.get(`${API_URL}/admin/revenue`, () => HttpResponse.json([])),
      http.get(`${API_URL}/admin/dashboard/registrations`, () =>
        HttpResponse.json([]),
      ),
      http.get(`${API_URL}/admin/subscriptions/pending-payments`, () =>
        HttpResponse.json([]),
      ),
    );

    renderWithQuery(<DashboardPage />);

    // Active subscriptions: real value (2), not the old always-0 fallback.
    await waitFor(() => expect(screen.getByText('2')).toBeInTheDocument());
    // Expired subscriptions: real value (7).
    expect(screen.getByText('7')).toBeInTheDocument();
    // Revenue: formatted currency, never "не число" (NaN-in-currency).
    expect(screen.queryByText(/не число/)).not.toBeInTheDocument();
    expect(screen.getByText(/450/)).toBeInTheDocument();
    // Monthly counts (renamed from the nonexistent "ThisWeek" fields) —
    // both labels must be present, proving the cards read
    // newUsersThisMonth/newStoresThisMonth rather than the old
    // nonexistent newUsersThisWeek/newStoresThisWeek fields.
    expect(screen.getByText('Новые за месяц')).toBeInTheDocument();
    expect(screen.getByText('Новые магазины')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
  });
});
