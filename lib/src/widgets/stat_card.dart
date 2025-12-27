import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// A premium stat card for displaying metrics on dashboards.
/// 
/// Features:
/// - Gradient backgrounds for premium feel
/// - Trend indicators (up/down arrows)
/// - Animated value transitions
/// - Compact and expanded variants
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.trendLabel,
    this.variant = StatCardVariant.standard,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final StatTrend? trend;
  final String? trendLabel;
  final StatCardVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: variant.backgroundColor,
          gradient: variant.gradientBackground,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: DesignTokens.paddingXs,
                    decoration: BoxDecoration(
                      color: variant.iconBackgroundColor,
                      borderRadius: DesignTokens.borderRadiusSm,
                    ),
                    child: Icon(
                      icon,
                      size: DesignTokens.iconSm,
                      color: variant.iconColor,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: DesignTokens.textSmall.copyWith(
                      color: variant.labelColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trend != null) _TrendBadge(trend: trend!, label: trendLabel),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              value,
              style: DesignTokens.textTitle.copyWith(
                color: variant.valueColor,
                fontSize: variant == StatCardVariant.compact ? 18 : 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend, this.label});
  final StatTrend trend;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = trend == StatTrend.up
        ? DesignTokens.success
        : trend == StatTrend.down
            ? DesignTokens.error
            : DesignTokens.grayMedium;

    final icon = trend == StatTrend.up
        ? Icons.trending_up
        : trend == StatTrend.down
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: DesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: DesignTokens.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (label != null) ...[
            const SizedBox(width: DesignTokens.spaceXs),
            Text(
              label!,
              style: DesignTokens.textSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum StatTrend { up, down, flat }

enum StatCardVariant {
  standard,
  compact,
  gradient,
  accent;

  Color get backgroundColor {
    switch (this) {
      case StatCardVariant.standard:
      case StatCardVariant.compact:
        return DesignTokens.surfaceWhite;
      case StatCardVariant.gradient:
        return Colors.transparent;
      case StatCardVariant.accent:
        return DesignTokens.brandAccentLight;
    }
  }

  LinearGradient? get gradientBackground {
    switch (this) {
      case StatCardVariant.gradient:
        return DesignTokens.brandGradient;
      default:
        return null;
    }
  }

  Color get labelColor {
    switch (this) {
      case StatCardVariant.gradient:
        return DesignTokens.surfaceWhite.withValues(alpha: 0.8);
      default:
        return DesignTokens.grayMedium;
    }
  }

  Color get valueColor {
    switch (this) {
      case StatCardVariant.gradient:
        return DesignTokens.surfaceWhite;
      case StatCardVariant.accent:
        return DesignTokens.brandPrimary;
      default:
        return DesignTokens.grayDark;
    }
  }

  Color get iconColor {
    switch (this) {
      case StatCardVariant.gradient:
        return DesignTokens.surfaceWhite;
      case StatCardVariant.accent:
        return DesignTokens.brandAccent;
      default:
        return DesignTokens.brandPrimary;
    }
  }

  Color get iconBackgroundColor {
    switch (this) {
      case StatCardVariant.gradient:
        return DesignTokens.surfaceWhite.withValues(alpha: 0.2);
      case StatCardVariant.accent:
        return DesignTokens.brandAccent.withValues(alpha: 0.15);
      default:
        return DesignTokens.grayLight.withValues(alpha: 0.5);
    }
  }
}

/// Row of stat cards that adapts to screen width
class StatCardRow extends StatelessWidget {
  const StatCardRow({required this.cards, super.key});
  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Wide layout: all cards in one row
          return Row(
            children: cards
                .map((card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: DesignTokens.spaceSm),
                        child: card,
                      ),
                    ))
                .toList(),
          );
        }
        // Narrow layout: 2 cards per row
        return Wrap(
          spacing: DesignTokens.spaceSm,
          runSpacing: DesignTokens.spaceSm,
          children: cards
              .map((card) => SizedBox(
                    width: (constraints.maxWidth - DesignTokens.spaceSm) / 2,
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }
}
