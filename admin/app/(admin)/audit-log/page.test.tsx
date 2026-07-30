import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../../../test/msw/server';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

import AuditLogPage from './page';

const API_URL = 'http://localhost:3000/api/proxy';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('AuditLogPage — before/after diff rendering', () => {
  it('shows a changed-field count and expands to a field-by-field diff for the new {before, after} shape', async () => {
    const user = userEvent.setup();
    server.use(
      http.get(`${API_URL}/admin/audit-log`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'log1',
              createdAt: '2026-04-26T12:00:00Z',
              userId: 'admin-1',
              user: { id: 'admin-1', name: 'Alice Admin', phone: '+992900000001' },
              action: 'UPDATE',
              entityType: 'users',
              entityId: 'u1',
              details: {
                before: { id: 'u1', isAdmin: false },
                after: { id: 'u1', isAdmin: true },
              },
              ip: '127.0.0.1',
            },
          ],
          total: 1,
          page: 1,
          pageSize: 20,
        }),
      ),
    );

    renderWithQuery(<AuditLogPage />);

    await waitFor(() => expect(screen.getByText('1 изм.')).toBeInTheDocument());

    // Diff fields are hidden until expanded.
    expect(screen.queryByText('isAdmin:')).not.toBeInTheDocument();

    await user.click(screen.getByText('1 изм.'));

    expect(screen.getByText('isAdmin:')).toBeInTheDocument();
    expect(screen.getByText('false')).toBeInTheDocument();
    expect(screen.getByText('true')).toBeInTheDocument();
  });

  it('shows "Без изменений" when before and after are identical', async () => {
    server.use(
      http.get(`${API_URL}/admin/audit-log`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'log2',
              createdAt: '2026-04-26T12:00:00Z',
              userId: 'admin-1',
              user: { id: 'admin-1', name: 'Alice Admin', phone: '+992900000001' },
              action: 'UPDATE',
              entityType: 'users',
              entityId: 'u1',
              details: {
                before: { id: 'u1', isAdmin: false },
                after: { id: 'u1', isAdmin: false },
              },
              ip: '127.0.0.1',
            },
          ],
          total: 1,
          page: 1,
          pageSize: 20,
        }),
      ),
    );

    renderWithQuery(<AuditLogPage />);

    await waitFor(() => expect(screen.getByText('Без изменений')).toBeInTheDocument());
  });

  it('falls back to raw JSON rendering for legacy flat-shape details without crashing', async () => {
    const user = userEvent.setup();
    server.use(
      http.get(`${API_URL}/admin/audit-log`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'log3',
              createdAt: '2025-01-15T09:00:00Z',
              userId: 'admin-1',
              user: { id: 'admin-1', name: 'Alice Admin', phone: '+992900000001' },
              action: 'UPDATE',
              entityType: 'users',
              entityId: 'u1',
              details: { name: 'Legacy Body', phone: '+992900000009' },
              ip: '127.0.0.1',
            },
          ],
          total: 1,
          page: 1,
          pageSize: 20,
        }),
      ),
    );

    expect(() => renderWithQuery(<AuditLogPage />)).not.toThrow();

    await waitFor(() =>
      expect(screen.getByText(/Legacy Body/)).toBeInTheDocument(),
    );

    // Legacy rendering is a raw-JSON toggle button, not the diff summary.
    expect(screen.queryByText(/изм\./)).not.toBeInTheDocument();

    // Expanding shows the full JSON without throwing.
    await user.click(screen.getByText(/Legacy Body/));
    expect(screen.getByText(/"phone": "\+992900000009"/)).toBeInTheDocument();
  });
});
