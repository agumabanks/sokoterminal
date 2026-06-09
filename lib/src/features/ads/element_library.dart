import 'package:flutter/material.dart';

import 'ad_templates.dart';

// ---------------------------------------------------------------------------
// Built-in element presets
// ---------------------------------------------------------------------------

final _shapeElements = <CanvasElement>[
  CanvasElement(id: 'el_rect', type: 'figure', width: 200, height: 200, fill: '#0EBE7E', cornerRadius: 0),
  CanvasElement(id: 'el_round_rect', type: 'figure', width: 200, height: 200, fill: '#3b82f6', cornerRadius: 24),
  CanvasElement(id: 'el_circle', type: 'figure', width: 200, height: 200, fill: '#f59e0b', cornerRadius: 100),
  CanvasElement(id: 'el_pill', type: 'figure', width: 300, height: 100, fill: '#dc2626', cornerRadius: 50),
  CanvasElement(id: 'el_line', type: 'figure', width: 400, height: 6, fill: '#ffffff', cornerRadius: 3),
  CanvasElement(id: 'el_thin_line', type: 'figure', width: 400, height: 2, fill: '#ffffff', cornerRadius: 1, opacity: 0.4),
  CanvasElement(id: 'el_dot', type: 'figure', width: 40, height: 40, fill: '#0EBE7E', cornerRadius: 20),
  CanvasElement(id: 'el_bar', type: 'figure', width: 60, height: 180, fill: '#6366f1', cornerRadius: 8),
];

final _badgeElements = <CanvasElement>[
  CanvasElement(id: 'badge_sale', type: 'figure', width: 200, height: 80, fill: '#dc2626', cornerRadius: 40),
  CanvasElement(id: 'badge_new', type: 'figure', width: 200, height: 80, fill: '#f59e0b', cornerRadius: 40),
  CanvasElement(id: 'badge_hot', type: 'figure', width: 200, height: 80, fill: '#f97316', cornerRadius: 40),
  CanvasElement(id: 'badge_free', type: 'figure', width: 200, height: 80, fill: '#0EBE7E', cornerRadius: 40),
  CanvasElement(id: 'badge_limited', type: 'figure', width: 240, height: 80, fill: '#7c3aed', cornerRadius: 40),
  CanvasElement(id: 'badge_premium', type: 'figure', width: 240, height: 80, fill: '#d4af37', cornerRadius: 40),
];

final _textElements = <CanvasElement>[
  CanvasElement(id: 'text_headline', type: 'text', text: 'HEADLINE', width: 700, fontSize: 72, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
  CanvasElement(id: 'text_subheadline', type: 'text', text: 'Subheadline goes here', width: 700, fontSize: 36, fontFamily: 'Poppins', fill: '#ffffff', align: 'center'),
  CanvasElement(id: 'text_body', type: 'text', text: 'Body copy. Describe your product or offer in 1-2 lines.', width: 700, fontSize: 24, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.85),
  CanvasElement(id: 'text_price', type: 'text', text: 'UGX 99,000', width: 500, fontSize: 56, fontWeight: 'bold', fontFamily: 'Inter', fill: '#fef08a', align: 'center'),
  CanvasElement(id: 'text_cta', type: 'text', text: 'SHOP NOW', width: 360, fontSize: 28, fontWeight: 'bold', fontFamily: 'Inter', fill: '#ffffff', align: 'center'),
  CanvasElement(id: 'text_badge_label', type: 'text', text: 'NEW', width: 200, fontSize: 32, fontWeight: 'bold', fontFamily: 'Oswald', fill: '#ffffff', align: 'center'),
  CanvasElement(id: 'text_caption', type: 'text', text: 'soko24.co', width: 400, fontSize: 18, fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.5),
  CanvasElement(id: 'text_script', type: 'text', text: 'Special Offer', width: 500, fontSize: 52, fontFamily: 'Pacifico', fill: '#fbbf24', align: 'center'),
];

// Icons expressed as figure + emoji text overlaid
final _stickerElements = <CanvasElement>[
  CanvasElement(id: 'stk_fire', type: 'text', text: '🔥', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_star', type: 'text', text: '⭐', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_sparkle', type: 'text', text: '✨', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_heart', type: 'text', text: '❤️', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_check', type: 'text', text: '✅', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_gift', type: 'text', text: '🎁', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_party', type: 'text', text: '🎉', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_money', type: 'text', text: '💰', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_cart', type: 'text', text: '🛒', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_bag', type: 'text', text: '🛍️', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_phone', type: 'text', text: '📱', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_chat', type: 'text', text: '💬', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_truck', type: 'text', text: '🚚', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_food', type: 'text', text: '🍔', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_coffee', type: 'text', text: '☕', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_new', type: 'text', text: '🆕', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_sale', type: 'text', text: '🏷️', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_trophy', type: 'text', text: '🏆', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_100', type: 'text', text: '💯', width: 120, fontSize: 72, align: 'center'),
  CanvasElement(id: 'stk_point', type: 'text', text: '👆', width: 120, fontSize: 72, align: 'center'),
];

final _iconElements = <_IconPreset>[
  _IconPreset(Icons.star_rounded,        '#f59e0b', 'Star'),
  _IconPreset(Icons.favorite_rounded,    '#ec4899', 'Heart'),
  _IconPreset(Icons.local_offer_rounded, '#dc2626', 'Tag'),
  _IconPreset(Icons.bolt_rounded,        '#fbbf24', 'Bolt'),
  _IconPreset(Icons.diamond_rounded,     '#a855f7', 'Diamond'),
  _IconPreset(Icons.thumb_up_rounded,    '#0EBE7E', 'Like'),
  _IconPreset(Icons.verified_rounded,    '#3b82f6', 'Verified'),
  _IconPreset(Icons.fire_truck,          '#f97316', 'Hot'),
  _IconPreset(Icons.emoji_events_rounded,'#d4af37', 'Trophy'),
  _IconPreset(Icons.shopping_bag_rounded,'#6366f1', 'Bag'),
  _IconPreset(Icons.delivery_dining_rounded, '#0EBE7E', 'Delivery'),
  _IconPreset(Icons.percent_rounded,     '#dc2626', 'Percent'),
];

class _IconPreset {
  const _IconPreset(this.icon, this.color, this.label);
  final IconData icon;
  final String color;
  final String label;
}

// ---------------------------------------------------------------------------
// Element Library Panel
// ---------------------------------------------------------------------------

class ElementLibraryPanel extends StatefulWidget {
  const ElementLibraryPanel({super.key, required this.onInsert});
  final ValueChanged<CanvasElement> onInsert;

  @override
  State<ElementLibraryPanel> createState() => _ElementLibraryPanelState();
}

class _ElementLibraryPanelState extends State<ElementLibraryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1A35),
      constraints: const BoxConstraints(maxHeight: 240),
      child: Column(
        children: [
          TabBar(
            controller: _tc,
            labelColor: const Color(0xFF0EBE7E),
            unselectedLabelColor: Colors.white38,
            indicatorColor: const Color(0xFF0EBE7E),
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(text: 'Shapes'),
              Tab(text: 'Badges'),
              Tab(text: 'Text'),
              Tab(text: 'Icons'),
              Tab(text: 'Stickers'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                _ShapesGrid(elements: _shapeElements, onInsert: widget.onInsert),
                _ShapesGrid(elements: _badgeElements, onInsert: widget.onInsert, showLabel: true),
                _TextGrid(elements: _textElements, onInsert: widget.onInsert),
                _IconGrid(presets: _iconElements, onInsert: widget.onInsert),
                _TextGrid(elements: _stickerElements, onInsert: widget.onInsert),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shapes / Badges grid
// ---------------------------------------------------------------------------

class _ShapesGrid extends StatelessWidget {
  const _ShapesGrid({
    required this.elements,
    required this.onInsert,
    this.showLabel = false,
  });

  final List<CanvasElement> elements;
  final ValueChanged<CanvasElement> onInsert;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: elements.length,
      itemBuilder: (_, i) {
        final el = elements[i];
        return GestureDetector(
          onTap: () => onInsert(el),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: parseHexColor(el.fill ?? '#ffffff'),
                    borderRadius: el.cornerRadius != null
                        ? BorderRadius.circular(
                            (el.cornerRadius! * 60 / (el.width > 0 ? el.width : 1)).clamp(0, 30))
                        : null,
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(height: 4),
                  Text(
                    _badgeLabelFor(el.id),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _badgeLabelFor(String id) {
    return id.replaceAll('badge_', '').toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Text grid
// ---------------------------------------------------------------------------

class _TextGrid extends StatelessWidget {
  const _TextGrid({required this.elements, required this.onInsert});
  final List<CanvasElement> elements;
  final ValueChanged<CanvasElement> onInsert;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: elements.length,
      itemBuilder: (_, i) {
        final el = elements[i];
        return GestureDetector(
          onTap: () => onInsert(el),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  el.text ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _scaleFont(el.fontSize ?? 24),
                    fontWeight: el.fontWeight == 'bold'
                        ? FontWeight.bold
                        : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  el.fontFamily ?? 'Inter',
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _scaleFont(double size) => (size / 5).clamp(10, 24).toDouble();
}

// ---------------------------------------------------------------------------
// Icon grid
// ---------------------------------------------------------------------------

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.presets, required this.onInsert});
  final List<_IconPreset> presets;
  final ValueChanged<CanvasElement> onInsert;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: presets.length,
      itemBuilder: (_, i) {
        final p = presets[i];
        return GestureDetector(
          onTap: () {
            // Insert as a figure (circle colored) with a text overlay
            // The canvas renderer will render the figure; icon overlay is cosmetic
            onInsert(CanvasElement(
              id: 'icon_${p.label.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
              type: 'figure',
              width: 120, height: 120,
              fill: p.color,
              cornerRadius: 60,
            ));
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: parseHexColor(p.color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: parseHexColor(p.color).withValues(alpha: 0.3)),
                  ),
                  child: Icon(p.icon, color: parseHexColor(p.color), size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  p.label,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
