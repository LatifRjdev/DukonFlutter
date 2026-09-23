import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import { createServer, type Server } from 'node:http';
import { gzipSync } from 'node:zlib';
import type { NextRequest } from 'next/server';

// route.ts reads API_INTERNAL_URL into a top-level const at module import
// time, so this test sets the env var and re-imports the module fresh
// (vi.resetModules) rather than importing it at the top of the file —
// otherwise it would already be bound to whatever URL was set before this
// test file ran.
function makeProxyRequest(): NextRequest {
  const headers = new Headers({ 'content-type': 'application/json' });
  return {
    url: 'http://localhost:3000/api/proxy/some/path',
    method: 'GET',
    headers,
    cookies: {
      get: (name: string) =>
        name === 'token' ? { name, value: 'fake-token' } : undefined,
    },
  } as unknown as NextRequest;
}

describe('admin proxy route: content-encoding handling', () => {
  let upstream: Server;
  let upstreamUrl: string;
  const payload = { hello: 'world', items: [1, 2, 3] };

  beforeAll(async () => {
    upstream = createServer((_req, res) => {
      const body = gzipSync(Buffer.from(JSON.stringify(payload)));
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Content-Encoding': 'gzip',
      });
      res.end(body);
    });
    await new Promise<void>((resolve) => upstream.listen(0, resolve));
    const address = upstream.address();
    if (address && typeof address === 'object') {
      upstreamUrl = `http://localhost:${address.port}`;
    }
  });

  afterAll(() => {
    upstream.close();
    delete process.env.API_INTERNAL_URL;
  });

  it('does not forward a stale content-encoding header for an already-decompressed body', async () => {
    process.env.API_INTERNAL_URL = upstreamUrl;
    vi.resetModules();
    const { GET } = await import('./route');

    const res = await GET(makeProxyRequest(), {
      params: Promise.resolve({ path: ['some', 'path'] }),
    });

    expect(res.headers.get('content-encoding')).toBeNull();
    const body = await res.json();
    expect(body).toEqual(payload);
  });
});
