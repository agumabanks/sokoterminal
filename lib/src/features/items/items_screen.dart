import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/app_providers.dart';
import '../../core/security/manager_approval.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/offline_cached_image.dart';
import '../../widgets/sync_status_badge.dart';
import '../../widgets/sync_status_chip.dart';
import '../ads/studio_editor_launcher.dart';
import '../ads/studio_providers.dart';
import '../ads/studio_screen.dart';
import 'add_product_screen.dart';
import 'stock_history_sheet.dart';
import 'product_preview_screen.dart';

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
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Products', style: DesignTokens.textTitle),
        actions: [
          const SyncStatusBadge(),
        ],
      ),
      floatingActionButton: _RotatingFab(
        onPressed: () => unawaited(_showItemEditor(context, null)),
      ),
      body: Column(
        children: [
          // Shop approval banner
          StreamBuilder<AppSetting?>(
            stream: db.watchAppSetting('shop_verification_status'),
            builder: (context, appSettingSnapshot) {
              return StreamBuilder<BusinessProfile?>(
                stream: db.watchBusinessProfile(),
                builder: (context, profileSnapshot) {
                  final appValue = appSettingSnapshot.data?.valueJson;
                  final profileValue = profileSnapshot.data?.verificationStatus;
                  final isApproved = appValue == '1' || profileValue == 1;
                  if (isApproved) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: DesignTokens.paddingScreen,
                    padding: DesignTokens.paddingMd,
                    decoration: BoxDecoration(
                      color: DesignTokens.warning.withValues(alpha: 0.12),
                      borderRadius: DesignTokens.borderRadiusMd,
                      border: Border.all(
                        color: DesignTokens.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: DesignTokens.warning,
                          size: 20,
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your shop is awaiting admin approval. Online listings will be visible once approved.',
                                style: DesignTokens.textSmall.copyWith(
                                  color: DesignTokens.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  await ref.read(syncServiceProvider).pullPosDelta();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Syncing status…'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  'Tap to refresh',
                                  style: DesignTokens.textSmall.copyWith(
                                    color: DesignTokens.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Search bar
          Padding(
            padding: DesignTokens.paddingScreen,
            child: Container(
              decoration: BoxDecoration(
                color: DesignTokens.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceSm + DesignTokens.spaceXs,
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: DesignTokens.textTertiary),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: DesignTokens.textBody.copyWith(
                          color: DesignTokens.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: DesignTokens.spaceMd - DesignTokens.spaceXxs,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    .where(
                      (item) =>
                          _searchQuery.isEmpty ||
                          item.name.toLowerCase().contains(_searchQuery),
                    )
                    .toList();

                if (items.isEmpty) {
                  return _EmptyState(
                    onAddProduct: () =>
                        unawaited(_showItemEditor(context, null)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemCard(
                      item: item,
                      onTap: () => unawaited(_showItemEditor(context, item)),
                      onPreview: () =>
                          unawaited(_showItemPreview(context, item)),
                      onStockTap: () =>
                          unawaited(_showStockAdjust(context, item)),
                      onDelete: () => _confirmDelete(context, item),
                      onToggleOnline: (v) => _toggleOnline(item, v),
                      onCreateAd: () => _createAdForItem(item),
                      onDesignInStudio: () => unawaited(_designInStudio(item)),
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => StockHistorySheet(itemId: item.id),
                        );
                      },
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
    if (!ok || !context.mounted) return;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(
            existingItem: existingItem,
            startPublishOnline: startPublishOnline,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[ItemsScreen] Error opening editor: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open product editor: $e')),
        );
      }
    }
  }

  Future<void> _showItemPreview(BuildContext context, Item item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductPreviewScreen(itemId: item.id)),
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
                ? stocks.firstWhere(
                    (s) => s.variant == selectedVariant,
                    orElse: () => stocks.first,
                  )
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
                    items: stocks.map((s) {
                      final label = s.variant.trim().isEmpty
                          ? 'Default'
                          : s.variant.replaceAll('-', ' • ');
                      return DropdownMenuItem(
                        value: s.variant,
                        child: Text(label),
                      );
                    }).toList(),
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
                    final appliedDelta =
                        requestedDelta < 0 && current + requestedDelta < 0
                        ? -current
                        : requestedDelta;
                    if (appliedDelta == 0) return;
                    final newStock = current + appliedDelta;

                    try {
                      await db.adjustStockAndEnqueueSync(
                        itemId: item.id,
                        delta: appliedDelta,
                        note: reason,
                        variant: hasVariants ? selectedVariant : null,
                        syncPayload: {
                          'local_id': item.id,
                          if (item.remoteId != null) 'remote_id': item.remoteId,
                          'delta': appliedDelta,
                          'current_stock': newStock,
                          'unit_price': unitPrice,
                          'published': item.publishedOnline ? 1 : 0,
                          if (hasVariants && selectedVariant.trim().isNotEmpty)
                            'variation': selectedVariant.trim(),
                        },
                      );
                      unawaited(sync.syncCatalogImmediately());

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
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Stock adjust failed: $e'),
                            backgroundColor: DesignTokens.error,
                          ),
                        );
                      }
                    }
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
                    final remoteId = item.remoteId;

                    // Remove locally immediately (offline-first), and enqueue remote delete if possible.
                    try {
                      await db.deleteItemAndEnqueueSync(
                        itemId: item.id,
                        remoteId: remoteId,
                      );
                      if (remoteId != null) {
                        unawaited(ref.read(syncServiceProvider).syncCatalogImmediately());
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product deleted'),
                          backgroundColor: DesignTokens.success,
                        ),
                      );
                    } catch (e) {
                      debugPrint('[ItemsDelete] Delete failed: $e');
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete failed: $e'),
                          backgroundColor: DesignTokens.error,
                        ),
                      );
                    }
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
    final ok = await requireManagerPin(
      context,
      ref,
      reason: 'publish products online',
    );
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
    await db.saveItemAndEnqueueSync(
      item: ItemsCompanion(
        id: Value(item.id),
        name: Value(item.name),
        price: Value(item.price),
        stockQty: Value(item.stockQty),
        publishedOnline: Value(value),
        synced: const Value(false),
      ),
      opType: 'item_update',
      syncPayload: {
        'local_id': item.id,
        if (item.remoteId != null) 'remote_id': item.remoteId,
        'name': item.name,
        'unit_price': item.price,
        'current_stock': item.stockQty,
        'published': value ? 1 : 0,
      },
    );
    unawaited(sync.syncCatalogImmediately());
  }

  void _createAdForItem(Item item) {
    Haptics.selection();
    ref.read(studioProductProvider.notifier).state = item;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudioScreen()),
    );
  }

  Future<void> _designInStudio(Item item) async {
    await launchFullStudioWebForProduct(
      context,
      ref,
      item,
      openPanel: 'smart-ads',
    );
  }

  List<String> _missingMarketplaceFields(Item item) {
    final missing = <String>[];
    final hasPhoto = ((item.thumbnailUrl ?? item.imageUrl) ?? '')
        .trim()
        .isNotEmpty;
    if (!hasPhoto) missing.add('photo');
    if ((item.categoryId ?? '').trim().isEmpty) missing.add('category');
    final desc = (item.description ?? '').trim();
    if (desc.isEmpty || desc.length < 10) missing.add('description');
    if (item.shippingDays == null) missing.add('shipping days');
    if (item.shippingFee == null) missing.add('shipping fee');
    return missing;
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onPreview,
    required this.onStockTap,
    required this.onDelete,
    required this.onToggleOnline,
    this.onLongPress,
    this.onCreateAd,
    this.onDesignInStudio,
  });

  final Item item;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onStockTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleOnline;
  final VoidCallback? onLongPress;
  final VoidCallback? onCreateAd;
  final VoidCallback? onDesignInStudio;

  @override
  Widget build(BuildContext context) {
    final threshold = item.lowStockWarning ?? 5;
    final outOfStock = item.stockEnabled && item.stockQty <= 0;
    final lowStock = item.stockEnabled && item.stockQty > 0 && item.stockQty <= threshold;
    final imageUrl = (item.thumbnailUrl ?? item.imageUrl)?.trim();

    final Color stockColor;
    final String stockLabel;
    if (outOfStock) {
      stockColor = DesignTokens.error;
      stockLabel = 'Out';
    } else if (lowStock) {
      stockColor = DesignTokens.warning;
      stockLabel = 'Low';
    } else {
      stockColor = DesignTokens.success;
      stockLabel = 'In Stock';
    }

    return Slidable(
      key: ValueKey(item.id),
      // Swipe right → Edit, Preview
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onTap(),
            backgroundColor: DesignTokens.info,
            foregroundColor: Colors.white,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(DesignTokens.radiusMd),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_outlined, size: 22),
                const SizedBox(height: DesignTokens.spaceXs),
                Text('Edit', style: DesignTokens.textCaption.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => onPreview(),
            backgroundColor: DesignTokens.brandPrimary,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.preview_outlined, size: 22),
                const SizedBox(height: DesignTokens.spaceXs),
                Text('Preview', style: DesignTokens.textCaption.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      // Swipe left → Stock, Delete
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onStockTap(),
            backgroundColor: DesignTokens.success,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 22),
                const SizedBox(height: DesignTokens.spaceXs),
                Text('Stock', style: DesignTokens.textCaption.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: DesignTokens.error,
            foregroundColor: Colors.white,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(DesignTokens.radiusMd),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline, size: 22),
                const SizedBox(height: DesignTokens.spaceXs),
                Text('Delete', style: DesignTokens.textCaption.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
          border: lowStock
              ? Border.all(color: DesignTokens.warning.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: DesignTokens.borderRadiusMd,
                splashFactory: NoSplash.splashFactory,
                highlightColor: DesignTokens.surfaceGrouped,
                child: Padding(
                  padding: DesignTokens.paddingMd,
                  child: Row(
                    children: [
                      Hero(
                        tag: 'item-image-${item.id}',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: DesignTokens.surfaceGrouped,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? OfflineCachedImage(
                                  imageUrl: imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: _productFallback(),
                                  errorWidget: _productFallback(),
                                )
                              : _productFallback(),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceMd),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: DesignTokens.textBody.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: DesignTokens.textPrimary,
                                    ),
                                  ),
                                ),
                                SyncStatusChip(
                                  isSynced: item.synced,
                                  localId: item.id,
                                ),
                              ],
                            ),
                            const SizedBox(height: DesignTokens.spaceXxs),
                            Row(
                              children: [
                                Text(
                                  item.price.toUgx(),
                                  style: DesignTokens.textMono.copyWith(fontSize: 14),
                                ),
                                const SizedBox(width: DesignTokens.spaceMd),
                                GestureDetector(
                                  onTap: onStockTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stockColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      stockLabel,
                                      style: DesignTokens.textCaption.copyWith(
                                        color: stockColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (onCreateAd != null)
              GestureDetector(
                onTap: onCreateAd,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.campaign_outlined,
                    color: DesignTokens.brandPrimary,
                    size: 22,
                  ),
                ),
              ),
            if (onDesignInStudio != null)
              Tooltip(
                message: 'Design in Studio',
                child: GestureDetector(
                  onTap: onDesignInStudio,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.design_services_rounded,
                      color: DesignTokens.brandPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: DesignTokens.spaceMd),
              child: _LiveToggle(
                value: item.publishedOnline,
                onChanged: onToggleOnline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productFallback() {
    return const Icon(
      Icons.inventory_2_outlined,
      color: DesignTokens.textTertiary,
      size: 20,
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
          color: selected
              ? color.withValues(alpha: 0.1)
              : DesignTokens.grayLight.withValues(alpha: 0.3),
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
            const Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: DesignTokens.textTertiary,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No products yet', style: DesignTokens.textHeadline),
            const SizedBox(height: DesignTokens.spaceXs),
            SizedBox(
              width: 260,
              child: Text(
                'Add your products here or sync from your online store',
                style: DesignTokens.textBody.copyWith(
                  color: DesignTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: onAddProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveToggle extends StatelessWidget {
  const _LiveToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        width: 72,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXs),
        decoration: BoxDecoration(
          color: value ? DesignTokens.brandAccent : DesignTokens.grayLight,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: DesignTokens.durationFast,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceXs + DesignTokens.spaceXxs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live',
                    style: DesignTokens.textCaption.copyWith(
                      color: value ? Colors.white : Colors.transparent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Draft',
                    style: DesignTokens.textCaption.copyWith(
                      color: !value ? DesignTokens.grayDark : Colors.transparent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotatingFab extends StatefulWidget {
  const _RotatingFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_RotatingFab> createState() => _RotatingFabState();
}

class _RotatingFabState extends State<_RotatingFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'items-fab',
      onPressed: () {
        setState(() => _pressed = !_pressed);
        widget.onPressed();
      },
      icon: AnimatedRotation(
        turns: _pressed ? 0.5 : 0,
        duration: DesignTokens.durationFast,
        child: const Icon(Icons.add),
      ),
      label: const Text('New Product'),
      backgroundColor: DesignTokens.brandAccent,
    );
  }
}

