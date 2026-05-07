import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../test/msw/server';
import { api } from './api';

// Browser fetches now go through the same-origin proxy at /api/proxy
// (see admin/app/api/proxy/[...path]/route.ts). Tests intercept on the
// jsdom origin (http://localhost:3000) instead of the upstream API host.
const API_URL = 'http://localhost:3000/api/proxy';

describe('lib/api', () => {
  let originalLocation: Location;

  beforeEach(() => {
    originalLocation = window.location;
    // jsdom's location is read-only — replace with a writable stub so we can
    // observe the redirect on 401 without navigating.
    // Keep the jsdom origin intact so apiFetch can build absolute URLs;
    // we only need .href to be writable so the 401-redirect assertion works.
    Object.defineProperty(window, 'location', {
      configurable: true,
      writable: true,
      value: { href: '/', origin: 'http://localhost:3000' } as Location,
    });
  });

  afterEach(() => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      writable: true,
      value: originalLocation,
    });
  });

  it('api.get returns parsed JSON body on 200', async () => {
    const result = await api.get('/admin/users');
    expect(result).toMatchObject({
      data: expect.any(Array),
      total: 1,
    });
    expect(result.data[0].name).toBe('Alice');
  });

  it('api.get redirects to /login on 401', async () => {
    server.use(
      http.get(`${API_URL}/admin/users`, () =>
        HttpResponse.json({ message: 'unauth' }, { status: 401 }),
      ),
    );

    await expect(api.get('/admin/users')).rejects.toThrow(/Unauthorized/);
    expect(window.location.href).toBe('/login');
  });

  it('api.post sends JSON body to the same-origin proxy', async () => {
    // Same-origin proxy: no credentials: include needed (cookies travel
    // automatically on same-origin requests). The proxy reads the
    // HttpOnly cookie server-side and forwards as Bearer to the API.
    const captured: { url?: string; body?: string; headers?: Record<string, string> } = {};
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(
      async (input: RequestInfo | URL, init?: RequestInit) => {
        captured.url = typeof input === 'string' ? input : input.toString();
        captured.body = init?.body as string;
        captured.headers = init?.headers as Record<string, string>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      },
    );

    const result = await api.post('/admin/users', { name: 'Carol' });
    expect(result).toEqual({ ok: true });
    expect(captured.url).toBe('http://localhost:3000/api/proxy/admin/users');
    expect(captured.body).toBe(JSON.stringify({ name: 'Carol' }));
    expect(captured.headers).toMatchObject({ 'Content-Type': 'application/json' });

    fetchSpy.mockRestore();
  });
});
