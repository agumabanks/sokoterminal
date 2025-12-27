import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/security/manager_approval.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import 'add_product_screen.dart';

/// Items Screen — Product catalog management.
/// 
/// Redesigned with premium UI following "Steve Jobs standard":
/// - Clean list with sync status
/// - Bottom sheet for add/edit
/// - Quick stock adjust
/// - Search and filter
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Products', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _syncFromSeller(context),
            tooltip: 'Sync from seller',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_showItemEditor(context, null)),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: DesignTokens.brandAccent,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: DesignTokens.paddingScreen,
            child: Container(
              decoration: BoxDecoration(
                color: DesignTokens.surfaceWhite,
                borderRadius: DesignTokens.borderRadiusMd,
                boxShadow: DesignTokens.shadowSm,
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                  prefixIcon: const Icon(Icons.search, color: DesignTokens.grayMedium),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceMd,
                  ),
                ),
              ),
            ),
          ),
          
          // Items list
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: db.watchItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final items = (snapshot.data ?? [])
                    .where((item) => _searchQuery.isEmpty || 
                        item.name.toLowerCase().contains(_searchQuery))
                    .toList();
                
                if (items.isEmpty) {
                  return _EmptyState(
                    onAddProduct: () => unawaited(_showItemEditor(context, null)),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemCard(
                      item: item,
                      onTap: () => unawaited(_showItemEditor(context, item)),
                      onStockTap: () => unawaited(_showStockAdjust(context, item)),
                      onDelete: () => _confirmDelete(context, item),
                      onToggleOnline: (v) => _toggleOnline(item, v),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemEditor(
    BuildContext context,
    Item? existingItem, {
    bool startPublishOnline = false,
  }) async {
    final action = existingItem == null ? 'create products' : 'edit products';
    final ok = await requireManagerPin(context, ref, reason: action);
    if (!ok || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          existingItem: existingItem,
          startPublishOnline: startPublishOnline,
        ),
      ),
    );
  }

  Future<void> _showStockAdjust(BuildContext context, Item item) async {
    final ok = await requireManagerPin(context, ref, reason: 'adjust stock');
    if (!ok || !context.mounted) return;

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    final stocks = await db.getItemStocksForItem(item.id);
    if (!context.mounted) return;

    final hasVariants =
        stocks.length > 1 ||
        (stocks.length == 1 && stocks.first.variant.trim().isNotEmpty);

    final adjustCtrl = TextEditingController();
    String reason = 'stock_in';
    String selectedVariant = '';
    if (hasVariants) {
      final defaultRow = stocks.where((s) => s.variant.trim().isEmpty).toList();
      selectedVariant = defaultRow.isNotEmpty ? '' : stocks.first.variant;
    }

    try {
      await BottomSheetModal.show(
        context: context,
        title: 'Adjust Stock',
        subtitle: item.name,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final selectedStock = hasVariants
                ? stocks.firstWhere((s) => s.variant == selectedVariant)
                : null;
            final current = selectedStock?.stockQty ?? item.stockQty;
            final unitPrice = selectedStock?.price ?? item.price;
            final variantLabel = selectedStock == null
                ? null
                : (selectedStock.variant.trim().isEmpty
                      ? 'Default'
                      : selectedStock.variant.replaceAll('-', ' • '));

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: DesignTokens.paddingMd,
                  decoration: BoxDecoration(
                    color: DesignTokens.grayLight.withValues(alpha: 0.3),
                    borderRadius: DesignTokens.borderRadiusMd,
                  ),
                  child: Column(
                    children: [
                      if (variantLabel != null)
                        Text(variantLabel, style: DesignTokens.textBodyBold),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Current: ', style: DesignTokens.textBody),
                          Text(
                            '$current units',
                            style: DesignTokens.textBodyBold,
                          ),
                        ],
                      ),
                      if (hasVariants)
                        Text(
                          'Price: ${unitPrice.toStringAsFixed(0)}',
                          style: DesignTokens.textSmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                if (hasVariants) ...[
                  Text('Variant', style: DesignTokens.textSmallBold),
                  const SizedBox(height: DesignTokens.spaceXs),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVariant,
                    items: stocks
                        .map((s) {
                          final label = s.variant.trim().isEmpty
                              ? 'Default'
                              : s.variant.replaceAll('-', ' • ');
                          return DropdownMenuItem(
                            value: s.variant,
                            child: Text(label),
                          );
                        })
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => selectedVariant = v);
                    },
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _ReasonChip(
                        label: 'Stock In (+)',
                        selected: reason == 'stock_in',
                        onTap: () => setLocalState(() => reason = 'stock_in'),
                        color: DesignTokens.brandAccent,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: _ReasonChip(
                        label: 'Stock Out (-)',
                        selected: reason == 'stock_out',
                        onTap: () => setLocalState(() => reason = 'stock_out'),
                        color: DesignTokens.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                TextField(
                  controller: adjustCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Enter amount...',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                ElevatedButton(
                  onPressed: () async {
                    final qty = int.tryParse(adjustCtrl.text) ?? 0;
                    if (qty <= 0) return;

                    final requestedDelta = reason == 'stock_in' ? qty : -qty;
                    final appliedDelta = requestedDelta < 0 && current + requestedDelta < 0
                        ? -current
                        : requestedDelta;
                    if (appliedDelta == 0) return;
                    final newStock = current + appliedDelta;

                    await db.recordInventoryMovement(
                      itemId: item.id,
                      delta: appliedDelta,
                      note: reason,
                      variant: hasVariants ? selectedVariant : null,
                    );
                    await db.updateItemFields(
                      item.id,
                      const ItemsCompanion(synced: Value(false)),
                    );

                    await sync.enqueue('stock_adjust', {
                      'local_id': item.id,
                      if (item.remoteId != null) 'remote_id': item.remoteId,
                      'delta': appliedDelta,
                      'current_stock': newStock,
                      'unit_price': unitPrice,
                      'published': item.publishedOnline ? 1 : 0,
                      if (hasVariants && selectedVariant.trim().isNotEmpty)
                        'variation': selectedVariant.trim(),
                    });
                    unawaited(sync.syncNow());

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stock adjusted: ${appliedDelta > 0 ? '+' : ''}$appliedDelta units',
                        ),
                        backgroundColor: DesignTokens.brandAccent,
                      ),
                    );
                  },
                  child: const Text('Apply Adjustment'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      adjustCtrl.dispose();
    }
  }

  void _confirmDelete(BuildContext context, Item item) {
    BottomSheetModal.show(
      context: context,
      title: 'Delete Product?',
      subtitle: 'This action cannot be undone',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: DesignTokens.paddingMd,
            decoration: BoxDecoration(
              color: DesignTokens.error.withValues(alpha: 0.1),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: DesignTokens.error),
                const SizedBox(width: DesignTokens.spaceMd),
                Expanded(
                  child: Text(
                    'You are about to delete "${item.name}". This will remove it from your catalog.',
                    style: DesignTokens.textBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                    final db = ref.read(appDatabaseProvider);
                    final remoteId = item.remoteId ?? int.tryParse(item.id);

                    // Remove locally immediately (offline-first), and enqueue remote delete if possible.
                    await db.deletePendingItemOps(item.id);
                    await db.deleteItemAndDetach(item.id);

                    if (remoteId != null) {
                      await db.enqueueSync(
                        'item_delete',
                        '{"remote_id":"$remoteId"}',
                      );
                      unawaited(ref.read(syncServiceProvider).syncNow());
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Product deleted'),
                        backgroundColor: DesignTokens.brandAccent,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.error,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOnline(Item item, bool value) async {
    final ok =
        await requireManagerPin(context, ref, reason: 'publish products online');
    if (!ok || !mounted) return;

    if (value) {
      final missing = _missingMarketplaceFields(item);
      if (missing.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete ${missing.join(', ')} before publishing online.',
            ),
            backgroundColor: DesignTokens.warning,
          ),
        );
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProductScreen(
                existingItem: item,
                startPublishOnline: true,
              ),
            ),
          ),
        );
        return;
      }
    }

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    await db.upsertItem(
      ItemsCompanion(
        id: Value(item.id),
        name: Value(item.name),
        price: Value(item.price),
        stockQty: Value(item.stockQty),
        publishedOnline: Value(value),
        synced: const Value(false),
      ),
    );
    await _enqueueItemSync(
      sync: sync,
      opType: 'item_update',
      itemId: item.id,
      remoteId: item.remoteId,
      name: item.name,
      price: item.price,
      stockQty: item.stockQty,
      publishedOnline: value,
    );
    unawaited(sync.syncNow());
  }

  List<String> _missingMarketplaceFields(Item item) {
    final missing = <String>[];
    final hasPhoto = ((item.thumbnailUrl ?? item.imageUrl) ?? '').trim().isNotEmpty;
    if (!hasPhoto) missing.add('photo');
    if ((item.categoryId ?? '').trim().isEmpty) missing.add('category');
    final desc = (item.description ?? '').trim();
    if (desc.isEmpty || desc.length < 10) missing.add('description');
    if (item.shippingDays == null) missing.add('shipping days');
    if (item.shippingFee == null) missing.add('shipping fee');
    return missing;
  }

  Future<void> _enqueueItemSync({
    required SyncService sync,
    required String opType,
    required String itemId,
    required int? remoteId,
    required String name,
    required double price,
    required int stockQty,
    required bool publishedOnline,
  }) async {
    final payload = <String, dynamic>{
      'local_id': itemId,
      'name': name,
      'price': price,
      'unit_price': price,
      'stock_qty': stockQty,
      'current_stock': stockQty,
      'published': publishedOnline ? 1 : 0,
    };
    if (remoteId != null) {
      payload['remote_id'] = remoteId;
    }
    await sync.enqueue(opType, payload);
  }

  void _syncFromSeller(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing products from server…')),
    );
    unawaited(() async {
      try {
        await ref.read(syncServiceProvider).pullSellerProducts();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Products updated'),
            backgroundColor: DesignTokens.brandAccent,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onStockTap,
    required this.onDelete,
    required this.onToggleOnline,
  });

  final Item item;
  final VoidCallback onTap;
  final VoidCallback onStockTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleOnline;

  @override
  Widget build(BuildContext context) {
    final lowStock = item.stockQty < 5;
    
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
        border: lowStock
            ? Border.all(color: DesignTokens.warning.withValues(alpha: 0.5))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.borderRadiusMd,
        child: Padding(
          padding: DesignTokens.paddingMd,
          child: Row(
            children: [
              // Product icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight.withValues(alpha: 0.3),
                  borderRadius: DesignTokens.borderRadiusSm,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: DesignTokens.grayMedium,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: DesignTokens.textBodyBold,
                          ),
                        ),
                        if (!item.synced)
                          Icon(
                            Icons.cloud_off,
                            size: 16,
                            color: DesignTokens.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceXxs),
                    Row(
                      children: [
                        Text(
                          'UGX ${item.price.toStringAsFixed(0)}',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.brandAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceMd),
                        GestureDetector(
                          onTap: onStockTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceSm,
                              vertical: DesignTokens.spaceXxs,
                            ),
                            decoration: BoxDecoration(
                              color: lowStock
                                  ? DesignTokens.warning.withValues(alpha: 0.1)
                                  : DesignTokens.grayLight.withValues(alpha: 0.5),
                              borderRadius: DesignTokens.borderRadiusSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory,
                                  size: 12,
                                  color: lowStock
                                      ? DesignTokens.warning
                                      : DesignTokens.grayMedium,
                                ),
                                const SizedBox(width: DesignTokens.spaceXs),
                                Text(
                                  '${item.stockQty}',
                                  style: DesignTokens.textSmall.copyWith(
                                    color: lowStock
                                        ? DesignTokens.warning
                                        : DesignTokens.grayMedium,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: item.publishedOnline,
                    onChanged: onToggleOnline,
                  ),
                  PopupMenuButton<_ItemMenuAction>(
                    tooltip: 'Actions',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (action) {
                      switch (action) {
                        case _ItemMenuAction.edit:
                          onTap();
                          break;
                        case _ItemMenuAction.adjustStock:
                          onStockTap();
                          break;
                        case _ItemMenuAction.delete:
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ItemMenuAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _ItemMenuAction.adjustStock,
                        child: Text('Adjust stock'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: _ItemMenuAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ItemMenuAction { edit, adjustStock, delete }

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : DesignTokens.grayLight.withValues(alpha: 0.3),
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: DesignTokens.textBody.copyWith(
            color: selected ? color : DesignTokens.grayMedium,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddProduct});
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: DesignTokens.paddingLg,
              decoration: BoxDecoration(
                color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: DesignTokens.brandPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text('No products yet', style: DesignTokens.textTitle),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              'Add your first product to start selling',
              style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: onAddProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
