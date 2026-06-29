import 'package:flutter/material.dart';

import 'overlay_presets.dart';

// ---------------------------------------------------------------------------
// Overlay Presets v2 — 20+ modern overlay types for Soko Studio
// ---------------------------------------------------------------------------

enum OverlayTypeV2 {
  swipeUp,
  socialHandle,
  ratingStars,
  asSeenOn,
  paymentMethods,
  openingHours,
  verifiedSeller,
  freeDelivery,
  limitedTime,
  beforeAfter,
  testimonialQuote,
  discountCode,
  referral,
  appDownload,
  locationMap,
  contactCard,
  productSpecs,
  comparison,
  processSteps,
  reviewCard,
}

extension OverlayTypeV2X on OverlayTypeV2 {
  String get label => switch (this) {
    OverlayTypeV2.swipeUp => 'Swipe Up',
    OverlayTypeV2.socialHandle => 'Social Handle',
    OverlayTypeV2.ratingStars => 'Rating Stars',
    OverlayTypeV2.asSeenOn => 'As Seen On',
    OverlayTypeV2.paymentMethods => 'Payment Methods',
    OverlayTypeV2.openingHours => 'Opening Hours',
    OverlayTypeV2.verifiedSeller => 'Verified Seller',
    OverlayTypeV2.freeDelivery => 'Free Delivery',
    OverlayTypeV2.limitedTime => 'Limited Time',
    OverlayTypeV2.beforeAfter => 'Before / After',
    OverlayTypeV2.testimonialQuote => 'Testimonial',
    OverlayTypeV2.discountCode => 'Discount Code',
    OverlayTypeV2.referral => 'Refer & Earn',
    OverlayTypeV2.appDownload => 'Get Our App',
    OverlayTypeV2.locationMap => 'Location Map',
    OverlayTypeV2.contactCard => 'Contact Card',
    OverlayTypeV2.productSpecs => 'Product Specs',
    OverlayTypeV2.comparison => 'Comparison',
    OverlayTypeV2.processSteps => 'Process Steps',
    OverlayTypeV2.reviewCard => 'Review Card',
  };

  OverlayAnchor get defaultAnchor => switch (this) {
    OverlayTypeV2.swipeUp => OverlayAnchor.bottomCenter,
    OverlayTypeV2.socialHandle => OverlayAnchor.topCenter,
    OverlayTypeV2.ratingStars => OverlayAnchor.topRight,
    OverlayTypeV2.asSeenOn => OverlayAnchor.bottomCenter,
    OverlayTypeV2.paymentMethods => OverlayAnchor.bottomCenter,
    OverlayTypeV2.openingHours => OverlayAnchor.topRight,
    OverlayTypeV2.verifiedSeller => OverlayAnchor.topLeft,
    OverlayTypeV2.freeDelivery => OverlayAnchor.topLeft,
    OverlayTypeV2.limitedTime => OverlayAnchor.fullTop,
    OverlayTypeV2.beforeAfter => OverlayAnchor.center,
    OverlayTypeV2.testimonialQuote => OverlayAnchor.bottomCenter,
    OverlayTypeV2.discountCode => OverlayAnchor.topRight,
    OverlayTypeV2.referral => OverlayAnchor.bottomCenter,
    OverlayTypeV2.appDownload => OverlayAnchor.bottomCenter,
    OverlayTypeV2.locationMap => OverlayAnchor.bottomLeft,
    OverlayTypeV2.contactCard => OverlayAnchor.bottomRight,
    OverlayTypeV2.productSpecs => OverlayAnchor.bottomLeft,
    OverlayTypeV2.comparison => OverlayAnchor.center,
    OverlayTypeV2.processSteps => OverlayAnchor.bottomCenter,
    OverlayTypeV2.reviewCard => OverlayAnchor.bottomRight,
  };
}

/// Creates a v2 overlay layer pre-filled with brand context.
OverlayLayer buildPresetV2({
  required OverlayTypeV2 type,
  required OverlayBrandContext ctx,
}) {
  final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
  final businessName = ctx.businessName;
  final brandPrimary = ctx.brandPrimary;
  final brandAccent = ctx.brandAccent;

  switch (type) {
    case OverlayTypeV2.swipeUp:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: '👆 SWIPE UP',
        secondaryText: businessName.isNotEmpty ? businessName : 'Shop Now',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayTypeV2.socialHandle:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.topCenter,
        primaryText: '@${businessName.toLowerCase().replaceAll(' ', '')}',
        secondaryText: 'Follow us for more',
        bgColor: brandPrimary.withValues(alpha: 0.85), accentColor: brandAccent,
      );

    case OverlayTypeV2.ratingStars:
      return OverlayLayer(
        id: id, type: OverlayType.trustBadge, anchor: OverlayAnchor.topRight,
        primaryText: '★★★★★',
        secondaryText: '4.9/5 Rating',
        bgColor: const Color(0xFFfbbf24), accentColor: brandAccent, textColor: Colors.black,
      );

    case OverlayTypeV2.asSeenOn:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: 'As seen on Soko24',
        secondaryText: businessName.isNotEmpty ? businessName : 'Trusted Shop',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayTypeV2.paymentMethods:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: '💳 Mobile Money · Bank · Cash',
        secondaryText: 'Secure payments accepted',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayTypeV2.openingHours:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.topRight,
        primaryText: '🕐 Open Now',
        secondaryText: 'Mon–Sat 8AM–6PM',
        bgColor: const Color(0xFF16a34a), accentColor: brandAccent,
      );

    case OverlayTypeV2.verifiedSeller:
      return OverlayLayer(
        id: id, type: OverlayType.trustBadge, anchor: OverlayAnchor.topLeft,
        primaryText: '✓ VERIFIED',
        secondaryText: 'Soko24 Seller',
        bgColor: const Color(0xFF3b82f6), accentColor: brandAccent,
      );

    case OverlayTypeV2.freeDelivery:
      return OverlayLayer(
        id: id, type: OverlayType.deliveryBadge, anchor: OverlayAnchor.topLeft,
        primaryText: '🚚 FREE DELIVERY',
        secondaryText: 'Kampala & beyond',
        bgColor: const Color(0xFF0f766e), accentColor: brandAccent,
      );

    case OverlayTypeV2.limitedTime:
      return OverlayLayer(
        id: id, type: OverlayType.countdown, anchor: OverlayAnchor.fullTop,
        primaryText: '⏰ LIMITED TIME OFFER',
        secondaryText: 'Ends soon — order now!',
        tertiaryText: businessName.isNotEmpty ? businessName : '',
        bgColor: const Color(0xFFdc2626), accentColor: brandAccent,
      );

    case OverlayTypeV2.beforeAfter:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.center,
        primaryText: 'BEFORE → AFTER',
        secondaryText: 'See the difference',
        bgColor: brandPrimary.withValues(alpha: 0.8), accentColor: brandAccent,
      );

    case OverlayTypeV2.testimonialQuote:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: '"Amazing quality!"',
        secondaryText: '— Happy Customer',
        bgColor: brandPrimary.withValues(alpha: 0.85), accentColor: brandAccent,
      );

    case OverlayTypeV2.discountCode:
      return OverlayLayer(
        id: id, type: OverlayType.saleRibbon, anchor: OverlayAnchor.topRight,
        primaryText: 'USE CODE: SOKO10',
        secondaryText: '10% off your order',
        bgColor: const Color(0xFF7c3aed), accentColor: brandAccent,
      );

    case OverlayTypeV2.referral:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: 'REFER & EARN',
        secondaryText: 'Share with friends, get rewards',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayTypeV2.appDownload:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: '📱 Get Our App',
        secondaryText: 'Shop faster & easier',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayTypeV2.locationMap:
      return OverlayLayer(
        id: id, type: OverlayType.logoBadge, anchor: OverlayAnchor.bottomLeft,
        primaryText: '📍 ${ctx.contactLocation}',
        secondaryText: ctx.contactPhone,
        bgColor: brandPrimary.withValues(alpha: 0.9), accentColor: brandAccent,
      );

    case OverlayTypeV2.contactCard:
      return OverlayLayer(
        id: id, type: OverlayType.contactStrip, anchor: OverlayAnchor.bottomRight,
        primaryText: ctx.contactPhone,
        secondaryText: ctx.contactWhatsapp,
        bgColor: brandPrimary.withValues(alpha: 0.9), accentColor: brandAccent,
      );

    case OverlayTypeV2.productSpecs:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomLeft,
        primaryText: '✓ Premium Quality',
        secondaryText: '✓ Fast Delivery  ✓ Best Price',
        bgColor: brandPrimary.withValues(alpha: 0.85), accentColor: brandAccent,
      );

    case OverlayTypeV2.comparison:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.center,
        primaryText: 'US vs THEM',
        secondaryText: 'See why we\'re better',
        bgColor: brandPrimary.withValues(alpha: 0.8), accentColor: brandAccent,
      );

    case OverlayTypeV2.processSteps:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomCenter,
        primaryText: '1 → 2 → 3',
        secondaryText: 'Order · Pay · Receive',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayTypeV2.reviewCard:
      return OverlayLayer(
        id: id, type: OverlayType.promoBar, anchor: OverlayAnchor.bottomRight,
        primaryText: '★★★★★',
        secondaryText: '"Best shop in Kampala!"',
        bgColor: const Color(0xFFfbbf24), accentColor: brandAccent, textColor: Colors.black,
      );
  }
}

/// All v2 overlay types for UI listing.
const overlayTypesV2 = <OverlayTypeV2>[
  OverlayTypeV2.swipeUp,
  OverlayTypeV2.socialHandle,
  OverlayTypeV2.ratingStars,
  OverlayTypeV2.verifiedSeller,
  OverlayTypeV2.freeDelivery,
  OverlayTypeV2.limitedTime,
  OverlayTypeV2.discountCode,
  OverlayTypeV2.openingHours,
  OverlayTypeV2.paymentMethods,
  OverlayTypeV2.asSeenOn,
  OverlayTypeV2.testimonialQuote,
  OverlayTypeV2.reviewCard,
  OverlayTypeV2.beforeAfter,
  OverlayTypeV2.comparison,
  OverlayTypeV2.processSteps,
  OverlayTypeV2.productSpecs,
  OverlayTypeV2.referral,
  OverlayTypeV2.appDownload,
  OverlayTypeV2.locationMap,
  OverlayTypeV2.contactCard,
];
