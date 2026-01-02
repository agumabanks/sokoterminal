import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/remote_config_service.dart';
import '../inbox/inbox_screen.dart';
import 'notifications_screen.dart';

class NotificationsEntryScreen extends ConsumerWidget {
  const NotificationsEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteConfig = ref.watch(remoteConfigProvider);
    if (remoteConfig.ffUnifiedInbox) {
      return const InboxScreen();
    }
    return const NotificationsScreen();
  }
}

