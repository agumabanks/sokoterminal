import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Composite the Soko24 logo watermark onto exported ad PNGs for free/trial sellers.
Future<Uint8List> applySokoWatermark(
  Uint8List pngBytes, {
  double opacity = 0.42,
  double scale = 0.14,
}) async {
  final baseCodec = await ui.instantiateImageCodec(pngBytes);
  final baseFrame = await baseCodec.getNextFrame();
  final baseImage = baseFrame.image;

  final logoBytes =
      (await rootBundle.load('assets/images/app_logo.png')).buffer.asUint8List();
  final logoCodec = await ui.instantiateImageCodec(logoBytes);
  final logoFrame = await logoCodec.getNextFrame();
  final logoImage = logoFrame.image;

  final canvasW = baseImage.width.toDouble();
  final canvasH = baseImage.height.toDouble();
  final logoW = canvasW * scale;
  final logoH = logoImage.height * (logoW / logoImage.width);
  final margin = canvasW * 0.04;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint();

  canvas.drawImage(baseImage, ui.Offset.zero, paint);

  final dst = ui.Rect.fromLTWH(
    canvasW - logoW - margin,
    canvasH - logoH - margin,
    logoW,
    logoH,
  );

  paint.color = ui.Color.fromRGBO(255, 255, 255, opacity);
  paint.blendMode = ui.BlendMode.modulate;

  canvas.saveLayer(dst, ui.Paint());
  canvas.drawImageRect(
    logoImage,
    ui.Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
    dst,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  canvas.drawRect(
    dst,
    ui.Paint()
      ..color = ui.Color.fromRGBO(14, 190, 126, opacity * 0.35)
      ..blendMode = ui.BlendMode.srcATop,
  );
  canvas.restore();

  final picture = recorder.endRecording();
  final watermarked = await picture.toImage(baseImage.width, baseImage.height);
  final byteData =
      await watermarked.toByteData(format: ui.ImageByteFormat.png);

  baseImage.dispose();
  logoImage.dispose();
  watermarked.dispose();

  return byteData!.buffer.asUint8List();
}

Future<File> writeWatermarkedPng(File source, Uint8List bytes) async {
  await source.writeAsBytes(bytes, flush: true);
  return source;
}