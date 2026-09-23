import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));
vi.mock('@/components/charts/revenue-chart', () => ({
  RevenueChart: ({ data }: { data: unknown }) => (
    <div data-testid="revenue-chart-data">{JSON.stringify(data)}</div>
  ),
}));
vi.mock('@/components/charts/registrations-chart', () => ({
  RegistrationsChart: ({ data }: { data: unknown }) => (
    <div data-testid="registrations-chart-data">{JSON.stringify(data)}</div>
  ),
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

describe('DashboardPage never shows fabricated chart data', () => {
  it('passes an empty array to the charts while the real queries are loading, never Math.random() output', () => {
    // Stub the other two queries so they don't attempt a real network
    // request during this test (MSW's onUnhandledRequest is 'bypass',
    // which would otherwise try to actually connect). Deliberately do NOT
    // register a handler for /admin/revenue or /admin/dashboard/registrations
    // — those two queries must stay pending, so revenueData/registrationData
    // are undefined on first render. Before this fix, that undefined state
    // fell back to Math.random()-generated arrays; after, it must fall back
    // to [].
    server.use(
      http.get(`${API_URL}/admin/dashboard`, () => HttpResponse.json({})),
      http.get(`${API_URL}/admin/subscriptions/pending-payments`, () =>
        HttpResponse.json([]),
      ),
    );

    renderWithQuery(<DashboardPage />);

    expect(screen.getByTestId('revenue-chart-data').textContent).toBe('[]');
    expect(screen.getByTestId('registrations-chart-data').textContent).toBe(
      '[]',
    );
  });
});
