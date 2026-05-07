# Deep QA — every feature, A→Я

**Date:** 2026-05-07
**Origin:** user request "проверить работоспособность каждой функции от А до Я"
**Selected scope:** Deep coverage for every module (≈20 h work, phased)

## Goal

Walk every feature of the DukonPro stack — registration, store creation,
subscription lifecycle, catalog, POS, sales, finance, customers, suppliers,
staff, shifts, reports, settings, notifications, sync, admin — and report
findings (bugs, UX gaps, missing validation, security holes) against a live
running stack.

Success = every module has a markdown report at `qa/2026-05-07-deep/`
listing per-flow PASS/FAIL with reproduction steps and severity.

## Non-goals

- Not a security audit (separate skill)
- Not a performance benchmark
- Not a fix-as-you-go session — findings get logged, fixes get sequenced
  separately
- Not iOS — no Xcode installed; iOS gets its own pass after install

## Approach (recommended of 3 considered)

**Chosen:** sequential, time-boxed phases. Each phase tackles 3–5 related
modules end-to-end with consistent depth. Findings written to per-module
markdown as the work happens. Final cross-cutting summary at the end.

Rejected:
- *Single monster sweep*: ~20 h in one session exhausts context, hard to
  resume.
- *Parallel subagents per module on the same emulator*: race conditions on
  ADB device + Postgres state; unreliable at this scale.

Subagents are used **only** for pure HTTP API audits (already covered in
the 2026-05-06 audit; this spec doesn't repeat them).

## Coverage depth (Deep, applied uniformly)

For every module:

1. **CRUD happy path** — create + read (list+detail) + update + delete /
   archive. Verify each via API/Postgres after the UI action, not just the
   on-screen state.
2. **Validation** — empty required fields, negative numbers where
   forbidden (price < 0, qty < 0), past dates where forbidden, oversize
   strings (>1k chars), special chars (Russian + Tajik + emoji + SQL `'`).
3. **Cross-store isolation** — store A's data must not appear in store B.
   For every list endpoint, verify the API rejects a foreign storeId.
4. **Subscription limits** — START plan caps (1 store, 500 products, 2
   staff, 0 discounts) trigger a clear UI block, not a 500.
5. **Role-based access** — non-admin user, cashier role, storekeeper role
   each see only their permitted screens / actions. Direct API calls from
   a non-owner JWT return 403.
6. **Error states** — what happens when network is down, when API returns
   500, when a referenced resource is deleted between GET and PUT.

A flow is **PASS** only when all six dimensions are exercised. **FAIL**
documents which dimension broke + repro.

## Phases

| # | Phase | Modules | Est. hours |
|---|---|---|---|
| 1 | Auth & onboarding | register, login, OTP, forgot-password, splash, onboarding-slides, language-switch | 2 |
| 2 | Store & subscription | create-store, multi-store, edit-store, subscription view, request-change, upload-receipt, admin approve/reject, plan limits enforcement | 3 |
| 3 | Catalog | categories, products (CRUD + photo + barcode + variants), Excel import, low-stock alerts | 2.5 |
| 4 | POS & sales | new sale (cash / credit / mixed), receipt preview, Telegram receipt, refund, sales history, filters | 2.5 |
| 5 | Customers & suppliers | customer CRUD, customer debts, loyalty points, supplier CRUD, supplier debts | 1.5 |
| 6 | Staff, shifts, payroll | staff add + roles, shifts open/close (cash count + discrepancy), Z-report, payroll, adjustments | 2 |
| 7 | Finance & reports | balance, credits, investments, zakat, currencies, expenses, reports (PDF + Excel export) | 2 |
| 8 | Operations | deliveries, inventory count, stock intake, discounts (apply at POS) | 1.5 |
| 9 | Settings & misc | profile, password, receipt template, KKM, scanner, Telegram-bot, language, offline mode toggle, notifications | 1.5 |
| 10 | Sync & resilience | offline-first behaviour, sync queue, conflict resolution, retry/backoff | 1 |
| 11 | Admin panel deep dive | every admin page, every destructive action exercised on disposable test data | 2 |
| 12 | Cross-cutting summary | severity-sorted findings, fix sequencing recommendation | 0.5 |
| **Total** | | | **≈22 h** |

## Per-phase output

```
qa/2026-05-07-deep/
├── 01-auth-onboarding.md
├── 02-store-subscription.md
├── 03-catalog.md
├── …
├── 11-admin.md
└── SUMMARY.md      ← cross-cutting, written at the end
```

Each `NN-<phase>.md` follows the same template:

```markdown
# Phase N — <name>

## Setup
- Test environment versions, seed data used, special config

## Modules
### <module>
- Flow: <description>
  - PASS / FAIL: <one-liner>
  - Repro (if FAIL): step-by-step
  - Screenshot: screenshots/NN-module/NN-flow.png
  - Severity: P0 / P1 / P2 / P3
- (one block per flow)

## Findings (this phase)
- P0: …
- P1: …
- P2: …
- P3: …
```

Screenshots live in `qa/2026-05-07-deep/screenshots/<phase>-<module>/`.

## Test data conventions

- Test admin: `+992000000000` / `admin123` (already seeded)
- Disposable test users: `+99290qa<NN>` (so cleanup is grep-able)
- Disposable test stores: `qa-<phase>-<NN>`
- Disposable test products: `qa-prod-<NN>`
- All disposable resources cleaned up at phase end OR documented as
  "intentionally left behind for inspection"

## Tooling

- Live API + admin + emulator running (already up from prior session)
- ADB for mobile UI driving (`exec-out screencap -p`, `input tap`,
  `input text`, `uiautomator dump`)
- `curl` + `jq` for API state verification
- Direct Postgres queries for cross-checks where API doesn't expose state
- Logcat watch (`AndroidRuntime:E` filter) for crash detection
- API server log for 401/500/refresh activity

## Time-boxing

Per phase: hard cap is the budget shown in the phase table (e.g. Phase 3
catalog = 2.5 h). If not done in budget, log "GAPS: <list>" in the
phase report and move on. The cross-cutting summary lists gaps
separately from findings so we can revisit if needed. No hard cap on
individual flows — phase budget is the ceiling.

## Stop-and-report cadence

After each phase:
1. Commit per-phase report + screenshots
2. Print short status to chat (modules covered, findings count, severity
   mix)
3. Decide with user (or auto-continue if auto mode active) whether to
   roll into next phase

## Severity definition

- **P0** — blocks core POS user journey or causes data loss / security
  breach. Must fix before any submission.
- **P1** — breaks a major non-core flow (admin, reports, settings) or
  silently corrupts a non-money record. Fix before launch.
- **P2** — UX confusion, validation gaps, missing affordance. Fix in
  next sprint.
- **P3** — cosmetic, copy issue, label missing localization. Backlog.

## Deferred / out of scope

- Bluetooth printer real hardware test (no printer in dev environment;
  the code path is exercised but no live print)
- iOS — separate sweep after Xcode install
- Telegram bot — webhook + bot account exists but the live flow needs
  a real chat ID. Will exercise the API + admin side; the actual
  Telegram delivery noted as "smoke only".
- Performance / load testing — separate skill / harness
- Localization deep-dive (tj/uz string completeness) — Mobile #7,
  already deferred to its own sprint

## Risks / known caveats

- 50-min cap may be optimistic for catalog and POS phases (lots of
  flows). Will trim or note gaps rather than blow the budget.
- Mobile login session may expire mid-phase (P1 fix shipped today —
  refresh now silent). If router refresh ever fails, capture the API
  log + mark as a regression of today's fix.
- Some flows (e.g. plan-change → admin approve) require 2-account
  context. Will use admin user + a second qa-NN user, both in DB.
- ADB tap coordinates depend on the running emulator's pixel size
  (1080×2400 here). If a different emulator is used later, coordinates
  will need recalculation; the report logs (x, y) for repro.
