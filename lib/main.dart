import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/app_providers.dart';
import 'src/core/config/app_config.dart';
import 'src/core/db/app_database.dart';
import 'src/core/storage/secure_storage.dart';
import 'src/core/telemetry/telemetry.dart';
import 'src/core/telemetry/bug_logger.dart';
import 'src/core/firebase/crashlytics_service.dart';
import 'src/core/firebase/firebase_analytics_service.dart';
import 'src/core/firebase/firebase_runtime.dart';
import 'src/core/firebase/remote_config_service.dart';
import 'src/core/theme/design_tokens.dart';

/// Top-level background message handler for FCM.
/// Runs in a separate isolate; keep it lightweight.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] Background message: ${message.messageId}');
  }
  final data = message.data;
  if (data['type']?.toString() == 'sync_hint') {
    // Background isolate cannot easily access Riverpod providers / database.
    // The 15-second foreground polling will catch up when the app opens.
    if (kDebugMode) {
      debugPrint('[FCM] Sync hint in background — will sync on next foreground');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: DesignTokens.tabBarBackground,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize Firebase Core first
  final firebaseEnabled = await FirebaseRuntime.instance.prepare();
  if (firebaseEnabled) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Main] Firebase Core initialized');

      // Register background message handler before any other FCM setup
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      debugPrint('[Main] FCM background handler registered');

      await FirebaseAnalyticsService.instance.init();
      debugPrint('[Main] Firebase Analytics initialized');

      // Initialize Crashlytics (error reporting)
      await CrashlyticsService.instance.init();
      debugPrint('[Main] Crashlytics initialized');

      // Initialize Remote Config
      await RemoteConfigService.instance.init();
      debugPrint('[Main] Remote Config initialized');
    } catch (e, stack) {
      FirebaseRuntime.instance.disable('Firebase init failed: $e');
      debugPrint('[Main] Firebase initialization failed: $e');
      // Log to crashlytics if possible
      try {
        await CrashlyticsService.instance.recordError(
          e,
          stack,
          reason: 'Firebase init failed',
        );
      } catch (_) {}
    }
  } else {
    debugPrint(
      '[Main] Skipping Firebase initialization: '
      '${FirebaseRuntime.instance.disableReason ?? 'unsupported runtime'}',
    );
  }

  // Initialize legacy telemetry
  try {
    await Telemetry.init();
    await BugLogger.init();
  } catch (_) {}

  // Load environment configuration with sensible fallbacks.
  try {
    await dotenv.load(fileName: 'assets/config/.env');
  } catch (_) {
    await dotenv.load(fileName: 'assets/config/.env.example');
  }
  final config = AppConfig.fromEnv(dotenv.env);

  final prefs = await SharedPreferences.getInstance();
  final secureStorage = SecureStorage();
  final database = await AppDatabase.make();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(secureStorage),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const SokoSellerApp(),
    ),
  );
}
