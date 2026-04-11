# Backend Static Audit Findings — 2026-04-10

Scope: static, read-only audit of the NestJS + Prisma backend at
`/Users/latifrjdev/Downloads/Dukon/api` — 80 HTTP routes across 16
controllers / 15 feature modules.

## Summary

- Total findings: 28 (P0: 4, P1: 8, P2: 9, P3: 7)
- Modules audited: 15 (auth, stores, products, categories, customers,
  suppliers, sales, expenses, finances, zakat, staff, payroll, shifts,
  roles, users) — all present in `app.module.ts`.
- Controllers: 16 (`products/` has two: `products.controller.ts` and
  `stock-movements.controller.ts`).
- Total routes (grep of `@Get|@Post|@Put|@Patch|@Delete`): 80 — matches
  scope. Every route that reads or writes store-scoped data is mounted
  under a controller decorated with `@UseGuards(JwtAuthGuard,
  StoreAccessGuard)`, so on paper **80 / 80** routes are guarded.
  However, several are effectively guard-bypassable because of the
  issues listed in P0/P1 below (e.g. `/auth/register` self-service of a
  user whose phone already belongs to a staff record — see P0-BE-001).
- `ValidationPipe` is enabled globally in `main.ts` with `whitelist`,
  `forbidNonWhitelisted`, and `transform` — good baseline. DTO coverage
  is broadly OK (44 DTO files, 311 class-validator decorators).

---

## P0 Findings (Blockers / Security)

### [P0-BE-001] Staff creation auto-provisions a User with password == phone number
- **File:** `api/src/modules/staff/staff.service.ts:12-28`
- **Description:** When `POST /stores/:storeId/staff` is called with a
  phone number that does not yet belong to any user, the service
  silently creates a new `User` record and uses the phone number
  itself as the password (after bcrypt). Because phone numbers are
  public/semi-public and guessable, anyone who later calls
  `POST /auth/login` with that phone and the phone as the password
  gains full authenticated access to the newly-created account.
  ```ts
  // staff.service.ts:19-28
  if (!user) {
    const hashedPassword = await bcrypt.hash(dto.phone, 12);
    user = await this.prisma.user.create({
      data: { phone: dto.phone, name: dto.name, password: hashedPassword },
    });
  }
  ```
  The compromised account can then be added as staff/owner of other
  stores, query store data via any `/stores/:storeId/*` endpoint
  (subject only to `StoreAccessGuard` which accepts any active staff
  record), and the legitimate owner of that phone number has no way
  to learn the account was created.
- **Impact:** Account takeover by anyone who knows a target's Tajik
  mobile number. Any owner can coerce unwitting users into "staff"
  accounts, then pivot from those accounts once the target registers.
- **Recommended fix:** Never set password = phone. Either (a) generate
  a cryptographically-random temporary password and deliver it
  out-of-band / force-reset on first login, or (b) create a `Staff`
  record in an `INVITED` state with a short-lived, single-use
  invitation token (no `User` row yet), and only provision the user
  when the invitee accepts through `/auth/register` or an
  `/auth/accept-invite` flow. Add a regression test.

### [P0-BE-002] JWT secrets fall back to hard-coded dev strings
- **File:** `api/src/modules/auth/auth.service.ts:101,108`;
  `api/src/modules/auth/strategies/jwt-access.strategy.ts:16`;
  `api/src/modules/auth/strategies/jwt-refresh.strategy.ts:16`
- **Description:** Every place JWTs are signed or verified uses the
  two-argument form of `ConfigService.get`, which returns the default
  when the env var is missing:
  ```ts
  this.configService.get<string>('JWT_ACCESS_SECRET', 'access-secret-dev')
  this.configService.get<string>('JWT_REFRESH_SECRET', 'refresh-secret-dev')
  ```
  If `JWT_ACCESS_SECRET` or `JWT_REFRESH_SECRET` is ever empty,
  missing, or typo'd in a production `.env`, the app silently signs
  and verifies tokens with `access-secret-dev` / `refresh-secret-dev`.
  Anyone on the internet can then mint valid JWTs for any user. The
  strings are also committed to source, so the "secret" is world-known
  the moment this code ships.
- **Impact:** Total authentication bypass in any deployment that loses
  the env vars (Docker restart with stale `.env`, missing CI secret,
  etc.).
- **Recommended fix:** Fail fast on boot if `JWT_ACCESS_SECRET` or
  `JWT_REFRESH_SECRET` is missing or shorter than 32 bytes. Load via a
  typed config with `joi`/`zod` validation in `ConfigModule.forRoot`,
  and remove the literal defaults. Rotate any secrets that were ever
  shipped.

### [P0-BE-003] `/auth/register` has no rate limit
- **File:** `api/src/modules/auth/auth.controller.ts:17-21` (compare
  to `login` at line 23 which has `@Throttle({ default: { limit: 5,
  ttl: 60000 }})`).
- **Description:** Only `POST /auth/login` is throttled. `POST
  /auth/register` and `POST /auth/refresh` fall back to the global
  `ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }])` in
  `app.module.ts:26` — 100 requests / 60s from a single IP. There is
  no uniqueness / cooldown on `phone`, so an attacker can enumerate
  phone registration state (409 vs 201) and flood store creation at
  100 rpm per IP, 6000 rpm via a /24. Combined with P0-BE-001 the
  impact is worse: an attacker can register a victim's phone, lock
  them out, and then own any stores they create.
- **Impact:** Phone enumeration, brute-force registration, account
  squatting, Denial-of-service of the onboarding flow.
- **Recommended fix:** Add `@Throttle({ default: { limit: 3, ttl:
  60000 }})` to `register` and `refresh`. Consider a per-phone limiter
  keyed on Redis rather than IP. When `register` sees an existing
  phone, return the same generic response regardless of outcome
  (don't leak 409 vs 201).

### [P0-BE-004] Global error filter always serialises raw exception messages
- **File:** `api/src/common/filters/http-exception.filter.ts:23-44`
- **Description:** The `AllExceptionsFilter` copies
  `exception.getResponse().message` straight into the response body
  regardless of environment. This is safe for `HttpException`, but for
  non-HTTP exceptions (e.g. Prisma `PrismaClientKnownRequestError`,
  unhandled `TypeError`) the code still treats the value like an
  `HttpException`, and the logger call on line 33-36 logs
  `exception.stack` in server logs — combined with the JSON response
  shape (`timestamp`, `path`), any 500 response includes the request
  path in clear text. There is no `NODE_ENV === 'production'` guard
  that redacts the message, and there is no handler for Prisma
  unique-constraint / foreign-key errors, so those surface as raw
  strings like `"Unique constraint failed on the fields: (`phone`)"`.
- **Impact:** Information disclosure — database column names, table
  structure, Prisma internals, and full stack traces leak to API
  consumers on any unhandled exception. Helps attackers map the
  schema for follow-on attacks.
- **Recommended fix:** In production, replace the body `message` with
  a generic string for status >= 500; map known Prisma errors to
  `ConflictException` / `NotFoundException` in each service or a
  dedicated `PrismaExceptionFilter`; never echo internal messages on
  status 500.

---

## P1 Findings

### [P1-BE-001] Refresh token rotation is best-effort, not guaranteed
- **File:** `api/src/modules/auth/auth.service.ts:72-80`
- **Description:** `refresh()` calls
  `prisma.refreshToken.deleteMany({ where: { token: oldTokenId }})`
  and then issues a fresh pair. There is no transaction wrapping the
  delete and the new insert, so a failure between `deleteMany` and
  `generateTokens` leaves the user with zero refresh tokens. More
  importantly, there is **no replay detection**: if an attacker
  captures a refresh token and calls `/auth/refresh` once, the legit
  user's next refresh silently returns a new token — there is no
  detection that the same `jti` was used twice before the rotation
  happened, nor any family-invalidation on replay.
- **Impact:** Refresh-token theft is undetectable; stolen tokens stay
  valid for up to 30 days (see next finding).
- **Recommended fix:** Wrap delete + create in `prisma.$transaction`.
  On `refresh`, if the `jti` is not found but its family is still
  valid, invalidate the entire family for that user and force
  re-login.

### [P1-BE-002] Refresh token expiry 30 days, no revocation on logout of other devices
- **File:** `api/src/modules/auth/auth.service.ts:109, 82-92`;
  `api/prisma/schema.prisma:30-40`
- **Description:** Refresh expiry defaulted to `30d`, which is long
  for a POS tenant handling cash. `logout(userId)` deletes **all**
  refresh tokens for the user (global logout), but there is no
  per-device logout and no UI surface to see active sessions. There
  is also no deny-list for access tokens — a stolen 15-minute access
  token is valid until expiry because the `JwtAccessStrategy` only
  verifies signature + `isActive`, not token revocation.
- **Recommended fix:** Reduce refresh expiry to 7 days or gate
  long-lived tokens behind "remember me". Track `deviceId` on
  `RefreshToken`, expose a session-management endpoint, and add a
  short-lived Redis deny-list for revoked access tokens.

### [P1-BE-003] No password complexity requirements beyond length 6
- **File:** `api/src/modules/auth/dto/register.dto.ts:17-19`;
  `api/src/modules/users/dto/change-password.dto.ts:5-13`
- **Description:** `@MinLength(6)` is the only constraint on
  passwords. `000000`, `123456`, and the user's own phone all pass.
  Security rule `.claude/rules/security.md` specifies minimum 6 chars
  which is met, but given P0-BE-001 the weak floor is compounded.
- **Recommended fix:** Require 8+ chars, at least one letter and one
  digit, and reject top-1000 common passwords. Consider `zxcvbn`.

### [P1-BE-004] `StoreAccessGuard` only checks active-staff flag, not role scope
- **File:** `api/src/common/guards/store-access.guard.ts:26-39`;
  `api/src/common/guards/permissions.guard.ts`
- **Description:** `StoreAccessGuard` passes any user who either owns
  the store or has `staff.isActive === true` — regardless of role.
  `PermissionsGuard` exists (`permissions.guard.ts`) and reads a
  `@Permissions()` decorator, but `grep` for `@Permissions(` across
  `src/modules/**/*.controller.ts` returns **zero** hits. This means
  the RBAC layer described in the schema (`RolePermission`, role-level
  permissions) is effectively unused: a `CASHIER` can hit every
  `PUT`/`DELETE` on products, staff, payroll, finances, roles — the
  only routes they're shut out of are the `/users/me/*` ones under a
  different controller.
- **Impact:** Privilege escalation inside a store — any active staff
  member can wipe inventory, edit prices, delete other staff,
  re-configure roles, and modify payroll.
- **Recommended fix:** Apply `PermissionsGuard` globally alongside
  `StoreAccessGuard`, decorate every mutating endpoint with
  `@Permissions('products.write')` etc., and change the "if no
  permissions configured for this role, allow by default" behaviour
  in `permissions.guard.ts:67-69` to deny-by-default.

### [P1-BE-005] CORS falls back to wildcard with credentials
- **File:** `api/src/main.ts:28-31`
- **Description:**
  ```ts
  app.enableCors({
    origin: configService.get<string>('CORS_ORIGIN', '*'),
    credentials: true,
  });
  ```
  When `CORS_ORIGIN` is unset, the app sends
  `Access-Control-Allow-Origin: *` **and**
  `Access-Control-Allow-Credentials: true`. Browsers reject that
  combination for credentialed requests, but some reverse proxies
  normalise it and any non-browser client will happily use it.
  `.env.example` does not define `CORS_ORIGIN`, so the fallback is
  the de-facto prod default.
- **Recommended fix:** Default to the empty string or a known
  production origin and refuse to boot in production if
  `CORS_ORIGIN` contains `*`. Add `CORS_ORIGIN` to `.env.example`.

### [P1-BE-006] Helmet mounted with defaults, no CSP/HSTS override
- **File:** `api/src/main.ts:23`
- **Description:** `app.use(helmet())` uses defaults. For a JSON API
  that serves Swagger under `/api/docs`, defaults are OK, but there
  is no explicit `Content-Security-Policy`, no `Strict-Transport-
  Security` override, and no `crossOriginResourcePolicy` setting.
  `Swagger` at `/api/docs` may break under strict CSP, so setting
  this up requires thought.
- **Recommended fix:** Pass an explicit helmet config, enable HSTS
  with `maxAge: 15552000`, and disable Swagger in production or
  gate it behind auth.

### [P1-BE-007] Dev JWT secrets committed in `api/.env`
- **File:** `api/.env:7-8`
- **Description:** `.env` (not `.env.example`) contains literal dev
  secrets:
  ```
  JWT_ACCESS_SECRET=dokonpro-access-secret-change-in-production-32chars
  JWT_REFRESH_SECRET=dokonpro-refresh-secret-change-in-production-32chars
  ```
  `.gitignore` at the repo root does exclude `.env` (see
  `Dukon/.gitignore` lines 7-10), so these should not be reaching
  GitHub — but they are present in the developer checkout. Any leak
  of the dev `.env` (screen share, backup) hands over the token-
  signing key. Also the DB connection string
  `postgresql://dokonpro:dokonpro_secret@localhost:5435/dokonpro` is
  committed in `.env`, so the password is public.
- **Recommended fix:** Rotate both secrets. Document in the README
  that developers must generate their own `.env` via a one-shot
  script (`openssl rand -base64 48`). Keep only `.env.example`
  committed.

### [P1-BE-008] `auth.service.register` returns tokens without email verification
- **File:** `api/src/modules/auth/auth.service.ts:20-45`
- **Description:** Registration returns access + refresh tokens
  immediately, with no OTP / email / phone verification. Combined
  with P0-BE-003 (no throttle) this allows automated squatting on
  any phone number. The project rules document explicitly specifies
  "OTP codes: 6 digits, 60s expiry, rate limited" in
  `.claude/rules/security.md` — but there is no OTP module at all.
- **Recommended fix:** Add a phone-OTP pre-step backed by Redis
  before `register` is allowed to create the user; enforce rate
  limiting on OTP issuance.

---

## P2 Findings

### [P2-BE-001] N+1 query in payroll calculation
- **File:** `api/src/modules/payroll/payroll.service.ts:34-106`
- **Description:** `calculate()` loops over every active staff
  member and, per-iteration, runs: `shift.count`, `sale.aggregate`,
  `payroll.findFirst` (with `include: adjustments`), then
  `payroll.upsert`. A store with 30 staff hits 120+ round-trips per
  call. No transaction wrapping the upserts, so a partial failure
  leaves the period half-calculated.
- **Recommended fix:** Replace with a single `groupBy` over
  `shifts` and `sales` keyed by `staffId`, hydrate adjustments in
  one `findMany`, then upsert in a batched transaction.

### [P2-BE-002] Broken `lowStock` filter and invalid raw SQL fragment
- **File:** `api/src/modules/products/products.service.ts:62-70`
- **Description:**
  ```ts
  if (query.lowStock) {
    where.AND = [
      { quantity: { gt: 0 } },
      { quantity: { lte: this.prisma.$queryRaw`"minQuantity"` as any } },
    ];
    // Simplified: use raw where for lowStock
    where.AND = undefined;
    where.quantity = { gt: 0 };
  }
  ```
  The `$queryRaw` tagged-template expression returns a thenable, not
  a number, so the first assignment is invalid; the author then
  overwrote `where.AND = undefined` so `lowStock` silently behaves
  like `inStock=true`. No injection risk (it's a template literal
  with a constant), but the feature is broken. This code would have
  been caught by a single unit test.
- **Recommended fix:** Drop the dead fragment and implement `lowStock`
  via a `prisma.$queryRaw` that selects IDs, or store a computed
  `isLowStock` column maintained by triggers / sync.

### [P2-BE-003] Store `create` ignores subscription idempotency
- **File:** `api/src/modules/stores/stores.service.ts:10-42`
- **Description:** Creating a store also creates a `Subscription` in
  `TRIAL` state. If the create transaction partially fails (e.g.
  `staff.create` throws), Prisma's auto-transaction wraps the single
  call, but there's no retry/idempotency key on the caller side,
  and there is no per-user limit on `POST /stores`. A staff user can
  create unlimited trial stores.
- **Recommended fix:** Enforce a per-user store limit (e.g. 5) and
  an idempotency key on `POST /stores`.

### [P2-BE-004] No e2e or unit tests — test suite is a stub
- **File:** `api/test/app.e2e-spec.ts`
- **Description:** The only test file is `app.e2e-spec.ts` which
  expects `GET /` to return `'Hello World!'`. There is no such
  route (the global prefix is `api`), so this test will fail.
  `find … -name '*.spec.ts'` returns zero unit tests.
- **Recommended fix:** Add minimal integration coverage for auth
  (register → login → refresh → logout), one per service module
  (happy path + one error), and make the e2e suite green.

### [P2-BE-005] Float-like columns for financial percentages
- **File:** `api/prisma/schema.prisma:384, 490, 577, 673`
  (`commission`, `zakatRate`, `birthdayDiscount`, `commissionRate`)
- **Description:** Every money field correctly uses
  `Decimal @db.Decimal(12, 2)` — good — but the four percentage
  fields use `Decimal(5, 2)`. That caps at 999.99% and 2dp, which
  is fine for now. However `birthdayDiscount` and `commissionRate`
  are nullable; make sure the code treats `null` as "0% / not set"
  everywhere.
- **Recommended fix:** Document zero/null semantics in the schema
  comments and assert in services.

### [P2-BE-006] Missing unique index on `Customer.email` and `Supplier.email`
- **File:** `api/prisma/schema.prisma:331-351, 355-372`
- **Description:** Both models have optional `email` without any
  uniqueness or index. Customer duplicate-detection and supplier
  lookup flows will full-scan per query. `Customer.phone` has a
  composite uniqueness with `storeId`, but email is free-form. For
  loyalty/marketing this is a latent bug.
- **Recommended fix:** Add `@@index([storeId, email])` at minimum.

### [P2-BE-007] Missing indexes on high-volume queries
- **File:** `api/prisma/schema.prisma`
- **Description:**
  - `User.phone` is `@unique` (implicit btree — good), but `User`
    has no index on `createdAt` even though auth flows and admin
    queries filter by it.
  - `StockMovement` has `@@index([productId, createdAt])` — good.
  - `Sale` has `@@index([storeId, createdAt])` — good.
  - `Expense` has `@@index([storeId, date])` — good.
  - `Payroll`, `PayrollPeriod`, `Shift` have no indexes on
    `staffId` or `openedAt`, so the payroll N+1 above (P2-BE-001)
    hits full table scans per iteration.
  - `RolePermission` keyed by `(storeId, role, permission)` is
    fine but lookups are by `(storeId, role)` — OK, covered by the
    leading prefix.
- **Recommended fix:** Add `@@index([staffId, openedAt])` on
  `Shift`; add `@@index([staffId, createdAt])` on `Sale`.

### [P2-BE-008] `RefreshToken.token` stored in plaintext
- **File:** `api/prisma/schema.prisma:30-40`;
  `api/src/modules/auth/auth.service.ts:118-124`
- **Description:** The server stores the raw `jti` (a UUID) in the
  `refresh_tokens.token` column. Anyone with read-only DB access can
  use the UUID + the JWT_REFRESH_SECRET to forge refresh tokens for
  any user. The `jti` alone isn't quite enough (JWT sig is needed),
  but a DB leak combined with a secrets leak is a total compromise.
- **Recommended fix:** Store `sha256(jti)` in the DB and compare on
  refresh. Never persist the raw token material.

### [P2-BE-009] `Store.subscription` relation not nullable-consistent
- **File:** `api/prisma/schema.prisma:59`
- **Description:** `Store.subscription` is declared `Subscription?`
  but `stores.service.create` always creates the subscription inline,
  so in practice it is non-null. This creates drift between schema
  expectations and runtime — TypeScript consumers have to handle
  `undefined` for no reason.
- **Recommended fix:** Either make it required (requires migration)
  or keep optional but document the invariant.

---

## P3 Findings

### [P3-BE-001] `shifts.service.ts` treats MIXED payments as CASH
- **File:** `api/src/modules/shifts/shifts.service.ts:102-105`
- **Description:** Z-report attributes the entire MIXED sale total
  to cash. Acceptable "conservative approach" per the code comment,
  but it skews drawer reconciliation.
- **Recommended fix:** Split MIXED using the actual `paidAmount` /
  change-due breakdown once sync captures it.

### [P3-BE-002] `CreateStaffDto.phone` skips Tajik-phone validator
- **File:** `api/src/modules/staff/dto/create-staff.dto.ts:15-17`
- **Description:** Other DTOs use
  `@Matches(/^\+992\d{9}$/)`; `create-staff.dto.ts` uses only
  `@IsString()`.
- **Recommended fix:** Use a shared `@IsTajikPhone()` decorator.

### [P3-BE-003] `UpdateUserDto` allows arbitrary `avatar` URL
- **File:** `api/src/modules/users/dto/update-user.dto.ts:15-18`
- **Description:** `avatar` is `@IsString()` — no URL validation.
  An attacker can store a `javascript:` URI that a lax mobile client
  might render.
- **Recommended fix:** Use `@IsUrl({ protocols: ['https'] })` and
  whitelist a storage domain.

### [P3-BE-004] `LoggingInterceptor` logs URL with query string
- **File:** `api/src/common/interceptors/logging.interceptor.ts:12,18`
- **Description:** Full URL including query string is logged on
  every request. If any controller ever accepts a token/PII in
  query params, it leaks into logs. Today no endpoint does, but
  it's a latent risk.
- **Recommended fix:** Strip `?` and everything after when logging.

### [P3-BE-005] Dev/prod port mismatch
- **File:** `api/.env:2` vs `api/.env.example:2`
- **Description:** `.env` uses PORT=4455 and postgres on `:5435`;
  `.env.example` uses PORT=3000 and postgres on `:5432`. New
  developers following the example will hit "port in use" locally.
- **Recommended fix:** Align `.env.example` with the actual dev
  compose file (`api/docker-compose.yml`).

### [P3-BE-006] Swagger enabled unconditionally
- **File:** `api/src/main.ts:46-54`
- **Description:** `/api/docs` is live in every environment, with
  bearer auth but no additional gate. For a multi-tenant SaaS this
  is risky: it hands attackers a schema map.
- **Recommended fix:** Gate behind `NODE_ENV !== 'production'` or
  require a shared header.

### [P3-BE-007] `RolesGuard` never used
- **File:** `api/src/common/guards/roles.guard.ts`
- **Description:** The `RolesGuard` class exists and reads
  `@Roles()` metadata, but no controller imports it. Dead code —
  either wire it up (preferred, with `PermissionsGuard`) or delete
  it.
- **Recommended fix:** Remove or integrate into the guard stack.

---

## Informational Notes

- **Controllers (16):** auth, categories, customers, expenses,
  finances, payroll, products, stock-movements, roles, sales,
  shifts, staff, stores, suppliers, users, zakat.
- **Modules (15):** all imported in `app.module.ts` — no orphans.
- **Routes (80):** matches scope.
- **DTO validation:** `ValidationPipe` globally applied with
  `whitelist` + `forbidNonWhitelisted` + `transform`. 311 validator
  decorators across 44 DTO files. Phone numbers validated with
  `@Matches(/^\+992\d{9}$/)` in auth & store DTOs; only
  `create-staff.dto.ts` misses it (see P3-BE-002).
- **Password hashing:** bcrypt cost factor 12 everywhere
  (`auth.service.ts:29`, `users.service.ts:53`, `staff.service.ts:20`).
- **Raw SQL:** Four `$queryRaw` sites — `finances.service.ts:33,
  169, 184`, `zakat.service.ts:21`, `products.service.ts:65`. All
  use Prisma tagged-template parameterisation, so none are
  injectable. The `products.service.ts:65` fragment is still
  functionally broken (see P2-BE-002).
- **Rate limiting:** `ThrottlerModule` globally at 100 req / 60s,
  `ThrottlerGuard` as `APP_GUARD`. Only `/auth/login` has a
  tighter override (5 / 60s). `/auth/register`, `/auth/refresh`,
  `/auth/logout` use the global default — see P0-BE-003. No OTP
  endpoints exist at all.
- **JWT config:**
  - Algorithm: HS256 (default).
  - Access expiry: `15m` (good).
  - Refresh expiry: `30d` (P1-BE-002).
  - Refresh rotation: partial — old jti is deleted on `refresh`
    but without a transaction or family detection (P1-BE-001).
  - Revocation: global logout only; no device-level or blacklist.
  - `jti` claim present on refresh only; access tokens have no jti.
- **Logging:** `Logger.log` used by
  `AllExceptionsFilter`, `LoggingInterceptor`, and
  `AuthService`. No `console.log` calls in `src/`. No PII / tokens
  logged, but full request URL is logged (P3-BE-004).
- **Tenant isolation:** every store-scoped controller uses
  `@UseGuards(JwtAuthGuard, StoreAccessGuard)`. The guard confirms
  the user is either the owner or an active staff member. Role-
  level authorisation is **not enforced** (see P1-BE-004).
- **Prisma schema highlights:** all money fields use `Decimal`
  (`@db.Decimal(12,2)`), no `Float` for money — good. Foreign keys
  default to `Restrict` except `RefreshToken -> User` and
  `PayrollAdjustment -> Payroll` and `SaleItem -> Sale`, which use
  `Cascade` — appropriate. `Sale -> Customer` is `Restrict`, which
  means deleting a customer errors while they have sales — good.
- **Tests:** 0 unit tests, 1 e2e stub that will fail because
  `GET /` no longer exists under the `api` global prefix
  (P2-BE-004).
- **`app.module.ts`:** clean — all 15 feature modules imported,
  `ConfigModule` global, `ThrottlerModule` as global guard, Prisma
  and Redis modules wired.
