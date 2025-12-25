import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';

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
      body: (json['notification_text'] ?? '').toString(),
      dateLabel: (json['date'] ?? '').toString(),
      image: json['image']?.toString(),
      data: json['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['data']) : const {},
      isRead: json['is_read'] == true || json['is_read']?.toString() == '1',
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
  NotificationsController(this.ref, this.api) : super(const NotificationsState());
  final Ref ref;
  final SellerApi api;

  Future<void> bootstrap() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await api.updateDeviceToken(token);
        state = state.copyWith(token: token);
      }

      FirebaseMessaging.onMessage.listen((message) {
        load();
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationRoute(message.data);
      });

      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.fetchNotifications();
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
      final items = list
          .whereType<Map>()
          .map((e) => NotificationDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();

      final unreadRes = await api.fetchUnreadNotifications();
      final unreadData = unreadRes.data;
      final unreadCount = unreadData is Map<String, dynamic>
          ? int.tryParse(unreadData['count']?.toString() ?? '') ?? 0
          : 0;

      state = state.copyWith(loading: false, items: items, unreadCount: unreadCount);
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
            item
      ];
      state = state.copyWith(items: updated);
      await refreshUnread();
    } catch (_) {}
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
          )
      ];
      state = state.copyWith(items: updated, unreadCount: 0);
    } catch (_) {}
  }

  Future<void> deleteNotification(String notificationId) async {
    // Optimistically remove from UI
    final updated = state.items.where((i) => i.id != notificationId).toList();
    state = state.copyWith(items: updated);
    
    try {
      await api.deleteNotification(notificationId);
      await refreshUnread();
    } catch (_) {
      // If failed, reload to restore
      await load();
    }
  }

  Future<void> refreshUnread() async {
    try {
      final res = await api.fetchUnreadNotifications();
      final data = res.data;
      final count = data is Map<String, dynamic>
          ? int.tryParse(data['count']?.toString() ?? '') ?? 0
          : 0;
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  void handleTap(NotificationDto notification) {
    _handleNotificationRoute(notification.data);
  }

  void _handleNotificationRoute(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final convoId = data['conversation_id']?.toString();
    if (convoId != null && convoId.isNotEmpty) {
      router.go('/home/more/chat/$convoId');
      return;
    }
    router.go('/home/notifications');
  }
}
