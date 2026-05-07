// Browser calls go through /api/proxy/<path>, a same-origin Next.js
// route handler that reads the HttpOnly admin-session cookie and
// re-issues the upstream request with `Authorization: Bearer <token>`.
// The backend's JwtAccessStrategy only reads the Authorization header,
// not cookies — without this proxy, every fetch returns 401.
//
// Closes P0 from qa/2026-05-06-admin-audit.md.
async function apiFetch(path: string, options?: RequestInit) {
  // path is something like "/admin/users" (with leading slash). The
  // proxy mount point is "/api/proxy" and the catch-all expects the
  // remainder without a leading slash, so trim it.
  const trimmed = path.startsWith('/') ? path.slice(1) : path;
  // Resolve to an absolute URL when a window origin is available.
  // Production browsers accept relative URLs in fetch(), but jsdom-based
  // tests + the @mswjs/interceptors fetch wrapper require an absolute URL.
  const origin =
    typeof window !== 'undefined' && window.location?.origin
      ? window.location.origin
      : '';
  const url = `${origin}/api/proxy/${trimmed}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });
  if (res.status === 401) {
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
    throw new Error('Unauthorized');
  }
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.message || `HTTP ${res.status}`);
  }
  return res.json();
}

export const api = {
  get: (path: string) => apiFetch(path),
  post: (path: string, body: unknown) =>
    apiFetch(path, { method: 'POST', body: JSON.stringify(body) }),
  put: (path: string, body?: unknown) =>
    apiFetch(path, { method: 'PUT', body: body ? JSON.stringify(body) : undefined }),
  delete: (path: string) => apiFetch(path, { method: 'DELETE' }),
};
