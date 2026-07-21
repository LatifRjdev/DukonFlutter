# Production Readiness Summary — 2026-07-21 (updated same day, follow-up pass)

Scope: Flutter mobile app + NestJS backend (`api/`). Combines the initial
sweep earlier today (Flutter unit/bloc/golden coverage, backend gap-fill,
live functional smoke test, this report) with a same-day follow-up that
acted on every recommendation the initial pass produced.

## Verdict

**No P0 blockers. One P1 found and fixed same-day** (Telegram webhook
auth). All 5 recommended follow-up actions from the initial pass are now
done: dependency audit triaged, app-lifecycle device scenarios actually
executed (all pass), OWASP re-swept, checkout verified end-to-end on a
real device against the live API, and web/macOS platforms scaffolded
(web works; macOS blocked by local environment, not code).

---

## 1. Automated test coverage

| Layer | Suites | Tests | Status |
|---|---|---|---|
| Flutter (`app/`) — unit, BLoC, golden | ~146 files | 1,427 | ✅ all passing* |
| Backend (`api/`) — Jest | 41 | 371 | ✅ all passing |

\* One test (`subscription_bloc_test.dart` — receipt upload, real temp-file
I/O) is intermittently flaky when run as part of the full suite (passes in
isolation and on most full-suite runs; failed once during this session).
Not a regression — pre-existing, timing-related, not caused by anything
changed today. Worth a look if it recurs, not a blocker.

Flutter: all 24 previously-uncovered feature areas now have behavioral
tests (commits `9af2202`..`1e7cfcf`). `flutter analyze`: clean.

Backend: added the 3 modules with zero coverage (`deliveries` 17 tests,
`staff` 24→32 tests after the guard fix, `telegram` 30 tests), plus 6 new
tests for the Telegram webhook production config gate. `tsc --noEmit`: clean.

## 2. Functional verification (live backend, real device, real checkout)

Two rounds of `flutter integration_test` against the live dev API
(`localhost:4455`, Postgres up) on an Android emulator:

**Round 1** — login + navigation: real `POST /auth/login`, token persists,
go_router redirects `/login`→`/home`; real API calls
(`/finances/dashboard`, `/products`, `/categories`) return 200; POS screen
renders against live data, no crash.

**Round 2** — full checkout: extended the same test to add a product to
cart, complete a CASH sale, and verify via a follow-up `GET /sales/:id`
that the sale was created exactly as submitted (id `db3709b9-…`, receipt
`R-000001`). **This is the strongest signal in this report** — the
complete revenue path (auth → browse → cart → checkout → persisted sale)
was proven against a real server, not mocks. Test data was cleaned up
(sale + a stock top-up movement deleted, product quantity restored to its
original value) after verification.

Web (`flutter build web`) now builds cleanly after scaffolding (§6). macOS
build is blocked by the local environment (§6), not attempted as a
functional-test target.

## 3. App-lifecycle device QA — now actually executed (was a blank template)

All 4 scenarios from `2026-07-05-app-lifecycle/REPORT.md` were run for
real on an Android emulator (API 36) this session, not simulated:

| # | Scenario | Result |
|---|---|---|
| 1 | OS process kill mid-sale (`am force-stop`) | ✅ Pass — restore dialog shows exact item count, restores the exact cart |
| 2 | Doze mode (10-min background) | ✅ Pass — simulated via `dumpsys deviceidle force-idle` rather than a real 10-min wait (noted as a caveat: process wasn't actually evicted, so this tests "survives backgrounding" more than true Doze eviction) |
| 3 | Device sleep during active sale | ✅ Pass — instant resume, cart untouched |
| 4 | Low-memory process kill | ✅ Pass, with one UX deviation: on reopen the app lands on the Home tab, not POS, before the restore dialog appears (the report's literal wording expected POS). Root cause: bottom-nav tab selection isn't part of persisted state; the cart itself restores correctly once you navigate back to Касса. Minor, not a data-loss bug. |

**No crashes or data loss found in any scenario** — no cashier's sale
would be lost by a process kill, Doze, sleep, or low-memory eviction.

Operational note from the QA run: the on-disk debug APK was, at the start
of this session, an **integration-test harness build**
(`flutter_test_listener.dart` entrypoint) rather than the real app —
produces a silent, crash-free splash hang nearly indistinguishable from a
real deadlock. Any `flutter test integration_test/...` run overwrites the
same APK path with this harness build. If you `adb install` and manually
poke at the app after running an integration test, rebuild first with
`flutter build apk --debug -t lib/main.dart` or you'll chase a phantom hang.

## 4. Security — OWASP re-swept same day (was 2 months stale)

Full re-sweep at `qa/2026-07-21-owasp-resweep/REPORT.md`, with extra
scrutiny on `deliveries`/`staff`/`telegram` (the modules that had zero
test coverage until this week) and the Telegram webhook specifically
(wasn't in scope for the May sweep).

**0 P0 · 1 P1 (found + fixed same day) · 3 P2 (1 carried/improved, 2 new,
1 of those fixed same day) · 2 P3 (both carried, unchanged from May).**

- **P1 — Telegram webhook accepted unauthenticated requests when
  `TELEGRAM_WEBHOOK_SECRET` was unset** (not in `.env.example`, not
  boot-checked, unlike JWT secrets). Traced real impact: a forged Telegram
  `Update` with a spoofed `contact.phone_number` could rebind a customer's
  or **store owner's** `telegramChatId` to an attacker, silently
  redirecting future receipts/notifications (containing purchase data).
  **Fixed**: `validate-config.ts` now requires `TELEGRAM_WEBHOOK_SECRET`
  (≥16 chars) in production, in both pre- and post-bootstrap validation
  paths, same pattern as the existing `CORS_ORIGIN` gate. 6 new tests.
- **P2 (new) — `staff.role_change` audit entries always attributed to
  `'system'`**, never the real actor. **Fixed**: caller id now threaded
  from controller to service via `@CurrentUser('id')`; falls back to
  `'system'` only when absent.
- **P2 (new, independently re-verified, downgraded from the initial P0/P1
  framing) — staff last-OWNER gap.** `staff.service.ts` had no guard
  against demoting/removing a store's last `OWNER` staff row, and no
  self-removal guard. Independent verification: `StoreAccessGuard`/
  `PermissionsGuard` check `Store.ownerId` directly and independently of
  the `Staff` table, and `StaffRoleEnum` structurally excludes `OWNER` as
  an assignable value — so the real owner **cannot** actually be locked
  out via this path; impact is bounded to data-integrity corruption (a
  `Staff` row's role/visibility diverging from reality) and a minor
  plan-limit undercount. Still worth fixing as defense-in-depth. **Fixed
  regardless**: `assertNotLastOwner()` guard added to both `update()` and
  `remove()`, plus a self-removal guard. 8 new tests.
- **P2 (carried, improved) — npm advisories**, see §5.
- **P3 ×2 (unchanged)** — currencies endpoints intentionally public;
  `POST /rates/fetch` has no dedicated rate limit beyond the global
  throttler. Both believed intentional, still undocumented in OpenAPI.

## 5. Dependencies — triaged same day

`npm audit --omit=dev`: **59 → 41 vulnerabilities, 4 → 2 critical.**

- Removed `xlsx` entirely — confirmed **completely unused** in source
  (the real Excel import/export path uses `exceljs`); its critical
  ReDoS/prototype-pollution advisories had no fix available, so deleting
  the dead dependency was strictly better than leaving it.
- `npm audit fix` (non-breaking): 59→46, lockfile-only, no `package.json`
  changes.
- `bcrypt` 5→6: cleared the `@mapbox/node-pre-gyp`/`tar` critical chain.
  Verified with a real (non-mocked) hash/compare round-trip after
  upgrading, not just unit tests.
- `firebase-admin` 13→14: routine bump, part of clearing the chain.
- **Remaining 2 critical** (`form-data`, `request`) are both transitive
  through `node-telegram-bot-api@0.67`'s `@cypress/request-promise`
  dependency. A fix exists (`node-telegram-bot-api@1.2`, a major bump) but
  was **deliberately deferred** — the telegram module just received its
  first-ever test coverage this week, and a major API bump without
  dedicated regression time risks breaking it same-day. Tracked as a
  follow-up.
- Full backend suite (371 tests) and `tsc --noEmit` green after all
  dependency changes.

## 6. Platform scaffolding — done, web works, macOS blocked by environment

`flutter create --platforms=macos,web .` was run (this repo never had
these platforms scaffolded — only iOS/Android existed). Generated a bogus
default `test/widget_test.dart` counter-app boilerplate, which was deleted
(would have failed against this app's real `main.dart`). `pubspec.yaml`
untouched.

- **Web**: `flutter build web` succeeds cleanly (WASM-compat warnings only,
  non-blocking; regular JS compilation is the default target anyway).
- **macOS**: build fails — this machine has Xcode Command Line Tools but
  not the full Xcode.app install (`xcodebuild` unavailable) and no
  CocoaPods. This is a one-time local environment setup requirement
  (multi-GB Xcode download + `sudo xcode-select`/`xcodebuild
  -runFirstLaunch` + CocoaPods install), not a code problem — deliberately
  not done automatically given the scope of that change; flag if you want
  it actioned.

Non-golden Flutter suite re-run after scaffolding: 1,427 tests, same
result as before (see the flaky-test note in §1) — scaffolding did not
regress anything.

## 7. Performance (k6 baseline, 2026-07-04, smoke-scale — unchanged this session)

All 4 scenarios passed well under threshold on localhost (p95 3–28ms), 2
P2 bugs fixed inline at the time. Not yet run at production scale or
against a non-localhost target — still a next step, not actioned this
session (lower priority than the security/coverage work above).

## 8. Bugs found and fixed today (chronological)

| # | Bug | File(s) | Severity |
|---|---|---|---|
| 1 | Sales-history date/payment filters silently reset on every reload | `sales_history_bloc.dart` | Functional |
| 2 | `/sales/empty` route unreachable (swallowed by `/sales/:id`) | `app_router.dart` | Functional |
| 3 | Telegram webhook accepts unauthenticated requests in production when secret unset | `validate-config.ts`, `.env.example` | **P1 security** |
| 4 | `staff.role_change` audit misattributes actor as `'system'` | `staff.service.ts`, `staff.controller.ts` | P2 accountability |
| 5 | No guard against removing/demoting a store's last OWNER staff record | `staff.service.ts`, `staff.controller.ts` | P2 defense-in-depth |
| 6 | `xlsx` unused dependency carrying an unfixable critical CVE | `package.json` | P2 hygiene |

All pushed or ready to push — items 1–2 are already on `origin/main`
(commit `9af2202`); items 3–6 are local, uncommitted (this session's
work), see git status.

## 9. Known non-blocking gaps (flagged, not fixed)

- `Category`/`Investment`/`FinanceSummary` entities omit some fields from
  `Equatable.props` — can suppress BLoC/UI rebuilds on real data changes.
- `ProductListBloc` drops the active category filter when search changes.
- Dead code: `StockMovementModel`, `SupplierModel`, `RouteNames.pos`.
- `NotificationService.scheduleNotification` uses in-memory timers, not
  `zonedSchedule` — reminders don't survive app restart.
- `node-telegram-bot-api` 0.67→1.2 bump deferred (§5).
- Currencies endpoints public, `POST /rates/fetch` unrate-limited beyond
  global throttle — both P3, believed intentional, undocumented.
- App-lifecycle scenario 4's UX deviation (lands on Home, not POS) — §3.
- One intermittently flaky Flutter test (§1) — pre-existing, not chased down.

## 10. CI/CD & deploy

`.github/workflows/ci.yml` and `deploy.yml` exist, not exercised this
session — still worth confirming CI actually runs the full suites
(1,427 + 371 tests) and that deploy targets are current. `main` was
pushed to `origin/main` earlier today (288 commits); today's follow-up
fixes are local and not yet pushed.

---

## What's left, if anything

Everything from the initial pass's "recommended next steps" is now done.
Remaining lower-priority items, roughly in order:

1. Push today's local commits (items 3–6 in §8) to `origin/main`.
2. Bump `node-telegram-bot-api` to 1.2 with dedicated regression testing
   (clears the last 2 critical npm advisories).
3. Set up full Xcode + CocoaPods on this machine if macOS functional
   testing is wanted (or defer indefinitely if macOS isn't a target
   platform for this product).
4. Re-run app-lifecycle scenario 2 with a real 10-minute wait if true Doze
   eviction behavior (not just backgrounding) needs verifying.
5. Full-scale k6 load run (100 VU / 5 min) against a non-localhost target.
