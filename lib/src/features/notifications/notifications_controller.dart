import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return NotificationsController(api)..bootstrap();
});

class NotificationsState {
  const NotificationsState({this.token, this.error, this.messages = const []});
  final String? token;
  final String? error;
  final List<RemoteMessage> messages;
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this.api) : super(const NotificationsState());
  final SellerApi api;

  Future<void> bootstrap() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await api.updateDeviceToken(token);
        state = NotificationsState(token: token, messages: state.messages);
      }

      FirebaseMessaging.onMessage.listen((message) {
        final updated = [...state.messages, message];
        state = NotificationsState(token: state.token, messages: updated);
      });
    } catch (e) {
      state = NotificationsState(error: e.toString(), messages: state.messages);
    }
  }
}
