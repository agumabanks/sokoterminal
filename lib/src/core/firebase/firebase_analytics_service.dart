import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Analytics service for tracking user events
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  static final instance = FirebaseAnalyticsService._();
  
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);
  
  /// Track sale completed
  Future<void> logSaleCompleted({
    required double amount,
    required int itemCount,
    String? paymentMethod,
  }) async {
    await _analytics.logEvent(
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
    await _analytics.logEvent(
      name: 'refund_issued',
      parameters: {'amount': amount},
    );
  }
  
  /// Track contact synced
  Future<void> logContactSynced({required int count}) async {
    await _analytics.logEvent(
      name: 'contacts_synced',
      parameters: {'count': count},
    );
  }
  
  /// Track template changed
  Future<void> logTemplateChanged({required String templateId}) async {
    await _analytics.logEvent(
      name: 'template_changed',
      parameters: {'template_id': templateId},
    );
  }
  
  /// Track screen view
  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
  
  /// Set user properties
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }
  
  Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
}

/// Provider for analytics service
final firebaseAnalyticsProvider = Provider<FirebaseAnalyticsService>((ref) {
  return FirebaseAnalyticsService.instance;
});
