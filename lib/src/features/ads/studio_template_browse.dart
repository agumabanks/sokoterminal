import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/haptics.dart';
import 'ad_templates.dart';
import 'business_hub_templates.dart';
import 'studio_lazy_preview.dart';
import 'studio_theme.dart';

/// Full template library browser — colour thumbs, live preview on tap only.
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

  Map<String, List<AdTemplate>> get _grouped {
    final map = <String, List<AdTemplate>>{};
    for (final t in allStudioTemplates) {
      if (t.category == 'blank' || t.category == 'photo') continue;
      map.putIfAbsent(t.category, () => []).add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
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
      initialChildSize: 0.88,
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
                            '${allStudioTemplates.length}+ professional layouts',
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
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (_, i) {
                    final tpl = templates[i];
                    return GestureDetector(
                      onTap: () async {
                        Haptics.selection();
                        Navigator.pop(context, tpl);
                        await widget.onPick(tpl);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: StudioColorThumb(template: tpl)),
                          const SizedBox(height: 4),
                          Text(
                            tpl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
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