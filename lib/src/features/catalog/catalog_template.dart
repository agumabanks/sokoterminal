import 'package:flutter/material.dart';

/// Professional catalog layout templates.
///
/// Each template defines the visual language, recommended item count,
/// and aspect ratio for the exported shareable image.
enum CatalogLayout {
  /// Newspaper-style: one hero item + supporting grid.
  /// Best for 5–7 items. Aspect 4:5 (portrait).
  magazine,

  /// Instagram-style square grid.
  /// Best for 4, 6, or 9 items. Aspect 1:1.
  grid,

  /// Vertical story / lookbook: full-bleed cards stacked.
  /// Best for 3–5 items. Aspect 9:16 (portrait).
  story,

  /// Apple Store-style clean list with large images.
  /// Best for 4–6 items. Aspect 4:5 (portrait).
  minimal,
}

extension CatalogLayoutExt on CatalogLayout {
  String get displayName {
    switch (this) {
      case CatalogLayout.magazine:
        return 'Magazine';
      case CatalogLayout.grid:
        return 'Grid';
      case CatalogLayout.story:
        return 'Story';
      case CatalogLayout.minimal:
        return 'Minimal';
    }
  }

  String get description {
    switch (this) {
      case CatalogLayout.magazine:
        return 'Hero feature + editorial grid. Great for launches.';
      case CatalogLayout.grid:
        return 'Clean square grid. Perfect for social feeds.';
      case CatalogLayout.story:
        return 'Full-bleed lookbook. Scroll-friendly vertical format.';
      case CatalogLayout.minimal:
        return 'Large images, airy spacing. Premium feel.';
    }
  }

  IconData get icon {
    switch (this) {
      case CatalogLayout.magazine:
        return Icons.article_outlined;
      case CatalogLayout.grid:
        return Icons.grid_view_outlined;
      case CatalogLayout.story:
        return Icons.view_agenda_outlined;
      case CatalogLayout.minimal:
        return Icons.auto_awesome_outlined;
    }
  }

  /// Recommended default item count for this layout.
  int get defaultItemCount {
    switch (this) {
      case CatalogLayout.magazine:
        return 5;
      case CatalogLayout.grid:
        return 6;
      case CatalogLayout.story:
        return 4;
      case CatalogLayout.minimal:
        return 4;
    }
  }

  /// Maximum items this layout handles well.
  int get maxRecommended {
    switch (this) {
      case CatalogLayout.magazine:
        return 7;
      case CatalogLayout.grid:
        return 9;
      case CatalogLayout.story:
        return 5;
      case CatalogLayout.minimal:
        return 6;
    }
  }

  /// Ideal aspect ratio for the exported image (width / height).
  double get aspectRatio {
    switch (this) {
      case CatalogLayout.magazine:
        return 4 / 5;
      case CatalogLayout.grid:
        return 1;
      case CatalogLayout.story:
        return 9 / 16;
      case CatalogLayout.minimal:
        return 4 / 5;
    }
  }

  /// Width in logical pixels for the off-screen render.
  double get renderWidth {
    switch (this) {
      case CatalogLayout.magazine:
        return 1080;
      case CatalogLayout.grid:
        return 1080;
      case CatalogLayout.story:
        return 1080;
      case CatalogLayout.minimal:
        return 1080;
    }
  }

  /// Render height derived from width and aspect ratio.
  double get renderHeight => renderWidth / aspectRatio;
}

/// Promotional overlay that can be applied to any catalog.
enum CatalogPromo {
  none,
  sale,
  newArrival,
  limitedTime,
  bestSeller,
}

extension CatalogPromoExt on CatalogPromo {
  String get displayName {
    switch (this) {
      case CatalogPromo.none:
        return 'No promo';
      case CatalogPromo.sale:
        return 'Sale';
      case CatalogPromo.newArrival:
        return 'New Arrival';
      case CatalogPromo.limitedTime:
        return 'Limited Time';
      case CatalogPromo.bestSeller:
        return 'Best Seller';
    }
  }

  String get badgeText {
    switch (this) {
      case CatalogPromo.none:
        return '';
      case CatalogPromo.sale:
        return 'ON SALE';
      case CatalogPromo.newArrival:
        return 'NEW';
      case CatalogPromo.limitedTime:
        return 'LIMITED';
      case CatalogPromo.bestSeller:
        return 'TOP RATED';
    }
  }

  Color get badgeColor {
    switch (this) {
      case CatalogPromo.none:
        return Colors.transparent;
      case CatalogPromo.sale:
        return const Color(0xFFE53E3E);
      case CatalogPromo.newArrival:
        return const Color(0xFF4299E1);
      case CatalogPromo.limitedTime:
        return const Color(0xFFF6AD55);
      case CatalogPromo.bestSeller:
        return const Color(0xFF0EBE7E);
    }
  }

  String get bannerText {
    switch (this) {
      case CatalogPromo.none:
        return '';
      case CatalogPromo.sale:
        return 'Special Prices This Week';
      case CatalogPromo.newArrival:
        return 'Just Dropped — Shop Now';
      case CatalogPromo.limitedTime:
        return 'While Stock Lasts';
      case CatalogPromo.bestSeller:
        return 'Customer Favourites';
    }
  }
}

/// A saved/catalog campaign the user is building.
class CatalogCampaign {
  const CatalogCampaign({
    this.title = '',
    this.layout = CatalogLayout.magazine,
    this.promo = CatalogPromo.none,
    this.selectedProductIds = const {},
    this.selectedServiceIds = const {},
    this.includeServices = false,
    this.customDiscount,
    this.customMessage,
  });

  final String title;
  final CatalogLayout layout;
  final CatalogPromo promo;
  final Set<String> selectedProductIds;
  final Set<String> selectedServiceIds;
  final bool includeServices;
  final double? customDiscount;
  final String? customMessage;

  CatalogCampaign copyWith({
    String? title,
    CatalogLayout? layout,
    CatalogPromo? promo,
    Set<String>? selectedProductIds,
    Set<String>? selectedServiceIds,
    bool? includeServices,
    double? customDiscount,
    String? customMessage,
  }) {
    return CatalogCampaign(
      title: title ?? this.title,
      layout: layout ?? this.layout,
      promo: promo ?? this.promo,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      selectedServiceIds: selectedServiceIds ?? this.selectedServiceIds,
      includeServices: includeServices ?? this.includeServices,
      customDiscount: customDiscount ?? this.customDiscount,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  int get selectedCount =>
      selectedProductIds.length + selectedServiceIds.length;
}
