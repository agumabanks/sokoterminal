import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'creative_asset_catalog.dart';
import 'creative_overlay_catalog.dart';
import 'studio_entitlements.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Creative Library — stickers, icons, illustrations, variable words, magic
// ---------------------------------------------------------------------------

class CreativeLibraryPanel extends ConsumerStatefulWidget {
  const CreativeLibraryPanel({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.currentBackground,
    this.product,
    required this.onInsert,
    required this.onInsertGroup,
    required this.onApplyBackground,
  });

  final double canvasWidth;
  final double canvasHeight;
  final String currentBackground;
  final Item? product;
  final ValueChanged<CanvasElement> onInsert;
  final void Function(List<CanvasElement> elements, String background) onInsertGroup;
  final ValueChanged<String> onApplyBackground;

  @override
  ConsumerState<CreativeLibraryPanel> createState() =>
      _CreativeLibraryPanelState();
}

class _CreativeLibraryPanelState extends ConsumerState<CreativeLibraryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  bool _canUsePremium(AsyncValue<StudioEntitlements> ent) {
    final e = ent.valueOrNull;
    if (e == null) return false;
    return !e.needsSokoWatermark;
  }

  void _tryInsert(CreativeAsset asset, bool canPremium) {
    if (asset.isPremium && !canPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgrade to Growth/Pro to unlock premium creative assets ✨'),
        ),
      );
      return;
    }
    widget.onInsert(asset.element);
  }

  @override
  Widget build(BuildContext context) {
    final ent = ref.watch(studioEntitlementsProvider);
    final canPremium = _canUsePremium(ent);
    final magic = magicLayoutsForCanvas(widget.canvasWidth, widget.canvasHeight);

    return Container(
      color: DesignTokens.brandPrimary,
      constraints: const BoxConstraints(maxHeight: 260),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: DesignTokens.brandAccent, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'CREATIVE LIBRARY',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (!canPremium)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFd4af37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFd4af37).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      'Pro unlocks more',
                      style: TextStyle(color: Color(0xFFd4af37), fontSize: 9),
                    ),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tc,
            isScrollable: true,
            labelColor: DesignTokens.brandAccent,
            unselectedLabelColor: Colors.white38,
            indicatorColor: DesignTokens.brandAccent,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: '✨ Magic'),
              Tab(text: 'Overlays'),
              Tab(text: 'Words'),
              Tab(text: 'Stickers'),
              Tab(text: 'Icons'),
              Tab(text: 'Art'),
              Tab(text: 'Pro'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                _MagicGrid(
                  layouts: magic,
                  canPremium: canPremium,
                  onApply: (layout) {
                    if (layout.isPremium && !canPremium) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Premium magic layouts need a Pro plan'),
                        ),
                      );
                      return;
                    }
                    widget.onInsertGroup(layout.elements, layout.background);
                  },
                ),
                _OverlaysGrid(
                  canvasWidth: widget.canvasWidth,
                  canvasHeight: widget.canvasHeight,
                  product: widget.product,
                  canPremium: canPremium,
                  onInsert: (elements) => widget.onInsertGroup(
                    elements,
                    widget.currentBackground,
                  ),
                ),
                _AssetGrid(
                  assets: variableWordPresets.where((a) => !a.isPremium).toList(),
                  onTap: (a) => _tryInsert(a, canPremium),
                ),
                _AssetGrid(
                  assets: stickerAssets.where((a) => !a.isPremium).toList(),
                  onTap: (a) => _tryInsert(a, canPremium),
                ),
                _AssetGrid(
                  assets: iconAssets.where((a) => !a.isPremium).toList(),
                  onTap: (a) => _tryInsert(a, canPremium),
                ),
                _AssetGrid(
                  assets: illustrationAssets.where((a) => !a.isPremium).toList(),
                  onTap: (a) => _tryInsert(a, canPremium),
                ),
                _AssetGrid(
                  assets: allCreativeAssets().where((a) => a.isPremium).toList(),
                  onTap: (a) => _tryInsert(a, canPremium),
                  showPremiumLock: !canPremium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MagicGrid extends StatelessWidget {
  const _MagicGrid({
    required this.layouts,
    required this.canPremium,
    required this.onApply,
  });

  final List<MagicLayout> layouts;
  final bool canPremium;
  final ValueChanged<MagicLayout> onApply;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      itemCount: layouts.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final l = layouts[i];
        final locked = l.isPremium && !canPremium;
        return GestureDetector(
          onTap: () => onApply(l),
          child: Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DesignTokens.brandAccent.withValues(alpha: 0.2),
                  const Color(0xFF6366f1).withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: DesignTokens.brandAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.emoji, style: const TextStyle(fontSize: 22)),
                    if (locked) ...[
                      const Spacer(),
                      Icon(Icons.lock_rounded,
                          size: 14, color: Colors.white.withValues(alpha: 0.5)),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  l.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${l.elements.length} layers',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.assets,
    required this.onTap,
    this.showPremiumLock = false,
  });

  final List<CreativeAsset> assets;
  final ValueChanged<CreativeAsset> onTap;
  final bool showPremiumLock;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      itemCount: assets.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final a = assets[i];
        return GestureDetector(
          onTap: () => onTap(a),
          child: Container(
            width: 88,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: a.isPremium
                    ? const Color(0xFFd4af37).withValues(alpha: 0.35)
                    : Colors.white10,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (a.emoji != null)
                  Text(a.emoji!, style: const TextStyle(fontSize: 28))
                else if (a.icon != null)
                  Icon(a.icon,
                      color: parseHexColor(a.element.fill ?? '#ffffff'),
                      size: 28)
                else
                  const Icon(Icons.category_rounded,
                      color: Colors.white38, size: 24),
                const SizedBox(height: 6),
                Text(
                  a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showPremiumLock || a.isPremium)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.lock_rounded, size: 10, color: Color(0xFFd4af37)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverlaysGrid extends ConsumerStatefulWidget {
  const _OverlaysGrid({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.product,
    required this.canPremium,
    required this.onInsert,
  });

  final double canvasWidth;
  final double canvasHeight;
  final Item? product;
  final bool canPremium;
  final ValueChanged<List<CanvasElement>> onInsert;

  @override
  ConsumerState<_OverlaysGrid> createState() => _OverlaysGridState();
}

class _OverlaysGridState extends ConsumerState<_OverlaysGrid> {
  OverlayCategory _category = OverlayCategory.sale;

  static const _chips = [
    (OverlayCategory.sale, 'Sale', Icons.local_offer_rounded),
    (OverlayCategory.trust, 'Trust', Icons.verified_rounded),
    (OverlayCategory.brand, 'Brand', Icons.business_rounded),
    (OverlayCategory.social, 'Social', Icons.favorite_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(brandKitProvider);
    final overlays = creativeOverlayCatalog
        .where((o) => o.category == _category)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            itemCount: _chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final chip = _chips[i];
              final selected = chip.$1 == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = chip.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? DesignTokens.brandAccent.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? DesignTokens.brandAccent.withValues(alpha: 0.6)
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(chip.$3,
                          size: 12,
                          color: selected
                              ? DesignTokens.brandAccent
                              : Colors.white54),
                      const SizedBox(width: 5),
                      Text(
                        chip.$2,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            itemCount: overlays.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final o = overlays[i];
              final locked = o.isPremium && !widget.canPremium;
              return GestureDetector(
                onTap: () {
                  if (locked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Upgrade to Growth/Pro to unlock premium overlays ✨'),
                      ),
                    );
                    return;
                  }
                  final elements = o.build(
                    canvasWidth: widget.canvasWidth,
                    canvasHeight: widget.canvasHeight,
                    kit: kit,
                    context: null,
                    product: widget.product,
                  );
                  widget.onInsert(elements);
                },
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: o.isPremium
                          ? const Color(0xFFd4af37).withValues(alpha: 0.35)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(o.emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        o.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (locked)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.lock_rounded,
                              size: 10, color: Color(0xFFd4af37)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}