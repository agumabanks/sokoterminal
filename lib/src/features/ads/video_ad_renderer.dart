import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'video_ad_story_template.dart';
import 'video_ad_effects.dart';

/// Main FFmpeg command builder for CapCut-grade video ads.
///
/// Assembles all components (scenes, effects, text, stickers, music)
/// into a final FFmpeg command for rendering.

class VideoAdRenderer {
  static const int _width = 1080;
  static const int _height = 1920;
  static const int _fps = 30;

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

  /// Build complete FFmpeg command from story template
  static Future<String> buildCommand({
    required VideoAdStoryTemplate template,
    required String fontPath,
    String? musicPath,
  }) async {
    final buffer = StringBuffer();
    final inputs = <String>[];

    // Add image inputs
    for (int i = 0; i < template.scenes.length; i++) {
      final scene = template.scenes[i];
      inputs.add("-loop 1 -t ${scene.duration.inSeconds} -i '${scene.imagePath}'");
    }

    // Build filter graph
    final filterBuffer = StringBuffer();

    // 1. Scale and normalize each input
    for (int i = 0; i < template.scenes.length; i++) {
      filterBuffer.write("[$i:v]scale=$_width:$_height:force_original_aspect_ratio=decrease,");
      filterBuffer.write("pad=$_width:$_height:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=$_fps[v$i];");
    }

    // 2. Apply Ken Burns and effects to each scene
    for (int i = 0; i < template.scenes.length; i++) {
      final scene = template.scenes[i];
      if (scene.kenBurns != null) {
        final kb = scene.kenBurns!;
        filterBuffer.write("[v$i]zoompan=z='");
        filterBuffer.write("if(on,${kb.startScale}+${kb.endScale}*${kb.startScale},");
        filterBuffer.write("if(lte(on,${(scene.duration.inSeconds * _fps).round()}),");
        filterBuffer.write("${kb.startScale}+(on-1)*(${kb.endScale}-${kb.startScale})/${(scene.duration.inSeconds * _fps).round()},");
        filterBuffer.write("${kb.endScale}))':d=${(scene.duration.inSeconds * _fps).round()}:");
        filterBuffer.write("x='iw/2-(iw/zoom/2)+${kb.startOffset.dx}*iw':");
        filterBuffer.write("y='ih/2-(ih/zoom/2)+${kb.startOffset.dy}*ih':");
        filterBuffer.write("s=${_width}x$_height:fps=$_fps[kb$i];");
      }
    }

    // 3. Apply color filter if specified
    if (template.filter != VideoFilter.none) {
      final colorFilter = VideoAdEffects.colorFilter(template.filter);
      if (colorFilter.isNotEmpty) {
        for (int i = 0; i < template.scenes.length; i++) {
          filterBuffer.write("[v$i]$colorFilter[filtered$i];");
        }
      }
    }

    // 4. Add text overlays for each scene
    for (int i = 0; i < template.scenes.length; i++) {
      final scene = template.scenes[i];
      var inputLabel = '[v$i]';

      for (final overlay in scene.textOverlays) {
        final textFilter = VideoAdEffects.textAnimationOverlay(
          fontPath: fontPath,
          text: overlay.text,
          fontSize: overlay.fontSize,
          color: '#${overlay.color.toARGB32().toRadixString(16).substring(2)}',
          borderColor: '#${overlay.color.toARGB32().toRadixString(16).substring(2)}',
          borderWidth: overlay.strokeWidth,
          animationType: overlay.animation.type,
          startTime: scene.startTime.inSeconds.toDouble(),
          duration: scene.duration.inSeconds.toDouble(),
          fps: _fps,
        );
        filterBuffer.write("$inputLabel$textFilter[text$i];");
        inputLabel = '[text$i]';
      }

      // Add stickers
      for (final sticker in scene.stickers) {
        final stickerFilter = VideoAdEffects.stickerOverlay(
          inputIndex: i,
          sticker: sticker,
          duration: scene.duration,
          fps: _fps,
        );
        if (stickerFilter.isNotEmpty) {
          filterBuffer.write("$inputLabel$stickerFilter[sticker$i];");
          inputLabel = '[sticker$i]';
        }
      }
    }

    // 5. Build xfade chain for transitions
    if (template.scenes.length >= 2) {
      filterBuffer.write("[v0][v1]xfade=transition=fade:duration=0.5:offset=${template.scenes[0].duration.inSeconds - 0.5}[x1];");
      for (int i = 1; i < template.scenes.length - 1; i++) {
        final offset = template.scenes.take(i + 1).fold<double>(0, (sum, s) => sum + s.duration.inSeconds) - (i + 1) * 0.5;
        filterBuffer.write("[x$i][v${i + 1}]xfade=transition=fade:duration=0.5:offset=$offset[x${i + 1}];");
      }
    }

    // 6. Apply vignette and film grain if needed
    if (template.filter == VideoFilter.cinematic) {
      filterBuffer.write("[x${template.scenes.length - 1}]${VideoAdEffects.vignette()}[vout];");
    }

    // Build final command
    buffer.write("-y ${inputs.join(' ')} ");

    // Add music input if provided
    if (musicPath != null && musicPath.isNotEmpty) {
      buffer.write("-i '$musicPath' ");
    }

    buffer.write("-filter_complex \"${filterBuffer.toString()}\" ");
    buffer.write("-map \"[vout]\" ");

    // Map audio if music is provided
    if (musicPath != null && musicPath.isNotEmpty) {
      buffer.write("-map ${template.scenes.length}:a ");
    }

    buffer.write("-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p ");
    if (musicPath != null && musicPath.isNotEmpty) {
      buffer.write("-c:a aac -b:a 128k ");
    }
    buffer.write("-shortest -t ${template.duration.inSeconds} ");

    return buffer.toString();
  }

  /// Generate video ad from story template
  static Future<bool> generate({
    required VideoAdStoryTemplate template,
    required String fontPath,
    String? musicPath,
    required void Function(double progress, String stage) onProgress,
  }) async {
    final cmd = await buildCommand(
      template: template,
      fontPath: fontPath,
      musicPath: musicPath,
    );


    final totalMs = template.duration.inMilliseconds;
    final session = await FFmpegKit.executeAsync(
      cmd,
      null,
      null,
      (stats) {
        final progress = (stats.getTime() / totalMs).clamp(0.0, 1.0);
        final stage = _getStage(progress);
        onProgress(progress, stage);
      },
    );

    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }

  static String _getStage(double progress) {
    if (progress < 0.2) return 'Composing frames...';
    if (progress < 0.4) return 'Adding effects...';
    if (progress < 0.6) return 'Adding text overlays...';
    if (progress < 0.8) return 'Adding music...';
    return 'Almost done...';
  }
}
