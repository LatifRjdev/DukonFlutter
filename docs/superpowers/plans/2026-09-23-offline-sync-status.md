# Offline Mode Screen — Real Sync Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewire the "Офлайн-режим" settings screen off the nonexistent backend endpoints `/sync/status`/`/sync/trigger` onto the app's existing local `SyncEngine`/`SyncQueue`, and make the "Авто-синхронизация" toggle actually functional instead of decorative.

**Architecture:** No backend work — there is no server-side sync queue to build against (confirmed: `/sync/status`/`/sync/trigger` aren't defined anywhere in `ApiEndpoints` or `api/src/`). `SyncEngine`/`SyncQueue` already exist, are already started at app boot (`main.dart`), and are already consumed correctly by `OfflineBanner` — `OfflineModePage` is rewired to the same pattern. `SyncEngine` gains an `autoSyncEnabled` flag that gates only its automatic on-reconnect path; manual `processQueue()` calls are unaffected.

**Tech Stack:** Flutter, `sqflite` (local sync queue storage), `mocktail`/`flutter_test`, `golden_toolkit`.

**Spec:** `docs/superpowers/specs/2026-09-23-offline-sync-status-design.md`

---

### Task 1: `SyncEngine.autoSyncEnabled` flag

**Files:**
- Modify: `app/lib/data/sync/sync_engine.dart:22` (new field), `:51-61` (`start()` method)
- Test: `app/test/data/sync/sync_engine_test.dart` (extend existing file)

- [ ] **Step 1: Write the failing tests**

In `app/test/data/sync/sync_engine_test.dart`, insert these three tests directly after the existing `test('start() begins polling on connectivity restore', ...)` test (i.e. right before the `test('dispose() closes the broadcast stream...` test):

```dart
  test('autoSyncEnabled defaults to true', () {
    final engine = buildEngine();
    expect(engine.autoSyncEnabled, isTrue);
  });

  test(
      'connectivity restore does not trigger processQueue when '
      'autoSyncEnabled is false', () async {
    final engine = buildEngine();
    engine.autoSyncEnabled = false;
    when(() => queue.getPendingItems())
        .thenAnswer((_) async => [item(operation: 'DELETE')]);
    when(() => dio.delete(any())).thenAnswer(
      (_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 204),
    );

    engine.start();
    connectivityCtrl.add(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => queue.getPendingItems());
    await engine.dispose();
  });

  test(
      'manual processQueue() still runs even when autoSyncEnabled is false',
      () async {
    final engine = buildEngine();
    engine.autoSyncEnabled = false;
    when(() => queue.getPendingItems())
        .thenAnswer((_) async => [item(operation: 'DELETE')]);
    when(() => dio.delete(any())).thenAnswer(
      (_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 204),
    );

    await engine.processQueue();

    verify(() => queue.getPendingItems()).called(1);
    await engine.dispose();
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `app/`): `flutter test test/data/sync/sync_engine_test.dart`

Expected: FAIL — `autoSyncEnabled` is not a defined getter/setter on `SyncEngine` (compile error).

- [ ] **Step 3: Add the flag and gate the connectivity listener**

In `app/lib/data/sync/sync_engine.dart`, change (currently lines 20-22):

```dart
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _disposed = false;
```

to:

```dart
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _disposed = false;

  /// Gates only the automatic on-reconnect path in [start]'s connectivity
  /// listener. Manual [processQueue] calls (this screen's button,
  /// OfflineBanner's "Повторить" link) are never gated by this — it only
  /// controls whether reconnecting the network by itself kicks off a sync.
  bool autoSyncEnabled = true;
```

Then change `start()` (currently lines 51-61, unchanged line numbers since the field was inserted above them — re-locate by matching the exact text below):

```dart
  void start() {
    if (_disposed) return;
    if (_connectivitySubscription != null) return;
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (isConnected) {
          processQueue();
        }
      },
    );
  }
```

to:

```dart
  void start() {
    if (_disposed) return;
    if (_connectivitySubscription != null) return;
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (isConnected && autoSyncEnabled) {
          processQueue();
        }
      },
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/sync/sync_engine_test.dart`

Expected: PASS (all tests in the file, including the 3 new ones and the pre-existing ones — should be 14 total)

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/sync_engine.dart test/data/sync/sync_engine_test.dart
git commit -m "feat(mobile): add autoSyncEnabled flag to SyncEngine"
```

(Run from `app/`.)

---

### Task 2: Load the auto-sync preference at startup

**Files:**
- Modify: `app/lib/main.dart` (add `loadAutoSyncPreference()` after `loadSavedLocale()`; call it in `_runApp()`)
- Test: `app/test/main_test.dart` (extend existing file)

- [ ] **Step 1: Write the failing tests**

In `app/test/main_test.dart`, add this new group after the existing `group('loadSavedLocale', ...)` block (before the closing of `void main() { ... }`):

```dart
  group('loadAutoSyncPreference', () {
    test('defaults to true when nothing has been saved yet', () async {
      SharedPreferences.setMockInitialValues({});

      final enabled = await loadAutoSyncPreference();

      expect(enabled, isTrue);
    });

    test('reads back a previously saved false value', () async {
      // Same key ('offline_auto_sync') OfflineModePage._saveAutoSync() writes.
      SharedPreferences.setMockInitialValues({'offline_auto_sync': false});

      final enabled = await loadAutoSyncPreference();

      expect(enabled, isFalse);
    });

    test('reads back a previously saved true value', () async {
      SharedPreferences.setMockInitialValues({'offline_auto_sync': true});

      final enabled = await loadAutoSyncPreference();

      expect(enabled, isTrue);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `app/`): `flutter test test/main_test.dart`

Expected: FAIL — `loadAutoSyncPreference` is not defined (compile error).

- [ ] **Step 3: Add the function**

In `app/lib/main.dart`, immediately after the existing `loadSavedLocale()` function (which ends with `return Locale(code);\n}` around line 44), add:

```dart

/// Key `offline_mode_page.dart`'s auto-sync toggle writes to. Read at
/// startup so a previously-saved "off" choice actually disables automatic
/// on-reconnect sync from a cold start, not just after revisiting the
/// Offline Mode settings screen.
const _kAutoSyncPrefKey = 'offline_auto_sync';

/// Reads the auto-sync preference saved by the Offline Mode settings
/// screen. Defaults to true, matching that screen's own fallback.
///
/// Extracted as a standalone, SharedPreferences-only function for the same
/// reason as [loadSavedLocale]: unit-testable without pumping a widget tree
/// or touching WidgetsFlutterBinding/Firebase/DI.
Future<bool> loadAutoSyncPreference() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kAutoSyncPrefKey) ?? true;
}
```

Then find this block inside `_runApp()` (near the end of the function):

```dart
  // SPEC.md #14 — read the language saved by the language settings screen
  // so it actually applies on this cold start, instead of always rendering
  // in the hardcoded default regardless of what the user picked and saved.
  final locale = await loadSavedLocale();

  // SyncEngine.start() / dispose() are managed by _AppLifecycleHost so the
  // broadcast StreamController is closed deterministically on teardown.
  runApp(_AppLifecycleHost(child: DukonProApp(locale: locale)));
```

and change it to:

```dart
  // SPEC.md #14 — read the language saved by the language settings screen
  // so it actually applies on this cold start, instead of always rendering
  // in the hardcoded default regardless of what the user picked and saved.
  final locale = await loadSavedLocale();

  // Apply a previously-saved auto-sync preference before SyncEngine.start()
  // (called by _AppLifecycleHost below) attaches its connectivity listener,
  // so a saved "off" choice takes effect from a cold start.
  sl<SyncEngine>().autoSyncEnabled = await loadAutoSyncPreference();

  // SyncEngine.start() / dispose() are managed by _AppLifecycleHost so the
  // broadcast StreamController is closed deterministically on teardown.
  runApp(_AppLifecycleHost(child: DukonProApp(locale: locale)));
```

`SyncEngine` is already imported in `main.dart` (`import 'data/sync/sync_engine.dart';`) and `sl` is already imported (`import 'injection.dart';`) — no new imports needed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/main_test.dart`

Expected: PASS (all tests, including the 3 new ones and the pre-existing `loadSavedLocale` ones — should be 6 total)

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/main_test.dart
git commit -m "feat(mobile): apply saved auto-sync preference at app startup"
```

---

### Task 3: Rewire `OfflineModePage` to real `SyncEngine`/`SyncQueue`/`NetworkInfo`

**Files:**
- Modify: `app/lib/presentation/pages/settings/offline_mode_page.dart` (rewrite the state class's data layer; `build()`'s widget tree is unchanged)
- Test: `app/test/presentation/pages/settings/offline_mode_page_test.dart` (full rewrite)

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `app/test/presentation/pages/settings/offline_mode_page_test.dart` with:

```dart
// Behavioral coverage for the offline mode screen's real sync status wiring
// (found during the 2026-09-22 QA pass — this page called nonexistent
// backend endpoints /sync/status and /sync/trigger; there's no server-side
// sync queue to call, the whole queue is local — SyncQueue/SyncEngine).
// Also preserves SPEC.md #15 coverage (non-destructive reset-button copy),
// adapted to the new mocked dependencies and trimmed dialog body text.
import 'dart:async';

import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/sync/sync_engine.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/settings/offline_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/golden_pump_helper.dart';

// SyncEngine/SyncQueue/NetworkInfo are all mocked so these tests exercise
// only OfflineModePage's own reactive logic (how it renders pendingCount,
// how it reacts to SyncStatus events) without re-exercising SyncEngine's
// internal retry/backoff behavior, which is already covered by
// test/data/sync/sync_engine_test.dart.
class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockSyncQueue extends Mock implements SyncQueue {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late _MockSyncEngine syncEngine;
  late _MockSyncQueue syncQueue;
  late _MockNetworkInfo networkInfo;
  late StreamController<SyncStatus> statusController;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    syncEngine = _MockSyncEngine();
    syncQueue = _MockSyncQueue();
    networkInfo = _MockNetworkInfo();
    statusController = StreamController<SyncStatus>.broadcast();

    when(() => syncEngine.syncStatus).thenAnswer((_) => statusController.stream);
    when(() => syncEngine.processQueue()).thenAnswer((_) async {});
    when(() => syncEngine.autoSyncEnabled = any()).thenReturn(null);
    when(() => syncQueue.pendingCount()).thenAnswer((_) async => 0);
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);

    if (sl.isRegistered<SyncEngine>()) sl.unregister<SyncEngine>();
    if (sl.isRegistered<SyncQueue>()) sl.unregister<SyncQueue>();
    if (sl.isRegistered<NetworkInfo>()) sl.unregister<NetworkInfo>();
    sl.registerSingleton<SyncEngine>(syncEngine);
    sl.registerSingleton<SyncQueue>(syncQueue);
    sl.registerSingleton<NetworkInfo>(networkInfo);
  });

  tearDown(() {
    statusController.close();
    if (sl.isRegistered<SyncEngine>()) sl.unregister<SyncEngine>();
    if (sl.isRegistered<SyncQueue>()) sl.unregister<SyncQueue>();
    if (sl.isRegistered<NetworkInfo>()) sl.unregister<NetworkInfo>();
  });

  Widget page() => const OfflineModePage();

  group('OfflineModePage real sync status', () {
    testWidgets('shows the real pending count from SyncQueue', (tester) async {
      when(() => syncQueue.pendingCount()).thenAnswer((_) async => 3);

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      expect(find.text('3 операций в очереди'), findsOneWidget);
    });

    testWidgets('shows "Всё синхронизировано" when there is nothing pending',
        (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      expect(find.text('Всё синхронизировано'), findsOneWidget);
    });

    testWidgets(
        'tapping "Синхронизировать сейчас" while offline shows a '
        'no-connection snackbar and never calls processQueue()', (tester) async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      await tester.tap(find.text('Синхронизировать сейчас'));
      await tester.pumpAndSettle();

      expect(find.text('Нет подключения к интернету'), findsOneWidget);
      verifyNever(() => syncEngine.processQueue());
    });

    testWidgets(
        'tapping "Синхронизировать сейчас" while online calls processQueue()',
        (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      await tester.tap(find.text('Синхронизировать сейчас'));
      await tester.pumpAndSettle();

      verify(() => syncEngine.processQueue()).called(1);
    });

    testWidgets(
        'a completed sync status updates the pending count, records the '
        'last-synced time, and shows a success snackbar', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      expect(find.textContaining('Синхронизация ещё не выполнялась'),
          findsOneWidget);

      when(() => syncQueue.pendingCount()).thenAnswer((_) async => 0);
      statusController.add(SyncStatus.completed);
      await tester.pumpAndSettle();

      expect(find.text('Синхронизация выполнена'), findsOneWidget);
      expect(find.textContaining('Последняя синхронизация'), findsOneWidget);
    });

    testWidgets(
        'an error sync status refreshes the pending count and shows an '
        'error snackbar', (tester) async {
      when(() => syncQueue.pendingCount()).thenAnswer((_) async => 2);
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      statusController.add(SyncStatus.error);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ошибка синхронизации'), findsOneWidget);
      expect(find.text('2 операций в очереди'), findsOneWidget);
    });

    testWidgets('toggling "Авто-синхронизация" sets SyncEngine.autoSyncEnabled',
        (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verify(() => syncEngine.autoSyncEnabled = false).called(1);
    });
  });

  group('OfflineModePage sync-status reset (SPEC.md #15)', () {
    testWidgets('button label no longer claims to clear a cache', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      expect(find.text('Очистить кэш'), findsNothing);
      expect(find.text('Сбросить статус синхронизации'), findsOneWidget);
    });

    testWidgets(
        'tapping the button shows a confirmation that does not claim data '
        'will be deleted, and no longer claims to reset the pending count',
        (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      await tester.tap(find.text('Сбросить статус синхронизации'));
      await tester.pumpAndSettle();

      expect(find.text('Сбросить статус синхронизации?'), findsOneWidget);
      expect(
        find.text('Отметка времени последней синхронизации будет сброшена '
            'на этом устройстве. Локальные данные не удаляются.'),
        findsOneWidget,
      );
      expect(
        find.text('Все локально кэшированные данные будут удалены. '
            'Данные синхронизированные с сервером останутся.'),
        findsNothing,
      );
    });

    testWidgets(
        'confirming clears the last-synced timestamp, shows the reset-status '
        'snackbar, and leaves the real pending count untouched', (tester) async {
      final syncedAt = DateTime(2026, 1, 1);
      SharedPreferences.setMockInitialValues({
        'last_sync_timestamp': syncedAt.millisecondsSinceEpoch,
      });
      when(() => syncQueue.pendingCount()).thenAnswer((_) async => 5);

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      expect(find.textContaining('Последняя синхронизация'), findsOneWidget);
      expect(find.text('5 операций в очереди'), findsOneWidget);

      await tester.tap(find.text('Сбросить статус синхронизации'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Последняя синхронизация'), findsNothing);
      expect(find.text('Статус синхронизации сброшен'), findsOneWidget);
      expect(find.text('Кэш очищен'), findsNothing);
      // Pending count is a real value from SyncQueue — untouched by reset.
      expect(find.text('5 операций в очереди'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('last_sync_timestamp'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `app/`): `flutter test test/presentation/pages/settings/offline_mode_page_test.dart`

Expected: FAIL — `SyncEngine`/`SyncQueue`/`NetworkInfo` are not registered in `sl` by `OfflineModePage` (it still reads `sl<DioClient>()` today, which isn't registered by this test file, so the page's `_load()` will throw during `sl<DioClient>()` resolution, or the new expectations simply won't match old behavior).

- [ ] **Step 3: Rewrite `offline_mode_page.dart`**

Replace the entire contents of `app/lib/presentation/pages/settings/offline_mode_page.dart` with:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/network_info.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/errors/exceptions.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../data/sync/sync_queue.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class OfflineModePage extends StatefulWidget {
  const OfflineModePage({super.key});

  @override
  State<OfflineModePage> createState() => _OfflineModePageState();
}

class _OfflineModePageState extends State<OfflineModePage> {
  final _syncEngine = sl<SyncEngine>();
  final _syncQueue = sl<SyncQueue>();
  final _networkInfo = sl<NetworkInfo>();
  static const _keyAutoSync = 'offline_auto_sync';

  bool _autoSync = true;
  DateTime? _lastSync;
  int _pendingOps = 0;
  bool _loading = true;
  bool _syncing = false;

  StreamSubscription<SyncStatus>? _syncStatusSub;

  @override
  void initState() {
    super.initState();
    _load();
    _syncStatusSub = _syncEngine.syncStatus.listen(_onSyncStatus);
  }

  @override
  void dispose() {
    _syncStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _autoSync = prefs.getBool(_keyAutoSync) ?? true;

    final lastSyncMs = prefs.getInt('last_sync_timestamp');
    if (lastSyncMs != null) {
      _lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }

    _pendingOps = await _syncQueue.pendingCount();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshPendingCount() async {
    final count = await _syncQueue.pendingCount();
    if (mounted) setState(() => _pendingOps = count);
  }

  Future<void> _recordLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('last_sync_timestamp', now.millisecondsSinceEpoch);
    if (mounted) setState(() => _lastSync = now);
  }

  void _onSyncStatus(SyncStatus status) {
    if (!mounted) return;
    switch (status) {
      case SyncStatus.syncing:
        setState(() => _syncing = true);
        break;
      case SyncStatus.completed:
        _refreshPendingCount();
        _recordLastSync();
        setState(() => _syncing = false);
        AppSnackbar.success(
            context, AppLocalizations.of(context)!.snackSyncCompleted);
        break;
      case SyncStatus.error:
        _refreshPendingCount();
        setState(() => _syncing = false);
        AppSnackbar.error(
          context,
          AppLocalizations.of(context)!
              .snackSyncError('не удалось синхронизировать часть операций'),
        );
        break;
      case SyncStatus.idle:
        setState(() => _syncing = false);
        break;
    }
  }

  Future<void> _manualSync() async {
    final connected = await _networkInfo.isConnected;
    if (!connected) {
      if (mounted) {
        AppSnackbar.error(
            context, mapErrorToUserMessage(const NetworkException()));
      }
      return;
    }
    await _syncEngine.processQueue();
  }

  Future<void> _saveAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, value);
    _syncEngine.autoSyncEnabled = value;
    if (mounted) setState(() => _autoSync = value);
  }

  void _confirmClearCache() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.offlineResetSyncStatusTitle),
        content: Text(l10n.offlineResetSyncStatusBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache();
            },
            child: Text(l10n.offlineResetSyncStatusConfirm,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // This does NOT wipe any local SQLite tables (products/categories/sales,
  // etc.) — those double as the offline-first read source and can hold
  // local writes not yet confirmed by the server (e.g. an offline sale or
  // product created while disconnected), so clearing them here would risk
  // real data loss or breaking offline reads. All this does — and all its
  // label promises — is discard the locally displayed "last synced at"
  // timestamp. The pending-ops count shown on this screen is a live read
  // from the real sync queue (SyncQueue.pendingCount()), not a local value
  // this button can honestly reset.
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_timestamp');
      if (mounted) {
        setState(() { _lastSync = null; });
        AppSnackbar.success(context, AppLocalizations.of(context)!.snackSyncStatusReset);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, mapErrorToUserMessage(e));
      }
    }
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Офлайн-режим'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sync status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _pendingOps == 0
                          ? AppColors.success.withValues(alpha: 0.08)
                          : context.warningBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                      border: Border.all(
                        color: _pendingOps == 0
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _pendingOps == 0
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_upload_outlined,
                              color: _pendingOps == 0
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _pendingOps == 0
                                  ? 'Всё синхронизировано'
                                  : '$_pendingOps операций в очереди',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _pendingOps == 0
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        if (_lastSync != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Последняя синхронизация: ${_formatDate(_lastSync!)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Синхронизация ещё не выполнялась',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Manual sync button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLg)),
                      ),
                      onPressed: _syncing ? null : _manualSync,
                      icon: _syncing
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync),
                      label: Text(
                        _syncing ? 'Синхронизация...' : 'Синхронизировать сейчас',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Settings
                  Text('Настройки',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: const Icon(Icons.sync_outlined,
                                color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Авто-синхронизация',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text('Синхронизировать при подключении к сети',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoSync,
                            onChanged: _saveAutoSync,
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.infoBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'В офлайн-режиме все операции сохраняются локально '
                            'и автоматически синхронизируются при восстановлении '
                            'подключения к интернету.',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clear cache
                  Text('Данные',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLg)),
                      ),
                      onPressed: _confirmClearCache,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(
                          AppLocalizations.of(context)!.offlineResetSyncStatusButton,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/pages/settings/offline_mode_page_test.dart`

Expected: PASS (10 tests total: 7 in the "real sync status" group + 3 in the SPEC.md #15 group)

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze lib/presentation/pages/settings/offline_mode_page.dart lib/data/sync/sync_engine.dart lib/main.dart`

Expected: no new errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/pages/settings/offline_mode_page.dart test/presentation/pages/settings/offline_mode_page_test.dart
git commit -m "fix(mobile): wire Offline Mode screen to real SyncEngine/SyncQueue

Replaces calls to the nonexistent backend endpoints /sync/status and
/sync/trigger with the app's existing local sync system, mirroring
the pattern already proven in OfflineBanner. Also wires the
auto-sync toggle to SyncEngine.autoSyncEnabled so it actually does
something (2026-09-22 QA finding #17)."
```

---

### Task 4: Update the golden test's fake dependencies

**Files:**
- Modify: `app/test/presentation/pages/settings/offline_mode_page_golden_test.dart`

- [ ] **Step 1: Replace the fake `DioClient` with mocked `SyncEngine`/`SyncQueue`/`NetworkInfo`**

Replace the entire contents of `app/test/presentation/pages/settings/offline_mode_page_golden_test.dart` with:

```dart
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/sync/sync_engine.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/settings/offline_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/golden_pump_helper.dart';

// ── Mocks — mirrors offline_mode_page_test.dart's setup ────────────────────

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockSyncQueue extends Mock implements SyncQueue {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});

    final syncEngine = _MockSyncEngine();
    final syncQueue = _MockSyncQueue();
    final networkInfo = _MockNetworkInfo();

    when(() => syncEngine.syncStatus)
        .thenAnswer((_) => const Stream<SyncStatus>.empty());
    when(() => syncQueue.pendingCount()).thenAnswer((_) async => 0);
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);

    if (sl.isRegistered<SyncEngine>()) sl.unregister<SyncEngine>();
    if (sl.isRegistered<SyncQueue>()) sl.unregister<SyncQueue>();
    if (sl.isRegistered<NetworkInfo>()) sl.unregister<NetworkInfo>();
    sl.registerSingleton<SyncEngine>(syncEngine);
    sl.registerSingleton<SyncQueue>(syncQueue);
    sl.registerSingleton<NetworkInfo>(networkInfo);
  });

  tearDown(() {
    if (sl.isRegistered<SyncEngine>()) sl.unregister<SyncEngine>();
    if (sl.isRegistered<SyncQueue>()) sl.unregister<SyncQueue>();
    if (sl.isRegistered<NetworkInfo>()) sl.unregister<NetworkInfo>();
  });

  Widget page() => const OfflineModePage();

  group('OfflineModePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'offline_mode_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'offline_mode_dark');
    });
  });
}
```

- [ ] **Step 2: Run the golden tests to confirm no regeneration is needed**

Run (from `app/`): `flutter test test/presentation/pages/settings/offline_mode_page_golden_test.dart`

Expected: PASS against the existing `offline_mode_light.png`/`offline_mode_dark.png` — the default mocked state (`pendingCount` 0, no `last_sync_timestamp`, `autoSync` true) renders identically to the old default fake-`DioClient` state (which always threw, also yielding `_pendingOps = 0`/no last sync). If this fails, do NOT regenerate the goldens — find and fix the mismatch in Task 3's rewrite instead, since the default rendered state must stay pixel-identical.

- [ ] **Step 3: Commit**

```bash
git add test/presentation/pages/settings/offline_mode_page_golden_test.dart
git commit -m "test(mobile): update Offline Mode golden test for real sync dependencies"
```

---

### Task 5: Fix the reset-button dialog copy

**Files:**
- Modify: `app/lib/l10n/app_ru.arb:525`

- [ ] **Step 1: Update the string**

In `app/lib/l10n/app_ru.arb`, change:

```json
  "offlineResetSyncStatusBody": "Отметка времени последней синхронизации и счётчик операций в очереди будут сброшены на этом устройстве. Локальные данные не удаляются.",
```

to:

```json
  "offlineResetSyncStatusBody": "Отметка времени последней синхронизации будет сброшена на этом устройстве. Локальные данные не удаляются.",
```

- [ ] **Step 2: Regenerate localizations**

Run (from `app/`): `flutter gen-l10n`

Expected: completes without error; `lib/l10n/app_localizations_ru.dart` (generated, do not hand-edit) now contains the trimmed string.

- [ ] **Step 3: Run the full offline-mode test suite to confirm the trimmed text matches Task 3's tests**

Run: `flutter test test/presentation/pages/settings/`

Expected: PASS — Task 3's test `'tapping the button shows a confirmation that does not claim data will be deleted, and no longer claims to reset the pending count'` already asserts the trimmed text exactly, so this should already be green; this step is a final confirmation after regenerating l10n.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations_ru.dart
git commit -m "fix(l10n): stop claiming the reset button clears the pending-ops count

The count is a live read from SyncQueue as of this branch — it can't
be reset without discarding real queued operations, so the dialog
body should no longer promise that."
```

---

### Task 6: Full regression run, live verification, and QA report update

**Files:** None modified except the QA report (manual verification + docs).

- [ ] **Step 1: Run the full app test suite**

Run (from `app/`): `flutter test test/data/sync/ test/main_test.dart test/presentation/pages/settings/`

Expected: all PASS, no regressions.

- [ ] **Step 2: Rebuild and install the debug APK**

```bash
cd app
flutter build apk --debug
adb -s emulator-5554 shell am force-stop com.itlsolutions.dukonpro
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.itlsolutions.dukonpro/.MainActivity
```

- [ ] **Step 3: Log in if the session has expired**

Phone: `+992900111222`, password: `test1234`. Use `adb shell uiautomator dump /sdcard/window_dump.xml` and read back exact widget bounds before tapping — do not estimate tap coordinates from a screenshot preview (it's scaled 900×2000 from the real 1080×2400 device resolution; using preview-pixel coordinates directly is off by a factor of 1.2x).

- [ ] **Step 4: Force the device offline and create a queued operation**

Turn on airplane mode (`adb -s emulator-5554 shell settings put global airplane_mode_on 1` — note this alone doesn't notify the connectivity stream on this emulator image reliably; toggling airplane mode from the quick-settings UI in the running emulator is more reliable, or use the emulator's own network controls). While offline, create something that queues a sync operation (e.g. add a product, or record an expense) — confirm it saves locally without error.

- [ ] **Step 5: Verify the Offline Mode screen shows a real pending count**

Navigate to Ещё → (find the offline mode / settings entry point that opens `OfflineModePage`) and confirm the status card now shows "N операций в очереди" reflecting the real queued item(s), not "Всё синхронизировано".

- [ ] **Step 6: Verify manual sync while offline**

While still offline, tap "Синхронизировать сейчас". Confirm it shows "Нет подключения к интернету" and the pending count does not change.

- [ ] **Step 7: Verify manual sync while online**

Restore connectivity, tap "Синхронизировать сейчас" again. Confirm the pending count drops to 0, the status card switches to "Всё синхронизировано", "Последняя синхронизация" now shows a recent timestamp, and a success snackbar appears.

- [ ] **Step 8: Verify the auto-sync toggle is now functional**

Turn "Авто-синхронизация" off. Go offline, create another queued operation, then reconnect. Confirm it does NOT auto-sync (pending count stays > 0 until you tap "Синхронизировать сейчас" manually). Turn the toggle back on, go offline/online again with a new queued item, and confirm it now DOES auto-sync without a manual tap.

- [ ] **Step 9: Verify the reset button**

With a nonzero pending count showing, tap "Сбросить статус синхронизации" → "Сбросить". Confirm the dialog body no longer mentions the queue counter, "Последняя синхронизация" reverts to "Синхронизация ещё не выполнялась", and the pending count is unchanged (still reflects the real queue).

- [ ] **Step 10: Update the QA report**

In `qa/2026-09-07-manual-test-run/REPORT.md`, find finding #17 ("Офлайн-режим: `/sync/status`/`/sync/trigger` не существуют на бэкенде") in both its detailed writeup and the summary table, mark it ИСПРАВЛЕНО with the commit SHAs from Tasks 1-5, and note the live verification steps above were completed successfully. Also update the session-total tally (currently "17 исправлены... 1 (№17, sync-архитектура) остаётся" from the payroll-deletion fix) to reflect both of this session's originally-open findings now being fixed (18/18).

```bash
git add qa/2026-09-07-manual-test-run/REPORT.md
git commit -m "docs(qa): mark offline sync status finding as fixed"
```

---

## Self-Review Notes

- **Spec coverage:** Architecture (no backend, `autoSyncEnabled` flag) → Task 1. Startup wiring → Task 2. `OfflineModePage` behavior (pending count, last-sync, manual sync online/offline, toggle, reset button) → Task 3. l10n → Task 5. Testing section → Tasks 1, 2, 3, 4. Live verification steps in the spec → Task 6. Out-of-scope items (no new banner, no `SyncQueue` logic changes, no backend) require no task and none were added.
- **No placeholders:** every step shows complete code; no "add error handling" or "similar to Task N" shortcuts.
- **Type consistency:** `autoSyncEnabled` is `bool` everywhere (field declaration, test assertions, `_saveAutoSync`'s assignment). `SyncStatus` enum values (`idle`/`syncing`/`completed`/`error`) used identically across Task 1's engine tests and Task 3's page tests. `_syncQueue.pendingCount()` return type (`Future<int>`) matches usage in both `_load()` and `_refreshPendingCount()`.
