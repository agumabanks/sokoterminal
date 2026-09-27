/// FFmpeg filter generation for CapCut-grade video effects.
///
/// Each effect generates the appropriate FFmpeg filter_complex string
/// for Ken Burns, transitions, color grading, and overlay effects.
library;
import 'package:flutter/material.dart' show Offset;
import 'video_ad_story_template.dart';

class VideoAdEffects {
  /// Generate Ken Burns zoom effect (subtle scale + pan)
  static String kenBurns({
    required double startScale,
    required double endScale,
    required Offset startOffset,
    required Offset endOffset,
    required double duration,
    required int fps,
  }) {
    final width = 1080;
    final height = 1920;
    final frames = (duration * fps).round();
    return "[0:v]zoompan=z='"
        "'+if(on,$startScale+$endScale*$startScale,"
        "if(lte(on,$frames),$startScale+(on-1)*($endScale-$startScale)/$frames,$endScale)'):d=$frames:"
        "x='iw/2-(iw/zoom/2)+$startOffset.dx*iw'"
        "y='ih/2-(ih/zoom/2)+$startOffset.dy*ih':s=${width}x$height:fps=$fps";
  }

  /// Generate fade transition
  static String fadeTransition({
    required int inputIndex1,
    required int inputIndex2,
    required double startTime,
    required double duration,
  }) {
    return "[${inputIndex1}v][${inputIndex2}v]xfade=transition=fade:duration=$duration:offset=$startTime";
  }

  /// Generate slide transition (left, right, up, down)
  static String slideTransition({
    required int inputIndex1,
    required int inputIndex2,
    required double startTime,
    required double duration,
    required SlideDirection direction,
  }) {
    final transitionName = switch (direction) {
      SlideDirection.left => 'slideleft',
      SlideDirection.right => 'slideright',
      SlideDirection.up => 'slideup',
      SlideDirection.down => 'slidedown',
    };
    return "[${inputIndex1}v][${inputIndex2}v]xfade=transition=$transitionName:duration=$duration:offset=$startTime";
  }

  /// Generate zoom transition
  static String zoomTransition({
    required int inputIndex1,
    required int inputIndex2,
    required double startTime,
    required double duration,
    required bool zoomIn,
  }) {
    final transitionName = zoomIn ? 'zoomin' : 'zoomout';
    return "[${inputIndex1}v][${inputIndex2}v]xfade=transition=$transitionName:duration=$duration:offset=$startTime";
  }

  /// Generate glitch transition
  static String glitchTransition({
    required int inputIndex1,
    required int inputIndex2,
    required double startTime,
    required double duration,
  }) {
    return "[${inputIndex1}v][${inputIndex2}v]xfade=transition=glitch:duration=$duration:offset=$startTime";
  }

  /// Generate crossfade transition
  static String crossfadeTransition({
    required int inputIndex1,
    required int inputIndex2,
    required double startTime,
    required double duration,
  }) {
    return "[${inputIndex1}v][${inputIndex2}v]xfade=transition=dissolve:duration=$duration:offset=$startTime";
  }

  /// Generate fade through black transition
  static String fadeThroughBlack({
    required int inputIndex1,
    required int inputIndex2,
    required double startTime,
    required double duration,
  }) {
    return "[${inputIndex1}v][${inputIndex2}v]xfade=transition=fadeblack:duration=$duration:offset=$startTime";
  }

  /// Generate color filter (vintage, neon, cinematic, etc.)
  static String colorFilter(VideoFilter filter) {
    switch (filter) {
      case VideoFilter.none:
        return '';
      case VideoFilter.vintage:
        return 'curves=vintage,eq=brightness=-0.05:contrast=1.1:saturation=0.8';
      case VideoFilter.neon:
        return 'eq=saturation=1.5:brightness=0.1,curves=blue="0/0 0.5/0.6 1/0.95",curves=red="0/0 0.5/0.45 1/0.9",hue=H=5*PI/180';
      case VideoFilter.cinematic:
        return 'curves="0/0.05 0.5/0.5 1/0.95",eq=contrast=1.1:brightness=-0.05:saturation=0.9';
      case VideoFilter.blackAndWhite:
        return 'hue=s=0';
      case VideoFilter.vibrant:
        return 'eq=saturation=1.5:contrast=1.2:brightness=0.05';
      case VideoFilter.warm:
        return 'curves=red="0/0 0.5/0.55 1/1",curves=blue="0/0 0.5/0.45 1/0.9",hue=H=3*PI/180';
      case VideoFilter.cool:
        return 'curves=blue="0/0 0.5/0.55 1/1",curves=red="0/0 0.5/0.45 1/0.9",hue=H=-3*PI/180';
    }
  }

  /// Generate vignette effect
  static String vignette({double intensity = 0.5}) {
        return 'vignette=PI/3:$intensity';
  }

  /// Generate film grain effect
  static String filmGrain({int intensity = 10}) {
        return 'noise=alls=$intensity:allf=t+u';
  }

  /// Generate text animation overlay
  static String textAnimationOverlay({
    required String fontPath,
    required String text,
    required double fontSize,
    required String color,
    required String borderColor,
    required double borderWidth,
    required TextAnimationType animationType,
    required double startTime,
    required double duration,
    required int fps,
    String position = 'bottom',
  }) {
    final x = '(w-text_w)/2';
    final y = switch (position) {
      'top' => 'h*0.08',
      'center' => '(h-text_h)/2',
      _ => 'h*0.75',
    };

    final enableExpr = "between(t,$startTime,${startTime + duration})";
    final startFrame = (startTime * fps).round();
    final totalFrames = (duration * fps).round();

    final (alphaExpr, yExpr) = switch (animationType) {
      TextAnimationType.fadeUp => (
          "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/2}),(on-$startFrame)/${totalFrames/2},1))",
          y
        ),
      TextAnimationType.popScale => (
          "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/4}),(on-$startFrame)/${totalFrames/4},1))",
          y
        ),
      TextAnimationType.slideInLeft => (
          "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/3}),(on-$startFrame)/${totalFrames/3},1))",
          y
        ),
      TextAnimationType.slideInRight => (
          "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/3}),(on-$startFrame)/${totalFrames/3},1))",
          y
        ),
      TextAnimationType.bounce => (
          "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/3}),1,1-abs(sin(on*0.1)*0.05)))",
          y
        ),
      _ => (
          "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/4}),(on-$startFrame)/${totalFrames/4},1))",
          y
        ),
    };

    return "drawtext=fontfile='$fontPath':text='$text':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:alpha='$alphaExpr':enable='$enableExpr'";
  }

  /// Generate animated price display with pop effect
  static String animatedPriceOverlay({
    required String fontPath,
    required String price,
    required double startTime,
    required double duration,
    required int fps,
  }) {
    final x = '(w-text_w)/2';
    final y = 'h*0.75';
    final startFrame = (startTime * fps).round();
    final totalFrames = (duration * fps).round();
    final enableExpr = "between(t,$startTime,${startTime + duration})";

    // Scale from 0 to 1 with bounce
    final scaleExpr = "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/3}),(on-$startFrame)/${totalFrames/3},1+0.1*sin(on*0.2)))";

    return "drawtext=fontfile='$fontPath':text='$price':fontsize=96*($scaleExpr):fontcolor=#FFD700:borderw=4:bordercolor=black:x=$x:y=$y:alpha='$scaleExpr':enable='$enableExpr'";
  }

  /// Generate product name caption with background pill
  static String productNameOverlay({
    required String fontPath,
    required String name,
    required double startTime,
    required double duration,
    required int fps,
  }) {
    final x = '(w-text_w)/2';
    final y = 'h*0.75';
    final startFrame = (startTime * fps).round();
    final totalFrames = (duration * fps).round();
    final enableExpr = "between(t,$startTime,${startTime + duration})";

    // Slide up from bottom
    final yExpr = "$y+(h*0.1)*if(lte(on,$startFrame),1,if(lte(on,${startFrame + totalFrames/3}),1-(on-$startFrame)/${totalFrames/3},0))";
    final alphaExpr = "if(lte(on,$startFrame),0,if(lte(on,${startFrame + totalFrames/4}),(on-$startFrame)/${totalFrames/4},1))";

    return "drawtext=fontfile='$fontPath':text='$name':fontsize=72:fontcolor=white:borderw=2:bordercolor=black:shadowcolor=black:shadowx=2:shadowy=2:x=$x:y=$yExpr:alpha='$alphaExpr':enable='$enableExpr'";
  }

  /// Generate CTA button overlay with pulse animation
  static String ctaButtonOverlay({
    required String fontPath,
    required String text,
    required double startTime,
    required double duration,
    required int fps,
  }) {
    final x = '(w-text_w)/2';
    final y = 'h*0.88';
    final startFrame = (startTime * fps).round();
    final enableExpr = "between(t,$startTime,${startTime + duration})";

    // Pulsing alpha
    final alphaExpr = "if(lte(on,$startFrame),0,0.8+0.2*sin(on*0.5))";

    return "drawtext=fontfile='$fontPath':text='$text':fontsize=64:fontcolor=white:borderw=4:bordercolor=#0EBE7E:x=$x:y=$y:alpha='$alphaExpr':enable='$enableExpr'";
  }

  /// Generate discount badge overlay
  static String discountBadgeOverlay({
    required String fontPath,
    required String discountText,
    required double startTime,
    required double duration,
    required int fps,
  }) {
    final x = 'w*0.15';
    final y = 'h*0.15';
    final startFrame = (startTime * fps).round();
    final enableExpr = "between(t,$startTime,${startTime + duration})";

    final alphaExpr = "if(lte(on,$startFrame),0,if(lte(on,${startFrame + 15}),(on-$startFrame)/15,1))";

    return "drawtext=fontfile='$fontPath':text='$discountText':fontsize=60:fontcolor=red:borderw=3:bordercolor=white:x=$x:y=$y:alpha='$alphaExpr':enable='$enableExpr'";
  }

  /// Generate sticker overlay
  static String stickerOverlay({
    required int inputIndex,
    required VideoAdSticker sticker,
    required Duration duration,
    int fps = 30,
  }) {
    final x = sticker.position.dx;
    final y = sticker.position.dy;
    const startFrame = 0;
    final endFrame = (duration.inMilliseconds * fps / 1000).round();
    final enableExpr = "between(n,$startFrame,$endFrame)";

    final alphaExpr = "if(lte(n,$startFrame),0,if(lte(n,${startFrame + 8}),(n-$startFrame)/8,1))";

    switch (sticker.type) {
      case StickerType.emoji:
        return "drawtext=text='${sticker.content}':fontsize=${sticker.size.height}:fontcolor=yellow:x=$x:y=$y:alpha='$alphaExpr*${sticker.opacity}':enable='$enableExpr'";
      case StickerType.badge:
        return "drawbox=x=$x:y=$y:w=${sticker.size.width}:h=${sticker.size.height}:color=red@0.8:t=fill,drawtext=text='${sticker.content}':fontsize=30:fontcolor=white:x=${x + 10}:y=${y + 10}:alpha='$alphaExpr*${sticker.opacity}':enable='$enableExpr'";
      case StickerType.ribbon:
        return "drawtext=text='${sticker.content}':fontsize=40:fontcolor=white:box=1:boxcolor=red@0.8:boxborderw=5:x=$x:y=$y:alpha='$alphaExpr*${sticker.opacity}':enable='$enableExpr'";
      default:
        return '';
    }
  }
}

enum SlideDirection { left, right, up, down }
