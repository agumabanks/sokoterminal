import 'package:flutter/material.dart';

import 'video_ad_story_template.dart';

/// Sticker and overlay system for CapCut-grade video ads.

enum StickerType {
  emoji,
  badge,
  ribbon,
  shape,
  logoWatermark,
  arrow,
  confetti,
  sparkle,
}

class VideoAdSticker {
  const VideoAdSticker({
    required this.type,
    required this.content,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.opacity = 1.0,
    this.animation = TextAnimationType.fadeUp,
    this.startTime = Duration.zero,
    this.duration = const Duration(seconds: 3),
  });

  final StickerType type;
  final String content;
  final Offset position;
  final Size size;
  final double rotation;
  final double opacity;
  final TextAnimationType animation;
  final Duration startTime;
  final Duration duration;

  /// Generate FFmpeg overlay filter for this sticker
  String toFFmpegOverlay(int inputIndex, {int fps = 30}) {
    final x = position.dx;
    final y = position.dy;
    final startFrame = (startTime.inMilliseconds * fps / 1000).round();
    final endFrame = ((startTime + duration).inMilliseconds * fps / 1000).round();

    final enableExpr = "between(n,$startFrame,$endFrame)";

    // Animation expressions
    final (alphaExpr, scaleExpr) = switch (animation) {
      TextAnimationType.popScale => (
          "if(lte(n,$startFrame),0,if(lte(n,${startFrame + 10}),(n-$startFrame)/10,1))",
          "if(lte(n,$startFrame),0,if(lte(n,${startFrame + 10}),0.5+0.5*(n-$startFrame)/10,1))"
        ),
      TextAnimationType.bounce => (
          "if(lte(n,$startFrame),0,if(lte(n,${startFrame + 8}),(n-$startFrame)/8,1))",
          "1"
        ),
      _ => (
          "if(lte(n,$startFrame),0,if(lte(n,${startFrame + 8}),(n-$startFrame)/8,1))",
          "1"
        ),
    };

    // For emoji stickers, use drawtext with the emoji character
    if (type == StickerType.emoji) {
      return "drawtext=text='$content':fontsize=${size.height}:fontcolor=yellow:x=$x:y=$y:alpha='$alphaExpr*$opacity':enable='$enableExpr'";
    }

    // For badges, use a colored box with text
    if (type == StickerType.badge) {
      return "drawbox=x=$x:y=$y:w=${size.width}:h=${size.height}:color=red@0.8:t=fill,drawtext=text='$content':fontsize=30:fontcolor=white:x=${x + 10}:y=${y + 10}:alpha='$alphaExpr*$opacity':enable='$enableExpr'";
    }

    // For ribbons, use rotated text
    if (type == StickerType.ribbon) {
      return "drawtext=text='$content':fontsize=40:fontcolor=white:box=1:boxcolor=red@0.8:boxborderw=5:x=$x:y=$y:alpha='$alphaExpr*$opacity':enable='$enableExpr'";
    }

    return '';
  }

  /// Generate sticker as Flutter widget for live preview
  Widget toWidget() {
    switch (type) {
      case StickerType.emoji:
        return Text(content, style: TextStyle(fontSize: size.height));
      case StickerType.badge:
        return Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              content,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        );
      case StickerType.ribbon:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            content,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Predefined sticker library
class StickerLibrary {
  static const fireEmoji = '🔥';
  static const starEmoji = '⭐';
  static const checkEmoji = '✅';
  static const moneyEmoji = '💰';
  static const partyEmoji = '🎉';
  static const saleBadge = 'SALE';
  static const newBadge = 'NEW';
  static const limitedBadge = 'LIMITED';
  static const bestSellerBadge = 'BEST SELLER';
  static const discount50Badge = '50% OFF';
  static const discount30Badge = '30% OFF';
  static const discount20Badge = '20% OFF';
}
