import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/build_metadata.dart';
import '../../core/notifications/local_notification_service.dart';
import '../network/seller_api.dart';
import 'fcm_navigation.dart';
import 'firebase_runtime.dart';

typedef FcmNavigateCallback = void Function(String route);
typedef FcmForegroundBannerCallback = void Function({
  required String title,
  String? body,
  String? actionLabel,
  VoidCallback? onAction,
});
typedef FcmSyncHintCallback = Future<void> Function();

/// Firebase Cloud Messaging service for push notifications.
///
/// This singleton owns all Firebase stream subscriptions and exposes a
/// [foregroundMessages] broadcast stream so UI controllers can react to pushes
/// without creating duplicate listeners.
class FCMService {
  FCMService._();
  static final instance = FCMService._();

  FirebaseMessaging? _messaging;
  String? _token;
  SellerApi? _sellerApi;
  FcmNavigateCallback? _onNavigate;
  FcmForegroundBannerCallback? _onForegroundBanner;
  FcmSyncHintCallback? _onSyncHint;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  final _foregroundMessageController = StreamController<RemoteMessage>.broadcast();

  /// Broadcast stream of FCM messages received while the app is in the foreground.
  /// Consumers (e.g. [NotificationsController]) should listen here rather than
  /// subscribing to [FirebaseMessaging.onMessage] directly to avoid leaks and
  /// duplicate UI (double SnackBars, double navigation).
  Stream<RemoteMessage> get foregroundMessages => _foregroundMessageController.stream;

  FirebaseMessaging? get _messagingOrNull {
    if (!FirebaseRuntime.instance.firebaseEnabled) return null;
    return _messaging ??= FirebaseMessaging.instance;
  }

  String? get token => _token;

  void configureHandlers({
    FcmNavigateCallback? onNavigate,
    FcmForegroundBannerCallback? onForegroundBanner,
    FcmSyncHintCallback? onSyncHint,
  }) {
    _onNavigate = onNavigate;
    _onForegroundBanner = onForegroundBanner;
    _onSyncHint = onSyncHint;
  }

  Future<void> init({SellerApi? sellerApi}) async {
    _sellerApi = sellerApi;
    final messaging = _messagingOrNull;
    if (messaging == null) {
      if (kDebugMode) {
        debugPrint(
          '[FCM] Disabled: ${FirebaseRuntime.instance.disableReason ?? 'unsupported runtime'}',
        );
      }
      return;
    }

    try {
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      _token = await messaging.getToken();
      if (kDebugMode) debugPrint('[FCM] Token obtained');
      if (_token != null) {
        unawaited(_registerTokenWithBackend(_token!));
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        debugPrint('[FCM] Token refreshed');
        unawaited(_registerTokenWithBackend(newToken));
      });

      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      await _openedAppSub?.cancel();
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _handleNotificationTap(initial);
      }
    } catch (e, st) {
      debugPrint('[FCM] Initialization failed: $e\n$st');
      // Do not crash the app if Firebase is partially unavailable.
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final api = _sellerApi;
    if (api == null) return;
    try {
      await api.registerDeviceToken(
        token: token,
        platform: BuildMetadata.notificationPlatform(),
        appVersion: BuildMetadata.appVersion,
      );
      if (kDebugMode) debugPrint('[FCM] Device token registered with backend');
    } catch (e, st) {
      debugPrint('[FCM] Failed to register device token: $e\n$st');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');

    // Emit to broadcast stream so NotificationsController can ingest without
    // creating a duplicate Firebase listener.
    _foregroundMessageController.add(message);

    if (FcmNavigation.shouldTriggerSync(data)) {
      unawaited(_onSyncHint?.call());
    }

    final route = FcmNavigation.routeForMessageData(data);
    final title = FcmNavigation.foregroundTitle(
      data,
      notificationTitle: message.notification?.title,
    );
    final body = FcmNavigation.foregroundBody(
      data,
      notificationBody: message.notification?.body,
    );

    if (title == null && body == null) {
      if (route != null) {
        _onNavigate?.call(route);
      }
      return;
    }

    _onForegroundBanner?.call(
      title: title ?? 'Notification',
      body: body,
      actionLabel: route == null ? null : 'Open',
      onAction: route == null ? null : () => _onNavigate?.call(route),
    );

    // Also post a system-tray local notification so the message is visible
    // when the user is outside the app or on another screen.
    unawaited(
      LocalNotificationService.instance.show(
        id: message.hashCode,
        title: title ?? 'Notification',
        body: body ?? '',
        channelId: _channelForData(data),
        payload: route,
      ),
    );
  }

  String _channelForData(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    final category = data['category']?.toString().toLowerCase() ?? '';
    if (type == 'order' ||
        category == 'order' ||
        category == 'orders' ||
        type == 'marketplace_order') {
      return 'orders_channel';
    }
    if (type == 'sync_hint' ||
        type == 'sync' ||
        type == 'sync_health') {
      return 'sync_channel';
    }
    return 'general_channel';
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    debugPrint('[FCM] Notification tapped: $data');

    if (FcmNavigation.shouldTriggerSync(data)) {
      unawaited(_onSyncHint?.call());
    }

    final route = FcmNavigation.routeForMessageData(data);
    if (route != null) {
      _onNavigate?.call(route);
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    await _foregroundMessageController.close();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedAppSub = null;
    _onNavigate = null;
    _onForegroundBanner = null;
    _onSyncHint = null;
  }

  Future<void> subscribeToTopic(String topic) async {
    final messaging = _messagingOrNull;
    if (messaging == null) return;
    try {
      await messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[FCM] subscribeToTopic failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final messaging = _messagingOrNull;
    if (messaging == null) return;
    try {
      await messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[FCM] unsubscribeFromTopic failed: $e');
    }
  }
}

final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService.instance;
});
