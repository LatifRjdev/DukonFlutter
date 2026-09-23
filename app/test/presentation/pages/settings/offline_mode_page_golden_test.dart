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
