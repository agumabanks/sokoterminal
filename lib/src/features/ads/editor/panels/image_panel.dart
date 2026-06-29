import 'package:flutter/material.dart';

import '../../ad_templates.dart';
import '../editor_shared_widgets.dart';

// ---------------------------------------------------------------------------
// Image panel
// ---------------------------------------------------------------------------

class ImagePanel extends StatelessWidget {
  const ImagePanel({
    super.key,
    required this.element,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onPickCatalog,
    required this.onRemoveBg,
    required this.onUpdate,
  });

  final CanvasElement? element;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onPickCatalog;
  final VoidCallback? onRemoveBg;
  final ValueChanged<CanvasElement>? onUpdate;

  @override
  Widget build(BuildContext context) {
    final el = element;
    final showHint = el == null || el.type != 'image';
    return PanelWrap(
      height: el?.type == 'image' ? 260 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHint) const _SelectElementHint(),
          // Source actions
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PanelAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: onPickGallery),
              PanelAction(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: onPickCamera),
              PanelAction(
                icon: Icons.folder_special_rounded,
                label: 'Catalog',
                color: const Color(0xFF3b82f6),
                onTap: onPickCatalog,
              ),
              if (onRemoveBg != null)
                PanelAction(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Remove BG',
                  color: const Color(0xFF6366f1),
                  onTap: onRemoveBg!,
                ),
            ],
          ),
          if (el != null && el.type == 'image' && onUpdate != null) ...[
            const SizedBox(height: 14),
            // Quick transform actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PanelAction(
                  icon: Icons.flip_rounded,
                  label: 'Flip H',
                  onTap: () => onUpdate!(el.copyWith(flipX: !el.flipX)),
                ),
                PanelAction(
                  icon: Icons.flip_rounded,
                  label: 'Flip V',
                  onTap: () => onUpdate!(el.copyWith(flipY: !el.flipY)),
                ),
                PanelAction(
                  icon: Icons.refresh_rounded,
                  label: 'Reset',
                  color: Colors.orangeAccent,
                  onTap: () => onUpdate!(el.copyWith(
                    flipX: false,
                    flipY: false,
                    rotation: 0.0,
                    opacity: 1.0,
                    cornerRadius: 0.0,
                    imageFit: 'cover',
                    imageFilter: null,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Fit mode selector
            _SectionTitle('Fit mode'),
            const SizedBox(height: 6),
            _FitModeSelector(
              value: el.imageFit ?? 'cover',
              onChanged: (v) => onUpdate!(el.copyWith(imageFit: v)),
            ),
            const SizedBox(height: 14),
            // Filter selector
            _SectionTitle('Filters'),
            const SizedBox(height: 6),
            _FilterSelector(
              value: el.imageFilter,
              onChanged: (v) => onUpdate!(el.copyWith(imageFilter: v)),
            ),
            const SizedBox(height: 12),
            // Opacity slider
            Row(
              children: [
                const Text('Opacity',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: el.opacity.clamp(0.1, 1.0),
                    min: 0.1,
                    max: 1.0,
                    activeColor: kAccent,
                    onChanged: (v) => onUpdate!(el.copyWith(opacity: v)),
                  ),
                ),
                Text('${(el.opacity * 100).round()}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            // Corner radius slider
            Row(
              children: [
                const Text('Corners',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: (el.cornerRadius ?? 0).clamp(0, 80),
                    min: 0,
                    max: 80,
                    activeColor: kAccent,
                    onChanged: (v) => onUpdate!(el.copyWith(cornerRadius: v)),
                  ),
                ),
                Text('${(el.cornerRadius ?? 0).round()}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FitModeSelector extends StatelessWidget {
  const _FitModeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('cover', Icons.crop_square, 'Cover'),
    ('contain', Icons.fit_screen, 'Contain'),
    ('fill', Icons.aspect_ratio, 'Fill'),
    ('none', Icons.crop_free, 'None'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _options.map((o) {
        final selected = value == o.$1;
        return GestureDetector(
          onTap: () => onChanged(o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? kAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? kAccent : Colors.white24,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(o.$2, color: selected ? kAccent : Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  o.$3,
                  style: TextStyle(
                    color: selected ? kAccent : Colors.white54,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FilterSelector extends StatelessWidget {
  const _FilterSelector({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = [
    (null, 'Normal', null),
    ('grayscale', 'B&W', Colors.grey),
    ('sepia', 'Sepia', Color(0xFF704214)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: _options.map((o) {
        final selected = value == o.$1;
        return GestureDetector(
          onTap: () => onChanged(o.$1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: o.$3?.withValues(alpha: 0.25) ?? Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? kAccent : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: o.$1 == null
                      ? Icon(Icons.no_photography_outlined, color: selected ? kAccent : Colors.white54, size: 18)
                      : Icon(
                          o.$1 == 'grayscale' ? Icons.filter_b_and_w : Icons.wb_sunny_outlined,
                          color: selected ? kAccent : o.$3,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                o.$2,
                style: TextStyle(
                  color: selected ? kAccent : Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SelectElementHint extends StatelessWidget {
  const _SelectElementHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
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
    );
  }
}
