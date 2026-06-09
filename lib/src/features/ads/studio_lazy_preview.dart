import 'package:flutter/material.dart';

import 'ad_templates.dart';
import 'canvas_renderer.dart';
import 'studio_variable_context.dart';

/// Lightweight template thumb — gradient placeholder first, live preview deferred.
class StudioLazyPreview extends StatefulWidget {
  const StudioLazyPreview({
    super.key,
    required this.template,
    this.variableContext,
    this.deferMs = 120,
    this.borderRadius = 10,
  });

  final AdTemplate template;
  final StudioVariableContext? variableContext;
  final int deferMs;
  final double borderRadius;

  @override
  State<StudioLazyPreview> createState() => _StudioLazyPreviewState();
}

class _StudioLazyPreviewState extends State<StudioLazyPreview> {
  bool _showLive = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.deferMs), () {
      if (mounted) setState(() => _showLive = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.template.previewColors ?? const <Color>[];
    final c1 = colors.isNotEmpty ? colors.first : const Color(0xFF0F1D40);
    final c2 = colors.length > 1 ? colors[1] : c1.withValues(alpha: 0.6);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: AspectRatio(
          aspectRatio: widget.template.aspectRatio,
          child: _showLive
              ? CanvasPreview(
                  template: widget.template,
                  variableContext: widget.variableContext,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c1, c2],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_mosaic_outlined,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 22,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Color-only thumb for large browse grids — zero canvas cost.
class StudioColorThumb extends StatelessWidget {
  const StudioColorThumb({
    super.key,
    required this.template,
    this.borderRadius = 10,
  });

  final AdTemplate template;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = template.previewColors ?? const <Color>[];
    final c1 = colors.isNotEmpty ? colors.first : const Color(0xFF0F1D40);
    final c2 = colors.length > 1 ? colors[1] : c1.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: template.aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                template.category.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}