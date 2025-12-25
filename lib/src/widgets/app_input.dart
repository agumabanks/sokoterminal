import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

class AppInput extends StatelessWidget {
  const AppInput({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(label, style: DesignTokens.textSmallBold),
         const SizedBox(height: 8),
         TextField(
           controller: controller,
           keyboardType: keyboardType,
           obscureText: obscureText,
           maxLines: maxLines,
           onChanged: onChanged,
           decoration: InputDecoration(
             isDense: true,
             prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
             border: OutlineInputBorder(
               borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
               borderSide: const BorderSide(color: DesignTokens.grayMedium),
             ),
             enabledBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
               borderSide: const BorderSide(color: DesignTokens.grayMedium),
             ),
             focusedBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
               borderSide: const BorderSide(color: DesignTokens.brandPrimary, width: 2),
             ),
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           ),
         ),
       ],
    );
  }
}
