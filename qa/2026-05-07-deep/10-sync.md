# Phase 10 — Sync & resilience

**Date:** 2026-05-07
**Status:** lightweight pass — full offline cycle requires UI driving
that didn't fit the budget. Schema-level + API-level checks below.

## What was checked

| Check | Result | Notes |
|---|---|---|
| Sync queue table exists in DB | 🟢 PASS | `sync_queue` table present in Postgres list (from baseline). |
| Sale DTO carries `localId` (offline idempotency) | 🟢 PASS | Verified in `CreateSaleDto` — optional field for client-generated UUID so a duplicate-sent sale is deduped server-side. |
| Sale model carries `syncedAt` | 🟢 PASS | Visible in returned sale objects (null for online-only sales). |
| JWT silent refresh on idle | 🟢 PASS | Earlier P1 fix verified in this session — router proactively refreshes on expired access token, so a returning user doesn't get kicked out. (See `app/lib/core/router/app_router.dart` change in commit 8d126fc.) |
| **Live offline → online cycle on emulator** | ⚪ NOT-RUN | Driving `adb svc data disable` mid-session would break parallel ADB commands; deferred to a focused offline-only run. |
| Conflict resolution (last-write-wins per spec) | ⚪ NOT-RUN | Same — needs offline cycle to exercise. |
| Retry with exponential backoff | ⚪ NOT-RUN | Has unit tests in place from earlier sessions; live test deferred. |

## Phase 10 summary

The sync infrastructure is **architecturally correct** based on schema +
DTO inspection. Live cycle (offline sale → reconnect → drain queue) was
not exercised this run. Recommend a dedicated half-day offline-mode QA
session before launch — the offline-first promise is a key value prop.

No new findings. P1 from yesterday's QA (silent logout on expired
token) was fixed earlier in this session.
