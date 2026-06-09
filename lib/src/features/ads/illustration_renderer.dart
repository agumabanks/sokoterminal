import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ad_templates.dart';

/// Renders vector-style illustration elements by [assetId].
class IllustrationRenderer extends StatelessWidget {
  const IllustrationRenderer({
    super.key,
    required this.assetId,
    required this.color,
    required this.width,
    required this.height,
  });

  final String assetId;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _IllustrationPainter(assetId: assetId, color: color),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({required this.assetId, required this.color});
  final String assetId;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (assetId) {
      case 'burst_rays':
        _burst(canvas, size, rays: 14);
      case 'spark_frame':
        _burst(canvas, size, rays: 10, inner: 0.35);
      case 'ribbon_banner':
        _ribbon(canvas, size);
      case 'speech_bubble':
        _bubble(canvas, size);
      case 'price_ring':
        _ring(canvas, size, label: 'SALE');
      case 'sale_stamp':
        _ring(canvas, size, label: 'SALE', rotate: true);
      case 'trust_seal':
        _ring(canvas, size, label: '✓');
      case 'arrow_up':
        _arrow(canvas, size);
      case 'neon_frame':
        _frame(canvas, size, glow: true);
      case 'gold_frame':
        _frame(canvas, size, glow: false);
      case 'cosmic_orb':
        _orb(canvas, size);
      default:
        _burst(canvas, size, rays: 12);
    }
  }

  void _burst(Canvas canvas, Size size, {required int rays, double inner = 0.2}) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide * 0.48;
    final paint = Paint()..color = color.withValues(alpha: 0.92);
    for (var i = 0; i < rays; i++) {
      final a = (i / rays) * math.pi * 2;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(
          c.dx + math.cos(a - 0.08) * outer,
          c.dy + math.sin(a - 0.08) * outer,
        )
        ..lineTo(
          c.dx + math.cos(a + 0.08) * outer,
          c.dy + math.sin(a + 0.08) * outer,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(c, outer * inner, Paint()..color = color);
  }

  void _ribbon(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.15)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(0, size.height * 0.75)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.35)
        ..lineTo(size.width * 0.08, size.height * 0.5)
        ..lineTo(0, size.height * 0.65),
      Paint()..color = color.withValues(alpha: 0.55),
    );
  }

  void _bubble(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.78),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.95));
    final tail = Path()
      ..moveTo(size.width * 0.25, size.height * 0.78)
      ..lineTo(size.width * 0.18, size.height)
      ..lineTo(size.width * 0.42, size.height * 0.78)
      ..close();
    canvas.drawPath(tail, Paint()..color = color.withValues(alpha: 0.95));
  }

  void _ring(Canvas canvas, Size size, {required String label, bool rotate = false}) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.42;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: r * 0.55,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    if (rotate) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.35);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  void _arrow(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, size.height * 0.55),
          width: size.width * 0.22,
          height: size.height * 0.45,
        ),
        const Radius.circular(12),
      ),
      paint,
    );
    final head = Path()
      ..moveTo(cx, size.height * 0.08)
      ..lineTo(cx - size.width * 0.28, size.height * 0.38)
      ..lineTo(cx + size.width * 0.28, size.height * 0.38)
      ..close();
    canvas.drawPath(head, paint);
  }

  void _frame(Canvas canvas, Size size, {required bool glow}) {
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    if (glow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 4 : 6,
    );
  }

  void _orb(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.4;
    final grad = RadialGradient(
      colors: [color, color.withValues(alpha: 0.1)],
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = grad.createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) =>
      old.assetId != assetId || old.color != color;
}