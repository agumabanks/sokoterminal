import 'package:flutter/material.dart';

import 'ad_templates.dart';
import '../../core/theme/design_tokens.dart';

/// Extra mesh / pattern backgrounds beyond flat gradients.
const meshBackgroundPresets = <({
  String id,
  String label,
  List<Color> colors,
  Alignment begin,
  Alignment end,
})>[
  (
    id: 'aurora',
    label: 'Aurora',
    colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  (
    id: 'soko',
    label: 'Soko Green',
    colors: [DesignTokens.brandPrimary, DesignTokens.brandAccent, DesignTokens.success],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  (
    id: 'candy',
    label: 'Candy',
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  (
    id: 'cosmic',
    label: 'Cosmic',
    colors: [Color(0xFF141e30), Color(0xFF243b55)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  (
    id: 'lime',
    label: 'Lime Pop',
    colors: [Color(0xFF134e5e), Color(0xFF71b280)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  ),
  (
    id: 'velvet',
    label: 'Velvet',
    colors: [Color(0xFF200122), Color(0xFF6f0000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  (
    id: 'sky',
    label: 'Sky',
    colors: [Color(0xFF2980b9), Color(0xFF6dd5fa), DesignTokens.canvas],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  (
    id: 'sunrise',
    label: 'Sunrise',
    colors: [Color(0xFFff512f), Color(0xFFf09819)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  ),
];

const patternBackgroundIds = <String>['dots', 'grid', 'diagonal', 'noise'];

Widget buildCanvasBackground({
  required String background,
  BoxFit fit = BoxFit.cover,
}) {
  if (background.startsWith('pattern:')) {
    final id = background.substring(8);
    final base = parseHexColor('#0f172a');
    return CustomPaint(
      painter: _PatternPainter(id: id, base: base),
      child: const SizedBox.expand(),
    );
  }

  if (background.startsWith('gradient:')) {
    final id = background.substring(9);
    final mesh = meshBackgroundPresets.where((m) => m.id == id).firstOrNull;
    if (mesh != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: mesh.begin,
            end: mesh.end,
            colors: mesh.colors,
          ),
        ),
      );
    }
    final preset = gradientPresets.firstWhere(
      (g) => g.id == id,
      orElse: () => gradientPresets.first,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: preset.colors,
        ),
      ),
    );
  }

  return Container(color: parseHexColor(background));
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.id, required this.base});
  final String id;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    switch (id) {
      case 'grid':
        const step = 28.0;
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
        }
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
        }
      case 'diagonal':
        final line = Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..strokeWidth = 2;
        const gap = 24.0;
        for (var i = -size.height; i < size.width + size.height; i += gap) {
          canvas.drawLine(
            Offset(i, 0),
            Offset(i + size.height, size.height),
            line,
          );
        }
      case 'noise':
        final rnd = Paint()..color = Colors.white.withValues(alpha: 0.04);
        for (var i = 0; i < 120; i++) {
          final x = (i * 37 % size.width);
          final y = (i * 53 % size.height);
          canvas.drawCircle(Offset(x, y), 1.2, rnd);
        }
      case 'dots':
      default:
        const step = 22.0;
        for (var x = step / 2; x < size.width; x += step) {
          for (var y = step / 2; y < size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 2, paint);
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) =>
      old.id != id || old.base != base;
}