import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/app_providers.dart';
import 'src/core/config/app_config.dart';
import 'src/core/db/app_database.dart';
import 'src/core/storage/secure_storage.dart';
import 'src/core/telemetry/telemetry.dart';
import 'src/core/telemetry/bug_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Telemetry.init();
    await BugLogger.init();
    debugPrint('[Main] Bug monitoring enabled - logs: production_bugs.jsonl');
  } catch (_) {
    // Best effort.
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Main] Firebase initialized successfully');
  } catch (e) {
    debugPrint('[Main] Firebase initialization failed: $e');
  }

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
