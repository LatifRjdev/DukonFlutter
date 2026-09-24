import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { format } from 'date-fns';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

import AnnouncementsPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('AnnouncementsPage history table shows real sender name and date', () => {
  it('renders the resolved sender name and formatted date, not a raw UUID or dash', async () => {
    const createdAt = '2026-04-01T10:00:00Z';
    server.use(
      http.get(`${API_URL}/admin/announcements`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'ann1',
              title: 'Добро пожаловать!',
              body: 'Текст',
              targetPlan: null,
              targetStatus: null,
              recipientCount: 5,
              createdAt,
              sentBy: 'bf774704-c8b4-4622-8cdb-985750b654e0',
              senderName: 'Admin',
            },
          ],
          total: 1,
          page: 1,
          limit: 20,
        }),
      ),
    );

    renderWithQuery(<AnnouncementsPage />);

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument());
    expect(
      screen.queryByText('bf774704-c8b4-4622-8cdb-985750b654e0'),
    ).not.toBeInTheDocument();
    // Computed the same way the component formats it (local time), rather
    // than a hardcoded UTC string, so the assertion isn't tied to the
    // test runner's timezone.
    expect(
      screen.getByText(format(new Date(createdAt), 'dd.MM.yyyy HH:mm')),
    ).toBeInTheDocument();
  });

  it('falls back to the raw id when senderName is null (sending admin deleted)', async () => {
    server.use(
      http.get(`${API_URL}/admin/announcements`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'ann2',
              title: 'Old announcement',
              body: 'Текст',
              targetPlan: null,
              targetStatus: null,
              recipientCount: 0,
              createdAt: '2026-01-01T00:00:00Z',
              sentBy: 'deleted-admin-id',
              senderName: null,
            },
          ],
          total: 1,
          page: 1,
          limit: 20,
        }),
      ),
    );

    renderWithQuery(<AnnouncementsPage />);

    await waitFor(() =>
      expect(screen.getByText('deleted-admin-id')).toBeInTheDocument(),
    );
  });
});

describe('AnnouncementsPage preview request includes title and body', () => {
  it('POSTs title and body (not just targetPlan/targetStatus) to /admin/announcements/preview', async () => {
    server.use(
      http.get(`${API_URL}/admin/announcements`, () =>
        HttpResponse.json({ data: [], total: 0, page: 1, limit: 20 }),
      ),
    );

    const captured: { body?: unknown } = {};
    server.use(
      http.post(`${API_URL}/admin/announcements/preview`, async ({ request }) => {
        captured.body = await request.json();
        return HttpResponse.json({ count: 3 });
      }),
    );

    renderWithQuery(<AnnouncementsPage />);

    await userEvent.type(
      screen.getByPlaceholderText(/Новые функции/i),
      'QA Title',
    );
    await userEvent.type(
      screen.getByPlaceholderText(/Введите текст объявления/i),
      'QA Body',
    );
    await userEvent.click(screen.getByRole('button', { name: /Отправить/i }));

    await waitFor(() => expect(captured.body).toMatchObject({
      title: 'QA Title',
      body: 'QA Body',
    }));
  });
});
