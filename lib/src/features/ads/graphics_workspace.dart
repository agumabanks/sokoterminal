import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/util/haptics.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'business_hub_config.dart';
import 'business_hub_templates.dart';
import 'studio_lazy_preview.dart';
import 'studio_theme.dart';
import 'studio_variable_context.dart';

/// Business Hub — fast gradient cards; live previews only in the picker sheet.
class GraphicsWorkspace extends ConsumerWidget {
  const GraphicsWorkspace({
    super.key,
    required this.kit,
    required this.selectedItem,
    required this.onEditTemplate,
  });

  final BrandKit kit;
  final Item? selectedItem;
  final Future<void> Function(AdTemplate) onEditTemplate;

  StudioVariableContext _variableContext() => StudioVariableContext(
        kit: kit,
        product: selectedItem,
        productLink: selectedItem != null
            ? 'soko24.co/p/${selectedItem!.id}'
            : kit.website,
      );

  AdTemplate _previewTemplate(AdTemplate template) => template.applyProduct(
        productName: selectedItem?.name ?? kit.businessName,
        priceFormatted: selectedItem != null
            ? 'UGX ${selectedItem!.price.toStringAsFixed(0)}'
            : '',
        imageUrl: selectedItem?.imageUrl ?? kit.logoNetworkUrl ?? '',
        whatsappNumber: kit.whatsapp,
        phoneNumber: kit.phone,
        businessName: kit.businessName,
        location: kit.location,
        shopUrl: kit.website.isNotEmpty ? kit.website : 'soko24.co',
        tagline: kit.tagline,
      );

  Future<void> _openHub(BuildContext context, BusinessHubType hub) async {
    Haptics.selection();
    final templates = templatesForCategory(hub.templateCategory);
    if (templates.isEmpty) return;
    if (templates.length == 1) {
      await onEditTemplate(templates.first);
      return;
    }
    final picked = await showModalBottomSheet<AdTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HubTemplatePickerSheet(
        hub: hub,
        templates: templates,
        previewBuilder: _previewTemplate,
        variableContext: _variableContext(),
      ),
    );
    if (picked != null) await onEditTemplate(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(studioThemeProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _HeroBanner(theme: theme)),
        SliverToBoxAdapter(
          child: _QuickStartRow(
            theme: theme,
            onHubTap: (hub) => _openHub(context, hub),
          ),
        ),
        for (final category in graphicsCategories)
          SliverToBoxAdapter(
            child: _CategoryRail(
              category: category,
              theme: theme,
              onHubTap: (hub) => _openHub(context, hub),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.theme});
  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.isMonochrome
                ? [theme.surfaceElevated, theme.surface]
                : theme.heroGradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Hub',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              'Print-ready graphics',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Logos, menus, invoices — professional & on-brand.',
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStartRow extends StatelessWidget {
  const _QuickStartRow({required this.theme, required this.onHubTap});
  final StudioThemeData theme;
  final ValueChanged<BusinessHubType> onHubTap;

  @override
  Widget build(BuildContext context) {
    const quickIds = ['logo', 'menu', 'business_card', 'invoice'];
    final hubs = quickIds.map(hubTypeById).whereType<BusinessHubType>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Quick start',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: hubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final hub = hubs[i];
              return ActionChip(
                label: Text(hub.label),
                avatar: Text(hub.emoji ?? '✦', style: const TextStyle(fontSize: 12)),
                onPressed: () => onHubTap(hub),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.category,
    required this.theme,
    required this.onHubTap,
  });

  final GraphicsCategory category;
  final StudioThemeData theme;
  final ValueChanged<BusinessHubType> onHubTap;

  @override
  Widget build(BuildContext context) {
    final hubs = category.hubIds.map(hubTypeById).whereType<BusinessHubType>().toList();
    if (hubs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Icon(category.icon, color: category.accent, size: 18),
              const SizedBox(width: 10),
              Text(
                category.title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: hubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final hub = hubs[i];
              final count = templatesForCategory(hub.templateCategory).length;
              return _HubGradientCard(
                hub: hub,
                templateCount: count,
                theme: theme,
                onTap: () => onHubTap(hub),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HubGradientCard extends StatelessWidget {
  const _HubGradientCard({
    required this.hub,
    required this.templateCount,
    required this.theme,
    required this.onTap,
  });

  final BusinessHubType hub;
  final int templateCount;
  final StudioThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.isMonochrome
                        ? [theme.surfaceElevated, theme.surface]
                        : [
                            hub.gradient.first.withValues(alpha: 0.5),
                            hub.gradient.last.withValues(alpha: 0.15),
                          ],
                  ),
                  border: Border.all(
                    color: theme.isMonochrome
                        ? theme.border
                        : hub.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(hub.emoji ?? '✦', style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 8),
                          Icon(hub.icon, color: hub.accent, size: 22),
                        ],
                      ),
                    ),
                    if (templateCount > 1)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Text(
                          '$templateCount',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hub.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTemplatePickerSheet extends StatelessWidget {
  const _HubTemplatePickerSheet({
    required this.hub,
    required this.templates,
    required this.previewBuilder,
    required this.variableContext,
  });

  final BusinessHubType hub;
  final List<AdTemplate> templates;
  final AdTemplate Function(AdTemplate) previewBuilder;
  final StudioVariableContext variableContext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B1628),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  hub.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (_, i) {
                    final tpl = templates[i];
                    final preview = previewBuilder(tpl);
                    return GestureDetector(
                      onTap: () {
                        Haptics.selection();
                        Navigator.pop(context, tpl);
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: StudioLazyPreview(
                              template: preview,
                              variableContext: variableContext,
                              deferMs: 80 + i * 60,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tpl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
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