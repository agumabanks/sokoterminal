import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../app.dart';

/// Handles local/system tray notifications for the seller terminal.
///
/// This is used for two cases:
/// 1. Displaying a system notification when a foreground FCM message arrives
///    (FCM does not show system notifications while the app is in foreground).
/// 2. Displaying a system notification when new database notifications are
///    pulled while the app is running.
///
/// Tap routing goes through [onNotificationTap] -> GoRouter.
class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final _tapController = StreamController<String>.broadcast();
  Stream<String> get onTap => _tapController.stream;

  bool _initialized = false;

  /// Initialize channels and request permissions.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone data for scheduled notifications. Kampala is the
    // primary market; fall back to UTC if the IANA database lookup fails.
    try {
      tz_data.initializeTimeZones();
      final location = tz.getLocation('Africa/Kampala');
      tz.setLocalLocation(location);
    } catch (e) {
      debugPrint('[LocalNotification] timezone init failed: $e; falling back to UTC');
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _backgroundNotificationTapCallback,
    );

    // Request runtime notification permission on Android 13+ (API 33).
    // The manifest already declares POST_NOTIFICATIONS; this triggers the OS
    // dialog on first app launch so local notifications can be shown.
    if (!kIsWeb) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    // Create channels matching the native Kotlin channels so that FCM payloads
    // that include `android_channel_id` land in the correct bucket.
    const androidChannelGroup = AndroidNotificationChannelGroup(
      'soko_seller_group',
      'Soko Seller Terminal',
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannelGroup(androidChannelGroup);

    const channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        'orders_channel',
        'Orders',
        description: 'New orders, order updates and delivery alerts',
        importance: Importance.high,
        groupId: 'soko_seller_group',
      ),
      AndroidNotificationChannel(
        'sync_channel',
        'Sync',
        description: 'Sync hints and background updates',
        importance: Importance.defaultImportance,
        groupId: 'soko_seller_group',
      ),
      AndroidNotificationChannel(
        'general_channel',
        'General',
        description: 'General announcements and admin broadcasts',
        importance: Importance.defaultImportance,
        groupId: 'soko_seller_group',
      ),
      AndroidNotificationChannel(
        'studio_channel',
        'Studio',
        description: 'Smart ad reminders and post suggestions',
        importance: Importance.high,
        groupId: 'soko_seller_group',
      ),
    ];

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Show a local system notification.
  ///
  /// [payload] is passed back on tap and should be a JSON-encoded map of the
  /// notification data so the router can navigate to the correct screen.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String channelId = 'general_channel',
    String? payload,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: _channelDescription(channelId),
      importance: _channelImportance(channelId),
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Schedule a Studio reminder notification.
  ///
  /// [scheduledDate] must be a [tz.TZDateTime]. Passing [matchDateTimeComponents]
  /// as [DateTimeComponents.time] makes the notification repeat daily at the
  /// same wall-clock time.
  Future<void> scheduleStudioReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents matchDateTimeComponents = DateTimeComponents.time,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'studio_channel',
      'Studio',
      channelDescription: 'Smart ad reminders and post suggestions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  /// Cancel a single scheduled notification by [id].
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel Studio reminder notifications.
  ///
  /// If [ids] is provided, only those IDs are cancelled. Otherwise all
  /// notifications whose IDs fall inside the Studio reminder base range
  /// (900000-909999) are cancelled.
  Future<void> cancelStudioReminders({List<int>? ids}) async {
    final toCancel = ids ?? List<int>.generate(10000, (i) => 900000 + i);
    for (final id in toCancel) {
      await _plugin.cancel(id);
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _tapController.add(payload);
    }
  }

  static void _backgroundNotificationTapCallback(
    NotificationResponse response,
  ) {
    // Background taps are handled by the OS launching the app; we rely on
    // getNotificationAppLaunchDetails() in main/init to route after launch.
    if (kDebugMode) {
      debugPrint(
        '[LocalNotification] background tap payload: ${response.payload}',
      );
    }
  }

  /// Check if the app was launched from a local notification tap.
  Future<String?> getLaunchPayload() async {
    if (!_initialized) await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  String _channelName(String id) {
    return switch (id) {
      'orders_channel' => 'Orders',
      'sync_channel' => 'Sync',
      'general_channel' => 'General',
      'studio_channel' => 'Studio',
      _ => 'General',
    };
  }

  String _channelDescription(String id) {
    return switch (id) {
      'orders_channel' => 'New orders, order updates and delivery alerts',
      'sync_channel' => 'Sync hints and background updates',
      'general_channel' => 'General announcements and admin broadcasts',
      'studio_channel' => 'Smart ad reminders and post suggestions',
      _ => 'General announcements',
    };
  }

  Importance _channelImportance(String id) {
    return switch (id) {
      'orders_channel' => Importance.high,
      'sync_channel' => Importance.defaultImportance,
      'general_channel' => Importance.defaultImportance,
      'studio_channel' => Importance.high,
      _ => Importance.defaultImportance,
    };
  }
}

/// Provider for the local notification service singleton.
final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService.instance,
);

/// Wires local notification taps to GoRouter.
///
/// Call this once after the widget tree is ready (e.g. in [SokoSellerApp]).
void configureLocalNotificationTapRouting(WidgetRef ref) {
  LocalNotificationService.instance.onTap.listen((payload) {
    try {
      final router = ref.read(routerProvider);

      // Direct route payloads (e.g. '/studio?product_id=123').
      if (payload.startsWith('/studio')) {
        router.go(payload);
        return;
      }

      // JSON payloads: route Studio notifications explicitly, otherwise fallback
      // to the notifications screen.
      if (payload.startsWith('{')) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['type']?.toString().toLowerCase() == 'studio') {
          final params = <String, String>{
            if (data['product_id'] != null &&
                data['product_id'].toString().isNotEmpty)
              'product_id': data['product_id'].toString(),
            if (data['service_id'] != null &&
                data['service_id'].toString().isNotEmpty)
              'service_id': data['service_id'].toString(),
            if (data['quotation_id'] != null &&
                data['quotation_id'].toString().isNotEmpty)
              'quotation_id': data['quotation_id'].toString(),
            if (data['receipt_id'] != null &&
                data['receipt_id'].toString().isNotEmpty)
              'receipt_id': data['receipt_id'].toString(),
            if (data['brand_kit']?.toString() == '1') 'brand_kit': '1',
            if (data['open_panel'] != null &&
                data['open_panel'].toString().isNotEmpty)
              'open_panel': data['open_panel'].toString(),
          };
          final query = params.entries
              .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
              .join('&');
          router.go(query.isEmpty ? '/studio' : '/studio?$query');
          return;
        }
        router.go('/home/notifications');
        return;
      }

      // Plain route payloads.
      if (payload.isNotEmpty) {
        router.go(payload);
      }
    } catch (e) {
      debugPrint('[LocalNotification] tap routing error: $e');
    }
  });
}
