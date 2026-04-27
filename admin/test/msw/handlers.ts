import { http, HttpResponse } from 'msw';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://api.test/api';

// Default test fixtures. Tests that need different shapes (failure paths,
// custom envelopes) override with server.use(...) inside the test.
export const handlers = [
  // Next.js route handler that the login page calls. Matches the real shape
  // returned by /admin/app/api/auth/login/route.ts (sets a cookie, returns user).
  http.post('http://localhost:3000/api/auth/login', async ({ request }) => {
    const body = (await request.json()) as { phone?: string; password?: string };
    if (body.phone === 'fail' || body.password === 'wrong') {
      return HttpResponse.json(
        { message: 'Invalid credentials' },
        { status: 401 },
      );
    }
    return HttpResponse.json(
      {
        user: {
          id: 'u1',
          phone: body.phone ?? '+992900000000',
          name: 'Admin User',
          isAdmin: true,
        },
      },
      {
        status: 200,
        headers: {
          // Mirror the cookie shape the real route handler sets.
          'Set-Cookie': 'token=fake-jwt; HttpOnly; Path=/',
        },
      },
    );
  }),

  http.post('http://localhost:3000/api/auth/logout', () =>
    HttpResponse.json({ ok: true }),
  ),

  // Backend list endpoint — paginated envelope { data, total, page, pageSize }.
  // This is the shape the real api wrappers expect (see audit-log/users pages
  // which read `r.data ?? []`).
  http.get(`${API_URL}/admin/users`, () =>
    HttpResponse.json({
      data: [
        {
          id: 'u1',
          name: 'Alice',
          phone: '+992900000001',
          email: 'a@x.tj',
          isAdmin: true,
          isActive: true,
          createdAt: '2026-01-01T00:00:00Z',
          _count: { ownedStores: 2 },
        },
      ],
      total: 1,
      page: 1,
      pageSize: 50,
    }),
  ),

  // Audit log with object-shaped fields that triggered the
  // "Objects are not valid as a React child" regression.
  http.get(`${API_URL}/admin/audit-log`, () =>
    HttpResponse.json({
      data: [
        {
          id: 'log1',
          createdAt: '2026-04-26T12:00:00Z',
          userId: 'u1',
          user: { id: 'u1', name: 'Alice', phone: '+992900000001' },
          action: 'UPDATE',
          entityType: 'User',
          entityId: 'u2',
          // details is an object — must be JSON-stringified, not rendered raw.
          details: { before: { name: 'Bob' }, after: { name: 'Bobby' } },
          ip: '127.0.0.1',
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    }),
  ),
];
