import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../network/dio_client.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _fcmInitialized = false;
  final List<StreamSubscription<dynamic>> _fcmSubscriptions = [];

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap — no-op for now
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dukonpro_channel',
      'DukonPro',
      channelDescription: 'DukonPro notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final delay = scheduledDate.difference(DateTime.now());
    if (delay.isNegative) return;

    Future.delayed(delay, () {
      showNotification(id: id, title: title, body: body, payload: payload);
    });
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> initFcm(DioClient dio, GoRouter router) async {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    // Foreground: FCM delivers silently when the app is open — show manually.
    _fcmSubscriptions.add(
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final n = message.notification;
        if (n != null) {
          showNotification(
            id: message.hashCode,
            title: n.title ?? '',
            body: n.body ?? '',
          );
        }
      }),
    );

    // Token refresh: FCM rotates tokens periodically — re-register with backend.
    _fcmSubscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        final platform =
            defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
        try {
          await dio.post(
            '/users/me/fcm-token',
            data: {'token': token, 'platform': platform},
          );
        } catch (_) {}
      }),
    );

    // Tap from terminated state (app was killed, user tapped notification).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) router.go('/notifications');

    // Tap from background state (app was open, user tapped notification).
    _fcmSubscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((_) => router.go('/notifications')),
    );
  }

  Future<void> disposeFcm() async {
    for (final sub in _fcmSubscriptions) {
      await sub.cancel();
    }
    _fcmSubscriptions.clear();
    _fcmInitialized = false;
  }
}
