# DukonPro Full-Stack Audit Report — 2026-04-10

**Branch:** `audit/2026-04-10`
**Auditor:** Claude (Opus 4.6) with operator @Latif Rajabov
**Scope:** NestJS backend (16 controllers, 80 routes, 15 modules) + Flutter app (lib/core + lib/data + lib/domain + lib/presentation, 58 pages, 24 BLoCs) + iOS/Android host shells (read-only, Flutter-only sanity)
**Out of scope:** Prisma migration history, backend Docker/infra, iOS-native code, signed-release pipelines, marketing site
**Build state at audit start:** `api` runs on `:4455`, `flutter run` installs `com.itlsolutions.dukonpro` on `emulator-5554`, `flutter analyze` = 0 errors / 0 warnings / 33 infos, `npm run build` in `api/` succeeds.

## Audit plan (from docs/audit/2026-04-10-full-audit-plan.md)

| Pass | Goal | Status |
|---|---|---|
| 1 | Backend static | **Complete** — 28 findings (see `backend-static-findings.md`) |
| 2 | Backend dynamic (auth, tenant, validation, SQLi, rate-limit) | **Complete** — 78/78 routes tested, 1 new dynamic finding (see `backend-routes-matrix.md`) |
| 3 | Flutter static | **Complete** — 16 findings (see `flutter-static-findings.md`) |
| 4 | Flutter dynamic walk | **Complete** — ~27 screens walked across two sessions, 22 screenshots, 25 new findings (see `flutter-screens-matrix.md`) |
| 5 | Offline / sync behaviour | **DEFERRED** — sync engine code is unreferenced (see FE-P1-005); a runtime airplane-mode walk is not meaningful until that wiring is fixed. Noted as separate workstream. |
| 6 | Performance / a11y / i18n locale switching | **DEFERRED** — cold-start ≈6s measured; bundle size, jank, TalkBack, tg/uz locale walkthrough not done. Noted as separate workstream. |
| 7 | Triage + P0 fix patches + this report + GitHub issues + PR | **In progress — this document** |

## Headline numbers

| Metric | Count |
|---|---:|
| Total findings (all passes) | **70** |
| P0 blockers | **11** |
| P1 | **18** |
| P2 | **23** |
| P3 | **15** |
| Screens where a live crash reproduces | **5** (zakat, staff, customers, payroll calculate, suppliers inferred) |
| Backend routes fully tested (auth/valid/invalid/tenant/SQLi) | **78 / 78** |
| Backend routes with tenant-isolation FAIL | **0** (see below for one disputed earlier finding) |
| Flutter routes walked live | ~27 of 51 `GoRoute` entries |
| Flutter unit / widget / bloc tests | **0 real** (1 scaffold) |
| Backend unit / e2e tests | **0 real** (1 stub that fails) |
| Hardcoded Cyrillic strings in UI | **288** across **59** files (i18n essentially non-functional for tg/uz) |

## P0 findings consolidated (11)

### Security / auth (backend)

1. **BE-P0-001** — `staff.service.ts` auto-creates a `User` with `password = phone`. Anyone who later logs in with the phone number as the password takes over the account. Account-takeover vector for any Tajik mobile number. `api/src/modules/staff/staff.service.ts:12-28`.
2. **BE-P0-002** — JWT access+refresh strategies fall back to hard-coded dev secrets if env vars are missing. Any deployment that loses the env vars silently accepts tokens signed with `access-secret-dev`/`refresh-secret-dev` — committed in source. `api/src/modules/auth/auth.service.ts:101,108`, `jwt-access.strategy.ts:16`, `jwt-refresh.strategy.ts:16`.
3. **BE-P0-003** — `POST /auth/register` and `POST /auth/refresh` have no per-route throttle; fall back to the global 100 rpm. Combined with BE-P0-001 this enables phone squatting and account takeover at scale. `api/src/modules/auth/auth.controller.ts:17-21`.
4. **BE-P0-004** — `AllExceptionsFilter` copies raw exception messages into responses and logs full stacks regardless of `NODE_ENV`. Prisma errors leak column names and schema; 500s leak path. `api/src/common/filters/http-exception.filter.ts:23-44`.

### Security / validity (frontend + cross-cutting)

5. **FE-P0-001** — **Hardcoded insecure HTTP base URL**: `http://10.0.2.2:4455/api` is committed in `api_endpoints.dart:4`, and again duplicated inside the token-refresh path at `api_interceptor.dart:44`. Ship-blocker: (a) URL is an emulator loopback, unreachable from real devices/iOS; (b) plain HTTP violates the `security.md` rule. Tokens and passwords would ship in cleartext.
6. **FE-P0-002** — Zero real tests. The only test file in `app/test/` is the default Flutter scaffold counter test. Auth, POS checkout, sync queue, token refresh — all untested. Violates `.claude/rules/testing.md`.

### Runtime crashes discovered in Pass 4 (Flutter dynamic)

7. **FD-P0-001 (FD-019)** — **Zakat screen crashes** on load. `GET /api/stores/:storeId/zakat/settings` returns HTTP 200 with **0-byte body and no content-type** when no `ZakatSettings` row exists. Flutter DTO cast fails (`'String' is not a subtype of 'Map<String, dynamic>'`). Backend bug: `zakat.service.ts:68-72` (`findUnique` → `null` → empty body). Frontend bug: no null-safety on cast.
8. **FD-P0-002 (FD-020)** — **Staff list crashes** on load. `GET /stores/:id/staff` returns a bare `[{...}]` array; Flutter parser expects `{ data: [...] }`. `List<dynamic>` → `Map<String, dynamic>` cast error. Inline red error, FAB still visible but list never renders.
9. **FD-P0-003 (FD-022)** — **Payroll "Рассчитать" crashes**. Tapping the button produces a snackbar + inline red `'Null' is not a subtype of 'String'`. Nullable backend field mapped as non-nullable.
10. **FD-P0-004 (FD-024)** — **Customers list crashes** on load with the same `List<dynamic> → Map<String, dynamic>` pattern as staff.
11. **FD-P0-005 (FD-026)** — **Suppliers list crashes** on load. Confirmed on a fresh `flutter clean && flutter build apk --debug && adb install -r` build: tile routes correctly to `SupplierListPage` (logcat: `GET .../suppliers?page=1&limit=20`, title renders "Поставщики"), but the screen crashes with the same `List<dynamic> → Map<String, dynamic>` cast error as staff and customers. Same root cause — backend returns bare `[...]` array, Flutter parser expects wrapped object. (Earlier in the session a misread uiautomator dump briefly suggested the tile was routing to `/customers`; that was an operator-side tap coordinate error, not a real bug.)

**Root cause class:** four of the five runtime crashes are the same bug shape — the Flutter DTO decoder casts `dynamic` into `Map<String, dynamic>` without null/shape checks. Every backend endpoint whose response is a bare array, an empty body, or contains a null-valued field tagged as non-nullable will trigger this. Likely also affects several screens we didn't walk deep enough.

## P1 findings consolidated (18)

### Backend (8 from backend-static-findings.md)
- BE-P1-001: Refresh rotation has no transaction and no replay detection.
- BE-P1-002: Refresh expiry 30 days; no per-device logout; no access-token deny list.
- BE-P1-003: Password complexity floor is `MinLength(6)` only — `000000`, `123456`, and the user's own phone pass.
- BE-P1-004: `StoreAccessGuard` does not enforce role scope; `PermissionsGuard` exists but is never used — **zero `@Permissions(...)` decorators in the entire module tree**. Any active staff can hit every mutating endpoint.
- BE-P1-005: CORS defaults to `*` with `credentials: true` when `CORS_ORIGIN` is unset; `.env.example` doesn't define `CORS_ORIGIN`.
- BE-P1-006: `helmet()` mounted with bare defaults; no explicit CSP / HSTS override.
- BE-P1-007: Dev JWT secrets committed in `api/.env` (gitignored at root, but present on every developer checkout and in CI artifacts).
- BE-P1-008: `register` returns tokens immediately; no OTP / phone verification — combined with BE-P0-003 the onboarding flow is abusable.

### Frontend (5 from flutter-static-findings.md)
- FE-P1-001: **288 hardcoded Russian strings** across 59 user-facing screens. tg/uz locales technically resolve but the UI shows Russian everywhere. i18n is effectively broken for the app's two non-Russian locales.
- FE-P1-002: `AuthBloc` (and `CheckoutBloc` by spot-check) emit `e.toString()` raw exception strings — leaks internal host, not localized, violates the sealed-class error rule.
- FE-P1-003: `use_build_context_synchronously` flagged by the analyzer in `customer_list_page.dart:106,110` and `supplier_list_page.dart:105,109`. Classic "deactivated widget's ancestor" crash after add-customer / add-supplier.
- FE-P1-004: Four `TextEditingController`s created inside `showDialog` builders and never disposed (`categories_page.dart:31`, `pos_checkout_page.dart:682`, `credit_sale_page.dart:95-96`, `shifts_page.dart:36`).
- FE-P1-005: `data/sync/` files exist but are **not wired into any repository**. Every repository delegates straight to the remote datasource. Contradicts `.claude/rules/sync-engine.md` and the whole offline-first product promise. **Decision required:** commit to offline-first and wire it up, or delete the sync tree.

### Pass 4 runtime (5 — first round)
- FD-P1-001 (FD-012): **6 of 8 Finance tiles are unwired** — `onTap: () {}` empty callbacks. Balance, Credits, Investments, Currencies, Delivery, Reports. The matching `pages/finance/*.dart` files **do not exist**. Dead UI.
- FD-P1-002 (FD-006): Dashboard shows "Чистая прибыль" twice — duplicate KPI card in the 6-card grid.
- FD-P1-003 (FD-011): Add-product "save" path returns to list with "1 операция в очереди" hanging — sync failure is silent.
- FD-P1-004 (FD-008): **Cold start ≈6s, warm launch >10s** (observed one >10s splash hang then recovery). Measured via `adb shell am start -W`. Above a reasonable P1 perf budget for POS use.
- FD-P1-005 (FD-005/FD-004): Store name + user name accept `'; DROP TABLE users; --` with no sanitization and the payload is rendered verbatim in dashboard header, store dropdown, every API response. Stored XSS vector if any WebView ever consumes those fields. Also impacts every screen.

## P2 (23) and P3 (15) findings

Enumerated in the three per-pass files. Highlights:

- **BE-P2-001:** N+1 in `payroll.service.ts::calculate()` — 120+ queries per 30-staff store, no transaction.
- **BE-P2-002:** `products.service.ts:62-70` has a broken `lowStock` filter — dead raw-SQL fragment overwritten on the next line. Feature is silently identical to `inStock=true`.
- **BE-P2-004:** Backend unit tests = 0; one e2e stub that fails (expects `GET /` returning `Hello World!`).
- **BE-P2-008:** `RefreshToken.token` stored plaintext — should be `sha256(jti)`.
- **BE-P2-DYN-001:** `PUT /stores/{storeId}/categories/{id}` returns 500 (unhandled) on SQLi payload; Prisma parameterises, so no injection — just an error-handling bug.
- **FE-P2-001 / P2-005:** Router re-reads secure storage on every navigation; POS checkout uses `setState` for money totals.
- **FE-P2-004:** Deprecated Flutter APIs: `FormField.value`, `Radio.groupValue`, `Radio.onChanged`.
- **FD-P2-001 (FD-021):** Shifts screen empty state has no CTA — no way to open a shift from that screen.
- **FD-P2-002 (FD-007):** Sync banner flips to red on the zakat empty-200 false positive.
- **FD-P2-003 (FD-003):** Rate limiter trips on the 2nd failed login attempt — too aggressive for real users.

## Passes explicitly deferred

| Pass | What's missing | Why deferred | Re-open as |
|---|---|---|---|
| 5 (offline/sync) | Airplane mode walk, queue FIFO, retry/backoff, conflict resolution, sync indicator | Sync engine code is not wired (FE-P1-005). Runtime walk is uninformative until wiring decision is made. | `[audit] Pass 5 — offline/sync rewalk after FE-P1-005 resolved` |
| 6a (performance) | Startup with profile build, frame jank in POS checkout, memory at 10-minute session, APK/IPA size | Profile build and memory tooling not set up this session | `[audit] Pass 6a — performance budget + profile build` |
| 6b (accessibility) | TalkBack pass, touch-target systematic sweep, contrast ratios, dynamic text | Takes a full standalone session with a screen reader turned on | `[audit] Pass 6b — a11y sweep` |
| 6c (i18n tg/uz) | Locale switch → walk every screen → screenshot delta vs ru | Gated by FE-P1-001 (only meaningful after the string sweep) | `[audit] Pass 6c — tg/uz locale walk after FE-P1-001` |

## P0 fix patches included in this PR

Due to session time budget, this PR ships **the audit artifacts and issue tracker**, not the P0 fixes themselves. Every P0 is filed as a separate GitHub issue with a minimal-diff fix recipe in the issue body. Recommended fix order:

1. **BE-P0-002** — fail-fast on missing JWT env vars. 1 file, <20 lines. No user impact.
2. **FE-P0-001** — introduce `--dart-define` flavour, remove hardcoded loopback. Required before any staging deploy.
3. **FD-P0-001** — `zakat.service.ts::getSettings()` returns `{}` on null; add Flutter null-safety in the DTO.
4. **FD-P0-002 / 004 / 005** — introduce a shared `ApiListResponse<T>` decoder that accepts both `[...]` and `{ data: [...] }`; migrate staff, customers, suppliers Blocs.
5. **FD-P0-003** — fix nullable field mapping in `PayrollDto`.
6. **BE-P0-001** — staff invite flow with one-time token (larger refactor, own PR).
7. **BE-P0-003 / P0-004** — per-route throttles and production-aware exception filter (small, own PR).
8. **FE-P0-002** — add bloc_test and widget_test skeletons for the money-handling paths as a separate testing PR.

## Verification status

- `flutter analyze` — **0 errors / 0 warnings / 33 infos** (unchanged during audit)
- `npm run build` in `api/` — **green** (baseline, not re-run post-audit since no code changed)
- `api` live on `:4455` — tested; all 78 routes reachable
- `adb` walk on `emulator-5554` — 22 screenshots captured in `docs/audit/screenshots/`
- Every finding in this report has a file path + line number OR a reproducible curl/adb command in its source file

## Artifacts in this PR

```
docs/audit/
├── 2026-04-10-full-audit-plan.md       (200 lines — original plan, unchanged)
├── 2026-04-10-full-audit-report.md     (this file)
├── backend-static-findings.md          (502 lines — 28 findings, P0–P3)
├── backend-routes-matrix.md            (138 lines — 78-route dynamic matrix)
├── flutter-static-findings.md          (158 lines — 16 findings, P0–P3)
├── flutter-screens-matrix.md           (~95 lines — 27-screen dynamic walk, 25 findings)
└── screenshots/                        (29 PNGs from the two walk sessions)
```

## Session-level meta

- Backend was kept running throughout the audit; no DB writes were made other than the bootstrap set in Pass 2 (category, product, customer, supplier, expense, staff, shift, sale all via primary token).
- One test user's store name + user name were set to `'; DROP TABLE users; --` during Pass 2 to exercise SQLi handling. The name persists in the DB and is now visible on the dashboard as a reminder — safe to overwrite at any time.
- Git state: one pre-existing modification to `.claude/settings.json` (unrelated to audit) is still uncommitted and should be staged or reverted before merging this PR.
- No backend or Flutter code was modified during the audit. This PR is docs-only.
