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
          final low = items.where((i) {
            final threshold = i.lowStockWarning ?? 5;
            return i.stockEnabled && i.stockQty <= threshold;
          }).toList()
            ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

          if (low.isEmpty) {
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
            child: ListView.separated(
              padding: DesignTokens.paddingScreen,
              itemCount: low.length,
              separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spaceSm),
              itemBuilder: (context, index) {
                final item = low[index];
                final threshold = item.lowStockWarning ?? 5;
                final subtitle = 'Stock ${item.stockQty} • Reorder at $threshold';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DesignTokens.warning,
                      child: const Icon(Icons.warning_amber, color: Colors.white),
                    ),
                    title: Text(item.name),
                    subtitle: Text(subtitle),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load items: $e')),
      ),
    );
  }
}

