// Behavioral coverage for SPEC.md #15 — "Очистить кэш" claimed to clear
// locally cached data but only ever reset a displayed timestamp. Since the
// local product/category/sale tables double as this app's offline-first
// read source and can hold unsynced local writes, wiping them would risk
// real data loss — so the fix renames the button/dialog/snackbar to
// accurately describe what it does (reset the displayed sync status) and
// leaves the underlying behavior (clear `last_sync_timestamp`, reset the
// in-memory pending-ops count) unchanged. These tests prove the new copy
// is what actually renders, and that confirming still performs the reset.
import 'package:dio/dio.dart' show Options, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/settings/offline_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/golden_pump_helper.dart';

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');
}

void main() {
  setUp(() {
    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() => const OfflineModePage();

  group('OfflineModePage sync-status reset (SPEC.md #15)', () {
    testWidgets('button label no longer claims to clear a cache',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      expect(find.text('Очистить кэш'), findsNothing);
      expect(find.text('Сбросить статус синхронизации'), findsOneWidget);
    });

    testWidgets(
        'tapping the button shows a confirmation that does not claim data '
        'will be deleted', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      await tester.tap(find.text('Сбросить статус синхронизации'));
      await tester.pumpAndSettle();

      expect(find.text('Сбросить статус синхронизации?'), findsOneWidget);
      expect(
        find.text('Отметка времени последней синхронизации и счётчик '
            'операций в очереди будут сброшены на этом устройстве. '
            'Локальные данные не удаляются.'),
        findsOneWidget,
      );
      expect(find.text('Все локально кэшированные данные будут удалены. '
          'Данные синхронизированные с сервером останутся.'),
          findsNothing);
    });

    testWidgets(
        'confirming clears the last-synced timestamp and shows the '
        'reset-status snackbar, not the old cache-cleared wording',
        (tester) async {
      final syncedAt = DateTime(2026, 1, 1);
      SharedPreferences.setMockInitialValues({
        'last_sync_timestamp': syncedAt.millisecondsSinceEpoch,
      });

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      // Confirms the pre-reset state actually reflects the seeded
      // timestamp, so the "cleared" assertion below is a real transition.
      expect(find.textContaining('Последняя синхронизация'), findsOneWidget);

      await tester.tap(find.text('Сбросить статус синхронизации'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Последняя синхронизация'), findsNothing);
      expect(find.text('Статус синхронизации сброшен'), findsOneWidget);
      expect(find.text('Кэш очищен'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('last_sync_timestamp'), isNull);
    });
  });
}
