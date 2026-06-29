import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Business Hub document types — beyond product ads.
class BusinessHubType {
  const BusinessHubType({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.templateCategory,
    this.canvasLabel,
    this.accent = DesignTokens.brandAccent,
    this.gradient = const [DesignTokens.brandAccent, DesignTokens.success],
    this.emoji,
  });

  final String id;
  final String label;
  final IconData icon;
  final String description;
  final String templateCategory;
  final String? canvasLabel;
  final Color accent;
  final List<Color> gradient;
  final String? emoji;
}

/// Graphics workspace sections — lively grouped navigation.
class GraphicsCategory {
  const GraphicsCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hubIds,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> hubIds;
  final Color accent;
}

const graphicsCategories = <GraphicsCategory>[
  GraphicsCategory(
    id: 'brand',
    title: 'Brand Identity',
    subtitle: 'Logo, cards & who you are',
    icon: Icons.auto_awesome_rounded,
    hubIds: ['logo', 'business_card', 'company_profile'],
    accent: Color(0xFFa855f7),
  ),
  GraphicsCategory(
    id: 'retail',
    title: 'Food & Retail',
    subtitle: 'Menus, collages & showcases',
    icon: Icons.storefront_rounded,
    hubIds: ['menu', 'collage'],
    accent: Color(0xFFf59e0b),
  ),
  GraphicsCategory(
    id: 'marketing',
    title: 'Marketing',
    subtitle: 'Flyers, invites & brochures',
    icon: Icons.campaign_rounded,
    hubIds: ['brochure', 'invitation', 'event_flyer', 'service_flyer'],
    accent: Color(0xFF22d3ee),
  ),
  GraphicsCategory(
    id: 'commerce',
    title: 'Commerce',
    subtitle: 'Invoices for print & POS',
    icon: Icons.receipt_long_rounded,
    hubIds: ['invoice'],
    accent: DesignTokens.brandAccent,
  ),
];

const businessHubTypes = <BusinessHubType>[
  BusinessHubType(
    id: 'logo',
    label: 'Logo',
    icon: Icons.hexagon_outlined,
    description: 'Mark, monogram & shop identity',
    templateCategory: 'logo',
    accent: Color(0xFFa855f7),
    gradient: [Color(0xFFa855f7), Color(0xFF6366f1)],
    emoji: '✦',
  ),
  BusinessHubType(
    id: 'collage',
    label: 'Product Collage',
    icon: Icons.grid_on_rounded,
    description: 'Multi-photo product showcase',
    templateCategory: 'collage',
    accent: Color(0xFF3b82f6),
    gradient: [Color(0xFF3b82f6), Color(0xFF1d4ed8)],
    emoji: '🖼',
  ),
  BusinessHubType(
    id: 'menu',
    label: 'Menu',
    icon: Icons.restaurant_menu_rounded,
    description: 'Food & drinks price list',
    templateCategory: 'menu',
    accent: Color(0xFFf59e0b),
    gradient: [Color(0xFFf59e0b), Color(0xFFd97706)],
    emoji: '🍽',
  ),
  BusinessHubType(
    id: 'brochure',
    label: 'Brochure',
    icon: Icons.menu_book_rounded,
    description: 'Tri-fold & service brochure',
    templateCategory: 'brochure',
    accent: Color(0xFF14b8a6),
    gradient: [Color(0xFF14b8a6), Color(0xFF0d9488)],
    emoji: '📖',
  ),
  BusinessHubType(
    id: 'company_profile',
    label: 'Company Profile',
    icon: Icons.business_center_outlined,
    description: 'About us & credentials',
    templateCategory: 'company_profile',
    accent: Color(0xFF64748b),
    gradient: [Color(0xFF475569), Color(0xFF334155)],
    emoji: '🏢',
  ),
  BusinessHubType(
    id: 'invitation',
    label: 'Invitation',
    icon: Icons.card_giftcard_outlined,
    description: 'Events, launches & parties',
    templateCategory: 'invitation',
    accent: Color(0xFFec4899),
    gradient: [Color(0xFFec4899), Color(0xFFbe185d)],
    emoji: '🎉',
  ),
  BusinessHubType(
    id: 'event_flyer',
    label: 'Event Flyer',
    icon: Icons.celebration_outlined,
    description: 'Promote events & openings',
    templateCategory: 'event_flyer',
    accent: Color(0xFFf97316),
    gradient: [Color(0xFFf97316), Color(0xFFea580c)],
    emoji: '📣',
  ),
  BusinessHubType(
    id: 'service_flyer',
    label: 'Service Flyer',
    icon: Icons.handyman_outlined,
    description: 'Flyers for your services',
    templateCategory: 'service_flyer',
    accent: Color(0xFF22d3ee),
    gradient: [Color(0xFF22d3ee), Color(0xFF0891b2)],
    emoji: '🔧',
  ),
  BusinessHubType(
    id: 'business_card',
    label: 'Business Card',
    icon: Icons.badge_outlined,
    description: 'Print-ready contact card',
    templateCategory: 'business_card',
    canvasLabel: '90×50mm',
    accent: DesignTokens.brandAccent,
    gradient: [DesignTokens.brandAccent, DesignTokens.success],
    emoji: '💳',
  ),
  BusinessHubType(
    id: 'invoice',
    label: 'Invoice',
    icon: Icons.receipt_long_outlined,
    description: 'Print or share with customers',
    templateCategory: 'invoice',
    accent: Color(0xFF10b981),
    gradient: [Color(0xFF10b981), Color(0xFF047857)],
    emoji: '🧾',
  ),
];

BusinessHubType? hubTypeById(String id) {
  for (final h in businessHubTypes) {
    if (h.id == id) return h;
  }
  return null;
}

/// Curated template sections shown in the Templates workspace.
const templateDiscoverySections = <({
  String id,
  String title,
  String subtitle,
  IconData icon,
})>[
  (
    id: 'todays_ads',
    title: "Today's Ads",
    subtitle: 'Ready to post for your catalog',
    icon: Icons.bolt_rounded,
  ),
  (
    id: 'top_picks',
    title: 'Top Picks',
    subtitle: 'Hand-picked by Soko Studio',
    icon: Icons.star_rounded,
  ),
  (
    id: 'popular',
    title: 'Popular',
    subtitle: 'Used by sellers across Uganda',
    icon: Icons.trending_up_rounded,
  ),
  (
    id: 'for_you',
    title: 'More Templates for You',
    subtitle: 'Based on your business & catalog',
    icon: Icons.auto_awesome_rounded,
  ),
  (
    id: 'business_hub',
    title: 'Business Hub',
    subtitle: 'Logos, menus, invoices & more',
    icon: Icons.storefront_rounded,
  ),
];