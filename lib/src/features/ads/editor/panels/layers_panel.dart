import 'package:flutter/material.dart';

import '../../ad_templates.dart';
import '../editor_shared_widgets.dart';
import '../../../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Layers panel
// ---------------------------------------------------------------------------

class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.elements,
    required this.selectedId,
    required this.onSelect,
    required this.onReorder,
    required this.onToggleLock,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  final List<CanvasElement> elements;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final void Function(int oldZ, int newZ) onReorder;
  final ValueChanged<String> onToggleLock;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final sorted = [...elements].reversed.toList(); // Top layer first
    if (sorted.isEmpty) {
      return const PanelWrap(
        height: 120,
        child: Center(
          child: _SelectElementHint(),
        ),
      );
    }
    return PanelWrap(
      height: 240,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: sorted.length,
        itemBuilder: (_, i) {
          final el = sorted[i];
          final isSel = el.id == selectedId;
          final isTop = i == 0;
          final isBottom = i == sorted.length - 1;
          return GestureDetector(
            onTap: () => onSelect(el.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isSel ? kAccent.withValues(alpha: 0.12) : Colors.transparent,
              child: Row(
                children: [
                  // Layer type icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSel ? kAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _iconForType(el.type),
                      color: isSel ? kAccent : (el.isVisible ? Colors.white38 : Colors.white24),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _labelFor(el),
                          style: TextStyle(
                            color: isSel ? Colors.white : (el.isVisible ? Colors.white60 : Colors.white30),
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (el.type == 'image' && el.src != null && el.src!.isNotEmpty)
                          Text(
                            el.src!.startsWith('http') ? 'Remote' : 'Local',
                            style: const TextStyle(color: Colors.white24, fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                  // Reorder controls
                  if (!isTop)
                    GestureDetector(
                      onTap: () => onReorder(el.zIndex, el.zIndex + 1),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white24, size: 18),
                    ),
                  if (!isBottom)
                    GestureDetector(
                      onTap: () => onReorder(el.zIndex, el.zIndex - 1),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.arrow_downward_rounded,
                            color: Colors.white24, size: 18),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Visibility
                  GestureDetector(
                    onTap: () => onToggleVisibility(el.id),
                    child: Icon(
                      el.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: el.isVisible ? (isSel ? kAccent : Colors.white38) : Colors.white24,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Lock
                  GestureDetector(
                    onTap: () => onToggleLock(el.id),
                    child: Icon(
                      el.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: el.isLocked ? DesignTokens.warning : Colors.white24,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  GestureDetector(
                    onTap: () => onDelete(el.id),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 18),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'text' || 'sticker' => Icons.title_rounded,
      'image' => Icons.image_rounded,
      'figure' => Icons.rectangle_rounded,
      'icon' => Icons.insert_emoticon_rounded,
      'illustration' => Icons.format_paint_rounded,
      _ => Icons.layers_rounded,
    };
  }

  String _labelFor(CanvasElement el) {
    if (el.text != null && el.text!.trim().isNotEmpty) {
      final t = el.text!.trim();
      if (t.length > 24) return '${t.substring(0, 24)}…';
      return t;
    }
    return '${el.type[0].toUpperCase()}${el.type.substring(1)} layer';
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
              'Tap an element on the canvas to edit it.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
