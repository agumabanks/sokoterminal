import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Video Ad Generator — CapCut-style slideshow video creator
///
/// Generates short video ads from product images with:
/// - Fade transitions
/// - Text overlays (product name, price)
/// - Background music
/// - Vertical format (9:16) for WhatsApp Status/Reels
class VideoAdGenerator {
  static const int _width = 1080;
  static const int _height = 1920;
  static const int _fps = 30;
  static const double _perImageSeconds = 5.0;
  static const double _fadeDuration = 0.5;

  /// Extract bundled font for FFmpeg drawtext
  static Future<String> extractFont() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/Montserrat-Bold.ttf');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/fonts/Montserrat-Bold.ttf');
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return file.path;
  }

  /// Escape text for FFmpeg drawtext filter
  static String escapeDrawtext(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", '\u2019')
        .replaceAll('%', '\\%')
        .replaceAll(',', '\\,');
  }

  /// Build FFmpeg command for slideshow video
  static String buildCommand({
    required List<String> imagePaths,
    required String musicPath,
    required String fontPath,
    required String productName,
    required String price,
    required String outputPath,
  }) {
    final name = escapeDrawtext(productName);
    final priceTxt = escapeDrawtext(price);

    final inputs = imagePaths
        .map((p) => "-loop 1 -t $_perImageSeconds -i '$p'")
        .join(' ');

    // Normalize each image stream
    final scaleFilters = List.generate(imagePaths.length, (i) =>
        "[$i:v]scale=$_width:$_height:force_original_aspect_ratio=decrease,"
        "pad=$_width:$_height:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=$_fps[v$i]"
    ).join(';');

    // Build xfade chain
    final buffer = StringBuffer();
    buffer.write(scaleFilters);

    if (imagePaths.length >= 2) {
      final offset1 = _perImageSeconds - _fadeDuration;
      buffer.write(";");
      buffer.write("[v0][v1]xfade=transition=fade:duration=$_fadeDuration:offset=$offset1[x1]");

      if (imagePaths.length >= 3) {
        final offset2 = offset1 + _perImageSeconds - _fadeDuration;
        buffer.write(";");
        buffer.write("[x1][v2]xfade=transition=fade:duration=$_fadeDuration:offset=$offset2[x2]");
        buffer.write(";");
        buffer.write("[x2]drawtext=fontfile='$fontPath':text='$name':fontsize=72:");
        buffer.write("fontcolor=white:borderw=4:bordercolor=black:");
        buffer.write("x=(w-text_w)/2:y=h-380[x3]");
        buffer.write(";");
        buffer.write("[x3]drawtext=fontfile='$fontPath':text='$priceTxt':fontsize=96:");
        buffer.write("fontcolor=#FFD700:borderw=4:bordercolor=black:");
        buffer.write("x=(w-text_w)/2:y=h-260[vout]");
      }
    } else {
      // Single image
      buffer.write(";");
      buffer.write("[v0]drawtext=fontfile='$fontPath':text='$name':fontsize=72:");
      buffer.write("fontcolor=white:borderw=4:bordercolor=black:");
      buffer.write("x=(w-text_w)/2:y=h-380[x3]");
      buffer.write(";");
      buffer.write("[x3]drawtext=fontfile='$fontPath':text='$priceTxt':fontsize=96:");
      buffer.write("fontcolor=#FFD700:borderw=4:bordercolor=black:");
      buffer.write("x=(w-text_w)/2:y=h-260[vout]");
    }

    final totalDur = (imagePaths.length * _perImageSeconds) -
        ((imagePaths.length - 1) * _fadeDuration);

    return "-y $inputs -i '$musicPath' "
        "-filter_complex \"${buffer.toString()}\" "
        "-map \"[vout]\" -map ${imagePaths.length}:a "
        "-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p "
        "-c:a aac -b:a 128k -shortest -t ${totalDur.ceil()} "
        "'$outputPath'";
  }

  /// Generate video ad
  static Future<bool> generate({
    required List<String> imagePaths,
    required String musicPath,
    required String fontPath,
    required String productName,
    required String price,
    required String outputPath,
    required void Function(double progress) onProgress,
  }) async {
    final cmd = buildCommand(
      imagePaths: imagePaths,
      musicPath: musicPath,
      fontPath: fontPath,
      productName: productName,
      price: price,
      outputPath: outputPath,
    );

    final totalMs = (imagePaths.length * _perImageSeconds * 1000).toInt();
    final session = await FFmpegKit.executeAsync(
      cmd,
      null,
      null,
      (stats) {
        final progress = (stats.getTime() / totalMs).clamp(0.0, 1.0);
        onProgress(progress);
      },
    );

    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }
}
