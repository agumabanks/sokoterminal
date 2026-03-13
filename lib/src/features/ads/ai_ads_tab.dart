import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/offline_cached_image.dart';
import '../checkout/checkout_screen.dart';

final _aiAdsProvider = FutureProvider.family<List<dynamic>, int?>((ref, productId) async {
  final api = ref.watch(sellerApiProvider);
  final res = await api.studioListAds(productId: productId);
  final data = res.data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  return [];
});

class AIAdsTab extends ConsumerStatefulWidget {
  const AIAdsTab({super.key});

  @override
  ConsumerState<AIAdsTab> createState() => _AIAdsTabState();
}

class _AIAdsTabState extends ConsumerState<AIAdsTab> {
  int? _selectedProductRemoteId;
  String? _selectedProductLocalId;
  bool _generating = false;
  bool _llmAvailable = true;
  Timer? _pollTimer;
  // ignore: unused_field
  static final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _checkLlm();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
    final items = ref.watch(itemsStreamProvider);

    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        if (products.isEmpty) {
          return _emptyState('No products yet', 'Add products first to generate AI ads');
        }
        return Column(
          children: [
            // LLM status banner
            if (!_llmAvailable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: DesignTokens.warning.withValues(alpha: 0.12),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: DesignTokens.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('AI service is temporarily unavailable. Try again later.',
                        style: TextStyle(fontSize: 12, color: DesignTokens.warning))),
                  ],
                ),
              ),
            // Product selector
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final item = products[i];
                  final selected = item.id == _selectedProductLocalId;
                  return _ProductChip(
                    item: item,
                    isSelected: selected,
                    onTap: () {
                      setState(() {
                        _selectedProductLocalId = item.id;
                        _selectedProductRemoteId = item.remoteId;
                      });
                      ref.invalidate(_aiAdsProvider);
                    },
                  );
                },
              ),
            ),
            // Generate button
            if (_selectedProductRemoteId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _generating
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(_generating ? 'Generating...' : 'Generate AI Ads'),
                        onPressed: (_generating || !_llmAvailable) ? null : _generateAds,
                      ),
                    ),
                  ],
                ),
              ),
            // Style chips
            if (_selectedProductRemoteId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  children: _styleLabels.entries.map((e) => Chip(
                    label: Text(e.value, style: const TextStyle(fontSize: 11)),
                    avatar: Icon(_styleIcons[e.key] ?? Icons.style, size: 14),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ),
            const Divider(height: 1),
            // Ads list
            Expanded(
              child: _selectedProductRemoteId == null
                  ? _emptyState('Select a product', 'Choose a product above to view or generate AI ads')
                  : _buildAdsList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdsList() {
    final adsAsync = ref.watch(_aiAdsProvider(_selectedProductRemoteId));
    return adsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load ads: $e', style: const TextStyle(fontSize: 13))),
      data: (ads) {
        if (ads.isEmpty) {
          return _emptyState(
            'No AI ads yet',
            'Tap "Generate AI Ads" to create professional ad creatives powered by AI',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_aiAdsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ads.length,
            itemBuilder: (_, i) {
              final ad = ads[i] as Map<String, dynamic>;
              return _AIAdCard(
                ad: ad,
                onDelete: () => _deleteAd(ad['id']),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _generateAds() async {
    if (_selectedProductRemoteId == null || _generating) return;
    setState(() => _generating = true);
    try {
      final api = ref.read(sellerApiProvider);
      await api.studioGenerateAds(
        productId: _selectedProductRemoteId!,
        styles: ['sale', 'new', 'whatsapp'],
        count: 3,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI ads queued! They will appear in 1-2 minutes.')),
      );
      // Start polling for completion
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      attempts++;
      if (attempts > 18) { // 3 minutes max
        timer.cancel();
        return;
      }
      try {
        final api = ref.read(sellerApiProvider);
        final res = await api.studioAdStatus(productId: _selectedProductRemoteId);
        if (res.data is Map && res.data['is_generating'] == false) {
          timer.cancel();
          ref.invalidate(_aiAdsProvider);
        }
      } catch (_) {}
    });
    // Also refresh immediately after a short delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) ref.invalidate(_aiAdsProvider);
    });
  }

  Future<void> _deleteAd(dynamic id) async {
    if (id == null) return;
    try {
      final api = ref.read(sellerApiProvider);
      await api.studioDeleteAd(id is int ? id : int.parse(id.toString()));
      ref.invalidate(_aiAdsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 48, color: DesignTokens.grayMedium),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(subtitle, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: DesignTokens.grayMedium)),
          ),
        ],
      ),
    );
  }

  static const _styleLabels = {
    'sale': 'Flash Deal',
    'new': 'New Arrival',
    'promo': 'Special Offer',
    'story': 'Brand Story',
    'minimal': 'Premium',
    'whatsapp': 'WhatsApp',
    'booking': 'Book Now',
    'catalog': 'Collection',
  };

  static const _styleIcons = {
    'sale': Icons.flash_on,
    'new': Icons.fiber_new,
    'promo': Icons.local_offer,
    'story': Icons.auto_stories,
    'minimal': Icons.diamond_outlined,
    'whatsapp': Icons.chat,
    'booking': Icons.calendar_today,
    'catalog': Icons.collections,
  };
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.item, required this.isSelected, required this.onTap});
  final Item item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? DesignTokens.brandPrimary : DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? DesignTokens.brandPrimary : DesignTokens.grayLight, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.thumbnailUrl != null || item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: OfflineCachedImage(
                  imageUrl: (item.thumbnailUrl ?? item.imageUrl)!,
                  width: 36, height: 36, fit: BoxFit.cover,
                  errorWidget: Icon(Icons.image, size: 20,
                      color: isSelected ? Colors.white70 : DesignTokens.grayMedium),
                ),
              )
            else
              Icon(Icons.inventory_2, size: 20,
                  color: isSelected ? Colors.white70 : DesignTokens.grayMedium),
            const SizedBox(height: 4),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : null)),
          ],
        ),
      ),
    );
  }
}

class _AIAdCard extends StatelessWidget {
  const _AIAdCard({required this.ad, required this.onDelete});
  final Map<String, dynamic> ad;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = ad['status']?.toString() ?? 'pending';
    final style = ad['template_style']?.toString() ?? '';
    final styleLabel = ad['style_label'] is Map ? ad['style_label']['name']?.toString() : style;
    // final name = ad['name']?.toString() ?? 'Generating...';
    final adCopy = ad['ad_copy'];
    final headline = adCopy is Map ? (adCopy['headline'] ?? adCopy['title'] ?? '').toString() : '';
    final body = adCopy is Map ? (adCopy['body'] ?? adCopy['description'] ?? '').toString() : '';
    final cta = adCopy is Map ? (adCopy['cta'] ?? '').toString() : '';
    final thumbnailUrl = ad['thumbnail_url']?.toString();
    final isPending = status == 'pending' || status == 'generating';
    final isFailed = status == 'failed';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _styleColor(style).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(styleLabel ?? style, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _styleColor(style))),
                ),
                const SizedBox(width: 8),
                if (isPending) ...[
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 6),
                  const Text('Generating...', style: TextStyle(fontSize: 12, color: DesignTokens.grayMedium)),
                ] else if (isFailed)
                  const Text('Failed', style: TextStyle(fontSize: 12, color: DesignTokens.error)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: DesignTokens.error),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (!isPending && !isFailed) ...[
              const SizedBox(height: 8),
              // Thumbnail
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: OfflineCachedImage(
                    imageUrl: thumbnailUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 8),
              if (headline.isNotEmpty)
                Text(headline, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 13, color: DesignTokens.grayMedium), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (cta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: DesignTokens.brandPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(cta, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 8),
              // Share actions
              Row(
                children: [
                  _MiniAction(icon: Icons.share, label: 'Share', onTap: () {
                    final text = '$headline\n\n$body${cta.isNotEmpty ? '\n\n$cta' : ''}';
                    Share.share(text);
                  }),
                  const SizedBox(width: 8),
                  _MiniAction(icon: Icons.chat, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: () {
                    final text = '$headline\n\n$body${cta.isNotEmpty ? '\n\n$cta' : ''}';
                    Share.share(text);
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _styleColor(String style) {
    switch (style) {
      case 'sale': return Colors.red;
      case 'new': return Colors.blue;
      case 'promo': return Colors.orange;
      case 'story': return Colors.purple;
      case 'minimal': return Colors.grey;
      case 'whatsapp': return const Color(0xFF25D366);
      case 'booking': return Colors.teal;
      case 'catalog': return Colors.indigo;
      default: return DesignTokens.brandPrimary;
    }
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? DesignTokens.grayLight),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? DesignTokens.grayMedium),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color ?? DesignTokens.grayMedium)),
          ],
        ),
      ),
    );
  }
}
