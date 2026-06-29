import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ad_templates.dart';
import '../canvas_background.dart';
import '../illustration_renderer.dart';
import '../studio_variable_context.dart';
import 'editor_shared_widgets.dart';
import 'editor_state.dart';

// ---------------------------------------------------------------------------
// Editor canvas with element rendering + handles
// ---------------------------------------------------------------------------

enum ResizeAnchor { topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left }

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({
    super.key,
    required this.state,
    required this.scale,
    required this.isExporting,
    required this.variableContext,
    required this.onElementTap,
    required this.onCanvasTap,
    required this.onElementMoved,
    required this.onElementResized,
    required this.onElementRotated,
  });

  final EditorState state;
  final double scale;
  final bool isExporting;
  final StudioVariableContext variableContext;
  final ValueChanged<String> onElementTap;
  final VoidCallback onCanvasTap;
  final void Function(String id, double dx, double dy) onElementMoved;
  final void Function(String id, double dw, double dh, ResizeAnchor anchor) onElementResized;
  final void Function(String id, double angle) onElementRotated;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  Offset? _dragStart;
  Offset? _resizeStart;
  ResizeAnchor? _activeAnchor;
  Offset? _rotateStart;
  Offset? _rotateCenter;
  double? _rotateStartAngle;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scale = widget.scale;
    final tpl = state.template;
    final cw = tpl.canvasWidth * scale;
    final ch = tpl.canvasHeight * scale;

    return GestureDetector(
      onTap: widget.onCanvasTap,
      child: Container(
        width: cw, height: ch,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Positioned.fill(
              child: buildCanvasBackground(background: tpl.background),
            ),

            // Grid
            if (state.showGrid)
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter(scale)),
              ),

            // Elements sorted by zIndex
            ...state.sortedElements.where((el) => el.isVisible).map((el) {
              final isSelected = !widget.isExporting && el.id == state.selectedId;
              return ElementWidget(
                key: ValueKey(el.id),
                el: el,
                scale: scale,
                isSelected: isSelected,
                variableContext: widget.variableContext,
                onTap: () => widget.onElementTap(el.id),
                onMoveStart: (pos) => _dragStart = pos,
                onMoveUpdate: (pos) {
                  if (_dragStart != null) {
                    final d = pos - _dragStart!;
                    _dragStart = pos;
                    widget.onElementMoved(el.id, d.dx, d.dy);
                  }
                },
                onResizeStart: (pos, anchor) {
                  _resizeStart = pos;
                  _activeAnchor = anchor;
                },
                onResizeUpdate: (pos) {
                  if (_resizeStart != null && _activeAnchor != null) {
                    final d = pos - _resizeStart!;
                    _resizeStart = pos;
                    widget.onElementResized(el.id, d.dx, d.dy, _activeAnchor!);
                  }
                },
                onRotateStart: (pos, center) {
                  _rotateCenter = center;
                  _rotateStart = pos;
                  _rotateStartAngle = el.rotation;
                },
                onRotateUpdate: (pos) {
                  if (_rotateCenter != null && _rotateStart != null) {
                    final startA = (_rotateStart! - _rotateCenter!).direction;
                    final currA = (pos - _rotateCenter!).direction;
                    final angle = (_rotateStartAngle ?? 0) + currA - startA;
                    widget.onElementRotated(el.id, angle);
                  }
                },
              );
            }),

            // Snap guide lines (suppressed during export)
            if (state.snapEnabled && !widget.isExporting)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SnapGuidePainter(
                      tpl: tpl, selected: state.selected, scale: scale)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Element widget with handles
// ---------------------------------------------------------------------------

const _kHandleSize = 18.0;

class ElementWidget extends StatelessWidget {
  const ElementWidget({
    super.key,
    required this.el,
    required this.scale,
    required this.isSelected,
    required this.variableContext,
    required this.onTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onRotateStart,
    required this.onRotateUpdate,
  });

  final CanvasElement el;
  final double scale;
  final bool isSelected;
  final StudioVariableContext variableContext;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMoveStart;
  final ValueChanged<Offset> onMoveUpdate;
  final void Function(Offset, ResizeAnchor) onResizeStart;
  final ValueChanged<Offset> onResizeUpdate;
  final void Function(Offset pos, Offset center) onRotateStart;
  final ValueChanged<Offset> onRotateUpdate;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final x = el.x * s, y = el.y * s;
    final w = el.width * s, h = el.type == 'text' ? null : el.height * s;
    final cx = x + (w) / 2, cy = y + ((h ?? 40.0)) / 2;

    Widget content = _buildContent(s);

    // Apply flip
    if (el.flipX || el.flipY) {
      content = Transform.scale(
        scaleX: el.flipX ? -1 : 1,
        scaleY: el.flipY ? -1 : 1,
        child: content,
      );
    }

    // Apply rotation
    Widget rotated = el.rotation != 0
        ? Transform.rotate(angle: el.rotation, child: content)
        : content;

    // Apply opacity
    Widget opaque = Opacity(opacity: el.opacity.clamp(0.0, 1.0), child: rotated);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main element
        Positioned(
          left: x, top: y,
          width: w,
          height: h,
          child: GestureDetector(
            onTap: onTap,
            onPanStart: (d) => onMoveStart(d.globalPosition),
            onPanUpdate: (d) => onMoveUpdate(d.globalPosition),
            child: opaque,
          ),
        ),

        // Selection overlay
        if (isSelected) ...[
          Positioned(
            left: x - 2, top: y - 2,
            width: (w) + 4,
            height: (h ?? 40.0) + 4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: kAccent, width: 1.5),
                ),
              ),
            ),
          ),

          // Rotation handle (above element center)
          Positioned(
            left: cx - _kHandleSize / 2,
            top: y - 36,
            child: GestureDetector(
              onPanStart: (d) => onRotateStart(d.globalPosition, Offset(cx, cy)),
              onPanUpdate: (d) => onRotateUpdate(d.globalPosition),
              child: Container(
                width: _kHandleSize, height: _kHandleSize,
                decoration: const BoxDecoration(
                  color: kAccent, shape: BoxShape.circle),
                child: const Icon(Icons.rotate_right_rounded,
                    color: Colors.white, size: 12),
              ),
            ),
          ),

          // Resize handles (8 points)
          ..._buildResizeHandles(x, y, w, h ?? 40.0),
        ],
      ],
    );
  }

  List<Widget> _buildResizeHandles(double x, double y, double w, double h) {
    final points = <(Offset, ResizeAnchor)>[
      (Offset(x, y), ResizeAnchor.topLeft),
      (Offset(x + w / 2, y), ResizeAnchor.top),
      (Offset(x + w, y), ResizeAnchor.topRight),
      (Offset(x + w, y + h / 2), ResizeAnchor.right),
      (Offset(x + w, y + h), ResizeAnchor.bottomRight),
      (Offset(x + w / 2, y + h), ResizeAnchor.bottom),
      (Offset(x, y + h), ResizeAnchor.bottomLeft),
      (Offset(x, y + h / 2), ResizeAnchor.left),
    ];
    return points.map((p) {
      final pos = p.$1;
      final anchor = p.$2;
      return Positioned(
        left: pos.dx - _kHandleSize / 2,
        top: pos.dy - _kHandleSize / 2,
        child: GestureDetector(
          onPanStart: (d) => onResizeStart(d.globalPosition, anchor),
          onPanUpdate: (d) => onResizeUpdate(d.globalPosition),
          child: Container(
            width: _kHandleSize, height: _kHandleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: kAccent, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildContent(double s) {
    switch (el.type) {
      case 'text':
      case 'sticker':
        return _buildText(s);
      case 'image':
        return _buildImage(s);
      case 'figure':
        return _buildFigure(s);
      case 'icon':
        return _buildIcon(s);
      case 'illustration':
        return _buildIllustration(s);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIcon(double s) {
    if (el.iconCodePoint == null) return _buildFigure(s);
    return Icon(
      IconData(
        el.iconCodePoint!,
        fontFamily: el.iconFontFamily,
        fontPackage: el.iconFontPackage,
      ),
      size: math.min(el.width, el.height) * s * 0.72,
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
    );
  }

  Widget _buildIllustration(double s) {
    final color = el.fill != null ? parseHexColor(el.fill!) : Colors.white;
    return IllustrationRenderer(
      assetId: el.assetId ?? 'burst_rays',
      color: color,
      width: el.width * s,
      height: el.height * s,
    );
  }

  Widget _buildText(double s) {
    FontWeight w = FontWeight.w400;
    if (el.fontWeight == 'bold' || el.fontWeight == '700') w = FontWeight.bold;
    if (el.fontWeight == '600') w = FontWeight.w600;
    if (el.fontWeight == '800') w = FontWeight.w800;
    if (el.fontWeight == '900') w = FontWeight.w900;

    TextAlign align = TextAlign.left;
    if (el.align == 'center') align = TextAlign.center;
    if (el.align == 'right') align = TextAlign.right;

    final color = el.fill != null ? parseHexColor(el.fill!) : Colors.black;

    List<Shadow>? shadows;
    if (el.hasShadow) {
      shadows = [
        Shadow(
          color: parseHexColor(el.shadowColor!).withValues(alpha: 0.6),
          offset: Offset(el.shadowDx, el.shadowDy),
          blurRadius: el.shadowBlur,
        ),
      ];
    }

    TextStyle style = TextStyle(
      fontSize: (el.fontSize ?? 24) * s,
      fontWeight: w,
      color: color,
      letterSpacing: el.letterSpacing,
      height: el.lineHeight,
      shadows: shadows,
      fontStyle: el.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
      decoration: el.textDecoration == 'underline'
          ? TextDecoration.underline
          : el.textDecoration == 'line-through'
              ? TextDecoration.lineThrough
              : TextDecoration.none,
    );

    if (el.fontFamily != null && studioFonts.containsKey(el.fontFamily)) {
      try {
        style = GoogleFonts.getFont(studioFonts[el.fontFamily!]!,
            textStyle: style);
      } catch (_) {}
    }

    final displayText = _applyTextTransform(
      variableContext.resolve(el.text ?? el.placeholder ?? ''),
      el.textTransform,
    );

    Widget text = Text(
      displayText,
      style: style,
      textAlign: align,
      softWrap: true,
    );

    if (el.hasStroke) {
      text = Stack(children: [
        Text(
          displayText,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (el.strokeWidth ?? 1) * s
              ..color = parseHexColor(el.strokeColor!),
          ),
          textAlign: align,
        ),
        text,
      ]);
    }

    return SizedBox(
      width: el.width * s,
      child: text,
    );
  }

  String _applyTextTransform(String text, String? transform) {
    switch (transform) {
      case 'uppercase': return text.toUpperCase();
      case 'lowercase': return text.toLowerCase();
      case 'capitalize':
        return text.split(' ').map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        }).join(' ');
      default: return text;
    }
  }

  Widget _buildImage(double s) {
    final src = el.src ?? '';
    final fit = _boxFitFor(el.imageFit);

    Widget img;
    if (src.startsWith('file://')) {
      img = Image.file(File(src.substring(7)),
          fit: fit, width: el.width * s, height: el.height * s);
    } else if (src.startsWith('http')) {
      img = Image.network(src,
          fit: fit, width: el.width * s, height: el.height * s,
          errorBuilder: (_, __, ___) => _placeholder(s));
    } else {
      img = _placeholder(s);
    }

    // Apply image filters (grayscale, sepia)
    img = _applyImageFilter(img);

    if ((el.cornerRadius ?? 0) > 0) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(el.cornerRadius! * s),
        child: img,
      );
    }
    return img;
  }

  BoxFit _boxFitFor(String? fit) {
    switch (fit) {
      case 'contain': return BoxFit.contain;
      case 'fill': return BoxFit.fill;
      case 'none': return BoxFit.none;
      case 'cover':
      default: return BoxFit.cover;
    }
  }

  Widget _applyImageFilter(Widget img) {
    switch (el.imageFilter) {
      case 'grayscale':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: img,
        );
      case 'sepia':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.393, 0.769, 0.189, 0, 0,
            0.349, 0.686, 0.168, 0, 0,
            0.272, 0.534, 0.131, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: img,
        );
      default:
        return img;
    }
  }

  Widget _placeholder(double s) => Container(
        width: el.width * s, height: el.height * s,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: el.cornerRadius != null
              ? BorderRadius.circular(el.cornerRadius! * s)
              : null,
        ),
        child: const Icon(Icons.image_outlined, color: Colors.white24, size: 32),
      );

  Widget _buildFigure(double s) {
    return Container(
      width: el.width * s, height: el.height * s,
      decoration: BoxDecoration(
        color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
        borderRadius: el.cornerRadius != null
            ? BorderRadius.circular(el.cornerRadius! * s)
            : null,
        border: el.hasStroke
            ? Border.all(
                color: parseHexColor(el.strokeColor!),
                width: (el.strokeWidth ?? 1) * s)
            : null,
        boxShadow: el.hasShadow
            ? [
                BoxShadow(
                  color: parseHexColor(el.shadowColor!).withValues(alpha: 0.4),
                  offset: Offset(el.shadowDx, el.shadowDy),
                  blurRadius: el.shadowBlur,
                ),
              ]
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Snap guide painter
// ---------------------------------------------------------------------------

class _SnapGuidePainter extends CustomPainter {
  const _SnapGuidePainter({required this.tpl, required this.selected, required this.scale});
  final AdTemplate tpl;
  final CanvasElement? selected;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected == null) return;
    final el = selected!;
    final s = scale;
    final paint = Paint()
      ..color = const Color(0xFF00BFFF).withValues(alpha: 0.7)
      ..strokeWidth = 0.8;

    const thresh = 12.0;
    final cw = tpl.canvasWidth;
    final ch = tpl.canvasHeight;

    // Center guides
    if ((el.x + el.width / 2 - cw / 2).abs() < thresh) {
      canvas.drawLine(Offset(cw * s / 2, 0), Offset(cw * s / 2, ch * s), paint);
    }
    if ((el.y + el.height / 2 - ch / 2).abs() < thresh) {
      canvas.drawLine(Offset(0, ch * s / 2), Offset(cw * s, ch * s / 2), paint);
    }
    // Edge guides
    if (el.x.abs() < thresh) {
      canvas.drawLine(Offset(0, 0), Offset(0, ch * s), paint);
    }
    if ((el.x + el.width - cw).abs() < thresh) {
      canvas.drawLine(Offset(cw * s, 0), Offset(cw * s, ch * s), paint);
    }
    if (el.y.abs() < thresh) {
      canvas.drawLine(Offset(0, 0), Offset(cw * s, 0), paint);
    }
    if ((el.y + el.height - ch).abs() < thresh) {
      canvas.drawLine(Offset(0, ch * s), Offset(cw * s, ch * s), paint);
    }
  }

  @override
  bool shouldRepaint(_SnapGuidePainter old) =>
      old.selected?.id != selected?.id || old.selected?.x != selected?.x;
}

// Grid painter
class _GridPainter extends CustomPainter {
  const _GridPainter(this.scale);
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0.5;
    const step = 108.0;
    for (double x = 0; x <= size.width; x += step * scale / 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step * scale / 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
