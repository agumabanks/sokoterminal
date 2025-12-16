import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(notificationsControllerProvider.notifier).bootstrap(),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.token != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.phonelink_ring),
                title: const Text('Device token registered'),
                subtitle: Text(state.token!),
              ),
            ),
          if (state.error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Notification error'),
                subtitle: Text(state.error!),
              ),
            ),
          ...state.messages.reversed.map(
            (msg) => Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(msg.notification?.title ?? 'Push'),
                subtitle: Text(msg.notification?.body ?? msg.data.toString()),
                trailing: Text(
                  msg.sentTime?.toLocal().toString() ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ),
          if (state.messages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Waiting for notifications...'),
            ),
        ],
      ),
    );
  }
}
