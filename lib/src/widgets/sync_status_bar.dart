import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/sync/sync_status_provider.dart';
import '../core/sync/sync_service.dart';
import '../core/theme/design_tokens.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    if (status.state == SyncState.idle && status.pendingCount == 0) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    IconData icon;
    String label;
    bool showProgress = false;

    switch (status.state) {
      case SyncState.syncing:
        bgColor = Colors.blue.shade700;
        icon = Icons.sync;
        label = status.message ?? 'Syncing your data...';
        showProgress = true;
        break;
      case SyncState.error:
        bgColor = Colors.red.shade700;
        icon = Icons.sync_problem;
        label = 'Sync issue: ${status.message}';
        break;
      case SyncState.offline:
        bgColor = Colors.orange.shade800;
        icon = Icons.cloud_off;
        label = 'Offline: ${status.pendingCount} items waiting to sync';
        break;
      case SyncState.idle:
        if (status.pendingCount > 0) {
          bgColor = Colors.blueGrey;
          icon = Icons.cloud_queue;
          label = '${status.pendingCount} items queued for sync';
        } else {
          return const SizedBox.shrink();
        }
    }

    return GestureDetector(
      onTap: () => ref.read(syncServiceProvider).syncNow(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: 6,
        ),
        decoration: BoxDecoration(color: bgColor),
        child: Row(
          children: [
            if (showProgress)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status.lastSyncTime != null && status.state == SyncState.idle)
              Text(
                'Synced ${DateFormat('HH:mm').format(status.lastSyncTime!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}
