# Dukon / DukonPro Full Application Audit — 2026-04-10

## Goal

Comprehensive audit of every route, screen, button, and user-facing function across the Dukon mobile POS platform. Produce a triaged list of bugs, security issues, and unfinished work; fix P0 blockers inline; open GitHub issues for P1+.

## Scope

### Backend (NestJS + Prisma + Redis)

- **Location:** `api/`
- **Scale:** 80 HTTP routes across 16 controllers / 15 feature modules
- **Modules:** `auth`, `stores`, `products`, `categories`, `customers`, `suppliers`, `sales`, `expenses`, `finances`, `zakat`, `staff`, `payroll`, `shifts`, `roles`, `users`
- **Database:** PostgreSQL 16 (dukonpro-db, port 5435), Redis 7 (port 6380)
- **Auth:** JWT access/refresh tokens

### Flutter App (Dart, Material 3, BLoC)

- **Location:** `app/`
- **Scale:** 55 screens / 54 routes across 18 feature groups
- **Features:** `auth`, `onboarding`, `dashboard`, `pos`, `product`, `stock`, `customer`, `supplier`, `sales`, `finance`, `debt`, `zakat`, `staff`, `payroll`, `shifts`, `roles`, `store`, `settings`
- **Target:** Android (tested on emulator-5554), iOS (untested in this audit)
- **Locales:** ru / tg / uz (all three must be audited)

### Out of scope

- iOS dynamic testing (no simulator booted)
- Load / stress testing
- Penetration testing with active exploits (static + known-pattern security checks only)
- Backend unit test coverage improvement (noted, not fixed)

## Audit Dimensions (7 passes)

### Pass 1 — Backend Static Audit

Tools: `Grep`, `Read`, manual review. No runtime.

**Checks:**
- Hardcoded secrets, API keys, passwords in source
- Missing auth guards on protected endpoints
- Missing input validation (class-validator decorators on DTOs)
- Raw SQL / unsafe Prisma queries
- Missing rate limits on auth/OTP endpoints
- CORS, helmet, CSRF configuration
- JWT handling: algorithm, expiry, refresh token rotation, blacklist on logout
- Password hashing (bcrypt cost, salt handling)
- Prisma schema: missing indexes, cascade misconfig, unique constraints
- N+1 query patterns
- Error messages leaking stack traces / internal paths
- OWASP Top 10: A01 Broken Access, A02 Crypto, A03 Injection, A04 Insecure Design, A05 Security Misconfig, A07 Auth, A08 Data Integrity, A09 Logging

**Output:** `docs/audit/backend-static-findings.md`

### Pass 2 — Backend Dynamic Audit

Tool: bash + curl against running backend (`http://localhost:4455/api`).

**Method:**
- Parse Swagger JSON to extract all routes with methods and required params
- For each route:
  1. Unauthenticated request → expect 401 (unless public)
  2. Authenticated valid request → expect 2xx
  3. Authenticated invalid request (missing/bad params) → expect 4xx
  4. Tenant isolation check: route scoped by `:storeId` — try accessing with another user's storeId → expect 403/404
  5. SQL injection / XSS payloads in text fields → expect sanitized
  6. Rate limit check on auth endpoints

**Output:** `docs/audit/backend-routes-matrix.md` (route × test × result)

### Pass 3 — Flutter Static Audit

Tools: `flutter analyze --fatal-warnings`, `dart fix --dry-run`, `Grep`.

**Checks:**
- `dart analyze` errors and warnings (strict mode)
- Unused imports, dead code, unused providers
- Missing `const` constructors (perf)
- `BuildContext` used across async gaps (Flutter lint)
- Hardcoded strings (should be in ARB for i18n)
- Hardcoded URLs, `http://` in production paths
- Secrets / tokens in code
- `print()` / `debugPrint` left in release code
- `TextEditingController` / `StreamSubscription` without `dispose()`
- Overflow risks: unconstrained `Row`/`Column`, fixed sizes in scrollable contexts
- `MediaQuery` usage without safe areas
- BLoC state management consistency (are all features using same pattern?)
- Architecture drift from `.claude/rules/*.md`

**Output:** `docs/audit/flutter-static-findings.md`

### Pass 4 — Flutter Dynamic UI Walkthrough

Tool: `adb` + `uiautomator dump` + screenshots read via vision.

**Method:**
- For each of 55 screens:
  1. Navigate to screen (via deep link if possible, otherwise tap sequence)
  2. Screenshot
  3. Read screenshot and check for: overflow, missing translations, broken images, empty states, misalignment
  4. Try every interactive element (buttons, tabs, forms, FABs, nav)
  5. Check `flutter run` logs for runtime errors/exceptions
- Critical flows end-to-end (full test):
  - Login → Dashboard
  - POS: pick product → add to cart → checkout → receipt → verify sale in backend
  - Inventory: create product → edit → delete → verify DB
  - Customer: create → add debt → settle debt
  - Finance: add income/expense → check dashboard stats update
  - Settings: change locale → re-check 5 screens

**Output:** `docs/audit/flutter-screens-matrix.md` + screenshots in `docs/audit/screenshots/`

### Pass 5 — Offline / Sync Audit

Tool: `adb shell svc wifi disable|enable`, backend logs.

**Checks:**
- Airplane ON → create product → verify UI shows offline indicator
- Verify write queued in local DB
- Airplane OFF → verify sync happens automatically
- Verify remote DB reflects change
- Conflict: update same entity both offline (app) and online (curl) → check resolution strategy
- Kill app mid-sync → relaunch → verify retry
- Check retry backoff behavior
- Verify reads from local DB while offline (dashboard stats, product list)

**Output:** `docs/audit/sync-findings.md`

### Pass 6 — Performance & Accessibility

**Performance:**
- `flutter build apk --analyze-size` — bundle size breakdown
- `adb shell am start -W` — cold start time
- `adb shell dumpsys gfxinfo com.itlsolutions.dukonpro` — frame jank stats during POS flow
- Memory: `adb shell dumpsys meminfo com.itlsolutions.dukonpro`

**Accessibility:**
- Touch target sizes (<48dp is a fail)
- Color contrast (WCAG AA 4.5:1 for text)
- `Semantics` widget usage for TalkBack
- Keyboard handling: inputs scrollable, forms submittable via keyboard

**i18n:**
- Switch locale to tg → spot-check 5 key screens
- Switch locale to uz → spot-check 5 key screens
- Flag untranslated strings (English/Russian leak in other locales)

**Output:** `docs/audit/perf-a11y-findings.md`

### Pass 7 — Triage & P0 Fixes

- Aggregate findings into `docs/audit/findings.json`
- Classify each: **P0** (security/blocker), **P1** (important), **P2** (nice-to-have), **P3** (cosmetic)
- P0 fixes implemented in this branch with dedicated commits
- Generate `docs/audit/ISSUES.md` → create GitHub issues via `gh issue create` for all P0/P1
- Final report: `docs/audit/2026-04-10-full-audit-report.md`

## Execution Strategy

**Parallelization where possible.** Passes 1, 3, and the Swagger-scraping portion of Pass 2 can run as independent agents:

- **Agent A:** Backend static audit (Pass 1) — returns JSON of findings
- **Agent B:** Flutter static audit (Pass 3) — returns JSON of findings
- **Agent C:** Backend dynamic audit (Pass 2) — needs running backend, returns route matrix

Then sequentially (I do myself, needs emulator + stateful context):
- Pass 4 Flutter dynamic walkthrough
- Pass 5 offline/sync
- Pass 6 perf & a11y
- Pass 7 triage & fixes

## Deliverables

1. `docs/audit/2026-04-10-full-audit-plan.md` — this document
2. `docs/audit/backend-static-findings.md`
3. `docs/audit/backend-routes-matrix.md`
4. `docs/audit/flutter-static-findings.md`
5. `docs/audit/flutter-screens-matrix.md`
6. `docs/audit/sync-findings.md`
7. `docs/audit/perf-a11y-findings.md`
8. `docs/audit/findings.json` — machine-readable, all findings with severity
9. `docs/audit/2026-04-10-full-audit-report.md` — executive summary + all findings
10. `docs/audit/screenshots/*.png` — evidence
11. GitHub issues for each P0 / P1 finding (label: `audit-2026-04-10`)
12. P0 fix commits in `audit/2026-04-10` branch
13. Pull request from `audit/2026-04-10` → `main`

## Risk & Limitations

- **Time**: estimated 2–6 hours of audit work even with parallelization
- **Emulator flakiness**: tap coordinates may drift between screens; recovery logic needed
- **Offline sync testing**: relies on `adb svc wifi` which is sometimes unreliable on Android emulators
- **Security depth**: static analysis only — no fuzzing, no active exploits, no chained attack scenarios
- **iOS**: completely untested (no simulator booted)

## Severity Definitions

- **P0 — Blocker / Security**: crash on happy path, auth bypass, data loss, secrets exposure, unauthorized data access, broken critical flow
- **P1 — Important**: feature partially broken, incorrect calculations, missing validation, performance regression on main flows, untranslated strings on key screens
- **P2 — Nice-to-have**: minor UI glitches, inefficiency, missing polish, edge case handling
- **P3 — Cosmetic**: copy changes, padding, style inconsistency, comments
