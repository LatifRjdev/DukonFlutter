// Shared auth helpers for k6 load scenarios.
// Import with: import { login, authHeaders } from './lib/auth.js';
import http from 'k6/http';
import { check } from 'k6';

/**
 * POST /api/auth/login and return the accessToken.
 * Calls check() so k6 tracks this request in metrics.
 * Throws (via check failure) if login returns non-200.
 */
export function login(baseUrl, phone, password) {
  const res = http.post(
    `${baseUrl}/api/auth/login`,
    JSON.stringify({ phone, password }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(res, { 'setup: login 200': (r) => r.status === 200 });
  return JSON.parse(res.body).accessToken;
}

/**
 * Returns a k6 params object with Authorization + Content-Type headers.
 * Pass as the third argument to any http.* call that needs auth.
 */
export function authHeaders(token) {
  return {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
  };
}
