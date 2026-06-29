import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import 'migration_controller.dart';

class RestorePromptDialog extends ConsumerWidget {
  const RestorePromptDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(migrationProvider);
    final backup = state.pendingBackup;

    if (backup == null) return const SizedBox.shrink();

    final date = DateTime.tryParse(
      backup['created_at']?.toString() ?? '',
    )?.toLocal();
    final dateStr = date != null
        ? DateFormat('MMM d, yyyy HH:mm').format(date)
        : 'Unknown date';
    final counts = backup['data_counts'] as Map<String, dynamic>? ?? {};

    return PopScope(
      canPop: !state.restoring,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        title: Row(
          children: [
            const Icon(
              Icons.cloud_download_outlined,
              color: DesignTokens.brandPrimary,
            ),
            const SizedBox(width: 8),
            const Text('Business Migration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We found your business data from another device. Would you like to restore it now?',
              style: DesignTokens.textBody,
            ),
            const SizedBox(height: 16),
            Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: DesignTokens.borderRadiusSm,
                border: Border.all(color: DesignTokens.grayLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup: ${backup['name'] ?? 'Cloud Backup'}',
                    style: DesignTokens.textBodyBold,
                  ),
                  Text('Saved on: $dateStr', style: DesignTokens.textSmall),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CompactStat(
                        label: 'Products',
                        value: '${counts['products'] ?? 0}',
                      ),
                      _CompactStat(
                        label: 'Customers',
                        value: '${counts['customers'] ?? 0}',
                      ),
                      _CompactStat(
                        label: 'Sales',
                        value: '${counts['transactions'] ?? 0}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: DesignTokens.textSmall.copyWith(
                  color: DesignTokens.error,
                ),
              ),
            ],
            if (state.restoring) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text(
                      'Restoring your business...',
                      style: DesignTokens.textSmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: state.restoring
            ? []
            : [
                TextButton(
                  onPressed: () =>
                      ref.read(migrationProvider.notifier).dismiss(),
                  child: Text(
                    'Start Fresh',
                    style: TextStyle(color: DesignTokens.grayMedium),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final success = await ref
                        .read(migrationProvider.notifier)
                        .restoreBackup(backup['id'] as int);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Business data restored successfully!'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Restore Now'),
                ),
              ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;

  const _CompactStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: DesignTokens.textBodyBold.copyWith(
            color: DesignTokens.brandPrimary,
          ),
        ),
        Text(label, style: DesignTokens.textSmall.copyWith(fontSize: 10)),
      ],
    );
  }
}
