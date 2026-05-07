import { NextRequest, NextResponse } from 'next/server';

// Server-side reverse proxy for the admin panel.
//
// Browser fetch to /api/proxy/<anything> -> this handler -> backend API
// at /api/<anything>. We attach Authorization: Bearer <token> using the
// HttpOnly admin-session cookie that login set, because the backend's
// JwtAccessStrategy reads the token only from the Authorization header,
// not from cookies. Without this proxy, every client-side admin fetch
// returns 401 in a real browser.
//
// Closes P0 from qa/2026-05-06-admin-audit.md.

const API_URL =
  process.env.API_INTERNAL_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  'http://localhost:4455/api';

const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  // Don't forward host — upstream sees its own origin.
  'host',
  // Don't forward client cookies — we replace with Bearer.
  'cookie',
  // Length is recomputed by fetch.
  'content-length',
]);

function buildHeaders(req: NextRequest, token: string | undefined): Headers {
  const out = new Headers();
  req.headers.forEach((value, key) => {
    if (!HOP_BY_HOP.has(key.toLowerCase())) {
      out.set(key, value);
    }
  });
  if (token) {
    out.set('Authorization', `Bearer ${token}`);
  }
  return out;
}

async function handle(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
): Promise<NextResponse> {
  const { path = [] } = await ctx.params;
  const subPath = path.join('/');

  // Preserve query string from the incoming request.
  const incomingUrl = new URL(req.url);
  const upstreamUrl = `${API_URL}/${subPath}${incomingUrl.search}`;

  const token = req.cookies.get('token')?.value;

  // GET/HEAD/DELETE shouldn't have a body; everything else streams the body
  // as-is. Setting `duplex: 'half'` lets Node fetch send a streaming body.
  const method = req.method.toUpperCase();
  const hasBody = !['GET', 'HEAD', 'DELETE'].includes(method);
  const init: RequestInit & { duplex?: 'half' } = {
    method,
    headers: buildHeaders(req, token),
    redirect: 'manual',
  };
  if (hasBody) {
    init.body = req.body;
    init.duplex = 'half';
  }

  let upstream: Response;
  try {
    upstream = await fetch(upstreamUrl, init);
  } catch (err) {
    return NextResponse.json(
      { message: 'Bad gateway', error: String(err) },
      { status: 502 },
    );
  }

  // Pass body and status through; strip hop-by-hop headers on the way back.
  const respHeaders = new Headers();
  upstream.headers.forEach((value, key) => {
    if (!HOP_BY_HOP.has(key.toLowerCase())) {
      respHeaders.set(key, value);
    }
  });

  return new NextResponse(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: respHeaders,
  });
}

export const GET = handle;
export const HEAD = handle;
export const POST = handle;
export const PUT = handle;
export const PATCH = handle;
export const DELETE = handle;
