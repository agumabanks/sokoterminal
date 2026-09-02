import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/media/offline_media_cache.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';
import '../../widgets/offline_cached_image.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_state.dart';
import 'catalog_image_preview.dart';
import 'catalog_export_review_screen.dart';
import 'catalog_service.dart';
import 'catalog_template.dart';
import 'shop_share_link.dart';

final _catalogItemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(appDatabaseProvider).watchItems();
});

final _catalogServicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(appDatabaseProvider).watchServices();
});

final _businessProfileProvider = FutureProvider<BusinessProfile?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.businessProfiles)..limit(1)).getSingleOrNull();
});

final _campaignProvider = StateProvider<CatalogCampaign>((ref) {
  return const CatalogCampaign();
});

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _catalogImageKey = GlobalKey();
  final _titleController = TextEditingController();
  bool _generating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(_catalogItemsProvider);
    final servicesAsync = ref.watch(_catalogServicesProvider);
    final profileAsync = ref.watch(_businessProfileProvider);
    final campaign = ref.watch(_campaignProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceGrouped,
        title: Text('Digital Catalog', style: DesignTokens.textHeadline),
        actions: [
          if (campaign.selectedCount > 0)
            TextButton(
              onPressed: () => _showShareSheet(
                itemsAsync.valueOrNull ?? [],
                servicesAsync.valueOrNull ?? [],
                profileAsync.valueOrNull,
              ),
              child: const Text('Share'),
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const LoadingState(label: 'Opening your catalog…'),
        error: (e, _) => ErrorState(
          message: 'Your saved catalog is safe. Try loading it again.',
          onRetry: () => ref.invalidate(_catalogItemsProvider),
        ),
        data: (items) {
          final services = servicesAsync.valueOrNull ?? [];
          final profile = profileAsync.valueOrNull;

          if (items.isEmpty && services.isEmpty) {
            return _emptyState();
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildCatalogGuide(campaign, items, services),
                  ),
                  SliverToBoxAdapter(child: _buildTemplateBar(campaign)),
                  SliverToBoxAdapter(child: _buildPromoBar(campaign)),
                  SliverToBoxAdapter(
                    child: _buildTitleEditor(campaign, profile),
                  ),
                  SliverToBoxAdapter(child: _buildLimitChip(campaign)),
                  if (items.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Products',
                          style: DesignTokens.textCaption.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  if (items.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 900
                              ? 4
                              : width >= 600
                              ? 3
                              : width < 280
                              ? 1
                              : 2;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  mainAxisExtent: columns == 1 ? 190 : 210,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ItemCard(
                                item: items[index],
                                selected: campaign.selectedProductIds.contains(
                                  items[index].id,
                                ),
                                onToggle: () => _toggleProduct(
                                  items[index].id,
                                  items.length,
                                ),
                                promo: campaign.promo,
                              ),
                              childCount: items.length,
                            ),
                          );
                        },
                      ),
                    ),
                  if (services.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text(
                              'Services',
                              style: DesignTokens.textCaption.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            FilterChip(
                              label: Text(
                                campaign.includeServices ? 'Included' : 'Skip',
                              ),
                              selected: campaign.includeServices,
                              onSelected: (v) {
                                ref.read(_campaignProvider.notifier).state =
                                    campaign.copyWith(includeServices: v);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (campaign.includeServices)
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final columns = width >= 900
                                ? 4
                                : width >= 600
                                ? 3
                                : width < 280
                                ? 1
                                : 2;
                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: columns == 1 ? 190 : 232,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _ServiceCard(
                                  service: services[index],
                                  selected: campaign.selectedServiceIds
                                      .contains(services[index].id),
                                  onToggle: () => _toggleService(
                                    services[index].id,
                                    services.length,
                                  ),
                                  promo: campaign.promo,
                                ),
                                childCount: services.length,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 200)),
                ],
              ),
              // Hidden off-screen renderer for PNG export
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: _catalogImageKey,
                  child: CatalogImagePreview(
                    items: items,
                    services: services,
                    campaign: campaign,
                    profile: profile,
                  ),
                ),
              ),
              // Floating preview toggle
              if (campaign.selectedCount > 0)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'catalog_share',
                    backgroundColor: DesignTokens.brandPrimary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share'),
                    onPressed: () => _showShareSheet(
                      itemsAsync.valueOrNull ?? [],
                      servicesAsync.valueOrNull ?? [],
                      profileAsync.valueOrNull,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTemplateBar(CatalogCampaign campaign) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: CatalogLayout.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final layout = CatalogLayout.values[index];
          final active = campaign.layout == layout;
          return GestureDetector(
            onTap: () {
              Haptics.selection();
              ref.read(_campaignProvider.notifier).state = campaign.copyWith(
                layout: layout,
              );
            },
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              width: 100,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active
                    ? DesignTokens.brandPrimary
                    : DesignTokens.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? DesignTokens.brandPrimary
                      : DesignTokens.dividerSolid,
                  width: active ? 2 : 1,
                ),
                boxShadow: active ? DesignTokens.shadowMd : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    layout.icon,
                    size: 24,
                    color: active ? Colors.white : DesignTokens.grayMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    layout.displayName,
                    style: DesignTokens.textCaption.copyWith(
                      color: active ? Colors.white : DesignTokens.textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogGuide(
    CatalogCampaign campaign,
    List<Item> items,
    List<Service> services,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.brandPrimary,
        borderRadius: DesignTokens.borderRadiusLg,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.selectedCount == 0
                      ? 'Create a catalog in three taps'
                      : '${campaign.selectedCount} selected • ${campaign.layout.displayName}',
                  style: DesignTokens.textBodyBold.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  campaign.selectedCount == 0
                      ? 'Choose a style, pick items, then share.'
                      : 'Keep choosing items or tap Share when ready.',
                  style: DesignTokens.textSmall.copyWith(
                    color: Colors.white.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
          ),
          if (campaign.selectedCount == 0)
            TextButton(
              onPressed: () {
                final limit = campaign.layout.defaultItemCount;
                final productIds = items
                    .take(limit)
                    .map((item) => item.id)
                    .toSet();
                final remaining = limit - productIds.length;
                final serviceIds = services
                    .take(remaining.clamp(0, services.length))
                    .map((service) => service.id)
                    .toSet();
                ref.read(_campaignProvider.notifier).state = campaign.copyWith(
                  selectedProductIds: productIds,
                  selectedServiceIds: serviceIds,
                  includeServices: serviceIds.isNotEmpty,
                );
                Haptics.selection();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Quick start'),
            ),
        ],
      ),
    );
  }

  Widget _buildPromoBar(CatalogCampaign campaign) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: CatalogPromo.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final promo = CatalogPromo.values[index];
          final active = campaign.promo == promo;
          return ChoiceChip(
            label: Text(promo.displayName),
            selected: active,
            onSelected: (_) {
              Haptics.selection();
              ref.read(_campaignProvider.notifier).state = campaign.copyWith(
                promo: promo,
              );
            },
            selectedColor: promo.badgeColor.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: active ? promo.badgeColor : DesignTokens.grayMedium,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildTitleEditor(CatalogCampaign campaign, BusinessProfile? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            onChanged: (v) {
              ref.read(_campaignProvider.notifier).state = campaign.copyWith(
                title: v,
              );
            },
            style: DesignTokens.textBodyBold,
            decoration: InputDecoration(
              hintText: campaign.title.isEmpty
                  ? '${profile?.shopName ?? 'My Shop'} — ${campaign.layout.displayName} Catalog'
                  : campaign.title,
              hintStyle: DesignTokens.textBody.copyWith(
                color: DesignTokens.grayMedium,
              ),
              prefixIcon: const Icon(Icons.title_outlined, size: 20),
              filled: true,
              fillColor: DesignTokens.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitChip(CatalogCampaign campaign) {
    final limit = campaign.layout.maxRecommended;
    final count = campaign.selectedCount;
    final color = count > limit ? DesignTokens.error : DesignTokens.success;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  '$count / $limit ${campaign.layout.displayName.toLowerCase()}',
                  style: DesignTokens.textCaption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              Haptics.selection();
              ref.read(_campaignProvider.notifier).state = campaign.copyWith(
                selectedProductIds: {},
                selectedServiceIds: {},
              );
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.grayMedium,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DesignTokens.brandAccentLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 36,
                color: DesignTokens.brandAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text('Build your first catalog', style: DesignTokens.textTitle),
            const SizedBox(height: 8),
            Text(
              'Add products or services, then create\na professional shareable catalog.',
              textAlign: TextAlign.center,
              style: DesignTokens.textBodyMuted,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go('/home/more/items'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/home/more/services'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add service'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleProduct(String id, int totalProducts) {
    final campaign = ref.read(_campaignProvider);
    final limit = campaign.layout.maxRecommended;
    final selected = Set<String>.from(campaign.selectedProductIds);

    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      if (campaign.selectedCount >= limit) {
        _showLimitToast(limit);
        return;
      }
      selected.add(id);
    }

    ref.read(_campaignProvider.notifier).state = campaign.copyWith(
      selectedProductIds: selected,
    );
    Haptics.selection();
  }

  void _toggleService(String id, int totalServices) {
    final campaign = ref.read(_campaignProvider);
    final limit = campaign.layout.maxRecommended;
    final selected = Set<String>.from(campaign.selectedServiceIds);

    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      if (campaign.selectedCount >= limit) {
        _showLimitToast(limit);
        return;
      }
      selected.add(id);
    }

    ref.read(_campaignProvider.notifier).state = campaign.copyWith(
      selectedServiceIds: selected,
    );
    Haptics.selection();
  }

  void _showLimitToast(int limit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Select up to $limit items for this layout'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
    Haptics.warning();
  }

  void _showShareSheet(
    List<Item> allItems,
    List<Service> allServices,
    BusinessProfile? profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ShareSheet(
        campaign: ref.read(_campaignProvider),
        allItems: allItems,
        allServices: allServices,
        profile: profile,
        onShareImage: () => _shareImage(allItems, allServices, profile),
        onSharePdf: () => _sharePdf(allItems, allServices, profile),
        onShareWhatsApp: () => _shareWhatsApp(allItems, allServices, profile),
        onOpenShopLink:
            buildShopShareLink(
                  shopId: profile?.shopId,
                  shopName: profile?.shopName,
                ) !=
                null
            ? () => _openShopLink(
                buildShopShareLink(
                  shopId: profile?.shopId,
                  shopName: profile?.shopName,
                )!,
              )
            : null,
        generating: _generating,
      ),
    );
  }

  Future<void> _shareImage(
    List<Item> items,
    List<Service> services,
    BusinessProfile? profile,
  ) async {
    final campaign = ref.read(_campaignProvider);
    final selectedProducts = items
        .where((i) => campaign.selectedProductIds.contains(i.id))
        .toList();
    final selectedServices = campaign.includeServices
        ? services
              .where((s) => campaign.selectedServiceIds.contains(s.id))
              .toList()
        : <Service>[];

    if (selectedProducts.isEmpty && selectedServices.isEmpty) return;

    setState(() => _generating = true);
    Navigator.pop(context);

    try {
      final media = <String?>[
        ...selectedProducts.map((item) => item.thumbnailUrl ?? item.imageUrl),
        ...selectedServices.map((service) => service.imageUrl),
        profile?.logoUrl,
      ].whereType<String>().where((value) => value.trim().isNotEmpty);
      await OfflineMediaCache.instance.prefetchAll(media);
      if (!mounted) return;
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final boundary =
          _catalogImageKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Preview not ready');
      // 2.5× on a 1080-wide canvas → 2700px wide PNG, crisp on all screens
      // without producing a texture so large that older GPUs drop image tiles.
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Image conversion failed');
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/${_safeFileName(profile?.shopName ?? 'catalog')}-catalog.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      final shareText = _buildShareText(campaign, profile);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CatalogExportReviewScreen.image(
            file: file,
            shareText: shareText,
            title: campaign.title.isNotEmpty
                ? campaign.title
                : '${profile?.shopName ?? 'My Shop'} catalog',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _sharePdf(
    List<Item> items,
    List<Service> services,
    BusinessProfile? profile,
  ) async {
    final campaign = ref.read(_campaignProvider);
    final selectedProducts = items
        .where((i) => campaign.selectedProductIds.contains(i.id))
        .toList();
    final selectedServices = campaign.includeServices
        ? services
              .where((s) => campaign.selectedServiceIds.contains(s.id))
              .toList()
        : <Service>[];

    if (selectedProducts.isEmpty && selectedServices.isEmpty || _generating) {
      return;
    }
    setState(() => _generating = true);
    Navigator.pop(context);

    try {
      final service = CatalogService(ref.read(appDatabaseProvider));
      final bytes = await service.buildCatalogPdf(
        items: selectedProducts,
        services: selectedServices,
        shopName: profile?.shopName ?? 'My Shop',
        shopPhone: profile?.shopPhone,
        shopAddress: profile?.shopAddress,
        logoUrl: profile?.logoUrl,
        shopId: profile?.shopId,
        campaign: campaign,
      );
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/${_safeFileName(profile?.shopName ?? 'catalog')}-catalog.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CatalogExportReviewScreen.pdf(
            file: file,
            pdfBytes: bytes,
            shareText: _buildShareText(campaign, profile),
            title: campaign.title.isNotEmpty
                ? campaign.title
                : '${profile?.shopName ?? 'My Shop'} catalog',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _shareWhatsApp(
    List<Item> items,
    List<Service> services,
    BusinessProfile? profile,
  ) async {
    final campaign = ref.read(_campaignProvider);
    final selectedProducts = items
        .where((i) => campaign.selectedProductIds.contains(i.id))
        .toList();
    final selectedServices = campaign.includeServices
        ? services
              .where((s) => campaign.selectedServiceIds.contains(s.id))
              .toList()
        : <Service>[];

    if (selectedProducts.isEmpty && selectedServices.isEmpty || _generating) {
      return;
    }
    setState(() => _generating = true);
    Navigator.pop(context);

    try {
      final svc = CatalogService(ref.read(appDatabaseProvider));
      await svc.shareWhatsApp(
        items: selectedProducts,
        services: selectedServices,
        shopName: profile?.shopName ?? 'My Shop',
        shopId: profile?.shopId,
        campaign: campaign,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openShopLink(String link) async {
    final svc = CatalogService(ref.read(appDatabaseProvider));
    await svc.openShopLink(link);
  }

  String _buildShareText(CatalogCampaign campaign, BusinessProfile? profile) {
    final buffer = StringBuffer();
    if (campaign.title.isNotEmpty) {
      buffer.writeln(campaign.title);
    } else {
      buffer.writeln('${profile?.shopName ?? 'My Shop'} — Catalog');
    }
    if (campaign.promo != CatalogPromo.none) {
      buffer.writeln('🏷 ${campaign.promo.bannerText}');
    }
    final shopLink = buildShopShareLink(
      shopId: profile?.shopId,
      shopName: profile?.shopName,
    );
    if (shopLink != null) {
      buffer.writeln('Shop online: $shopLink');
    }
    return buffer.toString();
  }

  String _safeFileName(String value) {
    final safe = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty ? 'soko24' : safe;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visual item cards
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.promo,
  });

  final Item item;
  final bool selected;
  final VoidCallback onToggle;
  final CatalogPromo promo;

  static final _currencyFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final price = '${_currencyFormat.format(item.price.round())} /=';
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DesignTokens.brandAccent : Colors.transparent,
            width: selected ? 2.5 : 0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DesignTokens.brandAccent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — 4:3 ratio, more editorial than square
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  AspectRatio(aspectRatio: 4 / 3, child: _buildImage()),
                  if (promo != CatalogPromo.none)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: promo.badgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          promo.badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: DesignTokens.durationFast,
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected
                            ? DesignTokens.brandAccent
                            : Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        selected ? Icons.check : Icons.add,
                        size: 16,
                        color: selected
                            ? Colors.white
                            : DesignTokens.grayMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    price,
                    style: const TextStyle(
                      color: DesignTokens.brandAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  if (item.stockEnabled && item.stockQty > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${item.stockQty} in stock',
                        style: DesignTokens.textCaption.copyWith(fontSize: 11),
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

  Widget _buildImage() {
    final url = item.thumbnailUrl ?? item.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return OfflineCachedImage(
        imageUrl: url.trim(),
        fit: BoxFit.cover,
        placeholder: _placeholder(),
        errorWidget: _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: DesignTokens.grayLight,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: DesignTokens.grayMedium,
        size: 32,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.selected,
    required this.onToggle,
    required this.promo,
  });

  final Service service;
  final bool selected;
  final VoidCallback onToggle;
  final CatalogPromo promo;

  static final _currencyFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final price = '${_currencyFormat.format(service.price.round())} /=';
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DesignTokens.brandAccent : Colors.transparent,
            width: selected ? 2.5 : 0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DesignTokens.brandAccent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  AspectRatio(aspectRatio: 4 / 3, child: _buildImage()),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.brandPrimary.withValues(
                          alpha: 0.88,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'SERVICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: DesignTokens.durationFast,
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected
                            ? DesignTokens.brandAccent
                            : Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        selected ? Icons.check : Icons.add,
                        size: 16,
                        color: selected
                            ? Colors.white
                            : DesignTokens.grayMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      color: DesignTokens.brandAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (service.durationMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 12,
                            color: DesignTokens.grayMedium,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${service.durationMinutes} min',
                            style: DesignTokens.textCaption.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
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

  Widget _buildImage() {
    final url = service.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return OfflineCachedImage(
        imageUrl: url.trim(),
        fit: BoxFit.cover,
        placeholder: _placeholder(),
        errorWidget: _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: DesignTokens.grayLight,
      child: const Icon(
        Icons.room_service_outlined,
        color: DesignTokens.grayMedium,
        size: 32,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.campaign,
    required this.allItems,
    required this.allServices,
    required this.profile,
    required this.onShareImage,
    required this.onSharePdf,
    required this.onShareWhatsApp,
    required this.onOpenShopLink,
    required this.generating,
  });

  final CatalogCampaign campaign;
  final List<Item> allItems;
  final List<Service> allServices;
  final BusinessProfile? profile;
  final VoidCallback onShareImage;
  final VoidCallback onSharePdf;
  final VoidCallback onShareWhatsApp;
  final VoidCallback? onOpenShopLink;
  final bool generating;

  @override
  Widget build(BuildContext context) {
    final selectedProducts = allItems
        .where((i) => campaign.selectedProductIds.contains(i.id))
        .toList();
    final selectedServices = campaign.includeServices
        ? allServices
              .where((s) => campaign.selectedServiceIds.contains(s.id))
              .toList()
        : <Service>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Text(
              campaign.title.isNotEmpty
                  ? campaign.title
                  : profile?.shopName ?? 'Catalog',
              style: DesignTokens.textHeadline,
            ),
            const SizedBox(height: 4),
            Text(
              '${selectedProducts.length} products${selectedServices.isNotEmpty ? ', ${selectedServices.length} services' : ''} · ${campaign.layout.displayName} layout',
              style: DesignTokens.textBodyMuted,
            ),
            if (campaign.promo != CatalogPromo.none) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: campaign.promo.badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  campaign.promo.bannerText,
                  style: TextStyle(
                    color: campaign.promo.badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Share actions
            _ShareButton(
              icon: Icons.message,
              label: 'Share on WhatsApp',
              subtitle: 'Send as a rich message with catalog link',
              color: const Color(0xFF25D366),
              onPressed: generating ? null : onShareWhatsApp,
              generating: generating,
            ),
            const SizedBox(height: 10),
            _ShareButton(
              icon: Icons.image,
              label: 'Preview image',
              subtitle:
                  'Inspect the exact high-res ${campaign.layout.displayName.toLowerCase()} poster',
              color: DesignTokens.brandPrimary,
              onPressed: generating ? null : onShareImage,
              generating: generating,
            ),
            const SizedBox(height: 10),
            _ShareButton(
              icon: Icons.picture_as_pdf,
              label: 'Preview PDF',
              subtitle: 'Proof every page before customers receive it',
              color: DesignTokens.error,
              onPressed: generating ? null : onSharePdf,
              generating: generating,
            ),
            if (onOpenShopLink != null) ...[
              const SizedBox(height: 10),
              _ShareButton(
                icon: Icons.storefront,
                label: 'Open Shop Link',
                subtitle:
                    buildShopShareLink(
                      shopId: profile?.shopId,
                      shopName: profile?.shopName,
                    ) ??
                    'Open your Soko24 shop',
                color: DesignTokens.brandAccent,
                onPressed: onOpenShopLink!,
                generating: false,
                outlined: true,
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
    required this.generating,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onPressed;
  final bool generating;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.transparent : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: outlined
              ? BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: outlined
                      ? color.withValues(alpha: 0.1)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: generating
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: outlined ? color : DesignTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: DesignTokens.textCaption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: outlined ? color : DesignTokens.grayMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
