import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';

/// Stock Movement History — bottom sheet showing all stock changes for a product.
///
/// Access: long-press any product in ItemsScreen → "View Stock History"
class StockHistorySheet extends ConsumerWidget {
  const StockHistorySheet({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return FutureBuilder<List<InventoryLog>>(
      future: db.getInventoryLogsForItem(itemId),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Stock History', style: DesignTokens.textTitle),
              const SizedBox(height: 12),
              if (logs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No stock movements recorded yet.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      final isPositive = log.delta > 0;
                      final date = DateFormat('dd MMM, HH:mm').format(log.createdAt.toLocal());

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: DesignTokens.paddingMd,
                        decoration: BoxDecoration(
                          color: DesignTokens.surfaceGrouped,
                          borderRadius: DesignTokens.borderRadiusMd,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? DesignTokens.success.withValues(alpha: 0.12)
                                    : DesignTokens.error.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  isPositive ? '+${log.delta}' : '${log.delta}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isPositive ? DesignTokens.success : DesignTokens.error,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.note ?? (isPositive ? 'Stock In' : 'Stock Out'),
                                    style: DesignTokens.textBody,
                                  ),
                                  Text(
                                    date,
                                    style: DesignTokens.textSmall.copyWith(
                                      color: DesignTokens.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
