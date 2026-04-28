import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  useSearchParams: () => new URLSearchParams(''),
}));

const toastSuccess = vi.fn();
const toastError = vi.fn();
vi.mock('sonner', () => ({
  toast: {
    success: (msg: string) => toastSuccess(msg),
    error: (msg: string) => toastError(msg),
  },
}));

import SubscriptionsPage from './page';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://api.test/api';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

// NOTE: SubscriptionsPage queryFn returns api.get(...) directly without
// unwrapping `.data`, so the page expects a raw array (not the envelope).
// We mock both list endpoints accordingly. The "envelope regression" test
// for paginated unwrap lives in users/page.test.tsx where the page does
// `r.data ?? []`.
function mockSubscriptionsAndPending() {
  server.use(
    http.get(`${API_URL}/admin/subscriptions`, () =>
      HttpResponse.json([
        {
          id: 'sub1',
          storeId: 's1',
          plan: 'BUSINESS',
          status: 'ACTIVE',
          currentPeriodEnd: '2026-12-31T00:00:00Z',
          adminDiscount: 0,
          createdAt: '2026-01-01T00:00:00Z',
          store: { id: 's1', name: 'Demo Store' },
        },
      ]),
    ),
    http.get(`${API_URL}/admin/subscriptions/pending-payments`, () =>
      HttpResponse.json([
        {
          id: 'pay1',
          subscriptionId: 'sub1',
          amount: 250,
          currency: 'TJS',
          createdAt: '2026-04-26T12:00:00Z',
          subscription: {
            id: 'sub1',
            plan: 'BUSINESS',
            status: 'PAST_DUE',
            store: { id: 's1', name: 'Pending Store' },
          },
        },
      ]),
    ),
  );
}

describe('SubscriptionsPage — list rendering', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  it('renders subscription rows from /admin/subscriptions', async () => {
    mockSubscriptionsAndPending();
    renderWithQuery(<SubscriptionsPage />);

    await waitFor(() =>
      expect(screen.getByText('Demo Store')).toBeInTheDocument(),
    );
    // Tab counter shows "(1)" — proves we pulled exactly one row.
    expect(screen.getByText(/Все подписки \(1\)/)).toBeInTheDocument();
  });
});

describe('SubscriptionsPage — destructive action: cancel subscription', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
  it('clicking "Отменить" PUTs /admin/subscriptions/:id/cancel and toasts success', async () => {
    mockSubscriptionsAndPending();

    const calls: string[] = [];
    server.use(
      http.put(`${API_URL}/admin/subscriptions/sub1/cancel`, () => {
        calls.push('cancel');
        return HttpResponse.json({ ok: true });
      }),
    );

    const user = userEvent.setup();
    renderWithQuery(<SubscriptionsPage />);
    await waitFor(() => screen.getByText('Demo Store'));

    const trigger = document.querySelector(
      '[data-slot="dropdown-menu-trigger"]',
    ) as HTMLElement;
    await user.click(trigger);

    const cancelItem = await screen.findByText('Отменить');
    await user.click(cancelItem);

    await waitFor(() => expect(calls).toContain('cancel'));
    expect(toastSuccess).toHaveBeenCalledWith('Подписка отменена');
  });
});

describe('SubscriptionsPage — destructive action: approve / reject pending payment', () => {
  beforeEach(() => {
    toastSuccess.mockReset();
    toastError.mockReset();
  });

  // TODO: when confirmation dialog is added, this test should assert dialog appears first.
  it('clicking "Подтвердить" PUTs /admin/subscriptions/:subId/approve-payment/:payId', async () => {
    mockSubscriptionsAndPending();

    const calls: string[] = [];
    server.use(
      http.put(
        `${API_URL}/admin/subscriptions/sub1/approve-payment/pay1`,
        () => {
          calls.push('approve');
          return HttpResponse.json({ ok: true });
        },
      ),
    );

    const user = userEvent.setup();
    renderWithQuery(<SubscriptionsPage />);

    // Switch to "pending" tab where the approve/reject buttons live.
    const pendingTab = await screen.findByRole('tab', {
      name: /Ожидают оплаты/i,
    });
    await user.click(pendingTab);

    const approveBtn = await screen.findByRole('button', {
      name: /Подтвердить/i,
    });
    await user.click(approveBtn);

    await waitFor(() => expect(calls).toContain('approve'));
    expect(toastSuccess).toHaveBeenCalledWith('Платёж подтверждён');
  });

  it('clicking "Отклонить" opens reject dialog and PUTs reject-payment with reason', async () => {
    mockSubscriptionsAndPending();

    let capturedBody: { reason?: string } | null = null;
    server.use(
      http.put(
        `${API_URL}/admin/subscriptions/sub1/reject-payment/pay1`,
        async ({ request }) => {
          capturedBody = (await request.json()) as { reason?: string };
          return HttpResponse.json({ ok: true });
        },
      ),
    );

    const user = userEvent.setup();
    renderWithQuery(<SubscriptionsPage />);

    const pendingTab = await screen.findByRole('tab', {
      name: /Ожидают оплаты/i,
    });
    await user.click(pendingTab);

    const rejectBtn = await screen.findByRole('button', {
      name: /Отклонить/i,
    });
    await user.click(rejectBtn);

    // Dialog opened — find the textarea for reason.
    const reasonInput = await screen.findByPlaceholderText(/Укажите причину/i);
    await user.type(reasonInput, 'Invalid receipt');

    // Submit via the destructive button inside the dialog footer. There are
    // multiple "Отклонить" buttons after dialog opens (the card's button is
    // still in the tree); pick the last, which is the dialog footer's submit.
    const allRejectButtons = screen.getAllByRole('button', {
      name: /Отклонить/i,
    });
    await user.click(allRejectButtons[allRejectButtons.length - 1]);

    await waitFor(() => expect(capturedBody).not.toBeNull());
    expect(capturedBody).toEqual({ reason: 'Invalid receipt' });
    await waitFor(() =>
      expect(toastSuccess).toHaveBeenCalledWith('Платёж отклонён'),
    );
  });
});
