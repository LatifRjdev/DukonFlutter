const SENSITIVE_KEYS = new Set([
  'password',
  'currentpassword',
  'oldpassword',
  'newpassword',
  'phone',
  'token',
  'accesstoken',
  'refreshtoken',
  'authorization',
  'cardnumber',
  'cvv',
  'otp',
  'code',
]);

const PLACEHOLDER = '[Filtered]';

function scrubObject(obj: unknown): void {
  if (!obj || typeof obj !== 'object') return;
  const rec = obj as Record<string, unknown>;
  for (const key of Object.keys(rec)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) {
      rec[key] = PLACEHOLDER;
      continue;
    }
    if (rec[key] && typeof rec[key] === 'object') {
      scrubObject(rec[key]);
    }
  }
}

export function scrubEventPii(event: {
  request?: { data?: unknown; headers?: unknown };
  extra?: unknown;
}): void {
  if (event.request?.data) scrubObject(event.request.data);
  if (event.request?.headers) scrubObject(event.request.headers);
  if (event.extra) scrubObject(event.extra);
}
