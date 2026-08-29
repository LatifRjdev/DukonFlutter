import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/constants/api_endpoints.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/sentry.dart';
import 'injection.dart';
import 'data/sync/sync_engine.dart';
import 'core/services/notification_service.dart';

/// FCM requires a top-level function annotated with vm:entry-point.
/// Called when a push arrives while the app is terminated or backgrounded.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  await initSentryAndRun(_runApp);
}

/// SPEC.md #14 — must match `_keyLanguage` in
/// `presentation/pages/settings/language_settings_page.dart`, the only
/// place this preference is written.
const _kLanguagePrefKey = 'app_language';

/// Reads the language saved by the language settings screen and resolves it
/// to a `Locale` for `MaterialApp.locale` at cold start — the "restart to
/// apply" notice on that screen was previously a lie, since this value was
/// saved but never read back. Defaults to 'ru', matching that screen's own
/// fallback when nothing has been saved yet (e.g. a fresh install).
///
/// Extracted as a standalone, SharedPreferences-only function (no
/// WidgetsFlutterBinding/Firebase/DI dependency) so it's unit-testable
/// without pumping a widget tree.
Future<Locale> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLanguagePrefKey) ?? 'ru';
  return Locale(code);
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp failed: $e');
  }

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

  // Register background message handler before any other FCM setup.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Register FCM token with backend (non-blocking)
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
      try {
        await sl<DioClient>().post(
          '/users/me/fcm-token',
          data: {'token': fcmToken, 'platform': platform},
        );
      } catch (_) {
        // Non-blocking — token registration can fail silently
      }
    }
  } catch (_) {
    // Firebase may not be initialized — skip FCM token registration
  }

  // Wire foreground display, token refresh, and tap navigation.
  try {
    await sl<NotificationService>().initFcm(sl<DioClient>(), AppRouter.router);
  } catch (_) {
    // Gracefully skip if Firebase is not initialised (e.g., missing config files).
  }

  // SPEC.md #14 — read the language saved by the language settings screen
  // so it actually applies on this cold start, instead of always rendering
  // in the hardcoded default regardless of what the user picked and saved.
  final locale = await loadSavedLocale();

  // SyncEngine.start() / dispose() are managed by _AppLifecycleHost so the
  // broadcast StreamController is closed deterministically on teardown.
  runApp(_AppLifecycleHost(child: DukonProApp(locale: locale)));
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
