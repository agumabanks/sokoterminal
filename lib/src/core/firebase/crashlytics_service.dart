import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../telemetry/bug_logger.dart';
import 'firebase_runtime.dart';

/// Firebase Crashlytics service for error reporting
class CrashlyticsService {
  CrashlyticsService._();
  static final instance = CrashlyticsService._();

  FirebaseCrashlytics? _crashlytics;

  FirebaseCrashlytics? get _crashlyticsOrNull {
    if (!FirebaseRuntime.instance.firebaseEnabled) return null;
    return _crashlytics ??= FirebaseCrashlytics.instance;
  }

  /// Initialize crashlytics and set up error handlers
  Future<void> init() async {
    final crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) return;

    // Disable in debug mode to avoid noise
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Pass Flutter errors to Crashlytics + local bug logger for admin upload.
    FlutterError.onError = (errorDetails) {
      crashlytics.recordFlutterFatalError(errorDetails);
      unawaited(
        BugLogger.instance.logCrash(
          error: errorDetails.exception,
          stackTrace: errorDetails.stack ?? StackTrace.current,
        ),
      );
    };

    // Pass async errors to Crashlytics + bug logger.
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      unawaited(
        BugLogger.instance.logCrash(
          error: error,
          stackTrace: stack,
        ),
      );
      return true;
    };
  }

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    final crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) return;
    await crashlytics.recordError(exception, stack, reason: reason);
  }

  /// Log a message (appears in crash reports)
  Future<void> log(String message) async {
    final crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) return;
    await crashlytics.log(message);
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    final crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) return;
    await crashlytics.setUserIdentifier(userId);
  }

  /// Set custom key-value for crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    final crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) return;
    await crashlytics.setCustomKey(key, value);
  }

  /// Force a test crash (for testing only)
  void testCrash() {
    final crashlytics = _crashlyticsOrNull;
    if (crashlytics == null) return;
    crashlytics.crash();
  }
}
