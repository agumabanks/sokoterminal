import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

enum OverlayType {
  logoBadge,         // Corner brand badge — business name + tagline
  newsTicker,        // Full-width bottom scroll bar (TV-style)
  saleRibbon,        // Diagonal corner ribbon (SALE / HOT / NEW)
  priceTag,          // Speech-bubble price indicator
  promoBar,          // Full-width bottom CTA gradient bar
  breakingNews,      // TV lower-third with logo box + headline + subline
  watermark,         // Centre semi-transparent brand watermark
  storyFrame,        // Header + footer brand strips (Reels/Stories style)
  contactStrip,      // Slim bar: phone · WhatsApp · location
  productSpotlight,  // Product name + price inline badge
  flashSale,         // Bold centred flash-sale banner
  countdown,         // Urgency strip — ends soon / limited time
  trustBadge,        // Verified / quality trust pill
  deliveryBadge,     // Free delivery / fast shipping callout
  limitedStock,      // Scarcity — only X left
  newArrival,        // NEW / JUST IN corner ribbon
}

enum OverlayAnchor {
  topLeft, topRight, topCenter,
  bottomLeft, bottomRight, bottomCenter,
  center,
  fullBottom, // spans full width, sticks to bottom
  fullTop,    // spans full width, sticks to top
  fullFrame,  // top + bottom strips (storyFrame only)
}

class OverlayLayer {
  OverlayLayer({
    required this.id,
    required this.type,
    required this.anchor,
    this.primaryText = '',
    this.secondaryText = '',
    this.tertiaryText = '',
    this.bgColor = const Color(0xFF0F1D40),
    this.accentColor = const Color(0xFF0EBE7E),
    this.textColor = Colors.white,
    this.opacity = 1.0,
    this.fontFamily = 'Inter',
    this.isSelected = false,
  });

  final String id;
  final OverlayType type;
  final OverlayAnchor anchor;
  String primaryText;
  String secondaryText;
  String tertiaryText;
  Color bgColor;
  Color accentColor;
  Color textColor;
  double opacity;
  String fontFamily;
  bool isSelected;

  OverlayLayer copyWith({
    OverlayAnchor? anchor,
    String? primaryText,
    String? secondaryText,
    String? tertiaryText,
    Color? bgColor,
    Color? accentColor,
    Color? textColor,
    double? opacity,
    String? fontFamily,
    bool? isSelected,
  }) =>
      OverlayLayer(
        id: id,
        type: type,
        anchor: anchor ?? this.anchor,
        primaryText: primaryText ?? this.primaryText,
        secondaryText: secondaryText ?? this.secondaryText,
        tertiaryText: tertiaryText ?? this.tertiaryText,
        bgColor: bgColor ?? this.bgColor,
        accentColor: accentColor ?? this.accentColor,
        textColor: textColor ?? this.textColor,
        opacity: opacity ?? this.opacity,
        fontFamily: fontFamily ?? this.fontFamily,
        isSelected: isSelected ?? this.isSelected,
      );
}

// ---------------------------------------------------------------------------
// Brand + product context
// ---------------------------------------------------------------------------

class OverlayBrandContext {
  const OverlayBrandContext({
    required this.businessName,
    required this.tagline,
    required this.brandPrimary,
    required this.brandAccent,
    this.phone = '',
    this.whatsapp = '',
    this.location = '',
    this.website = 'soko24.co',
    this.productName = '',
    this.productPrice = '',
    this.productWasPrice = '',
  });

  final String businessName;
  final String tagline;
  final Color brandPrimary;
  final Color brandAccent;
  final String phone;
  final String whatsapp;
  final String location;
  final String website;
  final String productName;
  final String productPrice;
  final String productWasPrice;

  String get contactPhone =>
      phone.isNotEmpty ? '📞 $phone' : '📞 Call us today';

  String get contactWhatsapp => whatsapp.isNotEmpty
      ? '💬 $whatsapp'
      : '💬 WhatsApp Us';

  String get contactLocation =>
      location.isNotEmpty ? '📍 $location' : '📍 Kampala, Uganda';

  String get displayProduct =>
      productName.isNotEmpty ? productName : 'Your Product';

  String get displayPrice =>
      productPrice.isNotEmpty ? productPrice : 'UGX —';

  String get displayWebsite =>
      website.isNotEmpty ? website.replaceFirst(RegExp(r'^https?://'), '') : 'soko24.co';
}

// ---------------------------------------------------------------------------
// Preset factory
// ---------------------------------------------------------------------------

/// Creates a default overlay layer for the given type, pre-filled with brand
/// kit and optional product details.
OverlayLayer buildPreset({
  required OverlayType type,
  required OverlayBrandContext ctx,
}) {
  final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
  final businessName = ctx.businessName;
  final tagline = ctx.tagline;
  final brandPrimary = ctx.brandPrimary;
  final brandAccent = ctx.brandAccent;
  switch (type) {
    case OverlayType.logoBadge:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.bottomLeft,
        primaryText: businessName.isNotEmpty ? businessName : 'Your Brand',
        secondaryText: tagline.isNotEmpty ? tagline : 'soko24.co',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayType.newsTicker:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.fullBottom,
        primaryText: '${businessName.isNotEmpty ? businessName.toUpperCase() : 'YOUR BRAND'}  •  ',
        secondaryText: 'SALE NOW ON  |  UP TO 50% OFF  |  CALL US TODAY  |',
        tertiaryText: 'LIMITED STOCK AVAILABLE  |  FREE DELIVERY KAMPALA',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayType.saleRibbon:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.topRight,
        primaryText: 'SALE',
        bgColor: const Color(0xFFdc2626), accentColor: brandAccent,
      );

    case OverlayType.priceTag:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.bottomRight,
        primaryText: ctx.displayPrice,
        secondaryText: ctx.productWasPrice,
        bgColor: brandAccent, accentColor: brandPrimary, textColor: Colors.white,
      );

    case OverlayType.promoBar:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.fullBottom,
        primaryText: businessName.isNotEmpty ? businessName : 'Your Brand',
        secondaryText: 'SHOP NOW  →',
        tertiaryText: ctx.displayWebsite,
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayType.breakingNews:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.fullBottom,
        primaryText: 'BREAKING',
        secondaryText: businessName.isNotEmpty
            ? '${businessName.toUpperCase()} — BIG SALE NOW ON'
            : 'BIG SALE — LIMITED OFFER ENDS TONIGHT',
        tertiaryText: tagline.isNotEmpty ? tagline : 'Soko 24 • Uganda\'s #1 Marketplace',
        bgColor: brandPrimary, accentColor: const Color(0xFFdc2626),
      );

    case OverlayType.watermark:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.center,
        primaryText: businessName.isNotEmpty ? businessName : 'YOUR BRAND',
        secondaryText: 'soko24.co',
        bgColor: Colors.transparent, accentColor: brandAccent,
        textColor: Colors.white, opacity: 0.35,
      );

    case OverlayType.storyFrame:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.fullFrame,
        primaryText: businessName.isNotEmpty ? businessName : 'Your Brand',
        secondaryText: tagline.isNotEmpty ? tagline : 'Quality • Style • Value',
        tertiaryText: 'soko24.co',
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayType.contactStrip:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.fullBottom,
        primaryText: ctx.contactPhone,
        secondaryText: ctx.contactWhatsapp,
        tertiaryText: ctx.contactLocation,
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayType.productSpotlight:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.bottomLeft,
        primaryText: ctx.displayProduct,
        secondaryText: ctx.displayPrice,
        bgColor: brandPrimary, accentColor: brandAccent,
      );

    case OverlayType.flashSale:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.center,
        primaryText: 'FLASH SALE',
        secondaryText: ctx.displayPrice,
        tertiaryText: 'TODAY ONLY',
        bgColor: const Color(0xFFdc2626), accentColor: brandAccent,
        textColor: Colors.white, opacity: 0.92,
      );

    case OverlayType.countdown:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.fullTop,
        primaryText: 'ENDS SOON',
        secondaryText: 'ORDER NOW BEFORE IT\'S GONE',
        tertiaryText: ctx.displayWebsite,
        bgColor: brandPrimary, accentColor: const Color(0xFFdc2626),
      );

    case OverlayType.trustBadge:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.topLeft,
        primaryText: '✓ Trusted Seller',
        secondaryText: businessName.isNotEmpty ? businessName : 'Verified on Soko24',
        bgColor: brandPrimary.withValues(alpha: 0.88), accentColor: brandAccent,
      );

    case OverlayType.deliveryBadge:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.topCenter,
        primaryText: '🚚 FREE DELIVERY',
        secondaryText: ctx.location.isNotEmpty ? ctx.location : 'Kampala & nearby',
        bgColor: brandAccent, accentColor: brandPrimary, textColor: Colors.white,
      );

    case OverlayType.limitedStock:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.topRight,
        primaryText: '⚡ LIMITED STOCK',
        secondaryText: 'Order while available',
        bgColor: const Color(0xFFf59e0b), accentColor: brandPrimary,
        textColor: Colors.black,
      );

    case OverlayType.newArrival:
      return OverlayLayer(
        id: id, type: type, anchor: OverlayAnchor.topRight,
        primaryText: 'NEW',
        bgColor: brandAccent, accentColor: brandPrimary, textColor: Colors.white,
      );
  }
}

/// One-tap overlay stacks for common seller promos.
List<OverlayLayer> buildComboLayers({
  required String comboId,
  required OverlayBrandContext ctx,
}) {
  final combo = overlayComboCatalogue.firstWhere(
    (c) => c.id == comboId,
    orElse: () => overlayComboCatalogue.first,
  );
  return [
    for (final type in combo.types) buildPreset(type: type, ctx: ctx),
  ];
}

// ---------------------------------------------------------------------------
// Preset catalogue (shown in the picker strip)
// ---------------------------------------------------------------------------

const overlayPresetCatalogue = <({
  OverlayType type,
  String label,
  String emoji,
  String description,
})>[
  (type: OverlayType.newsTicker,      label: 'News Ticker',      emoji: '📺', description: 'TV-style scrolling text bar'),
  (type: OverlayType.breakingNews,    label: 'Breaking News',    emoji: '🔴', description: 'CNN/BBC lower-third layout'),
  (type: OverlayType.storyFrame,      label: 'Story Frame',      emoji: '🎬', description: 'Header + footer brand strips'),
  (type: OverlayType.promoBar,        label: 'Promo Bar',        emoji: '🏷️', description: 'Full-width CTA gradient bar'),
  (type: OverlayType.logoBadge,       label: 'Logo Badge',       emoji: '🏷️', description: 'Brand name corner badge'),
  (type: OverlayType.saleRibbon,      label: 'Sale Ribbon',      emoji: '🎀', description: 'Diagonal corner ribbon'),
  (type: OverlayType.priceTag,        label: 'Price Tag',        emoji: '💰', description: 'Price bubble indicator'),
  (type: OverlayType.productSpotlight,label: 'Product Tag',      emoji: '✨', description: 'Name + price inline tag'),
  (type: OverlayType.contactStrip,    label: 'Contact Strip',    emoji: '📞', description: 'Phone · WhatsApp · location'),
  (type: OverlayType.watermark,       label: 'Watermark',        emoji: '💧', description: 'Semi-transparent brand stamp'),
  (type: OverlayType.flashSale,       label: 'Flash Sale',       emoji: '🔥', description: 'Bold centre sale banner'),
  (type: OverlayType.countdown,       label: 'Ends Soon',        emoji: '⏰', description: 'Urgency top strip'),
  (type: OverlayType.trustBadge,      label: 'Trust Badge',      emoji: '✓', description: 'Verified seller pill'),
  (type: OverlayType.deliveryBadge,   label: 'Free Delivery',    emoji: '🚚', description: 'Shipping callout'),
  (type: OverlayType.limitedStock,    label: 'Limited Stock',    emoji: '⚡', description: 'Scarcity alert'),
  (type: OverlayType.newArrival,      label: 'New Arrival',      emoji: '✨', description: 'Just-in corner ribbon'),
];

const overlayComboCatalogue = <({
  String id,
  String label,
  String emoji,
  String description,
  List<OverlayType> types,
})>[
  (
    id: 'product_sale',
    label: 'Product Sale',
    emoji: '🛍️',
    description: 'Ribbon + product tag + price',
    types: [OverlayType.saleRibbon, OverlayType.productSpotlight, OverlayType.priceTag],
  ),
  (
    id: 'story_promo',
    label: 'Story Promo',
    emoji: '📱',
    description: 'Reels frame + sale ribbon',
    types: [OverlayType.storyFrame, OverlayType.saleRibbon, OverlayType.logoBadge],
  ),
  (
    id: 'tv_broadcast',
    label: 'TV Broadcast',
    emoji: '📺',
    description: 'Breaking news + ticker',
    types: [OverlayType.breakingNews, OverlayType.newsTicker],
  ),
  (
    id: 'full_promo',
    label: 'Full Promo',
    emoji: '🔥',
    description: 'Flash sale + contact + delivery',
    types: [OverlayType.flashSale, OverlayType.deliveryBadge, OverlayType.contactStrip],
  ),
  (
    id: 'trust_shop',
    label: 'Trust & Shop',
    emoji: '✓',
    description: 'Trust badge + promo CTA',
    types: [OverlayType.trustBadge, OverlayType.promoBar, OverlayType.watermark],
  ),
  (
    id: 'urgency_pack',
    label: 'Urgency Pack',
    emoji: '⚡',
    description: 'Countdown + limited + price',
    types: [OverlayType.countdown, OverlayType.limitedStock, OverlayType.priceTag],
  ),
];

// ---------------------------------------------------------------------------
// Overlay renderer widgets
// ---------------------------------------------------------------------------

/// Renders a single [OverlayLayer] as a Widget positioned within the compositor.
class OverlayRenderer extends StatelessWidget {
  const OverlayRenderer({
    super.key,
    required this.layer,
    required this.compositorSize,
    this.onTap,
  });

  final OverlayLayer layer;
  final Size compositorSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final widget = GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: layer.opacity.clamp(0.0, 1.0),
        child: _buildOverlay(context),
      ),
    );

    // Selection ring
    if (layer.isSelected) {
      return Stack(
        children: [
          widget,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF0EBE7E),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return widget;
  }

  Widget _buildOverlay(BuildContext context) {
    switch (layer.type) {
      case OverlayType.logoBadge:      return _LogoBadge(layer: layer, size: compositorSize);
      case OverlayType.newsTicker:     return _NewsTicker(layer: layer, size: compositorSize);
      case OverlayType.saleRibbon:     return _SaleRibbon(layer: layer, size: compositorSize);
      case OverlayType.priceTag:       return _PriceTag(layer: layer, size: compositorSize);
      case OverlayType.promoBar:       return _PromoBar(layer: layer, size: compositorSize);
      case OverlayType.breakingNews:   return _BreakingNews(layer: layer, size: compositorSize);
      case OverlayType.watermark:      return _Watermark(layer: layer, size: compositorSize);
      case OverlayType.storyFrame:     return _StoryFrame(layer: layer, size: compositorSize);
      case OverlayType.contactStrip:   return _ContactStrip(layer: layer, size: compositorSize);
      case OverlayType.productSpotlight: return _ProductSpotlight(layer: layer, size: compositorSize);
      case OverlayType.flashSale:      return _FlashSale(layer: layer, size: compositorSize);
      case OverlayType.countdown:      return _CountdownStrip(layer: layer, size: compositorSize);
      case OverlayType.trustBadge:     return _TrustBadge(layer: layer, size: compositorSize);
      case OverlayType.deliveryBadge:  return _DeliveryBadge(layer: layer, size: compositorSize);
      case OverlayType.limitedStock:   return _LimitedStock(layer: layer, size: compositorSize);
      case OverlayType.newArrival:     return _SaleRibbon(layer: layer, size: compositorSize);
    }
  }
}

// ── Logo Badge ───────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final pad = size.width * 0.03;
    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.018,
      ),
      decoration: BoxDecoration(
        color: layer.bgColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(size.width * 0.025),
        border: Border.all(color: layer.accentColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size.width * 0.04,
                height: size.width * 0.04,
                decoration: BoxDecoration(
                  color: layer.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: size.width * 0.015),
              Text(
                layer.primaryText,
                style: _ts(size.width * 0.042, FontWeight.w800, layer.textColor),
              ),
            ],
          ),
          if (layer.secondaryText.isNotEmpty) ...[
            SizedBox(height: size.height * 0.003),
            Text(
              layer.secondaryText,
              style: _ts(size.width * 0.026, FontWeight.w400,
                  layer.textColor.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );

    return Align(
      alignment: _toAlignment(layer.anchor),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: badge,
      ),
    );
  }
}

// ── News Ticker ───────────────────────────────────────────────────────────────

class _NewsTicker extends StatefulWidget {
  const _NewsTicker({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  State<_NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<_NewsTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _offset = Tween<double>(begin: 1.0, end: -1.5).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final size = widget.size;
    final barH = size.height * 0.1;
    final labelW = size.width * 0.22;

    final tickerText =
        '${layer.primaryText}  ${layer.secondaryText}  ${layer.tertiaryText}  '
        '${layer.primaryText}  ${layer.secondaryText}  ';

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: SizedBox(
        height: barH,
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(color: layer.bgColor.withValues(alpha: 0.95)),
            ),
            // Label box
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: labelW,
              child: Container(
                color: layer.accentColor,
                child: Center(
                  child: Text(
                    'LIVE',
                    style: _ts(size.width * 0.038, FontWeight.w900, Colors.white),
                  ),
                ),
              ),
            ),
            // Scrolling text
            Positioned(
              left: labelW, right: 0, top: 0, bottom: 0,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _offset,
                  builder: (_, __) => FractionalTranslation(
                    translation: Offset(_offset.value, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tickerText,
                        style: _ts(size.width * 0.036, FontWeight.w600,
                            layer.textColor),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sale Ribbon ───────────────────────────────────────────────────────────────

class _SaleRibbon extends StatelessWidget {
  const _SaleRibbon({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final ribbonW = size.width * 0.38;
    final isRight = layer.anchor == OverlayAnchor.topRight ||
        layer.anchor == OverlayAnchor.bottomRight;

    return Positioned(
      top: 0,
      right: isRight ? 0 : null,
      left: isRight ? null : 0,
      child: ClipRect(
        child: SizedBox(
          width: ribbonW,
          height: ribbonW,
          child: CustomPaint(
            painter: _RibbonPainter(
              color: layer.bgColor,
              text: layer.primaryText,
              textColor: layer.textColor,
              fontSize: size.width * 0.048,
              mirrored: isRight,
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({
    required this.color,
    required this.text,
    required this.textColor,
    required this.fontSize,
    this.mirrored = false,
  });

  final Color color;
  final String text;
  final Color textColor;
  final double fontSize;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas.save();
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);

    // Draw text diagonally
    canvas.save();
    canvas.translate(size.width * 0.2, size.height * 0.16);
    canvas.rotate(-0.785); // -45°

    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();

    if (mirrored) canvas.restore();
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.color != color || old.text != text;
}

// ── Price Tag ─────────────────────────────────────────────────────────────────

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final pad = size.width * 0.03;
    return Align(
      alignment: _toAlignment(layer.anchor),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.height * 0.02,
          ),
          decoration: BoxDecoration(
            color: layer.bgColor,
            borderRadius: BorderRadius.circular(size.width * 0.03),
            boxShadow: [
              BoxShadow(
                color: layer.bgColor.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                layer.primaryText,
                style: _ts(size.width * 0.06, FontWeight.w900, layer.textColor),
              ),
              if (layer.secondaryText.isNotEmpty)
                Text(
                  layer.secondaryText,
                  style: _ts(
                    size.width * 0.026,
                    FontWeight.w400,
                    layer.textColor.withValues(alpha: 0.7),
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Promo Bar ─────────────────────────────────────────────────────────────────

class _PromoBar extends StatelessWidget {
  const _PromoBar({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.05,
          vertical: size.height * 0.03,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [layer.bgColor, layer.accentColor],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    layer.primaryText,
                    style: _ts(size.width * 0.05, FontWeight.w800, layer.textColor),
                  ),
                  if (layer.tertiaryText.isNotEmpty)
                    Text(
                      layer.tertiaryText,
                      style: _ts(size.width * 0.025, FontWeight.w400,
                          layer.textColor.withValues(alpha: 0.75)),
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: size.height * 0.015,
              ),
              decoration: BoxDecoration(
                color: layer.textColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                layer.secondaryText,
                style: _ts(size.width * 0.036, FontWeight.w700, layer.bgColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Breaking News ─────────────────────────────────────────────────────────────

class _BreakingNews extends StatelessWidget {
  const _BreakingNews({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final totalH = size.height * 0.22;
    final labelW = size.width * 0.28;
    final accentH = size.height * 0.06;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: SizedBox(
        height: totalH,
        child: Stack(
          children: [
            // Dark translucent base
            Positioned.fill(
              child: Container(
                color: layer.bgColor.withValues(alpha: 0.92),
              ),
            ),

            // Accent label bar (left column — "BREAKING" badge)
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: labelW,
              child: Container(
                color: layer.accentColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      layer.primaryText,
                      style: _ts(size.width * 0.042, FontWeight.w900,
                          Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.006),
                    Container(
                      width: size.width * 0.12,
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: size.height * 0.006),
                    Text(
                      'NEWS',
                      style: _ts(size.width * 0.028, FontWeight.w500,
                          Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ),

            // Headline + subline (right area)
            Positioned(
              left: labelW + size.width * 0.03,
              right: 0,
              top: 0,
              bottom: accentH,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layer.secondaryText,
                    style: _ts(size.width * 0.044, FontWeight.w700,
                        layer.textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Bottom thin accent strip with tertiary text
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: accentH,
              child: Container(
                color: layer.bgColor,
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    layer.tertiaryText,
                    style: _ts(size.width * 0.026, FontWeight.w400,
                        layer.textColor.withValues(alpha: 0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Watermark ─────────────────────────────────────────────────────────────────

class _Watermark extends StatelessWidget {
  const _Watermark({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              layer.primaryText.toUpperCase(),
              style: _ts(size.width * 0.1, FontWeight.w900,
                  layer.textColor.withValues(alpha: layer.opacity)),
              textAlign: TextAlign.center,
            ),
            Text(
              layer.secondaryText,
              style: _ts(size.width * 0.04, FontWeight.w400,
                  layer.textColor.withValues(alpha: layer.opacity * 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Story Frame ───────────────────────────────────────────────────────────────

class _StoryFrame extends StatelessWidget {
  const _StoryFrame({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final headerH = size.height * 0.13;
    final footerH = size.height * 0.11;

    return Stack(
      children: [
        // Header strip
        Positioned(
          left: 0, right: 0, top: 0,
          height: headerH,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  layer.bgColor.withValues(alpha: 0.95),
                  layer.bgColor.withValues(alpha: 0.0),
                ],
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.05,
              vertical: size.height * 0.025,
            ),
            child: Row(
              children: [
                Container(
                  width: size.width * 0.08,
                  height: size.width * 0.08,
                  decoration: BoxDecoration(
                    color: layer.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      layer.primaryText.isNotEmpty
                          ? layer.primaryText[0].toUpperCase()
                          : 'S',
                      style: _ts(size.width * 0.04, FontWeight.w900,
                          layer.bgColor),
                    ),
                  ),
                ),
                SizedBox(width: size.width * 0.03),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      layer.primaryText,
                      style: _ts(size.width * 0.042, FontWeight.w700,
                          Colors.white),
                    ),
                    Text(
                      layer.secondaryText,
                      style: _ts(size.width * 0.025, FontWeight.w400,
                          Colors.white.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Footer strip
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: footerH,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  layer.bgColor.withValues(alpha: 0.95),
                  layer.bgColor.withValues(alpha: 0.0),
                ],
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.05,
              vertical: size.height * 0.02,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                layer.tertiaryText,
                style: _ts(size.width * 0.028, FontWeight.w500,
                    Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Contact Strip ─────────────────────────────────────────────────────────────

class _ContactStrip extends StatelessWidget {
  const _ContactStrip({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        color: layer.bgColor.withValues(alpha: 0.94),
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.018,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _contactItem(layer.primaryText, size),
            _divider(size),
            _contactItem(layer.secondaryText, size),
            _divider(size),
            _contactItem(layer.tertiaryText, size),
          ],
        ),
      ),
    );
  }

  Widget _contactItem(String text, Size size) => Text(
        text,
        style: _ts(size.width * 0.028, FontWeight.w600, layer.textColor),
      );

  Widget _divider(Size size) => Container(
        width: 1,
        height: size.height * 0.04,
        color: layer.accentColor.withValues(alpha: 0.5),
      );
}

// ── Product Spotlight ─────────────────────────────────────────────────────────

class _ProductSpotlight extends StatelessWidget {
  const _ProductSpotlight({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final pad = size.width * 0.03;
    return Align(
      alignment: _toAlignment(layer.anchor),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.035,
                  vertical: size.height * 0.014,
                ),
                decoration: BoxDecoration(
                  color: layer.bgColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size.width * 0.02),
                    topRight: Radius.circular(size.width * 0.02),
                  ),
                ),
                child: Text(
                  layer.primaryText,
                  style: _ts(size.width * 0.036, FontWeight.w600,
                      layer.textColor),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.035,
                  vertical: size.height * 0.012,
                ),
                decoration: BoxDecoration(
                  color: layer.accentColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(size.width * 0.02),
                    bottomRight: Radius.circular(size.width * 0.02),
                  ),
                ),
                child: Text(
                  layer.secondaryText,
                  style: _ts(size.width * 0.045, FontWeight.w900, Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Flash Sale ───────────────────────────────────────────────────────────────

class _FlashSale extends StatelessWidget {
  const _FlashSale({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.06,
          vertical: size.height * 0.035,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [layer.bgColor, layer.accentColor],
          ),
          borderRadius: BorderRadius.circular(size.width * 0.03),
          boxShadow: [
            BoxShadow(
              color: layer.bgColor.withValues(alpha: 0.55),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              layer.primaryText,
              style: _ts(size.width * 0.08, FontWeight.w900, layer.textColor),
            ),
            if (layer.secondaryText.isNotEmpty) ...[
              SizedBox(height: size.height * 0.008),
              Text(
                layer.secondaryText,
                style: _ts(size.width * 0.05, FontWeight.w800, Colors.white),
              ),
            ],
            if (layer.tertiaryText.isNotEmpty)
              Text(
                layer.tertiaryText,
                style: _ts(size.width * 0.028, FontWeight.w600,
                    Colors.white.withValues(alpha: 0.85)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Countdown strip ───────────────────────────────────────────────────────────

class _CountdownStrip extends StatelessWidget {
  const _CountdownStrip({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, top: 0,
      child: Container(
        color: layer.bgColor.withValues(alpha: 0.94),
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.02,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.025,
                vertical: size.height * 0.008,
              ),
              decoration: BoxDecoration(
                color: layer.accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                layer.primaryText,
                style: _ts(size.width * 0.032, FontWeight.w900, Colors.white),
              ),
            ),
            SizedBox(width: size.width * 0.03),
            Expanded(
              child: Text(
                layer.secondaryText,
                style: _ts(size.width * 0.03, FontWeight.w700, layer.textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trust badge ───────────────────────────────────────────────────────────────

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final pad = size.width * 0.03;
    return Align(
      alignment: _toAlignment(layer.anchor),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.035,
            vertical: size.height * 0.014,
          ),
          decoration: BoxDecoration(
            color: layer.bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: layer.accentColor, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                layer.primaryText,
                style: _ts(size.width * 0.032, FontWeight.w800, layer.textColor),
              ),
              if (layer.secondaryText.isNotEmpty)
                Text(
                  layer.secondaryText,
                  style: _ts(size.width * 0.022, FontWeight.w500,
                      layer.textColor.withValues(alpha: 0.75)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delivery badge ────────────────────────────────────────────────────────────

class _DeliveryBadge extends StatelessWidget {
  const _DeliveryBadge({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _toAlignment(layer.anchor),
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.03),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.height * 0.012,
          ),
          decoration: BoxDecoration(
            color: layer.bgColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                layer.primaryText,
                style: _ts(size.width * 0.034, FontWeight.w800, layer.textColor),
              ),
              if (layer.secondaryText.isNotEmpty) ...[
                SizedBox(width: size.width * 0.02),
                Text(
                  '· ${layer.secondaryText}',
                  style: _ts(size.width * 0.024, FontWeight.w500,
                      layer.textColor.withValues(alpha: 0.85)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Limited stock ─────────────────────────────────────────────────────────────

class _LimitedStock extends StatelessWidget {
  const _LimitedStock({required this.layer, required this.size});
  final OverlayLayer layer;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final pad = size.width * 0.03;
    return Align(
      alignment: _toAlignment(layer.anchor),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.035,
            vertical: size.height * 0.012,
          ),
          decoration: BoxDecoration(
            color: layer.bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                layer.primaryText,
                style: _ts(size.width * 0.034, FontWeight.w900, layer.textColor),
              ),
              if (layer.secondaryText.isNotEmpty)
                Text(
                  layer.secondaryText,
                  style: _ts(size.width * 0.022, FontWeight.w600,
                      layer.textColor.withValues(alpha: 0.8)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

TextStyle _ts(double size, FontWeight weight, Color color) {
  try {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.2,
    );
  } catch (_) {
    return TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.2);
  }
}

Alignment _toAlignment(OverlayAnchor anchor) {
  switch (anchor) {
    case OverlayAnchor.topLeft:      return Alignment.topLeft;
    case OverlayAnchor.topRight:     return Alignment.topRight;
    case OverlayAnchor.topCenter:    return Alignment.topCenter;
    case OverlayAnchor.bottomLeft:   return Alignment.bottomLeft;
    case OverlayAnchor.bottomRight:  return Alignment.bottomRight;
    case OverlayAnchor.bottomCenter: return Alignment.bottomCenter;
    case OverlayAnchor.center:       return Alignment.center;
    case OverlayAnchor.fullTop:      return Alignment.topCenter;
    default:                         return Alignment.bottomLeft;
  }
}
