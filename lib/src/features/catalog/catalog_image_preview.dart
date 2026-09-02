
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../widgets/offline_cached_image.dart';
import 'catalog_template.dart';
import 'shop_share_link.dart';
import '../../core/theme/design_tokens.dart';

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
    final selectedItems = items
        .where((i) => campaign.selectedProductIds.contains(i.id))
        .toList();
    final selectedServices = campaign.includeServices
        ? services
              .where((s) => campaign.selectedServiceIds.contains(s.id))
              .toList()
        : <Service>[];

    final allEntries = <_CatalogEntry>[
      ...selectedItems.map((i) => _CatalogEntry.fromItem(i)),
      ...selectedServices.map((s) => _CatalogEntry.fromService(s)),
    ];

    final width = campaign.layout.renderWidth;

    return SizedBox(
      width: width,
      height: campaign.layout.renderHeight,
      child: ClipRect(
        child: ColoredBox(
          color: const Color(0xFFF7F8FA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(width),
              if (campaign.promo != CatalogPromo.none)
                _buildPromoBanner(width),
              Expanded(child: _buildBody(allEntries, width)),
              _buildFooter(width),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(52, 52, 52, 44),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DesignTokens.brandPrimary,
            const Color(0xFF0D2247),
            const Color(0xFF1A3A6B),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo with frosted glass ring
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 88,
                height: 88,
                color: Colors.white,
                child: profile?.logoUrl != null &&
                        profile!.logoUrl!.trim().isNotEmpty
                    ? OfflineCachedImage(
                        imageUrl: profile!.logoUrl!.trim(),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.storefront,
                        color: DesignTokens.brandPrimary,
                        size: 44,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.shopName ?? 'My Shop',
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  campaign.title.isNotEmpty
                      ? campaign.title
                      : 'Product & Service Catalog',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.78),
                    letterSpacing: 0.2,
                  ),
                ),
                if (profile?.shopPhone != null &&
                    profile!.shopPhone!.isNotEmpty ||
                    profile?.shopAddress != null &&
                        profile!.shopAddress!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (profile?.shopPhone != null &&
                            profile!.shopPhone!.isNotEmpty)
                          _HeaderPill(
                            icon: Icons.phone_outlined,
                            text: profile!.shopPhone!,
                          ),
                        if (profile?.shopAddress != null &&
                            profile!.shopAddress!.isNotEmpty)
                          _HeaderPill(
                            icon: Icons.place_outlined,
                            text: profile!.shopAddress!,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Decorative accent circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: DesignTokens.brandAccent.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: DesignTokens.brandAccent,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 52),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            campaign.promo.badgeColor,
            campaign.promo.badgeColor.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_offer_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Text(
            campaign.promo.bannerText.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
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
        return _MagazineLayout(
          entries: entries,
          width: width,
          promo: campaign.promo,
        );
      case CatalogLayout.grid:
        return _GridLayout(
          entries: entries,
          width: width,
          promo: campaign.promo,
        );
      case CatalogLayout.story:
        return _StoryLayout(
          entries: entries,
          width: width,
          promo: campaign.promo,
        );
      case CatalogLayout.minimal:
        return _MinimalLayout(
          entries: entries,
          width: width,
          promo: campaign.promo,
        );
    }
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────

  Widget _buildFooter(double width) {
    final shopLink = buildShopShareLink(
      shopId: profile?.shopId,
      shopName: profile?.shopName,
    )?.replaceFirst('https://', '');

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 36),
      color: const Color(0xFF0D1B2E),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: brand
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: DesignTokens.brandAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Powered by Soko24',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'The Operating System for African Business',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Right: shop link pill
          if (shopLink != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: DesignTokens.brandAccent,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    shopLink,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile?.shopPhone != null &&
                    profile!.shopPhone!.isNotEmpty)
                  _FooterPill(
                    icon: Icons.phone_outlined,
                    label: profile!.shopPhone!,
                  ),
                if (profile?.shopPhone != null &&
                    profile!.shopPhone!.isNotEmpty)
                  const SizedBox(width: 12),
                const _FooterPill(
                  icon: Icons.chat_bubble_outline,
                  label: 'WhatsApp',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── HEADER PILL ──────────────────────────────────────────────────────────────

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 15),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FOOTER PILL ──────────────────────────────────────────────────────────────

class _FooterPill extends StatelessWidget {
  const _FooterPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── MAGAZINE LAYOUT ──────────────────────────────────────────────────────────
// Editorial: one large hero (60% width) + up to 4 side items (40% width).
// Side items use alternating heights so the layout breathes organically.

class _MagazineLayout extends StatelessWidget {
  const _MagazineLayout({
    required this.entries,
    required this.width,
    required this.promo,
  });
  final List<_CatalogEntry> entries;
  final double width;
  final CatalogPromo promo;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Magazine = big hero tile top (60% height) + bottom row of up to 4 smaller tiles.
    // This gives the hero the spotlight and lets supporting items breathe instead of
    // being squashed into a side column.
    return Container(
      width: width,
      color: const Color(0xFFF7F8FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          const outerPad = 32.0;
          const innerGap = 18.0;

          final heroH = totalH * 0.58 - outerPad;
          final bottomH = totalH - heroH - outerPad * 2 - innerGap;

          final bottomEntries = entries.skip(1).take(4).toList();
          final bottomCount = bottomEntries.length.clamp(1, 4);

          return Padding(
            padding: const EdgeInsets.all(outerPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── HERO ──
                SizedBox(
                  height: heroH,
                  child: _ProofTile(
                    entry: entries.first,
                    promo: promo,
                    hero: true,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),

                if (bottomEntries.isNotEmpty) ...[
                  const SizedBox(height: innerGap),

                  // ── BOTTOM STRIP ──
                  SizedBox(
                    height: bottomH,
                    child: Row(
                      children: [
                        for (var i = 0; i < bottomCount; i++) ...[
                          if (i > 0) const SizedBox(width: innerGap),
                          Expanded(
                            child: _MagazineSupportTile(
                              entry: bottomEntries[i],
                              promo: promo,
                              // First bottom tile is slightly taller — give it a
                              // different visual weight via a landscape image ratio
                              accent: i == 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── MAGAZINE SUPPORT TILE ─────────────────────────────────────────────────────
// A horizontal mini-card: image on the left (fixed 40% width), text on the
// right. This is legible even at small heights because text is never overlaid
// on a dark gradient.

class _MagazineSupportTile extends StatelessWidget {
  const _MagazineSupportTile({
    required this.entry,
    required this.promo,
    this.accent = false,
  });

  final _CatalogEntry entry;
  final CatalogPromo promo;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0C000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image — takes ~60% of the tile height
            Expanded(
              flex: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  // Subtle bottom gradient so the price pill pops
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Price pill — bottom-left
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.brandAccent,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        entry.priceStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  // Promo badge — top-right
                  if (promo != CatalogPromo.none)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _SmallBadge(
                        text: promo.badgeText,
                        bg: promo.badgeColor,
                        fg: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            // Name — takes ~40% of the tile
            Expanded(
              flex: 40,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.isService)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _SmallBadge(
                          text: 'SERVICE',
                          bg: DesignTokens.brandAccent.withValues(alpha: 0.12),
                          fg: DesignTokens.brandAccent,
                        ),
                      ),
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0D1B2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
      return OfflineCachedImage(
        imageUrl: entry.imageUrl!.trim(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: _fallback(),
        errorWidget: _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD6DCE8), Color(0xFFBEC8D8)],
      ),
    ),
    child: Center(
      child: Icon(
        entry.isService
            ? Icons.room_service_outlined
            : Icons.inventory_2_outlined,
        size: 36,
        color: const Color(0xFFA0AEBC),
      ),
    ),
  );
}

// ── GRID LAYOUT ──────────────────────────────────────────────────────────────
// True masonry: one large feature tile on the left (full height), right column
// has two stacked tiles. If >3 items, a second row of equal tiles runs below.
// This creates the editorial "one hero + gallery" feel of a real design portfolio.

class _GridLayout extends StatelessWidget {
  const _GridLayout({
    required this.entries,
    required this.width,
    required this.promo,
  });
  final List<_CatalogEntry> entries;
  final double width;
  final CatalogPromo promo;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: width,
      color: const Color(0xFF111827),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const pad = 24.0;
          const gap = 14.0;
          final totalH = constraints.maxHeight;

          // Layout: 3-item masonry top block + optional bottom row
          final topEntries = entries.take(3).toList();
          final bottomEntries = entries.skip(3).take(3).toList();
          final hasBottom = bottomEntries.isNotEmpty;

          final topH = hasBottom
              ? totalH * 0.58 - pad
              : totalH - pad * 2;
          final bottomH = hasBottom
              ? totalH - topH - pad * 2 - gap
              : 0.0;

          return Padding(
            padding: const EdgeInsets.all(pad),
            child: Column(
              children: [
                // ── TOP BLOCK: feature left + 2 stacked right ──
                SizedBox(
                  height: topH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Feature tile — 55% wide, full height
                      Expanded(
                        flex: 55,
                        child: _ProofTile(
                          entry: topEntries[0],
                          promo: promo,
                          hero: topEntries.length == 1,
                          dark: true,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      if (topEntries.length > 1) ...[
                        const SizedBox(width: gap),
                        // Right column — 45% wide, two equal tiles
                        Expanded(
                          flex: 45,
                          child: Column(
                            children: [
                              Expanded(
                                child: _ProofTile(
                                  entry: topEntries[1],
                                  promo: promo,
                                  dark: true,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              if (topEntries.length > 2) ...[
                                const SizedBox(height: gap),
                                Expanded(
                                  child: _ProofTile(
                                    entry: topEntries[2],
                                    promo: promo,
                                    dark: true,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── BOTTOM ROW: up to 3 equal tiles ──
                if (hasBottom) ...[
                  const SizedBox(height: gap),
                  SizedBox(
                    height: bottomH,
                    child: Row(
                      children: [
                        for (var i = 0; i < bottomEntries.length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          Expanded(
                            child: _ProofTile(
                              entry: bottomEntries[i],
                              promo: promo,
                              dark: true,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── STORY LAYOUT ─────────────────────────────────────────────────────────────
// Cinematic: bold full-width feature at top with overlaid title, then a
// horizontal filmstrip of remaining items below — like a Netflix show page.
// Dark canvas keeps the focus entirely on product photography.

class _StoryLayout extends StatelessWidget {
  const _StoryLayout({
    required this.entries,
    required this.width,
    required this.promo,
  });
  final List<_CatalogEntry> entries;
  final double width;
  final CatalogPromo promo;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: width,
      color: const Color(0xFF080F1A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const pad = 28.0;
          const gap = 16.0;
          final totalH = constraints.maxHeight;

          final supportEntries = entries.skip(1).take(3).toList();
          final hasSupport = supportEntries.isNotEmpty;

          // Feature gets 55% of height, filmstrip gets 45%
          final featureH = hasSupport
              ? totalH * 0.56 - pad
              : totalH - pad * 2;
          final filmH = hasSupport
              ? totalH - featureH - pad * 2 - gap
              : 0.0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(pad, pad, pad, pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── CINEMATIC FEATURE ──
                SizedBox(
                  height: featureH,
                  child: _ProofTile(
                    entry: entries.first,
                    promo: promo,
                    hero: true,
                    dark: true,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),

                if (hasSupport) ...[
                  const SizedBox(height: gap),
                  // ── FILMSTRIP ──
                  SizedBox(
                    height: filmH,
                    child: Row(
                      children: [
                        for (var i = 0; i < supportEntries.length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          Expanded(
                            child: _StoryFilmTile(
                              entry: supportEntries[i],
                              promo: promo,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Filmstrip tile: image fills the card, number index in top-left corner,
// price pill bottom-left, name in a clean white strip at the bottom.
class _StoryFilmTile extends StatelessWidget {
  const _StoryFilmTile({required this.entry, required this.promo});
  final _CatalogEntry entry;
  final CatalogPromo promo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          _buildImage(),
          // Bottom gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
                colors: [Colors.transparent, Color(0xDD000000)],
              ),
            ),
          ),
          // Price + name at bottom
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.brandAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.priceStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Promo badge
          if (promo != CatalogPromo.none)
            Positioned(
              top: 10,
              left: 10,
              child: _SmallBadge(
                text: promo.badgeText,
                bg: promo.badgeColor,
                fg: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
      return OfflineCachedImage(
        imageUrl: entry.imageUrl!.trim(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: _fallback(),
        errorWidget: _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A2A40), Color(0xFF0D1B2E)],
      ),
    ),
    child: Center(
      child: Icon(
        entry.isService
            ? Icons.room_service_outlined
            : Icons.inventory_2_outlined,
        size: 40,
        color: const Color(0xFF3A5070),
      ),
    ),
  );
}

// ── MINIMAL LAYOUT ───────────────────────────────────────────────────────────
// Luxury editorial list — clean white cards, large product image on one side,
// editorial product detail on the other. Alternating image position breaks
// the monotony. A subtle index number adds luxury magazine character.

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({
    required this.entries,
    required this.width,
    required this.promo,
  });
  final List<_CatalogEntry> entries;
  final double width;
  final CatalogPromo promo;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: width,
      color: const Color(0xFFF2F3F5),
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 16.0;
          final height =
              (constraints.maxHeight - (entries.length - 1) * gap) /
              entries.length;

          return Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                SizedBox(
                  height: height,
                  child: _MinimalRow(
                    entry: entries[i],
                    promo: promo,
                    index: i + 1,
                    flip: i % 2 != 0,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MinimalRow extends StatelessWidget {
  const _MinimalRow({
    required this.entry,
    required this.promo,
    required this.index,
    this.flip = false,
  });
  final _CatalogEntry entry;
  final CatalogPromo promo;
  final int index;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final imageWidget = _MinimalImage(entry: entry);
    final details = _MinimalDetails(entry: entry, promo: promo, index: index);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: flip
              ? [
                  Expanded(flex: 52, child: details),
                  Expanded(flex: 48, child: imageWidget),
                ]
              : [
                  Expanded(flex: 48, child: imageWidget),
                  Expanded(flex: 52, child: details),
                ],
        ),
      ),
    );
  }
}

class _MinimalImage extends StatelessWidget {
  const _MinimalImage({required this.entry});
  final _CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
      return OfflineCachedImage(
        imageUrl: entry.imageUrl!.trim(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: _fallback(),
        errorWidget: _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDDE2EC), Color(0xFFC8D0DF)],
      ),
    ),
    child: Center(
      child: Icon(
        entry.isService
            ? Icons.room_service_outlined
            : Icons.inventory_2_outlined,
        size: 48,
        color: const Color(0xFF9AAABF),
      ),
    ),
  );
}

class _MinimalDetails extends StatelessWidget {
  const _MinimalDetails({
    required this.entry,
    required this.promo,
    required this.index,
  });
  final _CatalogEntry entry;
  final CatalogPromo promo;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Watermark Index number — luxury editorial touch, placed in background
        Positioned(
          top: -10,
          right: -10,
          child: Text(
            index.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Color(0xFFF0F3F7),
              fontSize: 110,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -6,
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges
              if (entry.isService || promo != CatalogPromo.none)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (entry.isService)
                        _SmallBadge(
                          text: 'SERVICE',
                          bg: DesignTokens.brandAccent.withValues(alpha: 0.1),
                          fg: DesignTokens.brandAccent,
                        ),
                      if (promo != CatalogPromo.none)
                        _SmallBadge(
                          text: promo.badgeText,
                          bg: promo.badgeColor,
                          fg: Colors.white,
                        ),
                    ],
                  ),
                ),
              Text(
                entry.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0D1B2E),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Price with accent underline
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: DesignTokens.brandAccent,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  entry.priceStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (entry.unit != null || entry.duration != null) ...[
                const SizedBox(height: 6),
                Text(
                  entry.unit != null
                      ? 'per ${entry.unit}'
                      : '${entry.duration} min',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A95A8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


// ── PROOF TILE (shared by Magazine, Grid, Story) ──────────────────────────

class _ProofTile extends StatelessWidget {
  const _ProofTile({
    required this.entry,
    required this.promo,
    this.hero = false,
    this.dark = false,
    required this.borderRadius,
  });

  final _CatalogEntry entry;
  final CatalogPromo promo;
  final bool hero;
  final bool dark;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image or fallback
          if (hasImage)
            OfflineCachedImage(
              imageUrl: entry.imageUrl!.trim(),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: _fallback(),
              errorWidget: _fallback(),
            )
          else
            _fallback(),

          // Multi-stop gradient — more cinematic than a 2-stop gradient
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.38, 0.72, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  (dark ? Colors.black : const Color(0xFF0A1628)).withValues(
                    alpha: 0.55,
                  ),
                  (dark ? Colors.black : const Color(0xFF0A1628)).withValues(
                    alpha: 0.93,
                  ),
                ],
              ),
            ),
          ),

          // Promo badge top-left
          if (promo != CatalogPromo.none)
            Positioned(
              top: hero ? 22 : 14,
              left: hero ? 22 : 14,
              child: _SmallBadge(
                text: promo.badgeText,
                bg: promo.badgeColor,
                fg: Colors.white,
              ),
            ),

          // Service tag top-right
          if (entry.isService)
            Positioned(
              top: hero ? 22 : 14,
              right: hero ? 22 : 14,
              child: _SmallBadge(
                text: 'SERVICE',
                bg: DesignTokens.brandAccent.withValues(alpha: 0.9),
                fg: Colors.white,
              ),
            ),

          // Bottom info panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.all(hero ? 26 : 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: hero ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: hero ? 30 : 20,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: hero ? 10 : 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.brandAccent,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      entry.priceStr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: hero ? 24 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFD6DCE8), const Color(0xFFBEC8D8)],
      ),
    ),
    child: Center(
      child: Icon(
        entry.isService
            ? Icons.room_service_outlined
            : Icons.inventory_2_outlined,
        size: hero ? 64 : 44,
        color: const Color(0xFFA0AEBC),
      ),
    ),
  );
}

// ── SMALL BADGE ──────────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── ENTRY MODEL ──────────────────────────────────────────────────────────────

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

  String get priceStr =>
      '${CatalogImagePreview._currencyFormat.format(price.round())} /=';
}
