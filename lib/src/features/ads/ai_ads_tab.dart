import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/offline_cached_image.dart';
import '../checkout/checkout_screen.dart';
import 'ad_detail_screen.dart';
import 'ad_editor_screen.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'canvas_renderer.dart';
import 'studio_design_storage.dart';
import 'studio_editor_launcher.dart';
import 'studio_screen.dart'; // for savedTemplatesProvider
import 'studio_share_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Unified product/service entry shown in the picker grid.
class AdCatalogEntry {
  AdCatalogEntry.fromItem(Item item)
      : id = item.id,
        remoteId = item.remoteId,
        name = item.name,
        price = item.price,
        imageUrl = item.imageUrl,
        thumbnailUrl = item.thumbnailUrl,
        isService = false,
        _item = item,
        _service = null;

  AdCatalogEntry.fromService(Service svc)
      : id = svc.id,
        remoteId = svc.remoteId,
        name = svc.title,
        price = svc.price,
        imageUrl = svc.imageUrl,
        thumbnailUrl = svc.imageUrl,
        isService = true,
        _item = null,
        _service = svc;

  final String id;
  final int? remoteId;
  final String name;
  final double price;
  final String? imageUrl;
  final String? thumbnailUrl;
  final bool isService;
  final Item? _item;
  final Service? _service;

  Item toItem() {
    if (_item != null) return _item!;
    return Item(
      id: id,
      remoteId: remoteId,
      name: name,
      price: price,
      imageUrl: imageUrl,
      thumbnailUrl: imageUrl,
      stockEnabled: false,
      stockQty: 0,
      publishedOnline: _service?.publishedOnline ?? false,
      minPurchaseQty: 1,
      refundable: false,
      cashOnDelivery: false,
      synced: true,
      updatedAt: _service?.updatedAt ?? DateTime.now(),
    );
  }
}

final _fmt = NumberFormat('#,###');

typedef _AiAdsQuery = ({int? productId, int? serviceId});

final _aiAdsProvider =
    FutureProvider.family<List<dynamic>, _AiAdsQuery>((ref, query) async {
  final api = ref.watch(sellerApiProvider);
  final res = await api.studioListAds(
    productId: query.productId,
    serviceId: query.serviceId,
  );
  final data = res.data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  return [];
});

// ---------------------------------------------------------------------------
// AI Ads Tab — main widget
// ---------------------------------------------------------------------------

class AIAdsTab extends ConsumerStatefulWidget {
  const AIAdsTab({super.key});

  @override
  ConsumerState<AIAdsTab> createState() => _AIAdsTabState();
}

class _AIAdsTabState extends ConsumerState<AIAdsTab>
    with SingleTickerProviderStateMixin {
  // Product / service selection
  String? _selectedId;
  int? _selectedRemoteId;
  bool _selectedIsService = false;
  bool _showServices = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Mode: 'templates' | 'ai'
  String _mode = 'templates';

  // Template filter
  String _templateCategory = 'all';

  // AI generation
  bool _generating = false;
  bool _llmAvailable = true;
  final Set<String> _selectedStyles = {'sale', 'new', 'whatsapp'};
  Timer? _pollTimer;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {
      _mode = _tabCtrl.index == 0 ? 'templates' : 'ai';
    }));
    _checkLlm();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkLlm() async {
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.studioLlmStatus();
      if (mounted && res.data is Map) {
        setState(() => _llmAvailable = res.data['llm_available'] == true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);
    final kit = ref.watch(brandKitProvider);

    return itemsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF0EBE7E))),
      ),
      error: (e, _) => Center(
        child: Text('Error loading catalog: $e',
            style: const TextStyle(color: Colors.white54))),
      data: (products) {
        final services = servicesAsync.valueOrNull ?? <Service>[];
        final allEntries = <AdCatalogEntry>[
          ...products.map(AdCatalogEntry.fromItem),
          ...services.map(AdCatalogEntry.fromService),
        ];

        final showingItems = _showServices
            ? services.map(AdCatalogEntry.fromService).toList()
            : products.map(AdCatalogEntry.fromItem).toList();

        final filtered = _query.isEmpty
            ? showingItems
            : showingItems
                .where((e) =>
                    e.name.toLowerCase().contains(_query.toLowerCase()))
                .toList();

        return Column(
          children: [
            // ── Mode tabs ────────────────────────────────────────────────
            Container(
              color: const Color(0xFF0F1D40),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFF0EBE7E),
                unselectedLabelColor: Colors.white38,
                indicatorColor: const Color(0xFF0EBE7E),
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(icon: Icon(Icons.grid_view_rounded, size: 16),
                      text: 'Template Ads'),
                  Tab(icon: Icon(Icons.auto_awesome_rounded, size: 16),
                      text: 'AI Generate'),
                ],
              ),
            ),

            // ── Product/service grid picker ──────────────────────────────
            if (allEntries.isNotEmpty)
              _ProductGrid(
                entries: filtered,
                selectedId: _selectedId,
                showServices: _showServices,
                hasServices: services.isNotEmpty,
                searchCtrl: _searchCtrl,
                query: _query,
                onQueryChanged: (q) => setState(() => _query = q),
                onToggle: (sv) => setState(() {
                  _showServices = sv;
                  _selectedId = null;
                  _selectedRemoteId = null;
                  _selectedIsService = false;
                }),
                onSelect: (entry) => setState(() {
                  _selectedId = entry.id;
                  _selectedRemoteId = entry.remoteId;
                  _selectedIsService = entry.isService;
                }),
              ),

            // ── Tab body ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _TemplatesMode(
                    selectedEntry: filtered.cast<AdCatalogEntry?>()
                        .firstWhere((e) => e?.id == _selectedId,
                            orElse: () => null),
                    kit: kit,
                    activeCategory: _templateCategory,
                    onCategoryChanged: (c) =>
                        setState(() => _templateCategory = c),
                    onEdit: (tpl) => _openEditor(tpl,
                        filtered.cast<AdCatalogEntry?>()
                            .firstWhere((e) => e?.id == _selectedId,
                                orElse: () => null)),
                  ),
                  _AIMode(
                    selectedId: _selectedId,
                    selectedRemoteId: _selectedRemoteId,
                    selectedIsService: _selectedIsService,
                    selectedStyles: _selectedStyles,
                    generating: _generating,
                    llmAvailable: _llmAvailable,
                    entries: filtered,
                    onStyleToggle: (key) => setState(() {
                      if (_selectedStyles.contains(key)) {
                        _selectedStyles.remove(key);
                      } else {
                        _selectedStyles.add(key);
                      }
                    }),
                    onGenerate: _generateAds,
                    onDeleteAd: _deleteAd,
                    onRefresh: () => ref.invalidate(_aiAdsProvider((
                      productId: _selectedIsService ? null : _selectedRemoteId,
                      serviceId: _selectedIsService ? _selectedRemoteId : null,
                    ))),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(AdTemplate tpl, AdCatalogEntry? entry) async {
    await launchStudioEditor(
      context,
      ref,
      template: tpl,
      product: entry?.toItem(),
    );
  }

  Future<void> _generateAds() async {
    if (_selectedRemoteId == null || _generating) return;
    setState(() => _generating = true);
    try {
      final api = ref.read(sellerApiProvider);
      await api.studioGenerateAds(
        productId: _selectedIsService ? null : _selectedRemoteId,
        serviceId: _selectedIsService ? _selectedRemoteId : null,
        styles: _selectedStyles.toList(),
        count: _selectedStyles.length,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: DesignTokens.success,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
                child: Text('AI ads queued — ready in 1-2 minutes!')),
          ]),
        ),
      );
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generation failed: $e'),
          backgroundColor: DesignTokens.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      attempts++;
      if (attempts > 18) {
        timer.cancel();
        return;
      }
      try {
        final api = ref.read(sellerApiProvider);
        final res = await api.studioAdStatus(
          productId: _selectedIsService ? null : _selectedRemoteId,
          serviceId: _selectedIsService ? _selectedRemoteId : null,
        );
        final data = res.data;
        if (data is Map && data['pending_count'] == 0) {
          timer.cancel();
          if (mounted) {
            ref.invalidate(_aiAdsProvider((
              productId: _selectedIsService ? null : _selectedRemoteId,
              serviceId: _selectedIsService ? _selectedRemoteId : null,
            )));
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _deleteAd(int adId) async {
    try {
      await ref.read(sellerApiProvider).studioDeleteAd(adId);
      ref.invalidate(_aiAdsProvider((
        productId: _selectedIsService ? null : _selectedRemoteId,
        serviceId: _selectedIsService ? _selectedRemoteId : null,
      )));
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Product/Service Grid Picker (horizontal scroll, search, 2-row grid)
// ---------------------------------------------------------------------------

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.entries,
    required this.selectedId,
    required this.showServices,
    required this.hasServices,
    required this.searchCtrl,
    required this.query,
    required this.onQueryChanged,
    required this.onToggle,
    required this.onSelect,
  });

  final List<AdCatalogEntry> entries;
  final String? selectedId;
  final bool showServices;
  final bool hasServices;
  final TextEditingController searchCtrl;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onToggle;
  final ValueChanged<AdCatalogEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1220),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search + toggle ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onQueryChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        showServices ? 'Search services…' : 'Search products…',
                    hintStyle: const TextStyle(
                        color: Colors.white30, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 18),
                    suffixIcon: query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              searchCtrl.clear();
                              onQueryChanged('');
                            },
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white38, size: 16),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white10)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF0EBE7E))),
                  ),
                ),
              ),
              if (hasServices) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onToggle(!showServices),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      showServices ? 'Products' : 'Services',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // ── Horizontal grid of cards ────────────────────────────────────
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                query.isEmpty
                    ? 'No ${showServices ? 'services' : 'products'} yet'
                    : 'No results for "$query"',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final isSel = entry.id == selectedId;
                  return GestureDetector(
                    onTap: () => onSelect(entry),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 90,
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF0EBE7E).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF0EBE7E)
                              : Colors.white10,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(11)),
                            child: entry.imageUrl?.isNotEmpty == true
                                ? OfflineCachedImage(
                                    imageUrl: entry.imageUrl!,
                                    width: 90, height: 74,
                                    fit: BoxFit.cover,
                                    errorWidget: _noImg(entry.isService),
                                  )
                                : _noImg(entry.isService),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(6, 4, 6, 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    entry.name,
                                    style: TextStyle(
                                      color: isSel
                                          ? const Color(0xFF0EBE7E)
                                          : Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'UGX ${_fmt.format(entry.price.round())}',
                                    style: TextStyle(
                                      color: isSel
                                          ? const Color(0xFF0EBE7E)
                                          : Colors.white38,
                                      fontSize: 8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _noImg(bool isService) => Container(
        width: 90, height: 74,
        color: Colors.white.withValues(alpha: 0.05),
        child: Icon(
          isService
              ? Icons.room_service_outlined
              : Icons.inventory_2_outlined,
          color: Colors.white24, size: 24,
        ),
      );
}

// ---------------------------------------------------------------------------
// Templates Mode
// ---------------------------------------------------------------------------

class _TemplatesMode extends StatelessWidget {
  const _TemplatesMode({
    required this.selectedEntry,
    required this.kit,
    required this.activeCategory,
    required this.onCategoryChanged,
    required this.onEdit,
  });

  final AdCatalogEntry? selectedEntry;
  final BrandKit kit;
  final String activeCategory;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<AdTemplate> onEdit;

  List<AdTemplate> get _filtered => activeCategory == 'all'
      ? builtInTemplates
      : builtInTemplates
          .where((t) => t.category == activeCategory)
          .toList();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Hint banner ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded,
                    color: Color(0xFF0EBE7E), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedEntry != null
                        ? 'Tap a template to create an ad for "${selectedEntry!.name}"'
                        : 'Select a product above, then tap any template',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Category chips ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: templateCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = templateCategories[i];
                final active = cat.id == activeCategory;
                return GestureDetector(
                  onTap: () => onCategoryChanged(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF0EBE7E)
                          : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon,
                            size: 11,
                            color: active
                                ? Colors.white
                                : Colors.white38),
                        const SizedBox(width: 4),
                        Text(cat.label,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // ── Templates 2-column grid ──────────────────────────────────────
        _filtered.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No templates in this category',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13),
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final tpl = _filtered[i];
                      final preview = selectedEntry != null
                          ? tpl.applyProduct(
                              productName: selectedEntry!.name,
                              priceFormatted:
                                  'UGX ${_fmt.format(selectedEntry!.price.round())}',
                              imageUrl:
                                  selectedEntry!.imageUrl ?? '',
                            )
                          : tpl;

                      return _TemplateCard(
                        template: tpl,
                        preview: preview,
                        hasEntry: selectedEntry != null,
                        onTap: () => onEdit(tpl),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                ),
              ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.preview,
    required this.hasEntry,
    required this.onTap,
  });

  final AdTemplate template;
  final AdTemplate preview;
  final bool hasEntry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1D40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CanvasPreview(template: preview),
                  ),
                  if (hasEntry)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EBE7E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Use →',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Edit',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          template.category.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${template.canvasWidth.toInt()}×${template.canvasHeight.toInt()}',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 7),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// AI Mode (backend generation)
// ---------------------------------------------------------------------------

class _AIMode extends ConsumerWidget {
  const _AIMode({
    required this.selectedId,
    required this.selectedRemoteId,
    required this.selectedIsService,
    required this.selectedStyles,
    required this.generating,
    required this.llmAvailable,
    required this.entries,
    required this.onStyleToggle,
    required this.onGenerate,
    required this.onDeleteAd,
    required this.onRefresh,
  });

  final String? selectedId;
  final int? selectedRemoteId;
  final bool selectedIsService;
  final Set<String> selectedStyles;
  final bool generating;
  final bool llmAvailable;
  final List<AdCatalogEntry> entries;
  final ValueChanged<String> onStyleToggle;
  final VoidCallback onGenerate;
  final ValueChanged<int> onDeleteAd;
  final VoidCallback onRefresh;

  static const _styles = [
    ('sale',    'Flash Deal',    Icons.flash_on_rounded,          Color(0xFFFF4757)),
    ('new',     'New Arrival',   Icons.fiber_new_rounded,         Color(0xFF3B82F6)),
    ('promo',   'Special Offer', Icons.local_offer_rounded,       Color(0xFFF59E0B)),
    ('story',   'Brand Story',   Icons.auto_stories_rounded,      Color(0xFF8B5CF6)),
    ('minimal', 'Premium',       Icons.diamond_outlined,          Color(0xFF64748B)),
    ('whatsapp','WhatsApp',      Icons.chat_rounded,              Color(0xFF25D366)),
    ('booking', 'Book Now',      Icons.calendar_today_rounded,    Color(0xFF14B8A6)),
    ('catalog', 'Collection',    Icons.collections_bookmark_rounded, Color(0xFF6366F1)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(_aiAdsProvider((
      productId: selectedIsService ? null : selectedRemoteId,
      serviceId: selectedIsService ? selectedRemoteId : null,
    )));
    final canGenerate = !generating && llmAvailable &&
        selectedStyles.isNotEmpty && selectedRemoteId != null;

    return CustomScrollView(
      slivers: [
        if (!llmAvailable)
          SliverToBoxAdapter(child: _LlmBanner()),

        // ── Style chips ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Ad Styles',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _styles.map((s) {
                    final key = s.$1;
                    final label = s.$2;
                    final icon = s.$3;
                    final color = s.$4;
                    final active = selectedStyles.contains(key);
                    return GestureDetector(
                      onTap: () => onStyleToggle(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: active
                              ? color.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? color
                                : Colors.white12,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 14,
                                color: active
                                    ? color
                                    : Colors.white38),
                            const SizedBox(width: 6),
                            Text(label,
                                style: TextStyle(
                                  color: active
                                      ? color
                                      : Colors.white38,
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // ── Generate button ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: canGenerate ? onGenerate : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: canGenerate
                      ? const LinearGradient(
                          colors: [Color(0xFF0EBE7E), Color(0xFF059669)])
                      : null,
                  color: canGenerate
                      ? null
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: generating
                    ? const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Generating…',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: canGenerate
                                    ? Colors.white
                                    : Colors.white24,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(
                              selectedId == null
                                  ? 'Select a product above'
                                  : selectedRemoteId == null
                                      ? 'Sync product to server first'
                                      : selectedStyles.isEmpty
                                          ? 'Pick at least one style'
                                          : 'Generate ${selectedStyles.length} AI Ad${selectedStyles.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: canGenerate
                                    ? Colors.white
                                    : Colors.white24,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),

        // ── Generated ads list ────────────────────────────────────────────
        adsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(Color(0xFF0EBE7E))),
              ),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          data: (ads) {
            if (selectedRemoteId == null) {
              return SliverToBoxAdapter(
                child: _EmptyAdsCard(
                  message: 'Select a product or service above to see your AI-generated ads here.',
                ),
              );
            }
            if (ads.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyAdsCard(
                  message: 'No AI ads yet for this item.\nTap Generate above to create some.',
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.separated(
                itemCount: ads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final ad = ads[i] as Map<String, dynamic>;
                  final item = entries.cast<AdCatalogEntry?>()
                      .firstWhere((e) => e?.id == selectedId,
                          orElse: () => entries.isNotEmpty ? entries.first : null)
                      ?.toItem();
                  if (item == null) return const SizedBox.shrink();
                  return _AIAdCard(
                    ad: ad,
                    item: item,
                    onDelete: () => onDeleteAd(ad['id']),
                    onRefresh: onRefresh,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// LLM Banner
// ---------------------------------------------------------------------------

class _LlmBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI generation is offline — use Template Ads instead.',
              style: TextStyle(
                  color: Color(0xFFF59E0B), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state card
// ---------------------------------------------------------------------------

class _EmptyAdsCard extends StatelessWidget {
  const _EmptyAdsCard({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              color: Colors.white24, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? 'No AI ads yet',
            style: const TextStyle(
                color: Colors.white38, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Ad card
// ---------------------------------------------------------------------------

class _AIAdCard extends ConsumerStatefulWidget {
  const _AIAdCard({
    required this.ad,
    required this.item,
    required this.onDelete,
    required this.onRefresh,
  });

  final Map<String, dynamic> ad;
  final Item item;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_AIAdCard> createState() => _AIAdCardState();
}

class _AIAdCardState extends ConsumerState<_AIAdCard> {
  final _canvasKey = GlobalKey();

  Map<String, dynamic> get ad => widget.ad;
  Item get item => widget.item;

  String _buildCaption() {
    final copy = ad['ad_copy'] as Map? ?? {};
    final sharing = copy['sharing_caption']?.toString() ?? '';
    final hashtags = copy['hashtags'];
    final tagStr = hashtags is List
        ? hashtags.map((h) => h.toString()).join(' ')
        : '#Soko24';

    if (sharing.isNotEmpty) return '$sharing\n\n$tagStr\n\nsoko24.co';

    final parts = <String>[];
    final headline = copy['headline']?.toString() ?? '';
    final sub = copy['subheadline']?.toString() ?? '';
    final sp = copy['selling_point']?.toString() ?? '';
    final price = copy['price_display']?.toString() ?? '';
    final cta = copy['cta_text']?.toString() ?? '';
    if (headline.isNotEmpty) parts.add(headline);
    if (sub.isNotEmpty) parts.add(sub);
    if (sp.isNotEmpty) parts.add('✓ $sp');
    if (price.isNotEmpty) parts.add('💰 $price');
    if (cta.isNotEmpty) parts.add('\n👉 $cta');
    parts.add('\n$tagStr');
    parts.add('soko24.co');
    return parts.join('\n');
  }

  Future<void> _shareAd() async {
    final styleKey = ad['template_style'] as String? ?? '';
    final cJson = ad['canvas_json'] as String?;
    try {
      // Try to render canvas to PNG
      RenderRepaintBoundary? boundary;
      if (_canvasKey.currentContext != null) {
        boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      }
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final data = await image.toByteData(format: dart_ui.ImageByteFormat.png);
        if (data != null && mounted) {
          final bytes = data.buffer.asUint8List();
          final dir = await getTemporaryDirectory();
          final file = File(p.join(dir.path, 'ai-ad-${ad['id']}.png'));
          await file.writeAsBytes(bytes, flush: true);
          final kit = ref.read(brandKitProvider);
          final tpl = cJson != null && cJson.length > 5
              ? AdTemplate.fromCanvasJson(
                  jsonDecode(cJson) as Map<String, dynamic>,
                  id: 'ai_${ad['id']}',
                  name: ad['name'] as String? ?? 'AI Ad',
                  category: styleKey,
                )
              : AdTemplate(
                  id: 'ai_${ad['id']}', name: item.name,
                  category: styleKey, canvasWidth: 1080, canvasHeight: 1080,
                  background: '#0F1D40', elements: [],
                );
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => StudioShareSheet(adFile: file, template: tpl, kit: kit),
          ));
          return;
        }
      }
    } catch (_) {}
    // Fallback: text-only share
    await Share.shareXFiles([], text: _buildCaption());
  }

  @override
  Widget build(BuildContext context) {
    final status = ad['status'] as String? ?? 'pending';
    final styleKey = ad['template_style'] as String? ?? '';
    final styleColors = <String, Color>{
      'sale': const Color(0xFFFF4757),
      'new': const Color(0xFF3B82F6),
      'promo': const Color(0xFFF59E0B),
      'story': const Color(0xFF8B5CF6),
      'minimal': const Color(0xFF64748B),
      'whatsapp': const Color(0xFF25D366),
      'booking': const Color(0xFF14B8A6),
      'catalog': const Color(0xFF6366F1),
    };
    final accent = styleColors[styleKey] ?? const Color(0xFF0EBE7E);

    final isPending = status == 'pending' || status == 'generating';
    final isFailed = status == 'failed';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header with style badge ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    ad['style_label'] as String? ??
                        styleKey.toUpperCase(),
                    style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                if (isPending)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(
                          Color(0xFFF59E0B)),
                    ),
                  )
                else if (isFailed)
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 16)
                else
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF0EBE7E), size: 16),
              ],
            ),
          ),

          // ── Thumbnail or pending state ─────────────────────────────────
          if (isPending)
            Container(
              height: 180,
              color: Colors.white.withValues(alpha: 0.04),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white24, size: 32),
                    SizedBox(height: 8),
                    Text('AI is creating your ad…',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            )
          else if (ad['thumbnail_url'] != null)
            ClipRRect(
              child: OfflineCachedImage(
                imageUrl: ad['thumbnail_url'] as String,
                height: 200,
                fit: BoxFit.cover,
                errorWidget: const SizedBox(height: 200),
              ),
            )
          else if (ad['canvas_json'] != null &&
              (ad['canvas_json'] as String).length > 5)
            RepaintBoundary(
              key: _canvasKey,
              child: _CanvasThumbnail(
                canvasJson: ad['canvas_json'] as String,
                styleName: ad['style_label'] as String? ?? '',
                item: item,
              ),
            ),

          // ── Ad copy preview ────────────────────────────────────────────
          if (ad['ad_copy'] is Map) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((ad['ad_copy'] as Map)['headline'] != null)
                    Text(
                      (ad['ad_copy'] as Map)['headline'].toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if ((ad['ad_copy'] as Map)['body'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (ad['ad_copy'] as Map)['body'].toString(),
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Actions ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                if (!isPending && !isFailed) ...[
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    color: const Color(0xFF0EBE7E),
                    onTap: () {
                      final canvasJson = ad['canvas_json'] as String?;
                      if (canvasJson == null || canvasJson.length < 5) return;
                      try {
                        final decoded = jsonDecode(canvasJson) as Map<String, dynamic>;
                        final tpl = AdTemplate.fromCanvasJson(
                          decoded,
                          id: 'ai_${ad['id']}',
                          name: ad['name'] as String? ?? ad['style_label'] as String? ?? 'AI Ad',
                          category: styleKey,
                        );
                        launchStudioEditor(
                          context,
                          ref,
                          template: tpl,
                          product: item,
                        );
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.bookmark_add_rounded,
                    label: 'Save',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      final cJson = ad['canvas_json'] as String?;
                      if (cJson == null || cJson.length < 5) return;
                      try {
                        final decoded = jsonDecode(cJson) as Map<String, dynamic>;
                        final tpl = AdTemplate.fromCanvasJson(
                          decoded,
                          id: 'ai_saved_${ad['id']}_${DateTime.now().millisecondsSinceEpoch}',
                          name: ad['name'] as String? ?? ad['style_label'] as String? ?? 'AI Ad',
                          category: styleKey,
                        );
                        ref.read(savedTemplatesProvider.notifier).save(tpl);
                        ref.read(yourDesignsProvider.notifier).saveDesign(tpl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saved to Your Designs ✓'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _shareAd(),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: Colors.redAccent,
                  onTap: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Canvas thumbnail widget
// ---------------------------------------------------------------------------

class _CanvasThumbnail extends StatelessWidget {
  const _CanvasThumbnail({
    required this.canvasJson,
    required this.styleName,
    required this.item,
  });

  final String canvasJson;
  final String styleName;
  final Item item;

  @override
  Widget build(BuildContext context) {
    try {
      final decoded = jsonDecode(canvasJson) as Map<String, dynamic>;
      final tpl = AdTemplate.fromCanvasJson(
        decoded,
        id: 'thumb',
        name: styleName,
        category: '',
      );
      return AspectRatio(
        aspectRatio: tpl.aspectRatio,
        child: CanvasPreview(template: tpl),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
