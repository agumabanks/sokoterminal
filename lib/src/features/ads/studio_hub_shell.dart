import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/util/haptics.dart';
import '../checkout/checkout_screen.dart' show itemsStreamProvider;
import '../../widgets/offline_cached_image.dart';
import 'ad_injector_screen.dart';
import 'ad_templates.dart';
import 'ai_ads_tab.dart';
import 'brand_kit_screen.dart';
import 'business_hub_templates.dart';
import 'studio_design_storage.dart';
import 'studio_editor_launcher.dart';
import 'studio_media_picker.dart';
import 'studio_mode.dart';
import 'studio_providers.dart';
import 'studio_recent_designs.dart';
import 'graphics_workspace.dart';
import 'studio_lazy_preview.dart';
import 'studio_settings_screen.dart';
import 'studio_template_browse.dart';
import 'studio_template_discovery.dart';
import 'studio_theme.dart';
import 'studio_entitlements.dart';
import 'studio_share_sheet.dart';
import 'studio_template_exporter.dart';
import 'studio_todays_ads.dart';

// Re-export template card from studio_screen via shared widget below.

/// Minimal Steve Jobs–style shell: mode picker + workspace body + Sanaa cloud bar.
class StudioHubShell extends ConsumerStatefulWidget {
  const StudioHubShell({
    super.key,
    required this.selectedItem,
    required this.items,
    required this.kit,
    required this.onItemSelected,
    required this.onOpenFullStudio,
    required this.onEditTemplate,
    required this.onCreateDesign,
  });

  final Item? selectedItem;
  final AsyncValue<List<Item>> items;
  final BrandKit kit;
  final ValueChanged<Item?> onItemSelected;
  final VoidCallback onOpenFullStudio;
  final Future<void> Function(AdTemplate) onEditTemplate;
  final VoidCallback onCreateDesign;

  @override
  ConsumerState<StudioHubShell> createState() => _StudioHubShellState();
}

class _StudioHubShellState extends ConsumerState<StudioHubShell> {
  StudioMode _mode = StudioMode.templates;

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(yourDesignsProvider).quota;
    final theme = ref.watch(studioThemeProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // ── App bar + mode picker ─────────────────────────────────────────
        Container(
          color: theme.surface,
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  _StudioCloseBtn(
                    theme: theme,
                    onTap: () {
                      Haptics.soft();
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.isMonochrome
                          ? theme.textPrimary
                          : null,
                      gradient: theme.isMonochrome
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF0EBE7E), Color(0xFF059669)],
                            ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: theme.isMonochrome
                          ? theme.scaffold
                          : Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SOKO STUDIO',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  _IconBtn(
                    icon: Icons.tune_rounded,
                    theme: theme,
                    onTap: () {
                      Haptics.selection();
                      Navigator.of(context).push(
                        studioPageRoute(const StudioSettingsScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: widget.onOpenFullStudio,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Full Studio',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModePicker(
                      mode: _mode,
                      theme: theme,
                      onChanged: (m) {
                        Haptics.selection();
                        setState(() => _mode = m);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ProductPill(
                    selectedItem: widget.selectedItem,
                    theme: theme,
                    onTap: () => _showProductPicker(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SanaaCloudBar(quota: quota, theme: theme),
            ],
          ),
        ),

        // ── Workspace body ────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_mode),
              child: _buildBody(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return switch (_mode) {
      StudioMode.editPhotos => _EditPhotosWorkspace(
          onCreateCollage: () => _openHubTemplate('hub_collage_grid'),
          onCreateDesign: widget.onCreateDesign,
          onOpenInjector: () => setState(() => _mode = StudioMode.injector),
          onEditPhoto: _editPhotoFlow,
          onRemoveBackground: _removeBackgroundFlow,
        ),
      StudioMode.templates => _TemplatesWorkspace(
          selectedItem: widget.selectedItem,
          kit: widget.kit,
          onEditTemplate: widget.onEditTemplate,
          onCreateDesign: widget.onCreateDesign,
          onOpenInjector: () => setState(() => _mode = StudioMode.injector),
        ),
      StudioMode.graphics => GraphicsWorkspace(
          kit: widget.kit,
          selectedItem: widget.selectedItem,
          onEditTemplate: widget.onEditTemplate,
        ),
      StudioMode.creators => _CreatorsWorkspace(
          onEditTemplate: widget.onEditTemplate,
        ),
      StudioMode.injector => const AdInjectorScreen(),
    };
  }

  Future<void> _openHubTemplate(String id) async {
    final tpl = templateById(id);
    if (tpl != null) await widget.onEditTemplate(tpl);
  }

  Future<void> _editPhotoFlow() async {
    final pick = await showStudioMediaPicker(
      context,
      ref: ref,
      title: 'Choose photo to edit',
    );
    if (pick == null || !mounted) return;
    final product = ref.read(studioProductProvider);
    await launchStudioEditor(
      context,
      ref,
      template: photoEditStarter(pick.src),
      product: product,
      initialPanel: 'image',
    );
  }

  Future<void> _removeBackgroundFlow() async {
    final pick = await showStudioMediaPicker(
      context,
      ref: ref,
      title: 'Photo for background removal',
    );
    if (pick == null || !mounted) return;
    final product = ref.read(studioProductProvider);
    await launchStudioEditor(
      context,
      ref,
      template: photoEditStarter(pick.src),
      product: product,
      initialPanel: 'image',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap Remove BG in the image panel when ready'),
      ),
    );
  }

  void _showProductPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1D40),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductPickerSheet(
        items: widget.items,
        selected: widget.selectedItem,
        onSelect: (item) {
          widget.onItemSelected(item);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode picker dropdown
// ---------------------------------------------------------------------------

class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.mode,
    required this.theme,
    required this.onChanged,
  });

  final StudioMode mode;
  final StudioThemeData theme;
  final ValueChanged<StudioMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = theme.isMonochrome ? theme.textPrimary : mode.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StudioMode>(
          value: mode,
          isExpanded: true,
          dropdownColor: theme.surface,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more_rounded, color: accent, size: 22),
          items: StudioMode.values.map((m) {
            final itemAccent =
                theme.isMonochrome ? theme.textPrimary : m.accent;
            return DropdownMenuItem(
              value: m,
              child: Row(
                children: [
                  Icon(m.icon, size: 18, color: itemAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.label,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          m.subtitle,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          selectedItemBuilder: (_) => StudioMode.values.map((m) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(m.icon, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.label,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          m.subtitle,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sanaa cloud storage bar
// ---------------------------------------------------------------------------

class _SanaaCloudBar extends StatelessWidget {
  const _SanaaCloudBar({required this.quota, required this.theme});

  final StudioCloudQuota quota;
  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    final barColor = quota.usedFraction > 0.9
        ? Colors.orangeAccent
        : theme.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, color: theme.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            quota.label,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: quota.usedFraction,
                minHeight: 4,
                backgroundColor: theme.border,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${quota.usedLabel} / ${quota.quotaLabel}',
            style: TextStyle(color: theme.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Photos workspace
// ---------------------------------------------------------------------------

class _EditPhotosWorkspace extends StatelessWidget {
  const _EditPhotosWorkspace({
    required this.onCreateCollage,
    required this.onCreateDesign,
    required this.onOpenInjector,
    required this.onEditPhoto,
    required this.onRemoveBackground,
  });

  final VoidCallback onCreateCollage;
  final VoidCallback onCreateDesign;
  final VoidCallback onOpenInjector;
  final VoidCallback onEditPhoto;
  final VoidCallback onRemoveBackground;

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        icon: Icons.photo_outlined,
        label: 'Edit Photo',
        sub: 'Gallery, catalog, Soko uploads or brand',
        color: const Color(0xFF3b82f6),
        onTap: onEditPhoto,
      ),
      (
        icon: Icons.grid_on_rounded,
        label: 'Product Collage',
        sub: 'Multi-photo showcase',
        color: const Color(0xFF6366f1),
        onTap: onCreateCollage,
      ),
      (
        icon: Icons.crop_rounded,
        label: 'Custom Canvas',
        sub: 'Any size — crop & layout',
        color: const Color(0xFF0EBE7E),
        onTap: onCreateDesign,
      ),
      (
        icon: Icons.layers_clear_rounded,
        label: 'Remove Background',
        sub: 'Pick any source, then one-tap remove',
        color: const Color(0xFF8b5cf6),
        onTap: onRemoveBackground,
      ),
      (
        icon: Icons.auto_fix_high_rounded,
        label: 'Ad Injector',
        sub: 'Overlay brand on photos & video',
        color: const Color(0xFF22d3ee),
        onTap: onOpenInjector,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Edit Photos',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Polish product shots, build collages, remove backgrounds.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        ...tools.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolTile(
                icon: t.icon,
                label: t.label,
                subtitle: t.sub,
                accent: t.color,
                onTap: t.onTap,
              ),
            )),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F1D40),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Templates workspace (discovery sections)
// ---------------------------------------------------------------------------

class _TemplatesWorkspace extends ConsumerWidget {
  const _TemplatesWorkspace({
    required this.selectedItem,
    required this.kit,
    required this.onEditTemplate,
    required this.onCreateDesign,
    required this.onOpenInjector,
  });

  final Item? selectedItem;
  final BrandKit kit;
  final Future<void> Function(AdTemplate) onEditTemplate;
  final VoidCallback onCreateDesign;
  final VoidCallback onOpenInjector;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(templateDiscoveryProvider);
    final recent = ref.watch(recentDesignsProvider);
    final yourDesigns = ref.watch(yourDesignsProvider).designs;
    final todaysAds = ref.watch(todaysAdsProvider);

    return discovery.when(
      loading: () => _DiscoveryScroll(
        sections: localTemplateDiscoveryFallback(),
        selectedItem: selectedItem,
        kit: kit,
        onEditTemplate: onEditTemplate,
        onCreateDesign: onCreateDesign,
        onOpenInjector: onOpenInjector,
        recent: recent,
        yourDesigns: yourDesigns,
        todaysAds: todaysAds,
        isLoadingCatalog: true,
      ),
      error: (_, __) => _DiscoveryScroll(
        sections: localTemplateDiscoveryFallback(),
        selectedItem: selectedItem,
        kit: kit,
        onEditTemplate: onEditTemplate,
        onCreateDesign: onCreateDesign,
        onOpenInjector: onOpenInjector,
        recent: recent,
        yourDesigns: yourDesigns,
        todaysAds: todaysAds,
      ),
      data: (sections) => _DiscoveryScroll(
        sections: sections,
        selectedItem: selectedItem,
        kit: kit,
        onEditTemplate: onEditTemplate,
        onCreateDesign: onCreateDesign,
        onOpenInjector: onOpenInjector,
        recent: recent,
        yourDesigns: yourDesigns,
        todaysAds: todaysAds,
      ),
    );
  }
}

class _DiscoveryScroll extends ConsumerWidget {
  const _DiscoveryScroll({
    required this.sections,
    required this.selectedItem,
    required this.kit,
    required this.onEditTemplate,
    required this.onCreateDesign,
    required this.onOpenInjector,
    required this.recent,
    required this.yourDesigns,
    required this.todaysAds,
    this.isLoadingCatalog = false,
  });

  final List<TemplateDiscoverySection> sections;
  final Item? selectedItem;
  final BrandKit kit;
  final Future<void> Function(AdTemplate) onEditTemplate;
  final VoidCallback onCreateDesign;
  final VoidCallback onOpenInjector;
  final List<AdTemplate> recent;
  final List<AdTemplate> yourDesigns;
  final List<TodaysAdEntry> todaysAds;
  final bool isLoadingCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.read(templateUseRecorderProvider);
    final theme = ref.watch(studioThemeProvider);

    return CustomScrollView(
      slivers: [
        if (todaysAds.isNotEmpty)
          SliverToBoxAdapter(
            child: _TodaysAdsSection(
              entries: todaysAds,
              theme: theme,
              kit: kit,
              onEdit: onEditTemplate,
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GestureDetector(
              onTap: () {
                Haptics.selection();
                onCreateDesign();
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.isMonochrome ? theme.textPrimary : null,
                  gradient: theme.isMonochrome
                      ? null
                      : LinearGradient(colors: [
                          theme.accent,
                          theme.accent.withValues(alpha: 0.75),
                        ]),
                  borderRadius: BorderRadius.circular(16),
                  border: theme.isMonochrome
                      ? Border.all(color: theme.border)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create a design',
                            style: TextStyle(
                              color: theme.isMonochrome
                                  ? theme.scaffold
                                  : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Blank canvas or pick a format',
                            style: TextStyle(
                              color: theme.isMonochrome
                                  ? theme.scaffold.withValues(alpha: 0.7)
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.add_rounded,
                      color: theme.isMonochrome ? theme.scaffold : Colors.white,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () {
                Haptics.selection();
                showStudioTemplateBrowse(
                  context,
                  onPick: onEditTemplate,
                );
              },
              icon: Icon(Icons.grid_view_rounded, color: theme.textPrimary, size: 18),
              label: Text(
                'Browse ${allStudioTemplates.length}+ templates',
                style: TextStyle(color: theme.textPrimary, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        if (isLoadingCatalog)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),

        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Continue editing',
              subtitle: 'Pick up where you left off',
              templates: recent.take(6).toList(),
              selectedItem: selectedItem,
              kit: kit,
              theme: theme,
              railHeight: 148,
              thumbWidth: 108,
              onTap: (tpl) async {
                await onEditTemplate(tpl);
              },
            ),
          ),

        if (yourDesigns.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Your Designs',
              subtitle: 'Saved on device & Sanaa Cloud',
              templates: yourDesigns.take(8).toList(),
              selectedItem: selectedItem,
              kit: kit,
              theme: theme,
              onTap: (tpl) async {
                await onEditTemplate(tpl);
              },
            ),
          ),

        for (final section in sections)
          if (section.id != 'todays_ads')
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: section.title,
                subtitle: section.subtitle,
                templates: section.resolveTemplates(),
                selectedItem: selectedItem,
                kit: kit,
                theme: theme,
                onTap: (tpl) async {
                  await recorder.record(tpl.id);
                  await onEditTemplate(tpl);
                },
              ),
            ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: GestureDetector(
              onTap: onOpenInjector,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1D40),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF22d3ee).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded,
                        color: Color(0xFF22d3ee), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ad Injector',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text('Overlay brand on any photo or video',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white38, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({
    required this.title,
    required this.subtitle,
    required this.templates,
    required this.selectedItem,
    required this.kit,
    required this.onTap,
    this.theme,
    this.railHeight = 168,
    this.thumbWidth = 120,
  });

  final String title;
  final String subtitle;
  final List<AdTemplate> templates;
  final Item? selectedItem;
  final BrandKit kit;
  final ValueChanged<AdTemplate> onTap;
  final StudioThemeData? theme;
  final double railHeight;
  final double thumbWidth;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();

    final t = theme;
    final titleColor = t?.textPrimary ?? Colors.white;
    final subtitleColor = t?.textMuted ?? Colors.white54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: subtitleColor, fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 24, 0),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final tpl = templates[i];
              return SizedBox(
                width: thumbWidth,
                child: StudioTemplateThumb(
                  template: tpl,
                  selectedItem: selectedItem,
                  kit: kit,
                  theme: theme,
                  onTap: () => onTap(tpl),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Creators workspace (AI + Brand Kit + Your Designs)
// ---------------------------------------------------------------------------

class _CreatorsWorkspace extends ConsumerWidget {
  const _CreatorsWorkspace({required this.onEditTemplate});

  final Future<void> Function(AdTemplate) onEditTemplate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF0F1D40),
            child: const TabBar(
              labelColor: Color(0xFFf59e0b),
              unselectedLabelColor: Colors.white38,
              indicatorColor: Color(0xFFf59e0b),
              indicatorWeight: 2,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'AI Studio'),
                Tab(text: 'Your Designs'),
                Tab(text: 'Brand Kit'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const AIAdsTab(),
                _YourDesignsTab(onEditTemplate: onEditTemplate),
                const BrandKitScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YourDesignsTab extends ConsumerWidget {
  const _YourDesignsTab({required this.onEditTemplate});

  final Future<void> Function(AdTemplate) onEditTemplate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(yourDesignsProvider);
    final designs = state.designs;

    if (designs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 56, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('No designs yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Saved work syncs to Sanaa Cloud (2 GB)\nand your device folder.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(yourDesignsProvider.notifier).refreshCloud(),
      color: const Color(0xFF0EBE7E),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: designs.length,
        itemBuilder: (_, i) {
          final tpl = designs[i];
          return Stack(
            children: [
              StudioTemplateThumb(
                template: tpl,
                selectedItem: null,
                kit: const BrandKit(),
                onTap: () => onEditTemplate(tpl),
                expanded: true,
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => ref
                      .read(yourDesignsProvider.notifier)
                      .deleteDesign(tpl.id),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's Ads — ready to post
// ---------------------------------------------------------------------------

class _TodaysAdsSection extends ConsumerWidget {
  const _TodaysAdsSection({
    required this.entries,
    required this.theme,
    required this.onEdit,
    required this.kit,
  });

  final List<TodaysAdEntry> entries;
  final StudioThemeData theme;
  final Future<void> Function(AdTemplate) onEdit;
  final BrandKit kit;

  Future<void> _postNow(
    BuildContext context,
    WidgetRef ref,
    TodaysAdEntry entry,
  ) async {
    Haptics.impact();
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Preparing your ad…'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final entitlements = await ref.read(studioEntitlementsProvider.future);
      if (!context.mounted) return;
      final file = await exportStudioTemplatePng(
        context,
        template: entry.template,
        applyWatermark: entitlements.needsSokoWatermark,
      );
      if (!context.mounted) return;
      rootNav.pop();
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export ad — try Polish')),
        );
        return;
      }
      Item? product;
      if (!entry.isService) {
        final items = ref.read(itemsStreamProvider).valueOrNull ?? [];
        for (final item in items) {
          if (item.id == entry.itemId) {
            product = item;
            break;
          }
        }
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => StudioShareSheet(
            adFile: file,
            template: entry.template,
            kit: kit,
            initialProduct: product,
            initialCaption: entry.caption,
            exportTitle: entry.template.name,
            showWatermarkBadge: entitlements.needsSokoWatermark,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        rootNav.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        entries.length == 1 ? "Today's Ad" : "Today's Ads";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: theme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      'Fresh today',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to post — polish if you like, then share',
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 32, 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final entry = entries[i];
              return _TodaysAdCard(
                entry: entry,
                theme: theme,
                onPost: () => _postNow(context, ref, entry),
                onPolish: () {
                  Haptics.selection();
                  onEdit(entry.template);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TodaysAdCard extends StatelessWidget {
  const _TodaysAdCard({
    required this.entry,
    required this.theme,
    required this.onPost,
    required this.onPolish,
  });

  final TodaysAdEntry entry;
  final StudioThemeData theme;
  final VoidCallback onPost;
  final VoidCallback onPolish;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.scaffold,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: StudioLazyPreview(
                    template: entry.template,
                    deferMs: 50,
                    borderRadius: 8,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Material(
                        color: theme.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: onPost,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_rounded,
                                  size: 12,
                                  color: theme.scaffold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Post now',
                                  style: TextStyle(
                                    color: theme.scaffold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: onPolish,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textSecondary,
                          side: BorderSide(color: theme.border),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Polish',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared template thumb (used across hub)
// ---------------------------------------------------------------------------

class StudioTemplateThumb extends StatelessWidget {
  const StudioTemplateThumb({
    required this.template,
    required this.selectedItem,
    required this.kit,
    required this.onTap,
    this.expanded = false,
    this.theme,
  });

  final AdTemplate template;
  final Item? selectedItem;
  final BrandKit kit;
  final VoidCallback onTap;
  final bool expanded;
  final StudioThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final preview = template.applyProduct(
      productName: selectedItem?.name ?? '',
      priceFormatted: selectedItem != null
          ? 'UGX ${selectedItem!.price.toStringAsFixed(0)}'
          : '',
      imageUrl: selectedItem?.imageUrl ?? '',
      whatsappNumber: kit.whatsapp,
      phoneNumber: kit.phone,
      businessName: kit.businessName,
      location: kit.location,
      shopUrl: kit.website.isNotEmpty
          ? kit.website
          : selectedItem != null
              ? 'soko24.co/p/${selectedItem!.id}'
              : 'soko24.co',
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StudioLazyPreview(
            template: preview,
            borderRadius: expanded ? 12 : 10,
            deferMs: expanded ? 40 : 100,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          template.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme?.textSecondary ??
                Colors.white.withValues(alpha: 0.8),
            fontSize: expanded ? 12 : 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (expanded) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1D40),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.all(8),
          child: content,
        ),
      );
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------

class _StudioCloseBtn extends StatelessWidget {
  const _StudioCloseBtn({required this.theme, required this.onTap});

  final StudioThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close_rounded, color: theme.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.theme,
  });

  final IconData icon;
  final VoidCallback onTap;
  final StudioThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final fg = theme?.textSecondary ?? Colors.white70;
    final bg = theme?.surfaceElevated ?? Colors.white.withValues(alpha: 0.08);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }
}

class _ProductPill extends StatelessWidget {
  const _ProductPill({
    required this.selectedItem,
    required this.theme,
    required this.onTap,
  });

  final Item? selectedItem;
  final StudioThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selectedItem != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? theme.accent.withValues(alpha: 0.1)
              : theme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? theme.accent.withValues(alpha: 0.35)
                : theme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.inventory_2_rounded
                  : Icons.add_circle_outline_rounded,
              size: 14,
              color: active ? theme.accent : theme.textMuted,
            ),
            if (active) ...[
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  selectedItem!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final AsyncValue<List<Item>> items;
  final Item? selected;
  final ValueChanged<Item?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('Apply to design',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (selected != null)
                TextButton(
                  onPressed: () => onSelect(null),
                  child: const Text('Clear',
                      style: TextStyle(color: Color(0xFF0EBE7E))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        items.when(
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No products yet',
                      style: TextStyle(color: Colors.white54)),
                )
              : SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final item = list[i];
                      final sel = selected?.id == item.id;
                      return GestureDetector(
                        onTap: () => onSelect(item),
                        child: Container(
                          width: 110,
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF0EBE7E).withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFF0EBE7E)
                                  : Colors.white12,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              if (item.imageUrl?.isNotEmpty == true)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: OfflineCachedImage(
                                    imageUrl: item.imageUrl!,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2,
                                      size: 28, color: Colors.white30),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF0EBE7E)),
            ),
          ),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}