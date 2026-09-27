import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Video Ad Generator — CapCut-style slideshow video creator
///
/// Generates short video ads from product images with:
/// - Fade transitions
/// - Animated text overlays (product name, price, stickers)
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

  /// Build FFmpeg command for slideshow video with animated text
  static String buildCommand({
    required List<String> imagePaths,
    required String musicPath,
    required String fontPath,
    required String productName,
    required String price,
    required String outputPath,
    String? stickerText,
    String animation = 'fade',
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
        // Animated text overlays
        final nameOverlay = _buildAnimatedDrawtext(
          text: name,
          fontPath: fontPath,
          fontSize: 72,
          color: 'white',
          borderColor: 'black',
          borderWidth: 4,
          position: 'bottom',
          animation: animation,
          startTime: 0.5,
          duration: 4,
        );
        buffer.write("[x2]$nameOverlay[x3]");
        buffer.write(";");
        final priceOverlay = _buildAnimatedDrawtext(
          text: priceTxt,
          fontPath: fontPath,
          fontSize: 96,
          color: '#FFD700',
          borderColor: 'black',
          borderWidth: 4,
          position: 'bottom',
          animation: 'pop',
          startTime: 1.0,
          duration: 3.5,
        );
        buffer.write("[x3]$priceOverlay[vout]");
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

  /// Build animated drawtext filter
  static String _buildAnimatedDrawtext({
    required String text,
    required String fontPath,
    required double fontSize,
    required String color,
    required String borderColor,
    required double borderWidth,
    required String position,
    String animation = 'fade',
    double startTime = 0,
    double duration = 3,
  }) {
    final x = '(w-text_w)/2';
    final y = position == 'top'
        ? 'h*0.08'
        : position == 'center'
            ? '(h-text_h)/2'
            : 'h*0.75';

    String enableExpr = "between(t,$startTime,${startTime + duration})";

    switch (animation) {
      case 'fade':
        return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:alpha='if(lt(t,$startTime),0,if(lt(t,${startTime + 0.5}),(t-$startTime)/0.5,if(lt(t,${startTime + duration - 0.5}),1,(${startTime + duration}-t)/0.5)))':enable='$enableExpr'";
      case 'slideup':
        return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y-$y*if(lt(t,$startTime),1,if(lt(t,${startTime + 0.4}),(1-(t-$startTime)/0.4),0)):enable='$enableExpr'";
      case 'slideleft':
        return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x-(w+text_w)*if(lt(t,$startTime),1,if(lt(t,${startTime + 0.4}),(1-(t-$startTime)/0.4),0)):y=$y:enable='$enableExpr'";
      case 'pop':
        final scaleExpr = "if(lt(t,$startTime),0,if(lt(t,${startTime + 0.3}),1.5-0.5*(${startTime + 0.3}-t)/0.3,1))";
        return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize*$scaleExpr:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:enable='$enableExpr'";
      case 'bounce':
        return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y+100*abs(sin(3.14159*(t-$startTime)))*if(lt(t,$startTime),0,if(gt(t,${startTime + 2}),0,1)):enable='$enableExpr'";
      default:
        return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:alpha='if(lt(t,$startTime),0,if(lt(t,${startTime + 0.3}),(t-$startTime)/0.3,1))':enable='$enableExpr'";
    }
  }

  /// Generate video ad
  static Future<bool> generate({
    required List<String> imagePaths,
    required String musicPath,
    required String fontPath,
    required String productName,
    required String price,
    required String outputPath,
    String? stickerText,
    String animation = 'fade',
    required void Function(double progress) onProgress,
  }) async {
    final cmd = buildCommand(
      imagePaths: imagePaths,
      musicPath: musicPath,
      fontPath: fontPath,
      productName: productName,
      price: price,
      outputPath: outputPath,
      stickerText: stickerText,
      animation: animation,
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
