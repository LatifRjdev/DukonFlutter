import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../test/msw/server';
import { api } from './api';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://api.test/api';

describe('lib/api', () => {
  let originalLocation: Location;

  beforeEach(() => {
    originalLocation = window.location;
    // jsdom's location is read-only — replace with a writable stub so we can
    // observe the redirect on 401 without navigating.
    Object.defineProperty(window, 'location', {
      configurable: true,
      writable: true,
      value: { href: '/' } as Location,
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

  it('api.post sends JSON body and credentials: include', async () => {
    const captured: { body?: string; credentials?: string; headers?: Record<string, string> } = {};
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(
      async (input: RequestInfo | URL, init?: RequestInit) => {
        captured.body = init?.body as string;
        captured.credentials = init?.credentials;
        captured.headers = init?.headers as Record<string, string>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      },
    );

    const result = await api.post('/admin/users', { name: 'Carol' });
    expect(result).toEqual({ ok: true });
    expect(captured.body).toBe(JSON.stringify({ name: 'Carol' }));
    expect(captured.credentials).toBe('include');
    expect(captured.headers).toMatchObject({ 'Content-Type': 'application/json' });

    fetchSpy.mockRestore();
  });
});
