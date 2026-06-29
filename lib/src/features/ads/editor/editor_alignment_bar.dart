import 'package:flutter/material.dart';

import 'editor_state.dart';
import '../../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Alignment bar
// ---------------------------------------------------------------------------

class AlignmentBar extends StatelessWidget {
  const AlignmentBar({super.key, required this.onAlign});
  final ValueChanged<AlignMode> onAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: DesignTokens.brandPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ABtn(Icons.align_horizontal_left_rounded, 'Left', () => onAlign(AlignMode.left)),
          _ABtn(Icons.align_horizontal_center_rounded, 'Center', () => onAlign(AlignMode.centerH)),
          _ABtn(Icons.align_horizontal_right_rounded, 'Right', () => onAlign(AlignMode.right)),
          Container(width: 1, height: 20, color: Colors.white12),
          _ABtn(Icons.align_vertical_top_rounded, 'Top', () => onAlign(AlignMode.top)),
          _ABtn(Icons.align_vertical_center_rounded, 'Middle', () => onAlign(AlignMode.centerV)),
          _ABtn(Icons.align_vertical_bottom_rounded, 'Bottom', () => onAlign(AlignMode.bottom)),
        ],
      ),
    );
  }
}

class _ABtn extends StatelessWidget {
  const _ABtn(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(icon, color: Colors.white54, size: 18),
          ),
        ),
      );
}
