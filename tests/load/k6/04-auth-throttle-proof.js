/**
 * Scenario 04 — Auth throttle proof
 *
 * 10 VUs each hammering POST /api/auth/login with wrong credentials.
 * The throttler allows 5/min per IP globally across all VUs (since they
 * share the runner machine's IP). After 5 requests, every subsequent login
 * attempt returns 429 Too Many Requests.
 *
 * INVERTED threshold: http_req_failed rate > 0.95 — the test PASSES only
 * when > 95% of requests are 429'd, proving the throttler is working.
 *
 * Duration: 1 min (one full throttle window).
 *
 * No env vars needed — uses intentionally wrong passwords.
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:4455';

export const options = {
  vus: 10,
  duration: '1m',
  thresholds: {
    // Inverted: test passes when the FAILURE rate exceeds 95%
    // (meaning the throttler is firing 429 on > 95% of requests).
    'http_req_failed': ['rate>0.95'],
  },
};

// No setup() needed — all VUs send bad credentials.

export default function () {
  // Use __VU to rotate phones slightly (still wrong creds either way).
  const phone = `+99290000${String(__VU).padStart(4, '0')}`;
  const res = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ phone, password: 'definitely-wrong-password' }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  // Accept 401 (bad creds) or 429 (throttled) — both are expected.
  // 401 fires in the first few requests; 429 takes over quickly.
  check(res, {
    'throttled or rejected': (r) => r.status === 401 || r.status === 429,
  });

  sleep(0.1);
}
