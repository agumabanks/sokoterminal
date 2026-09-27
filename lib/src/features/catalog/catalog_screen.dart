import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/error_state.dart';
import 'catalog_export_review_screen.dart';
import 'catalog_service.dart';
import 'catalog_template.dart';

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

/// Digital Catalog — Professional mobile-first design.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> with TickerProviderStateMixin {
  bool _generating = false;

  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entryAnimation = CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _entryController.forward());
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(_catalogItemsProvider);
    final servicesAsync = ref.watch(_catalogServicesProvider);
    final profileAsync = ref.watch(_businessProfileProvider);
    final campaign = ref.watch(_campaignProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(campaign),
      body: itemsAsync.when(
        loading: () => const LoadingState(label: 'Loading catalog...'),
        error: (e, _) => ErrorState(
          message: 'Could not load catalog',
          onRetry: () => ref.invalidate(_catalogItemsProvider),
        ),
        data: (items) {
          final services = servicesAsync.valueOrNull ?? [];
          final profile = profileAsync.valueOrNull;

          if (items.isEmpty && services.isEmpty) {
            return _emptyState();
          }

          return FadeTransition(
            opacity: _entryAnimation,
            child: _buildBody(campaign, items, services, profile),
          );
        },
      ),
      floatingActionButton: campaign.selectedCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => _shareImage(ref.watch(_catalogItemsProvider).valueOrNull ?? [], ref.watch(_catalogServicesProvider).valueOrNull ?? [], profileAsync.valueOrNull),
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.share),
              label: Text('Share (${campaign.selectedCount})'),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(CatalogCampaign campaign) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Digital Catalog', style: DesignTokens.textTitle),
          if (campaign.selectedCount > 0)
            Text('${campaign.selectedCount} items selected', style: DesignTokens.textCaption),
        ],
      ),
      actions: [
        if (campaign.selectedCount > 0)
          TextButton(
            onPressed: () => _shareImage(ref.watch(_catalogItemsProvider).valueOrNull ?? [], ref.watch(_catalogServicesProvider).valueOrNull ?? [], null),
            child: const Text('Share'),
          ),
      ],
    );
  }

  Widget _buildBody(CatalogCampaign campaign, List<Item> items, List<Service> services, BusinessProfile? profile) {
    final selectedItems = items.where((i) => campaign.selectedProductIds.contains(i.id)).toList();
    final selectedServices = campaign.includeServices
        ? services.where((s) => campaign.selectedServiceIds.contains(s.id)).toList()
        : <Service>[];

    return CustomScrollView(
      slivers: [
        // Preview Card
        SliverToBoxAdapter(
          child: _buildPreviewCard(selectedItems, selectedServices, campaign, profile),
        ),
        // Template selector
        SliverToBoxAdapter(child: _buildTemplateSelector(campaign)),
        // Promo selector
        SliverToBoxAdapter(child: _buildPromoSelector(campaign)),
        // Products section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Products', style: DesignTokens.textTitle),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildProductGrid(items, campaign, false),
        ),
        // Services section
        if (services.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Services', style: DesignTokens.textTitle),
                  const Spacer(),
                  FilterChip(
                    label: Text(campaign.includeServices ? 'Included' : 'Skip'),
                    selected: campaign.includeServices,
                    onSelected: (v) {
                      ref.read(_campaignProvider.notifier).state = campaign.copyWith(includeServices: v);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (campaign.includeServices)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildServiceGrid(services, campaign),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildPreviewCard(List<Item> selectedItems, List<Service> selectedServices, CatalogCampaign campaign, BusinessProfile? profile) {
    final allSelected = [...selectedItems, ...selectedServices];
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: DesignTokens.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.brandPrimary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: profile?.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(profile!.logoUrl!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.storefront, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.shopName ?? 'My Shop',
                        style: DesignTokens.textBodyBold.copyWith(color: Colors.white),
                      ),
                      Text(
                        campaign.title.isNotEmpty ? campaign.title : 'Product Catalog',
                        style: DesignTokens.textSmall.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content preview
          if (allSelected.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 48, color: DesignTokens.grayLight),
                    const SizedBox(height: 12),
                    Text('Select items to preview', style: DesignTokens.textBodyMuted),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: allSelected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = allSelected[index];
                  final isService = item is Service;
                  final name = isService ? (item).title : (item as Item).name;
                  final imageUrl = isService ? (item).imageUrl : (item as Item).imageUrl ?? (item).thumbnailUrl;
                  final price = isService ? (item).price : (item as Item).price;

                  return Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: DesignTokens.canvasCloud,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: imageUrl != null
                                ? Image.network(imageUrl, width: 120, fit: BoxFit.cover)
                                : Container(color: DesignTokens.canvasCloud),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(name, style: DesignTokens.textSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(price), style: DesignTokens.textCaption.copyWith(color: DesignTokens.brandAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.canvasCloud,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: DesignTokens.brandAccent),
                const SizedBox(width: 8),
                Text(
                  '${allSelected.length} items • ${campaign.layout.displayName}',
                  style: DesignTokens.textCaption,
                ),
                const Spacer(),
                if (campaign.promo != CatalogPromo.none)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: campaign.promo.badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      campaign.promo.badgeText,
                      style: DesignTokens.textCaption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(CatalogCampaign campaign) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: CatalogLayout.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final layout = CatalogLayout.values[index];
          final active = campaign.layout == layout;
          return GestureDetector(
            onTap: () {
              Haptics.selection();
              ref.read(_campaignProvider.notifier).state = campaign.copyWith(layout: layout);
            },
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              width: 80,
              decoration: BoxDecoration(
                color: active ? DesignTokens.brandPrimary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? DesignTokens.brandPrimary : DesignTokens.hairline),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(layout.icon, size: 24, color: active ? Colors.white : DesignTokens.grayMedium),
                  const SizedBox(height: 4),
                  Text(
                    layout.displayName,
                    style: DesignTokens.textCaption.copyWith(color: active ? Colors.white : DesignTokens.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoSelector(CatalogCampaign campaign) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: CatalogPromo.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final promo = CatalogPromo.values[index];
          final active = campaign.promo == promo;
          return GestureDetector(
            onTap: () {
              Haptics.selection();
              ref.read(_campaignProvider.notifier).state = campaign.copyWith(promo: promo);
            },
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? promo.badgeColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? promo.badgeColor : DesignTokens.hairline),
              ),
              child: Text(
                promo.displayName,
                style: DesignTokens.textCaption.copyWith(color: active ? Colors.white : DesignTokens.grayMedium),
              ),
            ),
          );
        },
      ),
    );
  }

  SliverGrid _buildProductGrid(List<Item> items, CatalogCampaign campaign, bool isService) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          final isSelected = campaign.selectedProductIds.contains(item.id);
          return _buildSelectableCard(
            name: item.name,
            imageUrl: item.imageUrl ?? item.thumbnailUrl,
            price: item.price,
            isSelected: isSelected,
            onTap: () => _toggleProduct(item.id, items.length),
          );
        },
        childCount: items.length,
      ),
    );
  }

  SliverGrid _buildServiceGrid(List<Service> services, CatalogCampaign campaign) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final service = services[index];
          final isSelected = campaign.selectedServiceIds.contains(service.id);
          return _buildSelectableCard(
            name: service.title,
            imageUrl: service.imageUrl,
            price: service.price,
            isSelected: isSelected,
            onTap: () => _toggleService(service.id, services.length),
          );
        },
        childCount: services.length,
      ),
    );
  }

  Widget _buildSelectableCard({
    required String name,
    String? imageUrl,
    required double price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? DesignTokens.brandAccent : DesignTokens.hairline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? DesignTokens.shadowSm : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: imageUrl != null
                        ? Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover)
                        : Container(color: DesignTokens.canvasCloud),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: DesignTokens.brandAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(name, style: DesignTokens.textSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(price),
                    style: DesignTokens.textCaption.copyWith(color: DesignTokens.brandAccent),
                  ),
                ],
              ),
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

    ref.read(_campaignProvider.notifier).state = campaign.copyWith(selectedProductIds: selected);
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

    ref.read(_campaignProvider.notifier).state = campaign.copyWith(selectedServiceIds: selected);
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

  Future<void> _shareImage(List<Item> items, List<Service> services, BusinessProfile? profile) async {
    if (_generating) return;
    final campaign = ref.read(_campaignProvider);
    final selectedProducts = items.where((i) => campaign.selectedProductIds.contains(i.id)).toList();
    final selectedServices = campaign.includeServices
        ? services.where((s) => campaign.selectedServiceIds.contains(s.id)).toList()
        : <Service>[];

    if (selectedProducts.isEmpty && selectedServices.isEmpty) return;

    setState(() => _generating = true);
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
            shareText: 'Check out my catalog!',
            title: campaign.title.isNotEmpty ? campaign.title : '${profile?.shopName ?? 'My Shop'} catalog',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
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
              child: const Icon(Icons.auto_awesome, size: 36, color: DesignTokens.brandAccent),
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

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}
