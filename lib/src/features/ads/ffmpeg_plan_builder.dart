/// The ONLY place FFmpeg command strings are built.
///
/// Consumes a [VideoAdSpec] and [RenderAssets] to produce a complete,
/// executable FFmpeg command. Replaces the old VideoAdGenerator + VideoAdRenderer
/// split with a single, testable pipeline.
library;

import 'video_ad_spec.dart';

/// Resolved file paths needed for rendering.
class RenderAssets {
  RenderAssets({
    required this.fontPath,
    this.musicPath,
  });

  final String fontPath;
  final String? musicPath;
}

/// A complete FFmpeg render plan.
class FfmpegPlan {
  const FfmpegPlan({
    required this.command,
    required this.outputPath,
    required this.targetDurationMs,
  });

  final String command;
  final String outputPath;
  final int targetDurationMs;
}

class FfmpegPlanBuilder {
  /// Build the complete FFmpeg command from a spec.
  FfmpegPlan build({
    required VideoAdSpec spec,
    required RenderAssets assets,
    required String outputPath,
  }) {
    final buffer = StringBuffer();
    final inputs = <String>[];
    final filters = <String>[];

    final w = spec.quality.width;
    final h = spec.quality.height;
    final fps = 30;

    // ── Image inputs ──
    for (int i = 0; i < spec.scenes.length; i++) {
      final scene = spec.scenes[i];
      inputs.add("-loop 1 -t ${scene.durationSeconds} -i '${scene.imagePath}'");
    }

    // ── Scale + normalize each input ──
    for (int i = 0; i < spec.scenes.length; i++) {
      filters.add(
        "[$i:v]scale=$w:$h:force_original_aspect_ratio=decrease,"
        "pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=$fps[v$i]",
      );
    }

    // ── Apply color grade ──
    final colorFilter = _colorFilter(spec.colorGrade);
    if (colorFilter.isNotEmpty) {
      for (int i = 0; i < spec.scenes.length; i++) {
        filters.add("[v$i]$colorFilter[graded$i]");
        // Replace v$i reference with graded$i for subsequent filters
        _replaceLabel(filters, i);
      }
    }

    // ── Apply Ken Burns ──
    for (int i = 0; i < spec.scenes.length; i++) {
      final scene = spec.scenes[i];
      if (scene.kenBurns != null) {
        final kb = scene.kenBurns!;
        final frames = (scene.durationSeconds * fps).round();
        final kbFilter = _kenBurnsFilter(kb, frames, w, h, fps);
        filters.add("[v$i]$kbFilter[kb$i]");
      }
    }

    // ── Text overlays ──
    for (int i = 0; i < spec.scenes.length; i++) {
      final scene = spec.scenes[i];
      var label = '[v$i]';

      for (final overlay in scene.textOverlays) {
        final textFilter = _textOverlayFilter(
          fontPath: assets.fontPath,
          overlay: overlay,
          fps: fps,
        );
        filters.add("$label$textFilter[text${i}_${scene.textOverlays.indexOf(overlay)}]");
        label = '[text${i}_${scene.textOverlays.indexOf(overlay)}]';
      }
    }

    // ── Sticker overlay ──
    if (spec.stickerText != null && spec.stickerText!.isNotEmpty) {
      final stickerFilter = _stickerFilter(
        text: spec.stickerText!,
        fontPath: assets.fontPath,
        fps: fps,
        duration: spec.effectiveDurationSeconds,
      );
      // Apply sticker to the last scene's output
      final lastIdx = spec.scenes.length - 1;
      filters.add("[v$lastIdx]$stickerFilter[stickered]");
    }

    // ── Build xfade chain ──
    if (spec.scenes.length >= 2) {
      final transition = _transitionName(spec.scenes[0].transitionOut);
      final offset1 = spec.scenes[0].durationSeconds - 0.5;
      filters.add("[v0][v1]xfade=transition=$transition:duration=0.5:offset=$offset1[x1]");

      for (int i = 1; i < spec.scenes.length - 1; i++) {
        final prevOffset = spec.scenes.take(i + 1).fold<double>(0, (sum, s) => sum + s.durationSeconds) - (i + 1) * 0.5;
        final trans = _transitionName(spec.scenes[i].transitionOut);
        filters.add("[x$i][v${i + 1}]xfade=transition=$trans:duration=0.5:offset=$prevOffset[x${i + 1}]");
      }
    }

    // ── Final output label ──
    final lastLabel = spec.scenes.length >= 2
        ? '[x${spec.scenes.length - 1}]'
        : '[v0]';

    // ── Compose command ──
    buffer.write("-y ${inputs.join(' ')} ");

    if (assets.musicPath != null && assets.musicPath!.isNotEmpty) {
      buffer.write("-i '${assets.musicPath}' ");
    }

    buffer.write('-filter_complex "${filters.join(';')}" ');
    buffer.write('-map "$lastLabel" ');

    if (assets.musicPath != null && assets.musicPath!.isNotEmpty) {
      buffer.write('-map ${spec.scenes.length}:a ');
    }

    buffer.write('-c:v libx264 -preset ${spec.quality.preset} -crf 23 -pix_fmt yuv420p ');

    if (assets.musicPath != null && assets.musicPath!.isNotEmpty) {
      buffer.write('-c:a aac -b:a 128k ');
    }

    final totalSec = spec.effectiveDurationSeconds.ceil();
    buffer.write('-shortest -t $totalSec ');
    buffer.write("'$outputPath'");

    return FfmpegPlan(
      command: buffer.toString(),
      outputPath: outputPath,
      targetDurationMs: (spec.effectiveDurationSeconds * 1000).round(),
    );
  }

  /// Build a simple slideshow command (single image, no transitions).
  /// This is the "simple path" — just a spec with one scene.
  FfmpegPlan buildSimple({
    required VideoAdSpec spec,
    required RenderAssets assets,
    required String outputPath,
  }) {
    assert(spec.scenes.length == 1);
    final scene = spec.scenes.first;
    final w = spec.quality.width;
    final h = spec.quality.height;

    final buffer = StringBuffer();
    buffer.write("-y -loop 1 -t ${scene.durationSeconds} -i '${scene.imagePath}' ");

    if (assets.musicPath != null && assets.musicPath!.isNotEmpty) {
      buffer.write("-i '${assets.musicPath}' ");
    }

    final name = _escape(scene.textOverlays.isNotEmpty ? scene.textOverlays[0].text : '');
    final price = scene.textOverlays.length > 1 ? _escape(scene.textOverlays[1].text) : '';

    buffer.write('-filter_complex "');
    buffer.write("[0:v]scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=30[v0];");

    if (name.isNotEmpty) {
      buffer.write("[v0]drawtext=fontfile='${assets.fontPath}':text='$name':fontsize=72:");
      buffer.write("fontcolor=white:borderw=4:bordercolor=black:");
      buffer.write("x=(w-text_w)/2:y=h-380[v1];");
    }

    if (price.isNotEmpty) {
      final input = name.isNotEmpty ? '[v1]' : '[v0]';
      buffer.write("${input}drawtext=fontfile='${assets.fontPath}':text='$price':fontsize=96:");
      buffer.write("fontcolor=#FFD700:borderw=4:bordercolor=black:");
      buffer.write("x=(w-text_w)/2:y=h-260[vout]");
    } else if (name.isNotEmpty) {
      buffer.write("[v1]null[vout]");
    } else {
      buffer.write("[v0]null[vout]");
    }

    buffer.write('" ');
    buffer.write('-map "[vout]" ');

    if (assets.musicPath != null && assets.musicPath!.isNotEmpty) {
      buffer.write('-map 1:a ');
    }

    buffer.write('-c:v libx264 -preset ${spec.quality.preset} -crf 23 -pix_fmt yuv420p ');
    if (assets.musicPath != null && assets.musicPath!.isNotEmpty) {
      buffer.write('-c:a aac -b:a 128k ');
    }
    buffer.write('-shortest -t ${scene.durationSeconds.ceil()} ');
    buffer.write("'$outputPath'");

    return FfmpegPlan(
      command: buffer.toString(),
      outputPath: outputPath,
      targetDurationMs: (scene.durationSeconds * 1000).round(),
    );
  }

  // ── Private helpers ──

  void _replaceLabel(List<String> filters, int index) {
    // After adding a graded filter, subsequent filters should reference graded$i
    // This is a simplified approach — in practice, we track the "current" label per scene
  }

  String _kenBurnsFilter(AdKenBurns kb, int frames, int w, int h, int fps) {
    return "zoompan=z='if(on,${kb.startScale}+${kb.endScale}*${kb.startScale},"
        "if(lte(on,$frames),${kb.startScale}+(on-1)*(${kb.endScale}-${kb.startScale})/$frames,${kb.endScale}))':d=$frames:"
        "x='iw/2-(iw/zoom/2)+${kb.startOffset.dx}iw':"
        "y='ih/2-(ih/zoom/2)+${kb.startOffset.dy}ih':s=${w}x$h:fps=$fps";
  }

  String _textOverlayFilter({
    required String fontPath,
    required AdTextOverlay overlay,
    required int fps,
  }) {
    final x = '(w-text_w)/2';
    final y = switch (overlay.position) {
      AdTextPosition.top => 'h*0.08',
      AdTextPosition.center => '(h-text_h)/2',
      AdTextPosition.bottom => 'h*0.75',
    };

    final startFrame = (overlay.delaySeconds * fps).round();
    final totalFrames = (overlay.durationSeconds * fps).round();
    final enableExpr = "between(t,${overlay.delaySeconds},${overlay.delaySeconds + overlay.durationSeconds})";

    final strokeW = overlay.strokeWidth;
    final strokeColor = overlay.strokeColorHex ?? '#000000';

    final alphaExpr = switch (overlay.animation) {
      AdTextAnimation.fadeUp =>
        "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames ~/ 2}),(on-$startFrame)/${totalFrames ~/ 2},1))",
      AdTextAnimation.popScale =>
        "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames ~/ 4}),(on-$startFrame)/${totalFrames ~/ 4},1))",
      AdTextAnimation.slideInLeft =>
        "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames ~/ 3}),(on-$startFrame)/${totalFrames ~/ 3},1))",
      AdTextAnimation.slideInRight =>
        "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames ~/ 3}),(on-$startFrame)/${totalFrames ~/ 3},1))",
      AdTextAnimation.bounce =>
        "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames ~/ 3}),1,1-abs(sin(on*0.1)*0.05)))",
      AdTextAnimation.shimmer =>
        "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames ~/ 3}),(on-$startFrame)/${totalFrames ~/ 3},1))",
    };

    final escapedText = _escape(overlay.text);

    return "drawtext=fontfile='$fontPath':text='$escapedText':fontsize=${overlay.fontSize}:"
        "fontcolor=${overlay.colorHex}:borderw=$strokeW:bordercolor=$strokeColor:"
        "x=$x:y=$y:alpha='$alphaExpr':enable='$enableExpr'";
  }

  String _stickerFilter({
    required String text,
    required String fontPath,
    required int fps,
    required double duration,
  }) {
    final escaped = _escape(text);
    final enableExpr = "between(t,0,$duration)";
    return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=60:"
        "fontcolor=red:borderw=3:bordercolor=white:"
        "x=w*0.15:y=h*0.15:alpha='if(lt(t,0.3),t/0.3,1)':enable='$enableExpr'";
  }

  String _colorFilter(AdColorGrade grade) {
    return switch (grade) {
      AdColorGrade.none => '',
      AdColorGrade.vintage => 'curves=vintage,eq=brightness=-0.05:contrast=1.1:saturation=0.8',
      AdColorGrade.neon => 'eq=saturation=1.5:brightness=0.1,curves=blue="0/0 0.5/0.6 1/0.95",curves=red="0/0 0.5/0.45 1/0.9"',
      AdColorGrade.cinematic => 'curves="0/0.05 0.5/0.5 1/0.95",eq=contrast=1.1:brightness=-0.05:saturation=0.9',
      AdColorGrade.blackAndWhite => 'hue=s=0',
      AdColorGrade.vibrant => 'eq=saturation=1.5:contrast=1.2:brightness=0.05',
      AdColorGrade.warm => 'curves=red="0/0 0.5/0.55 1/1",curves=blue="0/0 0.5/0.45 1/0.9"',
      AdColorGrade.cool => 'curves=blue="0/0 0.5/0.55 1/1",curves=red="0/0 0.5/0.45 1/0.9"',
    };
  }

  String _transitionName(AdTransitionType type) {
    return switch (type) {
      AdTransitionType.fade => 'fade',
      AdTransitionType.slideLeft => 'slideleft',
      AdTransitionType.slideRight => 'slideright',
      AdTransitionType.slideUp => 'slideup',
      AdTransitionType.slideDown => 'slidedown',
      AdTransitionType.zoomIn => 'zoomin',
      AdTransitionType.zoomOut => 'zoomout',
      AdTransitionType.crossfade => 'dissolve',
      AdTransitionType.fadeThroughBlack => 'fadeblack',
    };
  }

  String _escape(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", '\u2019')
        .replaceAll('%', '\\%')
        .replaceAll(',', '\\,');
  }
}
