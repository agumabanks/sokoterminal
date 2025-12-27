import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/design_tokens.dart';

/// A unified action tile for list-style navigation.
/// 
/// Used in the More screen and similar menus for consistent
/// navigation and action items.
class ActionTile extends StatelessWidget {
  const ActionTile({
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.iconBackgroundColor,
    this.showChevron = true,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final bool showChevron;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surfaceWhite,
      borderRadius: DesignTokens.borderRadiusMd,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: DesignTokens.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceMd,
          ),
          child: Row(
            children: [
              _IconContainer(
                icon: icon,
                color: iconColor,
                backgroundColor: iconBackgroundColor,
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DesignTokens.textBodyBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DesignTokens.spaceXxs),
                      Text(
                        subtitle!,
                        style: DesignTokens.textSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceSm,
                    vertical: DesignTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: DesignTokens.textSmall.copyWith(
                      color: DesignTokens.surfaceWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSm),
              ],
              if (trailing != null)
                trailing!
              else if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: DesignTokens.grayMedium,
                  size: DesignTokens.iconMd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({
    required this.icon,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? DesignTokens.brandPrimary;
    final effectiveBackground = backgroundColor ?? effectiveColor.withValues(alpha: 0.1);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: DesignTokens.borderRadiusMd,
      ),
      child: Icon(
        icon,
        color: effectiveColor,
        size: DesignTokens.iconMd,
      ),
    );
  }
}

/// A compact action tile for grid layouts
class ActionTileCompact extends StatelessWidget {
  const ActionTileCompact({
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? DesignTokens.brandPrimary;

    return Material(
      color: DesignTokens.surfaceWhite,
      borderRadius: DesignTokens.borderRadiusMd,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: DesignTokens.borderRadiusMd,
        child: Stack(
          children: [
            Padding(
              padding: DesignTokens.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.1),
                      borderRadius: DesignTokens.borderRadiusSm,
                    ),
                    child: Icon(
                      icon,
                      color: effectiveColor,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: DesignTokens.textBodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DesignTokens.spaceXxs),
                    Text(
                      subtitle!,
                      style: DesignTokens.textSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: DesignTokens.spaceSm,
                right: DesignTokens.spaceSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceSm,
                    vertical: DesignTokens.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: DesignTokens.textSmall.copyWith(
                      color: DesignTokens.surfaceWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A section header for grouping action tiles
class ActionTileSection extends StatelessWidget {
  const ActionTileSection({
    required this.title,
    required this.children,
    this.icon,
    super.key,
  });

  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: DesignTokens.spaceXs,
            bottom: DesignTokens.spaceSm,
            top: DesignTokens.spaceMd,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: DesignTokens.iconSm,
                  color: DesignTokens.grayMedium,
                ),
                const SizedBox(width: DesignTokens.spaceSm),
              ],
              Text(
                title.toUpperCase(),
                style: DesignTokens.textSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: DesignTokens.borderRadiusMd,
            boxShadow: DesignTokens.shadowSm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 76),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: DesignTokens.grayLight.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
