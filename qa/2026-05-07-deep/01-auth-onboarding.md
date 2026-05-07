# Phase 1 — Auth & onboarding

**Date:** 2026-05-07
**Stack:** API :4455, admin :3001, emulator-5554 (Pixel 1080×2400, API 36)
**Test users:** seed admin `+992000000000/admin123` + new `+992909000001/qatest1234`

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Cold launch from clean install | 🔴 FAIL | **P1** | Onboarding 4-slide carousel does NOT show on fresh install (uninstall + install). App jumps straight to login. |
| Onboarding "Skip" link | ⚪ N/A | — | Cannot test — onboarding never appears. |
| Register happy path (API) | 🟢 PASS | — | 201 + tokens, isAdmin=false correctly defaulted. |
| Register validation: empty body | 🟢 PASS | — | 400 with class-validator messages for all 3 required fields. |
| Register validation: phone without `+992` prefix | 🟢 PASS | — | 400 "Phone must be a valid Tajik number (+992XXXXXXXXX)". |
| Register validation: short password | 🟡 BLOCKED | P3 | Throttler hit (429) before retry. Validator config is correct (verified via empty-body test which surfaced "Password must be at least 8 characters long"). |
| Register validation: duplicate phone | 🟡 BLOCKED | P3 | Same throttler blocking. Will re-test in later phase when window reopens. |
| Login on emulator | 🟢 PASS | — | Filled phone + password, tapped Войти, landed on "Создать магазин" (correct — new user has no store). 0 FATAL EXCEPTIONs in logcat. |
| Forgot-password flow | 🟡 NOT EXERCISED | P3 | Did not exercise this phase due to time; routes confirmed via API log: `/api/auth/otp/request`, `/api/auth/otp/verify`, `/api/auth/reset-password`. Will revisit. |
| Language switch (ru/tg/uz) | 🟡 NOT EXERCISED | P3 | Will exercise in Phase 9 (Settings). |

## Findings

### F1.1 — P1: Onboarding never shows on fresh install

**Repro:**
1. `adb -s emulator-5554 uninstall com.itlsolutions.dukonpro`
2. `adb -s emulator-5554 install -r app-debug.apk`
3. `adb -s emulator-5554 shell monkey -p com.itlsolutions.dukonpro -c android.intent.category.LAUNCHER 1`

**Expected:** Splash screen → 4-slide onboarding (Быстрые продажи / Учёт товаров / Аналитика / Работает офлайн) → Login.
**Observed:** Splash → straight to Login. Onboarding skipped entirely.

The onboarding screens exist in the codebase
(`app/lib/presentation/pages/onboarding/onboarding_page.dart`) and
worked in earlier QA sessions. Likely cause: splash navigation logic
checks a flag (e.g. `hasSeenOnboarding`) that is set to `true` somewhere
that survives uninstall (unlikely on Android — package data dir is
wiped on uninstall) OR the splash page jumped to login because
`hasTokens()` returned a stale value, OR the onboarding is gated on a
flag that was never reset.

**Severity rationale:** First impression for every new user is broken.
The onboarding pages were specifically built for marketing /
feature-discovery. Skipping them silently dilutes the launch experience.

**Suggested next step:** read `app/lib/presentation/pages/onboarding/splash_page.dart`
navigation logic and confirm the flag store mechanism.

Screenshot: `screenshots/01-auth/01-onboarding-fresh-install.png`

### F1.2 — P2: Validation messages mostly in English

**Repro:** any 400 from `/api/auth/register` with invalid body. Example:
```json
{"statusCode":400,"message":[
  "name must be shorter than or equal to 80 characters",
  "name must be a string",
  "name should not be empty",
  "Phone must be a valid Tajik number (+992XXXXXXXXX)",
  "phone should not be empty",
  "Password must be at least 8 characters long",
  "password must be a string",
  "password should not be empty"
]}
```

**Severity:** P2. End users see English text in a Russian app. Some
messages are custom (Phone, Password) but most are class-validator
default English templates. The mobile app likely just displays
`response.message[0]` to the user verbatim.

**Suggested next step:** add a custom `ValidationPipe` `exceptionFactory`
that translates default messages, OR add `@MinLength`/`@IsNotEmpty`
custom messages on every DTO.

### F1.3 — P2: Auth throttler is aggressive (3 req / window)

**Repro:** make 4 requests to `/api/auth/register` within ~5 seconds.
4th returns `429 ThrottlerException: Too Many Requests`.

**Observed:** 3 successive requests work; 4th is blocked. Window length
unclear from observation but estimated ~60s based on retry timing.

**Severity:** P2 not P0 because it's a security feature. But:
- The error message is "Too Many Requests" — not localized.
- 3 requests is conservative. A user who mistypes their password 3
  times has to wait. A QA session is also impacted.
- No `Retry-After` header observed (worth verifying).

**Suggested next step:** measure the actual throttle window, set per-route limits
(more lenient on /register, stricter on /login attempts from same IP).

## What's still pending in Phase 1

- Forgot-password OTP flow (API + UI walk) — moved to Phase 9 batch
- Language switch — moved to Phase 9 (settings → language)
- Re-test of short-password and duplicate-phone register paths once
  throttler resets (will fold into Phase 2 startup)

## Phase 1 summary

3 PASS / 1 P1 / 2 P2 / 3 BLOCKED-or-DEFERRED. The P1 is real and
worth investigating before any user-facing launch. The P2s are
pre-launch-OK but should land on the next polish sprint.

Screenshots: `screenshots/01-auth/` (8 images covering register, login,
post-login redirect to "Создать магазин").
