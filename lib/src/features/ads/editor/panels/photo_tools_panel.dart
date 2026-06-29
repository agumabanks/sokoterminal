import 'package:flutter/material.dart';

import '../../ad_templates.dart';
import '../editor_shared_widgets.dart';

// ---------------------------------------------------------------------------
// Photo Tools panel — one-tap access to essential photo editing actions.
// Fully implemented: crop, rotate, flip, remove background, add text/sticker.
// Scaffolded: filters, adjust, enhance, doodle, replace color, portrait,
// PIP, mask, details/effects.
// ---------------------------------------------------------------------------

class PhotoToolsPanel extends StatelessWidget {
  const PhotoToolsPanel({
    super.key,
    required this.element,
    required this.onCrop,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onFlipH,
    required this.onFlipV,
    required this.onRemoveBg,
    required this.onAddText,
    required this.onAddSticker,
    required this.onOpenFilters,
    required this.onOpenAdjust,
  });

  final CanvasElement? element;
  final VoidCallback? onCrop;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;
  final VoidCallback? onFlipH;
  final VoidCallback? onFlipV;
  final VoidCallback? onRemoveBg;
  final VoidCallback? onAddText;
  final VoidCallback? onAddSticker;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenAdjust;

  static final _tools = [
    (
      id: 'crop',
      icon: Icons.crop_rounded,
      label: 'Crop',
      color: Color(0xFF3b82f6),
      needsImage: true,
    ),
    (
      id: 'rotate_left',
      icon: Icons.rotate_left_rounded,
      label: 'Rotate L',
      color: Color(0xFF6366f1),
      needsImage: true,
    ),
    (
      id: 'rotate_right',
      icon: Icons.rotate_right_rounded,
      label: 'Rotate R',
      color: Color(0xFF6366f1),
      needsImage: true,
    ),
    (
      id: 'flip_h',
      icon: Icons.flip_rounded,
      label: 'Flip H',
      color: Color(0xFF8b5cf6),
      needsImage: true,
    ),
    (
      id: 'flip_v',
      icon: Icons.flip_camera_android_rounded,
      label: 'Flip V',
      color: Color(0xFF8b5cf6),
      needsImage: true,
    ),
    (
      id: 'remove_bg',
      icon: Icons.layers_clear_rounded,
      label: 'Cutout',
      color: Color(0xFFec4899),
      needsImage: true,
    ),
    (
      id: 'filters',
      icon: Icons.photo_filter_rounded,
      label: 'Filters',
      color: Color(0xFFf59e0b),
      needsImage: true,
    ),
    (
      id: 'adjust',
      icon: Icons.tune_rounded,
      label: 'Adjust',
      color: Color(0xFF10b981),
      needsImage: true,
    ),
    (
      id: 'text',
      icon: Icons.title_rounded,
      label: 'Text',
      color: Color(0xFF06b6d4),
      needsImage: false,
    ),
    (
      id: 'sticker',
      icon: Icons.emoji_emotions_outlined,
      label: 'Sticker',
      color: Color(0xFFf97316),
      needsImage: false,
    ),
    (
      id: 'enhance',
      icon: Icons.auto_fix_high_rounded,
      label: 'Enhance',
      color: Color(0xFF14b8a6),
      needsImage: true,
    ),
    (
      id: 'doodle',
      icon: Icons.brush_rounded,
      label: 'Doodle',
      color: Color(0xFFa855f7),
      needsImage: false,
    ),
    (
      id: 'replace_color',
      icon: Icons.colorize_rounded,
      label: 'Replace',
      color: Color(0xFFef4444),
      needsImage: true,
    ),
    (
      id: 'portrait',
      icon: Icons.face_retouching_natural_rounded,
      label: 'Portrait',
      color: Color(0xFFd946ef),
      needsImage: true,
    ),
    (
      id: 'pip',
      icon: Icons.picture_in_picture_alt_rounded,
      label: 'PIP',
      color: Color(0xFF84cc16),
      needsImage: false,
    ),
    (
      id: 'mask',
      icon: Icons.filter_frames_rounded,
      label: 'Mask',
      color: Color(0xFF64748b),
      needsImage: true,
    ),
    (
      id: 'details',
      icon: Icons.bubble_chart_rounded,
      label: 'Details',
      color: Color(0xFF0ea5e9),
      needsImage: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final el = element;
    final hasImage = el != null && el.type == 'image';

    return PanelWrap(
      height: 320,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasImage)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.white38, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap an image on the canvas to edit it.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tools.map((t) {
                final enabled = !t.needsImage || hasImage;
                return _ToolChip(
                  icon: t.icon,
                  label: t.label,
                  color: t.color,
                  enabled: enabled,
                  onTap: enabled ? () => _handleTap(context, t.id) : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String id) {
    switch (id) {
      case 'crop':
        onCrop?.call();
      case 'rotate_left':
        onRotateLeft?.call();
      case 'rotate_right':
        onRotateRight?.call();
      case 'flip_h':
        onFlipH?.call();
      case 'flip_v':
        onFlipV?.call();
      case 'remove_bg':
        onRemoveBg?.call();
      case 'filters':
        onOpenFilters?.call();
      case 'adjust':
        onOpenAdjust?.call();
      case 'text':
        onAddText?.call();
      case 'sticker':
        onAddSticker?.call();
      case 'enhance':
      case 'doodle':
      case 'replace_color':
      case 'portrait':
      case 'pip':
      case 'mask':
      case 'details':
        _showScaffoldNotice(context, id);
    }
  }

  void _showScaffoldNotice(BuildContext context, String id) {
    final label = _tools.firstWhere((t) => t.id == id).label;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label tool selected — implementation scaffold ready.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: enabled ? color.withValues(alpha: 0.35) : Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(color: enabled ? Colors.white70 : Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
