import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http, HttpResponse } from 'msw';
import { server } from '../msw/server';

// Audit log uses next/navigation for nothing here, but Tooltip / Select from
// Base UI may probe matchMedia — handled in test/setup.ts.
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
}));

import AuditLogPage from '../../app/(admin)/audit-log/page';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://api.test/api';

function renderWithQuery(ui: React.ReactElement) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

describe('audit-log regression: object-as-React-child fix (0fc1fe2)', () => {
  it('renders rows where user/details are objects without throwing', async () => {
    // Override the default handler to be explicit about the object shapes
    // that previously caused "Objects are not valid as a React child".
    server.use(
      http.get(`${API_URL}/admin/audit-log`, () =>
        HttpResponse.json({
          data: [
            {
              id: 'log1',
              createdAt: '2026-04-26T12:00:00Z',
              userId: 'u1',
              user: { id: 'u1', name: 'Alice Admin', phone: '+992900000001' },
              action: 'UPDATE',
              entityType: 'User',
              entityId: 'u2',
              details: { before: { name: 'Bob' }, after: { name: 'Bobby' } },
              ip: '127.0.0.1',
            },
          ],
          total: 1,
          page: 1,
          pageSize: 20,
        }),
      ),
    );

    // If the page tried to render the user object directly, React would throw
    // synchronously and this render() call would reject.
    expect(() => renderWithQuery(<AuditLogPage />)).not.toThrow();

    // Once data lands, the user's *name* (a string) must appear — proving the
    // page extracts the scalar field instead of dropping the whole object in.
    await waitFor(() =>
      expect(screen.getByText('Alice Admin')).toBeInTheDocument(),
    );

    // entityType is rendered too (string field on the row).
    expect(screen.getByText('User')).toBeInTheDocument();
  });
});
