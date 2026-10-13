import '../../widgets/service_description_article.dart';
import '../payment_links/payment_links_screen.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/offline_cached_image.dart';
import '../ads/studio_editor_launcher.dart';
import 'add_product_screen.dart';
import 'wholesale_pricing.dart';

final _previewItemProvider = StreamProvider.family<Item?, String>((
  ref,
  itemId,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchItemById(itemId);
});

final _previewStocksProvider = StreamProvider.family<List<ItemStock>, String>((
  ref,
  itemId,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchItemStocksForItem(itemId);
});

class ProductPreviewScreen extends ConsumerStatefulWidget {
  const ProductPreviewScreen({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<ProductPreviewScreen> createState() =>
      _ProductPreviewScreenState();
}

class _ProductPreviewScreenState extends ConsumerState<ProductPreviewScreen> {
  final _pageController = PageController();

  int _pageIndex = 0;
  String _selectedVariant = '';

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
    return itemAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        backgroundColor: DesignTokens.surface,
        appBar: AppBar(title: Text('Preview', style: DesignTokens.textTitle)),
        body: Center(child: Text('Failed to load product: $e')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            backgroundColor: DesignTokens.surface,
            appBar: AppBar(
              title: Text('Preview', style: DesignTokens.textTitle),
            ),
            body: const Center(child: Text('Product not found')),
          );
        }

        final stocks = stocksAsync.valueOrNull ?? const <ItemStock>[];
        final selectedStock = _findStock(stocks, _selectedVariant);
        final unitPrice = selectedStock?.price ?? item.price;
        final stockNow = selectedStock?.stockQty ?? item.stockQty;
        final stockEnabled = item.stockEnabled;
        final lowStockThreshold = item.lowStockWarning ?? 5;
        final isLowStock =
            stockEnabled && stockNow > 0 && stockNow <= lowStockThreshold;
        final isOutOfStock = stockEnabled && stockNow <= 0;
        final imageUris = _buildImageUris(item: item, stock: selectedStock);
        final productDetails = <(String, String?)>[
          ('SKU', item.sku),
          ('Barcode', item.barcode),
          ('Category', item.categoryName ?? item.categoryId),
          ('Brand', item.brandName ?? item.brandId),
          ('Unit', item.unit),
        ].where((row) => row.$2?.trim().isNotEmpty == true).toList();
        final deliveryDetails = <(String, String?)>[
          if (item.minPurchaseQty > 1)
            ('Minimum order', '${item.minPurchaseQty} items'),
          if (item.shippingDays != null)
            ('Delivery time', '${item.shippingDays} days'),
          if (item.shippingFee != null)
            ('Delivery fee', item.shippingFee!.toUgx()),
          if (item.cashOnDelivery) ('Cash on delivery', 'Available'),
          if (item.refundable) ('Returns', 'Accepted'),
        ];
        return Scaffold(
          backgroundColor: DesignTokens.surface,
          appBar: AppBar(
            title: Text('Product preview', style: DesignTokens.textTitle),
            actions: [
              IconButton(
                tooltip: 'Edit product',
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
              PopupMenuButton<String>(
                tooltip: 'More product actions',
                onSelected: (action) async {
                  if (action == 'payment') {
                    await showGeneratePaymentLinkSheet(
                      context,
                      ref,
                      type: 'product',
                      remoteId: item.remoteId!,
                      title: item.name,
                      defaultAmount: item.price,
                    );
                  } else {
                    await launchFullStudioWebForProduct(
                      context,
                      ref,
                      item,
                      openPanel: 'smart-ads',
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (item.remoteId != null)
                    const PopupMenuItem(
                      value: 'payment',
                      child: ListTile(
                        leading: Icon(Icons.link),
                        title: Text('Create payment link'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'studio',
                    child: ListTile(
                      leading: Icon(Icons.design_services_outlined),
                      title: Text('Open Studio'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: SizedBox(
                      height: (MediaQuery.sizeOf(context).height * 0.34)
                          .clamp(240.0, 340.0)
                          .toDouble(),
                      child: ClipRRect(
                        borderRadius: DesignTokens.borderRadiusLg,
                        child: _ImageCarousel(
                          controller: _pageController,
                          pageIndex: _pageIndex,
                          images: imageUris,
                          onPageChanged: (i) => setState(() => _pageIndex = i),
                          onTap: imageUris.isEmpty
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _ImageGalleryScreen(
                                      images: imageUris,
                                      initialIndex: _pageIndex,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        item.name,
                        style: DesignTokens.textTitle.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unitPrice.toUgx(),
                        style: DesignTokens.textTitle.copyWith(
                          fontSize: 28,
                          color: DesignTokens.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            label: item.publishedOnline
                                ? 'Online'
                                : 'In my shop',
                            color: item.publishedOnline
                                ? DesignTokens.brandAccent
                                : DesignTokens.grayDark,
                          ),
                          if (stockEnabled)
                            _Pill(
                              label: isOutOfStock
                                  ? 'Out of stock'
                                  : isLowStock
                                  ? 'Low stock · ${stockNow.formatCommas()} left'
                                  : '${stockNow.formatCommas()} in stock',
                              color: isOutOfStock
                                  ? DesignTokens.error
                                  : isLowStock
                                  ? DesignTokens.warning
                                  : DesignTokens.brandPrimary,
                            ),
                          if (!stockEnabled)
                            const _Pill(
                              label: 'Stock tracking off',
                              color: DesignTokens.grayDark,
                            ),
                        ],
                      ),
                      if (_hasVariants(stocks)) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Choose an option',
                          style: DesignTokens.textBodyBold,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sortedStocks(stocks).map((s) {
                            final value = s.variant;
                            final label = value.trim().isEmpty
                                ? 'Default'
                                : value.replaceAll('-', ' • ');
                            return ChoiceChip(
                              selected: value == _selectedVariant,
                              label: Text(label),
                              onSelected: (_) =>
                                  setState(() => _selectedVariant = value),
                            );
                          }).toList(),
                        ),
                      ],
                      if ((item.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _Section(
                          title: 'About this product',
                          child: ServiceDescriptionArticle(
                            html: item.description!.trim(),
                          ),
                        ),
                      ],
                      if (wholesaleRanges(
                        item.wholesaleRangesJson,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Wholesale prices',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final range in wholesaleRanges(
                                item.wholesaleRangesJson,
                              ))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    '${range['min_qty']}–${range['max_qty']} items · ${(double.tryParse('${range['price']}') ?? 0).toUgx()} each',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (productDetails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Product details',
                          child: Column(
                            children: [
                              for (final row in productDetails)
                                _SpecRow(label: row.$1, value: row.$2),
                            ],
                          ),
                        ),
                      ],
                      if (item.publishedOnline &&
                          deliveryDetails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Delivery information',
                          child: Column(
                            children: [
                              for (final row in deliveryDetails)
                                _SpecRow(label: row.$1, value: row.$2),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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

  List<String> _buildImageUris({
    required Item item,
    required ItemStock? stock,
  }) {
    final images = <String>[];
    final seen = <String>{};

    void add(String? v) {
      final value = v?.trim();
      if (value == null || value.isEmpty) return;
      if (seen.add(value)) images.add(value);
    }

    add(stock?.imageUrl);
    add(item.imageUrl);
    add(item.thumbnailUrl);

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
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DesignTokens.textBodyMuted)),
          const SizedBox(width: DesignTokens.spaceSm),
          Flexible(
            child: Text(
              v,
              style: DesignTokens.textBodyBold,
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
      color: DesignTokens.surfaceWhite,
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 44),
                          child: isNetwork
                              ? OfflineCachedImage(
                                  imageUrl: uri,
                                  fit: BoxFit.contain,
                                  placeholder: _imagePlaceholder(),
                                  errorWidget: _imagePlaceholder(),
                                )
                              : (fileExists
                                    ? Image.file(file, fit: BoxFit.contain)
                                    : _imagePlaceholder()),
                        );
                      },
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
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
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
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
                  ? OfflineCachedImage(
                      imageUrl: uri,
                      fit: BoxFit.contain,
                      errorWidget: const Text(
                        'Image not found',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
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
