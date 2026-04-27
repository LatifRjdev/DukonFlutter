import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock `jose` BEFORE importing middleware so the real verify is replaced.
vi.mock('jose', () => ({
  jwtVerify: vi.fn(),
}));

import { jwtVerify } from 'jose';
import { middleware } from './middleware';

// Build a NextRequest-shaped object with the minimal surface middleware uses:
//   req.nextUrl.pathname, req.url, req.cookies.get(name).
function makeRequest(opts: { pathname?: string; token?: string } = {}) {
  const pathname = opts.pathname ?? '/dashboard';
  const url = `http://localhost${pathname}`;
  const cookies = new Map<string, string>();
  if (opts.token) cookies.set('token', opts.token);

  return {
    url,
    nextUrl: new URL(url),
    cookies: {
      get: (name: string) => {
        const v = cookies.get(name);
        return v ? { name, value: v } : undefined;
      },
    },
  } as unknown as Parameters<typeof middleware>[0];
}

describe('admin middleware', () => {
  beforeEach(() => {
    vi.mocked(jwtVerify).mockReset();
    process.env.JWT_ACCESS_SECRET = 'test-jwt-secret-do-not-use-in-prod';
  });

  it('should redirect to /login when no cookie is present', async () => {
    const res = await middleware(makeRequest({ pathname: '/dashboard' }));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/login');
    expect(jwtVerify).not.toHaveBeenCalled();
  });

  it('should redirect to /login when cookie has invalid JWT', async () => {
    vi.mocked(jwtVerify).mockRejectedValueOnce(new Error('bad sig'));
    const res = await middleware(
      makeRequest({ pathname: '/dashboard', token: 'garbage' }),
    );
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/login');
  });

  it('should redirect to /login when JWT verifies but isAdmin=false', async () => {
    vi.mocked(jwtVerify).mockResolvedValueOnce({
      payload: { sub: 'u1', isAdmin: false },
      protectedHeader: { alg: 'HS256' },
    } as never);
    const res = await middleware(
      makeRequest({ pathname: '/dashboard', token: 'valid-non-admin' }),
    );
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/login');
  });

  it('should call next() (no redirect) when valid admin JWT present', async () => {
    vi.mocked(jwtVerify).mockResolvedValueOnce({
      payload: { sub: 'u1', isAdmin: true },
      protectedHeader: { alg: 'HS256' },
    } as never);
    const res = await middleware(
      makeRequest({ pathname: '/dashboard', token: 'valid-admin' }),
    );
    // NextResponse.next() returns 200-ish with no location redirect header.
    expect(res.headers.get('location')).toBeNull();
    expect(res.status).toBe(200);
  });

  it('should bypass auth check for /login itself', async () => {
    const res = await middleware(makeRequest({ pathname: '/login' }));
    expect(res.headers.get('location')).toBeNull();
    expect(jwtVerify).not.toHaveBeenCalled();
  });
});
