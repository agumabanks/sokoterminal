import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

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
        onPressed: () => _showItemEditor(context, null),
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
                    onAddProduct: () => _showItemEditor(context, null),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemCard(
                      item: item,
                      onTap: () => _showItemEditor(context, item),
                      onStockTap: () => _showStockAdjust(context, item),
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

  void _showItemEditor(BuildContext context, Item? existingItem) {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem?.price.toStringAsFixed(0) ?? '',
    );
    final stockCtrl = TextEditingController(
      text: existingItem?.stockQty.toString() ?? '0',
    );
    bool publishedOnline = existingItem?.publishedOnline ?? true;
    
    BottomSheetModal.show(
      context: context,
      title: existingItem == null ? 'New Product' : 'Edit Product',
      subtitle: existingItem == null ? 'Add to your catalog' : 'Update product details',
      child: StatefulBuilder(
        builder: (context, setLocalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                hintText: 'E.g., Coffee, Sandwich...',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price (UGX)',
                      hintText: '0',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMd),
                Expanded(
                  child: TextField(
                    controller: stockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stock Qty',
                      hintText: '0',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withOpacity(0.3),
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, color: DesignTokens.grayMedium),
                  const SizedBox(width: DesignTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Publish Online', style: DesignTokens.textBodyBold),
                        Text(
                          'Show on marketplace',
                          style: DesignTokens.textSmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: publishedOnline,
                    onChanged: (v) => setLocalState(() => publishedOnline = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Row(
              children: [
                if (existingItem != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(context, existingItem);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignTokens.error,
                        side: const BorderSide(color: DesignTokens.error),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                if (existingItem != null) const SizedBox(width: DesignTokens.spaceMd),
                Expanded(
                  flex: existingItem != null ? 2 : 1,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text) ?? 0;
                      final stock = int.tryParse(stockCtrl.text) ?? 0;
                      
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a product name')),
                        );
                        return;
                      }
                      
                      final db = ref.read(appDatabaseProvider);
                      if (existingItem == null) {
                        await db.upsertItem(
                          ItemsCompanion.insert(
                            name: name,
                            price: price,
                            stockQty: Value(stock),
                            publishedOnline: Value(publishedOnline),
                            synced: const Value(false),
                          ),
                        );
                      } else {
                        await db.upsertItem(
                          ItemsCompanion(
                            id: Value(existingItem.id),
                            name: Value(name),
                            price: Value(price),
                            stockQty: Value(stock),
                            publishedOnline: Value(publishedOnline),
                            synced: const Value(false),
                          ),
                        );
                      }
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(existingItem == null
                                ? 'Product added!'
                                : 'Product updated!'),
                            backgroundColor: DesignTokens.brandAccent,
                          ),
                        );
                      }
                    },
                    child: Text(existingItem == null ? 'Add Product' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStockAdjust(BuildContext context, Item item) {
    final adjustCtrl = TextEditingController();
    String reason = 'stock_in';
    
    BottomSheetModal.show(
      context: context,
      title: 'Adjust Stock',
      subtitle: item.name,
      child: StatefulBuilder(
        builder: (context, setLocalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withOpacity(0.3),
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Current: ',
                    style: DesignTokens.textBody,
                  ),
                  Text(
                    '${item.stockQty} units',
                    style: DesignTokens.textBodyBold,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
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
                
                final delta = reason == 'stock_in' ? qty : -qty;
                final newStock = item.stockQty + delta;
                
                final db = ref.read(appDatabaseProvider);
                await db.upsertItem(
                  ItemsCompanion(
                    id: Value(item.id),
                    name: Value(item.name),
                    price: Value(item.price),
                    stockQty: Value(newStock < 0 ? 0 : newStock),
                    publishedOnline: Value(item.publishedOnline),
                    synced: const Value(false),
                  ),
                );
                
                await db.recordInventoryMovement(
                  itemId: item.id,
                  delta: delta,
                  note: reason,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Stock adjusted: ${delta > 0 ? '+' : ''}$delta units',
                      ),
                      backgroundColor: DesignTokens.brandAccent,
                    ),
                  );
                }
              },
              child: const Text('Apply Adjustment'),
            ),
          ],
        ),
      ),
    );
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
              color: DesignTokens.error.withOpacity(0.1),
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
                    final isRemoteId = RegExp(r'^\d+$').hasMatch(item.id);

                    // Remove locally immediately (offline-first), and enqueue remote delete if possible.
                    await db.deletePendingItemOps(item.id);
                    await db.deleteItemAndDetach(item.id);

                    if (isRemoteId) {
                      await db.enqueueSync(
                        'item_delete',
                        '{"remote_id":"${item.id}"}',
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
    final db = ref.read(appDatabaseProvider);
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
    required this.onToggleOnline,
  });

  final Item item;
  final VoidCallback onTap;
  final VoidCallback onStockTap;
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
            ? Border.all(color: DesignTokens.warning.withOpacity(0.5))
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
                  color: DesignTokens.grayLight.withOpacity(0.3),
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
                                  ? DesignTokens.warning.withOpacity(0.1)
                                  : DesignTokens.grayLight.withOpacity(0.5),
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
              
              // Online toggle
              Switch(
                value: item.publishedOnline,
                onChanged: onToggleOnline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          color: selected ? color.withOpacity(0.1) : DesignTokens.grayLight.withOpacity(0.3),
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
                color: DesignTokens.brandPrimary.withOpacity(0.1),
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
