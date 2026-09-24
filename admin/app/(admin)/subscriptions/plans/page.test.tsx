import { describe, it, expect } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../../test/msw/server';

import PlansPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

const REAL_PLAN_SHAPE = {
  plan: 'START',
  price: 200,
  maxProducts: 500,
  maxStaff: 2,
  maxDiscounts: 0,
  hasReportsAll: false,
  hasExport: false,
  hasTelegram: false,
  hasAllPush: false,
  hasDelivery: false,
  hasInventory: false,
  hasZakat: false,
  hasInvestments: false,
  hasLoyalty: false,
  hasBatchProfitability: false,
  hasEcommerceIntegration: false,
};

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('PlansPage reads/writes the real backend shape (no id/name/maxStores)', () => {
  it('renders the plan name from the "plan" field, not the nonexistent "name" field', async () => {
    server.use(
      http.get(`${API_URL}/admin/plans`, () => HttpResponse.json([REAL_PLAN_SHAPE])),
    );

    renderWithQuery(<PlansPage />);

    await waitFor(() => expect(screen.getByText('START')).toBeInTheDocument());
  });

  it('Save PUTs only UpdatePlanDto fields to /admin/plans/<plan>, never id/name/maxStores', async () => {
    server.use(
      http.get(`${API_URL}/admin/plans`, () => HttpResponse.json([REAL_PLAN_SHAPE])),
    );

    const captured: { url?: string; body?: unknown } = {};
    server.use(
      http.put(`${API_URL}/admin/plans/:plan`, async ({ request, params }) => {
        captured.url = `/admin/plans/${params.plan}`;
        captured.body = await request.json();
        return HttpResponse.json({ ...REAL_PLAN_SHAPE, price: 999 });
      }),
    );

    renderWithQuery(<PlansPage />);
    await waitFor(() => expect(screen.getByText('START')).toBeInTheDocument());

    const priceInput = screen.getByLabelText('Цена (сом/месяц)');
    await userEvent.clear(priceInput);
    await userEvent.type(priceInput, '999');
    await userEvent.click(screen.getByRole('button', { name: /Сохранить/i }));

    await waitFor(() => expect(captured.url).toBe('/admin/plans/START'));
    expect(captured.body).not.toHaveProperty('id');
    expect(captured.body).not.toHaveProperty('name');
    expect(captured.body).not.toHaveProperty('maxStores');
    expect(captured.body).toMatchObject({ price: 999, maxProducts: 500 });
  });

  it('does not render a "Макс. магазинов" field (maxStores no longer exists on the backend)', async () => {
    server.use(
      http.get(`${API_URL}/admin/plans`, () => HttpResponse.json([REAL_PLAN_SHAPE])),
    );

    renderWithQuery(<PlansPage />);
    await waitFor(() => expect(screen.getByText('START')).toBeInTheDocument());

    expect(screen.queryByText('Макс. магазинов')).not.toBeInTheDocument();
  });
});
