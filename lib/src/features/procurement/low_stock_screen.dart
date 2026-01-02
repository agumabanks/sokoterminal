import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';

final lowStockItemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(appDatabaseProvider).watchItems();
});

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(lowStockItemsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Low Stock'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncServiceProvider).syncNow(),
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          final alerts = items.where((i) {
            if (!i.stockEnabled) return false;
            final threshold = i.lowStockWarning ?? 5;
            return i.stockQty <= threshold;
          }).toList()
            ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

          final outOfStock = alerts.where((i) => i.stockQty <= 0).toList();
          final lowStock =
              alerts.where((i) => i.stockQty > 0).toList();

          if (outOfStock.isEmpty && lowStock.isEmpty) {
            return Center(
              child: Padding(
                padding: DesignTokens.paddingScreen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_outlined, size: 56, color: DesignTokens.grayMedium),
                    const SizedBox(height: DesignTokens.spaceMd),
                    Text('All good', style: DesignTokens.textBodyBold),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'No low-stock items right now.',
                      style: DesignTokens.textSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(syncServiceProvider).syncNow(),
            child: ListView(
              padding: DesignTokens.paddingScreen,
              children: [
                if (outOfStock.isNotEmpty) ...[
                  Text('Out of stock', style: DesignTokens.textBodyBold),
                  const SizedBox(height: DesignTokens.spaceSm),
                  ...outOfStock.map((item) {
                    final threshold = item.lowStockWarning ?? 5;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: DesignTokens.error,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text('Out of stock • Reorder at $threshold'),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: DesignTokens.spaceMd),
                ],
                if (lowStock.isNotEmpty) ...[
                  Text('Low stock', style: DesignTokens.textBodyBold),
                  const SizedBox(height: DesignTokens.spaceSm),
                  ...lowStock.map((item) {
                    final threshold = item.lowStockWarning ?? 5;
                    final subtitle = 'Stock ${item.stockQty} • Reorder at $threshold';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: DesignTokens.warning,
                            child: const Icon(
                              Icons.warning_amber,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text(subtitle),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load items: $e')),
      ),
    );
  }
}
