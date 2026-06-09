import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_runtime.dart';

/// Firebase Analytics service for tracking user events
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  static final instance = FirebaseAnalyticsService._();

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get _analyticsOrNull {
    if (!FirebaseRuntime.instance.firebaseEnabled) return null;
    return _analytics ??= FirebaseAnalytics.instance;
  }

  FirebaseAnalyticsObserver? get observer {
    final analytics = _analyticsOrNull;
    if (analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: analytics);
  }

  Future<void> init() async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.setAnalyticsCollectionEnabled(true);
  }

  /// Track sale completed
  Future<void> logSaleCompleted({
    required double amount,
    required int itemCount,
    String? paymentMethod,
  }) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.logEvent(
      name: 'sale_completed',
      parameters: {
        'amount': amount,
        'item_count': itemCount,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
    );
  }

  /// Track refund issued
  Future<void> logRefundIssued({required double amount}) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.logEvent(
      name: 'refund_issued',
      parameters: {'amount': amount},
    );
  }

  /// Track contact synced
  Future<void> logContactSynced({required int count}) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.logEvent(
      name: 'contacts_synced',
      parameters: {'count': count},
    );
  }

  /// Track template changed
  Future<void> logTemplateChanged({required String templateId}) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.logEvent(
      name: 'template_changed',
      parameters: {'template_id': templateId},
    );
  }

  /// Track screen view
  Future<void> logScreenView(String screenName) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.logScreenView(screenName: screenName);
  }

  /// Set user properties
  Future<void> setUserId(String userId) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.setUserId(id: userId);
  }

  Future<void> setUserProperty(String name, String value) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.setUserProperty(name: name, value: value);
  }

  /// Track custom event
  Future<void> logCustomEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) return;
    await analytics.logEvent(name: name, parameters: parameters);
  }
}

/// Provider for analytics service
final firebaseAnalyticsProvider = Provider<FirebaseAnalyticsService>((ref) {
  return FirebaseAnalyticsService.instance;
});
