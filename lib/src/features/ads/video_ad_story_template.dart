
import 'package:flutter/material.dart';

/// CapCut-grade video ad story template system.
/// 
/// 5-scene story structure:
/// 1. Hook (0-2s): Bold animated text grabber
/// 2. Product Reveal (2-5s): Full product image + animated name + price
/// 3. Features (5-10s): Bullet points with slide-in animations
/// 4. Price Punch (10-12s): Animated price with pop effect + discount badge
/// 5. CTA (12-15s): "Shop Now" / "Order on WhatsApp" pulsing button

enum VideoAdSceneType {
  hook,
  productReveal,
  features,
  pricePunch,
  cta,
}

enum TextAnimationType {
  fadeUp,
  typewriter,
  popScale,
  slideInLeft,
  slideInRight,
  bounce,
  wave,
  shimmer,
}

enum TransitionType {
  fade,
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
  zoomIn,
  zoomOut,
  crossfade,
  glitch,
}

enum VideoFilter {
  none,
  vintage,
  neon,
  cinematic,
  blackAndWhite,
  vibrant,
  warm,
  cool,
}

enum StickerType {
  emoji,
  badge,
  ribbon,
  shape,
  logoWatermark,
}

enum MusicGenre {
  afrobeats,
  bongoFlava,
  gengetone,
  gospel,
  traditional,
  hipHop,
  pop,
  electronic,
}

class VideoAdStoryTemplate {
  const VideoAdStoryTemplate({
    required this.name,
    required this.aspectRatio,
    required this.resolution,
    required this.fps,
    required this.duration,
    required this.scenes,
    this.musicTrack,
    this.filter = VideoFilter.none,
  });

  final String name;
  final VideoAdAspectRatio aspectRatio;
  final VideoAdResolution resolution;
  final int fps;
  final Duration duration;
  final List<VideoAdScene> scenes;
  final VideoAdMusicTrack? musicTrack;
  final VideoFilter filter;

  double get width => aspectRatio.width(resolution);
  double get height => aspectRatio.height(resolution);
}

class VideoAdScene {
  const VideoAdScene({
    required this.type,
    required this.startTime,
    required this.duration,
    required this.imagePath,
    this.textOverlays = const [],
    this.stickers = const [],
    this.transitionIn = TransitionType.fade,
    this.transitionOut = TransitionType.fade,
    this.kenBurns,
  });

  final VideoAdSceneType type;
  final Duration startTime;
  final Duration duration;
  final String imagePath;
  final List<VideoAdTextOverlay> textOverlays;
  final List<VideoAdSticker> stickers;
  final TransitionType transitionIn;
  final TransitionType transitionOut;
  final KenBurnsEffect? kenBurns;
}

class VideoAdTextOverlay {
  const VideoAdTextOverlay({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.color,
    required this.position,
    required this.animation,
    this.shadowColor,
    this.shadowBlur = 0,
    this.strokeColor,
    this.strokeWidth = 0,
    this.backgroundColor,
    this.backgroundPadding,
    this.backgroundRadius = 0,
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final Color color;
  final Offset position;
  final TextAnimation animation;
  final Color? shadowColor;
  final double shadowBlur;
  final Color? strokeColor;
  final double strokeWidth;
  final Color? backgroundColor;
  final EdgeInsets? backgroundPadding;
  final double backgroundRadius;
}

class VideoAdSticker {
  const VideoAdSticker({
    required this.type,
    required this.content,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.opacity = 1,
    this.animation = TextAnimationType.fadeUp,
  });

  final StickerType type;
  final String content;
  final Offset position;
  final Size size;
  final double rotation;
  final double opacity;
  final TextAnimationType animation;
}

class KenBurnsEffect {
  const KenBurnsEffect({
    this.startScale = 1.0,
    this.endScale = 1.15,
    this.startOffset = Offset.zero,
    this.endOffset = const Offset(0.05, 0.05),
  });

  final double startScale;
  final double endScale;
  final Offset startOffset;
  final Offset endOffset;
}

class VideoAdMusicTrack {
  const VideoAdMusicTrack({
    required this.path,
    required this.genre,
    this.volume = 0.3,
    this.ducking = true,
    this.duckingReduction = 0.1,
    this.startTime = Duration.zero,
  });

  final String path;
  final MusicGenre genre;
  final double volume;
  final bool ducking;
  final double duckingReduction;
  final Duration startTime;
}

enum VideoAdAspectRatio {
  ratio9x16,
  ratio1x1,
  ratio16x9,
  ratio4x5;

  double width(VideoAdResolution res) {
    switch (this) {
      case VideoAdAspectRatio.ratio9x16:
        return res.shortSide.toDouble();
      case VideoAdAspectRatio.ratio1x1:
        return res.longSide.toDouble();
      case VideoAdAspectRatio.ratio16x9:
        return res.longSide.toDouble();
      case VideoAdAspectRatio.ratio4x5:
        return (res.shortSide * 0.8).toDouble();
    }
  }

  double height(VideoAdResolution res) {
    switch (this) {
      case VideoAdAspectRatio.ratio9x16:
        return res.longSide.toDouble();
      case VideoAdAspectRatio.ratio1x1:
        return res.longSide.toDouble();
      case VideoAdAspectRatio.ratio16x9:
        return res.shortSide.toDouble();
      case VideoAdAspectRatio.ratio4x5:
        return res.shortSide.toDouble();
    }
  }
}

enum VideoAdResolution {
  sd480,
  hd720,
  fhd1080;

  int get longSide {
    switch (this) {
      case VideoAdResolution.sd480:
        return 480;
      case VideoAdResolution.hd720:
        return 720;
      case VideoAdResolution.fhd1080:
        return 1080;
    }
  }

  int get shortSide {
    switch (this) {
      case VideoAdResolution.sd480:
        return 480;
      case VideoAdResolution.hd720:
        return 720;
      case VideoAdResolution.fhd1080:
        return 1080;
    }
  }
}

/// Curves for text animations
class TextAnimation {
  const TextAnimation({
    required this.type,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
  });

  final TextAnimationType type;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// Sample keyframes for FFmpeg expressions
  List<Keyframe> sampleKeyframes({int fps = 30}) {
    final frames = (duration.inMilliseconds * fps / 1000).round();
    if (frames <= 0) return [];
    return List.generate(frames, (i) {
      final t = i / (frames - 1);
      return Keyframe(time: t, value: curve.transform(t));
    });
  }
}

class Keyframe {
  const Keyframe({required this.time, required this.value});
  final double time;
  final double value;
}
