import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand_kit_screen.dart';
import 'studio_watermark_settings.dart';

/// Composite the Soko24 (or business) logo watermark onto exported ad PNGs.
Future<Uint8List> applySokoWatermark(
  Uint8List pngBytes, {
  required WatermarkSettings settings,
  BrandKit? brandKit,
}) async {
  if (!settings.enabled) return pngBytes;
  if (pngBytes.isEmpty) throw StateError('Cannot watermark empty PNG bytes');

  final baseCodec = await ui.instantiateImageCodec(pngBytes);
  final baseFrame = await baseCodec.getNextFrame();
  final baseImage = baseFrame.image;

  final logoBytes = await _loadWatermarkBytes(
    settings: settings,
    brandKit: brandKit,
  );
  if (logoBytes.isEmpty) throw StateError('Cannot decode empty watermark bytes');

  final logoCodec = await ui.instantiateImageCodec(logoBytes);
  final logoFrame = await logoCodec.getNextFrame();
  final logoImage = logoFrame.image;

  final canvasW = baseImage.width.toDouble();
  final canvasH = baseImage.height.toDouble();
  final logoW = canvasW * settings.scale;
  final logoH = logoImage.height * (logoW / logoImage.width);
  final margin = canvasW * 0.04;

  final dst = switch (settings.position) {
    WatermarkPosition.topLeft => ui.Rect.fromLTWH(margin, margin, logoW, logoH),
    WatermarkPosition.topRight =>
      ui.Rect.fromLTWH(canvasW - logoW - margin, margin, logoW, logoH),
    WatermarkPosition.bottomLeft =>
      ui.Rect.fromLTWH(margin, canvasH - logoH - margin, logoW, logoH),
    WatermarkPosition.bottomRight => ui.Rect.fromLTWH(
        canvasW - logoW - margin,
        canvasH - logoH - margin,
        logoW,
        logoH,
      ),
    WatermarkPosition.center => ui.Rect.fromLTWH(
        (canvasW - logoW) / 2,
        (canvasH - logoH) / 2,
        logoW,
        logoH,
      ),
  };

  final blendMode = watermarkBlendMode(settings.blendMode) ?? ui.BlendMode.modulate;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Draw base image.
  canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());

  // Draw watermark with the chosen blend mode + opacity.
  final watermarkPaint = ui.Paint()
    ..colorFilter = ui.ColorFilter.mode(
      Colors.white.withValues(alpha: settings.opacity),
      blendMode,
    )
    ..filterQuality = ui.FilterQuality.high;

  canvas.drawImageRect(
    logoImage,
    ui.Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
    dst,
    watermarkPaint,
  );

  final picture = recorder.endRecording();
  final watermarked = await picture.toImage(baseImage.width, baseImage.height);
  final byteData = await watermarked.toByteData(format: ui.ImageByteFormat.png);

  baseImage.dispose();
  logoImage.dispose();
  watermarked.dispose();

  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _loadWatermarkBytes({
  required WatermarkSettings settings,
  BrandKit? brandKit,
}) async {
  String source = 'assets/images/app_logo.png';

  if (settings.useBusinessLogo && brandKit != null && brandKit.hasLogo) {
    source = watermarkAssetPath(settings: settings, brandKit: brandKit);
  }

  try {
    if (source.startsWith('assets/')) {
      return (await rootBundle.load(source)).buffer.asUint8List();
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          responseType: ResponseType.bytes,
        ),
      ).get<List<int>>(source);
      final data = response.data;
      if (data == null || data.isEmpty) throw StateError('Empty logo response');
      return Uint8List.fromList(data);
    }

    // Treat as local file path.
    final file = File(source);
    if (!file.existsSync()) throw StateError('Logo file not found: $source');
    return file.readAsBytes();
  } catch (_) {
    // Always fall back to the bundled Soko logo.
    return (await rootBundle.load('assets/images/app_logo.png')).buffer.asUint8List();
  }
}

Future<File> writeWatermarkedPng(File source, Uint8List bytes) async {
  await source.writeAsBytes(bytes, flush: true);
  return source;
}
