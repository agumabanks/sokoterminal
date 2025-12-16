import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app.dart';
import 'src/core/app_providers.dart';
import 'src/core/config/app_config.dart';
import 'src/core/db/app_database.dart';
import 'src/core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Continue with limited functionality if Firebase options are not set locally.
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
