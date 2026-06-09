import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ad_templates.dart';
import 'canvas_background.dart';
import 'illustration_renderer.dart';
import 'studio_variable_context.dart';
import '../../widgets/offline_cached_image.dart';

/// Non-interactive preview (used in gallery cards, thumbnails).
class CanvasPreview extends StatelessWidget {
  const CanvasPreview({
    super.key,
    required this.template,
    this.imageCache = const {},
    this.interactive = false,
    this.onElementTap,
    this.variableContext,
  });

  final AdTemplate template;
  final Map<String, ui.Image> imageCache;
  final bool interactive;
  final void Function(CanvasElement)? onElementTap;
  final StudioVariableContext? variableContext;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: template.aspectRatio,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final scaleX = constraints.maxWidth / template.canvasWidth;
        final scaleY = constraints.maxHeight / template.canvasHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(4 * scaleX),
          child: Stack(
            fit: StackFit.expand,
            children: [
              buildCanvasBackground(background: template.background),
              ...template.elements.map((el) {
                return Positioned(
                  left: el.x * scaleX,
                  top: el.y * scaleY,
                  width: el.width * scaleX,
                  height: el.type == 'text' || el.type == 'sticker'
                      ? null
                      : el.height * scaleY,
                  child: Opacity(
                    opacity: el.opacity.clamp(0.0, 1.0),
                    child: _buildStaticElement(el, scaleX, scaleY),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStaticElement(CanvasElement el, double sx, double sy) {
    Widget child;
    switch (el.type) {
      case 'figure':
        child = _FigureWidget(el: el, sx: sx, sy: sy);
      case 'image':
        child = _ImageWidget(el: el, sx: sx, sy: sy);
      case 'icon':
        child = _IconWidget(el: el, sx: sx, sy: sy);
      case 'illustration':
        child = _IllustrationWidget(el: el, sx: sx, sy: sy);
      case 'text':
      case 'sticker':
      default:
        child = _TextWidget(
          el: el,
          sx: sx,
          variableContext: variableContext,
        );
    }
    if (interactive && onElementTap != null) {
      return GestureDetector(onTap: () => onElementTap!(el), child: child);
    }
    return child;
  }
}

/// Interactive canvas used inside the ad editor.
/// Supports tap-to-select, drag-to-move, and broadcasts selection changes.
class InteractiveCanvas extends StatefulWidget {
  const InteractiveCanvas({
    super.key,
    required this.template,
    required this.selectedElementId,
    required this.onElementSelected,
    required this.onElementMoved,
    required this.onElementResized,
  });

  final AdTemplate template;
  final String? selectedElementId;
  final ValueChanged<String?> onElementSelected;
  final void Function(String elementId, double dx, double dy) onElementMoved;
  final void Function(String elementId, double dw, double dh) onElementResized;

  @override
  State<InteractiveCanvas> createState() => _InteractiveCanvasState();
}

class _InteractiveCanvasState extends State<InteractiveCanvas> {
  Offset? _dragStart;

  String? _hitTest(Offset localPos, double sx, double sy) {
    // Iterate in reverse (top elements first)
    for (final el in widget.template.elements.reversed) {
      final left = el.x * sx;
      final top = el.y * sy;
      final w = el.width * sx;
      final h = el.type == 'text'
          ? ((el.fontSize ?? 24) * sx * 2.0).clamp(30.0, 500.0)
          : el.height * sy;
      if (localPos.dx >= left &&
          localPos.dx <= left + w &&
          localPos.dy >= top &&
          localPos.dy <= top + h) {
        return el.id;
      }
    }
    return null;
  }

  void _handleTap(Offset localPos, double sx, double sy) {
    final id = _hitTest(localPos, sx, sy);
    widget.onElementSelected(id);
  }

  void _handleDragStart(Offset localPos, double sx, double sy) {
    final id = _hitTest(localPos, sx, sy);
    if (id != null) {
      widget.onElementSelected(id);
      _dragStart = localPos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.template.aspectRatio,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final sx = constraints.maxWidth / widget.template.canvasWidth;
        final sy = constraints.maxHeight / widget.template.canvasHeight;

        return Listener(
          onPointerDown: (event) {
            final pos = event.localPosition;
            final id = _hitTest(pos, sx, sy);
            widget.onElementSelected(id);
            if (id != null) {
              _dragStart = pos;
            }
          },
          onPointerMove: (event) {
            if (_dragStart == null || widget.selectedElementId == null) return;
            widget.onElementMoved(
              widget.selectedElementId!,
              event.delta.dx / sx,
              event.delta.dy / sy,
            );
          },
          onPointerUp: (_) => _dragStart = null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4 * sx),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                buildCanvasBackground(background: widget.template.background),
                ...widget.template.elements.map((el) {
                  final left = el.x * sx;
                  final top = el.y * sy;
                  final w = el.width * sx;
                  final isText =
                      el.type == 'text' || el.type == 'sticker';
                  final h = isText ? null : el.height * sy;

                  return Positioned(
                    left: left,
                    top: top,
                    width: w,
                    height: h,
                    child: Opacity(
                      opacity: el.opacity.clamp(0.0, 1.0),
                      child: _buildElement(el, sx, sy),
                    ),
                  );
                }),
                if (widget.selectedElementId != null)
                  ..._buildSelectionOverlay(sx, sy),
              ],
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildSelectionOverlay(double sx, double sy) {
    final el = widget.template.elements
        .where((e) => e.id == widget.selectedElementId)
        .firstOrNull;
    if (el == null) return [];

    final left = el.x * sx;
    final top = el.y * sy;
    final w = el.width * sx;
    // For text elements, estimate height from font size
    final h = el.type == 'text'
        ? ((el.fontSize ?? 24) * sx * 1.4).clamp(20.0, 500.0)
        : el.height * sy;
    const handleSize = 10.0;

    return [
      // Selection border
      Positioned(
        left: left - 1,
        top: top - 1,
        width: w + 2,
        height: h + 2,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4A90D9), width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),

      // Resize handles (corners only for images/figures)
      if (el.type == 'image' || el.type == 'figure') ...[
        _buildHandle(left - handleSize / 2, top - handleSize / 2, handleSize, 'tl', el, sx, sy),
        _buildHandle(left + w - handleSize / 2, top - handleSize / 2, handleSize, 'tr', el, sx, sy),
        _buildHandle(left - handleSize / 2, top + h - handleSize / 2, handleSize, 'bl', el, sx, sy),
        _buildHandle(left + w - handleSize / 2, top + h - handleSize / 2, handleSize, 'br', el, sx, sy),
      ],
    ];
  }

  Widget _buildHandle(double x, double y, double size, String handle, CanvasElement el, double sx, double sy) {
    return Positioned(
      left: x,
      top: y,
      width: size,
      height: size,
      child: GestureDetector(
        onPanUpdate: (d) {
          double dw = 0, dh = 0;
          if (handle.contains('r')) dw = d.delta.dx / sx;
          if (handle.contains('l')) dw = -d.delta.dx / sx;
          if (handle.contains('b')) dh = d.delta.dy / sy;
          if (handle.contains('t')) dh = -d.delta.dy / sy;
          widget.onElementResized(el.id, dw, dh);
          if (handle.contains('l')) {
            widget.onElementMoved(el.id, d.delta.dx / sx, 0);
          }
          if (handle.contains('t')) {
            widget.onElementMoved(el.id, 0, d.delta.dy / sy);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF4A90D9), width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildElement(CanvasElement el, double sx, double sy) {
    switch (el.type) {
      case 'figure':
        return _FigureWidget(el: el, sx: sx, sy: sy);
      case 'image':
        return _ImageWidget(el: el, sx: sx, sy: sy);
      case 'icon':
        return _IconWidget(el: el, sx: sx, sy: sy);
      case 'illustration':
        return _IllustrationWidget(el: el, sx: sx, sy: sy);
      case 'sticker':
      case 'text':
      default:
        return _TextWidget(el: el, sx: sx);
    }
  }
}

// ── Shared element widgets ────────────────────────────────────────────

class _IconWidget extends StatelessWidget {
  const _IconWidget({required this.el, required this.sx, required this.sy});
  final CanvasElement el;
  final double sx, sy;

  @override
  Widget build(BuildContext context) {
    if (el.iconCodePoint == null) {
      return _FigureWidget(el: el, sx: sx, sy: sy);
    }
    return Icon(
      IconData(
        el.iconCodePoint!,
        fontFamily: el.iconFontFamily,
        fontPackage: el.iconFontPackage,
      ),
      size: (el.width < el.height ? el.width : el.height) * sx * 0.72,
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
    );
  }
}

class _IllustrationWidget extends StatelessWidget {
  const _IllustrationWidget({required this.el, required this.sx, required this.sy});
  final CanvasElement el;
  final double sx, sy;

  @override
  Widget build(BuildContext context) {
    return IllustrationRenderer(
      assetId: el.assetId ?? 'burst_rays',
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
      width: el.width * sx,
      height: el.height * sy,
    );
  }
}

class _FigureWidget extends StatelessWidget {
  const _FigureWidget({required this.el, required this.sx, required this.sy});
  final CanvasElement el;
  final double sx, sy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: el.fill != null ? parseHexColor(el.fill!) : Colors.transparent,
        borderRadius: el.cornerRadius != null
            ? BorderRadius.circular(el.cornerRadius! * sx)
            : null,
      ),
    );
  }
}

class _ImageWidget extends StatelessWidget {
  const _ImageWidget({required this.el, required this.sx, required this.sy});
  final CanvasElement el;
  final double sx, sy;

  @override
  Widget build(BuildContext context) {
    final src = el.src;
    if (src == null || src.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: el.cornerRadius != null
              ? BorderRadius.circular(el.cornerRadius! * sx)
              : null,
        ),
        child: Center(
          child: Icon(Icons.image, size: 28 * sx, color: Colors.grey.shade400),
        ),
      );
    }
    return ClipRRect(
      borderRadius: el.cornerRadius != null
          ? BorderRadius.circular(el.cornerRadius! * sx)
          : BorderRadius.zero,
      child: OfflineCachedImage(
        imageUrl: src,
        width: el.width * sx,
        height: el.height * sy,
        fit: BoxFit.cover,
        errorWidget: Container(
          color: Colors.grey.shade200,
          child: Center(child: Icon(Icons.broken_image, size: 28 * sx, color: Colors.grey.shade400)),
        ),
      ),
    );
  }
}

class _TextWidget extends StatelessWidget {
  const _TextWidget({
    required this.el,
    required this.sx,
    this.variableContext,
  });
  final CanvasElement el;
  final double sx;
  final StudioVariableContext? variableContext;

  @override
  Widget build(BuildContext context) {
    final fontSize = (el.fontSize ?? 24) * sx;
    final isBold = el.fontWeight == 'bold' || el.fontWeight == '700' || el.fontWeight == '800' || el.fontWeight == '900';
    final isSemiBold = el.fontWeight == '600' || el.fontWeight == '500';
    TextAlign textAlign;
    switch (el.align) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      default:
        textAlign = TextAlign.center;
    }

    TextDecoration? decoration;
    if (el.textDecoration == 'line-through') {
      decoration = TextDecoration.lineThrough;
    }

    final isName = el.id.contains('product_name') || el.id.contains('name');
    final isTitle = el.id.contains('headline') || el.id.contains('badge');
    final maxLines = isName ? 2 : (isTitle ? 2 : 3);

    var style = TextStyle(
      fontSize: fontSize.clamp(4.0, 200.0),
      fontWeight: isBold ? FontWeight.bold : (isSemiBold ? FontWeight.w600 : FontWeight.w400),
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.black,
      decoration: decoration,
      height: el.lineHeight ?? 1.2,
      letterSpacing: el.letterSpacing ?? (isBold ? -0.3 : 0),
    );

    if (el.fontFamily != null && studioFonts.containsKey(el.fontFamily)) {
      try {
        style = GoogleFonts.getFont(
          studioFonts[el.fontFamily!]!,
          textStyle: style,
        );
      } catch (_) {}
    }

    final raw = el.text ?? '';
    final display = variableContext?.resolve(raw) ?? raw;

    return SizedBox(
      width: el.width * sx,
      child: Text(
        display,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
