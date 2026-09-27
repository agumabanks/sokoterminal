import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
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
import 'src/core/startup/startup_gate.dart';

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
      debugPrint(
        '[FCM] Sync hint in background — will sync on next foreground',
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use Android's permissionless Photo Picker for every gallery flow. On
  // devices without the native/backported picker, AndroidX falls back to a
  // system document picker that grants access only to the selected media.
  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: DesignTokens.canvas,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: DesignTokens.tabBarBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(StartupGate(initialize: _initializeLocalApp));
}

Future<Widget> _initializeLocalApp() async {
  // Load environment configuration with sensible fallbacks.
  try {
    await dotenv.load(fileName: 'assets/config/.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: 'assets/config/.env.example');
    } catch (_) {
      // AppConfig also supports compile-time and production defaults.
    }
  }
  final config = AppConfig.fromEnv(
    dotenv.isInitialized ? dotenv.env : const {},
  );

  final prefs = await SharedPreferences.getInstance().timeout(
    const Duration(seconds: 10),
  );
  // Firebase Core is required before AuthController can safely initialize FCM.
  // Keep Remote Config, Analytics and notification setup deferred until after
  // the first frame.
  final firebaseEnabled = await FirebaseRuntime.instance.prepare();
  if (firebaseEnabled) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (error) {
      FirebaseRuntime.instance.disable('Firebase init failed: $error');
    }
  }
  final secureStorage = SecureStorage();
  final database = await AppDatabase.make();

  try {
    // Finish migrations before providers read local data; never launch a second
    // migration writer by timing out this operation and offering Retry.
    await database.customSelect('SELECT 1').get();
  } catch (_) {
    await database.close();
    rethrow;
  }

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStorageProvider.overrideWithValue(secureStorage),
      appDatabaseProvider.overrideWithValue(database),
    ],
    child: SokoSellerApp(initializeServices: _initializeOptionalServices),
  );
}

Future<void> _initializeOptionalServices() async {
  // Initialize error handlers before the legacy logger chains them.
  await _bestEffort(() => CrashlyticsService.instance.init());
  await _bestEffort(() => Telemetry.init());
  await _bestEffort(() => BugLogger.init());
  unawaited(_bestEffort(() => FirebaseAnalyticsService.instance.init()));
  unawaited(_bestEffort(() => RemoteConfigService.instance.init()));
}

Future<void> _bestEffort(Future<dynamic> Function() action) async {
  try {
    await action();
  } catch (error) {
    debugPrint('[Startup] Optional service unavailable: $error');
  }
}
