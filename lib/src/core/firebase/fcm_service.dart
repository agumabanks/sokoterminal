import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Cloud Messaging service for push notifications
class FCMService {
  FCMService._();
  static final instance = FCMService._();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _token;
  
  /// Get FCM token
  String? get token => _token;
  
  /// Initialize FCM and request permissions
  Future<void> init() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get token
      _token = await _messaging.getToken();
      debugPrint('[FCM] Token: $_token');
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        debugPrint('[FCM] Token refreshed: $newToken');
        // TODO: Send new token to backend
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    }
  }
  
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    // TODO: Show local notification or update UI
  }
  
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    // TODO: Navigate to relevant screen based on message.data
  }
  
  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }
  
  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Provider for FCM service
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService.instance;
});
