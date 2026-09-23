import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
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
              createdAt: '2026-04-01T10:00:00Z',
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
    expect(screen.getByText('01.04.2026 10:00')).toBeInTheDocument();
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
