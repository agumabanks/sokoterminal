import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------
const kAccent = DesignTokens.brandAccent;
const kSurface = DesignTokens.brandPrimary;
const kBg = DesignTokens.brandPrimary;

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class PanelWrap extends StatelessWidget {
  const PanelWrap({super.key, required this.child, this.height});
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.brandPrimary,
      constraints: BoxConstraints(maxHeight: height ?? 160),
      child: child,
    );
  }
}

class PanelAction extends StatelessWidget {
  const PanelAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class ToggleBtn extends StatelessWidget {
  const ToggleBtn({
    super.key,
    this.icon,
    this.label,
    required this.active,
    required this.onTap,
    this.bold = false,
    this.underline = false,
  });
  final IconData? icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;
  final bool bold;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: active ? kAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? kAccent : Colors.transparent),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: active ? kAccent : Colors.white38, size: 18)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: active ? kAccent : Colors.white38,
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
                    decoration: underline ? TextDecoration.underline : TextDecoration.none,
                    decorationColor: active ? kAccent : Colors.white38,
                  ),
                ),
        ),
      ),
    );
  }
}

class DarkField extends StatelessWidget {
  const DarkField({
    super.key,
    required this.ctrl,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kAccent)),
        ),
      );
}
