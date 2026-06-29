import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'canvas_renderer.dart';
import 'studio_watermark.dart';
import 'studio_watermark_settings.dart';

/// Renders [template] off-screen and writes a PNG suitable for sharing.
Future<File?> exportStudioTemplatePng(
  BuildContext context, {
  required AdTemplate template,
  bool applyWatermark = false,
  double pixelRatio = 1.5,
}) async {
  return _renderTemplateToPng(
    context,
    template: template,
    fileName: 'soko-studio-${template.id}.png',
    applyWatermark: applyWatermark,
    pixelRatio: pixelRatio,
  );
}

/// Exports [template] scaled to each of [sizes] and returns the generated PNG
/// files. The original design is not modified.
Future<List<File>> exportStudioTemplatePngForSizes(
  BuildContext context, {
  required AdTemplate template,
  required List<AdSize> sizes,
  bool applyWatermark = false,
  double pixelRatio = 1.5,
}) async {
  final files = <File>[];
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  for (var i = 0; i < sizes.length; i++) {
    final size = sizes[i];
    final sizedTemplate = scaleTemplateToSize(template, size);
    final safeLabel = size.label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
    final file = await _renderTemplateToPng(
      context,
      template: sizedTemplate,
      fileName: 'soko-studio-${template.id}-$safeLabel-${timestamp}_$i.png',
      applyWatermark: applyWatermark,
      pixelRatio: pixelRatio,
    );
    if (file != null) files.add(file);
  }
  return files;
}

/// Shared off-screen rendering pipeline used by single and multi-size exports.
Future<File?> _renderTemplateToPng(
  BuildContext context, {
  required AdTemplate template,
  required String fileName,
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
  final container = ProviderScope.containerOf(context);
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
      final settings = container.read(watermarkSettingsProvider);
      final brandKit = container.read(brandKitProvider);
      bytes = await applySokoWatermark(
        bytes,
        settings: settings,
        brandKit: brandKit,
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } finally {
    entry.remove();
  }
}
