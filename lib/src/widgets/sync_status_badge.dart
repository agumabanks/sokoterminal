import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';

/// Sync status enum
enum SyncStatus {
  synced,   // All data synced
  pending,  // Operations waiting to sync
  syncing,  // Currently syncing
  failed,   // Has failed operations
}

/// Provider that watches sync queue status
final syncStatusProvider = StreamProvider<SyncStatusData>((ref) {
  final db = ref.watch(appDatabaseProvider);
  
  // Watch the SyncOps table for changes
  return db.select(db.syncOps).watch().map((ops) {
    final pending = ops.where((o) => o.status == 'pending').length;
    final failed = ops.where((o) => o.status == 'failed' || (o.retryCount ?? 0) > 3).length;
    final total = ops.length;
    
    SyncStatus status;
    if (failed > 0) {
      status = SyncStatus.failed;
    } else if (pending > 0) {
      status = SyncStatus.pending;
    } else {
      status = SyncStatus.synced;
    }
    
    return SyncStatusData(
      status: status,
      pendingCount: pending,
      failedCount: failed,
      totalOps: total,
      ops: ops,
    );
  });
});

/// Data class for sync status
class SyncStatusData {
  const SyncStatusData({
    required this.status,
    required this.pendingCount,
    required this.failedCount,
    required this.totalOps,
    this.ops = const [],
  });
  
  final SyncStatus status;
  final int pendingCount;
  final int failedCount;
  final int totalOps;
  final List<SyncOp> ops;
  
  String get statusText {
    switch (status) {
      case SyncStatus.synced:
        return 'All synced';
      case SyncStatus.pending:
        return '$pendingCount pending';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.failed:
        return '$failedCount failed';
    }
  }
}

/// Compact badge for app bar
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key, this.onTap});
  
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);
    
    return statusAsync.when(
      data: (data) => _buildBadge(context, data, ref),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
  
  Widget _buildBadge(BuildContext context, SyncStatusData data, WidgetRef ref) {
    // Don't show if everything is synced and no pending
    if (data.status == SyncStatus.synced && data.totalOps == 0) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: onTap ?? () => _showSyncDetails(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(data.status),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getIcon(data.status),
            if (data.pendingCount > 0 || data.failedCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                data.failedCount > 0 
                    ? '${data.failedCount}' 
                    : '${data.pendingCount}',
                style: TextStyle(
                  color: _getTextColor(data.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getBackgroundColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return DesignTokens.success.withValues(alpha: 0.15);
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return DesignTokens.warning.withValues(alpha: 0.15);
      case SyncStatus.failed:
        return DesignTokens.error.withValues(alpha: 0.15);
    }
  }
  
  Color _getTextColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return DesignTokens.success;
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return DesignTokens.warning;
      case SyncStatus.failed:
        return DesignTokens.error;
    }
  }
  
  Widget _getIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icon(Icons.cloud_done, size: 16, color: DesignTokens.success);
      case SyncStatus.pending:
        return Icon(Icons.cloud_upload_outlined, size: 16, color: DesignTokens.warning);
      case SyncStatus.syncing:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(DesignTokens.warning),
          ),
        );
      case SyncStatus.failed:
        return Icon(Icons.cloud_off, size: 16, color: DesignTokens.error);
    }
  }
  
  void _showSyncDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const SyncDetailsSheet(),
    );
  }
}

/// Full sync details sheet
class SyncDetailsSheet extends ConsumerWidget {
  const SyncDetailsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);
    final sync = ref.read(syncServiceProvider);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sync Status', style: DesignTokens.textTitle),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Sync Now'),
                      onPressed: () {
                        sync.syncNow();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: statusAsync.when(
                  data: (data) => _buildContent(context, data, ref, scrollController),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildContent(
    BuildContext context, 
    SyncStatusData data, 
    WidgetRef ref,
    ScrollController scrollController,
  ) {
    if (data.totalOps == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_done, size: 64, color: DesignTokens.success),
            const SizedBox(height: 16),
            Text('All data synced', style: DesignTokens.textBodyBold),
            const SizedBox(height: 8),
            Text(
              'Your data is safely backed up',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
            ),
          ],
        ),
      );
    }
    
    // Group ops by status
    final failed = data.ops.where((o) => o.status == 'failed' || (o.retryCount ?? 0) > 3).toList();
    final pending = data.ops.where((o) => o.status == 'pending' && (o.retryCount ?? 0) <= 3).toList();
    
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getSummaryColor(data.status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                data.status == SyncStatus.failed ? Icons.warning_amber : Icons.info_outline,
                color: data.status == SyncStatus.failed ? DesignTokens.error : DesignTokens.brandPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.statusText, style: DesignTokens.textBodyBold),
                    Text(
                      _getSummaryMessage(data),
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Failed Operations', style: DesignTokens.textBodyBold),
          const SizedBox(height: 8),
          ...failed.map((op) => _SyncOpCard(op: op, isFailed: true)),
        ],
        
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Pending Operations', style: DesignTokens.textBodyBold),
          const SizedBox(height: 8),
          ...pending.map((op) => _SyncOpCard(op: op, isFailed: false)),
        ],
      ],
    );
  }
  
  Color _getSummaryColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return DesignTokens.success.withValues(alpha: 0.1);
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return DesignTokens.warning.withValues(alpha: 0.1);
      case SyncStatus.failed:
        return DesignTokens.error.withValues(alpha: 0.1);
    }
  }
  
  String _getSummaryMessage(SyncStatusData data) {
    if (data.failedCount > 0) {
      return 'Some operations could not be synced. Check your connection.';
    } else if (data.pendingCount > 0) {
      return 'Waiting for network to sync ${data.pendingCount} operations.';
    }
    return 'All operations completed successfully.';
  }
}

class _SyncOpCard extends StatelessWidget {
  const _SyncOpCard({required this.op, required this.isFailed});
  
  final SyncOp op;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isFailed 
                    ? DesignTokens.error.withValues(alpha: 0.1)
                    : DesignTokens.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getOpIcon(op.opType),
                color: isFailed ? DesignTokens.error : DesignTokens.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatOpType(op.opType), style: DesignTokens.textBodyBold),
                  if (op.lastError != null && isFailed)
                    Text(
                      op.lastError!,
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'Retry #${op.retryCount ?? 0}',
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                    ),
                ],
              ),
            ),
            if (isFailed)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  // Retry will happen on next sync cycle
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Will retry on next sync')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  IconData _getOpIcon(String opType) {
    if (opType.contains('ledger')) return Icons.receipt_long;
    if (opType.contains('item') || opType.contains('product')) return Icons.inventory_2;
    if (opType.contains('service')) return Icons.handyman;
    if (opType.contains('customer')) return Icons.person;
    if (opType.contains('quotation')) return Icons.description;
    if (opType.contains('template')) return Icons.receipt;
    if (opType.contains('cash')) return Icons.payments;
    return Icons.sync;
  }
  
  String _formatOpType(String opType) {
    return opType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
