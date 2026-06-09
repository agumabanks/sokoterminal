import 'package:flutter/material.dart';

import 'ad_templates.dart';

// ---------------------------------------------------------------------------
// Catalog entry types
// ---------------------------------------------------------------------------

class CreativeAsset {
  const CreativeAsset({
    required this.id,
    required this.label,
    required this.category,
    required this.element,
    this.emoji,
    this.icon,
    this.isPremium = false,
    this.description,
  });

  final String id;
  final String label;
  final String category;
  final CanvasElement element;
  final String? emoji;
  final IconData? icon;
  final bool isPremium;
  final String? description;
}

class MagicLayout {
  const MagicLayout({
    required this.id,
    required this.label,
    required this.emoji,
    required this.background,
    required this.elements,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final String emoji;
  final String background;
  final List<CanvasElement> elements;
  final bool isPremium;
}

// ---------------------------------------------------------------------------
// Variable word presets — product/brand placeholders
// ---------------------------------------------------------------------------

final variableWordPresets = <CreativeAsset>[
  CreativeAsset(
    id: 'word_product_hero',
    label: 'Product Hero',
    category: 'words',
    emoji: '🛍️',
    element: CanvasElement(
      id: 'word_product_hero',
      type: 'text',
      text: '{{PRODUCT}}',
      width: 900,
      fontSize: 88,
      fontWeight: '900',
      fontFamily: 'Bebas Neue',
      fill: '#ffffff',
      align: 'center',
      shadowColor: '#000000',
      shadowBlur: 12,
    ),
  ),
  CreativeAsset(
    id: 'word_price_pop',
    label: 'Price Pop',
    category: 'words',
    emoji: '💰',
    element: CanvasElement(
      id: 'word_price_pop',
      type: 'text',
      text: '{{PRICE}}',
      width: 600,
      fontSize: 72,
      fontWeight: '800',
      fontFamily: 'Oswald',
      fill: '#fef08a',
      align: 'center',
      strokeColor: '#000000',
      strokeWidth: 2,
    ),
  ),
  CreativeAsset(
    id: 'word_sale_script',
    label: 'Sale Script',
    category: 'words',
    emoji: '✨',
    element: CanvasElement(
      id: 'word_sale_script',
      type: 'text',
      text: 'Special Offer',
      width: 700,
      fontSize: 64,
      fontFamily: 'Pacifico',
      fill: '#fbbf24',
      align: 'center',
    ),
  ),
  CreativeAsset(
    id: 'word_cta_bold',
    label: 'Shop CTA',
    category: 'words',
    emoji: '🛒',
    element: CanvasElement(
      id: 'word_cta_bold',
      type: 'text',
      text: 'SHOP NOW →',
      width: 500,
      fontSize: 40,
      fontWeight: '800',
      fontFamily: 'Montserrat',
      fill: '#ffffff',
      align: 'center',
    ),
  ),
  CreativeAsset(
    id: 'word_whatsapp',
    label: 'WhatsApp',
    category: 'words',
    emoji: '💬',
    element: CanvasElement(
      id: 'word_whatsapp',
      type: 'text',
      text: 'Order: {{WHATSAPP}}',
      width: 700,
      fontSize: 32,
      fontWeight: '600',
      fontFamily: 'Inter',
      fill: '#ffffff',
      align: 'center',
    ),
  ),
  CreativeAsset(
    id: 'word_business',
    label: 'Business',
    category: 'words',
    emoji: '🏪',
    element: CanvasElement(
      id: 'word_business',
      type: 'text',
      text: '{{BUSINESS}}',
      width: 800,
      fontSize: 48,
      fontWeight: '700',
      fontFamily: 'Playfair Display',
      fill: '#ffffff',
      align: 'center',
    ),
  ),
  CreativeAsset(
    id: 'word_location',
    label: 'Location',
    category: 'words',
    emoji: '📍',
    element: CanvasElement(
      id: 'word_location',
      type: 'text',
      text: '{{LOCATION}}',
      width: 600,
      fontSize: 28,
      fontFamily: 'Poppins',
      fill: '#ffffff',
      align: 'center',
      opacity: 0.85,
    ),
  ),
  CreativeAsset(
    id: 'word_neon',
    label: 'Neon Headline',
    category: 'words',
    emoji: '⚡',
    isPremium: true,
    element: CanvasElement(
      id: 'word_neon',
      type: 'text',
      text: 'FLASH SALE',
      width: 800,
      fontSize: 76,
      fontWeight: '900',
      fontFamily: 'Anton',
      fill: '#22d3ee',
      align: 'center',
      shadowColor: '#06b6d4',
      shadowBlur: 24,
      strokeColor: '#ffffff',
      strokeWidth: 1.5,
    ),
  ),
  CreativeAsset(
    id: 'word_luxury',
    label: 'Luxury Serif',
    category: 'words',
    emoji: '👑',
    isPremium: true,
    element: CanvasElement(
      id: 'word_luxury',
      type: 'text',
      text: '{{PRODUCT}}',
      width: 800,
      fontSize: 56,
      fontWeight: '600',
      fontFamily: 'Cormorant Garamond',
      fill: '#d4af37',
      align: 'center',
      letterSpacing: 2,
    ),
  ),
  CreativeAsset(
    id: 'word_street',
    label: 'Street Bold',
    category: 'words',
    emoji: '🔥',
    isPremium: true,
    element: CanvasElement(
      id: 'word_street',
      type: 'text',
      text: 'NEW DROP',
      width: 700,
      fontSize: 82,
      fontWeight: '900',
      fontFamily: 'Archivo Black',
      fill: '#ffffff',
      align: 'center',
      shadowColor: '#dc2626',
      shadowBlur: 8,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Stickers (emoji) — free + premium
// ---------------------------------------------------------------------------

final stickerAssets = <CreativeAsset>[
  for (final e in [
    ('🔥', 'Fire'), ('⭐', 'Star'), ('✨', 'Sparkle'), ('❤️', 'Heart'),
    ('✅', 'Check'), ('🎁', 'Gift'), ('🎉', 'Party'), ('💰', 'Money'),
    ('🛒', 'Cart'), ('🛍️', 'Bags'), ('📱', 'Phone'), ('💬', 'Chat'),
    ('🚚', 'Delivery'), ('🍔', 'Food'), ('☕', 'Coffee'), ('🆕', 'New'),
    ('🏷️', 'Tag'), ('🏆', 'Trophy'), ('💯', '100'), ('👆', 'Point'),
    ('📣', 'Announce'), ('⚡', 'Bolt'), ('🎯', 'Target'), ('💎', 'Gem'),
    ('🌟', 'Glow'), ('🤑', 'Deal'), ('📦', 'Box'), ('🧾', 'Receipt'),
  ])
    CreativeAsset(
      id: 'stk_${e.$2.toLowerCase()}',
      label: e.$2,
      category: 'stickers',
      emoji: e.$1,
      element: CanvasElement(
        id: 'stk_${e.$2.toLowerCase()}',
        type: 'sticker',
        text: e.$1,
        width: 140,
        height: 140,
        fontSize: 88,
        align: 'center',
      ),
    ),
  CreativeAsset(
    id: 'stk_premium_crown',
    label: 'Crown',
    category: 'stickers',
    emoji: '👑',
    isPremium: true,
    element: CanvasElement(
      id: 'stk_premium_crown',
      type: 'sticker',
      text: '👑',
      width: 160,
      height: 160,
      fontSize: 100,
      align: 'center',
    ),
  ),
  CreativeAsset(
    id: 'stk_premium_rocket',
    label: 'Rocket',
    category: 'stickers',
    emoji: '🚀',
    isPremium: true,
    element: CanvasElement(
      id: 'stk_premium_rocket',
      type: 'sticker',
      text: '🚀',
      width: 160,
      height: 160,
      fontSize: 100,
      align: 'center',
    ),
  ),
  CreativeAsset(
    id: 'stk_premium_combo',
    label: 'Hot Deal',
    category: 'stickers',
    emoji: '🔥💯',
    isPremium: true,
    element: CanvasElement(
      id: 'stk_premium_combo',
      type: 'sticker',
      text: '🔥💯',
      width: 200,
      height: 140,
      fontSize: 72,
      align: 'center',
    ),
  ),
];

// ---------------------------------------------------------------------------
// Icons — rendered as real icon elements
// ---------------------------------------------------------------------------

CreativeAsset _iconAsset(String id, IconData icon, String label, String color,
    {bool premium = false}) =>
    CreativeAsset(
      id: id,
      label: label,
      category: 'icons',
      icon: icon,
      isPremium: premium,
      element: CanvasElement(
        id: id,
        type: 'icon',
        width: 120,
        height: 120,
        fill: color,
        iconCodePoint: icon.codePoint,
        iconFontFamily: icon.fontFamily,
        iconFontPackage: icon.fontPackage,
      ),
    );

final iconAssets = <CreativeAsset>[
  _iconAsset('ico_star', Icons.star_rounded, 'Star', '#f59e0b'),
  _iconAsset('ico_heart', Icons.favorite_rounded, 'Heart', '#ec4899'),
  _iconAsset('ico_tag', Icons.local_offer_rounded, 'Tag', '#dc2626'),
  _iconAsset('ico_bolt', Icons.bolt_rounded, 'Bolt', '#fbbf24'),
  _iconAsset('ico_diamond', Icons.diamond_rounded, 'Diamond', '#a855f7'),
  _iconAsset('ico_like', Icons.thumb_up_rounded, 'Like', '#0EBE7E'),
  _iconAsset('ico_verified', Icons.verified_rounded, 'Verified', '#3b82f6'),
  _iconAsset('ico_trophy', Icons.emoji_events_rounded, 'Trophy', '#d4af37'),
  _iconAsset('ico_bag', Icons.shopping_bag_rounded, 'Bag', '#6366f1'),
  _iconAsset('ico_delivery', Icons.delivery_dining_rounded, 'Delivery', '#0EBE7E'),
  _iconAsset('ico_percent', Icons.percent_rounded, 'Percent', '#dc2626'),
  _iconAsset('ico_cart', Icons.shopping_cart_rounded, 'Cart', '#0EBE7E'),
  _iconAsset('ico_store', Icons.storefront_rounded, 'Store', '#0F1D40'),
  _iconAsset('ico_phone', Icons.phone_in_talk_rounded, 'Call', '#22c55e'),
  _iconAsset('ico_chat', Icons.chat_rounded, 'Chat', '#25D366'),
  _iconAsset('ico_location', Icons.location_on_rounded, 'Pin', '#ef4444'),
  _iconAsset('ico_timer', Icons.timer_rounded, 'Timer', '#f97316'),
  _iconAsset('ico_gift', Icons.card_giftcard_rounded, 'Gift', '#ec4899'),
  _iconAsset('ico_new', Icons.fiber_new_rounded, 'New', '#3b82f6'),
  _iconAsset('ico_trending', Icons.trending_up_rounded, 'Trending', '#0EBE7E'),
  _iconAsset('ico_crown', Icons.workspace_premium_rounded, 'Premium', '#d4af37',
      premium: true),
  _iconAsset('ico_sparkle', Icons.auto_awesome_rounded, 'Magic', '#a855f7',
      premium: true),
  _iconAsset('ico_diamond_p', Icons.diamond_outlined, 'Elite', '#22d3ee',
      premium: true),
  _iconAsset('ico_rocket', Icons.rocket_launch_rounded, 'Launch', '#f97316',
      premium: true),
];

// ---------------------------------------------------------------------------
// Illustrations — vector art via assetId
// ---------------------------------------------------------------------------

CreativeAsset _illus(String id, String label, String assetId, String color,
    {bool premium = false, double w = 280, double h = 280}) =>
    CreativeAsset(
      id: id,
      label: label,
      category: 'illustrations',
      isPremium: premium,
      element: CanvasElement(
        id: id,
        type: 'illustration',
        assetId: assetId,
        width: w,
        height: h,
        fill: color,
      ),
    );

final illustrationAssets = <CreativeAsset>[
  _illus('ill_burst', 'Star Burst', 'burst_rays', '#fbbf24'),
  _illus('ill_ribbon', 'Ribbon', 'ribbon_banner', '#dc2626'),
  _illus('ill_bubble', 'Speech', 'speech_bubble', '#ffffff'),
  _illus('ill_price', 'Price Ring', 'price_ring', '#0EBE7E'),
  _illus('ill_arrow', 'Swipe Up', 'arrow_up', '#ffffff'),
  _illus('ill_stamp', 'Sale Stamp', 'sale_stamp', '#dc2626'),
  _illus('ill_spark', 'Spark Frame', 'spark_frame', '#a855f7'),
  _illus('ill_badge', 'Trust Seal', 'trust_seal', '#3b82f6'),
  _illus('ill_neon', 'Neon Frame', 'neon_frame', '#22d3ee', premium: true),
  _illus('ill_lux', 'Gold Frame', 'gold_frame', '#d4af37', premium: true),
  _illus('ill_cosmic', 'Cosmic Orb', 'cosmic_orb', '#6366f1', premium: true),
];

// ---------------------------------------------------------------------------
// Magic one-tap layouts (seconds to ad)
// ---------------------------------------------------------------------------

List<MagicLayout> magicLayoutsForCanvas(double w, double h) => [
  MagicLayout(
    id: 'magic_sale_blast',
    label: 'Sale Blast',
    emoji: '🔥',
    background: 'gradient:fire',
    elements: [
      CanvasElement(
        id: 'm_headline', type: 'text', text: 'MEGA SALE',
        x: w * 0.08, y: h * 0.12, width: w * 0.84, fontSize: 72,
        fontWeight: '900', fontFamily: 'Anton', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_price', type: 'text', text: '{{PRICE}}',
        x: w * 0.15, y: h * 0.38, width: w * 0.7, fontSize: 56,
        fontWeight: '800', fontFamily: 'Oswald', fill: '#fef08a', align: 'center',
      ),
      CanvasElement(
        id: 'm_product', type: 'text', text: '{{PRODUCT}}',
        x: w * 0.1, y: h * 0.55, width: w * 0.8, fontSize: 36,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_cta', type: 'figure',
        x: w * 0.25, y: h * 0.72, width: w * 0.5, height: h * 0.08,
        fill: '#0EBE7E', cornerRadius: 40,
      ),
      CanvasElement(
        id: 'm_cta_t', type: 'text', text: 'ORDER ON WHATSAPP',
        x: w * 0.25, y: h * 0.735, width: w * 0.5, fontSize: 22,
        fontWeight: '700', fontFamily: 'Montserrat', fill: '#ffffff', align: 'center',
      ),
    ],
  ),
  MagicLayout(
    id: 'magic_story_price',
    label: 'Story Price',
    emoji: '📱',
    background: 'gradient:soko',
    elements: [
      CanvasElement(
        id: 'm_biz', type: 'text', text: '{{BUSINESS}}',
        x: w * 0.08, y: h * 0.06, width: w * 0.84, fontSize: 28,
        fontWeight: '700', fontFamily: 'Montserrat', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_prod', type: 'text', text: '{{PRODUCT}}',
        x: w * 0.08, y: h * 0.42, width: w * 0.84, fontSize: 52,
        fontWeight: '800', fontFamily: 'Bebas Neue', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_prc', type: 'text', text: '{{PRICE}}',
        x: w * 0.2, y: h * 0.52, width: w * 0.6, fontSize: 64,
        fontWeight: '900', fontFamily: 'Oswald', fill: '#fef08a', align: 'center',
      ),
      CanvasElement(
        id: 'm_wa', type: 'text', text: '💬 {{WHATSAPP}}',
        x: w * 0.1, y: h * 0.88, width: w * 0.8, fontSize: 26,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
    ],
  ),
  MagicLayout(
    id: 'magic_minimal',
    label: 'Minimal Luxe',
    emoji: '✨',
    background: '#0f172a',
    elements: [
      CanvasElement(
        id: 'm_l1', type: 'text', text: '{{PRODUCT}}',
        x: w * 0.1, y: h * 0.35, width: w * 0.8, fontSize: 48,
        fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_l2', type: 'text', text: '{{PRICE}}',
        x: w * 0.2, y: h * 0.48, width: w * 0.6, fontSize: 40,
        fontWeight: '600', fontFamily: 'Cormorant Garamond', fill: '#d4af37',
        align: 'center',
      ),
      CanvasElement(
        id: 'm_l3', type: 'figure',
        x: w * 0.35, y: h * 0.58, width: w * 0.3, height: 2,
        fill: '#d4af37',
      ),
    ],
  ),
  MagicLayout(
    id: 'magic_whatsapp',
    label: 'WhatsApp CTA',
    emoji: '💬',
    background: 'gradient:forest',
    elements: [
      CanvasElement(
        id: 'm_w1', type: 'text', text: '{{PRODUCT}}',
        x: w * 0.08, y: h * 0.2, width: w * 0.84, fontSize: 44,
        fontWeight: '700', fontFamily: 'Poppins', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_w2', type: 'text', text: '{{PRICE}}',
        x: w * 0.15, y: h * 0.32, width: w * 0.7, fontSize: 52,
        fontWeight: '800', fontFamily: 'Oswald', fill: '#fef08a', align: 'center',
      ),
      CanvasElement(
        id: 'm_w3', type: 'figure',
        x: w * 0.12, y: h * 0.72, width: w * 0.76, height: h * 0.1,
        fill: '#25D366', cornerRadius: 50,
      ),
      CanvasElement(
        id: 'm_w4', type: 'text', text: 'WhatsApp {{WHATSAPP}}',
        x: w * 0.12, y: h * 0.745, width: w * 0.76, fontSize: 24,
        fontWeight: '700', fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
    ],
  ),
  MagicLayout(
    id: 'magic_new_drop',
    label: 'New Drop',
    emoji: '🆕',
    background: 'gradient:neon',
    isPremium: true,
    elements: [
      CanvasElement(
        id: 'm_n1', type: 'text', text: 'NEW ARRIVAL',
        x: w * 0.08, y: h * 0.15, width: w * 0.84, fontSize: 64,
        fontWeight: '900', fontFamily: 'Archivo Black', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_n2', type: 'text', text: '{{PRODUCT}}',
        x: w * 0.1, y: h * 0.4, width: w * 0.8, fontSize: 40,
        fontFamily: 'Montserrat', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_n3', type: 'text', text: '{{PRICE}}',
        x: w * 0.2, y: h * 0.52, width: w * 0.6, fontSize: 48,
        fontWeight: '800', fontFamily: 'Oswald', fill: '#22d3ee', align: 'center',
      ),
    ],
  ),
  MagicLayout(
    id: 'magic_flash',
    label: 'Flash Deal',
    emoji: '⚡',
    background: 'gradient:midnight',
    isPremium: true,
    elements: [
      CanvasElement(
        id: 'm_f1', type: 'illustration', assetId: 'burst_rays',
        x: w * 0.2, y: h * 0.08, width: w * 0.6, height: w * 0.6,
        fill: '#fbbf24', opacity: 0.9,
      ),
      CanvasElement(
        id: 'm_f2', type: 'text', text: 'FLASH DEAL',
        x: w * 0.1, y: h * 0.35, width: w * 0.8, fontSize: 58,
        fontWeight: '900', fontFamily: 'Anton', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'm_f3', type: 'text', text: '{{PRICE}}',
        x: w * 0.15, y: h * 0.48, width: w * 0.7, fontSize: 52,
        fontWeight: '800', fontFamily: 'Oswald', fill: '#fef08a', align: 'center',
      ),
    ],
  ),
];

List<CreativeAsset> allCreativeAssets() => [
  ...variableWordPresets,
  ...stickerAssets,
  ...iconAssets,
  ...illustrationAssets,
];