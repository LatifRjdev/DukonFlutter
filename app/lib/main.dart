import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/constants/api_endpoints.dart';
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

  // Start the sync engine to process offline queue when connectivity returns
  sl<SyncEngine>().start();

  // Initialize local notifications
  await sl<NotificationService>().init();
  await sl<NotificationService>().requestPermission();

  runApp(const DokonProApp());
}
