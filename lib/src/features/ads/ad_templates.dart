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

/// Blank canvas for "Create from scratch" flows.
AdTemplate blankCanvas(AdSize size, {String? name}) => AdTemplate(
      id: 'blank_${size.width.toInt()}x${size.height.toInt()}_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Untitled Design',
      category: 'blank',
      canvasWidth: size.width,
      canvasHeight: size.height,
      background: '#ffffff',
      elements: const [],
      previewColors: const [Color(0xFFf8fafc), Color(0xFFe2e8f0)],
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
  });

  final String id;
  final String name;
  final String category;
  final double canvasWidth;
  final double canvasHeight;
  final String background;
  final List<CanvasElement> elements;
  final List<Color>? previewColors;

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

    final newElements = elements.map((el) {
      var t = el.text;
      if (t != null) {
        // ── Brand CTA variable substitutions ─────────────────────────────
        t = t
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

        // ── Product name substitutions (only when non-empty) ─────────────────
        if (productName.isNotEmpty) {
          t = t
              .replaceAll('PRODUCT NAME',      productName)
              .replaceAll('Product Name',      productName)
              .replaceAll('Product Name Here', productName)
              .replaceAll('YOUR PRODUCT HERE', productName)
              .replaceAll('ADD YOUR PRODUCT',  productName)
              .replaceAll('PRODUCT IMAGE',     productName)
              .replaceAll('YOUR PRODUCT',      productName);
        }

        // ── Price substitutions (only when non-empty) ──────────────────────
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

        // ── Business name substitutions (only when different from placeholder) ─
        if (biz != 'Soko 24') {
          t = t
              .replaceAll('YOUR BUSINESS', biz)
              .replaceAll('Your Business', biz);
        }
      }
      var src = el.src;
      if (el.type == 'image' && imageUrl != null && imageUrl.isNotEmpty) {
        src = imageUrl;
      }
      return el.copyWith(text: t, src: src);
    }).toList();
    return AdTemplate(
      id: id, name: name, category: this.category,
      canvasWidth: canvasWidth, canvasHeight: canvasHeight,
      background: background, elements: newElements,
      previewColors: previewColors,
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

// ---------------------------------------------------------------------------
// Pre-installed templates (matching the webapp's CanvasBuilderService)
// ---------------------------------------------------------------------------
final builtInTemplates = <AdTemplate>[
  // ── Flash Deal (1080x1080) ────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_sale_bold', name: 'Flash Deal', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#dc2626',
    previewColors: [Color(0xFFdc2626), Color(0xFFfef08a)],
    elements: [
      CanvasElement(id: 'headline', type: 'text', text: 'MEGA SALE', x: 40, y: 50, width: 1000, fontSize: 72, fontWeight: 'bold', fontFamily: 'Inter', fill: '#fef08a', align: 'center'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'Limited Time Offer', x: 40, y: 140, width: 1000, fontSize: 32, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 220, width: 800, height: 480, cornerRadius: 20),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 730, width: 1000, fontSize: 36, fontWeight: '600', fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 790, width: 1000, fontSize: 64, fontWeight: 'bold', fontFamily: 'Inter', fill: '#fef08a', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 890, width: 400, height: 70, fill: '#fef08a', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 340, y: 906, width: 400, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#dc2626', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1035, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.6),
    ],
  ),

  // ── New Arrival (1080x1080) ───────────────────────────────────────────
  AdTemplate(
    id: 'tpl_new_arrival', name: 'New Arrival', category: 'new',
    canvasWidth: 1080, canvasHeight: 1080, background: '#1e293b',
    previewColors: [Color(0xFF1e293b), Color(0xFFf97316)],
    elements: [
      CanvasElement(id: 'accent_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 120, fill: '#f97316'),
      CanvasElement(id: 'headline', type: 'text', text: 'NEW ARRIVAL', x: 40, y: 35, width: 1000, fontSize: 48, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 160, width: 800, height: 500, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 700, width: 1000, fontSize: 42, fontWeight: 'bold', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 40, y: 770, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#f97316', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 870, width: 400, height: 70, fill: '#f97316', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BE FIRST', x: 340, y: 886, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Special Offer (1080x1080) ─────────────────────────────────────────
  AdTemplate(
    id: 'tpl_promo', name: 'Special Offer', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#7c3aed',
    previewColors: [Color(0xFF7c3aed), Color(0xFFf5f3ff)],
    elements: [
      CanvasElement(id: 'headline', type: 'text', text: 'SPECIAL OFFER', x: 40, y: 60, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'Just For You', x: 40, y: 130, width: 1000, fontSize: 28, fontFamily: 'Poppins', fill: '#f5f3ff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 190, width: 800, height: 480, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 700, width: 1000, fontSize: 40, fontWeight: '600', fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 120,000', x: 40, y: 760, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#f5f3ff', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 290, y: 870, width: 500, height: 80, fill: '#ffffff', cornerRadius: 40),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ORDER NOW', x: 290, y: 892, width: 500, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#7c3aed', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.7),
    ],
  ),

  // ── Story (1080x1920) ─────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_story', name: 'Story / Status', category: 'story',
    canvasWidth: 1080, canvasHeight: 1920, background: '#e11d48',
    previewColors: [Color(0xFFe11d48), Color(0xFFfff1f2)],
    elements: [
      CanvasElement(id: 'top_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 400, fill: '#fff1f2'),
      CanvasElement(id: 'headline', type: 'text', text: 'HOT DEAL', x: 40, y: 120, width: 1000, fontSize: 72, fontWeight: 'bold', fontFamily: 'Inter', fill: '#e11d48', align: 'center'),
      CanvasElement(id: 'subheadline', type: 'text', text: "Don't Miss Out!", x: 40, y: 220, width: 1000, fontSize: 36, fontFamily: 'Poppins', fill: '#e11d48', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 480, width: 900, height: 700, cornerRadius: 24),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 1230, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 1300, width: 1000, fontSize: 72, fontWeight: 'bold', fontFamily: 'Inter', fill: '#fff1f2', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 240, y: 1440, width: 600, height: 100, fill: '#fff1f2', cornerRadius: 50),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SWIPE UP', x: 240, y: 1468, width: 600, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#e11d48', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1620, width: 1000, fontSize: 28, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.8),
    ],
  ),

  // ── Premium / Minimal (1080x1080) ─────────────────────────────────────
  AdTemplate(
    id: 'tpl_minimal', name: 'Premium Clean', category: 'minimal',
    canvasWidth: 1080, canvasHeight: 1080, background: '#fafafa',
    previewColors: [Color(0xFFfafafa), Color(0xFF1e293b)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 80, width: 900, height: 560, cornerRadius: 12),
      CanvasElement(id: 'product_name', type: 'text', text: 'Product Name', x: 40, y: 680, width: 1000, fontSize: 44, fontWeight: '600', fontFamily: 'Playfair Display', fill: '#1e293b', align: 'center'),
      CanvasElement(id: 'selling', type: 'text', text: 'Crafted with care', x: 40, y: 745, width: 1000, fontSize: 22, fontFamily: 'Inter', fill: '#1e293b', align: 'center', opacity: 0.7),
      CanvasElement(id: 'divider', type: 'figure', x: 440, y: 800, width: 200, height: 2, fill: '#f97316', opacity: 0.3),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 830, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#f97316', align: 'center'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Shop Now →', x: 40, y: 920, width: 1000, fontSize: 24, fontWeight: '600', fontFamily: 'Inter', fill: '#1e293b', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1000, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#1e293b', align: 'center', opacity: 0.5),
    ],
  ),

  // ── WhatsApp (800x800) ────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_whatsapp', name: 'WhatsApp Ready', category: 'whatsapp',
    canvasWidth: 800, canvasHeight: 800, background: '#075e54',
    previewColors: [Color(0xFF075e54), Color(0xFFdcf8c6)],
    elements: [
      CanvasElement(id: 'inner_box', type: 'figure', x: 40, y: 40, width: 720, height: 720, fill: '#ffffff', cornerRadius: 16),
      CanvasElement(id: 'headline', type: 'text', text: 'ORDER ON', x: 40, y: 70, width: 720, fontSize: 24, fontWeight: 'bold', fontFamily: 'Inter', fill: '#075e54', align: 'center', opacity: 0.9),
      CanvasElement(id: 'headline2', type: 'text', text: 'WHATSAPP', x: 40, y: 100, width: 720, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#25d366', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 100, y: 160, width: 600, height: 340, cornerRadius: 12),
      CanvasElement(id: 'product_name', type: 'text', text: 'Product Name', x: 40, y: 530, width: 720, fontSize: 28, fontWeight: '600', fontFamily: 'Inter', fill: '#1f2937', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 75,000', x: 40, y: 580, width: 720, fontSize: 40, fontWeight: 'bold', fontFamily: 'Inter', fill: '#25d366', align: 'center'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Tap to Order →', x: 40, y: 660, width: 720, fontSize: 22, fontWeight: '600', fontFamily: 'Inter', fill: '#075e54', align: 'center'),
    ],
  ),

  // ── Book Now (1080x1080) ──────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_booking', name: 'Book Now', category: 'booking',
    canvasWidth: 1080, canvasHeight: 1080, background: '#1e40af',
    previewColors: [Color(0xFF1e40af), Color(0xFFdbeafe)],
    elements: [
      CanvasElement(id: 'accent_top', type: 'figure', x: 0, y: 0, width: 1080, height: 8, fill: '#dbeafe'),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 340, y: 40, width: 400, height: 44, fill: '#dbeafe', cornerRadius: 22),
      CanvasElement(id: 'badge_text', type: 'text', text: 'PROFESSIONAL SERVICE', x: 340, y: 50, width: 400, fontSize: 16, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1e40af', align: 'center'),
      CanvasElement(id: 'headline', type: 'text', text: 'BOOK TODAY', x: 40, y: 110, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 200, width: 800, height: 440, cornerRadius: 20),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 680, width: 1000, fontSize: 38, fontWeight: '600', fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 740, width: 1000, fontSize: 48, fontWeight: 'bold', fontFamily: 'Inter', fill: '#dbeafe', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 290, y: 830, width: 500, height: 80, fill: '#dbeafe', cornerRadius: 40),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BOOK NOW', x: 290, y: 850, width: 500, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1e40af', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Collection / Catalog (1080x1350) ──────────────────────────────────
  AdTemplate(
    id: 'tpl_catalog', name: 'Collection', category: 'catalog',
    canvasWidth: 1080, canvasHeight: 1350, background: '#111827',
    previewColors: [Color(0xFF111827), Color(0xFF6366f1)],
    elements: [
      CanvasElement(id: 'top_band', type: 'figure', x: 0, y: 0, width: 1080, height: 6, fill: '#6366f1'),
      CanvasElement(id: 'cat_bg', type: 'figure', x: 60, y: 40, width: 280, height: 40, fill: '#6366f1', cornerRadius: 20),
      CanvasElement(id: 'cat_text', type: 'text', text: 'FEATURED', x: 60, y: 48, width: 280, fontSize: 16, fontWeight: 'bold', fontFamily: 'Inter', fill: '#111827', align: 'center'),
      CanvasElement(id: 'headline', type: 'text', text: 'TOP PICK', x: 60, y: 105, width: 960, fontSize: 48, fontWeight: 'bold', fontFamily: 'Inter', fill: '#f9fafb', align: 'left'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 190, width: 960, height: 640, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 870, width: 960, fontSize: 40, fontWeight: '600', fontFamily: 'Poppins', fill: '#f9fafb', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 60, y: 940, width: 960, height: 2, fill: '#f9fafb', opacity: 0.2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 60, y: 970, width: 500, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#6366f1', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 620, y: 970, width: 400, height: 70, fill: '#6366f1', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 620, y: 988, width: 400, fontSize: 24, fontWeight: 'bold', fontFamily: 'Inter', fill: '#111827', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1100, width: 960, fontSize: 18, fontFamily: 'Inter', fill: '#f9fafb', align: 'left', opacity: 0.6),
    ],
  ),

  // ── Instagram Gradient (1080x1080) ────────────────────────────────────
  AdTemplate(
    id: 'tpl_instagram', name: 'Instagram', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#833ab4',
    previewColors: [Color(0xFFfd1d1d), Color(0xFF833ab4)],
    elements: [
      CanvasElement(id: 'bg_gradient', type: 'figure', x: 0, y: 0, width: 1080, height: 540, fill: '#fd1d1d', opacity: 0.4),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 190, y: 60, width: 700, height: 500, cornerRadius: 24),
      CanvasElement(id: 'headline', type: 'text', text: 'HOT NOW', x: 40, y: 590, width: 1000, fontSize: 68, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 680, width: 960, fontSize: 34, fontWeight: '600', fontFamily: 'Poppins', fill: '#ffffff', align: 'center', opacity: 0.9),
      CanvasElement(id: 'price_bg', type: 'figure', x: 280, y: 750, width: 520, height: 80, fill: '#ffffff', cornerRadius: 40),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 280, y: 768, width: 520, fontSize: 40, fontWeight: 'bold', fontFamily: 'Inter', fill: '#833ab4', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 870, width: 400, height: 65, fill: '#fccc63', cornerRadius: 32),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 340, y: 886, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: '#833ab4', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1000, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Dark Luxury (1080x1080) ───────────────────────────────────────────
  AdTemplate(
    id: 'tpl_luxury', name: 'Dark Luxury', category: 'minimal',
    canvasWidth: 1080, canvasHeight: 1080, background: '#0a0a0a',
    previewColors: [Color(0xFF0a0a0a), Color(0xFFc9a96e)],
    elements: [
      CanvasElement(id: 'gold_line_top', type: 'figure', x: 100, y: 60, width: 880, height: 1, fill: '#c9a96e', opacity: 0.5),
      CanvasElement(id: 'headline', type: 'text', text: 'EXCLUSIVE', x: 40, y: 80, width: 1000, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#c9a96e', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 150, width: 800, height: 520, cornerRadius: 8),
      CanvasElement(id: 'product_name', type: 'text', text: 'Product Name', x: 60, y: 710, width: 960, fontSize: 42, fontWeight: '600', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'selling', type: 'text', text: 'Premium Collection', x: 60, y: 775, width: 960, fontSize: 20, fontFamily: 'Inter', fill: '#c9a96e', align: 'center'),
      CanvasElement(id: 'gold_line_mid', type: 'figure', x: 380, y: 820, width: 320, height: 1, fill: '#c9a96e', opacity: 0.6),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 850, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#c9a96e', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 300, y: 940, width: 480, height: 65, fill: '#c9a96e', cornerRadius: 4),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 300, y: 955, width: 480, fontSize: 24, fontWeight: 'bold', fontFamily: 'Inter', fill: '#0a0a0a', align: 'center'),
      CanvasElement(id: 'gold_line_bottom', type: 'figure', x: 100, y: 1040, width: 880, height: 1, fill: '#c9a96e', opacity: 0.5),
    ],
  ),

  // ── Bold Geometric (1080x1080) ────────────────────────────────────────
  AdTemplate(
    id: 'tpl_geometric', name: 'Bold Geometric', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#1a1a2e',
    previewColors: [Color(0xFF1a1a2e), Color(0xFFe94560)],
    elements: [
      CanvasElement(id: 'shape1', type: 'figure', x: 0, y: 0, width: 540, height: 200, fill: '#e94560'),
      CanvasElement(id: 'shape2', type: 'figure', x: 540, y: 0, width: 540, height: 120, fill: '#0f3460'),
      CanvasElement(id: 'headline', type: 'text', text: 'BIG SALE', x: 40, y: 40, width: 480, fontSize: 72, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'left'),
      CanvasElement(id: 'discount_bg', type: 'figure', x: 600, y: 30, width: 200, height: 60, fill: '#e94560', cornerRadius: 8),
      CanvasElement(id: 'discount', type: 'text', text: '-50%', x: 600, y: 42, width: 200, fontSize: 32, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 230, width: 960, height: 480, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 740, width: 650, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'left'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 800, width: 650, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#e94560', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 40, y: 890, width: 350, height: 70, fill: '#e94560', cornerRadius: 12),
      CanvasElement(id: 'cta_text', type: 'text', text: 'GRAB IT', x: 40, y: 907, width: 350, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'shape3', type: 'figure', x: 750, y: 880, width: 280, height: 180, fill: '#0f3460', cornerRadius: 16),
      CanvasElement(id: 'qr_hint', type: 'text', text: '{{CTA_LINK}}', x: 750, y: 950, width: 280, fontSize: 22, fontWeight: '600', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
    ],
  ),

  // ── Colorful Pop (1080x1350) ──────────────────────────────────────────
  AdTemplate(
    id: 'tpl_colorpop', name: 'Colorful Pop', category: 'new',
    canvasWidth: 1080, canvasHeight: 1350, background: '#fef3c7',
    previewColors: [Color(0xFFfef3c7), Color(0xFFf97316)],
    elements: [
      CanvasElement(id: 'circle1', type: 'figure', x: -100, y: -100, width: 400, height: 400, fill: '#fb923c', cornerRadius: 200),
      CanvasElement(id: 'circle2', type: 'figure', x: 780, y: 1050, width: 400, height: 400, fill: '#f87171', cornerRadius: 200),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 60, y: 60, width: 200, height: 50, fill: '#f97316', cornerRadius: 25),
      CanvasElement(id: 'badge_text', type: 'text', text: 'NEW IN', x: 60, y: 70, width: 200, fontSize: 22, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 160, width: 900, height: 600, cornerRadius: 24),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 800, width: 960, fontSize: 44, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1e293b', align: 'left'),
      CanvasElement(id: 'selling', type: 'text', text: 'Trending now!', x: 60, y: 865, width: 960, fontSize: 24, fontFamily: 'Poppins', fill: '#f97316', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 60, y: 920, width: 200, height: 4, fill: '#f97316', cornerRadius: 2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 60, y: 950, width: 600, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1e293b', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 60, y: 1050, width: 400, height: 80, fill: '#f97316', cornerRadius: 16),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 60, y: 1070, width: 400, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1200, width: 960, fontSize: 20, fontFamily: 'Inter', fill: '#1e293b', align: 'left', opacity: 0.4),
    ],
  ),

  // ── Food & Restaurant (1080x1080) ────────────────────────────────────
  AdTemplate(
    id: 'tpl_food', name: 'Food Special', category: 'food',
    canvasWidth: 1080, canvasHeight: 1080, background: '#1c1207',
    previewColors: [Color(0xFF1c1207), Color(0xFFf59e0b)],
    elements: [
      CanvasElement(id: 'top_stripe', type: 'figure', x: 0, y: 0, width: 1080, height: 8, fill: '#f59e0b'),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 40, y: 30, width: 220, height: 55, fill: '#f59e0b', cornerRadius: 8),
      CanvasElement(id: 'badge_text', type: 'text', text: "TODAY'S SPECIAL", x: 40, y: 42, width: 220, fontSize: 18, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#1c1207', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 120, width: 960, height: 560, cornerRadius: 20),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 720, width: 1000, fontSize: 48, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#ffffff', align: 'left'),
      CanvasElement(id: 'subtitle', type: 'text', text: 'Fresh · Delicious · Quality', x: 40, y: 782, width: 700, fontSize: 20, fontFamily: 'Lato', fill: '#f59e0b', align: 'left'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 75,000', x: 40, y: 860, width: 600, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#f59e0b', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 700, y: 860, width: 340, height: 80, fill: '#f59e0b', cornerRadius: 40),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ORDER', x: 700, y: 880, width: 340, fontSize: 30, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#1c1207', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 18, fontFamily: 'Lato', fill: '#ffffff', align: 'center', opacity: 0.4),
      CanvasElement(id: 'bottom_stripe', type: 'figure', x: 0, y: 1072, width: 1080, height: 8, fill: '#f59e0b'),
    ],
  ),

  // ── Fashion (1080x1350 Portrait) ──────────────────────────────────────
  AdTemplate(
    id: 'tpl_fashion', name: 'Fashion Drop', category: 'fashion',
    canvasWidth: 1080, canvasHeight: 1350, background: '#f8f4f0',
    previewColors: [Color(0xFFf8f4f0), Color(0xFF1a1a1a)],
    elements: [
      CanvasElement(id: 'sidebar', type: 'figure', x: 0, y: 0, width: 60, height: 1350, fill: '#1a1a1a'),
      CanvasElement(id: 'label_bg', type: 'figure', x: 100, y: 60, width: 180, height: 40, fill: '#1a1a1a', cornerRadius: 0),
      CanvasElement(id: 'label', type: 'text', text: 'NEW SEASON', x: 100, y: 68, width: 180, fontSize: 16, fontWeight: 'bold', fontFamily: 'Raleway', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'headline', type: 'text', text: 'PRODUCT\nNAME', x: 100, y: 130, width: 900, fontSize: 80, fontWeight: 'bold', fontFamily: 'Montserrat', fill: '#1a1a1a', align: 'left'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 100, y: 370, width: 880, height: 680, cornerRadius: 4),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 100, y: 1090, width: 500, fontSize: 44, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1a1a1a', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 100, y: 1170, width: 340, height: 70, fill: '#1a1a1a', cornerRadius: 0),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP THE LOOK', x: 100, y: 1188, width: 340, fontSize: 20, fontWeight: 'bold', fontFamily: 'Raleway', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 100, y: 1280, width: 880, fontSize: 18, fontFamily: 'Raleway', fill: '#1a1a1a', align: 'right', opacity: 0.35),
    ],
  ),

  // ── Real Estate (1080x1080) ───────────────────────────────────────────
  AdTemplate(
    id: 'tpl_realestate', name: 'Property Listing', category: 'realestate',
    canvasWidth: 1080, canvasHeight: 1080, background: '#0f172a',
    previewColors: [Color(0xFF0f172a), Color(0xFFd4af37)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 580, cornerRadius: 0),
      CanvasElement(id: 'image_overlay', type: 'figure', x: 0, y: 380, width: 1080, height: 200, fill: '#0f172a', cornerRadius: 0, opacity: 0.6),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 40, y: 40, width: 160, height: 48, fill: '#d4af37', cornerRadius: 6),
      CanvasElement(id: 'badge_text', type: 'text', text: 'FOR SALE', x: 40, y: 52, width: 160, fontSize: 20, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#0f172a', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 200,000', x: 40, y: 610, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#d4af37', align: 'left'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 680, width: 800, fontSize: 36, fontWeight: '600', fontFamily: 'Merriweather', fill: '#ffffff', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 40, y: 750, width: 120, height: 3, fill: '#d4af37', cornerRadius: 2),
      CanvasElement(id: 'details', type: 'text', text: 'Premium Quality  ·  Fast Delivery', x: 40, y: 780, width: 900, fontSize: 22, fontFamily: 'Lato', fill: '#94a3b8', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 40, y: 870, width: 380, height: 75, fill: '#d4af37', cornerRadius: 12),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ENQUIRE NOW', x: 40, y: 892, width: 380, fontSize: 26, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#0f172a', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 18, fontFamily: 'Lato', fill: '#94a3b8', align: 'right'),
    ],
  ),

  // ── Health & Beauty (1080x1080) ───────────────────────────────────────
  AdTemplate(
    id: 'tpl_beauty', name: 'Beauty & Wellness', category: 'beauty',
    canvasWidth: 1080, canvasHeight: 1080, background: '#fdf2f8',
    previewColors: [Color(0xFFfdf2f8), Color(0xFFbe185d)],
    elements: [
      CanvasElement(id: 'top_accent', type: 'figure', x: 0, y: 0, width: 1080, height: 6, fill: '#be185d'),
      CanvasElement(id: 'headline', type: 'text', text: 'BEAUTY ESSENTIALS', x: 40, y: 40, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Playfair Display', fill: '#be185d', align: 'center'),
      CanvasElement(id: 'subline', type: 'text', text: 'Glow · Shine · Radiate', x: 40, y: 100, width: 1000, fontSize: 22, fontFamily: 'Raleway', fill: '#9d174d', align: 'center'),
      CanvasElement(id: 'circle_bg', type: 'figure', x: 140, y: 160, width: 800, height: 800, fill: '#fce7f3', cornerRadius: 400),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 170, width: 800, height: 500, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 720, width: 1000, fontSize: 38, fontWeight: '600', fontFamily: 'Playfair Display', fill: '#1f2937', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 790, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#be185d', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 290, y: 880, width: 500, height: 80, fill: '#be185d', cornerRadius: 40),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 290, y: 900, width: 500, fontSize: 28, fontWeight: 'bold', fontFamily: 'Raleway', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 18, fontFamily: 'Raleway', fill: '#be185d', align: 'center', opacity: 0.5),
      CanvasElement(id: 'bottom_accent', type: 'figure', x: 0, y: 1074, width: 1080, height: 6, fill: '#be185d'),
    ],
  ),

  // ── Services / Barbershop (1080x1080) ─────────────────────────────────
  AdTemplate(
    id: 'tpl_service_bold', name: 'Services Bold', category: 'service',
    canvasWidth: 1080, canvasHeight: 1080, background: '#111111',
    previewColors: [Color(0xFF111111), Color(0xFFFFD700)],
    elements: [
      CanvasElement(id: 'gold_corner', type: 'figure', x: 0, y: 0, width: 300, height: 8, fill: '#FFD700'),
      CanvasElement(id: 'gold_corner2', type: 'figure', x: 0, y: 0, width: 8, height: 300, fill: '#FFD700'),
      CanvasElement(id: 'gold_corner3', type: 'figure', x: 780, y: 1072, width: 300, height: 8, fill: '#FFD700'),
      CanvasElement(id: 'gold_corner4', type: 'figure', x: 1072, y: 780, width: 8, height: 300, fill: '#FFD700'),
      CanvasElement(id: 'headline', type: 'text', text: 'BOOK NOW', x: 40, y: 60, width: 1000, fontSize: 80, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#FFD700', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 200, width: 920, height: 520, cornerRadius: 4),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 760, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'tagline', type: 'text', text: 'Professional · Expert · Trusted', x: 40, y: 825, width: 1000, fontSize: 20, fontFamily: 'Lato', fill: '#FFD700', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'FROM UGX 75,000', x: 40, y: 880, width: 1000, fontSize: 32, fontWeight: '600', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 290, y: 950, width: 500, height: 80, fill: '#FFD700', cornerRadius: 0),
      CanvasElement(id: 'cta_text', type: 'text', text: 'CALL / WHATSAPP', x: 290, y: 970, width: 500, fontSize: 24, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#111111', align: 'center'),
    ],
  ),

  // ── Electronics / Tech (1080x1080) ───────────────────────────────────
  AdTemplate(
    id: 'tpl_tech', name: 'Tech Product', category: 'tech',
    canvasWidth: 1080, canvasHeight: 1080, background: '#030712',
    previewColors: [Color(0xFF030712), Color(0xFF3b82f6)],
    elements: [
      CanvasElement(id: 'glow_orb', type: 'figure', x: 330, y: 80, width: 420, height: 420, fill: '#1d4ed8', cornerRadius: 210, opacity: 0.25),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 80, width: 900, height: 520, cornerRadius: 24),
      CanvasElement(id: 'tag_bg', type: 'figure', x: 40, y: 40, width: 140, height: 44, fill: '#3b82f6', cornerRadius: 22),
      CanvasElement(id: 'tag', type: 'text', text: 'FEATURED', x: 40, y: 50, width: 140, fontSize: 16, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 640, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Montserrat', fill: '#ffffff', align: 'left'),
      CanvasElement(id: 'spec_line', type: 'text', text: 'Pro Performance  ·  Free Delivery', x: 40, y: 700, width: 800, fontSize: 20, fontFamily: 'Inter', fill: '#93c5fd', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 40, y: 745, width: 60, height: 3, fill: '#3b82f6', cornerRadius: 2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 40, y: 770, width: 700, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#3b82f6', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 40, y: 870, width: 360, height: 80, fill: '#3b82f6', cornerRadius: 16),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BUY NOW', x: 40, y: 890, width: 360, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1015, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#4b5563', align: 'right'),
    ],
  ),

  // ── Gradient Story (1080x1920) ────────────────────────────────────────
  AdTemplate(
    id: 'tpl_gradient_story', name: 'Gradient Story', category: 'story',
    canvasWidth: 1080, canvasHeight: 1920, background: '#6d28d9',
    previewColors: [Color(0xFF6d28d9), Color(0xFFec4899)],
    elements: [
      CanvasElement(id: 'grad1', type: 'figure', x: 0, y: 0, width: 1080, height: 960, fill: '#6d28d9', cornerRadius: 0),
      CanvasElement(id: 'grad2', type: 'figure', x: 0, y: 960, width: 1080, height: 960, fill: '#db2777', cornerRadius: 0),
      CanvasElement(id: 'overlay', type: 'figure', x: 0, y: 0, width: 1080, height: 1920, fill: '#000000', cornerRadius: 0, opacity: 0.35),
      CanvasElement(id: 'headline', type: 'text', text: "DON'T MISS", x: 60, y: 120, width: 960, fontSize: 80, fontWeight: 'bold', fontFamily: 'Montserrat', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'This Amazing Deal', x: 60, y: 220, width: 960, fontSize: 44, fontFamily: 'Nunito', fill: '#fce7f3', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 360, width: 920, height: 820, cornerRadius: 32),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 1240, width: 960, fontSize: 52, fontWeight: 'bold', fontFamily: 'Montserrat', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 60, y: 1320, width: 960, fontSize: 72, fontWeight: 'bold', fontFamily: 'Inter', fill: '#fce7f3', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 190, y: 1450, width: 700, height: 100, fill: '#ffffff', cornerRadius: 50),
      CanvasElement(id: 'cta_text', type: 'text', text: 'TAP TO ORDER', x: 190, y: 1472, width: 700, fontSize: 34, fontWeight: 'bold', fontFamily: 'Montserrat', fill: '#6d28d9', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1630, width: 960, fontSize: 28, fontFamily: 'Nunito', fill: '#ffffff', align: 'center', opacity: 0.7),
    ],
  ),

  // ── Business Professional (1080x1080) ─────────────────────────────────
  AdTemplate(
    id: 'tpl_professional', name: 'Professional', category: 'professional',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFffffff), Color(0xFF1d4ed8)],
    elements: [
      CanvasElement(id: 'left_panel', type: 'figure', x: 0, y: 0, width: 380, height: 1080, fill: '#1d4ed8'),
      CanvasElement(id: 'brand', type: 'text', text: 'SOKO 24', x: 0, y: 60, width: 380, fontSize: 24, fontWeight: 'bold', fontFamily: 'Raleway', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'vertical_text', type: 'text', text: 'QUALITY', x: 155, y: 500, width: 70, fontSize: 16, fontWeight: 'bold', fontFamily: 'Raleway', fill: '#93c5fd', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 400, y: 60, width: 640, height: 500, cornerRadius: 8),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 420, y: 600, width: 620, fontSize: 36, fontWeight: 'bold', fontFamily: 'Merriweather', fill: '#1e293b', align: 'left'),
      CanvasElement(id: 'tagline', type: 'text', text: 'Trusted by thousands across Uganda', x: 420, y: 655, width: 620, fontSize: 18, fontFamily: 'Lato', fill: '#64748b', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 420, y: 700, width: 80, height: 3, fill: '#1d4ed8', cornerRadius: 2),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 120,000', x: 420, y: 730, width: 620, fontSize: 44, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1d4ed8', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 420, y: 830, width: 300, height: 70, fill: '#1d4ed8', cornerRadius: 8),
      CanvasElement(id: 'cta_text', type: 'text', text: 'GET YOURS', x: 420, y: 848, width: 300, fontSize: 24, fontWeight: 'bold', fontFamily: 'Raleway', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 420, y: 960, width: 620, fontSize: 18, fontFamily: 'Raleway', fill: '#64748b', align: 'right'),
    ],
  ),

  // ── WhatsApp Green (800x800) ──────────────────────────────────────────
  AdTemplate(
    id: 'tpl_whatsapp2', name: 'WhatsApp Business', category: 'whatsapp',
    canvasWidth: 800, canvasHeight: 800, background: '#075e54',
    previewColors: [Color(0xFF075e54), Color(0xFF25d366)],
    elements: [
      CanvasElement(id: 'header_bg', type: 'figure', x: 0, y: 0, width: 800, height: 100, fill: '#128c7e'),
      CanvasElement(id: 'header_text', type: 'text', text: '🛍️ Special Offer for You!', x: 20, y: 28, width: 760, fontSize: 28, fontWeight: 'bold', fontFamily: 'Nunito', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 130, width: 680, height: 340, cornerRadius: 12),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 30, y: 500, width: 740, fontSize: 32, fontWeight: 'bold', fontFamily: 'Nunito', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price_badge', type: 'figure', x: 200, y: 555, width: 400, height: 60, fill: '#25d366', cornerRadius: 30),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 200, y: 568, width: 400, fontSize: 30, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'details', type: 'text', text: '✅ Free Delivery  ·  ✅ Quality Guaranteed', x: 30, y: 640, width: 740, fontSize: 18, fontFamily: 'Nunito', fill: '#d1fae5', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: 'Reply to ORDER  ·  soko24.co', x: 30, y: 700, width: 740, fontSize: 20, fontWeight: '600', fontFamily: 'Nunito', fill: '#25d366', align: 'center'),
    ],
  ),

  // ── Luxury Black Gold (1080x1080) ─────────────────────────────────────
  AdTemplate(
    id: 'tpl_luxury_gold', name: 'Dark Luxury', category: 'luxury',
    canvasWidth: 1080, canvasHeight: 1080, background: '#080808',
    previewColors: [Color(0xFF080808), Color(0xFFd4af37)],
    elements: [
      CanvasElement(id: 'frame_tl', type: 'figure', x: 30, y: 30, width: 120, height: 3, fill: '#d4af37'),
      CanvasElement(id: 'frame_tl2', type: 'figure', x: 30, y: 30, width: 3, height: 120, fill: '#d4af37'),
      CanvasElement(id: 'frame_br', type: 'figure', x: 930, y: 1047, width: 120, height: 3, fill: '#d4af37'),
      CanvasElement(id: 'frame_br2', type: 'figure', x: 1047, y: 930, width: 3, height: 120, fill: '#d4af37'),
      CanvasElement(id: 'headline', type: 'text', text: 'LUXURY COLLECTION', x: 40, y: 70, width: 1000, fontSize: 28, fontWeight: '300', fontFamily: 'Raleway', fill: '#d4af37', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 130, width: 920, height: 560, cornerRadius: 0),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 730, width: 1000, fontSize: 40, fontWeight: '300', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'divider_left', type: 'figure', x: 340, y: 790, width: 140, height: 1, fill: '#d4af37'),
      CanvasElement(id: 'divider_right', type: 'figure', x: 600, y: 790, width: 140, height: 1, fill: '#d4af37'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 200,000', x: 40, y: 820, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Inter', fill: '#d4af37', align: 'center'),
      CanvasElement(id: 'cta_text', type: 'text', text: '⸻ ENQUIRE NOW ⸻', x: 40, y: 920, width: 1000, fontSize: 20, fontWeight: '500', fontFamily: 'Raleway', fill: '#d4af37', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 16, fontFamily: 'Raleway', fill: '#d4af37', align: 'center', opacity: 0.4),
    ],
  ),

  // ── Grand Opening (1080x1080) ────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_grand_opening', name: 'Grand Opening', category: 'grand',
    canvasWidth: 1080, canvasHeight: 1080, background: '#7c2d12',
    previewColors: [Color(0xFF7c2d12), Color(0xFFfbbf24)],
    elements: [
      CanvasElement(id: 'confetti1', type: 'figure', x: 0, y: 0, width: 1080, height: 12, fill: '#fbbf24'),
      CanvasElement(id: 'confetti2', type: 'figure', x: 0, y: 1068, width: 1080, height: 12, fill: '#fbbf24'),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 290, y: 60, width: 500, height: 70, fill: '#fbbf24', cornerRadius: 35),
      CanvasElement(id: 'badge_text', type: 'text', text: '🎉 GRAND OPENING', x: 290, y: 77, width: 500, fontSize: 26, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#7c2d12', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 175, width: 920, height: 500, cornerRadius: 20),
      CanvasElement(id: 'business_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 715, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Bebas Neue', fill: '#fbbf24', align: 'center'),
      CanvasElement(id: 'tagline', type: 'text', text: 'We are officially open! Come visit us today.', x: 40, y: 790, width: 1000, fontSize: 22, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 870, width: 400, height: 75, fill: '#fbbf24', cornerRadius: 37),
      CanvasElement(id: 'cta_text', type: 'text', text: 'VISIT US TODAY', x: 340, y: 890, width: 400, fontSize: 24, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#7c2d12', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1000, width: 1000, fontSize: 18, fontFamily: 'Inter', fill: '#fbbf24', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Minimal White (1080x1080) ─────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_minimal_white', name: 'Minimal White', category: 'minimal',
    canvasWidth: 1080, canvasHeight: 1080, background: '#ffffff',
    previewColors: [Color(0xFFffffff), Color(0xFF111111)],
    elements: [
      CanvasElement(id: 'accent_line', type: 'figure', x: 80, y: 100, width: 4, height: 880, fill: '#111111'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 100, width: 860, height: 580, cornerRadius: 0),
      CanvasElement(id: 'category', type: 'text', text: 'FEATURED', x: 140, y: 720, width: 860, fontSize: 14, fontWeight: '600', fontFamily: 'Inter', fill: '#999999', align: 'left'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 140, y: 760, width: 860, fontSize: 48, fontWeight: '800', fontFamily: 'Inter', fill: '#111111', align: 'left'),
      CanvasElement(id: 'divider', type: 'figure', x: 140, y: 840, width: 200, height: 2, fill: '#111111'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 140, y: 870, width: 400, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#111111', align: 'left'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 140, y: 960, width: 860, fontSize: 16, fontFamily: 'Inter', fill: '#999999', align: 'right'),
    ],
  ),

  // ── Free Delivery (1080x1080) ─────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_free_delivery', name: 'Free Delivery', category: 'delivery',
    canvasWidth: 1080, canvasHeight: 1080, background: '#0f766e',
    previewColors: [Color(0xFF0f766e), Color(0xFFffffff)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 680, cornerRadius: 0),
      CanvasElement(id: 'image_overlay', type: 'figure', x: 0, y: 520, width: 1080, height: 200, fill: '#0f766e', cornerRadius: 0, opacity: 0.7),
      CanvasElement(id: 'delivery_badge', type: 'figure', x: 40, y: 40, width: 220, height: 60, fill: '#ffffff', cornerRadius: 30),
      CanvasElement(id: 'delivery_text', type: 'text', text: '🚚 FREE DELIVERY', x: 40, y: 58, width: 220, fontSize: 18, fontWeight: 'bold', fontFamily: 'Inter', fill: '#0f766e', align: 'center'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 720, width: 1000, fontSize: 48, fontWeight: 'bold', fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 800, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'sub', type: 'text', text: 'Free delivery within Kampala • Order now', x: 40, y: 880, width: 1000, fontSize: 20, fontFamily: 'Lato', fill: '#ffffff', align: 'center', opacity: 0.85),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 940, width: 400, height: 70, fill: '#ffffff', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'WA: {{WHATSAPP}}', x: 340, y: 958, width: 400, fontSize: 20, fontWeight: 'bold', fontFamily: 'Inter', fill: '#0f766e', align: 'center'),
    ],
  ),

  // ── Limited Stock (1080x1080) ─────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_limited_stock', name: 'Limited Stock', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#1c1c1c',
    previewColors: [Color(0xFF1c1c1c), Color(0xFFef4444)],
    elements: [
      CanvasElement(id: 'urgent_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 80, fill: '#ef4444'),
      CanvasElement(id: 'urgent_text', type: 'text', text: '⚠️  LIMITED STOCK — HURRY!', x: 40, y: 22, width: 1000, fontSize: 28, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 120, y: 120, width: 840, height: 500, cornerRadius: 12),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 660, width: 1000, fontSize: 42, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'stock_badge', type: 'figure', x: 390, y: 730, width: 300, height: 55, fill: '#ef4444', cornerRadius: 8),
      CanvasElement(id: 'stock_text', type: 'text', text: 'Only 5 left in stock!', x: 390, y: 746, width: 300, fontSize: 20, fontWeight: '600', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 820, width: 1000, fontSize: 60, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ef4444', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: 'Get it before it runs out • soko24.co', x: 40, y: 1010, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Event Invite (1080x1350) ──────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_event', name: 'Event Invite', category: 'event',
    canvasWidth: 1080, canvasHeight: 1350, background: '#1e1b4b',
    previewColors: [Color(0xFF1e1b4b), Color(0xFFa78bfa)],
    elements: [
      CanvasElement(id: 'glow1', type: 'figure', x: -100, y: -100, width: 500, height: 500, fill: '#7c3aed', cornerRadius: 250, opacity: 0.2),
      CanvasElement(id: 'glow2', type: 'figure', x: 700, y: 900, width: 400, height: 400, fill: '#ec4899', cornerRadius: 200, opacity: 0.15),
      CanvasElement(id: 'event_label', type: 'text', text: '✦  YOU ARE INVITED  ✦', x: 40, y: 80, width: 1000, fontSize: 20, fontWeight: '600', fontFamily: 'Raleway', fill: '#a78bfa', align: 'center'),
      CanvasElement(id: 'event_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 140, width: 1000, fontSize: 72, fontWeight: '800', fontFamily: 'Syne', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'divider', type: 'figure', x: 440, y: 260, width: 200, height: 2, fill: '#a78bfa'),
      CanvasElement(id: 'event_image', type: 'image', src: '', x: 80, y: 300, width: 920, height: 620, cornerRadius: 24),
      CanvasElement(id: 'date_bg', type: 'figure', x: 240, y: 960, width: 600, height: 80, fill: '#7c3aed', cornerRadius: 12),
      CanvasElement(id: 'date_text', type: 'text', text: '📅  Saturday, 1 June 2025', x: 240, y: 980, width: 600, fontSize: 22, fontWeight: '700', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'location', type: 'text', text: '📍  Kampala, Uganda', x: 40, y: 1080, width: 1000, fontSize: 22, fontFamily: 'Inter', fill: '#a78bfa', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 1150, width: 400, height: 70, fill: '#a78bfa', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'RSVP NOW', x: 340, y: 168, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#1e1b4b', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1270, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#a78bfa', align: 'center', opacity: 0.5),
    ],
  ),

  // ── Health & Wellness (1080x1080) ────────────────────────────────────────
  AdTemplate(
    id: 'tpl_health', name: 'Health & Wellness', category: 'health',
    canvasWidth: 1080, canvasHeight: 1080, background: '#f0fdf4',
    previewColors: [Color(0xFFf0fdf4), Color(0xFF16a34a)],
    elements: [
      CanvasElement(id: 'leaf1', type: 'figure', x: -60, y: -60, width: 250, height: 250, fill: '#bbf7d0', cornerRadius: 125, opacity: 0.5),
      CanvasElement(id: 'leaf2', type: 'figure', x: 900, y: 880, width: 200, height: 200, fill: '#bbf7d0', cornerRadius: 100, opacity: 0.4),
      CanvasElement(id: 'badge_bg', type: 'figure', x: 40, y: 60, width: 200, height: 50, fill: '#16a34a', cornerRadius: 10),
      CanvasElement(id: 'badge_text', type: 'text', text: '🌿 NATURAL', x: 40, y: 73, width: 200, fontSize: 20, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 150, width: 920, height: 520, cornerRadius: 24),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 710, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Plus Jakarta Sans', fill: '#14532d', align: 'center'),
      CanvasElement(id: 'benefit', type: 'text', text: '100% Natural  •  No Chemicals  •  Results Guaranteed', x: 40, y: 780, width: 1000, fontSize: 18, fontFamily: 'Lato', fill: '#16a34a', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 840, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#14532d', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 930, width: 400, height: 70, fill: '#16a34a', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'ORDER NOW', x: 340, y: 948, width: 400, fontSize: 24, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
    ],
  ),

  // ── Farm Fresh (1080x1080) ────────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_agri', name: 'Farm Fresh', category: 'agri',
    canvasWidth: 1080, canvasHeight: 1080, background: '#451a03',
    previewColors: [Color(0xFF451a03), Color(0xFF84cc16)],
    elements: [
      CanvasElement(id: 'soil_strip', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: '#451a03'),
      CanvasElement(id: 'green_strip', type: 'figure', x: 0, y: 0, width: 1080, height: 120, fill: '#84cc16'),
      CanvasElement(id: 'headline', type: 'text', text: '🌱 FRESH FROM THE FARM', x: 40, y: 35, width: 1000, fontSize: 36, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#451a03', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 160, width: 920, height: 500, cornerRadius: 20),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 700, width: 1000, fontSize: 50, fontWeight: 'bold', fontFamily: 'Fjalla One', fill: '#84cc16', align: 'center'),
      CanvasElement(id: 'quality', type: 'text', text: 'Organically Grown  •  Direct from Farmers', x: 40, y: 775, width: 1000, fontSize: 20, fontFamily: 'Lato', fill: '#d9f99d', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 40, y: 840, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 930, width: 400, height: 70, fill: '#84cc16', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'BUY FRESH TODAY', x: 340, y: 948, width: 400, fontSize: 22, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#451a03', align: 'center'),
    ],
  ),

  // ── Weekend Sale (1080x1080) ──────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_weekend_sale', name: 'Weekend Sale', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#faf5ff',
    previewColors: [Color(0xFFfaf5ff), Color(0xFF7c3aed)],
    elements: [
      CanvasElement(id: 'big_circle', type: 'figure', x: 540, y: 0, width: 800, height: 800, fill: '#7c3aed', cornerRadius: 400, opacity: 0.08),
      CanvasElement(id: 'weekend_badge', type: 'figure', x: 0, y: 0, width: 1080, height: 90, fill: '#7c3aed'),
      CanvasElement(id: 'weekend_text', type: 'text', text: 'WEEKEND SALE  🔥  ENDS SUNDAY', x: 40, y: 25, width: 1000, fontSize: 32, fontWeight: 'bold', fontFamily: 'Barlow Condensed', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 100, y: 130, width: 880, height: 520, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 690, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Plus Jakarta Sans', fill: '#1e1b4b', align: 'center'),
      CanvasElement(id: 'was_price', type: 'text', text: 'Was UGX 150,000', x: 40, y: 760, width: 1000, fontSize: 22, fontFamily: 'Inter', fill: '#6b7280', align: 'center'),
      CanvasElement(id: 'now_price', type: 'text', text: 'NOW UGX 99,000', x: 40, y: 810, width: 1000, fontSize: 58, fontWeight: 'bold', fontFamily: 'Inter', fill: '#7c3aed', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 910, width: 400, height: 70, fill: '#7c3aed', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 340, y: 928, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1018, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#6b7280', align: 'center'),
    ],
  ),

  // ── Booking Card (1080x1080) ──────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_booking_session', name: 'Book a Session', category: 'booking',
    canvasWidth: 1080, canvasHeight: 1080, background: '#0c0a09',
    previewColors: [Color(0xFF0c0a09), Color(0xFFfbbf24)],
    elements: [
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 0, width: 1080, height: 700, cornerRadius: 0),
      CanvasElement(id: 'overlay', type: 'figure', x: 0, y: 0, width: 1080, height: 700, fill: '#000000', cornerRadius: 0, opacity: 0.45),
      CanvasElement(id: 'service_label', type: 'text', text: 'BOOK A SESSION', x: 40, y: 60, width: 1000, fontSize: 18, fontWeight: '600', fontFamily: 'Raleway', fill: '#fbbf24', align: 'center'),
      CanvasElement(id: 'service_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 120, width: 1000, fontSize: 64, fontWeight: 'bold', fontFamily: 'Cinzel', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'slots', type: 'text', text: 'Mon – Sat  •  9:00 AM – 6:00 PM', x: 40, y: 230, width: 1000, fontSize: 20, fontFamily: 'Lato', fill: '#fbbf24', align: 'center'),
      CanvasElement(id: 'price_bg', type: 'figure', x: 340, y: 280, width: 400, height: 70, fill: '#fbbf24', cornerRadius: 8),
      CanvasElement(id: 'price_text', type: 'text', text: 'From UGX 50,000', x: 340, y: 298, width: 400, fontSize: 22, fontWeight: 'bold', fontFamily: 'Inter', fill: '#0c0a09', align: 'center'),
      CanvasElement(id: 'bottom_box', type: 'figure', x: 0, y: 700, width: 1080, height: 380, fill: '#0c0a09'),
      CanvasElement(id: 'description', type: 'text', text: 'Professional service tailored just for you.', x: 40, y: 730, width: 1000, fontSize: 22, fontFamily: 'Raleway', fill: '#d6d3d1', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 240, y: 810, width: 600, height: 80, fill: '#fbbf24', cornerRadius: 40),
      CanvasElement(id: 'cta_text', type: 'text', text: 'WA: {{WHATSAPP}}', x: 240, y: 830, width: 600, fontSize: 28, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#0c0a09', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 940, width: 1000, fontSize: 18, fontFamily: 'Raleway', fill: '#fbbf24', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Daily Special (1080x1080) ─────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_daily_special', name: 'Daily Special', category: 'food',
    canvasWidth: 1080, canvasHeight: 1080, background: '#fff7ed',
    previewColors: [Color(0xFFfff7ed), Color(0xFFea580c)],
    elements: [
      CanvasElement(id: 'top_bar', type: 'figure', x: 0, y: 0, width: 1080, height: 100, fill: '#ea580c'),
      CanvasElement(id: 'day_text', type: 'text', text: '🍽️  TODAY\'S SPECIAL', x: 40, y: 30, width: 1000, fontSize: 32, fontWeight: 'bold', fontFamily: 'Staatliches', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 60, y: 140, width: 960, height: 560, cornerRadius: 20),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 745, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Staatliches', fill: '#431407', align: 'center'),
      CanvasElement(id: 'desc', type: 'text', text: 'Fresh · Made with love · Ready to serve', x: 40, y: 820, width: 1000, fontSize: 20, fontFamily: 'Pacifico', fill: '#ea580c', align: 'center'),
      CanvasElement(id: 'price_bg', type: 'figure', x: 390, y: 870, width: 300, height: 70, fill: '#ea580c', cornerRadius: 35),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 25,000', x: 390, y: 890, width: 300, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: 'Order now · soko24.co', x: 40, y: 990, width: 1000, fontSize: 16, fontFamily: 'Lato', fill: '#9a3412', align: 'center', opacity: 0.6),
    ],
  ),

  // ── Catalog Grid Story (1080x1350) ────────────────────────────────────────
  AdTemplate(
    id: 'tpl_catalog_story', name: 'Catalog Story', category: 'catalog',
    canvasWidth: 1080, canvasHeight: 1350, background: '#0a0a0a',
    previewColors: [Color(0xFF0a0a0a), Color(0xFFffffff)],
    elements: [
      CanvasElement(id: 'header_bg', type: 'figure', x: 0, y: 0, width: 1080, height: 120, fill: '#0a0a0a'),
      CanvasElement(id: 'brand_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 38, width: 1000, fontSize: 38, fontWeight: '800', fontFamily: 'Space Grotesk', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'divider', type: 'figure', x: 80, y: 115, width: 920, height: 1, fill: '#333333'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 0, y: 120, width: 1080, height: 820, cornerRadius: 0),
      CanvasElement(id: 'overlay', type: 'figure', x: 0, y: 700, width: 1080, height: 250, fill: '#000000', cornerRadius: 0, opacity: 0.65),
      CanvasElement(id: 'item_name', type: 'text', text: 'Collection Piece', x: 40, y: 730, width: 1000, fontSize: 48, fontWeight: '300', fontFamily: 'Raleway', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 120,000', x: 40, y: 800, width: 1000, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer_bg', type: 'figure', x: 0, y: 940, width: 1080, height: 410, fill: '#0a0a0a'),
      CanvasElement(id: 'tagline', type: 'text', text: 'Swipe to see more →', x: 40, y: 990, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#999999', align: 'center'),
      CanvasElement(id: 'shop_url', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1050, width: 1000, fontSize: 28, fontWeight: '600', fontFamily: 'Space Grotesk', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 240, y: 1120, width: 600, height: 70, fill: '#ffffff', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP THE COLLECTION', x: 240, y: 138, width: 600, fontSize: 22, fontWeight: 'bold', fontFamily: 'Space Grotesk', fill: '#0a0a0a', align: 'center'),
    ],
  ),

  // ── Testimonial / Review (1080x1080) ─────────────────────────────────────
  AdTemplate(
    id: 'tpl_review', name: 'Customer Review', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#eff6ff',
    previewColors: [Color(0xFFeff6ff), Color(0xFF1d4ed8)],
    elements: [
      CanvasElement(id: 'quote_mark', type: 'text', text: '"', x: 40, y: 20, width: 200, fontSize: 180, fontWeight: 'bold', fontFamily: 'Playfair Display', fill: '#bfdbfe', align: 'left'),
      CanvasElement(id: 'review_text', type: 'text', text: 'This is the best product I have ever bought. Highly recommend to everyone in Kampala!', x: 80, y: 180, width: 920, fontSize: 36, fontFamily: 'Merriweather', fill: '#1e3a8a', align: 'center'),
      CanvasElement(id: 'reviewer_img', type: 'image', src: '', x: 440, y: 500, width: 200, height: 200, cornerRadius: 100),
      CanvasElement(id: 'reviewer_name', type: 'text', text: 'Jane Nakato', x: 40, y: 730, width: 1000, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#1d4ed8', align: 'center'),
      CanvasElement(id: 'stars', type: 'text', text: '★★★★★', x: 40, y: 780, width: 1000, fontSize: 40, fill: '#fbbf24', align: 'center'),
      CanvasElement(id: 'product_name', type: 'text', text: 'Try PRODUCT NAME today', x: 40, y: 860, width: 1000, fontSize: 30, fontWeight: '600', fontFamily: 'Inter', fill: '#1e3a8a', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 940, width: 400, height: 70, fill: '#1d4ed8', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'SHOP NOW', x: 340, y: 958, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
    ],
  ),

  // ── Back-to-School (1080x1080) ────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_school', name: 'Back to School', category: 'promo',
    canvasWidth: 1080, canvasHeight: 1080, background: '#fef9c3',
    previewColors: [Color(0xFFfef9c3), Color(0xFF713f12)],
    elements: [
      CanvasElement(id: 'ruler_left', type: 'figure', x: 0, y: 0, width: 40, height: 1080, fill: '#713f12'),
      CanvasElement(id: 'ruler_right', type: 'figure', x: 1040, y: 0, width: 40, height: 1080, fill: '#713f12'),
      CanvasElement(id: 'badge', type: 'figure', x: 340, y: 60, width: 400, height: 70, fill: '#dc2626', cornerRadius: 8),
      CanvasElement(id: 'badge_text', type: 'text', text: '✏️ BACK TO SCHOOL', x: 340, y: 78, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Permanent Marker', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 80, y: 180, width: 920, height: 500, cornerRadius: 12),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 80, y: 720, width: 920, fontSize: 48, fontWeight: 'bold', fontFamily: 'Permanent Marker', fill: '#713f12', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 49,000', x: 80, y: 800, width: 920, fontSize: 52, fontWeight: 'bold', fontFamily: 'Inter', fill: '#dc2626', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 890, width: 400, height: 70, fill: '#713f12', cornerRadius: 35),
      CanvasElement(id: 'cta_text', type: 'text', text: 'WA: {{WHATSAPP}}', x: 340, y: 908, width: 400, fontSize: 22, fontWeight: 'bold', fontFamily: 'Inter', fill: '#fef9c3', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 40, y: 1010, width: 1000, fontSize: 16, fontFamily: 'Inter', fill: '#713f12', align: 'center', opacity: 0.5),
    ],
  ),

  // ── TikTok Viral (1080x1920) ─────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_tiktok', name: 'TikTok Viral', category: 'story',
    canvasWidth: 1080, canvasHeight: 1920, background: '#000000',
    previewColors: [Color(0xFF000000), Color(0xFFfe2c55)],
    elements: [
      CanvasElement(id: 'glow', type: 'figure', x: 0, y: 0, width: 1080, height: 600, fill: '#fe2c55', opacity: 0.25),
      CanvasElement(id: 'headline', type: 'text', text: 'POV: YOU NEED THIS', x: 60, y: 120, width: 960, fontSize: 58, fontWeight: 'bold', fontFamily: 'Bebas Neue', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 320, width: 900, height: 900, cornerRadius: 24),
      CanvasElement(id: 'price_bg', type: 'figure', x: 240, y: 1280, width: 600, height: 90, fill: '#fe2c55', cornerRadius: 45),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 240, y: 1300, width: 600, fontSize: 44, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Link in bio 👆', x: 60, y: 1420, width: 960, fontSize: 32, fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{CTA_LINK}}', x: 60, y: 1780, width: 960, fontSize: 22, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
    ],
  ),

  // ── LinkedIn Professional (1200x627) ─────────────────────────────────────
  AdTemplate(
    id: 'tpl_linkedin', name: 'LinkedIn Post', category: 'professional',
    canvasWidth: 1200, canvasHeight: 627, background: '#f8fafc',
    previewColors: [Color(0xFFf8fafc), Color(0xFF0a66c2)],
    elements: [
      CanvasElement(id: 'accent', type: 'figure', x: 0, y: 0, width: 12, height: 627, fill: '#0a66c2'),
      CanvasElement(id: 'headline', type: 'text', text: 'Now Available', x: 60, y: 60, width: 700, fontSize: 42, fontWeight: 'bold', fontFamily: 'Inter', fill: '#0f172a', align: 'left'),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 60, y: 120, width: 700, fontSize: 28, fontFamily: 'Inter', fill: '#334155', align: 'left'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 780, y: 60, width: 380, height: 380, cornerRadius: 12),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 150,000', x: 60, y: 200, width: 500, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: '#0a66c2', align: 'left'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 60, y: 480, width: 220, height: 56, fill: '#0a66c2', cornerRadius: 28),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Learn more', x: 60, y: 494, width: 220, fontSize: 20, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'footer', type: 'text', text: '{{BUSINESS}} · {{CTA_LINK}}', x: 60, y: 570, width: 1100, fontSize: 16, fontFamily: 'Inter', fill: '#64748b', align: 'left'),
    ],
  ),

  // ── Black Friday (1080x1080) ─────────────────────────────────────────────
  AdTemplate(
    id: 'tpl_black_friday', name: 'Black Friday', category: 'sale',
    canvasWidth: 1080, canvasHeight: 1080, background: '#09090b',
    previewColors: [Color(0xFF09090b), Color(0xFFfacc15)],
    elements: [
      CanvasElement(id: 'burst', type: 'figure', x: 340, y: 40, width: 400, height: 400, fill: '#facc15', cornerRadius: 200, opacity: 0.15),
      CanvasElement(id: 'headline', type: 'text', text: 'BLACK FRIDAY', x: 40, y: 80, width: 1000, fontSize: 64, fontWeight: 'bold', fontFamily: 'Bebas Neue', fill: '#facc15', align: 'center'),
      CanvasElement(id: 'subheadline', type: 'text', text: 'UP TO 50% OFF', x: 40, y: 160, width: 1000, fontSize: 36, fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 140, y: 240, width: 800, height: 480, cornerRadius: 16),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 760, width: 1000, fontSize: 34, fontWeight: '600', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 99,000', x: 40, y: 820, width: 1000, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#facc15', align: 'center'),
      CanvasElement(id: 'cta_bg', type: 'figure', x: 290, y: 920, width: 500, height: 72, fill: '#facc15', cornerRadius: 36),
      CanvasElement(id: 'cta_text', type: 'text', text: 'GRAB THE DEAL', x: 290, y: 938, width: 500, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: '#09090b', align: 'center'),
    ],
  ),

  // ── Restaurant Special (1080x1350) ───────────────────────────────────────
  AdTemplate(
    id: 'tpl_restaurant', name: 'Menu Special', category: 'food',
    canvasWidth: 1080, canvasHeight: 1350, background: '#1c1917',
    previewColors: [Color(0xFF1c1917), Color(0xFFea580c)],
    elements: [
      CanvasElement(id: 'top_band', type: 'figure', x: 0, y: 0, width: 1080, height: 280, fill: '#ea580c'),
      CanvasElement(id: 'headline', type: 'text', text: "TODAY'S SPECIAL", x: 40, y: 80, width: 1000, fontSize: 52, fontWeight: 'bold', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'product_image', type: 'image', src: '', x: 90, y: 320, width: 900, height: 560, cornerRadius: 20),
      CanvasElement(id: 'product_name', type: 'text', text: 'PRODUCT NAME', x: 40, y: 920, width: 1000, fontSize: 44, fontWeight: 'bold', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center'),
      CanvasElement(id: 'price', type: 'text', text: 'UGX 25,000', x: 40, y: 990, width: 1000, fontSize: 48, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ea580c', align: 'center'),
      CanvasElement(id: 'cta_text', type: 'text', text: 'Order: {{WHATSAPP}}', x: 40, y: 1080, width: 1000, fontSize: 28, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.85),
      CanvasElement(id: 'footer', type: 'text', text: '{{LOCATION}}', x: 40, y: 1260, width: 1000, fontSize: 20, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
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
  (id: 'sunset',    label: 'Sunset',    colors: [Color(0xFFff6b35), Color(0xFFf7c59f)]),
  (id: 'ocean',     label: 'Ocean',     colors: [Color(0xFF0077b6), Color(0xFF00b4d8)]),
  (id: 'forest',    label: 'Forest',    colors: [Color(0xFF1b4332), Color(0xFF40916c)]),
  (id: 'neon',      label: 'Neon',      colors: [Color(0xFF6d28d9), Color(0xFFec4899)]),
  (id: 'gold',      label: 'Gold',      colors: [Color(0xFF92400e), Color(0xFFd4af37)]),
  (id: 'midnight',  label: 'Midnight',  colors: [Color(0xFF0f0c29), Color(0xFF302b63)]),
  (id: 'rose',      label: 'Rose',      colors: [Color(0xFFbe185d), Color(0xFFfda4af)]),
  (id: 'arctic',    label: 'Arctic',    colors: [Color(0xFF1e3a5f), Color(0xFF4a9eff)]),
  (id: 'fire',      label: 'Fire',      colors: [Color(0xFF7f1d1d), Color(0xFFef4444)]),
  (id: 'mint',      label: 'Mint',      colors: [Color(0xFF064e3b), Color(0xFF34d399)]),
  (id: 'peach',     label: 'Peach',     colors: [Color(0xFFfed7aa), Color(0xFFfdba74)]),
  (id: 'slate',     label: 'Slate',     colors: [Color(0xFF0f172a), Color(0xFF334155)]),
  (id: 'soko',      label: 'Soko',      colors: [Color(0xFF0F1D40), Color(0xFF0EBE7E)]),
  (id: 'candy',     label: 'Candy',     colors: [Color(0xFFf093fb), Color(0xFFf5576c)]),
  (id: 'cosmic',    label: 'Cosmic',    colors: [Color(0xFF141e30), Color(0xFF243b55)]),
  (id: 'lime',      label: 'Lime',      colors: [Color(0xFF134e5e), Color(0xFF71b280)]),
  (id: 'velvet',    label: 'Velvet',    colors: [Color(0xFF200122), Color(0xFF6f0000)]),
  (id: 'sky',       label: 'Sky',       colors: [Color(0xFF2980b9), Color(0xFF6dd5fa)]),
  (id: 'sunrise',   label: 'Sunrise',   colors: [Color(0xFFff512f), Color(0xFFf09819)]),
];

/// Solid color palette (displayed in background & color pickers)
const colorPalette = <Color>[
  Color(0xFFffffff), Color(0xFF000000), Color(0xFF1e293b), Color(0xFF0f172a),
  Color(0xFF111827), Color(0xFF374151), Color(0xFF6b7280), Color(0xFF9ca3af),
  Color(0xFFe5e7eb), Color(0xFFf9fafb),
  // Reds
  Color(0xFF7f1d1d), Color(0xFFdc2626), Color(0xFFef4444), Color(0xFFf87171),
  Color(0xFFfecaca),
  // Oranges
  Color(0xFF92400e), Color(0xFFd97706), Color(0xFFf59e0b), Color(0xFFfbbf24),
  Color(0xFFfef08a),
  // Greens
  Color(0xFF14532d), Color(0xFF16a34a), Color(0xFF22c55e), Color(0xFF0EBE7E),
  Color(0xFF34d399),
  // Blues
  Color(0xFF1e3a8a), Color(0xFF1d4ed8), Color(0xFF3b82f6), Color(0xFF60a5fa),
  Color(0xFF93c5fd),
  // Purples
  Color(0xFF4c1d95), Color(0xFF7c3aed), Color(0xFFa855f7), Color(0xFFd8b4fe),
  Color(0xFFf3e8ff),
  // Pinks
  Color(0xFF9d174d), Color(0xFFbe185d), Color(0xFFec4899), Color(0xFFf9a8d4),
  // Brand
  Color(0xFF0F1D40), Color(0xFF0EBE7E),
  // Gold
  Color(0xFF78350f), Color(0xFFd4af37), Color(0xFFfbbf24),
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
