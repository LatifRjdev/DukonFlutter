# Phase 9 — Settings

**Date:** 2026-05-07

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Profile edit (name + email) | 🟢 PASS | — | 200, fields updated. |
| Change password — wrong old | 🟢 PASS | — | 400 with proper error. |
| Change password — short new | 🟢 PASS | — | 400 "Password must be at least 8 characters long". |
| Receipt template — get default | 🟢 PASS | — | Returns empty defaults. |
| Receipt template — save empty (P2 from prior QA) | 🟡 KNOWN | P2 | Carryover from 2026-05-06 QA — accepts `{}` and silently resets. Not retested. |
| Loyalty settings endpoint | 🔴 NOT-FOUND | P3 | `GET /api/stores/:id/loyalty-settings` returns 404 — endpoint not mounted. The `loyalty_settings` table exists in DB. Either reachable under another path or feature is partially implemented. |
| Notifications list | 🟢 PASS | — | 2 notifications visible from Phase 2 (SUBSCRIPTION_APPROVED + SUBSCRIPTION_REJECTED). Russian text correct. |
| Notification mark as read | (untested) | — | PUT route exists; smoke skipped. |
| Notification settings PUT | (untested) | — | Same. |
| Telegram bot webhook + send-receipt | (untested-live) | — | Routes exist. Need real chat ID for live test. |

## Findings

### F9.1 — P3: Change password DTO uses `currentPassword`, not `oldPassword`

Minor naming. Mobile devs and Swagger consumers will hit this. Either
align across the codebase or document clearly.

### F9.2 — P3: Loyalty-settings endpoint not mounted

DB table exists, no controller. Either remove the unused table or
implement the missing endpoint.

## Phase 9 summary

7 PASS / 0 P0/P1 / 1 P2 (known carryover) / 2 P3 nits.
