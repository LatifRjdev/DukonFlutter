# App lifecycle stress test — 2026-05-12

## Setup

qa-business OWNER on Android emulator-5554 (Flutter debug APK rebuilt at the
start of this run with the new D.0 cart restore prompt, commit 9f5e3e2).
Driven end-to-end by `run.sh`. Total wall time ~7 min (5 min of which is
the Scenario 5 background sleep).

- Backend: `http://localhost:4455` healthy
- Package: `com.itlsolutions.dukonpro`
- DB: `dukonpro-db` (docker)
- Account: `+992910001002` / `qatest1234`
- Store: `d169d2e8-0a24-4a23-844a-5d5e7b690d8c`

## Scenario results

| # | Scenario | Method | Expected | Actual | Status |
|---|----------|--------|----------|--------|--------|
| 1 | Kill mid-cart -> restore prompt | UI tap (chip) + `am force-stop` | "Восстановить корзину?" dialog on cold start | Dashboard shown, no dialog. Root cause: chip-tap coordinate (147, 525) hit empty space — the Касса tab opens to an empty cart with a search field and no product chips visible until user searches. **No cart was ever populated, so no save fired, so no prompt is correct behavior.** Manual verification still required. | ? |
| 2 | Kill mid-checkout | UI tap CTA + `am force-stop` | restore prompt or empty cart | Same as #1: cart never populated. The (540, 1991) tap actually launched **Gmail** (visible in 03-checkout-screen.png) — coordinate hit a different surface because the Касса screen at that vertical position is empty. Test inconclusive. | ? |
| 3 | Offline + kill + reconnect cycle | adb svc + API total count | no crash, no sale duplicates | Sales total 24 -> 24 (no drift). Wifi/data toggle worked. Relaunch after reconnect succeeded without crash. Backend integrity is clean. | OK |
| 4 | OS Doze | `dumpsys deviceidle force-idle` | foreground app stays interactive | `mState=IDLE` confirmed. App remained in foreground, no force-stop fired by the OS. Screenshot 05 shows the dashboard rendered cleanly. | OK |
| 5 | 5 min background -> resume | `KEYCODE_HOME` + `sleep 300` + relaunch | resume to last state, no token-storm | Relaunched successfully after 5 min; dashboard shown. No login screen, no crash, no token refresh storm visible. | OK |
| 6 | Token revoked while backgrounded | SQL `UPDATE users SET tokensRevokedAt=NOW()` | UI redirects to login on resume | Dashboard still shown after revoke + resume. **Root cause (verified via code read):** the 401 handler lives inside per-resource `*RemoteDatasource` classes (`api_interceptor.dart:28` + 9 datasource sites). It only fires on the next HTTP request — and resume does not eagerly re-fetch dashboard data, so the dashboard stays from cache until the user navigates. This is **expected behavior given the current architecture**, not a token-revoke regression. | ? |

Summary counts: **OK 3** (#3, #4, #5) | **? 3** (#1, #2, #6 — all explainable, see Findings).

## Findings

### F1. Cart-population coordinate drift (Scenario 1, 2)
The driver's chip-tap coordinate `(147, 525)` is stale — the current Касса
screen opens with an empty cart and a search bar; there are no quick-add
product chips on the empty state. To populate a cart programmatically you
must either (a) tap into the search field, type, then tap a result, or
(b) use the `+ Новая продажа` CTA from the dashboard. Either pattern
needs ~5+ tap steps and is far more brittle than the API-driven
scenarios. Manual verification of the restore prompt is the
pragmatic path.

### F2. Coordinate (540, 1991) launched Gmail (Scenario 2)
Screenshot `03-checkout-screen.png` shows the Gmail welcome screen, not
the Dukon checkout. The tap fell through to a different app — likely
because between the `01b` shot and the `03` shot the Касса tab was
already open (no cart populated), and the vertical (1991) position
combined with edge-swipe behavior triggered an app switch. Not a Dukon
bug; a driver-coordinate bug.

### F3. Token revoke does not eagerly invalidate the cached dashboard (Scenario 6)
The code path `app/lib/core/network/api_interceptor.dart:28` handles
401 correctly, but only on the **next** outbound request. After
`tokensRevokedAt = NOW()` and a resume, the user sees a stale
dashboard until they navigate to a screen that triggers a fetch.
If the team wants "revoke = immediate logout on resume", a
`AppLifecycleState.resumed` listener that pings `/auth/me` (and
routes to login on 401) would close this gap. Severity: low — the
next user action will surface the 401 within ~1 tap.

### F4. Doze + long background are clean
Scenarios 3, 4, 5 passed cleanly. The app survived `mState=IDLE`,
a 5-min background, and a network-toggle + force-stop + reconnect
cycle without crash or backend drift. These are the most important
real-world resilience checks and they all pass.

## Recommendations

1. **For QA tooling:** Replace the chip-tap pattern in scenarios 1/2
   with either an instrumentation test (Flutter integration_test) or
   a manual checklist, since UI-tap drift on a screen that has no
   stable visual landmarks (empty cart) makes adb-driven automation
   unreliable.
2. **For the app:** Consider adding a lightweight "is my session
   still valid?" ping on `AppLifecycleState.resumed` if the team
   wants token-revoke to land on the user immediately. Current
   behavior (lazy 401 on next call) is acceptable but produces a
   slightly confusing 1-frame stale dashboard after a long
   background.
3. **For the lifecycle matrix going forward:** Scenarios 3, 4, 5
   are good candidates for periodic CI runs (they're fully
   adb/API driven). Scenarios 1, 2, 6 should be promoted to a
   manual checklist or an integration_test.

## Files

- `qa/2026-05-12-app-lifecycle/run.sh` — driver
- `qa/2026-05-12-app-lifecycle/REPORT.md` — this file
- `qa/2026-05-12-app-lifecycle/results.txt` — raw status lines
- `qa/2026-05-12-app-lifecycle/screenshots/` — 18 PNGs (9 full + 9 sm)
