import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/app_providers.dart';
import '../../core/config/build_metadata.dart';
import '../../core/firebase/firebase_runtime.dart';
import '../../core/network/seller_api.dart';
import '../../core/sync/sync_service.dart';

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
      final api = ref.watch(sellerApiProvider);
      return NotificationsController(ref, api)..bootstrap();
    });

class NotificationDto {
  NotificationDto({
    required this.id,
    required this.title,
    required this.body,
    required this.dateLabel,
    required this.image,
    required this.data,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final String dateLabel;
  final String? image;
  final Map<String, dynamic> data;
  final bool isRead;

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? json['notification_text'] ?? '').toString(),
      dateLabel: (json['created_at'] ?? json['date'] ?? '').toString(),
      image: json['image']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : const {},
      isRead:
          json['status'] == 'read' ||
          json['is_read'] == true ||
          json['is_read']?.toString() == '1',
    );
  }
}

class NotificationsState {
  const NotificationsState({
    this.loading = false,
    this.token,
    this.error,
    this.items = const [],
    this.unreadCount = 0,
  });

  final bool loading;
  final String? token;
  final String? error;
  final List<NotificationDto> items;
  final int unreadCount;

  NotificationsState copyWith({
    bool? loading,
    String? token,
    String? error,
    List<NotificationDto>? items,
    int? unreadCount,
  }) {
    return NotificationsState(
      loading: loading ?? this.loading,
      token: token ?? this.token,
      error: error,
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this.ref, this.api)
    : super(const NotificationsState());
  final Ref ref;
  final SellerApi api;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  Future<void> bootstrap() async {
    try {
      final appVersion = BuildMetadata.appVersion;
      if (FirebaseRuntime.instance.firebaseEnabled) {
        final messaging = FirebaseMessaging.instance;
        await messaging.setAutoInitEnabled(true);
        await messaging.requestPermission();
        final token = await messaging.getToken();
        if (token != null) {
          await api.registerDeviceToken(
            token: token,
            platform: BuildMetadata.notificationPlatform(),
            appVersion: appVersion,
          );
          state = state.copyWith(token: token);
        }

        // Refresh token if it changes
        _subscriptions.add(
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
            await api.registerDeviceToken(
              token: newToken,
              platform: BuildMetadata.notificationPlatform(),
              appVersion: appVersion,
            );
            state = state.copyWith(token: newToken);
          }),
        );

        _subscriptions.add(
          FirebaseMessaging.onMessage.listen((message) {
            _ingestForegroundMessage(message);
          }),
        );

        _subscriptions.add(
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
            _ingestForegroundMessage(message, showToast: false);
            _handleNotificationRoute(message.data);
          }),
        );
      }

      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.fetchNotifications();
      final responseData = res.data;

      // Handle new API response structure: {success, data: [...], meta: {...}, unread_count}
      List items = [];
      int unreadCount = 0;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is List) {
          items = responseData['data'] as List;
        }
        unreadCount =
            int.tryParse(responseData['unread_count']?.toString() ?? '') ?? 0;
      }

      final notifications = items
          .whereType<Map>()
          .map((e) => NotificationDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();

      state = state.copyWith(
        loading: false,
        items: notifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await api.markNotificationRead(notificationId);
      final updated = [
        for (final item in state.items)
          if (item.id == notificationId)
            NotificationDto(
              id: item.id,
              title: item.title,
              body: item.body,
              dateLabel: item.dateLabel,
              image: item.image,
              data: item.data,
              isRead: true,
            )
          else
            item,
      ];
      state = state.copyWith(items: updated);
      await refreshUnread();
    } catch (e) {
      debugPrint('markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await api.markAllNotificationsRead();
      final updated = [
        for (final item in state.items)
          NotificationDto(
            id: item.id,
            title: item.title,
            body: item.body,
            dateLabel: item.dateLabel,
            image: item.image,
            data: item.data,
            isRead: true,
          ),
      ];
      state = state.copyWith(items: updated, unreadCount: 0);
    } catch (e) {
      debugPrint('markAllRead failed: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    // Optimistically remove from UI
    final updated = state.items.where((i) => i.id != notificationId).toList();
    state = state.copyWith(items: updated);

    try {
      await api.deleteNotification(notificationId);
      await refreshUnread();
    } catch (e) {
      debugPrint('deleteNotification failed: $e');
      // If failed, reload to restore
      await load();
    }
  }

  Future<void> refreshUnread() async {
    try {
      final res = await api.fetchUnreadNotificationCount();
      final data = res.data;
      final count = data is Map<String, dynamic>
          ? int.tryParse(data['unread_count']?.toString() ?? '') ?? 0
          : 0;
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      debugPrint('refreshUnread failed: $e');
    }
  }

  void handleTap(NotificationDto notification) {
    _handleNotificationRoute(notification.data);
  }

  void _ingestForegroundMessage(
    RemoteMessage message, {
    bool showToast = true,
  }) {
    final data = Map<String, dynamic>.from(message.data);

    // Handle silent sync hints without showing notifications
    if (data['type']?.toString() == 'sync_hint') {
      debugPrint('[Notifications] Sync hint received — triggering delta pull');
      unawaited(ref.read(syncServiceProvider).pullPosDelta());
      return;
    }

    final title =
        message.notification?.title?.trim() ??
        message.data['title']?.toString().trim() ??
        'New notification';
    final body =
        message.notification?.body?.trim() ??
        message.data['body']?.toString().trim() ??
        '';
    final item = NotificationDto(
      id:
          message.messageId ??
          'push_${DateTime.now().microsecondsSinceEpoch.toString()}',
      title: title,
      body: body,
      dateLabel: DateTime.now().toIso8601String(),
      image: null,
      data: data,
      isRead: false,
    );

    final alreadyPresent = state.items.any((n) => n.id == item.id);
    state = state.copyWith(
      items: alreadyPresent ? state.items : [item, ...state.items],
      unreadCount: state.unreadCount + (alreadyPresent ? 0 : 1),
    );

    if (showToast) {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(body.isEmpty ? title : '$title\n$body'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => _handleNotificationRoute(data),
              ),
            ),
          );
      }
    }

    load();
  }

  void _handleNotificationRoute(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final screen = data['screen']?.toString().toLowerCase();
    if (screen == 'bulk_sms') {
      router.go('/home/more/bulk-sms');
      return;
    }
    if (screen == 'sanaa_wallet' ||
        screen == 'seller_wallet' ||
        screen == 'wallet') {
      router.go('/home/more/wallet');
      return;
    }
    final convoId = data['conversation_id']?.toString();
    if (convoId != null && convoId.isNotEmpty) {
      router.go('/home/more/chat/$convoId');
      return;
    }
    router.go('/home/notifications');
  }
}
