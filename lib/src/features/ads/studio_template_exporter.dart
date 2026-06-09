import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ad_templates.dart';
import 'canvas_renderer.dart';
import 'studio_watermark.dart';

/// Renders [template] off-screen and writes a PNG suitable for sharing.
Future<File?> exportStudioTemplatePng(
  BuildContext context, {
  required AdTemplate template,
  bool applyWatermark = false,
  double pixelRatio = 1.5,
}) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -12000,
      top: -12000,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: template.canvasWidth,
          height: template.canvasHeight,
          child: RepaintBoundary(
            key: key,
            child: CanvasPreview(template: template),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    Uint8List bytes = data.buffer.asUint8List();
    if (applyWatermark) {
      bytes = await applySokoWatermark(bytes);
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'soko-studio-${template.id}.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } finally {
    entry.remove();
  }
}