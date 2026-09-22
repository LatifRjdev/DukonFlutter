# Offline Mode Screen — Real Sync Status — Design

**Context.** Found during the 2026-09-21/22 manual QA pass
(`qa/2026-09-07-manual-test-run/REPORT.md`, finding #17): the "Офлайн-режим"
settings screen (`offline_mode_page.dart`) calls `GET /sync/status` and
`POST /sync/trigger` against the backend. Neither endpoint exists — they
aren't even defined in `ApiEndpoints`, and the backend has zero sync-related
routes anywhere in `api/src/`. Every call 404s; the page silently swallows
the error and always shows "Всё синхронизировано" (pending count hardcoded
to 0 on failure), and "Синхронизировать сейчас" always reports success
regardless of what actually happened.

**Root cause.** There is no server-side sync queue to call `/sync/status`
or `/sync/trigger` against — the entire sync queue is local, in a `sqflite`
table (`SyncQueue`, `sync_queue.dart`), processed by `SyncEngine`
(`sync_engine.dart`). Both already work correctly and are already wired at
app startup (`main.dart` calls `sl<SyncEngine>().start()`), and are already
consumed correctly elsewhere in the app — `OfflineBanner`
(`presentation/widgets/common/offline_banner.dart`) reads
`SyncQueue.pendingCount()` and listens to `SyncEngine.syncStatus` today.
`offline_mode_page.dart` is the one place in the app that doesn't talk to
this existing local sync system — it's dead code calling nonexistent
endpoints instead.

**Goal.** Rewire the screen to the real local `SyncEngine`/`SyncQueue`,
mirroring `OfflineBanner`'s proven pattern. No backend work — there's
nothing on the server to build. Along the way, fix two adjacent problems
surfaced while investigating: the "Авто-синхронизация" toggle is currently
decorative (saved to a preference nothing reads), and the "Сбросить статус
синхронизации" button's copy claims it resets a pending-ops counter that,
once real, can't honestly be reset without touching actual queued data.

## Architecture

No new components. Three existing pieces get connected:

- **`SyncEngine`** (`data/sync/sync_engine.dart`) gains a `bool
  autoSyncEnabled = true` field. Its connectivity-change listener becomes
  `if (isConnected && autoSyncEnabled) processQueue();`. Manual
  `processQueue()` calls (from this screen's button, or `OfflineBanner`'s
  "Повторить" link) are never gated by this flag — only the automatic
  on-reconnect path is.
- **`main.dart`** reads the persisted `offline_auto_sync` preference once
  at startup (alongside the existing saved-locale read in `main()`) and
  sets `sl<SyncEngine>().autoSyncEnabled` before `_AppLifecycleHost` calls
  `.start()`, so a previously-saved "off" setting takes effect from a cold
  start rather than only after the user revisits the settings screen.
- **`OfflineModePage`** drops its `DioClient` dependency and the
  `/sync/status` / `/sync/trigger` calls entirely, reading from
  `sl<SyncEngine>()`, `sl<SyncQueue>()`, and `sl<NetworkInfo>()` instead —
  the same three dependencies `OfflineBanner` already uses.

## Component: OfflineModePage

- **Pending count.** `_syncQueue.pendingCount()` on `initState`, refreshed
  whenever `_syncEngine.syncStatus` emits `SyncStatus.completed` or
  `SyncStatus.error` (mirrors `OfflineBanner._refreshPendingCount`).
- **Last synced.** Unchanged storage mechanism (`SharedPreferences` key
  `last_sync_timestamp`), but now written when `syncStatus` emits
  `completed`, instead of after a fake successful POST.
- **"Синхронизировать сейчас".** Checks `await
  _networkInfo.isConnected` first:
  - Offline → show an error snackbar with
    `mapErrorToUserMessage(const NetworkException())` ("Нет подключения к
    интернету"). Does **not** call `processQueue()` — today it would
    silently no-op mid-flight since `processQueue()` itself returns before
    emitting any status when offline, leaving the button looking like it
    did nothing.
  - Online → `await _syncEngine.processQueue()`. The button's own
    `_syncing` display state, and the resulting success/error snackbar,
    are both driven by the `syncStatus` stream listener (see below) — not
    set directly in the button handler. This means a sync triggered
    automatically by reconnect while this screen happens to be open
    surfaces the same feedback as a manual tap, which is correct: the
    user is looking at this exact screen either way.
- **`syncStatus` stream listener** (subscribed in `initState`, cancelled in
  `dispose`, matching `OfflineBanner`'s subscription lifecycle):
  - `syncing` → `_syncing = true`.
  - `completed` → `_syncing = false`; refresh pending count; persist +
    display new "last synced" timestamp; show a success snackbar
    (`snackSyncCompleted`, existing key, unchanged text).
  - `error` → `_syncing = false`; refresh pending count; show an error
    snackbar (`snackSyncError`, existing key, unchanged text — the
    generic "Ошибка синхронизации: {error}" wording already fits; no new
    key needed since we're not passing a specific caught exception here,
    just a fixed generic message for this fixed error kind).
  - `idle` → `_syncing = false` (empty-queue fast path; no snackbar, since
    there's nothing to report and the status card already reads "Всё
    синхронизировано" whenever pending count is 0).
- **Auto-sync toggle.** `_saveAutoSync` now does two things: persists to
  `SharedPreferences` (unchanged) and sets
  `sl<SyncEngine>().autoSyncEnabled = value` (new), so flipping it takes
  effect immediately without an app restart.
- **"Сбросить статус синхронизации".** `_clearCache` drops the
  `_pendingOps = 0` line entirely — it now only clears
  `last_sync_timestamp` and the displayed `_lastSync`. Pending count is a
  live value read from the real queue; there is nothing honest to "reset"
  it to.

## l10n

`offlineResetSyncStatusBody` (`app_ru.arb`) currently reads:

> "Отметка времени последней синхронизации и счётчик операций в очереди
> будут сброшены на этом устройстве. Локальные данные не удаляются."

The "и счётчик операций в очереди" clause is no longer true and is
removed:

> "Отметка времени последней синхронизации будет сброшена на этом
> устройстве. Локальные данные не удаляются."

No other new keys needed — `snackSyncCompleted`, `snackSyncError`, and
`offlineResetSyncStatusButton`/`Title`/`Confirm` all already exist and
still fit.

## Testing

`offline_mode_page_test.dart` currently only fakes `DioClient` (being
removed from this page entirely) — it gets rewritten to mock `SyncQueue`
and `NetworkInfo` and wire a **real** `SyncEngine` to those mocks, exactly
matching the mocking approach already established in
`test/data/sync/sync_engine_test.dart` (`SyncQueue` can't be extended
without a real `Database`, so it's `Mock`-based there too; `SyncEngine`
itself is real so its actual stream-emission logic runs, not a
hand-rolled fake of it).

New/updated coverage:
1. Pending count displayed matches a mocked `SyncQueue.pendingCount()`
   value.
2. Tapping "Синхронизировать сейчас" while `NetworkInfo.isConnected`
   resolves `false` shows the no-connection snackbar and never invokes
   `processQueue()`.
3. Tapping it while online invokes `processQueue()`; a `completed` status
   drives a success snackbar and an updated "last synced" display; an
   `error` status drives an error snackbar.
4. Toggling "Авто-синхронизация" sets `SyncEngine.autoSyncEnabled` to the
   new value.
5. "Сбросить статус синхронизации" clears the last-synced display; the
   pending count shown is unaffected by the reset.
6. The three existing SPEC.md #15 tests (button copy, non-destructive
   dialog wording, reset confirmation flow) are preserved, adapted to the
   new mocked dependencies and the trimmed dialog body text.

Live verification on the emulator: open Ещё → (settings) → Офлайн-режим
with at least one item genuinely queued (e.g. create something while the
emulator is offline), confirm the real count shows; toggle airplane mode
off, tap "Синхронизировать сейчас", confirm it actually syncs and the
count drops to 0; toggle airplane mode on, tap the button again, confirm
the no-connection snackbar; flip "Авто-синхронизация" off, queue another
item, reconnect, confirm it does *not* auto-sync until toggled back on or
triggered manually.

## Out of scope

- No new online/offline indicator on this screen — the app-wide
  `OfflineBanner` already covers that.
- No changes to `SyncQueue`'s retry/backoff logic, entity-type resolution,
  or conflict resolution.
- No backend changes of any kind — confirmed there is nothing to build.
