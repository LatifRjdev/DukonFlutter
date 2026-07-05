/**
 * Scenario 01 — POS happy path
 *
 * Simulates a cashier completing a full sale + refund cycle.
 * Ramp: 0 → 100 VU over 2 min, hold 3 min, ramp down 30s.
 * Thresholds: p(95) < 500ms, error rate < 1%.
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
  stages: [
    { duration: '2m', target: 100 },
    { duration: '3m', target: 100 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
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

  // Fetch first page of products to get real product IDs.
  const productsRes = http.get(
    `${BASE_URL}/api/stores/${storeId}/products?take=10`,
    authHeaders(token),
  );
  check(productsRes, { 'setup: products 200': (r) => r.status === 200 });

  const products = JSON.parse(productsRes.body).data || [];
  if (products.length < 3) {
    throw new Error(
      `Need at least 3 active products in store ${storeId}, found ${products.length}`,
    );
  }

  return {
    token,
    storeId,
    productIds: products.slice(0, 3).map((p) => p.id),
  };
}

export default function (data) {
  const { token, storeId, productIds } = data;
  const headers = authHeaders(token);

  // Step 1: List products (simulates cashier browsing/searching)
  const productsRes = http.get(
    `${BASE_URL}/api/stores/${storeId}/products?take=20`,
    headers,
  );
  check(productsRes, { 'products list 200': (r) => r.status === 200 });

  // Step 2: Create a 3-item cash sale
  const saleBody = JSON.stringify({
    paymentType: 'CASH',
    paidAmount: 9999,
    localId: `k6-vu${__VU}-iter${__ITER}`,
    items: productIds.map((id) => ({ productId: id, quantity: 1 })),
  });
  const saleRes = http.post(
    `${BASE_URL}/api/stores/${storeId}/sales`,
    saleBody,
    headers,
  );
  check(saleRes, { 'sale create 201': (r) => r.status === 201 });

  if (saleRes.status !== 201) {
    sleep(1);
    return;
  }

  const sale = JSON.parse(saleRes.body);

  // Step 3: Refund the first item
  const refundBody = JSON.stringify({
    items: [{ saleItemId: sale.items[0].id, quantity: 1 }],
    reason: 'k6 load test refund',
  });
  const refundRes = http.post(
    `${BASE_URL}/api/stores/${storeId}/sales/${sale.id}/refund`,
    refundBody,
    headers,
  );
  check(refundRes, { 'refund 2xx': (r) => r.status >= 200 && r.status < 300 });

  // Step 4: Logout (simulates end of shift)
  const logoutRes = http.post(
    `${BASE_URL}/api/auth/logout`,
    null,
    headers,
  );
  check(logoutRes, { 'logout 200': (r) => r.status === 200 });

  sleep(1);
}
