import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ad_templates_generated.dart';

// Sentinel for optional nullable copyWith params
const _kKeep = Object();

/// Represents an ad canvas size preset
class AdSize {
  const AdSize(this.label, this.icon, this.width, this.height);
  final String label;
  final IconData icon;
  final double width;
  final double height;
  double get aspectRatio => width / height;
}

const adSizes = [
  AdSize('Instagram Post', Icons.crop_square, 1080, 1080),
  AdSize('Instagram Story', Icons.smartphone, 1080, 1920),
  AdSize('TikTok / Reels', Icons.play_circle_outline, 1080, 1920),
  AdSize('Facebook Post', Icons.facebook, 1200, 630),
  AdSize('Facebook Cover', Icons.panorama, 1640, 924),
  AdSize('YouTube Thumb', Icons.play_arrow, 1280, 720),
  AdSize('LinkedIn Post', Icons.business, 1200, 627),
  AdSize('Pinterest Pin', Icons.push_pin_outlined, 1000, 1500),
  AdSize('WhatsApp Status', Icons.chat, 1080, 1920),
  AdSize('X / Twitter', Icons.alternate_email, 1600, 900),
  AdSize('Portrait (4:5)', Icons.crop_portrait, 1080, 1350),
  AdSize('Square (1:1)', Icons.crop_square, 1080, 1080),
  AdSize('Banner (16:9)', Icons.panorama, 1920, 1080),
  AdSize('A4 Flyer', Icons.description_outlined, 2480, 3508),
];

/// Returns the first [AdSize] preset whose dimensions match [width]×[height],
/// or `null` if none match.
AdSize? findAdSizeFor(double width, double height) {
  final w = width.round();
  final h = height.round();
  for (final size in adSizes) {
    if (size.width.round() == w && size.height.round() == h) return size;
  }
  return null;
}

/// Returns a copy of [template] resized to [size] with every element scaled
/// uniformly so the design fits the new canvas. Text font sizes are clamped
/// to a minimum of 14 after scaling.
AdTemplate scaleTemplateToSize(AdTemplate template, AdSize size) {
  final oldW = template.canvasWidth;
  final oldH = template.canvasHeight;
  if (oldW <= 0 || oldH <= 0) {
    return AdTemplate(
      id: template.id,
      name: template.name,
      category: template.category,
      canvasWidth: size.width,
      canvasHeight: size.height,
      background: template.background,
      elements: template.elements,
      previewColors: template.previewColors,
      tags: template.tags,
      industry: template.industry,
      season: template.season,
      complexity: template.complexity,
      suggestedCaption: template.suggestedCaption,
      marketingGoal: template.marketingGoal,
    );
  }

  final scale = math.min(size.width / oldW, size.height / oldH);
  final scaledElements = template.elements.map((el) {
    final newX = el.x * scale;
    final newY = el.y * scale;
    final newW = el.width * scale;
    final newH = el.height * scale;
    final newFontSize = el.fontSize != null
        ? (el.fontSize! * scale).clamp(14.0, double.infinity)
        : null;
    return el.copyWith(
      x: newX,
      y: newY,
      width: newW,
      height: newH,
      fontSize: newFontSize,
    );
  }).toList();

  return AdTemplate(
    id: template.id,
    name: template.name,
    category: template.category,
    canvasWidth: size.width,
    canvasHeight: size.height,
    background: template.background,
    elements: scaledElements,
    previewColors: template.previewColors,
    tags: template.tags,
    industry: template.industry,
    season: template.season,
    complexity: template.complexity,
    suggestedCaption: template.suggestedCaption,
    marketingGoal: template.marketingGoal,
  );
}

/// Blank canvas for "Create from scratch" flows.
AdTemplate blankCanvas(AdSize size, {String? name}) => AdTemplate(
      id: 'blank_${size.width.toInt()}x${size.height.toInt()}_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Untitled Design',
      category: 'blank',
      canvasWidth: size.width,
      canvasHeight: size.height,
      background: '#ffffff',
      elements: const [],
      previewColors: const [Color(0xFFFFFFFF), Color(0xFF77ABFF)],
    );

/// Brand palette colors for quick-pick in editors (hex strings).
List<Color> brandPaletteColors({
  required String primary,
  required String secondary,
  required String accent,
}) =>
    [
      parseHexColor(primary),
      parseHexColor(secondary),
      parseHexColor(accent),
    ];

/// Returns black or white hex text color that contrasts with [bgHex].
String contrastText(String bgHex) {
  final rgb = hexToRgb(bgHex);
  if (rgb == null) return '#000000';
  final luminance = (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255;
  return luminance > 0.5 ? '#000000' : '#FFFFFF';
}

({int r, int g, int b})? hexToRgb(String hex) {
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6) return null;
  try {
    return (
      r: int.parse(h.substring(0, 2), radix: 16),
      g: int.parse(h.substring(2, 4), radix: 16),
      b: int.parse(h.substring(4, 6), radix: 16),
    );
  } catch (_) {
    return null;
  }
}

/// A recipe used by the programmatic template generator.
class LayoutRecipe {
  const LayoutRecipe(this.id, this.name, this.builder);
  final String id;
  final String name;
  final List<CanvasElement> Function({
    required double w,
    required double h,
    required dynamic palette,
    required String headline,
    required String category,
    required int variant,
  }) builder;
}

/// A single element on the canvas
class CanvasElement {
  const CanvasElement({
    required this.id,
    required this.type,
    this.text,
    this.src,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.fill,
    this.align,
    this.cornerRadius,
    this.opacity = 1.0,
    this.textDecoration,
    this.placeholder,
    this.rotation = 0.0,
    this.zIndex = 0,
    this.isLocked = false,
    this.letterSpacing,
    this.lineHeight,
    this.shadowColor,
    this.shadowDx = 2.0,
    this.shadowDy = 2.0,
    this.shadowBlur = 4.0,
    this.strokeColor,
    this.strokeWidth,
    this.groupId,
    this.flipX = false,
    this.flipY = false,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.assetId,
    this.isPremium = false,
    this.isVisible = true,
    this.fontStyle,
    this.textTransform,
    this.imageFit,
    this.imageFilter,
  });

  final String id;
  final String type; // text, image, figure, icon, sticker, illustration
  final String? text;
  final String? src;
  final double x, y, width, height;
  final double? fontSize;
  final String? fontWeight;
  final String? fontFamily;
  final String? fill;
  final String? align;
  final double? cornerRadius;
  final double opacity;
  final String? textDecoration;
  final String? placeholder;
  final double rotation;       // radians; 0 = no rotation
  final int zIndex;
  final bool isLocked;
  final double? letterSpacing;
  final double? lineHeight;
  final String? shadowColor;   // hex color; null = no shadow
  final double shadowDx;
  final double shadowDy;
  final double shadowBlur;
  final String? strokeColor;   // hex; null = no stroke
  final double? strokeWidth;
  final String? groupId;
  final bool flipX;
  final bool flipY;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final String? assetId;
  final bool isPremium;
  final bool isVisible;
  final String? fontStyle;
  final String? textTransform;
  final String? imageFit;
  final String? imageFilter;

  bool get hasShadow => shadowColor != null;
  bool get hasStroke => strokeColor != null && (strokeWidth ?? 0) > 0;

  CanvasElement copyWith({
    String? text,
    String? src,
    double? x,
    double? y,
    double? width,
    double? height,
    String? fill,
    double? fontSize,
    String? fontWeight,
    String? fontFamily,
    String? align,
    double? cornerRadius,
    double? opacity,
    double? rotation,
    int? zIndex,
    bool? isLocked,
    double? letterSpacing,
    double? lineHeight,
    Object? shadowColor = _kKeep,
    double? shadowDx,
    double? shadowDy,
    double? shadowBlur,
    Object? strokeColor = _kKeep,
    double? strokeWidth,
    Object? groupId = _kKeep,
    bool? flipX,
    bool? flipY,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    String? assetId,
    bool? isPremium,
    bool? isVisible,
    String? fontStyle,
    String? textTransform,
    String? imageFit,
    String? imageFilter,
  }) {
    return CanvasElement(
      id: id,
      type: type,
      text: text ?? this.text,
      src: src ?? this.src,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      fill: fill ?? this.fill,
      align: align ?? this.align,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      opacity: opacity ?? this.opacity,
      textDecoration: textDecoration,
      placeholder: placeholder,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      shadowColor: shadowColor == _kKeep ? this.shadowColor : shadowColor as String?,
      shadowDx: shadowDx ?? this.shadowDx,
      shadowDy: shadowDy ?? this.shadowDy,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      strokeColor: strokeColor == _kKeep ? this.strokeColor : strokeColor as String?,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      groupId: groupId == _kKeep ? this.groupId : groupId as String?,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      assetId: assetId ?? this.assetId,
      isPremium: isPremium ?? this.isPremium,
      isVisible: isVisible ?? this.isVisible,
      fontStyle: fontStyle ?? this.fontStyle,
      textTransform: textTransform ?? this.textTransform,
      imageFit: imageFit ?? this.imageFit,
      imageFilter: imageFilter ?? this.imageFilter,
    );
  }

  factory CanvasElement.fromJson(Map<String, dynamic> j) {
    return CanvasElement(
      id: j['id']?.toString() ?? '',
      type: j['type']?.toString() ?? 'text',
      text: j['text']?.toString(),
      src: j['src']?.toString(),
      x: (j['x'] as num?)?.toDouble() ?? 0,
      y: (j['y'] as num?)?.toDouble() ?? 0,
      width: (j['width'] as num?)?.toDouble() ?? 0,
      height: (j['height'] as num?)?.toDouble() ?? 0,
      fontSize: (j['fontSize'] as num?)?.toDouble(),
      fontWeight: j['fontWeight']?.toString(),
      fontFamily: j['fontFamily']?.toString(),
      fill: j['fill']?.toString(),
      align: j['align']?.toString(),
      cornerRadius: (j['cornerRadius'] as num?)?.toDouble(),
      opacity: (j['opacity'] as num?)?.toDouble() ?? 1.0,
      textDecoration: j['textDecoration']?.toString(),
      placeholder: j['placeholder']?.toString(),
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0.0,
      zIndex: (j['zIndex'] as num?)?.toInt() ?? 0,
      isLocked: j['isLocked'] as bool? ?? false,
      letterSpacing: (j['letterSpacing'] as num?)?.toDouble(),
      lineHeight: (j['lineHeight'] as num?)?.toDouble(),
      shadowColor: j['shadowColor']?.toString(),
      shadowDx: (j['shadowDx'] as num?)?.toDouble() ?? 2.0,
      shadowDy: (j['shadowDy'] as num?)?.toDouble() ?? 2.0,
      shadowBlur: (j['shadowBlur'] as num?)?.toDouble() ?? 4.0,
      strokeColor: j['strokeColor']?.toString(),
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble(),
      groupId: j['groupId']?.toString(),
      flipX: j['flipX'] as bool? ?? false,
      flipY: j['flipY'] as bool? ?? false,
      iconCodePoint: (j['iconCodePoint'] as num?)?.toInt(),
      iconFontFamily: j['iconFontFamily']?.toString(),
      iconFontPackage: j['iconFontPackage']?.toString(),
      assetId: j['assetId']?.toString(),
      isPremium: j['isPremium'] as bool? ?? false,
      isVisible: j['isVisible'] as bool? ?? true,
      fontStyle: j['fontStyle']?.toString(),
      textTransform: j['textTransform']?.toString(),
      imageFit: j['imageFit']?.toString(),
      imageFilter: j['imageFilter']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type,
    if (text != null) 'text': text,
    if (src != null) 'src': src,
    'x': x, 'y': y, 'width': width, 'height': height,
    if (fontSize != null) 'fontSize': fontSize,
    if (fontWeight != null) 'fontWeight': fontWeight,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (fill != null) 'fill': fill,
    if (align != null) 'align': align,
    if (cornerRadius != null) 'cornerRadius': cornerRadius,
    if (opacity != 1.0) 'opacity': opacity,
    if (textDecoration != null) 'textDecoration': textDecoration,
    if (placeholder != null) 'placeholder': placeholder,
    if (rotation != 0.0) 'rotation': rotation,
    if (zIndex != 0) 'zIndex': zIndex,
    if (isLocked) 'isLocked': isLocked,
    if (letterSpacing != null) 'letterSpacing': letterSpacing,
    if (lineHeight != null) 'lineHeight': lineHeight,
    if (shadowColor != null) 'shadowColor': shadowColor,
    if (hasShadow) ...{'shadowDx': shadowDx, 'shadowDy': shadowDy, 'shadowBlur': shadowBlur},
    if (strokeColor != null) 'strokeColor': strokeColor,
    if (strokeWidth != null) 'strokeWidth': strokeWidth,
    if (groupId != null) 'groupId': groupId,
    if (flipX) 'flipX': flipX,
    if (flipY) 'flipY': flipY,
    if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
    if (iconFontFamily != null) 'iconFontFamily': iconFontFamily,
    if (iconFontPackage != null) 'iconFontPackage': iconFontPackage,
    if (assetId != null) 'assetId': assetId,
    if (isPremium) 'isPremium': isPremium,
    if (!isVisible) 'isVisible': isVisible,
    if (fontStyle != null) 'fontStyle': fontStyle,
    if (textTransform != null) 'textTransform': textTransform,
    if (imageFit != null) 'imageFit': imageFit,
    if (imageFilter != null) 'imageFilter': imageFilter,
  };
}

/// Full canvas template definition
class AdTemplate {
  const AdTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.background,
    required this.elements,
    this.previewColors,
    this.tags = const [],
    this.industry = '',
    this.season = '',
    this.complexity = 'starter',
    this.suggestedCaption = '',
    this.marketingGoal = 'awareness',
  });

  final String id;
  final String name;
  final String category;
  final double canvasWidth;
  final double canvasHeight;
  final String background;
  final List<CanvasElement> elements;
  final List<Color>? previewColors;
  final List<String> tags;
  final String industry;
  final String season;
  final String complexity;
  final String suggestedCaption;
  final String marketingGoal;

  double get aspectRatio => canvasWidth / canvasHeight;

  /// Return a new template with product data and brand CTA variables filled in.
  ///
  /// Placeholders in element text that are automatically substituted:
  ///   {{WHATSAPP}}   → whatsappNumber (e.g. "0700 123 456")
  ///   {{PHONE}}      → phoneNumber
  ///   {{CTA_LINK}}   → shopUrl or soko24.co/product/...
  ///   {{BUSINESS}}   → businessName
  ///   {{LOCATION}}   → location
  ///
  /// Plus legacy plain-text replacements for product name, price, etc.
  AdTemplate applyProduct({
    required String productName,
    required String priceFormatted,
    String? imageUrl,
    String? shopUrl,
    String? category,
    // Brand kit CTA variables — all optional
    String? whatsappNumber,
    String? phoneNumber,
    String? businessName,
    String? location,
    String? tagline,
  }) {
    final waNum   = whatsappNumber?.isNotEmpty == true ? whatsappNumber! : '0700 000 000';
    final phone   = phoneNumber?.isNotEmpty == true ? phoneNumber! : waNum;
    final biz     = businessName?.isNotEmpty == true ? businessName! : 'Soko 24';
    final loc     = location?.isNotEmpty == true ? location! : 'Kampala, Uganda';
    final ctaLink = shopUrl?.isNotEmpty == true ? shopUrl! : 'soko24.co';
    final tag     = tagline?.isNotEmpty == true ? tagline! : '';
    final price   = priceFormatted;
    final pname   = productName;

    String applyCommon(String? raw) {
      if (raw == null) return '';
      var t = raw
          .replaceAll('{{WHATSAPP}}',  waNum)
          .replaceAll('{{PHONE}}',     phone)
          .replaceAll('{{CTA_LINK}}',  ctaLink)
          .replaceAll('{{BUSINESS}}',  biz)
          .replaceAll('{{LOCATION}}',  loc)
          .replaceAll('{{TAGLINE}}',   tag)
          .replaceAll('{{PRODUCT}}',   pname.isNotEmpty ? pname : 'Product Name')
          .replaceAll('{{PRICE}}',     price.isNotEmpty ? price : 'UGX 0')
          // Shorthand variants
          .replaceAll('WA: {{WA}}',    'WA: $waNum')
          .replaceAll('📞 {{PHONE}}',  '📞 $phone')
          .replaceAll('💬 {{WA}}',     '💬 $waNum');

      if (productName.isNotEmpty) {
        t = t
            .replaceAll('PRODUCT NAME',      productName)
            .replaceAll('PRODUCT\nNAME',     productName)
            .replaceAll('Product Name',      productName)
            .replaceAll('Product Name Here', productName)
            .replaceAll('YOUR PRODUCT HERE', productName)
            .replaceAll('ADD YOUR PRODUCT',  productName)
            .replaceAll('PRODUCT IMAGE',     productName)
            .replaceAll('YOUR PRODUCT',      productName);
      }

      if (priceFormatted.isNotEmpty) {
        t = t
            .replaceAll('UGX 150,000', priceFormatted)
            .replaceAll('UGX 99,000',  priceFormatted)
            .replaceAll('UGX 120,000', priceFormatted)
            .replaceAll('UGX 75,000',  priceFormatted)
            .replaceAll('UGX 49,000',  priceFormatted)
            .replaceAll('UGX 25,000',  priceFormatted)
            .replaceAll('UGX 200,000', priceFormatted);
      }

      if (category != null) {
        t = t.replaceAll('FEATURED', category.toUpperCase());
      }

      if (biz != 'Soko 24') {
        t = t
            .replaceAll('YOUR BUSINESS', biz)
            .replaceAll('Your Business', biz);
      }
      return t;
    }

    final newElements = elements.map((el) {
      final t = applyCommon(el.text ?? el.placeholder);
      var src = el.src;
      if (el.type == 'image' && imageUrl != null && imageUrl.isNotEmpty) {
        src = imageUrl;
      }
      return el.copyWith(text: t.isEmpty ? null : t, src: src);
    }).toList();

    return AdTemplate(
      id: id,
      name: name,
      category: this.category,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      background: background,
      elements: newElements,
      previewColors: previewColors,
      tags: tags,
      industry: industry,
      season: season,
      complexity: complexity,
      suggestedCaption: applyCommon(suggestedCaption),
      marketingGoal: marketingGoal,
    );
  }

  /// Apply service details to this template (covers product-style placeholders
  /// plus service-specific wording).
  AdTemplate applyService({
    required String serviceName,
    required String priceFormatted,
    String? imageUrl,
    String? shopUrl,
    String? category,
    String? whatsappNumber,
    String? phoneNumber,
    String? businessName,
    String? location,
    String? tagline,
  }) {
    final applied = applyProduct(
      productName: serviceName,
      priceFormatted: priceFormatted,
      imageUrl: imageUrl,
      shopUrl: shopUrl,
      category: category,
      whatsappNumber: whatsappNumber,
      phoneNumber: phoneNumber,
      businessName: businessName,
      location: location,
      tagline: tagline,
    );

    String serviceSubstitutions(String? raw) {
      if (raw == null) return '';
      var t = raw;
      if (serviceName.isNotEmpty) {
        t = t
            .replaceAll('SERVICE NAME',      serviceName)
            .replaceAll('Service Name',      serviceName)
            .replaceAll('YOUR SERVICE HERE', serviceName)
            .replaceAll('YOUR SERVICE',      serviceName)
            .replaceAll('BOOK NOW',          'BOOK NOW')
            .replaceAll('SERVICE',           serviceName);
      }
      return t;
    }

    final serviceElements = applied.elements.map((el) {
      final t = serviceSubstitutions(el.text);
      return el.copyWith(text: t.isEmpty ? el.text : t);
    }).toList();

    return AdTemplate(
      id: id,
      name: name,
      category: category ?? this.category,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      background: background,
      elements: serviceElements,
      previewColors: previewColors,
      tags: tags,
      industry: industry,
      season: season,
      complexity: complexity,
      suggestedCaption: serviceSubstitutions(applied.suggestedCaption),
      marketingGoal: marketingGoal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'background': background,
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory AdTemplate.fromJson(Map<String, dynamic> j) => AdTemplate(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Untitled',
        category: j['category']?.toString() ?? 'blank',
        canvasWidth: (j['canvasWidth'] as num?)?.toDouble() ?? 1080,
        canvasHeight: (j['canvasHeight'] as num?)?.toDouble() ?? 1080,
        background: j['background']?.toString() ?? '#ffffff',
        elements: (j['elements'] as List? ?? [])
            .map((e) => CanvasElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory AdTemplate.fromCanvasJson(Map<String, dynamic> json, {
    required String id,
    required String name,
    required String category,
  }) {
    final pages = json['pages'];
    final page = pages is List && pages.isNotEmpty
        ? pages.first as Map<String, dynamic>?
        : null;
    return AdTemplate(
      id: id,
      name: name,
      category: category,
      canvasWidth: (json['width'] as num?)?.toDouble() ?? 1080,
      canvasHeight: (json['height'] as num?)?.toDouble() ?? 1080,
      background: page?['background']?.toString() ?? '#ffffff',
      elements: (page?['children'] as List? ?? [])
          .map((e) => CanvasElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final builtInTemplates = <AdTemplate>[
  // ── Flash Deal (1080x1080) ──────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_sale_bold', name: 'Flash Deal', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#1e3a8a',
    previewColors: [Color(0xFF1E3A8A), Color(0xFFFF6B6B)],
    elements: [
      CanvasElement(id: 'top_accent', type: 'figure', x: 60, y: 50, width: 960, height: 8, fill: '#ff6b6b', cornerRadius: 4),
      CanvasElement(id: 'headline', type: 'text', text: 'MEGA SALE', x: 40, y: 70, width: 1000, fontSize: 78, fontFamily: 'Inter', fill: '#ff6b6b', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'Limited Time Offer', x: 40, y: 155, width: 1000, fontSize: 32, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 120, y: 210, width: 840, height: 520, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 760, width: 1000, fontSize: 40, fontFamily: 'Poppins', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 820, width: 1000, fontSize: 66, fontFamily: 'Inter', fill: '#ff6b6b', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_shadow', type: 'figure', x: 320, y: 910, width: 440, height: 78, fill: '#000000', cornerRadius: 39, opacity: 0.18, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 910, width: 440, height: 78, fill: '#ff6b6b', cornerRadius: 39),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 320, y: 930, width: 440, fontSize: 30, fontFamily: 'Inter', fill: '#FFFFFF', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1035, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.6),
    ],
  ),

  // ── New Arrival (1080x1080) ─────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_new_arrival', name: 'New Arrival', category: 'new',
    canvasWidth: 1080, canvasHeight: 1080, background: '#064e3b',
    previewColors: [Color(0xFF064E3B), Color(0xFFFEF3C7)],
    elements: [
      CanvasElement(id: 'accent_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 130, fill: '#fef3c7'),
      CanvasElement(id: 'headline', type: 'text', text: 'NEW ARRIVAL', x: 40, y: 40, width: 1000, fontSize: 54, fontFamily: 'Inter', fill: '#064e3b', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 130, y: 170, width: 820, height: 540, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 740, width: 1000, fontSize: 44, fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 40, y: 805, width: 1000, fontSize: 60, fontFamily: 'Inter', fill: '#fef3c7', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 880, width: 440, height: 78, fill: '#fef3c7', cornerRadius: 39),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BE FIRST', x: 320, y: 900, width: 440, fontSize: 28, fontFamily: 'Inter', fill: '#064e3b', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Special Offer (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_promo', name: 'Special Offer', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#581c87',
    previewColors: [Color(0xFF581C87), Color(0xFFFBBF24)],
    elements: [
      CanvasElement(id: 'top_accent', type: 'figure', x: 60, y: 50, width: 960, height: 8, fill: '#fbbf24', cornerRadius: 4),
      CanvasElement(id: 'headline', type: 'text', text: 'SPECIAL OFFER', x: 40, y: 70, width: 1000, fontSize: 64, fontFamily: 'Inter', fill: '#fbbf24', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'Just For You', x: 40, y: 145, width: 1000, fontSize: 30, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 120, y: 200, width: 840, height: 520, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 750, width: 1000, fontSize: 42, fontFamily: 'Poppins', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 120,000', x: 40, y: 810, width: 1000, fontSize: 62, fontFamily: 'Inter', fill: '#fbbf24', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 280, y: 890, width: 520, height: 82, fill: '#fbbf24', cornerRadius: 41),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ORDER NOW', x: 280, y: 912, width: 520, fontSize: 30, fontFamily: 'Inter', fill: '#581c87', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.7),
    ],
  ),

  // ── Story / Status (1080x1920) ──────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_story', name: 'Story / Status', category: 'story',
    canvasWidth: 1080, canvasHeight: 1920, background: '#f97316',
    previewColors: [Color(0xFFF97316), Color(0xFF0F172A)],
    elements: [
      CanvasElement(id: 'top_glow', type: 'figure', x: 0, y: 0, width: 1080, height: 420, fill: '#0f172a'),
      CanvasElement(id: 'headline', type: 'text', text: 'HOT DEAL', x: 40, y: 130, width: 1000, fontSize: 80, fontFamily: 'Inter', fill: '#0f172a', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'subheadline', type: 'text', text: "Don't Miss Out!", x: 40, y: 230, width: 1000, fontSize: 38, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 460, width: 920, height: 760, cornerRadius: 32, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 1260, width: 1000, fontSize: 48, fontFamily: 'Poppins', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 1330, width: 1000, fontSize: 78, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 220, y: 1460, width: 640, height: 105, fill: '#0f172a', cornerRadius: 52),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SWIPE UP', x: 220, y: 1488, width: 640, fontSize: 38, fontFamily: 'Inter', fill: '#0f172a', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1625, width: 1000, fontSize: 28, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.8),
    ],
  ),

  // ── Premium Clean (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_minimal', name: 'Premium Clean', category: 'minimal',
    canvasWidth: 1080, canvasHeight: 1080, background: '#fef3c7',
    previewColors: [Color(0xFFFEF3C7), Color(0xFF115E59)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 70, width: 920, height: 600, cornerRadius: 20, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'Product Name', x: 40, y: 700, width: 1000, fontSize: 46, fontFamily: 'Playfair Display', fill: '#115e59', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'selling', type: 'text', text: 'Crafted with care', x: 40, y: 760, width: 1000, fontSize: 24, fontFamily: 'Inter', fill: '#115e59', align: 'center', opacity: 0.7),
      CanvasElement(id: 'divider', type: 'figure', x: 420, y: 810, width: 240, height: 3, fill: '#115e59', cornerRadius: 1, opacity: 0.4),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 840, width: 1000, fontSize: 56, fontFamily: 'Inter', fill: '#115e59', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Shop Now →', x: 40, y: 925, width: 1000, fontSize: 26, fontFamily: 'Inter', fill: '#115e59', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1005, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#115e59', align: 'center', opacity: 0.5),
    ],
  ),

  // ── WhatsApp Ready (800x800) ──────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_whatsapp', name: 'WhatsApp Ready', category: 'whatsapp',
    canvasWidth: 800, canvasHeight: 800, background: '#115e59',
    previewColors: [Color(0xFF115E59), Color(0xFFFACC15)],
    elements: [
      CanvasElement(id: 'inner_box', type: 'figure', x: 35, y: 35, width: 730, height: 730, fill: '#ffffff', cornerRadius: 24),
      CanvasElement(id: 'headline', type: 'text', text: 'ORDER ON', x: 40, y: 75, width: 720, fontSize: 26, fontFamily: 'Inter', fill: '#115e59', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'headline2', type: 'text', text: 'WHATSAPP', x: 40, y: 108, width: 720, fontSize: 40, fontFamily: 'Inter', fill: '#22c55e', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 165, width: 620, height: 360, cornerRadius: 16, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'Product Name', x: 40, y: 550, width: 720, fontSize: 30, fontFamily: 'Inter', fill: '#115e59', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 75,000', x: 40, y: 600, width: 720, fontSize: 44, fontFamily: 'Inter', fill: '#facc15', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Tap to Order →', x: 40, y: 680, width: 720, fontSize: 24, fontFamily: 'Inter', fill: '#115e59', align: 'center', fontWeight: '600'),
    ],
  ),

  // ── Book Now (1080x1080) ────────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_booking', name: 'Book Now', category: 'booking',
    canvasWidth: 1080, canvasHeight: 1080, background: '#312e81',
    previewColors: [Color(0xFF312E81), Color(0xFFA3E635)],
    elements: [
      CanvasElement(id: 'accent_top', type: 'figure', x: 0, y: 0, width: 1080, height: 8, fill: '#a3e635'),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 320, y: 45, width: 440, height: 50, fill: '#a3e635', cornerRadius: 25),
      CanvasElement(id: 'badge_text', type: 'text', text: 'PROFESSIONAL SERVICE', x: 320, y: 58, width: 440, fontSize: 18, fontFamily: 'Inter', fill: '#312e81', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'headline', type: 'text', text: 'BOOK TODAY', x: 40, y: 120, width: 1000, fontSize: 60, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 120, y: 210, width: 840, height: 480, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 715, width: 1000, fontSize: 40, fontFamily: 'Poppins', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 770, width: 1000, fontSize: 52, fontFamily: 'Inter', fill: '#a3e635', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 270, y: 840, width: 540, height: 82, fill: '#a3e635', cornerRadius: 41),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BOOK NOW', x: 270, y: 862, width: 540, fontSize: 30, fontFamily: 'Inter', fill: '#312e81', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1005, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Collection (1080x1350) ──────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_catalog', name: 'Collection', category: 'catalog',
    canvasWidth: 1080, canvasHeight: 1350, background: '#2f44a8',
    previewColors: [Color(0xFF2F44A8), Color(0xFF5A74F0)],
    elements: [
      CanvasElement(id: 'top_band', type: 'figure', x: 0, y: 0, width: 1080, height: 6, fill: '#5a74f0'),
      CanvasElement(id: 'cat_bg', type: 'figure', x: 60, y: 45, width: 280, height: 48, fill: '#5a74f0', cornerRadius: 24),
      CanvasElement(id: 'cat_text', type: 'text', text: 'FEATURED', x: 60, y: 56, width: 280, fontSize: 18, fontFamily: 'Inter', fill: '#2f44a8', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'headline', type: 'text', text: 'TOP PICK', x: 60, y: 115, width: 960, fontSize: 52, fontFamily: 'Inter', fill: '#ffffff', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 185, width: 960, height: 670, cornerRadius: 24, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 880, width: 960, fontSize: 42, fontFamily: 'Poppins', fill: '#ffffff', align: 'left', fontWeight: '600'),
      CanvasElement(id: 'divider', type: 'figure', x: 60, y: 945, width: 960, height: 2, fill: '#ffffff', cornerRadius: 1, opacity: 0.2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 60, y: 975, width: 500, fontSize: 54, fontFamily: 'Inter', fill: '#5a74f0', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 620, y: 975, width: 400, height: 72, fill: '#5a74f0', cornerRadius: 36),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 620, y: 994, width: 400, fontSize: 26, fontFamily: 'Inter', fill: '#2f44a8', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1100, width: 960, fontSize: 18, fontFamily: 'Inter', fill: '#ffffff', align: 'left', opacity: 0.6),
    ],
  ),

  // ── Instagram (1080x1080) ───────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_instagram', name: 'Instagram', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#6f08b2',
    previewColors: [Color(0xFFE6404D), Color(0xFF6F08B2)],
    elements: [
      CanvasElement(id: 'bg_gradient', type: 'figure', x: 0, y: 0, width: 1080, height: 560, fill: '#e6404d', opacity: 0.35),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 170, y: 60, width: 740, height: 520, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'headline', type: 'text', text: 'HOT NOW', x: 40, y: 610, width: 1000, fontSize: 74, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 700, width: 960, fontSize: 36, fontFamily: 'Poppins', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price_bg', type: 'figure', x: 260, y: 760, width: 560, height: 84, fill: '#ffffff', cornerRadius: 42),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 260, y: 780, width: 560, fontSize: 44, fontFamily: 'Inter', fill: '#6f08b2', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 880, width: 440, height: 70, fill: '#fb9623', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 320, y: 898, width: 440, fontSize: 28, fontFamily: 'Inter', fill: '#6f08b2', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Dark Luxury (1080x1080) ─────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_luxury', name: 'Dark Luxury', category: 'minimal',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFF4A96E)],
    elements: [
      CanvasElement(id: 'gold_line_top', type: 'figure', x: 100, y: 60, width: 880, height: 2, fill: '#f4a96e', opacity: 0.5),
      CanvasElement(id: 'headline', type: 'text', text: 'EXCLUSIVE', x: 40, y: 85, width: 1000, fontSize: 40, fontFamily: 'Inter', fill: '#f4a96e', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 120, y: 160, width: 840, height: 560, cornerRadius: 12, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'Product Name', x: 60, y: 745, width: 960, fontSize: 46, fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'selling', type: 'text', text: 'Premium Collection', x: 60, y: 810, width: 960, fontSize: 22, fontFamily: 'Inter', fill: '#f4a96e', align: 'center'),
      CanvasElement(id: 'gold_line_mid', type: 'figure', x: 380, y: 855, width: 320, height: 2, fill: '#f4a96e', opacity: 0.6),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 885, width: 1000, fontSize: 60, fontFamily: 'Inter', fill: '#f4a96e', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 280, y: 955, width: 520, height: 72, fill: '#f4a96e', cornerRadius: 36),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 280, y: 973, width: 520, fontSize: 26, fontFamily: 'Inter', fill: '#000000', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'gold_line_bottom', type: 'figure', x: 100, y: 1055, width: 880, height: 2, fill: '#f4a96e', opacity: 0.5),
    ],
  ),

  // ── Bold Geometric (1080x1080) ──────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_geometric', name: 'Bold Geometric', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#3046ad',
    previewColors: [Color(0xFF3046AD), Color(0xFFE74652)],
    elements: [
      CanvasElement(id: 'shape1', type: 'figure', x: 0, y: 0, width: 540.0, height: 210, fill: '#e74652'),
      CanvasElement(id: 'shape2', type: 'figure', x: 540.0, y: 0, width: 540.0, height: 130, fill: '#2d69c9'),
      CanvasElement(id: 'headline', type: 'text', text: 'BIG SALE', x: 40, y: 45, width: 460, fontSize: 76, fontFamily: 'Inter', fill: '#ffffff', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'discount_bg', type: 'figure', x: 590, y: 35, width: 220, height: 65, fill: '#e74652', cornerRadius: 8),
      CanvasElement(id: 'discount', type: 'text', text: '-50%', x: 590, y: 50, width: 220, fontSize: 34, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 50, y: 240, width: 980, height: 510, cornerRadius: 20, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 775, width: 640, fontSize: 38, fontFamily: 'Inter', fill: '#ffffff', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 835, width: 640, fontSize: 56, fontFamily: 'Inter', fill: '#e74652', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 40, y: 910, width: 380, height: 74, fill: '#e74652', cornerRadius: 12),
      CanvasElement(id: 'cta_text', type: 'text', text: 'GRAB IT', x: 40, y: 928, width: 380, fontSize: 30, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'shape3', type: 'figure', x: 740, y: 900, width: 300, height: 190, fill: '#2d69c9', cornerRadius: 18),
      CanvasElement(id: 'qr_hint', type: 'text', text: '{{CTA_LINK}}', x: 740, y: 975, width: 300, fontSize: 24, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: '600'),
    ],
  ),

  // ── Colorful Pop (1080x1350) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_colorpop', name: 'Colorful Pop', category: 'new',
    canvasWidth: 1080, canvasHeight: 1350, background: '#fca84a',
    previewColors: [Color(0xFFFCA84A), Color(0xFFE1224C)],
    elements: [
      CanvasElement(id: 'circle1', type: 'figure', x: -100, y: -100, width: 420, height: 420, fill: '#f4a96e', cornerRadius: 210),
      CanvasElement(id: 'circle2', type: 'figure', x: 780, y: 1060, width: 400, height: 400, fill: '#e95762', cornerRadius: 200),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 60, y: 60, width: 220, height: 56, fill: '#e1224c', cornerRadius: 28),
      CanvasElement(id: 'badge_text', type: 'text', text: 'NEW IN', x: 60, y: 74, width: 220, fontSize: 24, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 160, width: 920, height: 640, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 830, width: 960, fontSize: 46, fontFamily: 'Inter', fill: '#3249b3', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'selling', type: 'text', text: 'Trending now!', x: 60, y: 895, width: 960, fontSize: 26, fontFamily: 'Poppins', fill: '#e1224c', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 60, y: 950, width: 220, height: 5, fill: '#e1224c', cornerRadius: 2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 60, y: 985, width: 600, fontSize: 60, fontFamily: 'Inter', fill: '#3249b3', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 60, y: 1070, width: 440, height: 84, fill: '#e1224c', cornerRadius: 18),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 60, y: 1092, width: 440, fontSize: 30, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1205, width: 960, fontSize: 20, fontFamily: 'Inter', fill: '#3249b3', align: 'left', opacity: 0.4),
    ],
  ),

  // ── Food Special (1080x1080) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_food', name: 'Food Special', category: 'food',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFF4A261)],
    elements: [
      CanvasElement(id: 'top_stripe', type: 'figure', x: 0, y: 0, width: 1080, height: 10, fill: '#f4a261'),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 45, y: 35, width: 240, height: 62, fill: '#f4a261', cornerRadius: 10),
      CanvasElement(id: 'badge_text', type: 'text', text: "TODAY'S SPECIAL", x: 45, y: 52, width: 240, fontSize: 20, fontFamily: 'Oswald', fill: '#000000', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 55, y: 125, width: 970, height: 590, cornerRadius: 24, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 745, width: 1000, fontSize: 50, fontFamily: 'Oswald', fill: '#ffffff', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'subtitle', type: 'text', text: 'Fresh · Delicious · Quality', x: 40, y: 805, width: 700, fontSize: 22, fontFamily: 'Lato', fill: '#f4a261', align: 'left'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 75,000', x: 40, y: 880, width: 600, fontSize: 56, fontFamily: 'Inter', fill: '#f4a261', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 700, y: 880, width: 340, height: 78, fill: '#f4a261', cornerRadius: 39),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ORDER', x: 700, y: 900, width: 340, fontSize: 32, fontFamily: 'Oswald', fill: '#000000', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.4),
      CanvasElement(id: 'bottom_stripe', type: 'figure', x: 0, y: 1070, width: 1080, height: 10, fill: '#f4a261'),
    ],
  ),

  // ── Fashion Drop (1080x1350) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_fashion', name: 'Fashion Drop', category: 'fashion',
    canvasWidth: 1080, canvasHeight: 1350, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF000000)],
    elements: [
      CanvasElement(id: 'sidebar', type: 'figure', x: 0, y: 0, width: 70, height: 1350, fill: '#000000'),
      CanvasElement(id: 'label_bg', type: 'figure', x: 100, y: 60, width: 200, height: 46, fill: '#000000', cornerRadius: 8),
      CanvasElement(id: 'label', type: 'text', text: 'NEW SEASON', x: 100, y: 71, width: 200, fontSize: 18, fontFamily: 'Raleway', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'headline', type: 'text', text: 'PRODUCT\nNAME', x: 100, y: 130, width: 900, fontSize: 78, fontFamily: 'Montserrat', fill: '#000000', align: 'left', fontWeight: 'bold', lineHeight: 1.05),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 100, y: 360, width: 880, height: 700, cornerRadius: 12, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 100, y: 1090, width: 500, fontSize: 48, fontFamily: 'Inter', fill: '#000000', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 100, y: 1170, width: 360, height: 74, fill: '#000000', cornerRadius: 8),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP THE LOOK', x: 100, y: 1189, width: 360, fontSize: 22, fontFamily: 'Raleway', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 100, y: 1280, width: 880, fontSize: 18, fontFamily: 'Inter', fill: '#000000', align: 'right', opacity: 0.35),
    ],
  ),

  // ── Property Listing (1080x1080) ────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_realestate', name: 'Property Listing', category: 'realestate',
    canvasWidth: 1080, canvasHeight: 1080, background: '#2f44a8',
    previewColors: [Color(0xFF2F44A8), Color(0xFFFB8704)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 620, cornerRadius: 0),
      CanvasElement(id: 'image_overlay', type: 'figure', x: 0, y: 420, width: 1080, height: 220, fill: '#2f44a8', opacity: 0.65),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 45, y: 45, width: 180, height: 54, fill: '#fb8704', cornerRadius: 8),
      CanvasElement(id: 'badge_text', type: 'text', text: 'FOR SALE', x: 45, y: 60, width: 180, fontSize: 22, fontFamily: 'Oswald', fill: '#2f44a8', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 200,000', x: 40, y: 650, width: 1000, fontSize: 56, fontFamily: 'Oswald', fill: '#fb8704', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 720, width: 800, fontSize: 40, fontFamily: 'Merriweather', fill: '#ffffff', align: 'left', fontWeight: '600'),
      CanvasElement(id: 'divider', type: 'figure', x: 40, y: 790, width: 130, height: 4, fill: '#fb8704', cornerRadius: 2),
      CanvasElement(id: 'details', type: 'text', text: 'Premium Quality  ·  Fast Delivery', x: 40, y: 820, width: 900, fontSize: 24, fontFamily: 'Lato', fill: '#5872ef', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 40, y: 890, width: 400, height: 78, fill: '#fb8704', cornerRadius: 14),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ENQUIRE NOW', x: 40, y: 912, width: 400, fontSize: 28, fontFamily: 'Oswald', fill: '#2f44a8', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#5872ef', align: 'right'),
    ],
  ),

  // ── Beauty & Wellness (1080x1080) ───────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_beauty', name: 'Beauty & Wellness', category: 'beauty',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFFD31B43)],
    elements: [
      CanvasElement(id: 'top_accent', type: 'figure', x: 0, y: 0, width: 1080, height: 8, fill: '#d31b43'),
      CanvasElement(id: 'headline', type: 'text', text: 'BEAUTY ESSENTIALS', x: 40, y: 45, width: 1000, fontSize: 46, fontFamily: 'Playfair Display', fill: '#d31b43', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'subline', type: 'text', text: 'Glow · Shine · Radiate', x: 40, y: 105, width: 1000, fontSize: 24, fontFamily: 'Raleway', fill: '#c81940', align: 'center'),
      CanvasElement(id: 'circle_bg', type: 'figure', x: 130, y: 160, width: 820, height: 820, fill: '#ffffff', cornerRadius: 410),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 130, y: 170, width: 820, height: 520, cornerRadius: 20, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 725, width: 1000, fontSize: 40, fontFamily: 'Playfair Display', fill: '#2b64bf', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 795, width: 1000, fontSize: 56, fontFamily: 'Inter', fill: '#d31b43', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 270, y: 880, width: 540, height: 80, fill: '#d31b43', cornerRadius: 40),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 270, y: 900, width: 540, fontSize: 30, fontFamily: 'Raleway', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#d31b43', align: 'center', opacity: 0.5),
      CanvasElement(id: 'bottom_accent', type: 'figure', x: 0, y: 1072, width: 1080, height: 8, fill: '#d31b43'),
    ],
  ),

  // ── Services Bold (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_service_bold', name: 'Services Bold', category: 'service',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFFB8500)],
    elements: [
      CanvasElement(id: 'gold_corner', type: 'figure', x: 0, y: 0, width: 320, height: 10, fill: '#fb8500'),
      CanvasElement(id: 'gold_corner2', type: 'figure', x: 0, y: 0, width: 10, height: 320, fill: '#fb8500'),
      CanvasElement(id: 'gold_corner3', type: 'figure', x: 760, y: 1070, width: 320, height: 10, fill: '#fb8500'),
      CanvasElement(id: 'gold_corner4', type: 'figure', x: 1070, y: 760, width: 10, height: 320, fill: '#fb8500'),
      CanvasElement(id: 'headline', type: 'text', text: 'BOOK NOW', x: 40, y: 70, width: 1000, fontSize: 84, fontFamily: 'Oswald', fill: '#fb8500', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 75, y: 210, width: 930, height: 560, cornerRadius: 12, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 800, width: 1000, fontSize: 46, fontFamily: 'Oswald', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'tagline', type: 'text', text: 'Professional · Expert · Trusted', x: 40, y: 865, width: 1000, fontSize: 22, fontFamily: 'Inter', fill: '#fb8500', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'FROM UGX 75,000', x: 40, y: 915, width: 1000, fontSize: 34, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 270, y: 960, width: 540, height: 82, fill: '#fb8500', cornerRadius: 0),
      CanvasElement(id: 'cta_text', type: 'text', text: 'CALL / WHATSAPP', x: 270, y: 980, width: 540, fontSize: 26, fontFamily: 'Oswald', fill: '#000000', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Tech Product (1080x1080) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_tech', name: 'Tech Product', category: 'tech',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFF506CEF)],
    elements: [
      CanvasElement(id: 'glow_orb', type: 'figure', x: 330, y: 80, width: 420, height: 420, fill: '#425fea', cornerRadius: 210, opacity: 0.25),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 80, width: 920, height: 560, cornerRadius: 26, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'tag_bg', type: 'figure', x: 45, y: 45, width: 160, height: 50, fill: '#506cef', cornerRadius: 25),
      CanvasElement(id: 'tag', type: 'text', text: 'FEATURED', x: 45, y: 58, width: 160, fontSize: 18, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 670, width: 1000, fontSize: 48, fontFamily: 'Montserrat', fill: '#ffffff', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'spec_line', type: 'text', text: 'Pro Performance  ·  Free Delivery', x: 40, y: 730, width: 800, fontSize: 22, fontFamily: 'Inter', fill: '#649fff', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 40, y: 775, width: 70, height: 4, fill: '#506cef', cornerRadius: 2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 40, y: 805, width: 700, fontSize: 56, fontFamily: 'Inter', fill: '#506cef', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 40, y: 895, width: 380, height: 80, fill: '#506cef', cornerRadius: 18),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BUY NOW', x: 40, y: 916, width: 380, fontSize: 30, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1018, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#3b55d1', align: 'right'),
    ],
  ),

  // ── Gradient Story (1080x1920) ──────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_gradient_story', name: 'Gradient Story', category: 'story',
    canvasWidth: 1080, canvasHeight: 1920, background: '#8338ec',
    previewColors: [Color(0xFF8338EC), Color(0xFFE32E56)],
    elements: [
      CanvasElement(id: 'grad1', type: 'figure', x: 0, y: 0, width: 1080, height: 960.0, fill: '#8338ec'),
      CanvasElement(id: 'grad2', type: 'figure', x: 0, y: 960.0, width: 1080, height: 960.0, fill: '#e11d48'),
      CanvasElement(id: 'overlay', type: 'figure', x: 0, y: 0, width: 1080, height: 1920, fill: '#000000', opacity: 0.32),
      CanvasElement(id: 'headline', type: 'text', text: "DON'T MISS", x: 60, y: 120, width: 960, fontSize: 84, fontFamily: 'Montserrat', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'This Amazing Deal', x: 60, y: 225, width: 960, fontSize: 46, fontFamily: 'Nunito', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 70, y: 360, width: 940, height: 840, cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 1240, width: 960, fontSize: 56, fontFamily: 'Montserrat', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 60, y: 1330, width: 960, fontSize: 78, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 180, y: 1470, width: 720, height: 105, fill: '#ffffff', cornerRadius: 52),
      CanvasElement(id: 'cta_text', type: 'text', text: 'TAP TO ORDER', x: 180, y: 1494, width: 720, fontSize: 38, fontFamily: 'Montserrat', fill: '#8338ec', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1650, width: 960, fontSize: 28, fontFamily: 'Nunito', fill: '#ffffff', align: 'center', opacity: 0.7),
    ],
  ),

  // ── Professional (1080x1080) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_professional', name: 'Professional', category: 'professional',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF425FEA)],
    elements: [
      CanvasElement(id: 'left_panel', type: 'figure', x: 0, y: 0, width: 400, height: 1080, fill: '#425fea'),
      CanvasElement(id: 'brand', type: 'text', text: '{{BUSINESS}}', x: 0, y: 70, width: 400, fontSize: 28, fontFamily: 'Raleway', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'vertical_text', type: 'text', text: 'QUALITY', x: 162, y: 500, width: 76, fontSize: 18, fontFamily: 'Raleway', fill: '#649fff', align: 'center', fontWeight: 'bold', letterSpacing: 3),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 420, y: 60, width: 620, height: 520, cornerRadius: 12, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 440, y: 610, width: 600, fontSize: 40, fontFamily: 'Merriweather', fill: '#3249b3', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'tagline', type: 'text', text: 'Trusted by thousands across Uganda', x: 440, y: 665, width: 600, fontSize: 20, fontFamily: 'Lato', fill: '#415ee8', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 440, y: 710, width: 90, height: 4, fill: '#425fea', cornerRadius: 2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 120,000', x: 440, y: 745, width: 600, fontSize: 48, fontFamily: 'Inter', fill: '#425fea', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 440, y: 840, width: 320, height: 74, fill: '#425fea', cornerRadius: 10),
      CanvasElement(id: 'cta_text', type: 'text', text: 'GET YOURS', x: 440, y: 860, width: 320, fontSize: 24, fontFamily: 'Raleway', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 440, y: 970, width: 600, fontSize: 18, fontFamily: 'Inter', fill: '#415ee8', align: 'right'),
    ],
  ),

  // ── WhatsApp Business (800x800) ───────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_whatsapp2', name: 'WhatsApp Business', category: 'whatsapp',
    canvasWidth: 800, canvasHeight: 800, background: '#20796e',
    previewColors: [Color(0xFF20796E), Color(0xFF0DBC7C)],
    elements: [
      CanvasElement(id: 'header_bg', type: 'figure', x: 0, y: 0, width: 800, height: 110, fill: '#24867a'),
      CanvasElement(id: 'header_text', type: 'text', text: '🛍️ Special Offer for You!', x: 20, y: 35, width: 760, fontSize: 30, fontFamily: 'Nunito', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 140, width: 680, height: 360, cornerRadius: 16, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 30, y: 530, width: 740, fontSize: 34, fontFamily: 'Nunito', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price_badge', type: 'figure', x: 190, y: 565, width: 420, height: 66, fill: '#0dbc7c', cornerRadius: 33),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 190, y: 582, width: 420, fontSize: 32, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'details', type: 'text', text: '✅ Free Delivery  ·  ✅ Quality Guaranteed', x: 30, y: 655, width: 740, fontSize: 20, fontFamily: 'Nunito', fill: '#56d1a4', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: 'Reply to ORDER  ·  soko24.co', x: 30, y: 715, width: 740, fontSize: 22, fontFamily: 'Nunito', fill: '#0dbc7c', align: 'center', fontWeight: '600'),
    ],
  ),

  // ── Dark Luxury (1080x1080) ─────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_luxury_gold', name: 'Dark Luxury', category: 'luxury',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFFB8704)],
    elements: [
      CanvasElement(id: 'frame_tl', type: 'figure', x: 35, y: 35, width: 130, height: 4, fill: '#fb8704'),
      CanvasElement(id: 'frame_tl2', type: 'figure', x: 35, y: 35, width: 4, height: 130, fill: '#fb8704'),
      CanvasElement(id: 'frame_br', type: 'figure', x: 915, y: 1041, width: 130, height: 4, fill: '#fb8704'),
      CanvasElement(id: 'frame_br2', type: 'figure', x: 1041, y: 915, width: 4, height: 130, fill: '#fb8704'),
      CanvasElement(id: 'headline', type: 'text', text: 'LUXURY COLLECTION', x: 40, y: 75, width: 1000, fontSize: 32, fontFamily: 'Raleway', fill: '#fb8704', align: 'center', fontWeight: '300'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 75, y: 140, width: 930, height: 590, cornerRadius: 0, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 760, width: 1000, fontSize: 44, fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center', fontWeight: '300'),
      CanvasElement(id: 'divider_left', type: 'figure', x: 330, y: 820, width: 150, height: 2, fill: '#fb8704'),
      CanvasElement(id: 'divider_right', type: 'figure', x: 600, y: 820, width: 150, height: 2, fill: '#fb8704'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 200,000', x: 40, y: 855, width: 1000, fontSize: 50, fontFamily: 'Inter', fill: '#fb8704', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_text', type: 'text', text: '⸻ ENQUIRE NOW ⸻', x: 40, y: 935, width: 1000, fontSize: 22, fontFamily: 'Raleway', fill: '#fb8704', align: 'center', fontWeight: '500'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#fb8704', align: 'center', opacity: 0.4),
    ],
  ),

  // ── Grand Opening (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_grand_opening', name: 'Grand Opening', category: 'grand',
    canvasWidth: 1080, canvasHeight: 1080, background: '#bb183c',
    previewColors: [Color(0xFFBB183C), Color(0xFFFB8A0C)],
    elements: [
      CanvasElement(id: 'confetti1', type: 'figure', x: 0, y: 0, width: 1080, height: 14, fill: '#fb8a0c'),
      CanvasElement(id: 'confetti2', type: 'figure', x: 0, y: 1066, width: 1080, height: 14, fill: '#fb8a0c'),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 280, y: 60, width: 520, height: 76, fill: '#fb8a0c', cornerRadius: 38),
      CanvasElement(id: 'badge_text', type: 'text', text: '🎉 GRAND OPENING', x: 280, y: 80, width: 520, fontSize: 28, fontFamily: 'Oswald', fill: '#bb183c', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 75, y: 175, width: 930, height: 530, cornerRadius: 24, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'business_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 735, width: 1000, fontSize: 56, fontFamily: 'Bebas Neue', fill: '#fb8a0c', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'tagline', type: 'text', text: 'We are officially open! Come visit us today.', x: 40, y: 810, width: 1000, fontSize: 24, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 875, width: 440, height: 78, fill: '#fb8a0c', cornerRadius: 39),
      CanvasElement(id: 'cta_text', type: 'text', text: 'VISIT US TODAY', x: 320, y: 896, width: 440, fontSize: 26, fontFamily: 'Oswald', fill: '#bb183c', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1005, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#fb8a0c', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Minimal White (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_minimal_white', name: 'Minimal White', category: 'minimal',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF000000)],
    elements: [
      CanvasElement(id: 'accent_line', type: 'figure', x: 80, y: 100, width: 5, height: 880, fill: '#000000', cornerRadius: 2),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 100, width: 800, height: 610, cornerRadius: 0, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'category', type: 'text', text: 'FEATURED', x: 140, y: 740, width: 800, fontSize: 16, fontFamily: 'Inter', fill: '#64748b', align: 'left', fontWeight: '600'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 140, y: 780, width: 800, fontSize: 52, fontFamily: 'Inter', fill: '#000000', align: 'left', fontWeight: '800'),
      CanvasElement(id: 'divider', type: 'figure', x: 140, y: 855, width: 220, height: 3, fill: '#000000', cornerRadius: 1),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 140, y: 890, width: 420, fontSize: 40, fontFamily: 'Inter', fill: '#000000', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 140, y: 975, width: 800, fontSize: 16, fontFamily: 'Inter', fill: '#64748b', align: 'right', opacity: 0.7),
    ],
  ),

  // ── Free Delivery (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_free_delivery', name: 'Free Delivery', category: 'delivery',
    canvasWidth: 1080, canvasHeight: 1080, background: '#228075',
    previewColors: [Color(0xFF228075), Color(0xFFFFFFFF)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 700, cornerRadius: 0),
      CanvasElement(id: 'image_overlay', type: 'figure', x: 0, y: 520, width: 1080, height: 200, fill: '#228075', opacity: 0.72),
      CanvasElement(id: 'delivery_badge', type: 'figure', x: 45, y: 45, width: 240, height: 66, fill: '#ffffff', cornerRadius: 33),
      CanvasElement(id: 'delivery_text', type: 'text', text: '🚚 FREE DELIVERY', x: 45, y: 65, width: 240, fontSize: 20, fontFamily: 'Inter', fill: '#228075', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 735, width: 1000, fontSize: 52, fontFamily: 'Poppins', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 815, width: 1000, fontSize: 62, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'sub', type: 'text', text: 'Free delivery within Kampala • Order now', x: 40, y: 895, width: 1000, fontSize: 22, fontFamily: 'Lato', fill: '#ffffff', align: 'center', opacity: 0.9),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 950, width: 440, height: 76, fill: '#ffffff', cornerRadius: 38),
      CanvasElement(id: 'cta_text', type: 'text', text: 'WA: {{WHATSAPP}}', x: 320, y: 970, width: 440, fontSize: 22, fontFamily: 'Inter', fill: '#228075', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Limited Stock (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_limited_stock', name: 'Limited Stock', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFE74854)],
    elements: [
      CanvasElement(id: 'urgent_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 88, fill: '#e74854'),
      CanvasElement(id: 'urgent_text', type: 'text', text: '⚠️  LIMITED STOCK — HURRY!', x: 40, y: 26, width: 1000, fontSize: 30, fontFamily: 'Oswald', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 110, y: 125, width: 860, height: 540, cornerRadius: 16, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 690, width: 1000, fontSize: 44, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'stock_badge', type: 'figure', x: 360, y: 755, width: 360, height: 62, fill: '#e74854', cornerRadius: 10),
      CanvasElement(id: 'stock_text', type: 'text', text: 'Only 5 left in stock!', x: 360, y: 772, width: 360, fontSize: 22, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 850, width: 1000, fontSize: 66, fontFamily: 'Inter', fill: '#e74854', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: 'Get it before it runs out • soko24.co', x: 40, y: 1015, width: 1000, fontSize: 17, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Event Invite (1080x1350) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_event', name: 'Event Invite', category: 'event',
    canvasWidth: 1080, canvasHeight: 1350, background: '#334bb8',
    previewColors: [Color(0xFF334BB8), Color(0xFF9B5FEF)],
    elements: [
      CanvasElement(id: 'glow1', type: 'figure', x: -100, y: -100, width: 520, height: 520, fill: '#8a43ed', cornerRadius: 260, opacity: 0.18),
      CanvasElement(id: 'glow2', type: 'figure', x: 700, y: 900, width: 420, height: 420, fill: '#e32e56', cornerRadius: 210, opacity: 0.12),
      CanvasElement(id: 'event_label', type: 'text', text: '✦  YOU ARE INVITED  ✦', x: 40, y: 85, width: 1000, fontSize: 22, fontFamily: 'Raleway', fill: '#9b5fef', align: 'center', fontWeight: '600', letterSpacing: 2),
      CanvasElement(id: 'event_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 140, width: 1000, fontSize: 76, fontFamily: 'Syne', fill: '#ffffff', align: 'center', fontWeight: '800'),
      CanvasElement(id: 'divider', type: 'figure', x: 430, y: 265, width: 220, height: 3, fill: '#9b5fef', cornerRadius: 1),
      CanvasElement(id: 'event_image', type: 'image', src: '', x: 70, y: 305, width: 940, height: 660, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'date_bg', type: 'figure', x: 230, y: 990, width: 620, height: 84, fill: '#8a43ed', cornerRadius: 14),
      CanvasElement(id: 'date_text', type: 'text', text: '📅  Saturday, 1 June 2025', x: 230, y: 1012, width: 620, fontSize: 24, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: '700'),
      CanvasElement(id: 'location', type: 'text', text: '📍  Kampala, Uganda', x: 40, y: 1110, width: 1000, fontSize: 24, fontFamily: 'Inter', fill: '#9b5fef', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 1185, width: 440, height: 76, fill: '#9b5fef', cornerRadius: 38),
      CanvasElement(id: 'cta_text', type: 'text', text: 'RSVP NOW', x: 320, y: 1205, width: 440, fontSize: 28, fontFamily: 'Oswald', fill: '#334bb8', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1290, width: 1000, fontSize: 17, fontFamily: 'Inter', fill: '#9b5fef', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Health & Wellness (1080x1080) ───────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_health', name: 'Health & Wellness', category: 'health',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF0CAA71)],
    elements: [
      CanvasElement(id: 'leaf1', type: 'figure', x: -60, y: -60, width: 270, height: 270, fill: '#4dcf9f', cornerRadius: 135, opacity: 0.45),
      CanvasElement(id: 'leaf2', type: 'figure', x: 900, y: 880, width: 220, height: 220, fill: '#4dcf9f', cornerRadius: 110, opacity: 0.35),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 45, y: 60, width: 220, height: 56, fill: '#0caa71', cornerRadius: 12),
      CanvasElement(id: 'badge_text', type: 'text', text: '🌿 NATURAL', x: 45, y: 75, width: 220, fontSize: 22, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 70, y: 155, width: 940, height: 560, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 745, width: 1000, fontSize: 46, fontFamily: 'Plus Jakarta Sans', fill: '#0a9361', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'benefit', type: 'text', text: '100% Natural  •  No Chemicals  •  Results Guaranteed', x: 40, y: 810, width: 1000, fontSize: 20, fontFamily: 'Lato', fill: '#0caa71', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 870, width: 1000, fontSize: 56, fontFamily: 'Inter', fill: '#0a9361', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 950, width: 440, height: 74, fill: '#0caa71', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ORDER NOW', x: 320, y: 969, width: 440, fontSize: 26, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Farm Fresh (1080x1080) ──────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_agri', name: 'Farm Fresh', category: 'agri',
    canvasWidth: 1080, canvasHeight: 1080, background: '#a41534',
    previewColors: [Color(0xFFA41534), Color(0xFFF0B622)],
    elements: [
      CanvasElement(id: 'green_strip', type: 'figure', x: 0, y: 0, width: 1080, height: 130, fill: '#f0b622'),
      CanvasElement(id: 'headline', type: 'text', text: '🌱 FRESH FROM THE FARM', x: 40, y: 38, width: 1000, fontSize: 38, fontFamily: 'Oswald', fill: '#a41534', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 70, y: 165, width: 940, height: 540, cornerRadius: 24, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 735, width: 1000, fontSize: 52, fontFamily: 'Fjalla One', fill: '#f0b622', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'quality', type: 'text', text: 'Organically Grown  •  Direct from Farmers', x: 40, y: 805, width: 1000, fontSize: 22, fontFamily: 'Lato', fill: '#fbcd54', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 870, width: 1000, fontSize: 60, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 950, width: 440, height: 74, fill: '#f0b622', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BUY FRESH TODAY', x: 320, y: 969, width: 440, fontSize: 24, fontFamily: 'Oswald', fill: '#a41534', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Weekend Sale (1080x1080) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_weekend_sale', name: 'Weekend Sale', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF8A43ED)],
    elements: [
      CanvasElement(id: 'big_circle', type: 'figure', x: 540, y: 0, width: 820, height: 820, fill: '#8a43ed', cornerRadius: 410, opacity: 0.08),
      CanvasElement(id: 'weekend_badge', type: 'figure', x: 0, y: 0, width: 1080, height: 100, fill: '#8a43ed'),
      CanvasElement(id: 'weekend_text', type: 'text', text: 'WEEKEND SALE  🔥  ENDS SUNDAY', x: 40, y: 28, width: 1000, fontSize: 34, fontFamily: 'Barlow Condensed', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 130, width: 900, height: 560, cornerRadius: 20, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 715, width: 1000, fontSize: 46, fontFamily: 'Plus Jakarta Sans', fill: '#334bb8', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'was_price', type: 'text', text: 'Was UGX 150,000', x: 40, y: 775, width: 1000, fontSize: 24, fontFamily: 'Inter', fill: '#6c757d', align: 'center'),
      CanvasElement(id: 'now_price', type: 'text', text: 'NOW UGX 99,000', x: 40, y: 825, width: 1000, fontSize: 62, fontFamily: 'Inter', fill: '#8a43ed', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 915, width: 440, height: 74, fill: '#8a43ed', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 320, y: 934, width: 440, fontSize: 28, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1020, width: 1000, fontSize: 17, fontFamily: 'Inter', fill: '#6c757d', align: 'center'),
    ],
  ),

  // ── Book a Session (1080x1080) ──────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_booking_session', name: 'Book a Session', category: 'booking',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFFB8A0C)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 720, cornerRadius: 0),
      CanvasElement(id: 'overlay', type: 'figure', x: 0, y: 0, width: 1080, height: 720, fill: '#000000', opacity: 0.42),
      CanvasElement(id: 'service_label', type: 'text', text: 'BOOK A SESSION', x: 40, y: 65, width: 1000, fontSize: 20, fontFamily: 'Raleway', fill: '#fb8a0c', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'service_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 125, width: 1000, fontSize: 68, fontFamily: 'Cinzel', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'slots', type: 'text', text: 'Mon – Sat  •  9:00 AM – 6:00 PM', x: 40, y: 240, width: 1000, fontSize: 22, fontFamily: 'Lato', fill: '#fb8a0c', align: 'center'),
      CanvasElement(id: 'price_bg', type: 'figure', x: 330, y: 290, width: 420, height: 74, fill: '#fb8a0c', cornerRadius: 10),
      CanvasElement(id: 'price_text', type: 'text', text: 'From UGX 50,000', x: 330, y: 310, width: 420, fontSize: 24, fontFamily: 'Inter', fill: '#000000', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'bottom_box', type: 'figure', x: 0, y: 720, width: 1080, height: 360, fill: '#000000'),
      CanvasElement(id: 'description', type: 'text', text: 'Professional service tailored just for you.', x: 40, y: 755, width: 1000, fontSize: 24, fontFamily: 'Raleway', fill: '#f8f9fa', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 230, y: 825, width: 620, height: 84, fill: '#fb8a0c', cornerRadius: 42),
      CanvasElement(id: 'cta_text', type: 'text', text: 'WA: {{WHATSAPP}}', x: 230, y: 847, width: 620, fontSize: 30, fontFamily: 'Oswald', fill: '#000000', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 955, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#fb8a0c', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Daily Special (1080x1080) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_daily_special', name: 'Daily Special', category: 'food',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFFDE1C47)],
    elements: [
      CanvasElement(id: 'top_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 110, fill: '#de1c47'),
      CanvasElement(id: 'day_text', type: 'text', text: "🍽️  TODAY'S SPECIAL", x: 40, y: 33, width: 1000, fontSize: 34, fontFamily: 'Staatliches', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 50, y: 140, width: 980, height: 590, cornerRadius: 24, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 760, width: 1000, fontSize: 54, fontFamily: 'Staatliches', fill: '#a51534', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'desc', type: 'text', text: 'Fresh · Made with love · Ready to serve', x: 40, y: 830, width: 1000, fontSize: 22, fontFamily: 'Pacifico', fill: '#de1c47', align: 'center'),
      CanvasElement(id: 'price_bg', type: 'figure', x: 370, y: 880, width: 340, height: 74, fill: '#de1c47', cornerRadius: 37),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 25,000', x: 370, y: 900, width: 340, fontSize: 28, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: 'Order now · soko24.co', x: 40, y: 995, width: 1000, fontSize: 17, fontFamily: 'Inter', fill: '#c5193f', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Catalog Story (1080x1350) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_catalog_story', name: 'Catalog Story', category: 'catalog',
    canvasWidth: 1080, canvasHeight: 1350, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFFFFFFF)],
    elements: [
      CanvasElement(id: 'header_bg', type: 'figure', x: 0, y: 0, width: 1080, height: 125, fill: '#000000'),
      CanvasElement(id: 'brand_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 42, width: 1000, fontSize: 40, fontFamily: 'Space Grotesk', fill: '#ffffff', align: 'center', fontWeight: '800'),
      CanvasElement(id: 'divider', type: 'figure', x: 80, y: 118, width: 920, height: 2, fill: '#343a40', cornerRadius: 1),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 125, width: 1080, height: 850, cornerRadius: 0),
      CanvasElement(id: 'overlay', type: 'figure', x: 0, y: 720, width: 1080, height: 280, fill: '#000000', opacity: 0.6),
      CanvasElement(id: 'item_name', type: 'text', text: 'Collection Piece', x: 40, y: 755, width: 1000, fontSize: 50, fontFamily: 'Raleway', fill: '#ffffff', align: 'center', fontWeight: '300'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 120,000', x: 40, y: 825, width: 1000, fontSize: 38, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer_bg', type: 'figure', x: 0, y: 955, width: 1080, height: 395, fill: '#000000'),
      CanvasElement(id: 'tagline', type: 'text', text: 'Swipe to see more →', x: 40, y: 1005, width: 1000, fontSize: 22, fontFamily: 'Inter', fill: '#f8f9fa', align: 'center'),
      CanvasElement(id: 'shop_url', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1065, width: 1000, fontSize: 30, fontFamily: 'Space Grotesk', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 230, y: 1135, width: 620, height: 74, fill: '#ffffff', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP THE COLLECTION', x: 230, y: 1155, width: 620, fontSize: 24, fontFamily: 'Space Grotesk', fill: '#000000', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Customer Review (1080x1080) ─────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_review', name: 'Customer Review', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF425FEA)],
    elements: [
      CanvasElement(id: 'quote_mark', type: 'text', text: '"', x: 40, y: 15, width: 200, fontSize: 180, fontFamily: 'Playfair Display', fill: '#71a7ff', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'review_text', type: 'text', text: 'This is the best product I have ever bought. Highly recommend to everyone in Kampala!', x: 80, y: 170, width: 920, fontSize: 36, fontFamily: 'Merriweather', fill: '#3a54cf', align: 'center', lineHeight: 1.5),
      CanvasElement(id: 'reviewer_img', type: 'image', src: '', x: 430, y: 470, width: 220, height: 220, cornerRadius: 110, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'reviewer_name', type: 'text', text: 'Jane Nakato', x: 40, y: 725, width: 1000, fontSize: 30, fontFamily: 'Inter', fill: '#425fea', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'stars', type: 'text', text: '★★★★★', x: 40, y: 780, width: 1000, fontSize: 42, fontFamily: 'Inter', fill: '#fbbf24', align: 'center'),
      CanvasElement(id: 'product_name', type: 'text', text: 'Try PRODUCT NAME today', x: 40, y: 860, width: 1000, fontSize: 32, fontFamily: 'Inter', fill: '#3a54cf', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 945, width: 440, height: 74, fill: '#425fea', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 320, y: 964, width: 440, fontSize: 28, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Back to School (1080x1080) ──────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_school', name: 'Back to School', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#fca748',
    previewColors: [Color(0xFFFCA748), Color(0xFFE63946)],
    elements: [
      CanvasElement(id: 'ruler_left', type: 'figure', x: 0, y: 0, width: 45, height: 1080, fill: '#c7844f'),
      CanvasElement(id: 'ruler_right', type: 'figure', x: 1035, y: 0, width: 45, height: 1080, fill: '#c7844f'),
      CanvasElement(id: 'badge', type: 'figure', x: 330, y: 60, width: 420, height: 76, fill: '#e63946', cornerRadius: 10),
      CanvasElement(id: 'badge_text', type: 'text', text: '✏️ BACK TO SCHOOL', x: 330, y: 80, width: 420, fontSize: 28, fontFamily: 'Permanent Marker', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 75, y: 175, width: 930, height: 530, cornerRadius: 14, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 80, y: 740, width: 920, fontSize: 50, fontFamily: 'Permanent Marker', fill: '#c7844f', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 80, y: 820, width: 920, fontSize: 56, fontFamily: 'Inter', fill: '#e63946', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 320, y: 905, width: 440, height: 74, fill: '#c7844f', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'WA: {{WHATSAPP}}', x: 320, y: 924, width: 440, fontSize: 24, fontFamily: 'Inter', fill: '#fca748', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 17, fontFamily: 'Inter', fill: '#c7844f', align: 'center', opacity: 0.5),
    ],
  ),

  // ── TikTok Viral (1080x1920) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_tiktok', name: 'TikTok Viral', category: 'story',
    canvasWidth: 1080, canvasHeight: 1920, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFE74551)],
    elements: [
      CanvasElement(id: 'glow', type: 'figure', x: 0, y: 0, width: 1080, height: 620, fill: '#e74551', opacity: 0.28),
      CanvasElement(id: 'headline', type: 'text', text: 'POV: YOU NEED THIS', x: 60, y: 120, width: 960, fontSize: 62, fontFamily: 'Bebas Neue', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 330, width: 920, height: 920, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'price_bg', type: 'figure', x: 220, y: 1295, width: 640, height: 95, fill: '#e74551', cornerRadius: 47),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 220, y: 1318, width: 640, fontSize: 46, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Link in bio 👆', x: 60, y: 1440, width: 960, fontSize: 34, fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1790, width: 960, fontSize: 24, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── LinkedIn Post (1200x627) ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_linkedin', name: 'LinkedIn Post', category: 'professional',
    canvasWidth: 1200, canvasHeight: 627, background: '#ffffff',
    previewColors: [Color(0xFFFFFFFF), Color(0xFF357BEB)],
    elements: [
      CanvasElement(id: 'accent', type: 'figure', x: 0, y: 0, width: 14, height: 627, fill: '#357beb'),
      CanvasElement(id: 'headline', type: 'text', text: 'Now Available', x: 60, y: 55, width: 700, fontSize: 44, fontFamily: 'Inter', fill: '#2f44a8', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 115, width: 700, fontSize: 30, fontFamily: 'Inter', fill: '#3750c4', align: 'left'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 790, y: 55, width: 390, height: 390, cornerRadius: 14, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 60, y: 200, width: 500, fontSize: 38, fontFamily: 'Inter', fill: '#357beb', align: 'left', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 60, y: 490, width: 240, height: 60, fill: '#357beb', cornerRadius: 30),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Learn more', x: 60, y: 506, width: 240, fontSize: 22, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'footer', type: 'text', text: '{{BUSINESS}} · {{CTA_LINK}}', x: 60, y: 585, width: 1100, fontSize: 17, fontFamily: 'Inter', fill: '#415ee8', align: 'left'),
    ],
  ),

  // ── Black Friday (1080x1080) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_black_friday', name: 'Black Friday', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFFB8706)],
    elements: [
      CanvasElement(id: 'burst', type: 'figure', x: 340, y: 40, width: 420, height: 420, fill: '#fb8706', cornerRadius: 210, opacity: 0.18),
      CanvasElement(id: 'headline', type: 'text', text: 'BLACK FRIDAY', x: 40, y: 85, width: 1000, fontSize: 68, fontFamily: 'Bebas Neue', fill: '#fb8706', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'UP TO 50% OFF', x: 40, y: 170, width: 1000, fontSize: 38, fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 130, y: 250, width: 820, height: 510, cornerRadius: 20, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 785, width: 1000, fontSize: 36, fontFamily: 'Inter', fill: '#ffffff', align: 'center', fontWeight: '600'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 840, width: 1000, fontSize: 62, fontFamily: 'Inter', fill: '#fb8706', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 280, y: 930, width: 520, height: 76, fill: '#fb8706', cornerRadius: 38),
      CanvasElement(id: 'cta_text', type: 'text', text: 'GRAB THE DEAL', x: 280, y: 950, width: 520, fontSize: 28, fontFamily: 'Inter', fill: '#000000', align: 'center', fontWeight: 'bold'),
    ],
  ),

  // ── Menu Special (1080x1350) ────────────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_restaurant', name: 'Menu Special', category: 'food',
    canvasWidth: 1080, canvasHeight: 1350, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFDE1C47)],
    elements: [
      CanvasElement(id: 'top_band', type: 'figure', x: 0, y: 0, width: 1080, height: 290, fill: '#de1c47'),
      CanvasElement(id: 'headline', type: 'text', text: "TODAY'S SPECIAL", x: 40, y: 85, width: 1000, fontSize: 54, fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 325, width: 920, height: 590, cornerRadius: 24, shadowColor: '#000000', shadowDx: 0, shadowDy: 12, shadowBlur: 28),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 945, width: 1000, fontSize: 46, fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 25,000', x: 40, y: 1015, width: 1000, fontSize: 52, fontFamily: 'Inter', fill: '#de1c47', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Order: {{WHATSAPP}}', x: 40, y: 1100, width: 1000, fontSize: 30, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.9),
      CanvasElement(id: 'footer', type: 'text', text: '{{LOCATION}}', x: 40, y: 1285, width: 1000, fontSize: 22, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── SM Insta / Flip what you see (1080x1350) ────────────────────────────
  AdTemplate(
    id: 'tpl_sminsta', name: 'SM Insta', category: 'camera',
    canvasWidth: 1080, canvasHeight: 1350, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFFBBF24)],
    elements: [
      CanvasElement(id: 'photo', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 1080, imageFit: 'cover'),
      CanvasElement(id: 'fade', type: 'figure', x: 0, y: 960, width: 1080, height: 390, fill: '#000000', opacity: 0.65),
      CanvasElement(id: 'business', type: 'text', text: '{{BUSINESS}}', x: 40, y: 1010, width: 1000, fontSize: 42, fontFamily: 'Montserrat', fill: '#ffffff', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'whatsapp', type: 'text', text: 'WhatsApp: {{WHATSAPP}}', x: 40, y: 1070, width: 1000, fontSize: 26, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.9),
      CanvasElement(id: 'price', type: 'text', text: '{{PRICE}}', x: 40, y: 1130, width: 1000, fontSize: 56, fontFamily: 'Inter', fill: '#fbbf24', align: 'center', fontWeight: 'bold'),
      CanvasElement(id: 'cta', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1220, width: 1000, fontSize: 24, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.7),
    ],
  ),

  // ── Programmatic layouts (100+ total with generated set) ─────────────────
  ...generateStudioTemplates(),
];

/// Resolves a programmatic template id from layout + category keys.
String? generatedTemplateId(
  String layout,
  String category, {
  String preferSizeKey = 'sq',
}) {
  final prefix = 'gen_${layout}_${category}_';
  String? fallback;
  for (final t in builtInTemplates) {
    if (!t.id.startsWith(prefix)) continue;
    fallback ??= t.id;
    final parts = t.id.split('_');
    if (parts.length >= 5 && parts[parts.length - 2] == preferSizeKey) {
      return t.id;
    }
  }
  return fallback;
}

// ─── Google Fonts available in Studio (30 fonts) ──────────────────────────────
/// Display name → Google Fonts package name (exact case for GoogleFonts.getFont)
const studioFonts = <String, String>{
  // Sans-serif / modern
  'Inter':              'Inter',
  'Poppins':            'Poppins',
  'Montserrat':         'Montserrat',
  'DM Sans':            'DM Sans',
  'Plus Jakarta Sans':  'Plus Jakarta Sans',
  'Space Grotesk':      'Space Grotesk',
  'Syne':               'Syne',
  'Josefin Sans':       'Josefin Sans',
  'Nunito':             'Nunito',
  'Lato':               'Lato',
  'Raleway':            'Raleway',
  'Open Sans':          'Open Sans',
  'Roboto':             'Roboto',
  'Ubuntu':             'Ubuntu',
  // Condensed / display
  'Oswald':             'Oswald',
  'Bebas Neue':         'Bebas Neue',
  'Barlow Condensed':   'Barlow Condensed',
  'Staatliches':        'Staatliches',
  'Fjalla One':         'Fjalla One',
  'Righteous':          'Righteous',
  'Exo 2':              'Exo 2',
  'Orbitron':           'Orbitron',
  // Serif / editorial
  'Merriweather':       'Merriweather',
  'Playfair Display':   'Playfair Display',
  'Cinzel':             'Cinzel',
  'Yeseva One':         'Yeseva One',
  // Script / decorative
  'Pacifico':           'Pacifico',
  'Dancing Script':     'Dancing Script',
  'Lobster':            'Lobster',
  'Permanent Marker':   'Permanent Marker',
  'Anton':              'Anton',
  'Archivo Black':      'Archivo Black',
  'Cormorant Garamond': 'Cormorant Garamond',
};

/// Clone a library preset for insertion onto the canvas.
CanvasElement stampCanvasElement(
  CanvasElement source, {
  required String newId,
  bool preservePosition = false,
  double? canvasWidth,
  double? canvasHeight,
}) {
  final cx = preservePosition || canvasWidth == null
      ? source.x
      : (canvasWidth - source.width) / 2;
  final cy = preservePosition || canvasHeight == null
      ? source.y
      : (canvasHeight - source.height) / 2;
  return CanvasElement(
    id: newId,
    type: source.type,
    text: source.text,
    src: source.src,
    x: cx,
    y: cy,
    width: source.width,
    height: source.height,
    fontSize: source.fontSize,
    fontWeight: source.fontWeight,
    fontFamily: source.fontFamily,
    fill: source.fill,
    align: source.align,
    cornerRadius: source.cornerRadius,
    opacity: source.opacity,
    textDecoration: source.textDecoration,
    placeholder: source.placeholder,
    rotation: source.rotation,
    letterSpacing: source.letterSpacing,
    lineHeight: source.lineHeight,
    shadowColor: source.shadowColor,
    shadowDx: source.shadowDx,
    shadowDy: source.shadowDy,
    shadowBlur: source.shadowBlur,
    strokeColor: source.strokeColor,
    strokeWidth: source.strokeWidth,
    iconCodePoint: source.iconCodePoint,
    iconFontFamily: source.iconFontFamily,
    iconFontPackage: source.iconFontPackage,
    assetId: source.assetId,
    isPremium: source.isPremium,
  );
}

/// Font style descriptors shown in the UI font picker
const fontDescriptors = <String, ({String sample, String vibe})>{
  'Inter':              (sample: 'Aa', vibe: 'Clean'),
  'Poppins':            (sample: 'Aa', vibe: 'Modern'),
  'Montserrat':         (sample: 'Aa', vibe: 'Bold'),
  'DM Sans':            (sample: 'Aa', vibe: 'Minimal'),
  'Plus Jakarta Sans':  (sample: 'Aa', vibe: 'Premium'),
  'Space Grotesk':      (sample: 'Aa', vibe: 'Techy'),
  'Syne':               (sample: 'Aa', vibe: 'Artsy'),
  'Josefin Sans':       (sample: 'Aa', vibe: 'Chic'),
  'Nunito':             (sample: 'Aa', vibe: 'Round'),
  'Lato':               (sample: 'Aa', vibe: 'Friendly'),
  'Raleway':            (sample: 'Aa', vibe: 'Elegant'),
  'Open Sans':          (sample: 'Aa', vibe: 'Neutral'),
  'Roboto':             (sample: 'Aa', vibe: 'Google'),
  'Ubuntu':             (sample: 'Aa', vibe: 'Tech'),
  'Oswald':             (sample: 'AA', vibe: 'Strong'),
  'Bebas Neue':         (sample: 'AA', vibe: 'Impact'),
  'Barlow Condensed':   (sample: 'AA', vibe: 'News'),
  'Staatliches':        (sample: 'AA', vibe: 'Poster'),
  'Fjalla One':         (sample: 'Aa', vibe: 'Athletic'),
  'Righteous':          (sample: 'Aa', vibe: 'Street'),
  'Exo 2':              (sample: 'Aa', vibe: 'Sci-Fi'),
  'Orbitron':           (sample: 'AA', vibe: 'Futuristic'),
  'Merriweather':       (sample: 'Aa', vibe: 'Editorial'),
  'Playfair Display':   (sample: 'Aa', vibe: 'Luxury'),
  'Cinzel':             (sample: 'AA', vibe: 'Classic'),
  'Yeseva One':         (sample: 'Aa', vibe: 'Vintage'),
  'Pacifico':           (sample: 'Aa', vibe: 'Fun'),
  'Dancing Script':     (sample: 'Aa', vibe: 'Script'),
  'Lobster':            (sample: 'Aa', vibe: 'Retro'),
  'Permanent Marker':   (sample: 'Aa', vibe: 'Handmade'),
  'Anton':              (sample: 'AA', vibe: 'Poster'),
  'Archivo Black':      (sample: 'AA', vibe: 'Street'),
  'Cormorant Garamond': (sample: 'Aa', vibe: 'Editorial'),
};

/// Curated modern, vibrant, professional color palettes for Studio templates.
/// Each palette guarantees readable text via [contrastText].
const studioVibrantPalettes = <({String bg, String accent, String text, String muted})>[
  // Cobalt + Coral
  (bg: '#1e3a8a', accent: '#ff6b6b', text: '#ffffff', muted: '#93c5fd'),
  // Emerald + Cream
  (bg: '#064e3b', accent: '#fef3c7', text: '#ffffff', muted: '#6ee7b7'),
  // Royal Purple + Gold
  (bg: '#581c87', accent: '#fbbf24', text: '#ffffff', muted: '#d8b4fe'),
  // Sunset Orange + Deep Navy
  (bg: '#f97316', accent: '#0f172a', text: '#ffffff', muted: '#fed7aa'),
  // Magenta + Soft Blush
  (bg: '#be185d', accent: '#fce7f3', text: '#ffffff', muted: '#fbcfe8'),
  // Teal + Citrus
  (bg: '#115e59', accent: '#facc15', text: '#ffffff', muted: '#5eead4'),
  // Deep Indigo + Electric Lime
  (bg: '#312e81', accent: '#a3e635', text: '#ffffff', muted: '#a5b4fc'),
  // Charcoal + Tangerine
  (bg: '#1f2937', accent: '#fb923c', text: '#ffffff', muted: '#9ca3af'),
  // Midnight + Cyan
  (bg: '#0f172a', accent: '#22d3ee', text: '#ffffff', muted: '#94a3b8'),
  // Wine + Peach
  (bg: '#7f1d1d', accent: '#fdba74', text: '#ffffff', muted: '#fca5a5'),
];

/// Returns a stable palette from [studioVibrantPalettes] based on [seed].
({String bg, String accent, String text, String muted}) studioPaletteFor(int seed) {
  return studioVibrantPalettes[seed.abs() % studioVibrantPalettes.length];
}

/// Template categories for the Studio picker
const templateCategories = <({String id, String label, IconData icon})>[
  (id: 'all',          label: 'All',         icon: Icons.grid_view_rounded),
  (id: 'sale',         label: 'Sale',        icon: Icons.local_offer_rounded),
  (id: 'new',          label: 'New Arrival', icon: Icons.star_rounded),
  (id: 'promo',        label: 'Promo',       icon: Icons.campaign_rounded),
  (id: 'event',        label: 'Event',       icon: Icons.celebration_rounded),
  (id: 'grand',        label: 'Grand Open',  icon: Icons.storefront_rounded),
  (id: 'story',        label: 'Story',       icon: Icons.smartphone_rounded),
  (id: 'minimal',      label: 'Minimal',     icon: Icons.crop_rounded),
  (id: 'food',         label: 'Food',        icon: Icons.restaurant_rounded),
  (id: 'fashion',      label: 'Fashion',     icon: Icons.checkroom_rounded),
  (id: 'beauty',       label: 'Beauty',      icon: Icons.spa_rounded),
  (id: 'health',       label: 'Health',      icon: Icons.local_hospital_rounded),
  (id: 'agri',         label: 'Farm/Agri',   icon: Icons.grass_rounded),
  (id: 'tech',         label: 'Tech',        icon: Icons.devices_rounded),
  (id: 'service',      label: 'Service',     icon: Icons.miscellaneous_services_rounded),
  (id: 'luxury',       label: 'Luxury',      icon: Icons.diamond_rounded),
  (id: 'whatsapp',     label: 'WhatsApp',    icon: Icons.chat_rounded),
  (id: 'realestate',   label: 'Property',    icon: Icons.home_rounded),
  (id: 'professional', label: 'Business',    icon: Icons.business_center_rounded),
  (id: 'booking',      label: 'Booking',     icon: Icons.calendar_month_rounded),
  (id: 'catalog',      label: 'Catalog',     icon: Icons.view_list_rounded),
  (id: 'delivery',     label: 'Delivery',    icon: Icons.delivery_dining_rounded),
];

/// Preset gradient backgrounds for the canvas background panel
const gradientPresets = <({String id, String label, List<Color> colors})>[
  (id: 'cobaltCoral', label: 'Cobalt Coral', colors: [Color(0xFF1E3A8A), Color(0xFFFF6B6B)]),
  (id: 'emeraldCream', label: 'Emerald Cream', colors: [Color(0xFF064E3B), Color(0xFFFEF3C7)]),
  (id: 'royalGold', label: 'Royal Gold', colors: [Color(0xFF581C87), Color(0xFFFBBF24)]),
  (id: 'sunsetNavy', label: 'Sunset Navy', colors: [Color(0xFFF97316), Color(0xFF0F172A)]),
  (id: 'magentaBlush', label: 'Magenta Blush', colors: [Color(0xFFBE185D), Color(0xFFFCE7F3)]),
  (id: 'tealCitrus', label: 'Teal Citrus', colors: [Color(0xFF115E59), Color(0xFFFACC15)]),
  (id: 'indigoLime', label: 'Indigo Lime', colors: [Color(0xFF312E81), Color(0xFFA3E635)]),
  (id: 'charcoalTangerine', label: 'Charcoal Tangerine', colors: [Color(0xFF1F2937), Color(0xFFFB923C)]),
  (id: 'midnightCyan', label: 'Midnight Cyan', colors: [Color(0xFF0F172A), Color(0xFF22D3EE)]),
  (id: 'winePeach', label: 'Wine Peach', colors: [Color(0xFF7F1D1D), Color(0xFFFDBA74)]),
  (id: 'sunset',    label: 'Sunset',    colors: [Color(0xFFE32E56), Color(0xFFF6B684)]),
  (id: 'ocean',     label: 'Ocean',     colors: [Color(0xFF3377E3), Color(0xFF367EF0)]),
  (id: 'forest',    label: 'Forest',    colors: [Color(0xFF0A9160), Color(0xFF0DB175)]),
  (id: 'neon',      label: 'Neon',      colors: [Color(0xFF8338EC), Color(0xFFE32E56)]),
  (id: 'gold',      label: 'Gold',      colors: [Color(0xFFC1183D), Color(0xFFFB8704)]),
  (id: 'midnight',  label: 'Midnight',  colors: [Color(0xFF5C27A5), Color(0xFF6D2EC4)]),
  (id: 'rose',      label: 'Rose',      colors: [Color(0xFFD31B43), Color(0xFFEB6872)]),
  (id: 'arctic',    label: 'Arctic',    colors: [Color(0xFF2E6CCE), Color(0xFF4F93FF)]),
  (id: 'fire',      label: 'Fire',      colors: [Color(0xFFC4303B), Color(0xFFE74854)]),
  (id: 'mint',      label: 'Mint',      colors: [Color(0xFF1F756B), Color(0xFF2C9E90)]),
  (id: 'peach',     label: 'Peach',     colors: [Color(0xFFF6B988), Color(0xFFF5B17B)]),
  (id: 'slate',     label: 'Slate',     colors: [Color(0xFF2F44A8), Color(0xFF3750C4)]),
  (id: 'soko',      label: 'Soko',      colors: [Color(0xFF3147B0), Color(0xFF269184)]),
  (id: 'candy',     label: 'Candy',     colors: [Color(0xFF8F3CC6), Color(0xFFE84F5A)]),
  (id: 'cosmic',    label: 'Cosmic',    colors: [Color(0xFF3046AC), Color(0xFF2E6BCC)]),
  (id: 'lime',      label: 'Lime',      colors: [Color(0xFF2D6AC9), Color(0xFF1AC184)]),
  (id: 'velvet',    label: 'Velvet',    colors: [Color(0xFF000000), Color(0xFFB52C37)]),
  (id: 'sky',       label: 'Sky',       colors: [Color(0xFF3780F4), Color(0xFF5898FF)]),
  (id: 'sunrise',   label: 'Sunrise',   colors: [Color(0xFFE74652), Color(0xFFF4A363)]),
];

/// Solid color palette (displayed in background & color pickers)
const colorPalette = <Color>[
  // Modern curated accents
  Color(0xFFFF6B6B), Color(0xFFFEF3C7), Color(0xFFFBBF24), Color(0xFFF97316),
  Color(0xFFFCE7F3), Color(0xFFFACC15), Color(0xFFA3E635), Color(0xFFFB923C),
  Color(0xFF22D3EE), Color(0xFFFDBA74),
  // Curated backgrounds
  Color(0xFF1E3A8A), Color(0xFF064E3B), Color(0xFF581C87), Color(0xFF0F172A),
  Color(0xFFBE185D), Color(0xFF115E59), Color(0xFF312E81), Color(0xFF1F2937),
  Color(0xFF7F1D1D),
  Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF3249B3), Color(0xFF2F44A8),
  Color(0xFF3750C4), Color(0xFF6C757D), Color(0xFFF8F9FA),
  Color(0xFF7C91F3),
  // Reds
  Color(0xFFC4303B), Color(0xFFE63946), Color(0xFFE74854), Color(0xFFE95762),
  Color(0xFFED737C),
  // Oranges
  Color(0xFFC1183D), Color(0xFFE89A5C), Color(0xFFF4A261), Color(0xFFFB8A0C),
  Color(0xFFFB9D33),
  // Greens
  Color(0xFF0A9361), Color(0xFF0CAA71), Color(0xFF0DB779), Color(0xFF269184),
  Color(0xFF2C9E90),
  // Blues
  Color(0xFF3A54CF), Color(0xFF425FEA), Color(0xFF506CEF), Color(0xFF5496FF),
  Color(0xFF649FFF),
  // Purples
  Color(0xFF7431D1), Color(0xFF8A43ED), Color(0xFF914EEE), Color(0xFFA36CF1),
  // Pinks
  Color(0xFFC81940), Color(0xFFD31B43), Color(0xFFE32E56), Color(0xFFE85273),
  // Brand
  Color(0xFF3147B0), Color(0xFF269184),
  // Gold
  Color(0xFFB9173B), Color(0xFFFB8704), Color(0xFFFB8A0C),
];

Color parseHexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

String colorToHex(Color c) {
  final value = c.toARGB32();
  return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
