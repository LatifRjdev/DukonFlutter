/**
 * Scenario 03 — Admin bulk approve
 *
 * 5 VUs each calling approve-payment 30 times sequentially.
 * The endpoint is idempotent — approving the same payment twice returns
 * the already-approved state without error. This tests $transaction +
 * audit log write throughput under burst admin ops.
 *
 * Threshold: p(95) < 300ms.
 *
 * Required env vars:
 *   K6_BASE_URL            Default: http://localhost:4455
 *   K6_ADMIN_PHONE         Default: +992900000099
 *   K6_ADMIN_PASSWORD      Default: admin123
 *   K6_SUB_ID              Required: subscription UUID with a PENDING payment
 *   K6_PAYMENT_ID          Required: payment UUID to approve (PENDING or already APPROVED)
 */
import http from 'k6/http';
import { check } from 'k6';
import { login, authHeaders } from './lib/auth.js';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  vus: 5,
  duration: '2m',
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.05'],
  },
};

export function setup() {
  const phone = __ENV.K6_ADMIN_PHONE || '+992900000099';
  const password = __ENV.K6_ADMIN_PASSWORD || 'admin123';
  const subId = __ENV.K6_SUB_ID;
  const paymentId = __ENV.K6_PAYMENT_ID;
  if (!subId || !paymentId) {
    throw new Error('K6_SUB_ID and K6_PAYMENT_ID env vars are required');
  }
  const token = login(BASE_URL, phone, password);
  return { token, subId, paymentId };
}

export default function (data) {
  const { token, subId, paymentId } = data;
  const headers = authHeaders(token);

  // 30 sequential approve calls (matches spec: 30 per VU)
  for (let i = 0; i < 30; i++) {
    const res = http.put(
      `${BASE_URL}/api/admin/subscriptions/${subId}/approve-payment/${paymentId}`,
      null,
      headers,
    );
    // 200 on first approve, 200 on subsequent (idempotent)
    check(res, { 'approve 200': (r) => r.status === 200 });
  }
}
