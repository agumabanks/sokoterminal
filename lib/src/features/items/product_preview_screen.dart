import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import 'add_product_screen.dart';

final _previewItemProvider = StreamProvider.family<Item?, String>((ref, itemId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchItemById(itemId);
});

final _previewStocksProvider =
    StreamProvider.family<List<ItemStock>, String>((ref, itemId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchItemStocksForItem(itemId);
});

final _previewNetUnits7dProvider = StreamProvider.family<int, String>((ref, itemId) {
  final db = ref.watch(appDatabaseProvider);
  final since = DateTime.now().toUtc().subtract(const Duration(days: 7));
  return db.watchNetUnitsMovedForItemSince(itemId, since);
});

class ProductPreviewScreen extends ConsumerStatefulWidget {
  const ProductPreviewScreen({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<ProductPreviewScreen> createState() => _ProductPreviewScreenState();
}

class _ProductPreviewScreenState extends ConsumerState<ProductPreviewScreen> {
  final _pageController = PageController();

  int _pageIndex = 0;
  String _selectedVariant = '';
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    ref.listen<AsyncValue<List<ItemStock>>>(
      _previewStocksProvider(widget.itemId),
      (prev, next) {
        final stocks = next.valueOrNull;
        if (stocks == null || stocks.isEmpty) return;
        final variants = _sortedStocks(stocks).map((s) => s.variant).toList();
        if (!variants.contains(_selectedVariant)) {
          final nextVariant = variants.contains('') ? '' : variants.first;
          if (mounted) {
            setState(() => _selectedVariant = nextVariant);
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(_previewItemProvider(widget.itemId));
    final stocksAsync = ref.watch(_previewStocksProvider(widget.itemId));
    final netUnits7dAsync = ref.watch(_previewNetUnits7dProvider(widget.itemId));

    return itemAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: DesignTokens.surface,
        appBar: AppBar(title: Text('Preview', style: DesignTokens.textTitle)),
        body: Center(child: Text('Failed to load product: $e')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            backgroundColor: DesignTokens.surface,
            appBar: AppBar(title: Text('Preview', style: DesignTokens.textTitle)),
            body: const Center(child: Text('Product not found')),
          );
        }

        final stocks = stocksAsync.valueOrNull ?? const <ItemStock>[];
        final selectedStock = _findStock(stocks, _selectedVariant);
        final unitPrice = selectedStock?.price ?? item.price;
        final stockNow = selectedStock?.stockQty ?? item.stockQty;
        final stockEnabled = item.stockEnabled;
        final lowStockThreshold = item.lowStockWarning ?? 5;
        final isLowStock = stockEnabled && stockNow > 0 && stockNow <= lowStockThreshold;
        final isOutOfStock = stockEnabled && stockNow <= 0;
        final netUnits7d = netUnits7dAsync.valueOrNull;
        final isFastMoving = netUnits7d != null && netUnits7d >= 20;

        final imageUris = _buildImageUris(item: item, stock: selectedStock);

        final total = unitPrice * _qty;

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: DesignTokens.surface,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  backgroundColor: DesignTokens.surface,
                  title: Text('Preview', style: DesignTokens.textTitle),
                  pinned: true,
                  expandedHeight: 280,
                  actions: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final ok = await requireManagerPin(
                          context,
                          ref,
                          reason: 'edit products',
                        );
                        if (!ok || !context.mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddProductScreen(existingItem: item),
                          ),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _ImageCarousel(
                      controller: _pageController,
                      pageIndex: _pageIndex,
                      images: imageUris,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      onTap: imageUris.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _ImageGalleryScreen(
                                    images: imageUris,
                                    initialIndex: _pageIndex,
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
                  bottom: TabBar(
                    labelColor: DesignTokens.brandPrimary,
                    unselectedLabelColor: DesignTokens.grayMedium,
                    indicatorColor: DesignTokens.brandPrimary,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Specs'),
                      Tab(text: 'Reviews'),
                      Tab(text: 'Logistics'),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: DesignTokens.paddingScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(item.name, style: DesignTokens.textTitle),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Row(
                          children: [
                            Text(
                              unitPrice.toUgx(),
                              style: DesignTokens.textTitle.copyWith(
                                color: DesignTokens.brandPrimary,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spaceSm),
                            if (isLowStock)
                              _Pill(
                                label: 'LOW STOCK',
                                color: DesignTokens.warning,
                              ),
                            if (isFastMoving)
                              _Pill(
                                label: 'FAST MOVING',
                                color: DesignTokens.info,
                              ),
                            if (isOutOfStock)
                              _Pill(
                                label: 'OUT OF STOCK',
                                color: DesignTokens.error,
                              ),
                            if (item.publishedOnline)
                              _Pill(
                                label: 'ONLINE',
                                color: DesignTokens.brandAccent,
                              ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: DesignTokens.grayMedium,
                            ),
                            const SizedBox(width: DesignTokens.spaceXs),
                            Text(
                              stockEnabled
                                  ? 'Stock: ${stockNow.formatCommas()}'
                                  : 'Stock tracking off',
                              style: DesignTokens.textSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceMd),
                        if (_hasVariants(stocks)) ...[
                          Text('Variants', style: DesignTokens.textSmallBold),
                          const SizedBox(height: DesignTokens.spaceXs),
                          Wrap(
                            spacing: DesignTokens.spaceSm,
                            runSpacing: DesignTokens.spaceSm,
                            children: _sortedStocks(stocks).map((s) {
                              final value = s.variant;
                              final label = value.trim().isEmpty
                                  ? 'Default'
                                  : value.replaceAll('-', ' • ');
                              return ChoiceChip(
                                selected: value == _selectedVariant,
                                label: Text(label),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedVariant = value;
                                    _qty = 1;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _OverviewTab(item: item),
                  _SpecsTab(item: item, stocks: stocks),
                  _ReviewsTab(item: item),
                  _LogisticsTab(item: item),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                padding: DesignTokens.paddingMd,
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceWhite,
                  boxShadow: DesignTokens.shadowMd,
                ),
                child: Row(
                  children: [
                    _QtyStepper(
                      qty: _qty,
                      max: stockEnabled && stockNow > 0 ? stockNow : null,
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                    const SizedBox(width: DesignTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total', style: DesignTokens.textSmall),
                          Text(
                            total.toUgx(),
                            style: DesignTokens.textBodyBold.copyWith(
                              color: DesignTokens.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceMd),
                    ElevatedButton(
                      onPressed: isOutOfStock
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Preview only (no order placed).'),
                                ),
                              );
                            },
                      child: const Text('Add to cart'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<ItemStock> _sortedStocks(List<ItemStock> stocks) {
    final list = [...stocks];
    list.sort((a, b) {
      final av = a.variant.trim();
      final bv = b.variant.trim();
      if (av.isEmpty && bv.isNotEmpty) return -1;
      if (av.isNotEmpty && bv.isEmpty) return 1;
      return av.compareTo(bv);
    });
    return list;
  }

  bool _hasVariants(List<ItemStock> stocks) {
    final meaningful = stocks.where((s) => s.variant.trim().isNotEmpty).length;
    return meaningful > 0;
  }

  ItemStock? _findStock(List<ItemStock> stocks, String variant) {
    for (final s in stocks) {
      if (s.variant == variant) return s;
    }
    if (variant.isEmpty) return null;
    for (final s in stocks) {
      if (s.variant.trim().isEmpty) return s;
    }
    return null;
  }

  List<String> _buildImageUris({required Item item, required ItemStock? stock}) {
    final images = <String>[];
    final seen = <String>{};

    void add(String? v) {
      final value = v?.trim();
      if (value == null || value.isEmpty) return;
      if (seen.add(value)) images.add(value);
    }

    add(stock?.imageUrl);
    add(item.thumbnailUrl);
    add(item.imageUrl);

    for (final g in _decodeStringList(item.galleryUrls)) {
      add(g);
    }

    return images;
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final desc = (item.description ?? '').trim();
    final tags = (item.tags ?? '').trim();
    return ListView(
      padding: DesignTokens.paddingScreen,
      children: [
        _Section(
          title: 'Description',
          child: Text(
            desc.isEmpty ? 'No description yet.' : desc,
            style: DesignTokens.textBody,
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.spaceMd),
          _Section(
            title: 'Tags',
            child: Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: tags
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .map(
                    (t) => Chip(
                      label: Text(t, style: DesignTokens.textSmall),
                      backgroundColor: DesignTokens.grayLight.withValues(alpha: 0.3),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.spaceMd),
        _Section(
          title: 'Online status',
          child: Text(
            item.publishedOnline ? 'Published online' : 'Not published online',
            style: DesignTokens.textBody,
          ),
        ),
      ],
    );
  }
}

class _SpecsTab extends StatelessWidget {
  const _SpecsTab({required this.item, required this.stocks});
  final Item item;
  final List<ItemStock> stocks;

  @override
  Widget build(BuildContext context) {
    final variantCount = stocks.where((s) => s.variant.trim().isNotEmpty).length;
    return ListView(
      padding: DesignTokens.paddingScreen,
      children: [
        _SpecRow(label: 'SKU', value: item.sku),
        _SpecRow(label: 'Barcode', value: item.barcode),
        _SpecRow(label: 'Category', value: item.categoryName ?? item.categoryId),
        _SpecRow(label: 'Brand', value: item.brandName ?? item.brandId),
        _SpecRow(label: 'Unit', value: item.unit),
        _SpecRow(label: 'Weight (kg)', value: item.weight?.toString()),
        _SpecRow(
          label: 'Variants',
          value: variantCount == 0 ? 'None' : '$variantCount',
        ),
      ],
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: DesignTokens.paddingScreen,
      children: [
        _Section(
          title: 'Reviews',
          child: Text(
            'Reviews will appear here once the product is live and customers start buying.',
            style: DesignTokens.textBody,
          ),
        ),
      ],
    );
  }
}

class _LogisticsTab extends StatelessWidget {
  const _LogisticsTab({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: DesignTokens.paddingScreen,
      children: [
        _SpecRow(label: 'Min purchase qty', value: item.minPurchaseQty.toString()),
        _SpecRow(label: 'Shipping days', value: item.shippingDays?.toString()),
        _SpecRow(
          label: 'Shipping fee',
          value: item.shippingFee?.toUgx(),
        ),
        _SpecRow(label: 'Refundable', value: item.refundable ? 'Yes' : 'No'),
        _SpecRow(
          label: 'Cash on delivery',
          value: item.cashOnDelivery ? 'Yes' : 'No',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesignTokens.textSmallBold),
          const SizedBox(height: DesignTokens.spaceSm),
          child,
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final v = value?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: DesignTokens.textBodyBold),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Flexible(
            child: Text(
              (v == null || v.isEmpty) ? '—' : v,
              style: DesignTokens.textBodyMuted,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: DesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DesignTokens.borderRadiusLg,
      ),
      child: Text(
        label,
        style: DesignTokens.textSmallBold.copyWith(color: color),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onChanged,
    this.max,
  });

  final int qty;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDec = qty > 1;
    final canInc = max == null ? true : qty < max!;
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.grayLight.withValues(alpha: 0.25),
        borderRadius: DesignTokens.borderRadiusLg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canDec ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Text('$qty', style: DesignTokens.textBodyBold),
          IconButton(
            onPressed: canInc ? () => onChanged(qty + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  const _ImageCarousel({
    required this.controller,
    required this.pageIndex,
    required this.images,
    required this.onPageChanged,
    required this.onTap,
  });

  final PageController controller;
  final int pageIndex;
  final List<String> images;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImages = images.isNotEmpty;
    return Container(
      color: DesignTokens.surface,
      child: hasImages
          ? Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onTap,
                    child: PageView.builder(
                      controller: controller,
                      onPageChanged: onPageChanged,
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final uri = images[index];
                        final isNetwork = uri.startsWith('http');
                        final file = isNetwork ? null : File(uri);
                        final fileExists = file != null && file.existsSync();
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: DesignTokens.spaceMd,
                            right: DesignTokens.spaceMd,
                            bottom: 44,
                            top: 12,
                          ),
                          child: ClipRRect(
                            borderRadius: DesignTokens.borderRadiusLg,
                            child: isNetwork
                                ? Image.network(uri, fit: BoxFit.cover)
                                : (fileExists
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : _imagePlaceholder()),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  Positioned(
                    left: 8,
                    top: 110,
                    child: _ArrowButton(
                      icon: Icons.chevron_left,
                      onTap: () {
                        if (!controller.hasClients) return;
                        controller.previousPage(
                          duration: DesignTokens.durationFast,
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 110,
                    child: _ArrowButton(
                      icon: Icons.chevron_right,
                      onTap: () {
                        if (!controller.hasClients) return;
                        controller.nextPage(
                          duration: DesignTokens.durationFast,
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == pageIndex
                                ? DesignTokens.brandPrimary
                                : DesignTokens.grayLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          : Center(child: _imagePlaceholder()),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: DesignTokens.grayLight.withValues(alpha: 0.25),
      child: Icon(
        Icons.image_outlined,
        size: 72,
        color: DesignTokens.grayMedium.withValues(alpha: 0.7),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: DesignTokens.shadowSm,
          ),
          child: Icon(icon, size: 32, color: DesignTokens.grayDark),
        ),
      ),
    );
  }
}

class _ImageGalleryScreen extends StatefulWidget {
  const _ImageGalleryScreen({required this.images, required this.initialIndex});
  final List<String> images;
  final int initialIndex;

  @override
  State<_ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<_ImageGalleryScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: widget.images.length,
        itemBuilder: (context, i) {
          final uri = widget.images[i];
          final isNetwork = uri.startsWith('http');
          final file = isNetwork ? null : File(uri);
          final fileExists = file != null && file.existsSync();
          return InteractiveViewer(
            child: Center(
              child: isNetwork
                  ? Image.network(uri, fit: BoxFit.contain)
                  : (fileExists
                        ? Image.file(file, fit: BoxFit.contain)
                        : const Text(
                            'Image not found',
                            style: TextStyle(color: Colors.white),
                          )),
            ),
          );
        },
      ),
    );
  }
}
