import 'package:flutter/material.dart';

import 'ad_templates.dart';

// ---------------------------------------------------------------------------
// Modern Icon Library — 100+ semantic icons for Soko Studio
// ---------------------------------------------------------------------------

class ModernIcon {
  const ModernIcon({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    this.brandTintable = true,
  });

  final String id;
  final String label;
  final String category;
  final IconData icon;
  final bool brandTintable;
}

// ---------------------------------------------------------------------------
// Commerce & Shopping
// ---------------------------------------------------------------------------
const _commerceIcons = <ModernIcon>[
  ModernIcon(id: 'cart', label: 'Shopping Cart', category: 'commerce', icon: Icons.shopping_cart_rounded),
  ModernIcon(id: 'bag', label: 'Shopping Bag', category: 'commerce', icon: Icons.shopping_bag_rounded),
  ModernIcon(id: 'basket', label: 'Basket', category: 'commerce', icon: Icons.shopping_basket_rounded),
  ModernIcon(id: 'tag', label: 'Price Tag', category: 'commerce', icon: Icons.local_offer_rounded),
  ModernIcon(id: 'percent', label: 'Percent', category: 'commerce', icon: Icons.percent_rounded),
  ModernIcon(id: 'discount', label: 'Discount', category: 'commerce', icon: Icons.discount_rounded),
  ModernIcon(id: 'star', label: 'Star', category: 'commerce', icon: Icons.star_rounded),
  ModernIcon(id: 'star_half', label: 'Star Half', category: 'commerce', icon: Icons.star_half_rounded),
  ModernIcon(id: 'heart', label: 'Heart', category: 'commerce', icon: Icons.favorite_rounded),
  ModernIcon(id: 'heart_outline', label: 'Heart Outline', category: 'commerce', icon: Icons.favorite_border_rounded),
  ModernIcon(id: 'gift', label: 'Gift', category: 'commerce', icon: Icons.card_giftcard_rounded),
  ModernIcon(id: 'box', label: 'Package', category: 'commerce', icon: Icons.inventory_2_rounded),
  ModernIcon(id: 'box_open', label: 'Open Box', category: 'commerce', icon: Icons.open_in_new_rounded),
  ModernIcon(id: 'store', label: 'Store', category: 'commerce', icon: Icons.store_rounded),
  ModernIcon(id: 'storefront', label: 'Storefront', category: 'commerce', icon: Icons.storefront_rounded),
  ModernIcon(id: 'wallet', label: 'Wallet', category: 'commerce', icon: Icons.account_balance_wallet_rounded),
  ModernIcon(id: 'receipt', label: 'Receipt', category: 'commerce', icon: Icons.receipt_rounded),
  ModernIcon(id: 'receipt_long', label: 'Receipt Long', category: 'commerce', icon: Icons.receipt_long_rounded),
  ModernIcon(id: 'payment', label: 'Payment', category: 'commerce', icon: Icons.payment_rounded),
  ModernIcon(id: 'credit_card', label: 'Credit Card', category: 'commerce', icon: Icons.credit_card_rounded),
  ModernIcon(id: 'money', label: 'Money', category: 'commerce', icon: Icons.attach_money_rounded),
  ModernIcon(id: 'trending_up', label: 'Trending Up', category: 'commerce', icon: Icons.trending_up_rounded),
  ModernIcon(id: 'trending_down', label: 'Trending Down', category: 'commerce', icon: Icons.trending_down_rounded),
  ModernIcon(id: 'price_check', label: 'Price Check', category: 'commerce', icon: Icons.price_check_rounded),
  ModernIcon(id: 'sell', label: 'Sell', category: 'commerce', icon: Icons.sell_rounded),
];

// ---------------------------------------------------------------------------
// Social & Communication
// ---------------------------------------------------------------------------
const _socialIcons = <ModernIcon>[
  ModernIcon(id: 'share', label: 'Share', category: 'social', icon: Icons.share_rounded),
  ModernIcon(id: 'send', label: 'Send', category: 'social', icon: Icons.send_rounded),
  ModernIcon(id: 'chat', label: 'Chat', category: 'social', icon: Icons.chat_rounded),
  ModernIcon(id: 'chat_bubble', label: 'Chat Bubble', category: 'social', icon: Icons.chat_bubble_rounded),
  ModernIcon(id: 'forum', label: 'Forum', category: 'social', icon: Icons.forum_rounded),
  ModernIcon(id: 'notifications', label: 'Notifications', category: 'social', icon: Icons.notifications_rounded),
  ModernIcon(id: 'notifications_active', label: 'Notifications Active', category: 'social', icon: Icons.notifications_active_rounded),
  ModernIcon(id: 'video', label: 'Video', category: 'social', icon: Icons.videocam_rounded),
  ModernIcon(id: 'photo', label: 'Photo', category: 'social', icon: Icons.photo_rounded),
  ModernIcon(id: 'camera', label: 'Camera', category: 'social', icon: Icons.camera_alt_rounded),
  ModernIcon(id: 'hashtag', label: 'Hashtag', category: 'social', icon: Icons.tag_rounded),
  ModernIcon(id: 'like', label: 'Thumbs Up', category: 'social', icon: Icons.thumb_up_rounded),
  ModernIcon(id: 'dislike', label: 'Thumbs Down', category: 'social', icon: Icons.thumb_down_rounded),
  ModernIcon(id: 'group', label: 'Group', category: 'social', icon: Icons.group_rounded),
  ModernIcon(id: 'person', label: 'Person', category: 'social', icon: Icons.person_rounded),
  ModernIcon(id: 'people', label: 'People', category: 'social', icon: Icons.people_rounded),
  ModernIcon(id: 'follow', label: 'Person Add', category: 'social', icon: Icons.person_add_rounded),
];

// ---------------------------------------------------------------------------
// Business & Marketing
// ---------------------------------------------------------------------------
const _businessIcons = <ModernIcon>[
  ModernIcon(id: 'chart', label: 'Bar Chart', category: 'business', icon: Icons.bar_chart_rounded),
  ModernIcon(id: 'pie_chart', label: 'Pie Chart', category: 'business', icon: Icons.pie_chart_rounded),
  ModernIcon(id: 'analytics', label: 'Analytics', category: 'business', icon: Icons.analytics_rounded),
  ModernIcon(id: 'target', label: 'Target', category: 'business', icon: Icons.track_changes_rounded),
  ModernIcon(id: 'megaphone', label: 'Megaphone', category: 'business', icon: Icons.campaign_rounded),
  ModernIcon(id: 'rocket', label: 'Rocket', category: 'business', icon: Icons.rocket_rounded),
  ModernIcon(id: 'trophy', label: 'Trophy', category: 'business', icon: Icons.emoji_events_rounded),
  ModernIcon(id: 'shield', label: 'Shield', category: 'business', icon: Icons.verified_user_rounded),
  ModernIcon(id: 'verified', label: 'Verified', category: 'business', icon: Icons.verified_rounded),
  ModernIcon(id: 'clock', label: 'Clock', category: 'business', icon: Icons.access_time_rounded),
  ModernIcon(id: 'calendar', label: 'Calendar', category: 'business', icon: Icons.calendar_month_rounded),
  ModernIcon(id: 'location', label: 'Location', category: 'business', icon: Icons.location_on_rounded),
  ModernIcon(id: 'map', label: 'Map', category: 'business', icon: Icons.map_rounded),
  ModernIcon(id: 'phone', label: 'Phone', category: 'business', icon: Icons.phone_rounded),
  ModernIcon(id: 'email', label: 'Email', category: 'business', icon: Icons.email_rounded),
  ModernIcon(id: 'link', label: 'Link', category: 'business', icon: Icons.link_rounded),
  ModernIcon(id: 'qr', label: 'QR Code', category: 'business', icon: Icons.qr_code_rounded),
  ModernIcon(id: 'scan', label: 'QR Scan', category: 'business', icon: Icons.qr_code_scanner_rounded),
  ModernIcon(id: 'print', label: 'Print', category: 'business', icon: Icons.print_rounded),
  ModernIcon(id: 'download', label: 'Download', category: 'business', icon: Icons.download_rounded),
  ModernIcon(id: 'upload', label: 'Upload', category: 'business', icon: Icons.upload_rounded),
  ModernIcon(id: 'copy', label: 'Copy', category: 'business', icon: Icons.content_copy_rounded),
  ModernIcon(id: 'edit', label: 'Edit', category: 'business', icon: Icons.edit_rounded),
  ModernIcon(id: 'delete', label: 'Delete', category: 'business', icon: Icons.delete_rounded),
  ModernIcon(id: 'save', label: 'Save', category: 'business', icon: Icons.save_rounded),
  ModernIcon(id: 'bookmark', label: 'Bookmark', category: 'business', icon: Icons.bookmark_rounded),
];

// ---------------------------------------------------------------------------
// UI & Navigation
// ---------------------------------------------------------------------------
const _uiIcons = <ModernIcon>[
  ModernIcon(id: 'arrow_up', label: 'Arrow Up', category: 'ui', icon: Icons.arrow_upward_rounded),
  ModernIcon(id: 'arrow_down', label: 'Arrow Down', category: 'ui', icon: Icons.arrow_downward_rounded),
  ModernIcon(id: 'arrow_left', label: 'Arrow Left', category: 'ui', icon: Icons.arrow_back_rounded),
  ModernIcon(id: 'arrow_right', label: 'Arrow Right', category: 'ui', icon: Icons.arrow_forward_rounded),
  ModernIcon(id: 'chevron_up', label: 'Chevron Up', category: 'ui', icon: Icons.expand_less_rounded),
  ModernIcon(id: 'chevron_down', label: 'Chevron Down', category: 'ui', icon: Icons.expand_more_rounded),
  ModernIcon(id: 'chevron_left', label: 'Chevron Left', category: 'ui', icon: Icons.chevron_left_rounded),
  ModernIcon(id: 'chevron_right', label: 'Chevron Right', category: 'ui', icon: Icons.chevron_right_rounded),
  ModernIcon(id: 'plus', label: 'Plus', category: 'ui', icon: Icons.add_rounded),
  ModernIcon(id: 'minus', label: 'Minus', category: 'ui', icon: Icons.remove_rounded),
  ModernIcon(id: 'check', label: 'Check', category: 'ui', icon: Icons.check_rounded),
  ModernIcon(id: 'check_circle', label: 'Check Circle', category: 'ui', icon: Icons.check_circle_rounded),
  ModernIcon(id: 'close', label: 'Close', category: 'ui', icon: Icons.close_rounded),
  ModernIcon(id: 'menu', label: 'Menu', category: 'ui', icon: Icons.menu_rounded),
  ModernIcon(id: 'search', label: 'Search', category: 'ui', icon: Icons.search_rounded),
  ModernIcon(id: 'filter', label: 'Filter', category: 'ui', icon: Icons.filter_list_rounded),
  ModernIcon(id: 'sort', label: 'Sort', category: 'ui', icon: Icons.sort_rounded),
  ModernIcon(id: 'more', label: 'More', category: 'ui', icon: Icons.more_vert_rounded),
  ModernIcon(id: 'settings', label: 'Settings', category: 'ui', icon: Icons.settings_rounded),
  ModernIcon(id: 'info', label: 'Info', category: 'ui', icon: Icons.info_rounded),
  ModernIcon(id: 'help', label: 'Help', category: 'ui', icon: Icons.help_rounded),
  ModernIcon(id: 'warning', label: 'Warning', category: 'ui', icon: Icons.warning_rounded),
  ModernIcon(id: 'error', label: 'Error', category: 'ui', icon: Icons.error_rounded),
];

// ---------------------------------------------------------------------------
// Seasonal & Decorative
// ---------------------------------------------------------------------------
const _seasonalIcons = <ModernIcon>[
  ModernIcon(id: 'moon', label: 'Moon', category: 'seasonal', icon: Icons.nightlight_rounded),
  ModernIcon(id: 'sun', label: 'Sun', category: 'seasonal', icon: Icons.wb_sunny_rounded),
  ModernIcon(id: 'cloud', label: 'Cloud', category: 'seasonal', icon: Icons.cloud_rounded),
  ModernIcon(id: 'rain', label: 'Rain', category: 'seasonal', icon: Icons.water_drop_rounded),
  ModernIcon(id: 'fire', label: 'Fire', category: 'seasonal', icon: Icons.local_fire_department_rounded),
  ModernIcon(id: 'flower', label: 'Flower', category: 'seasonal', icon: Icons.local_florist_rounded),
  ModernIcon(id: 'tree', label: 'Tree', category: 'seasonal', icon: Icons.park_rounded),
  ModernIcon(id: 'beach', label: 'Beach', category: 'seasonal', icon: Icons.beach_access_rounded),
  ModernIcon(id: 'umbrella', label: 'Umbrella', category: 'seasonal', icon: Icons.beach_access_rounded),
  ModernIcon(id: 'snow', label: 'Snow', category: 'seasonal', icon: Icons.ac_unit_rounded),
  ModernIcon(id: 'lightning', label: 'Lightning', category: 'seasonal', icon: Icons.bolt_rounded),
  ModernIcon(id: 'celebration', label: 'Celebration', category: 'seasonal', icon: Icons.celebration_rounded),
  ModernIcon(id: 'cake', label: 'Cake', category: 'seasonal', icon: Icons.cake_rounded),
  ModernIcon(id: 'balloon', label: 'Balloon', category: 'seasonal', icon: Icons.party_mode_rounded),
  ModernIcon(id: 'music', label: 'Music', category: 'seasonal', icon: Icons.music_note_rounded),
];

// ---------------------------------------------------------------------------
// Combined registry
// ---------------------------------------------------------------------------
List<ModernIcon> get allModernIcons => [
  ..._commerceIcons,
  ..._socialIcons,
  ..._businessIcons,
  ..._uiIcons,
  ..._seasonalIcons,
];

Map<String, List<ModernIcon>> get modernIconsByCategory {
  final map = <String, List<ModernIcon>>{};
  for (final icon in allModernIcons) {
    map.putIfAbsent(icon.category, () => []).add(icon);
  }
  return map;
}

ModernIcon? modernIconById(String id) {
  for (final icon in allModernIcons) {
    if (icon.id == id) return icon;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

/// A brand-tinted modern icon widget.
class BrandTintedIcon extends StatelessWidget {
  const BrandTintedIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 24,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}

/// Converts a modern icon to a CanvasElement for insertion into designs.
CanvasElement modernIconToCanvasElement(ModernIcon icon, {
  required String id,
  double x = 0,
  double y = 0,
  double size = 80,
  Color? color,
}) {
  return CanvasElement(
    id: id,
    type: 'icon',
    x: x,
    y: y,
    width: size,
    height: size,
    iconCodePoint: icon.icon.codePoint,
    iconFontFamily: icon.icon.fontFamily,
    iconFontPackage: icon.icon.fontPackage,
    fill: color != null ? colorToHex(color) : '#ffffff',
  );
}
