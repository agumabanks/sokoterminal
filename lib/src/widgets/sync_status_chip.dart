import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_providers.dart';
import '../core/db/app_database.dart';

/// A small chip that shows the cloud sync status of an item or service.
///
/// States:
/// - synced + no pending ops  → green cloud check
/// - !synced + no pending ops → grey cloud off (local only)
/// - pending op               → blue cloud with progress indicator
/// - failed/blocked op        → red cloud with warning
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({
    super.key,
    required this.isSynced,
    required this.localId,
  });

  final bool isSynced;
  final String localId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return StreamBuilder<SyncOp?>(
      stream: db.watchSyncOpForLocalId(localId),
      builder: (context, snapshot) {
        final op = snapshot.data;

        // No sync op at all → show based on item.synced flag
        if (op == null) {
          return _buildChip(
            icon: isSynced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: isSynced ? Colors.green : Colors.grey,
            tooltip: isSynced ? 'Online' : 'Local only',
            showPulse: false,
          );
        }

        // Has a sync op → derive state from op status
        switch (op.status) {
          case 'synced':
            return _buildChip(
              icon: Icons.cloud_done_outlined,
              color: Colors.green,
              tooltip: 'Online',
              showPulse: false,
            );
          case 'pending':
            return _buildChip(
              icon: Icons.cloud_upload_outlined,
              color: Colors.blue,
              tooltip: 'Syncing…',
              showPulse: true,
            );
          case 'blocked':
            return _buildChip(
              icon: Icons.cloud_off_outlined,
              color: Colors.red,
              tooltip: 'Sync failed: ${op.lastError ?? 'Blocked'}',
              showPulse: false,
            );
          default:
            return _buildChip(
              icon: Icons.cloud_off_outlined,
              color: Colors.grey,
              tooltip: 'Local only',
              showPulse: false,
            );
        }
      },
    );
  }

  Widget _buildChip({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool showPulse,
  }) {
    final iconWidget = Icon(icon, size: 14, color: color);
    return Tooltip(
      message: tooltip,
      child: showPulse
          ? _PulsingIcon(child: iconWidget, color: color)
          : iconWidget,
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}
