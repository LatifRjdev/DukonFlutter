// ignore_for_file: depend_on_referenced_packages
//
// flutter_local_notifications_platform_interface is a transitive dependency
// (pulled in by flutter_local_notifications, which IS a direct dep). We
// import it directly to install a fake through the plugin's own testing
// seam — see the class docs below.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:dukonpro/core/services/notification_service.dart';

/// `NotificationService` wraps `FlutterLocalNotificationsPlugin`, which
/// resolves its real Android/iOS implementation through a generated plugin
/// registrant that only runs on a device or in an integration test — never
/// in a plain `flutter test` unit run. Left completely unconfigured,
/// `FlutterLocalNotificationsPlatform.instance` is an uninitialized `late`
/// field, so simply calling any of these methods throws
/// `LateInitializationError` before we get anywhere near the code we want
/// to exercise.
///
/// The plugin's own testing seam is `FlutterLocalNotificationsPlatform`
/// (a `PlatformInterface`, same pattern as path_provider/share_plus): we
/// install a lightweight subclass so the late field has *something*, which
/// lets `NotificationService`'s Android/iOS resolution path run its real
/// (harmless, in-test) no-op branch. That in turn lets us assert on the
/// behavior that *is* observable from here: methods complete without
/// throwing, `requestPermission()` degrees gracefully to `true` when no
/// platform-specific implementation is found, and `cancelAllNotifications()`
/// — which calls straight through to `FlutterLocalNotificationsPlatform
/// .instance.cancelAll()` without going through Android/iOS resolution —
/// can be observed directly via our fake.
///
/// `initFcm`/`FirebaseMessaging` static APIs are NOT covered here: Firebase
/// requires `Firebase.initializeApp()` against a real/mocked platform
/// channel before any `FirebaseMessaging.*` static getter can be touched,
/// which is new test infrastructure beyond this service's own seams. See
/// the report for this gap.
class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  int cancelAllCallCount = 0;

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount++;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      const [];

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => const [];
}

void main() {
  late _FakeNotificationsPlatform fakePlatform;
  late NotificationService service;

  setUp(() {
    fakePlatform = _FakeNotificationsPlatform();
    FlutterLocalNotificationsPlatform.instance = fakePlatform;
    service = NotificationService();
  });

  group('NotificationService.init', () {
    test('completes without throwing on a host with no registered plugin',
        () async {
      await expectLater(service.init(), completes);
    });

    test('is idempotent — calling init twice does not throw', () async {
      await service.init();
      await expectLater(service.init(), completes);
    });
  });

  group('NotificationService.requestPermission', () {
    test('returns true when no platform-specific implementation is resolvable',
        () async {
      // On a bare test VM, resolvePlatformSpecificImplementation<Android...>
      // and <IOS...> both resolve to null since our fake isn't of either
      // concrete type, so the method falls through to `return true`.
      final result = await service.requestPermission();
      expect(result, isTrue);
    });
  });

  group('NotificationService.showNotification', () {
    test('completes without throwing for a minimal notification', () async {
      await expectLater(
        service.showNotification(id: 1, title: 'Title', body: 'Body'),
        completes,
      );
    });

    test('completes without throwing when payload is provided', () async {
      await expectLater(
        service.showNotification(
          id: 2,
          title: 'Title',
          body: 'Body',
          payload: 'debt:sale-1',
        ),
        completes,
      );
    });
  });

  group('NotificationService.cancelNotification', () {
    test('completes without throwing for an arbitrary id', () async {
      await expectLater(service.cancelNotification(42), completes);
    });
  });

  group('NotificationService.cancelAllNotifications', () {
    test('delegates straight through to the platform instance', () async {
      expect(fakePlatform.cancelAllCallCount, 0);

      await service.cancelAllNotifications();

      expect(fakePlatform.cancelAllCallCount, 1);
    });

    test('can be called multiple times, incrementing the platform call count',
        () async {
      await service.cancelAllNotifications();
      await service.cancelAllNotifications();

      expect(fakePlatform.cancelAllCallCount, 2);
    });
  });

  group('NotificationService.scheduleNotification', () {
    test('completes promptly for a date already in the past (no timer armed)',
        () async {
      final past = DateTime.now().subtract(const Duration(days: 1));

      await expectLater(
        service.scheduleNotification(
          id: 10,
          title: 'Title',
          body: 'Body',
          scheduledDate: past,
        ).timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    test('completes promptly for a future date (delayed callback is not awaited)',
        () async {
      final future = DateTime.now().add(const Duration(minutes: 5));

      await expectLater(
        service.scheduleNotification(
          id: 11,
          title: 'Title',
          body: 'Body',
          scheduledDate: future,
        ).timeout(const Duration(seconds: 2)),
        completes,
      );
    });
  });

  group('NotificationService.disposeFcm', () {
    test('is a safe no-op when initFcm was never called', () async {
      await expectLater(service.disposeFcm(), completes);
    });

    test('is idempotent', () async {
      await service.disposeFcm();
      await expectLater(service.disposeFcm(), completes);
    });
  });
}
