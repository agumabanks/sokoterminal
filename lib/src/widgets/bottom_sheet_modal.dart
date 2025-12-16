import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/design_tokens.dart';

/// A premium bottom sheet modal with glassmorphism effect.
/// 
/// Use this instead of AlertDialog for all modal interactions
/// to maintain consistent, premium UI.
/// 
/// Example usage:
/// ```dart
/// BottomSheetModal.show(
///   context: context,
///   title: 'Park Sale',
///   child: YourContent(),
/// );
/// ```
class BottomSheetModal extends StatelessWidget {
  const BottomSheetModal({
    required this.child,
    this.title,
    this.subtitle,
    this.showHandle = true,
    this.showCloseButton = true,
    this.padding,
    this.maxHeight,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showHandle;
  final bool showCloseButton;
  final EdgeInsets? padding;
  final double? maxHeight;

  /// Show the bottom sheet modal
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    bool showHandle = true,
    bool showCloseButton = true,
    bool isDismissible = true,
    bool enableDrag = true,
    EdgeInsets? padding,
    double? maxHeight,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => BottomSheetModal(
        title: title,
        subtitle: subtitle,
        showHandle: showHandle,
        showCloseButton: showCloseButton,
        padding: padding,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveMaxHeight = maxHeight ?? screenHeight * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite.withOpacity(0.92),
        borderRadius: DesignTokens.borderRadiusBottomSheet,
      ),
      child: ClipRRect(
        borderRadius: DesignTokens.borderRadiusBottomSheet,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              if (showHandle) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignTokens.grayLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
              ],

              // Header with title
              if (title != null || showCloseButton)
                Padding(
                  padding: EdgeInsets.only(
                    left: DesignTokens.spaceMd,
                    right: showCloseButton ? DesignTokens.spaceXs : DesignTokens.spaceMd,
                    top: showHandle ? 0 : DesignTokens.spaceMd,
                    bottom: DesignTokens.spaceSm,
                  ),
                  child: Row(
                    children: [
                      if (title != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title!, style: DesignTokens.textTitle),
                              if (subtitle != null) ...[
                                const SizedBox(height: DesignTokens.spaceXs),
                                Text(subtitle!, style: DesignTokens.textSmall),
                              ],
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      if (showCloseButton)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: DesignTokens.grayMedium,
                          style: IconButton.styleFrom(
                            backgroundColor: DesignTokens.grayLight.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                ),

              // Content
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: padding?.left ?? DesignTokens.spaceMd,
                    right: padding?.right ?? DesignTokens.spaceMd,
                    top: padding?.top ?? 0,
                    bottom: bottomInset + (padding?.bottom ?? DesignTokens.spaceLg),
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrollable bottom sheet for longer content
class ScrollableBottomSheetModal extends StatelessWidget {
  const ScrollableBottomSheetModal({
    required this.children,
    this.title,
    this.subtitle,
    this.showHandle = true,
    this.showCloseButton = true,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final String? subtitle;
  final bool showHandle;
  final bool showCloseButton;

  static Future<T?> show<T>({
    required BuildContext context,
    required List<Widget> children,
    String? title,
    String? subtitle,
    bool showHandle = true,
    bool showCloseButton = true,
    bool isDismissible = true,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ScrollableBottomSheetModal(
        title: title,
        subtitle: subtitle,
        showHandle: showHandle,
        showCloseButton: showCloseButton,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetModal(
      title: title,
      subtitle: subtitle,
      showHandle: showHandle,
      showCloseButton: showCloseButton,
      child: ListView(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// Quick action bottom sheet with a list of options
class ActionBottomSheet extends StatelessWidget {
  const ActionBottomSheet({
    required this.actions,
    this.title,
    super.key,
  });

  final List<ActionSheetItem> actions;
  final String? title;

  static Future<T?> show<T>({
    required BuildContext context,
    required List<ActionSheetItem> actions,
    String? title,
  }) {
    return BottomSheetModal.show<T>(
      context: context,
      title: title,
      showCloseButton: false,
      child: ActionBottomSheet(actions: actions, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...actions.map((action) => _ActionTile(action: action)),
        const SizedBox(height: DesignTokens.spaceSm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: DesignTokens.paddingMd,
            ),
            child: Text(
              'Cancel',
              style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final ActionSheetItem action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive ? DesignTokens.error : DesignTokens.brandPrimary;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        action.onTap?.call();
      },
      borderRadius: DesignTokens.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceMd,
        ),
        child: Row(
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, color: color, size: DesignTokens.iconMd),
              const SizedBox(width: DesignTokens.spaceMd),
            ],
            Expanded(
              child: Text(
                action.label,
                style: DesignTokens.textBody.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (action.trailing != null) action.trailing!,
          ],
        ),
      ),
    );
  }
}

class ActionSheetItem {
  const ActionSheetItem({
    required this.label,
    this.icon,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;
}
