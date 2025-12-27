import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Crashlytics service for error reporting
class CrashlyticsService {
  CrashlyticsService._();
  static final instance = CrashlyticsService._();
  
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  
  /// Initialize crashlytics and set up error handlers
  Future<void> init() async {
    // Disable in debug mode to avoid noise
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    
    // Pass Flutter errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      _crashlytics.recordFlutterFatalError(errorDetails);
    };
    
    // Pass async errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  /// Record a non-fatal error
  Future<void> recordError(dynamic exception, StackTrace? stack, {String? reason}) async {
    await _crashlytics.recordError(exception, stack, reason: reason);
  }
  
  /// Log a message (appears in crash reports)
  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }
  
  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }
  
  /// Set custom key-value for crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    await _crashlytics.setCustomKey(key, value);
  }
  
  /// Force a test crash (for testing only)
  void testCrash() {
    _crashlytics.crash();
  }
}
