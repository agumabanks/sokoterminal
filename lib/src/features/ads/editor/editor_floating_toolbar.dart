import 'package:flutter/material.dart';

import '../ad_templates.dart';
import '../../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Floating element toolbar (above selected element)
// ---------------------------------------------------------------------------

class FloatingToolbar extends StatelessWidget {
  const FloatingToolbar({
    super.key,
    required this.element,
    required this.onDelete,
    required this.onDuplicate,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onLock,
    this.onEditText,
    this.onEditFont,
    this.onEditImage,
  });

  final CanvasElement element;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final VoidCallback onLock;
  final VoidCallback? onEditText;
  final VoidCallback? onEditFont;
  final VoidCallback? onEditImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: DesignTokens.brandPrimary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEditText != null) _FTBtn(Icons.edit_rounded, 'Edit', onEditText!),
            if (onEditFont != null) _FTBtn(Icons.font_download_rounded, 'Font', onEditFont!),
            if (onEditImage != null) _FTBtn(Icons.image_rounded, 'Image', onEditImage!),
            _FTBtn(Icons.content_copy_rounded, 'Copy', onDuplicate),
            _FTBtn(Icons.flip_to_front_rounded, '↑', onBringForward),
            _FTBtn(Icons.flip_to_back_rounded, '↓', onSendBackward),
            _FTBtn(
              element.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              element.isLocked ? 'Unlock' : 'Lock',
              onLock,
              color: element.isLocked ? DesignTokens.warning : null,
            ),
            _FTBtn(Icons.delete_rounded, 'Del', onDelete, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }
}

class _FTBtn extends StatelessWidget {
  const _FTBtn(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: c, size: 16),
              Text(label, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
