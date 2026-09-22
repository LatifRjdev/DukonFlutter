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
