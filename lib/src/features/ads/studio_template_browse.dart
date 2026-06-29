import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/haptics.dart';
import '../checkout/checkout_screen.dart' show itemsStreamProvider, servicesStreamProvider;
import 'ad_templates.dart';
import 'business_hub_templates.dart';
import 'seasonal_campaign_generator.dart';
import 'studio_lazy_preview.dart';
import 'studio_theme.dart';

/// Full template library browser — search, filter by category & size, live preview on tap.
Future<AdTemplate?> showStudioTemplateBrowse(
  BuildContext context, {
  required Future<void> Function(AdTemplate) onPick,
}) {
  return showModalBottomSheet<AdTemplate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TemplateBrowseSheet(onPick: onPick),
  );
}

class _TemplateBrowseSheet extends ConsumerStatefulWidget {
  const _TemplateBrowseSheet({required this.onPick});

  final Future<void> Function(AdTemplate) onPick;

  @override
  ConsumerState<_TemplateBrowseSheet> createState() => _TemplateBrowseSheetState();
}

class _TemplateBrowseSheetState extends ConsumerState<_TemplateBrowseSheet> {
  String? _category;
  String _query = '';
  String? _sizeFilter;

  List<AdTemplate> get _allTemplates {
    return allStudioTemplates.where((t) {
      if (t.category == 'blank' || t.category == 'photo') return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final match = t.name.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            t.tags.any((tag) => tag.toLowerCase().contains(q)) ||
            t.industry.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_sizeFilter != null) {
        final sizeName = _sizeNameFor(t.canvasWidth, t.canvasHeight);
        if (sizeName != _sizeFilter) return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<AdTemplate>> get _grouped {
    final map = <String, List<AdTemplate>>{};
    for (final t in _allTemplates) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  List<AdTemplate> _featuredTemplates(WidgetRef ref) {
    final items = ref.watch(itemsStreamProvider).valueOrNull ?? [];
    final services = ref.watch(servicesStreamProvider).valueOrNull ?? [];
    final season = (currentSeasons().isNotEmpty ? currentSeasons().first.name : '').toLowerCase();
    final hasItems = items.isNotEmpty;
    final hasServices = services.isNotEmpty;

    int score(AdTemplate t) {
      int s = 0;
      // Prefer seasonal match
      if (t.season.toLowerCase() == season) s += 30;
      // Prefer complexity
      if (t.complexity == 'premium') s += 20;
      if (t.complexity == 'pro') s += 10;
      // Prefer relevant categories
      if (hasItems && (t.category == 'product' || t.category == 'promo')) s += 15;
      if (hasServices && (t.category == 'service' || t.category == 'booking')) s += 15;
      if (t.category == 'social' || t.category == 'announcement') s += 5;
      // Prefer square/story sizes (most common for social)
      if (t.canvasWidth == 1080 && t.canvasHeight == 1080) s += 5;
      if (t.canvasWidth == 1080 && t.canvasHeight == 1920) s += 3;
      return s;
    }

    final pool = allStudioTemplates.where((t) {
      if (t.category == 'blank' || t.category == 'photo') return false;
      return true;
    }).toList();

    pool.sort((a, b) => score(b).compareTo(score(a)));
    return pool.take(12).toList();
  }

  static final _sizeOptions = <({String label, String key, double w, double h})>[
    (label: 'Square', key: 'sq', w: 1080, h: 1080),
    (label: 'Story', key: 'story', w: 1080, h: 1920),
    (label: 'Portrait', key: 'portrait', w: 1080, h: 1350),
    (label: 'Facebook', key: 'fb', w: 1200, h: 630),
    (label: 'Banner', key: 'banner', w: 1920, h: 1080),
    (label: 'A5', key: 'a5', w: 1748, h: 2480),
    (label: 'A6', key: 'a6', w: 1240, h: 1748),
  ];

  String? _sizeNameFor(double w, double h) {
    for (final s in _sizeOptions) {
      if ((w - s.w).abs() < 10 && (h - s.h).abs() < 10) return s.key;
    }
    return null;
  }

  static IconData _categoryIcon(String category) {
    return switch (category) {
      'sale' => Icons.local_offer_rounded,
      'new' => Icons.fiber_new_rounded,
      'promo' => Icons.campaign_rounded,
      'story' => Icons.smartphone_rounded,
      'minimal' => Icons.minimize_rounded,
      'whatsapp' => Icons.chat_rounded,
      'booking' => Icons.calendar_today_rounded,
      'catalog' => Icons.collections_rounded,
      'food' => Icons.restaurant_rounded,
      'fashion' => Icons.checkroom_rounded,
      'realestate' => Icons.home_work_rounded,
      'beauty' => Icons.spa_rounded,
      'service' => Icons.miscellaneous_services_rounded,
      'social' => Icons.share_rounded,
      _ => Icons.folder_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(studioThemeProvider);
    final grouped = _grouped;
    final categories = grouped.keys.toList();
    final active = _category ?? (categories.isNotEmpty ? categories.first : null);
    final templates = active != null ? grouped[active] ?? [] : <AdTemplate>[];
    final bottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffold,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Template Library',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_allTemplates.length} professional layouts',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
              // ── Search ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search templates...',
                    hintStyle: TextStyle(color: theme.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: theme.textMuted, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: theme.textMuted, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: theme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Size filter chips ───────────────────────────────────────
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _sizeOptions.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final sel = _sizeFilter == null;
                      return ChoiceChip(
                        label: Text('All Sizes', style: TextStyle(fontSize: 11)),
                        selected: sel,
                        onSelected: (_) => setState(() => _sizeFilter = null),
                        selectedColor: theme.accent,
                        backgroundColor: theme.surface,
                        side: BorderSide(color: theme.border),
                        showCheckmark: false,
                      );
                    }
                    final s = _sizeOptions[i - 1];
                    final sel = _sizeFilter == s.key;
                    return ChoiceChip(
                      label: Text(s.label, style: TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (_) => setState(() => _sizeFilter = s.key),
                      selectedColor: theme.accent,
                      backgroundColor: theme.surface,
                      side: BorderSide(color: theme.border),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // ── Featured for you ────────────────────────────────────────
              _FeaturedTemplatesRow(
                templates: _featuredTemplates(ref),
                theme: theme,
                onPick: (tpl) async {
                  Haptics.selection();
                  Navigator.pop(context, tpl);
                  await widget.onPick(tpl);
                },
              ),
              const SizedBox(height: 8),
              // ── Category chips ──────────────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    final sel = cat == active;
                    return FilterChip(
                      avatar: Icon(
                        _categoryIcon(cat),
                        color: sel ? theme.scaffold : theme.textSecondary,
                        size: 14,
                      ),
                      label: Text(
                        '${cat[0].toUpperCase()}${cat.substring(1)} (${grouped[cat]!.length})',
                        style: TextStyle(
                          fontSize: 11,
                          color: sel ? theme.scaffold : theme.textSecondary,
                        ),
                      ),
                      selected: sel,
                      onSelected: (_) => setState(() => _category = cat),
                      selectedColor: theme.accent,
                      backgroundColor: theme.surface,
                      side: BorderSide(color: theme.border),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // ── Template grid ───────────────────────────────────────────
              Expanded(
                child: templates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, color: theme.textMuted, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'No templates match your search',
                              style: TextStyle(color: theme.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            if (_query.isNotEmpty || _sizeFilter != null)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _query = '';
                                  _sizeFilter = null;
                                }),
                                icon: Icon(Icons.clear_all_rounded, color: theme.accent, size: 16),
                                label: Text(
                                  'Clear filters',
                                  style: TextStyle(color: theme.accent, fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: templates.length,
                        itemBuilder: (_, i) {
                          final tpl = templates[i];
                          return _TemplateCard(
                            template: tpl,
                            onTap: () async {
                              Haptics.selection();
                              Navigator.pop(context, tpl);
                              await widget.onPick(tpl);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Template Card with metadata badges
// ---------------------------------------------------------------------------

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final AdTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(studioThemeProvider);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: StudioColorThumb(template: template),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _TemplateBrowseSheetState._categoryIcon(template.category),
                          color: theme.textSecondary,
                          size: 8,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          template.category[0].toUpperCase() + template.category.substring(1),
                          style: TextStyle(
                            fontSize: 7,
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Complexity badge
                if (template.complexity != 'starter')
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        template.complexity == 'premium' ? '★' : '●',
                        style: TextStyle(
                          fontSize: 8,
                          color: template.complexity == 'premium'
                              ? const Color(0xFFfbbf24)
                              : theme.accent,
                        ),
                      ),
                    ),
                  ),
                // Size badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${template.canvasWidth.toInt()}×${template.canvasHeight.toInt()}',
                      style: TextStyle(
                        fontSize: 7,
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            template.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${template.canvasWidth.toInt()} × ${template.canvasHeight.toInt()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Featured templates row
// ---------------------------------------------------------------------------

class _FeaturedTemplatesRow extends StatelessWidget {
  const _FeaturedTemplatesRow({
    required this.templates,
    required this.theme,
    required this.onPick,
  });

  final List<AdTemplate> templates;
  final StudioThemeData theme;
  final ValueChanged<AdTemplate> onPick;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: theme.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                'Featured for you',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final tpl = templates[i];
              return GestureDetector(
                onTap: () => onPick(tpl),
                child: SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: StudioColorThumb(template: tpl),
                              ),
                            ),
                            if (tpl.complexity == 'premium')
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFfbbf24).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '★',
                                    style: TextStyle(fontSize: 8, color: Colors.black),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tpl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 9,
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
      ],
    );
  }
}
