# Admin panel audit — 2026-05-06

## Test environment notes

- The Next.js process running on `localhost:3000` at audit start was a **different project** (`/Users/latifrjdev/Desktop/magaznov`, Next.js 16.2.4), **not** the DukonPro admin. Backend on `:4455` is correct (DukonPro NestJS).
- Started DukonPro admin (`admin/` folder) on `localhost:3001` with `JWT_ACCESS_SECRET` set from `api/.env`, `NEXT_PUBLIC_API_URL=http://localhost:4455/api`, `API_INTERNAL_URL=http://localhost:4455/api`. Audit was run against `:3001`.
- Admin user (phone `+992000000000` / `admin123`) logged in successfully and received an HttpOnly `token` cookie.

## Summary

- Pages discovered: 11 (incl. dynamic detail routes)
- PASS: 11, AUTH_ISSUE: 0, SERVER_ERROR: 0, CLIENT_ERROR: 0 (HTML render only — see critical finding below)
- Critical findings:
  - **P0 / blocker — admin frontend cannot fetch any data in a browser.** Backend extracts JWT only from the `Authorization: Bearer …` header (`api/src/modules/auth/strategies/jwt-access.strategy.ts` uses `ExtractJwt.fromAuthHeaderAsBearerToken()`). The admin login route stores the token in an `HttpOnly` cookie named `token` on the **Next.js origin** (`localhost:3001`); the admin browser client (`admin/lib/api.ts`) calls the **backend origin** (`localhost:4455`) with `credentials: 'include'`. Result: a) the cookie is cross-origin and SameSite=Strict so it isn't sent anyway, b) even if it were sent, the backend wouldn't read it. Reproduced: `GET /api/admin/users` with the cookie returns **401 "Invalid or expired token"**; only `Authorization: Bearer` returns 200. This means **every list page, every dashboard widget, every destructive-action mutation will fail with 401** in a real browser, and the api wrapper then redirects to `/login` — making the admin panel functionally unusable end-to-end. The HTML pages render (200) because the data fetches happen client-side and don't fail until hydration.
  - **P3 / housekeeping — Next.js deprecation warning at admin boot:** `The "middleware" file convention is deprecated. Please use "proxy" instead. Learn more: https://nextjs.org/docs/messages/middleware-to-proxy`. The whole admin auth gate at `admin/middleware.ts` will need to migrate.
  - **P3 — `admin/.env` ships placeholders.** `JWT_ACCESS_SECRET=` is empty and `API_INTERNAL_URL=` is empty. Without overrides the admin process would never verify tokens (middleware silently redirects everyone to `/login`). Worth a startup assertion (`throw if !JWT_ACCESS_SECRET`) and a developer setup note.

## Findings by route

All HTTP/SIZE values come from authenticated curl with the admin cookie. "ERR" counts matches against `Cannot read|Objects are not valid|TypeError|ReferenceError|Application error|something went wrong|Internal Server Error|Unhandled` in the rendered HTML.

### `/` (root)
- HTTP 307 → `/dashboard` (server-side `redirect('/dashboard')` at `admin/app/page.tsx`).

### `/login`
- HTTP 200, login form renders, submission works against `/api/auth/login` proxy.
- Unauthenticated requests to any other route are correctly redirected to `/login` (HTTP 307) by `admin/middleware.ts`. Bad/forged token cookies also redirect.

### `/dashboard`
- HTTP 200, ~45 KB, no error markers. Backend `/admin/dashboard` returns `{totalUsers:3, totalStores:3, subscriptionsByStatus:{ACTIVE:1,TRIAL:1,PAST_DUE:1}, ...}`.
- `/admin/revenue` returns `[]` and `/admin/dashboard/registrations` returns 1-row series; both HTTP 200.

### `/users`
- HTTP 200, ~39 KB, no error markers.
- Backend `/admin/users` returns envelope `{data:[3 items], total:3, page:1, limit:50}`. The page reads `r.data ?? []` which matches the envelope shape.

### `/users/:id`
- HTTP 200 for a real user (`90a2085b-…`) and for the admin user (`bf774704-…`), ~26 KB, no error markers.

### `/stores`
- HTTP 200, ~43 KB, no error markers.
- Backend `/admin/stores` returns envelope `{data:[3 items], ...}`. Stores list confirmed populated (Test Shop + 2 seed stores).

### `/stores/:id`
- HTTP 200 for `3561d14d-…` (Test Shop), ~26 KB, no error markers. Backed by `GET /admin/stores/:id` and `GET /admin/stores/:id/subscription`.

### `/subscriptions`
- HTTP 200, ~42 KB, no error markers.
- `/admin/subscriptions` returns plain array (3 items). `/admin/subscriptions/pending-payments` returns plain array (1 pending payment seeded). Both 200.

### `/subscriptions/plans`
- HTTP 200, ~26 KB, no error markers.
- `/admin/plans` returns 3 plan rows (`START`, `STANDARD`, `PREMIUM`).

### `/announcements`
- HTTP 200, ~38 KB, no error markers.
- `/admin/announcements` returns `{data:[1 item: "Добро пожаловать!"], ...}`.

### `/audit-log`
- HTTP 200, ~37 KB, no error markers.
- `/admin/audit-log?limit=5` returns `{data:[], total:0, page:1, limit:5}` — empty (no audit rows seeded).

## Destructive action handlers (verified by route-file inspection only — no mutations performed)

All handlers below exist in `api/src/modules/admin/*` or `api/src/modules/subscriptions/subscriptions.controller.ts`. None were exercised against real resources — verification was via reading the `@Controller`/`@Get`/`@Put`/`@Post`/`@Delete` decorators in the source.

User actions — `api/src/modules/admin/admin-users.controller.ts`:
- `PUT /admin/users/:id/block` — block user (sets `isActive=false`)
- `PUT /admin/users/:id/unblock`
- `PUT /admin/users/:id/toggle-admin`
- `DELETE /admin/users/:id`
- `GET /admin/users`, `GET /admin/users/:id`, `GET /admin/users/:id/stores`

Store actions — `api/src/modules/admin/admin-stores.controller.ts`:
- `PUT /admin/stores/:id/suspend`
- `PUT /admin/stores/:id/unsuspend`
- `PUT /admin/stores/:id/transfer` (body `{userId}`)
- `GET /admin/stores`, `GET /admin/stores/:id`, `GET /admin/stores/:id/subscription`

Subscription/billing actions — `api/src/modules/subscriptions/subscriptions.controller.ts` (`@Controller('admin/subscriptions')`):
- `PUT /admin/subscriptions/:id/approve-payment/:paymentId`
- `PUT /admin/subscriptions/:id/reject-payment/:paymentId` (body `{reason}`)
- `PUT /admin/subscriptions/:id/cancel`
- `PUT /admin/subscriptions/:id/extend` (body `{days}`)
- `PUT /admin/subscriptions/:id/change-plan` (body `{planId}`)
- `PUT /admin/subscriptions/:id/set-discount` (body `{percent}`)
- `GET /admin/subscriptions`, `GET /admin/subscriptions/pending-payments`

Plans — `api/src/modules/admin/admin-plans.controller.ts`:
- `PUT /admin/plans/:plan`
- `GET /admin/plans`

Announcements — `api/src/modules/admin/admin-announcements.controller.ts`:
- `POST /admin/announcements`
- `POST /admin/announcements/preview`
- `GET /admin/announcements`

Dashboard/audit (read-only):
- `GET /admin/dashboard`, `GET /admin/dashboard/registrations`, `GET /admin/revenue`
- `GET /admin/audit-log`

All destructive endpoints are also wired from the admin frontend (verified via grep on `api.put|api.post|api.delete` in `admin/app/**`). Per the bug above, **none of those mutations will actually succeed in a real browser session** until the auth-bridge is fixed.

## Recommended fix for the P0

Two reasonable options:
1. **Make the API also accept the cookie.** Add a cookie extractor to `JwtAccessStrategy` (e.g. `ExtractJwt.fromExtractors([cookieExtractor, ExtractJwt.fromAuthHeaderAsBearerToken()])`) and have the API enable `cookie-parser` + ensure CORS keeps `credentials: true` and the cookie's `SameSite` is `Lax`/`None` for cross-origin from `:3001` → `:4455`.
2. **Proxy every admin call through the Next.js server.** Replace `admin/lib/api.ts` `fetch(API_URL + path)` with `fetch('/api/proxy' + path)` and add a proxy route handler that reads the `token` cookie server-side and forwards it as `Authorization: Bearer …`. This keeps the token entirely server-side and out of the browser, matching the security posture stated in the login route's comment ("Admin #1").

Option 2 is more consistent with the rest of the admin code (login is already proxied) and with the codebase's `security.md` rule about not exposing tokens to JS.

## Files referenced

- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/admin/middleware.ts`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/admin/app/api/auth/login/route.ts`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/admin/app/login/page.tsx`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/admin/app/page.tsx`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/admin/lib/api.ts`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/admin/app/(admin)/users/page.tsx` (and other 7 page files under `app/(admin)/`)
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/auth/strategies/jwt-access.strategy.ts`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/admin/admin-*.controller.ts`
- `/Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/subscriptions/subscriptions.controller.ts`
