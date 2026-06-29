import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/haptics.dart';
import 'brand_kit_screen.dart';
import 'studio_notification_scheduler.dart';
import 'studio_theme.dart';
import 'studio_watermark_settings.dart';

/// Studio appearance + quick link to brand kit business settings.
class StudioSettingsScreen extends ConsumerWidget {
  const StudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(studioThemeProvider);
    final appearance = ref.watch(studioAppearanceProvider);
    final watermark = ref.watch(watermarkSettingsProvider);
    final brandKit = ref.watch(brandKitProvider);
    final notifications = ref.watch(studioNotificationPrefsProvider);

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
          const SizedBox(height: 28),
          Text(
            'Watermark',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          _WatermarkCard(
            theme: theme,
            watermark: watermark,
            brandKit: brandKit,
            onChanged: (value) {
              Haptics.selection();
              ref.read(watermarkSettingsProvider.notifier).update(value);
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Notifications',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          _NotificationsCard(
            theme: theme,
            prefs: notifications,
            onChanged: (value) {
              Haptics.selection();
              ref.read(studioNotificationPrefsProvider.notifier).update(value);
            },
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

// ---------------------------------------------------------------------------
// Watermark settings card
// ---------------------------------------------------------------------------

class _WatermarkCard extends StatelessWidget {
  const _WatermarkCard({
    required this.theme,
    required this.watermark,
    required this.brandKit,
    required this.onChanged,
  });

  final StudioThemeData theme;
  final WatermarkSettings watermark;
  final BrandKit brandKit;
  final ValueChanged<WatermarkSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            theme: theme,
            label: 'Add Soko watermark on export',
            value: watermark.enabled,
            onChanged: (v) => onChanged(watermark.copyWith(enabled: v)),
          ),
          const SizedBox(height: 6),
          _ToggleRow(
            theme: theme,
            label: 'Prominent brand stamp',
            value: watermark.prominentBrandStamp,
            onChanged: (v) => onChanged(
              WatermarkSettings.fromPreset(prominent: v).copyWith(
                useBusinessLogo: watermark.useBusinessLogo,
                enabled: watermark.enabled,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SliderRow(
            theme: theme,
            label: 'Opacity',
            value: watermark.opacity.clamp(0.0, 1.0),
            displayValue: '${(watermark.opacity * 100).round()}%',
            onChanged: (v) => onChanged(watermark.copyWith(opacity: v)),
          ),
          const SizedBox(height: 12),
          _SliderRow(
            theme: theme,
            label: 'Size',
            value: watermark.scale.clamp(0.02, 0.5),
            min: 0.02,
            max: 0.5,
            displayValue: '${(watermark.scale * 100).round()}%',
            onChanged: (v) => onChanged(watermark.copyWith(scale: v)),
          ),
          const SizedBox(height: 18),
          Text(
            'Blend mode',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _BlendModeDropdown(
            theme: theme,
            value: watermark.blendMode,
            onChanged: (v) => onChanged(watermark.copyWith(blendMode: v)),
          ),
          const SizedBox(height: 18),
          Text(
            'Position',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _PositionSelector(
            theme: theme,
            position: watermark.position,
            onChanged: (v) => onChanged(watermark.copyWith(position: v)),
          ),
          const SizedBox(height: 18),
          _ToggleRow(
            theme: theme,
            label: 'Use my business logo',
            value: watermark.useBusinessLogo,
            onChanged: (v) => onChanged(watermark.copyWith(useBusinessLogo: v)),
          ),
          if (watermark.useBusinessLogo && !brandKit.hasLogo) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: theme.textMuted, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No business logo set. Upload one in Brand Kit.',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.theme,
    required this.prefs,
    required this.onChanged,
  });

  final StudioThemeData theme;
  final StudioNotificationPrefs prefs;
  final ValueChanged<StudioNotificationPrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            theme: theme,
            label: 'Smart ad reminders',
            value: prefs.enabled,
            onChanged: (v) => onChanged(prefs.copyWith(enabled: v)),
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            theme: theme,
            label: 'Remind me about new inventory',
            value: prefs.suggestFromInventory,
            onChanged: (v) => onChanged(prefs.copyWith(suggestFromInventory: v)),
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            theme: theme,
            label: 'Weekly promo suggestions',
            value: prefs.suggestWeeklyPromo,
            onChanged: (v) => onChanged(prefs.copyWith(suggestWeeklyPromo: v)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.textMuted, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reminders are scheduled for 10:00 AM, 2:00 PM and 6:00 PM based on your device time.',
                  style: TextStyle(color: theme.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final StudioThemeData theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: theme.surface,
          activeTrackColor: theme.textPrimary,
          inactiveThumbColor: theme.textMuted,
          inactiveTrackColor: theme.border,
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.displayValue,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  final StudioThemeData theme;
  final String label;
  final String displayValue;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: theme.textPrimary,
          inactiveColor: theme.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BlendModeDropdown extends StatelessWidget {
  const _BlendModeDropdown({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final StudioThemeData theme;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.scaffold,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: theme.surfaceElevated,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.textMuted),
          style: TextStyle(color: theme.textPrimary, fontSize: 13),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: kWatermarkBlendModes.map((mode) {
            return DropdownMenuItem<String>(
              value: mode.$1,
              child: Text(
                mode.$2,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
          selectedItemBuilder: (_) => kWatermarkBlendModes.map((mode) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mode.$2,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PositionSelector extends StatelessWidget {
  const _PositionSelector({
    required this.theme,
    required this.position,
    required this.onChanged,
  });

  final StudioThemeData theme;
  final WatermarkPosition position;
  final ValueChanged<WatermarkPosition> onChanged;

  @override
  Widget build(BuildContext context) {
    final positions = WatermarkPosition.values;
    return ToggleButtons(
      isSelected: positions.map((p) => p == position).toList(),
      onPressed: (index) => onChanged(positions[index]),
      borderRadius: BorderRadius.circular(10),
      borderColor: theme.border,
      selectedBorderColor: theme.textPrimary,
      fillColor: theme.textPrimary,
      color: theme.textMuted,
      selectedColor: theme.surface,
      constraints: const BoxConstraints(minHeight: 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      children: positions.map((p) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            p.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }
}