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
import '../payment_links/payment_links_screen.dart';
import 'add_product_screen.dart';
import 'product_guide.dart';
import 'dart:convert';
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
  late final _itemsStream = ref.read(appDatabaseProvider).watchItems();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Item item) => switch (_filter) {
    'low' =>
      item.stockEnabled &&
          item.stockQty > 0 &&
          item.stockQty <= (item.lowStockWarning ?? 5),
    'out' => item.stockEnabled && item.stockQty <= 0,
    'online' => item.publishedOnline,
    'shop' => !item.publishedOnline,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Products', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'How to use products',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const SingleChildScrollView(
                child: ProductGuide(replay: true),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'New product',
            style: IconButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => unawaited(_showItemEditor(context, null)),
            icon: const Icon(Icons.add),
          ),
          const SyncStatusBadge(),
        ],
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
                                  await ref
                                      .read(syncServiceProvider)
                                      .pullPosDelta();
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

          StreamBuilder<List<Item>>(
            stream: _itemsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final products = snapshot.data!;
              final low = products
                  .where(
                    (i) =>
                        i.stockEnabled &&
                        i.stockQty > 0 &&
                        i.stockQty <= (i.lowStockWarning ?? 5),
                  )
                  .length;
              final out = products
                  .where((i) => i.stockEnabled && i.stockQty <= 0)
                  .length;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in {
                        'all': 'All (${products.length})',
                        'low': 'Low stock ($low)',
                        'out': 'Out of stock ($out)',
                        'online': 'Online',
                        'shop': 'In my shop',
                      }.entries) ...[
                        if (entry.key != 'all')
                          const SizedBox(width: DesignTokens.spaceXs),
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _filter == entry.key,
                          onSelected: (_) =>
                              setState(() => _filter = entry.key),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Search bar
          Padding(
            padding: DesignTokens.paddingScreen,
            child: TextField(
              controller: _searchController,
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.textPrimary,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search products by name',
                hintStyle: DesignTokens.textBody.copyWith(
                  color: DesignTokens.textTertiary,
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: DesignTokens.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: DesignTokens.borderRadiusMd,
                  borderSide: const BorderSide(
                    color: DesignTokens.dividerSolid,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: DesignTokens.borderRadiusMd,
                  borderSide: const BorderSide(
                    color: DesignTokens.dividerSolid,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: DesignTokens.borderRadiusMd,
                  borderSide: const BorderSide(
                    color: DesignTokens.brandPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Items list
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: _itemsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = (snapshot.data ?? [])
                    .where(
                      (item) =>
                          _matchesFilter(item) &&
                          (_searchQuery.isEmpty ||
                              item.name.toLowerCase().contains(_searchQuery)),
                    )
                    .toList();

                if (items.isEmpty) {
                  if (_searchQuery.isNotEmpty || _filter != 'all') {
                    return _NoMatchingProducts(
                      query: _searchQuery,
                      filter: _filter,
                      onReset: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _filter = 'all';
                        });
                      },
                    );
                  }
                  return _EmptyState(
                    onAddProduct: () =>
                        unawaited(_showItemEditor(context, null)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                  ),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return const ProductGuide();
                    final item = items[index - 1];
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
                      onPaymentLink: () => _generatePaymentLink(item),
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
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

  Future<void> _generatePaymentLink(Item item) async {
    final remoteId = item.remoteId;
    if (remoteId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product must be synced first.')),
        );
      }
      return;
    }
    if (!mounted) return;
    await showGeneratePaymentLinkSheet(
      context,
      ref,
      type: 'product',
      remoteId: remoteId,
      title: item.name,
      defaultAmount: item.price,
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
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProductPreviewScreen(itemId: item.id),
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

  Future<void> _confirmDelete(BuildContext context, Item item) async {
    final permitted = await requireManagerPin(
      context,
      ref,
      reason: 'delete products',
    );
    if (!permitted || !context.mounted) return;
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
                        unawaited(
                          ref
                              .read(syncServiceProvider)
                              .syncCatalogImmediately(),
                        );
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
        if (value) 'media_contract_version': 2,
      },
    );
    unawaited(sync.syncCatalogImmediately());
  }

  void _createAdForItem(Item item) {
    Haptics.selection();
    ref.read(studioProductProvider.notifier).state = item;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StudioScreen()));
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
    if (!hasPhoto) missing.add('cover photo');
    final gallery = item.galleryUrls == null
        ? const []
        : (jsonDecode(item.galleryUrls!) as List);
    if (gallery.length < 3 || gallery.length > 6) {
      missing.add('3–6 gallery photos');
    }
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
    this.onPaymentLink,
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
  final VoidCallback? onPaymentLink;

  @override
  Widget build(BuildContext context) {
    final threshold = item.lowStockWarning ?? 5;
    final outOfStock = item.stockEnabled && item.stockQty <= 0;
    final lowStock =
        item.stockEnabled && item.stockQty > 0 && item.stockQty <= threshold;
    final imageUrl = (item.thumbnailUrl ?? item.imageUrl)?.trim();
    final channelLabel = item.publishedOnline
        ? 'Online + in my shop'
        : 'In my shop';

    final String stockLabel;
    if (outOfStock) {
      stockLabel = 'Out of stock';
    } else if (lowStock) {
      stockLabel = '${item.stockQty} left · low';
    } else {
      stockLabel = item.stockEnabled
          ? '${item.stockQty} in stock'
          : 'Stock not tracked';
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
                const Icon(Icons.edit_outlined, size: 22, color: Colors.white),
                const SizedBox(height: DesignTokens.spaceXs),
                Text(
                  'Edit',
                  style: DesignTokens.textCaption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                const Icon(
                  Icons.preview_outlined,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(height: DesignTokens.spaceXs),
                Text(
                  'Preview',
                  style: DesignTokens.textCaption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Swipe left reveals the same actions as the visible More button.
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.72,
        children: [
          SlidableAction(
            onPressed: (_) => onTap(),
            backgroundColor: const Color(0xff1c5e91),
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onStockTap(),
            backgroundColor: const Color(0xff14623c),
            foregroundColor: Colors.white,
            icon: Icons.inventory_2_outlined,
            label: 'Stock',
          ),
          SlidableAction(
            onPressed: (_) => _showActions(context),
            backgroundColor: const Color(0xff333940),
            foregroundColor: Colors.white,
            icon: Icons.more_horiz,
            label: 'More',
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
        child: Stack(
          children: [
            InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: DesignTokens.borderRadiusMd,
              splashFactory: NoSplash.splashFactory,
              highlightColor: DesignTokens.surfaceGrouped,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSm,
                  vertical: DesignTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'item-image-${item.id}',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: DesignTokens.surfaceGrouped,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? OfflineCachedImage(
                                imageUrl: imageUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: _productFallback(),
                                errorWidget: _productFallback(),
                              )
                            : _productFallback(),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 48),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                          ),
                          const SizedBox(height: DesignTokens.spaceXxs),
                          Padding(
                            padding: const EdgeInsets.only(right: 48),
                            child: Text(
                              item.price.toUgx(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceXxs),
                          Row(
                            children: [
                              Flexible(
                                flex: 4,
                                child: Text(
                                  stockLabel,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: outOfStock
                                        ? const Color(0xffa12222)
                                        : lowStock
                                        ? const Color(0xff815000)
                                        : const Color(0xff14623c),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spaceXs),
                              Flexible(
                                flex: 8,
                                child: Text(
                                  channelLabel,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff51565f),
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
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: DesignTokens.surfaceGrouped,
                  foregroundColor: DesignTokens.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                ),
                tooltip: 'More product actions',
                onPressed: () => _showActions(context),
                icon: const Icon(Icons.more_horiz),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: DesignTokens.surfaceWhite,
            onSurface: DesignTokens.textPrimary,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: DesignTokens.grayMedium.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.textBodyBold.copyWith(
                        color: DesignTokens.textPrimary,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ),
                for (final action in <(IconData, String, VoidCallback)>[
                  (Icons.edit_outlined, 'Edit product', onTap),
                  (Icons.inventory_2_outlined, 'Update stock', onStockTap),
                  (
                    Icons.public,
                    item.publishedOnline
                        ? 'Unpublish online'
                        : 'Publish online',
                    () => onToggleOnline(!item.publishedOnline),
                  ),
                  (Icons.visibility_outlined, 'Preview product', onPreview),
                  if (onLongPress != null)
                    (Icons.history, 'Stock history', onLongPress!),
                  if (onPaymentLink != null)
                    (Icons.link, 'Payment link', onPaymentLink!),
                  if (onCreateAd != null)
                    (Icons.campaign_outlined, 'Create an ad', onCreateAd!),
                  if (onDesignInStudio != null)
                    (
                      Icons.design_services_outlined,
                      'Open Studio',
                      onDesignInStudio!,
                    ),
                  (Icons.delete_outline, 'Delete product', onDelete),
                ])
                  ListTile(
                    minVerticalPadding: 12,
                    leading: Icon(
                      action.$1,
                      color: action.$2 == 'Delete product'
                          ? const Color(0xffb42318)
                          : DesignTokens.textSecondary,
                    ),
                    title: Text(
                      action.$2,
                      style: DesignTokens.textBody.copyWith(
                        color: action.$2 == 'Delete product'
                            ? const Color(0xffb42318)
                            : DesignTokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      action.$3();
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
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

class _NoMatchingProducts extends StatelessWidget {
  const _NoMatchingProducts({
    required this.query,
    required this.filter,
    required this.onReset,
  });

  final String query;
  final String filter;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    final title = searching
        ? 'No products found'
        : switch (filter) {
            'out' => 'Nothing is out of stock',
            'low' => 'No low-stock products',
            'online' => 'No online products yet',
            'shop' => 'No in-shop products yet',
            _ => 'No matching products',
          };
    final message = searching
        ? 'Try a shorter name, or clear the search to see your products.'
        : switch (filter) {
            'out' => 'Your products are currently in stock.',
            'low' => 'No products are below their low-stock warning.',
            'online' => 'Products published online will appear here.',
            'shop' => 'Products kept in your shop will appear here.',
            _ => 'Try another filter to see your products.',
          };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DesignTokens.brandPrimary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                searching ? Icons.search_off : Icons.inventory_2_outlined,
                color: DesignTokens.brandPrimary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTokens.textBodyBold.copyWith(
                color: DesignTokens.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(
                searching ? 'Clear search and filters' : 'Show all products',
              ),
            ),
          ],
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
      child: SingleChildScrollView(
        // Empty state can be taller than a short phone (640dp); scroll rather
        // than clipping the "Add Product" action off the bottom.
        child: Padding(
          padding: DesignTokens.paddingScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
