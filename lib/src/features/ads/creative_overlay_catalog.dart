import '../../core/db/app_database.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'studio_variable_context.dart';

// ---------------------------------------------------------------------------
// Creative Overlays — ready-made marketing overlays for the Studio canvas
// ---------------------------------------------------------------------------

enum OverlayCategory { sale, trust, brand, social }

class CreativeOverlay {
  const CreativeOverlay({
    required this.id,
    required this.label,
    required this.category,
    required this.emoji,
    this.isPremium = false,
    required this.build,
  });

  final String id;
  final String label;
  final OverlayCategory category;
  final String emoji;
  final bool isPremium;
  final List<CanvasElement> Function({
    required double canvasWidth,
    required double canvasHeight,
    required BrandKit kit,
    required StudioVariableContext? context,
    Item? product,
  }) build;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _ts() => DateTime.now().millisecondsSinceEpoch.toString();

String _overlayId(String overlayId, String suffix, String ts) =>
    '${overlayId}_${suffix}_$ts';

String _groupId(String overlayId, String ts) => '${overlayId}_group_$ts';

String _brandOr(String? brandHex, String fallback) {
  if (brandHex == null || brandHex.isEmpty || brandHex == '#000000') {
    return fallback;
  }
  return brandHex;
}

String _primary(BrandKit kit) => _brandOr(kit.primaryColor, '#0F1D40');
String _secondary(BrandKit kit) => _brandOr(kit.secondaryColor, '#0EBE7E');
String _accent(BrandKit kit) => _brandOr(kit.accentColor, '#fbbf24');
String _headingFont(BrandKit kit) =>
    kit.headingFont.isEmpty ? 'Montserrat' : kit.headingFont;
String _bodyFont(BrandKit kit) => kit.font.isEmpty ? 'Inter' : kit.font;

String _discountLabel(Item? product) {
  if (product == null) return '20% OFF';
  final discount = product.discount;
  final type = product.discountType;
  if (discount == null || discount <= 0) return '20% OFF';
  int percent;
  if (type == 'percent') {
    percent = discount.round();
  } else {
    final price = product.price;
    if (price <= 0) return '20% OFF';
    percent = ((discount / price) * 100).round();
  }
  if (percent <= 0) return '20% OFF';
  return '$percent% OFF';
}

CanvasElement _overlayFigure({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  required String fill,
  double? cornerRadius,
  double opacity = 1.0,
  String? groupId,
}) =>
    CanvasElement(
      id: id,
      type: 'figure',
      x: x,
      y: y,
      width: width,
      height: height,
      fill: fill,
      cornerRadius: cornerRadius,
      opacity: opacity,
      groupId: groupId,
    );

CanvasElement _overlayText({
  required String id,
  required double x,
  required double y,
  required double width,
  required String text,
  required String fill,
  required String fontFamily,
  double fontSize = 32,
  String? fontWeight,
  String align = 'center',
  String? groupId,
  double? letterSpacing,
  String? shadowColor,
  double shadowBlur = 6,
  double opacity = 1.0,
}) =>
    CanvasElement(
      id: id,
      type: 'text',
      text: text,
      x: x,
      y: y,
      width: width,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      fill: fill,
      align: align,
      groupId: groupId,
      letterSpacing: letterSpacing,
      shadowColor: shadowColor,
      shadowBlur: shadowBlur,
      opacity: opacity,
    );

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

List<CanvasElement> _buildSaleBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('sale_badge', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final size = canvasWidth * 0.28;
  return [
    _overlayFigure(
      id: _overlayId('sale_badge', 'bg', ts),
      x: canvasWidth - size - 16,
      y: 16,
      width: size,
      height: size,
      fill: accent,
      cornerRadius: size / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('sale_badge', 'txt', ts),
      x: canvasWidth - size - 16,
      y: 16 + size * 0.35,
      width: size,
      text: 'SALE',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: size * 0.28,
      fontWeight: '900',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildPercentOffBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('percent_off_badge', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final w = canvasWidth * 0.42;
  final h = canvasHeight * 0.16;
  return [
    _overlayFigure(
      id: _overlayId('percent_off', 'bg', ts),
      x: canvasWidth - w - 20,
      y: 24,
      width: w,
      height: h,
      fill: primary,
      cornerRadius: 16,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('percent_off', 'txt', ts),
      x: canvasWidth - w - 20,
      y: 24 + h * 0.22,
      width: w,
      text: _discountLabel(product),
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.45,
      fontWeight: '900',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildFlashBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('flash_badge', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final w = canvasWidth * 0.55;
  final h = canvasHeight * 0.10;
  return [
    _overlayFigure(
      id: _overlayId('flash_badge', 'bg', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight * 0.06,
      width: w,
      height: h,
      fill: accent,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('flash_badge', 'txt', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight * 0.06 + h * 0.18,
      width: w,
      text: '⚡ FLASH DEAL',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.42,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildHotBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('hot_badge', ts);
  final w = canvasWidth * 0.30;
  final h = canvasHeight * 0.08;
  return [
    _overlayFigure(
      id: _overlayId('hot_badge', 'bg', ts),
      x: canvasWidth - w - 18,
      y: 18,
      width: w,
      height: h,
      fill: '#e63946',
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('hot_badge', 'txt', ts),
      x: canvasWidth - w - 18,
      y: 18 + h * 0.18,
      width: w,
      text: '🔥 HOT',
      fill: '#ffffff',
      fontFamily: _headingFont(kit),
      fontSize: h * 0.42,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildNewBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('new_badge', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final size = canvasWidth * 0.22;
  return [
    _overlayFigure(
      id: _overlayId('new_badge', 'bg', ts),
      x: 20,
      y: 20,
      width: size,
      height: size,
      fill: secondary,
      cornerRadius: size / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('new_badge', 'txt', ts),
      x: 20,
      y: 20 + size * 0.32,
      width: size,
      text: 'NEW',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: size * 0.30,
      fontWeight: '900',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildLimitedStockBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('limited_stock_badge', ts);
  final w = canvasWidth * 0.70;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('limited_stock', 'bg', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight * 0.04,
      width: w,
      height: h,
      fill: '#000000',
      cornerRadius: h / 2,
      opacity: 0.85,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('limited_stock', 'txt', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight * 0.04 + h * 0.18,
      width: w,
      text: '⚠️ LIMITED STOCK',
      fill: '#ffffff',
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.38,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildPriceTag({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('price_tag', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final w = canvasWidth * 0.34;
  final h = canvasHeight * 0.10;
  return [
    _overlayFigure(
      id: _overlayId('price_tag', 'bg', ts),
      x: canvasWidth - w - 16,
      y: canvasHeight * 0.18,
      width: w,
      height: h,
      fill: accent,
      cornerRadius: 10,
      groupId: gid,
    ),
    _overlayFigure(
      id: _overlayId('price_tag', 'hole', ts),
      x: canvasWidth - 32,
      y: canvasHeight * 0.18 + h * 0.35,
      width: h * 0.30,
      height: h * 0.30,
      fill: textColor,
      cornerRadius: h * 0.15,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('price_tag', 'txt', ts),
      x: canvasWidth - w - 16,
      y: canvasHeight * 0.18 + h * 0.25,
      width: w - h * 0.30,
      text: '{{PRICE}}',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.36,
      fontWeight: '800',
      align: 'center',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildSaleBanner({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('sale_banner', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final h = canvasHeight * 0.09;
  return [
    _overlayFigure(
      id: _overlayId('sale_banner', 'bg', ts),
      x: 0,
      y: 0,
      width: canvasWidth,
      height: h,
      fill: primary,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('sale_banner', 'txt', ts),
      x: 0,
      y: h * 0.22,
      width: canvasWidth,
      text: '🏷️ MEGA SALE — UP TO 50% OFF',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.38,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildClearanceBanner({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('clearance_banner', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final h = canvasHeight * 0.08;
  return [
    _overlayFigure(
      id: _overlayId('clearance_banner', 'bg', ts),
      x: 0,
      y: canvasHeight - h,
      width: canvasWidth,
      height: h,
      fill: accent,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('clearance_banner', 'txt', ts),
      x: 0,
      y: canvasHeight - h + h * 0.22,
      width: canvasWidth,
      text: 'CLEARANCE — LAST FEW ITEMS',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.38,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Trust
// ---------------------------------------------------------------------------

List<CanvasElement> _buildVerifiedBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('verified_badge', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final w = canvasWidth * 0.45;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('verified_badge', 'bg', ts),
      x: 18,
      y: canvasHeight * 0.12,
      width: w,
      height: h,
      fill: secondary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('verified_badge', 'txt', ts),
      x: 18,
      y: canvasHeight * 0.12 + h * 0.20,
      width: w,
      text: '✓ VERIFIED SELLER',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.34,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildFreeDeliveryBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('free_delivery_badge', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final w = canvasWidth * 0.48;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('free_delivery', 'bg', ts),
      x: 18,
      y: canvasHeight - h - 18,
      width: w,
      height: h,
      fill: primary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('free_delivery', 'txt', ts),
      x: 18,
      y: canvasHeight - h - 18 + h * 0.20,
      width: w,
      text: '🚚 FREE DELIVERY',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildPaymentMethodsStrip({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('payment_methods_strip', ts);
  final h = canvasHeight * 0.06;
  return [
    _overlayFigure(
      id: _overlayId('payment_strip', 'bg', ts),
      x: 0,
      y: canvasHeight - h,
      width: canvasWidth,
      height: h,
      fill: '#ffffff',
      opacity: 0.92,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('payment_strip', 'txt', ts),
      x: 0,
      y: canvasHeight - h + h * 0.22,
      width: canvasWidth,
      text: '💳 Cash · Mobile Money · Bank Transfer',
      fill: '#1f2937',
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '600',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildAppDownloadBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('app_download_badge', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final w = canvasWidth * 0.60;
  final h = canvasHeight * 0.08;
  return [
    _overlayFigure(
      id: _overlayId('app_download', 'bg', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight - h - 20,
      width: w,
      height: h,
      fill: accent,
      cornerRadius: 14,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('app_download', 'txt', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight - h - 20 + h * 0.22,
      width: w,
      text: '📲 Shop on Soko24 App',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.36,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildTrustBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('trust_badge', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final size = canvasWidth * 0.26;
  return [
    _overlayFigure(
      id: _overlayId('trust_badge', 'bg', ts),
      x: canvasWidth - size - 20,
      y: canvasHeight * 0.30,
      width: size,
      height: size,
      fill: secondary,
      cornerRadius: size / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('trust_badge', 'txt', ts),
      x: canvasWidth - size - 20,
      y: canvasHeight * 0.30 + size * 0.35,
      width: size,
      text: 'TRUSTED',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: size * 0.22,
      fontWeight: '800',
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('trust_badge', 'sub', ts),
      x: canvasWidth - size - 20,
      y: canvasHeight * 0.30 + size * 0.58,
      width: size,
      text: '★★★★★',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: size * 0.16,
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildMoneyBackBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('money_back_badge', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final w = canvasWidth * 0.52;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('money_back', 'bg', ts),
      x: 18,
      y: canvasHeight * 0.22,
      width: w,
      height: h,
      fill: primary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('money_back', 'txt', ts),
      x: 18,
      y: canvasHeight * 0.22 + h * 0.20,
      width: w,
      text: '↩️ 7-DAY MONEY BACK',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Brand / contact
// ---------------------------------------------------------------------------

List<CanvasElement> _buildNowOpenBanner({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('now_open_banner', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final h = canvasHeight * 0.14;
  final biz = kit.businessName.isEmpty ? 'YOUR BUSINESS' : kit.businessName;
  final phone = kit.phone.isEmpty ? '{{PHONE}}' : kit.phone;
  return [
    _overlayFigure(
      id: _overlayId('now_open', 'bg', ts),
      x: 0,
      y: canvasHeight - h,
      width: canvasWidth,
      height: h,
      fill: accent,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('now_open', 'head', ts),
      x: 0,
      y: canvasHeight - h + h * 0.16,
      width: canvasWidth,
      text: '✨ NOW OPEN ✨',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.30,
      fontWeight: '900',
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('now_open', 'biz', ts),
      x: 0,
      y: canvasHeight - h + h * 0.50,
      width: canvasWidth,
      text: biz,
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.22,
      fontWeight: '600',
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('now_open', 'phone', ts),
      x: 0,
      y: canvasHeight - h + h * 0.75,
      width: canvasWidth,
      text: '📞 $phone',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.18,
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildBusinessHoursStrip({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('business_hours_strip', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final h = canvasHeight * 0.08;
  final biz = kit.businessName.isEmpty ? '{{BUSINESS}}' : kit.businessName;
  return [
    _overlayFigure(
      id: _overlayId('business_hours', 'bg', ts),
      x: 0,
      y: 0,
      width: canvasWidth,
      height: h,
      fill: primary,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('business_hours', 'txt', ts),
      x: 0,
      y: h * 0.24,
      width: canvasWidth,
      text: '$biz · Mon–Sat 8am–7pm',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '600',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildContactCard({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('contact_card', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final w = canvasWidth * 0.72;
  final h = canvasHeight * 0.18;
  return [
    _overlayFigure(
      id: _overlayId('contact_card', 'bg', ts),
      x: 20,
      y: canvasHeight - h - 20,
      width: w,
      height: h,
      fill: secondary,
      cornerRadius: 18,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('contact_card', 'head', ts),
      x: 20,
      y: canvasHeight - h - 20 + h * 0.14,
      width: w,
      text: 'CONTACT US',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.22,
      fontWeight: '800',
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('contact_card', 'wa', ts),
      x: 20,
      y: canvasHeight - h - 20 + h * 0.45,
      width: w,
      text: '💬 WhatsApp: {{WHATSAPP}}',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.15,
      fontWeight: '600',
      align: 'left',
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('contact_card', 'phone', ts),
      x: 20 + w * 0.08,
      y: canvasHeight - h - 20 + h * 0.68,
      width: w * 0.84,
      text: '📞 {{PHONE}}',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.15,
      fontWeight: '600',
      align: 'left',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildSocialHandleStrip({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('social_handle_strip', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final h = canvasHeight * 0.07;
  final handle = kit.website.isEmpty ? '@soko24' : kit.website;
  return [
    _overlayFigure(
      id: _overlayId('social_handle', 'bg', ts),
      x: 0,
      y: canvasHeight - h,
      width: canvasWidth,
      height: h,
      fill: accent,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('social_handle', 'txt', ts),
      x: 0,
      y: canvasHeight - h + h * 0.22,
      width: canvasWidth,
      text: '📲 Follow us: $handle',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.34,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildLocationBadge({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('location_badge', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final w = canvasWidth * 0.62;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('location_badge', 'bg', ts),
      x: 18,
      y: canvasHeight - h - 18,
      width: w,
      height: h,
      fill: primary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('location_badge', 'txt', ts),
      x: 18,
      y: canvasHeight - h - 18 + h * 0.20,
      width: w,
      text: '📍 {{LOCATION}}',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '600',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildQrFrame({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('qr_frame', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final size = canvasWidth * 0.26;
  return [
    _overlayFigure(
      id: _overlayId('qr_frame', 'bg', ts),
      x: canvasWidth - size - 20,
      y: canvasHeight - size - 20,
      width: size,
      height: size,
      fill: '#ffffff',
      cornerRadius: 16,
      groupId: gid,
    ),
    _overlayFigure(
      id: _overlayId('qr_frame', 'inner', ts),
      x: canvasWidth - size - 20 + size * 0.12,
      y: canvasHeight - size - 20 + size * 0.12,
      width: size * 0.76,
      height: size * 0.76,
      fill: secondary,
      cornerRadius: 8,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('qr_frame', 'txt', ts),
      x: canvasWidth - size - 20,
      y: canvasHeight - size - 20 + size * 0.42,
      width: size,
      text: 'QR',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: size * 0.22,
      fontWeight: '900',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildWebsiteStrip({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('website_strip', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final h = canvasHeight * 0.06;
  return [
    _overlayFigure(
      id: _overlayId('website_strip', 'bg', ts),
      x: 0,
      y: 0,
      width: canvasWidth,
      height: h,
      fill: primary,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('website_strip', 'txt', ts),
      x: 0,
      y: h * 0.22,
      width: canvasWidth,
      text: '🌐 {{CTA_LINK}}',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.34,
      fontWeight: '600',
      groupId: gid,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Social proof
// ---------------------------------------------------------------------------

List<CanvasElement> _buildReviewCard({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('review_card', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final w = canvasWidth * 0.78;
  final h = canvasHeight * 0.18;
  return [
    _overlayFigure(
      id: _overlayId('review_card', 'bg', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight - h - 24,
      width: w,
      height: h,
      fill: primary,
      cornerRadius: 20,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('review_card', 'stars', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight - h - 24 + h * 0.12,
      width: w,
      text: '★★★★★',
      fill: '#fbbf24',
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.18,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('review_card', 'quote', ts),
      x: (canvasWidth - w) / 2 + w * 0.06,
      y: canvasHeight - h - 24 + h * 0.38,
      width: w * 0.88,
      text: '"Amazing quality and fast delivery!"',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.15,
      fontWeight: '600',
      align: 'left',
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('review_card', 'name', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight - h - 24 + h * 0.70,
      width: w,
      text: '— Happy Customer',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.13,
      opacity: 0.85,
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildTestimonialQuote({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('testimonial_quote', ts);
  final accent = _accent(kit);
  final textColor = contrastText(accent);
  final w = canvasWidth * 0.84;
  final h = canvasHeight * 0.22;
  return [
    _overlayFigure(
      id: _overlayId('testimonial_quote', 'bg', ts),
      x: (canvasWidth - w) / 2,
      y: canvasHeight * 0.08,
      width: w,
      height: h,
      fill: accent,
      cornerRadius: 24,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('testimonial_quote', 'quote', ts),
      x: (canvasWidth - w) / 2 + w * 0.08,
      y: canvasHeight * 0.08 + h * 0.22,
      width: w * 0.84,
      text: '"This store never disappoints. Highly recommend!"',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.16,
      fontWeight: '700',
      align: 'left',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildRatingStars({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('rating_stars', ts);
  final w = canvasWidth * 0.46;
  final h = canvasHeight * 0.08;
  return [
    _overlayFigure(
      id: _overlayId('rating_stars', 'bg', ts),
      x: canvasWidth - w - 18,
      y: canvasHeight - h - 18,
      width: w,
      height: h,
      fill: '#ffffff',
      cornerRadius: h / 2,
      opacity: 0.95,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('rating_stars', 'txt', ts),
      x: canvasWidth - w - 18,
      y: canvasHeight - h - 18 + h * 0.16,
      width: w,
      text: '★★★★★ 4.9',
      fill: '#f59e0b',
      fontFamily: _headingFont(kit),
      fontSize: h * 0.40,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildBeforeAfterLabel({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('before_after_label', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final w = canvasWidth * 0.30;
  final h = canvasHeight * 0.08;
  return [
    _overlayFigure(
      id: _overlayId('before_after', 'bg', ts),
      x: 18,
      y: canvasHeight * 0.45,
      width: w,
      height: h,
      fill: secondary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('before_after', 'txt', ts),
      x: 18,
      y: canvasHeight * 0.45 + h * 0.20,
      width: w,
      text: 'BEFORE → AFTER',
      fill: textColor,
      fontFamily: _headingFont(kit),
      fontSize: h * 0.34,
      fontWeight: '800',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildFollowerCount({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('follower_count', ts);
  final primary = _primary(kit);
  final textColor = contrastText(primary);
  final w = canvasWidth * 0.48;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('follower_count', 'bg', ts),
      x: canvasWidth - w - 18,
      y: canvasHeight * 0.12,
      width: w,
      height: h,
      fill: primary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('follower_count', 'txt', ts),
      x: canvasWidth - w - 18,
      y: canvasHeight * 0.12 + h * 0.20,
      width: w,
      text: '❤️ 10K+ Happy Buyers',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

List<CanvasElement> _buildVerifiedReview({
  required double canvasWidth,
  required double canvasHeight,
  required BrandKit kit,
  required StudioVariableContext? context,
  Item? product,
}) {
  final ts = _ts();
  final gid = _groupId('verified_review', ts);
  final secondary = _secondary(kit);
  final textColor = contrastText(secondary);
  final w = canvasWidth * 0.56;
  final h = canvasHeight * 0.07;
  return [
    _overlayFigure(
      id: _overlayId('verified_review', 'bg', ts),
      x: 18,
      y: canvasHeight * 0.04,
      width: w,
      height: h,
      fill: secondary,
      cornerRadius: h / 2,
      groupId: gid,
    ),
    _overlayText(
      id: _overlayId('verified_review', 'txt', ts),
      x: 18,
      y: canvasHeight * 0.04 + h * 0.20,
      width: w,
      text: '✓ Verified 5-Star Review',
      fill: textColor,
      fontFamily: _bodyFont(kit),
      fontSize: h * 0.32,
      fontWeight: '700',
      groupId: gid,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Public catalog
// ---------------------------------------------------------------------------

final creativeOverlayCatalog = <CreativeOverlay>[
  // Sale
  CreativeOverlay(
    id: 'sale_badge',
    label: 'Sale Badge',
    category: OverlayCategory.sale,
    emoji: '🏷️',
    build: _buildSaleBadge,
  ),
  CreativeOverlay(
    id: 'percent_off_badge',
    label: '% OFF',
    category: OverlayCategory.sale,
    emoji: '%',
    build: _buildPercentOffBadge,
  ),
  CreativeOverlay(
    id: 'flash_badge',
    label: 'Flash Deal',
    category: OverlayCategory.sale,
    emoji: '⚡',
    build: _buildFlashBadge,
  ),
  CreativeOverlay(
    id: 'hot_badge',
    label: 'Hot Badge',
    category: OverlayCategory.sale,
    emoji: '🔥',
    build: _buildHotBadge,
  ),
  CreativeOverlay(
    id: 'new_badge',
    label: 'New Badge',
    category: OverlayCategory.sale,
    emoji: '✨',
    build: _buildNewBadge,
  ),
  CreativeOverlay(
    id: 'limited_stock_badge',
    label: 'Limited Stock',
    category: OverlayCategory.sale,
    emoji: '⚠️',
    build: _buildLimitedStockBadge,
  ),
  CreativeOverlay(
    id: 'price_tag',
    label: 'Price Tag',
    category: OverlayCategory.sale,
    emoji: '🏷️',
    build: _buildPriceTag,
  ),
  CreativeOverlay(
    id: 'sale_banner',
    label: 'Sale Banner',
    category: OverlayCategory.sale,
    emoji: '📢',
    build: _buildSaleBanner,
  ),
  CreativeOverlay(
    id: 'clearance_banner',
    label: 'Clearance',
    category: OverlayCategory.sale,
    emoji: '🏷️',
    isPremium: true,
    build: _buildClearanceBanner,
  ),
  // Trust
  CreativeOverlay(
    id: 'verified_badge',
    label: 'Verified Seller',
    category: OverlayCategory.trust,
    emoji: '✅',
    build: _buildVerifiedBadge,
  ),
  CreativeOverlay(
    id: 'free_delivery_badge',
    label: 'Free Delivery',
    category: OverlayCategory.trust,
    emoji: '🚚',
    build: _buildFreeDeliveryBadge,
  ),
  CreativeOverlay(
    id: 'payment_methods_strip',
    label: 'Payment Strip',
    category: OverlayCategory.trust,
    emoji: '💳',
    build: _buildPaymentMethodsStrip,
  ),
  CreativeOverlay(
    id: 'app_download_badge',
    label: 'App Download',
    category: OverlayCategory.trust,
    emoji: '📲',
    build: _buildAppDownloadBadge,
  ),
  CreativeOverlay(
    id: 'trust_badge',
    label: 'Trust Badge',
    category: OverlayCategory.trust,
    emoji: '🛡️',
    build: _buildTrustBadge,
  ),
  CreativeOverlay(
    id: 'money_back_badge',
    label: 'Money Back',
    category: OverlayCategory.trust,
    emoji: '↩️',
    isPremium: true,
    build: _buildMoneyBackBadge,
  ),
  // Brand / contact
  CreativeOverlay(
    id: 'now_open_banner',
    label: 'Now Open',
    category: OverlayCategory.brand,
    emoji: '🎉',
    build: _buildNowOpenBanner,
  ),
  CreativeOverlay(
    id: 'business_hours_strip',
    label: 'Business Hours',
    category: OverlayCategory.brand,
    emoji: '🕒',
    build: _buildBusinessHoursStrip,
  ),
  CreativeOverlay(
    id: 'contact_card',
    label: 'Contact Card',
    category: OverlayCategory.brand,
    emoji: '📇',
    build: _buildContactCard,
  ),
  CreativeOverlay(
    id: 'social_handle_strip',
    label: 'Social Handle',
    category: OverlayCategory.brand,
    emoji: '@',
    build: _buildSocialHandleStrip,
  ),
  CreativeOverlay(
    id: 'location_badge',
    label: 'Location',
    category: OverlayCategory.brand,
    emoji: '📍',
    build: _buildLocationBadge,
  ),
  CreativeOverlay(
    id: 'qr_frame',
    label: 'QR Frame',
    category: OverlayCategory.brand,
    emoji: '🔲',
    build: _buildQrFrame,
  ),
  CreativeOverlay(
    id: 'website_strip',
    label: 'Website Strip',
    category: OverlayCategory.brand,
    emoji: '🌐',
    isPremium: true,
    build: _buildWebsiteStrip,
  ),
  // Social proof
  CreativeOverlay(
    id: 'review_card',
    label: 'Review Card',
    category: OverlayCategory.social,
    emoji: '💬',
    build: _buildReviewCard,
  ),
  CreativeOverlay(
    id: 'testimonial_quote',
    label: 'Testimonial',
    category: OverlayCategory.social,
    emoji: '"',
    build: _buildTestimonialQuote,
  ),
  CreativeOverlay(
    id: 'rating_stars',
    label: 'Rating Stars',
    category: OverlayCategory.social,
    emoji: '⭐',
    build: _buildRatingStars,
  ),
  CreativeOverlay(
    id: 'before_after_label',
    label: 'Before/After',
    category: OverlayCategory.social,
    emoji: '↔️',
    build: _buildBeforeAfterLabel,
  ),
  CreativeOverlay(
    id: 'follower_count',
    label: 'Follower Count',
    category: OverlayCategory.social,
    emoji: '❤️',
    build: _buildFollowerCount,
  ),
  CreativeOverlay(
    id: 'verified_review',
    label: 'Verified Review',
    category: OverlayCategory.social,
    emoji: '✓',
    isPremium: true,
    build: _buildVerifiedReview,
  ),
];
