import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/constants/api_endpoints.dart';
import 'core/network/dio_client.dart';
import 'injection.dart';
import 'data/sync/sync_engine.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast on release builds configured with an insecure base URL — prevents
  // shipping a build that still points at the dev loopback or any plain http://
  // endpoint. Pass `--dart-define=API_BASE_URL=https://...` at build time.
  if (kReleaseMode && !ApiEndpoints.baseUrl.startsWith('https://')) {
    throw StateError(
      'Insecure API_BASE_URL in release build: "${ApiEndpoints.baseUrl}". '
      'Pass --dart-define=API_BASE_URL=https://... at build time.',
    );
  }

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize dependency injection (registers all datasources, repos, blocs)
  await initDependencies();

  // Initialize local notifications
  await sl<NotificationService>().init();
  await sl<NotificationService>().requestPermission();

  // Register FCM token with backend (non-blocking)
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      try {
        await sl<DioClient>().post('/users/me/fcm-token', data: {'token': fcmToken});
      } catch (_) {
        // Non-blocking — token registration can fail silently
      }
    }
  } catch (_) {
    // Firebase may not be initialized — skip FCM token registration
  }

  // SyncEngine.start() / dispose() are managed by _AppLifecycleHost so the
  // broadcast StreamController is closed deterministically on teardown.
  runApp(const _AppLifecycleHost(child: DokonProApp()));
}

/// Owns process-lifetime resources that must be bound to the Flutter widget
/// tree — currently the [SyncEngine]. Starting in [initState] and disposing
/// on both `AppLifecycleState.detached` and [State.dispose] closes the
/// broadcast `StreamController` deterministically instead of leaking it for
/// the app's lifetime.
class _AppLifecycleHost extends StatefulWidget {
  const _AppLifecycleHost({required this.child});

  final Widget child;

  @override
  State<_AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends State<_AppLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start the sync engine to process the offline queue when connectivity
    // returns. Idempotent — safe even if something else also called start().
    sl<SyncEngine>().start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Process is about to be torn down — release the broadcast stream.
      sl<SyncEngine>().dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sl<SyncEngine>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
