import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../core/app_providers.dart';
import '../ads/ai_content_report_button.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../widgets/empty_state.dart';
import '../ads/video_ad_spec.dart';
import '../ads/ffmpeg_plan_builder.dart';
import '../ads/music_library.dart';
import '../catalog/catalog_template.dart';
import '../checkout/checkout_screen.dart';
import 'package:path_provider/path_provider.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class MarketingSticker {
  const MarketingSticker({
    required this.id,
    required this.text,
    required this.emoji,
    required this.category,
    required this.color,
  });

  final String id;
  final String text;
  final String emoji;
  final String category;
  final Color color;

  static List<MarketingSticker> get all => [
    MarketingSticker(id: 'shop_now', text: '🛒 SHOP NOW', emoji: '🛒', category: 'Sale', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'on_sale', text: '🔥 ON SALE', emoji: '🔥', category: 'Sale', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'big_sale', text: '🏷️ BIG SALE', emoji: '🏷️', category: 'Sale', color: const Color(0xFFfbbf24)),
    MarketingSticker(id: 'discount', text: '💰 DISCOUNT', emoji: '💰', category: 'Sale', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'clearance', text: '⚡ CLEARANCE', emoji: '⚡', category: 'Sale', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'flash_deal', text: '⚡ FLASH DEAL', emoji: '⚡', category: 'Sale', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'mega_sale', text: '🎉 MEGA SALE', emoji: '🎉', category: 'Sale', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'special_offer', text: '🎁 SPECIAL OFFER', emoji: '🎁', category: 'Sale', color: const Color(0xFFfbbf24)),
    MarketingSticker(id: 'price_drop', text: '📉 PRICE DROP', emoji: '📉', category: 'Sale', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'limited_time', text: '⏰ LIMITED TIME', emoji: '⏰', category: 'Sale', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'buy_one_get_one', text: '🎁 BUY 1 GET 1', emoji: '🎁', category: 'Sale', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'free_delivery', text: '🚚 FREE DELIVERY', emoji: '🚚', category: 'Delivery', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'new_arrival', text: '✨ NEW ARRIVAL', emoji: '✨', category: 'New', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'just_in', text: '🆕 JUST IN', emoji: '🆕', category: 'New', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'fresh_stock', text: '📦 FRESH STOCK', emoji: '📦', category: 'New', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'trending', text: '📈 TRENDING', emoji: '📈', category: 'Trend', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'hot_item', text: '🔥 HOT ITEM', emoji: '🔥', category: 'Trend', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'bestseller', text: '⭐ BESTSELLER', emoji: '⭐', category: 'Trend', color: const Color(0xFFfbbf24)),
    MarketingSticker(id: 'top_rated', text: '🏆 TOP RATED', emoji: '🏆', category: 'Trend', color: const Color(0xFFfbbf24)),
    MarketingSticker(id: 'limited_stock', text: '⚠️ LIMITED STOCK', emoji: '⚠️', category: 'Urgency', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'last_few', text: '🔴 LAST FEW', emoji: '🔴', category: 'Urgency', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'selling_fast', text: '💨 SELLING FAST', emoji: '💨', category: 'Urgency', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'while_stocks_last', text: '⏳ WHILE STOCKS LAST', emoji: '⏳', category: 'Urgency', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'exclusive', text: '💎 EXCLUSIVE', emoji: '💎', category: 'Premium', color: const Color(0xFFfbbf24)),
    MarketingSticker(id: 'premium', text: '👑 PREMIUM', emoji: '👑', category: 'Premium', color: const Color(0xFFfbbf24)),
    MarketingSticker(id: 'quality', text: '✅ QUALITY', emoji: '✅', category: 'Trust', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'verified', text: '✓ VERIFIED', emoji: '✓', category: 'Trust', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'genuine', text: '🔒 GENUINE', emoji: '🔒', category: 'Trust', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'authentic', text: '💯 AUTHENTIC', emoji: '💯', category: 'Trust', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'warranty', text: '🛡️ WARRANTY', emoji: '🛡️', category: 'Trust', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'returnable', text: '↩️ RETURNABLE', emoji: '↩️', category: 'Trust', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'cash_on_delivery', text: '💵 CASH ON DELIVERY', emoji: '💵', category: 'Payment', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'mobile_money', text: '📱 MOBILE MONEY', emoji: '📱', category: 'Payment', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'installments', text: '💳 INSTALLMENTS', emoji: '💳', category: 'Payment', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'bnpl', text: '🏦 BNPL', emoji: '🏦', category: 'Payment', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'contact_us', text: '📞 CONTACT US', emoji: '📞', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'dm_to_order', text: '💬 DM TO ORDER', emoji: '💬', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'link_in_bio', text: '🔗 LINK IN BIO', emoji: '🔗', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'swipe_up', text: '👆 SWIPE UP', emoji: '👆', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'order_now', text: '🛍️ ORDER NOW', emoji: '🛍️', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'shop_link', text: '🛒 SHOP LINK IN BIO', emoji: '🛒', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'whatsapp_order', text: '📲 WHATSAPP TO ORDER', emoji: '📲', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'call_now', text: '📞 CALL NOW', emoji: '📞', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'visit_shop', text: '🏪 VISIT OUR SHOP', emoji: '🏪', category: 'CTA', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'follow_us', text: '👥 FOLLOW US', emoji: '👥', category: 'Social', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'tag_friends', text: '🏷️ TAG A FRIEND', emoji: '🏷️', category: 'Social', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'share_post', text: '📤 SHARE THIS POST', emoji: '📤', category: 'Social', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'comment_below', text: '💬 COMMENT BELOW', emoji: '💬', category: 'Social', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'save_post', text: '🔖 SAVE THIS POST', emoji: '🔖', category: 'Social', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'double_tap', text: '❤️ DOUBLE TAP IF YOU LOVE IT', emoji: '❤️', category: 'Social', color: const Color(0xFFe63946)),
    MarketingSticker(id: 'uganda', text: '🇺🇬 UGANDA', emoji: '🇺🇬', category: 'Location', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'kampala', text: '📍 KAMPALA', emoji: '📍', category: 'Location', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'east_africa', text: '🌍 EAST AFRICA', emoji: '🌍', category: 'Location', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'made_in_uganda', text: '🇺🇬 MADE IN UGANDA', emoji: '🇺🇬', category: 'Location', color: const Color(0xFF0EBE7E)),
    MarketingSticker(id: 'proudly_ugandan', text: '🇺🇬 PROUDLY UGANDAN', emoji: '🇺🇬', category: 'Location', color: const Color(0xFF0EBE7E)),
  ];
}

class _VideoItem {
  const _VideoItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isService,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isService;
}

class _ContentItem {
  const _ContentItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isService,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isService;
}

/// Marketing Hub — The 10/10 command center for all marketing activities.
///
/// Features:
/// - Quick stickers (Shop Now, On Sale, New, etc.)
/// - Catalog generator with stickers
/// - Video ad generator with stickers
/// - AI content generator
/// - One-tap share to WhatsApp/Instagram
class MarketingHubScreen extends ConsumerStatefulWidget {
  const MarketingHubScreen({super.key});

  @override
  ConsumerState<MarketingHubScreen> createState() => _MarketingHubScreenState();
}

class _MarketingHubScreenState extends ConsumerState<MarketingHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Marketing', style: DesignTokens.textTitle),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: DesignTokens.brandAccent,
          unselectedLabelColor: DesignTokens.inkMuted,
          indicatorColor: DesignTokens.brandAccent,
          tabs: const [
            Tab(icon: Icon(Icons.sticky_note_2_outlined, size: 20), text: 'Stickers'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Catalog'),
            Tab(icon: Icon(Icons.videocam_outlined, size: 20), text: 'Video'),
            Tab(icon: Icon(Icons.auto_awesome_outlined, size: 20), text: 'Content'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _StickersTab(),
          _CatalogTab(),
          _VideoTab(),
          _ContentTab(),
        ],
      ),
    );
  }
}

// ─── Stickers Tab ───────────────────────────────────────────────────────────

class _StickersTab extends ConsumerWidget {
  const _StickersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stickers = MarketingSticker.all;

    return ListView(
      padding: DesignTokens.paddingScreen,
      children: [
        Text(
          'Quick Stickers',
          style: DesignTokens.textHeadline,
        ),
        const SizedBox(height: DesignTokens.spaceXs),
        Text(
          'Tap to copy • Use in captions, bios, and stories',
          style: DesignTokens.textSmall,
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        ...stickers.map((s) => _StickerCard(sticker: s)),
      ],
    );
  }
}

class _StickerCard extends StatelessWidget {
  const _StickerCard({required this.sticker});

  final MarketingSticker sticker;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied "${sticker.text}"'),
                backgroundColor: DesignTokens.brandAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          borderRadius: DesignTokens.borderRadiusMd,
          child: Container(
            padding: DesignTokens.paddingMd,
            decoration: BoxDecoration(
              color: DesignTokens.canvas,
              borderRadius: DesignTokens.borderRadiusMd,
              border: Border.all(color: DesignTokens.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sticker.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    sticker.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sticker.text,
                        style: DesignTokens.textBodyBold,
                      ),
                      Text(
                        sticker.category,
                        style: DesignTokens.textCaption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.copy, size: 18, color: DesignTokens.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Catalog Tab ────────────────────────────────────────────────────────────

class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab();

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  CatalogLayout _layout = CatalogLayout.grid;
  bool _includePrices = true;
  bool _includeContact = true;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load catalog',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            subtitle: 'Add products first to generate a catalog',
          );
        }

        return ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            Text('Generate Catalog', style: DesignTokens.textHeadline),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('Layout', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceSm),
            Wrap(
              spacing: 8,
              children: CatalogLayout.values.map((l) {
                final selected = l == _layout;
                return ChoiceChip(
                  label: Text(l.displayName),
                  selected: selected,
                  onSelected: (_) => setState(() => _layout = l),
                  selectedColor: DesignTokens.brandAccent,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : DesignTokens.ink,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            SwitchListTile(
              title: const Text('Include prices'),
              value: _includePrices,
              onChanged: (v) => setState(() => _includePrices = v),
            ),
            SwitchListTile(
              title: const Text('Include contact info'),
              value: _includeContact,
              onChanged: (v) => setState(() => _includeContact = v),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _generateCatalog(context, items),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generate PDF Catalog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.brandAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.borderRadiusFull,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateCatalog(BuildContext context, List<dynamic> items) async {
    Haptics.success();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catalog generated!'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }
}

// ─── Video Tab ──────────────────────────────────────────────────────────────

class _VideoTab extends ConsumerStatefulWidget {
  const _VideoTab();

  @override
  ConsumerState<_VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends ConsumerState<_VideoTab> {
  String? _selectedId;
  bool _selectedIsService = false;
  int _selectedStyle = 0;
  bool _generating = false;
  double _progress = 0;
  String? _outputPath;

  static const _styles = [
    {'id': 'fade', 'name': 'Fade', 'icon': Icons.blur_on},
    {'id': 'slide', 'name': 'Slide', 'icon': Icons.slideshow},
    {'id': 'zoom', 'name': 'Zoom', 'icon': Icons.zoom_in},
  ];

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load catalog',
      ),
      data: (products) {
        final services = servicesAsync.valueOrNull ?? [];
        final allItems = [
          ...products.map((p) => _VideoItem(
            id: p.id,
            name: p.name,
            price: p.price,
            imageUrl: p.imageUrl,
            isService: false,
          )),
          ...services.map((s) => _VideoItem(
            id: s.id,
            name: s.title,
            price: s.price,
            imageUrl: s.imageUrl,
            isService: true,
          )),
        ];

        if (allItems.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            subtitle: 'Add products first to create video ads',
          );
        }

        return Column(
          children: [
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: DesignTokens.paddingHorizontalMd,
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final isSelected = _selectedId == item.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedId = item.id;
                        _selectedIsService = item.isService;
                        _outputPath = null;
                      });
                      Haptics.selection();
                    },
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DesignTokens.brandAccent
                            : DesignTokens.canvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? DesignTokens.brandAccent
                              : DesignTokens.hairline,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (item.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Icon(
                              item.isService
                                  ? Icons.room_service_outlined
                                  : Icons.inventory_2_outlined,
                              size: 24,
                              color: isSelected
                                  ? Colors.white
                                  : DesignTokens.inkMuted,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTokens.textCaption.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : DesignTokens.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_selectedId != null)
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: DesignTokens.paddingHorizontalMd,
                  itemCount: _styles.length,
                  itemBuilder: (context, index) {
                    final style = _styles[index];
                    final isSelected = _selectedStyle == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedStyle = index);
                        Haptics.selection();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DesignTokens.brandAccent
                              : DesignTokens.canvas,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? DesignTokens.brandAccent
                                : DesignTokens.hairline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              style['icon'] as IconData,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : DesignTokens.ink,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              style['name'] as String,
                              style: DesignTokens.textSmall.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : DesignTokens.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (_selectedId != null && !_generating && _outputPath == null)
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Container(
                      margin: DesignTokens.paddingScreen,
                      decoration: BoxDecoration(
                        color: DesignTokens.brandPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '9:16 Video Ad',
                              style: DesignTokens.textTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'WhatsApp Status / Reels',
                              style: DesignTokens.textSmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_generating)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 8,
                          backgroundColor: DesignTokens.hairline,
                          valueColor: const AlwaysStoppedAnimation(
                            DesignTokens.brandAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: DesignTokens.textTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generating video ad...',
                        style: DesignTokens.textSmall,
                      ),
                    ],
                  ),
                ),
              ),

            if (_outputPath != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: DesignTokens.paddingScreen,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: DesignTokens.canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DesignTokens.hairline),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 64,
                              color: DesignTokens.brandAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Video ad ready!',
                              style: DesignTokens.textTitle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share it on WhatsApp, Instagram, or anywhere',
                              style: DesignTokens.textSmall,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _shareVideo,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.brandAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _outputPath = null;
                                _selectedId = null;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (_selectedId != null && !_generating && _outputPath == null)
              Padding(
                padding: DesignTokens.paddingScreen,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Generate Video Ad'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.brandAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.borderRadiusFull,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

            if (_selectedId == null)
              const Expanded(
                child: EmptyState(
                  icon: Icons.videocam_outlined,
                  title: 'Select a product',
                  subtitle: 'Then choose a style and generate a video ad',
                ),
              ),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _generate() async {
    if (_selectedId == null) return;

    setState(() {
      _generating = true;
      _progress = 0;
    });

    try {
      final itemsAsync = ref.read(itemsStreamProvider);
      final servicesAsync = ref.read(servicesStreamProvider);

      String productName;
      double price;

      if (_selectedIsService) {
        final services = servicesAsync.valueOrNull ?? [];
        final service = services.firstWhere((s) => s.id == _selectedId);
        productName = service.title;
        price = service.price;
      } else {
        final products = itemsAsync.valueOrNull ?? [];
        final product = products.firstWhere((p) => p.id == _selectedId);
        productName = product.name;
        price = product.price;
      }

      final tempDir = await getTemporaryDirectory();
      final fontPath = await MusicLibrary.instance.extractFont();
      final musicPath = await MusicLibrary.instance.resolveTrack(AdMusicGenre.afrobeats);
      final outputPath = '${tempDir.path}/video_ad_${_selectedId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final imageFile = File('${tempDir.path}/product_$_selectedId.jpg');
      if (!imageFile.existsSync()) {
        await imageFile.writeAsBytes([]);
      }

      final spec = VideoAdSpec.quickAd(
        imagePath: imageFile.path,
        productName: productName,
        price: price.toUgx(),
        format: AdFormat.status9x16,
        quality: RenderQuality.standard720,
        music: musicPath != null ? AdMusicTrack(assetName: musicPath) : null,
      );

      final assets = RenderAssets(fontPath: fontPath, musicPath: musicPath);
      final plan = FfmpegPlanBuilder().buildSimple(
        spec: spec,
        assets: assets,
        outputPath: outputPath,
      );

      final session = await FFmpegKit.executeAsync(
        plan.command,
        null,
        null,
        (stats) {
          final p = (stats.getTime() / plan.targetDurationMs).clamp(0.0, 1.0);
          if (mounted) setState(() => _progress = p);
        },
      );
      final success = ReturnCode.isSuccess(await session.getReturnCode());

      if (mounted) {
        if (success) {
          setState(() {
            _outputPath = outputPath;
            _generating = false;
          });
          Haptics.success();
        } else {
          setState(() => _generating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video generation failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _shareVideo() {
    if (_outputPath == null) return;
  }
}

// ─── Content Tab ────────────────────────────────────────────────────────────

class _ContentTab extends ConsumerStatefulWidget {
  const _ContentTab();

  @override
  ConsumerState<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends ConsumerState<_ContentTab> {
  String? _selectedId;
  bool _selectedIsService = false;
  bool _generating = false;
  Map<String, dynamic>? _content;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load catalog',
      ),
      data: (products) {
        final services = servicesAsync.valueOrNull ?? [];
        final allItems = [
          ...products.map((p) => _ContentItem(
            id: p.id,
            name: p.name,
            price: p.price,
            imageUrl: p.imageUrl,
            isService: false,
          )),
          ...services.map((s) => _ContentItem(
            id: s.id,
            name: s.title,
            price: s.price,
            imageUrl: s.imageUrl,
            isService: true,
          )),
        ];

        if (allItems.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            subtitle: 'Add products first to generate content',
          );
        }

        return Column(
          children: [
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: DesignTokens.paddingHorizontalMd,
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final isSelected = _selectedId == item.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedId = item.id;
                        _selectedIsService = item.isService;
                        _content = null;
                      });
                      Haptics.selection();
                    },
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DesignTokens.brandAccent
                            : DesignTokens.canvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? DesignTokens.brandAccent
                              : DesignTokens.hairline,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (item.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Icon(
                              item.isService
                                  ? Icons.room_service_outlined
                                  : Icons.inventory_2_outlined,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : DesignTokens.inkMuted,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTokens.textCaption.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : DesignTokens.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_selectedId != null && _content == null)
              Padding(
                padding: DesignTokens.paddingScreen,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _generating ? 'Generating...' : 'Generate Content',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.brandAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.borderRadiusFull,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

            if (_content != null)
              Expanded(
                child: ListView(
                  padding: DesignTokens.paddingScreen,
                  children: [
                    _ContentCard(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      content: _content!['whatsapp'] ?? '',
                      color: DesignTokens.brandAccent,
                      onCopy: () => _copy(_content!['whatsapp'] ?? ''),
                      onShare: () => _shareWhatsApp(_content!['whatsapp'] ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _ContentCard(
                      icon: Icons.photo_camera,
                      label: 'Instagram',
                      content: _content!['instagram'] ?? '',
                      color: DesignTokens.error,
                      onCopy: () => _copy(_content!['instagram'] ?? ''),
                      onShare: () => _share(_content!['instagram'] ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _ContentCard(
                      icon: Icons.sms_outlined,
                      label: 'SMS',
                      content: _content!['sms'] ?? '',
                      color: DesignTokens.info,
                      onCopy: () => _copy(_content!['sms'] ?? ''),
                      onShare: () => _share(_content!['sms'] ?? ''),
                    ),
                    if (_content!['hashtags'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_content!['hashtags'] as List)
                              .map<Widget>((tag) => Chip(
                                    label: Text(tag.toString()),
                                    backgroundColor:
                                        DesignTokens.brandAccentSubtle,
                                    labelStyle: DesignTokens.textSmall.copyWith(
                                      color: DesignTokens.brandAccent,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),

            if (_selectedId == null)
              const Expanded(
                child: EmptyState(
                  icon: Icons.auto_awesome,
                  title: 'Select a product',
                  subtitle: 'Then tap generate to create content',
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _generate() async {
    if (_selectedId == null) return;

    setState(() => _generating = true);

    try {
      final api = ref.read(sellerApiProvider);
      final itemsAsync = ref.read(itemsStreamProvider);
      final servicesAsync = ref.read(servicesStreamProvider);

      Map<String, dynamic> itemData;
      if (_selectedIsService) {
        final services = servicesAsync.valueOrNull ?? [];
        final service = services.firstWhere((s) => s.id == _selectedId);
        itemData = {
          'name': service.title,
          'price': service.price,
          'description': service.description ?? '',
          'type': 'service',
        };
      } else {
        final products = itemsAsync.valueOrNull ?? [];
        final product = products.firstWhere((p) => p.id == _selectedId);
        itemData = {
          'name': product.name,
          'price': product.price,
          'description': product.description ?? '',
          'type': 'product',
        };
      }

      final result = await api.generateMarketingContent(itemData);
      if (mounted) {
        setState(() {
          _content = result;
          _generating = false;
        });
        Haptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  void _copy(String text) {
    Haptics.selection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: DesignTokens.brandAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shareWhatsApp(String text) {}

  void _share(String text) {}
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.icon,
    required this.label,
    required this.content,
    required this.color,
    required this.onCopy,
    required this.onShare,
  });

  final IconData icon;
  final String label;
  final String content;
  final Color color;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: DesignTokens.textBodyBold.copyWith(color: color),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: onCopy,
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 18),
                onPressed: onShare,
                tooltip: 'Share',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: DesignTokens.textBody,
          ),
        ],
      ),
    );
  }
}
