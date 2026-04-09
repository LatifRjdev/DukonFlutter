import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'injection.dart';
import 'data/sync/sync_engine.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
