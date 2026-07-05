/**
 * Scenario 02 — Reports read-heavy
 *
 * 20 VUs each hitting 3 report endpoints (sales, profit, products) in a loop.
 * Duration: 5 min. Threshold: p(95) < 800ms.
 *
 * Required env vars:
 *   K6_BASE_URL          Default: http://localhost:4455
 *   K6_OWNER_PHONE       Default: +992900000001
 *   K6_OWNER_PASSWORD    Default: password123
 *   K6_QA_STORE_ID       Required: UUID of the store to test against
 */
import http from 'k6/http';
import { check, sleep } from 'k6';
import { login, authHeaders } from './lib/auth.js';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  vus: 20,
  duration: '5m',
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.02'],
  },
};

export function setup() {
  const phone = __ENV.K6_OWNER_PHONE || '+992900000001';
  const password = __ENV.K6_OWNER_PASSWORD || 'password123';
  const storeId = __ENV.K6_QA_STORE_ID;
  if (!storeId) {
    throw new Error('K6_QA_STORE_ID env var is required');
  }
  const token = login(BASE_URL, phone, password);
  return { token, storeId };
}

export default function (data) {
  const { token, storeId } = data;
  const headers = authHeaders(token);
  const query = '?startDate=2026-01-01&endDate=2026-12-31';
  const base = `${BASE_URL}/api/stores/${storeId}/reports`;

  const salesRes = http.get(`${base}/sales${query}`, headers);
  check(salesRes, { 'reports/sales 200': (r) => r.status === 200 });

  const profitRes = http.get(`${base}/profit${query}`, headers);
  check(profitRes, { 'reports/profit 200': (r) => r.status === 200 });

  const productsRes = http.get(`${base}/products${query}`, headers);
  check(productsRes, { 'reports/products 200': (r) => r.status === 200 });

  sleep(0.5);
}
