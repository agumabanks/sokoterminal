import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

enum AppButtonVariant { primary, outline, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = _getStyle();
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
           Container(
             width: 16, height: 16,
             margin: const EdgeInsets.only(right: 8),
             child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
           )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 20),
          ),
        Text(label),
      ],
    );

    final btn = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: child,
    );

    if (expand) return SizedBox(width: double.infinity, height: 48, child: btn);
    return SizedBox(height: 48, child: btn);
  }

  ButtonStyle _getStyle() {
    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.brandPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
          elevation: 0,
        );
      case AppButtonVariant.outline:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: DesignTokens.brandPrimary,
          side: const BorderSide(color: DesignTokens.brandPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
          elevation: 0,
        );
      case AppButtonVariant.danger:
         return ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
          elevation: 0,
        );
      case AppButtonVariant.text:
       return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: DesignTokens.brandPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
        );
    }
  }
}
