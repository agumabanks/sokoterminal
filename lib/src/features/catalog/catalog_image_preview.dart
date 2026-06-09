import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../widgets/offline_cached_image.dart';
import 'catalog_template.dart';

/// Social-media-friendly catalog preview rendered off-screen for PNG export.
///
/// Supports four professional layouts: Magazine, Grid, Story, Minimal.
/// Renders at 1080 logical pixels wide for high-res export.
class CatalogImagePreview extends StatelessWidget {
  const CatalogImagePreview({
    super.key,
    required this.items,
    required this.services,
    required this.campaign,
    required this.profile,
  });

  final List<Item> items;
  final List<Service> services;
  final CatalogCampaign campaign;
  final BusinessProfile? profile;

  static final _currencyFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final selectedItems = items.where((i) => campaign.selectedProductIds.contains(i.id)).toList();
    final selectedServices = campaign.includeServices
        ? services.where((s) => campaign.selectedServiceIds.contains(s.id)).toList()
        : <Service>[];

    final allEntries = <_CatalogEntry>[
      ...selectedItems.map((i) => _CatalogEntry.fromItem(i)),
      ...selectedServices.map((s) => _CatalogEntry.fromService(s)),
    ];

    final width = campaign.layout.renderWidth;

    return Container(
      width: width,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(width),
          if (campaign.promo != CatalogPromo.none) _buildPromoBanner(width),
          _buildBody(allEntries, width),
          _buildFooter(width),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1D40), Color(0xFF1A2E5A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              if (profile?.logoUrl != null && profile!.logoUrl!.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.white,
                    child: OfflineCachedImage(
                      imageUrl: profile!.logoUrl!.trim(),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 36),
                ),
              const SizedBox(width: 24),
              // Shop info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.shopName ?? 'My Shop',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      campaign.title.isNotEmpty
                          ? campaign.title
                          : 'Product & Service Catalog',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (profile?.shopPhone != null && profile!.shopPhone!.isNotEmpty)
                          _HeaderChip(icon: Icons.phone, text: profile!.shopPhone!),
                        if (profile?.shopAddress != null && profile!.shopAddress!.isNotEmpty)
                          _HeaderChip(icon: Icons.location_on, text: profile!.shopAddress!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
      color: campaign.promo.badgeColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_offer, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            campaign.promo.bannerText.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── BODY (template dispatch) ──────────────────────────────────────────────

  Widget _buildBody(List<_CatalogEntry> entries, double width) {
    switch (campaign.layout) {
      case CatalogLayout.magazine:
        return _MagazineLayout(entries: entries, width: width);
      case CatalogLayout.grid:
        return _GridLayout(entries: entries, width: width);
      case CatalogLayout.story:
        return _StoryLayout(entries: entries, width: width);
      case CatalogLayout.minimal:
        return _MinimalLayout(entries: entries, width: width);
    }
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────

  Widget _buildFooter(double width) {
    final shopLink = profile?.shopId != null
        ? 'soko24.co/shop/${profile!.shopId}'
        : null;

    return Container(
      width: width,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          if (shopLink != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1D40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Shop Online: $shopLink',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (profile?.shopPhone != null && profile!.shopPhone!.isNotEmpty)
                _FooterAction(icon: Icons.phone, label: 'Call'),
              if (profile?.shopPhone != null) const SizedBox(width: 24),
              _FooterAction(icon: Icons.message, label: 'WhatsApp'),
              const SizedBox(width: 24),
              _FooterAction(icon: Icons.share, label: 'Share'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0EBE7E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Powered by Soko24 — The Operating System for African Business',
                style: TextStyle(fontSize: 14, color: Color(0xFF718096), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── HEADER CHIP ─────────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FOOTER ACTION ───────────────────────────────────────────────────────────

class _FooterAction extends StatelessWidget {
  const _FooterAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1D40).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0F1D40), size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── MAGAZINE LAYOUT ─────────────────────────────────────────────────────────

class _MagazineLayout extends StatelessWidget {
  const _MagazineLayout({required this.entries, required this.width});
  final List<_CatalogEntry> entries;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final hero = entries.first;
    final rest = entries.skip(1).toList();
    final padding = 40.0;
    final gap = 20.0;
    final colWidth = (width - padding * 2 - gap) / 2;

    return Container(
      width: width,
      padding: EdgeInsets.all(padding),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          _HeroCard(entry: hero, width: width - padding * 2),
          const SizedBox(height: 24),
          // Grid of remaining
          if (rest.isNotEmpty)
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: rest.map((e) => _GridCard(entry: e, width: colWidth)).toList(),
            ),
        ],
      ),
    );
  }
}

// ── GRID LAYOUT ─────────────────────────────────────────────────────────────

class _GridLayout extends StatelessWidget {
  const _GridLayout({required this.entries, required this.width});
  final List<_CatalogEntry> entries;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final padding = 40.0;
    final gap = 20.0;
    final colWidth = (width - padding * 2 - gap) / 2;

    return Container(
      width: width,
      padding: EdgeInsets.all(padding),
      color: Colors.white,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: entries.map((e) => _GridCard(entry: e, width: colWidth)).toList(),
      ),
    );
  }
}

// ── STORY LAYOUT ────────────────────────────────────────────────────────────

class _StoryLayout extends StatelessWidget {
  const _StoryLayout({required this.entries, required this.width});
  final List<_CatalogEntry> entries;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final padding = 40.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(padding),
      color: const Color(0xFF0F1D40),
      child: Column(
        children: entries.map((e) => _StoryCard(entry: e, width: width - padding * 2)).toList(),
      ),
    );
  }
}

// ── MINIMAL LAYOUT ──────────────────────────────────────────────────────────

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({required this.entries, required this.width});
  final List<_CatalogEntry> entries;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final padding = 40.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(padding),
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: entries.map((e) => _MinimalCard(entry: e, width: width - padding * 2)).toList(),
      ),
    );
  }
}

// ── CARD WIDGETS ────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.entry, required this.width});
  final _CatalogEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              width: width,
              height: width * 0.55,
              color: const Color(0xFFEEEEEE),
              child: entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty
                  ? OfflineCachedImage(
                      imageUrl: entry.imageUrl!.trim(),
                      width: width,
                      height: width * 0.55,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        entry.isService ? 'SERVICE' : 'PRODUCT',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.isService)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Service',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00A884),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.priceStr,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00A884),
                        ),
                      ),
                      if (entry.unit != null)
                        Text(
                          'per ${entry.unit}',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
                        ),
                      if (entry.duration != null)
                        Text(
                          '${entry.duration} min',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.entry, required this.width});
  final _CatalogEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              width: width,
              height: width * 0.9,
              color: const Color(0xFFEEEEEE),
              child: entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty
                  ? OfflineCachedImage(
                      imageUrl: entry.imageUrl!.trim(),
                      width: width,
                      height: width * 0.9,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        entry.isService ? 'SERVICE' : 'PRODUCT',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.isService)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Service',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF00A884),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.priceStr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00A884),
                  ),
                ),
                if (entry.unit != null)
                  Text(
                    'per ${entry.unit}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
                if (entry.duration != null)
                  Text(
                    '${entry.duration} min',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.entry, required this.width});
  final _CatalogEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: width,
                height: width * 0.75,
                color: const Color(0xFFEEEEEE),
                child: entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty
                    ? OfflineCachedImage(
                        imageUrl: entry.imageUrl!.trim(),
                        width: width,
                        height: width * 0.75,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          entry.isService ? 'SERVICE' : 'PRODUCT',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.priceStr,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0EBE7E),
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
    );
  }
}

class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.entry, required this.width});
  final _CatalogEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: width * 0.42,
              height: width * 0.42,
              color: const Color(0xFFEEEEEE),
              child: entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty
                  ? OfflineCachedImage(
                      imageUrl: entry.imageUrl!.trim(),
                      width: width * 0.42,
                      height: width * 0.42,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        entry.isService ? 'SERVICE' : 'PRODUCT',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.isService)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Service',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00A884),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  entry.priceStr,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00A884),
                  ),
                ),
                if (entry.unit != null)
                  Text(
                    'per ${entry.unit}',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF999999)),
                  ),
                if (entry.duration != null)
                  Text(
                    '${entry.duration} min',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF999999)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ENTRY MODEL ─────────────────────────────────────────────────────────────

class _CatalogEntry {
  _CatalogEntry({
    required this.name,
    required this.price,
    this.unit,
    this.imageUrl,
    required this.isService,
    this.duration,
  });

  factory _CatalogEntry.fromItem(Item item) {
    return _CatalogEntry(
      name: item.name,
      price: item.price,
      unit: item.unit,
      imageUrl: item.thumbnailUrl ?? item.imageUrl,
      isService: false,
      duration: null,
    );
  }

  factory _CatalogEntry.fromService(Service service) {
    return _CatalogEntry(
      name: service.title,
      price: service.price,
      unit: null,
      imageUrl: service.imageUrl,
      isService: true,
      duration: service.durationMinutes,
    );
  }

  final String name;
  final double price;
  final String? unit;
  final String? imageUrl;
  final bool isService;
  final int? duration;

  String get priceStr => 'UGX ${CatalogImagePreview._currencyFormat.format(price.round())}';
}
