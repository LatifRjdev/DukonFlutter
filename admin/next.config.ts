import type { NextConfig } from "next";

const apiBase = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4455/api';
const apiOrigin = new URL(apiBase).origin;

// Content Security Policy.
// - default-src 'self' locks down loads to same-origin by default.
// - script-src allows inline for Next.js runtime hydration; unsafe-eval
//   is omitted so React dev-mode eval is blocked (OK in production).
// - style-src permits inline for shadcn/Tailwind runtime styles.
// - img-src allows https: + data: so uploaded receipts and avatar URLs
//   from any backend bucket render.
// - connect-src includes the API origin and the Sentry ingest host so
//   fetch() + error reports work.
// - frame-ancestors 'none' prevents clickjacking.
const csp = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: https:",
  "font-src 'self' data:",
  `connect-src 'self' ${apiOrigin} https://*.sentry.io https://*.ingest.sentry.io https://*.ingest.de.sentry.io https://*.ingest.us.sentry.io`,
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join('; ');

const securityHeaders = [
  { key: 'Content-Security-Policy', value: csp },
  { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
];

const nextConfig: NextConfig = {
  output: 'standalone',
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};

export default nextConfig;
