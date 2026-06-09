import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/haptics.dart';
import 'brand_kit_screen.dart';
import 'studio_theme.dart';

/// Studio appearance + quick link to brand kit business settings.
class StudioSettingsScreen extends ConsumerWidget {
  const StudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(studioThemeProvider);
    final appearance = ref.watch(studioAppearanceProvider);

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        backgroundColor: theme.surface,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        title: Text(
          'Studio Settings',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.textPrimary),
          onPressed: () {
            Haptics.soft();
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monochrome keeps your work front and centre — like a premium design book.',
            style: TextStyle(color: theme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final option in StudioAppearance.values)
            _AppearanceTile(
              theme: theme,
              option: option,
              selected: appearance == option,
              onTap: () {
                Haptics.selection();
                ref.read(studioAppearanceProvider.notifier).setAppearance(option);
              },
            ),
          const SizedBox(height: 28),
          Text(
            'Business',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                Haptics.selection();
                Navigator.of(context).push(
                  studioPageRoute(const BrandKitScreen()),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined, color: theme.textPrimary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Brand Kit',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Logo, colours, contact & business info',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: theme.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({
    required this.theme,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final StudioThemeData theme;
  final StudioAppearance option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = StudioThemeData.forAppearance(option);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: preview.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? preview.accent : theme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: preview.heroGradient),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: preview.border),
                  ),
                  child: Icon(
                    option == StudioAppearance.monochromeLight
                        ? Icons.wb_sunny_outlined
                        : option == StudioAppearance.monochromeDark
                            ? Icons.nights_stay_outlined
                            : Icons.auto_awesome_rounded,
                    color: preview.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          color: preview.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          color: preview.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: preview.accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}