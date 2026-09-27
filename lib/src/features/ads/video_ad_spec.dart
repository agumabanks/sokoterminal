/// Unified video ad specification — replaces the dual VideoAdGenerator + VideoAdRenderer
/// split with a single serializable model that the FfmpegPlanBuilder consumes.
///
/// Created 2026-06-13 as part of the video pipeline unification.
library;

import 'dart:convert';

/// Output formats targeting the platforms sellers actually use.
enum AdFormat {
  /// WhatsApp Status / Instagram Reels / TikTok (9:16 vertical, ≤30s).
  status9x16('Status (9:16)', 720, 1280),
  /// Square feed post for Instagram/Facebook.
  feedSquare('Post (1:1)', 1080, 1080),
  /// Landscape for YouTube/Facebook feed.
  feedWide('Wide (16:9)', 1920, 1080),
  /// Portrait post (4:5) for Instagram feed.
  feedPortrait('Portrait (4:5)', 1080, 1350);

  const AdFormat(this.displayName, this.width, this.height);
  final String displayName;
  final int width;
  final int height;
}

/// Render quality tiers for low-end device awareness.
enum RenderQuality {
  /// 480p draft for quick preview loop.
  draft480('Draft', 480, 854, 'ultrafast'),
  /// 720p standard — WhatsApp Status sweet spot.
  standard720('Standard', 720, 1280, 'veryfast'),
  /// 1080p final — only for capable devices.
  final1080('Final', 1080, 1920, 'veryfast');

  const RenderQuality(this.label, this.height, this.width, this.preset);
  final String label;
  final int height;
  final int width;
  final String preset;
}

/// Text animation styles for drawtext overlays.
enum AdTextAnimation {
  fadeUp,
  popScale,
  slideInLeft,
  slideInRight,
  bounce,
  shimmer,
}

/// Color grade / LUT applied via FFmpeg eq/curves filters.
enum AdColorGrade {
  none,
  vintage,
  neon,
  cinematic,
  blackAndWhite,
  vibrant,
  warm,
  cool,
}

/// Transition types between scenes.
enum AdTransitionType {
  fade,
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
  zoomIn,
  zoomOut,
  crossfade,
  fadeThroughBlack,
}

/// Music genres — East African sellers choose local sounds.
enum AdMusicGenre {
  afrobeats('Afrobeats'),
  bongoFlava('Bongo Flava'),
  gengetone('Gengetone'),
  gospel('Gospel'),
  traditional('Traditional'),
  hipHop('Hip Hop'),
  pop('Pop'),
  electronic('Electronic');

  const AdMusicGenre(this.displayName);
  final String displayName;
}

/// A single text overlay rendered via drawtext.
class AdTextOverlay {
  const AdTextOverlay({
    required this.text,
    required this.fontSize,
    required this.colorHex,
    required this.animation,
    this.strokeColorHex,
    this.strokeWidth = 2,
    this.position = AdTextPosition.bottom,
    this.delaySeconds = 0,
    this.durationSeconds = 3,
  });

  final String text;
  final double fontSize;
  final String colorHex; // e.g. '#FFD700'
  final AdTextAnimation animation;
  final String? strokeColorHex;
  final double strokeWidth;
  final AdTextPosition position;
  final double delaySeconds;
  final double durationSeconds;

  Map<String, dynamic> toJson() => {
    'text': text,
    'fontSize': fontSize,
    'colorHex': colorHex,
    'animation': animation.name,
    'strokeColorHex': strokeColorHex,
    'strokeWidth': strokeWidth,
    'position': position.name,
    'delaySeconds': delaySeconds,
    'durationSeconds': durationSeconds,
  };

  factory AdTextOverlay.fromJson(Map<String, dynamic> json) => AdTextOverlay(
    text: json['text'] as String,
    fontSize: (json['fontSize'] as num).toDouble(),
    colorHex: json['colorHex'] as String,
    animation: AdTextAnimation.values.firstWhere(
      (e) => e.name == json['animation'],
      orElse: () => AdTextAnimation.fadeUp,
    ),
    strokeColorHex: json['strokeColorHex'] as String?,
    strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2,
    position: AdTextPosition.values.firstWhere(
      (e) => e.name == json['position'],
      orElse: () => AdTextPosition.bottom,
    ),
    delaySeconds: (json['delaySeconds'] as num?)?.toDouble() ?? 0,
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 3,
  );
}

enum AdTextPosition { top, center, bottom }

/// Ken Burns pan/zoom effect parameters.
class AdKenBurns {
  const AdKenBurns({
    this.startScale = 1.0,
    this.endScale = 1.12,
    this.startOffset = const NormalizedOffset(0, 0),
    this.endOffset = const NormalizedOffset(0.03, 0.03),
  });

  final double startScale;
  final double endScale;
  final NormalizedOffset startOffset;
  final NormalizedOffset endOffset;

  Map<String, dynamic> toJson() => {
    'startScale': startScale,
    'endScale': endScale,
    'startOffset': {'dx': startOffset.dx, 'dy': startOffset.dy},
    'endOffset': {'dx': endOffset.dx, 'dy': endOffset.dy},
  };

  factory AdKenBurns.fromJson(Map<String, dynamic> json) => AdKenBurns(
    startScale: (json['startScale'] as num?)?.toDouble() ?? 1.0,
    endScale: (json['endScale'] as num?)?.toDouble() ?? 1.12,
    startOffset: NormalizedOffset.fromJson(json['startOffset']),
    endOffset: NormalizedOffset.fromJson(json['endOffset']),
  );
}

/// Offset in normalized [0,1] coordinates (relative to frame dimensions).
class NormalizedOffset {
  const NormalizedOffset(this.dx, this.dy);
  final double dx;
  final double dy;

  Map<String, dynamic> toJson() => {'dx': dx, 'dy': dy};
  factory NormalizedOffset.fromJson(Map<String, dynamic>? json) =>
      NormalizedOffset(
        (json?['dx'] as num?)?.toDouble() ?? 0,
        (json?['dy'] as num?)?.toDouble() ?? 0,
      );
}

/// A single scene in the ad story.
class AdScene {
  const AdScene({
    required this.imagePath,
    required this.durationSeconds,
    this.textOverlays = const [],
    this.kenBurns,
    this.transitionIn = AdTransitionType.fade,
    this.transitionOut = AdTransitionType.fade,
  });

  final String imagePath;
  final double durationSeconds;
  final List<AdTextOverlay> textOverlays;
  final AdKenBurns? kenBurns;
  final AdTransitionType transitionIn;
  final AdTransitionType transitionOut;

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'durationSeconds': durationSeconds,
    'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
    'kenBurns': kenBurns?.toJson(),
    'transitionIn': transitionIn.name,
    'transitionOut': transitionOut.name,
  };

  factory AdScene.fromJson(Map<String, dynamic> json) => AdScene(
    imagePath: json['imagePath'] as String,
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
    textOverlays: (json['textOverlays'] as List<dynamic>?)
            ?.map((e) => AdTextOverlay.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    kenBurns: json['kenBurns'] != null
        ? AdKenBurns.fromJson(json['kenBurns'] as Map<String, dynamic>)
        : null,
    transitionIn: AdTransitionType.values.firstWhere(
      (e) => e.name == json['transitionIn'],
      orElse: () => AdTransitionType.fade,
    ),
    transitionOut: AdTransitionType.values.firstWhere(
      (e) => e.name == json['transitionOut'],
      orElse: () => AdTransitionType.fade,
    ),
  );
}

/// Music track selection — may be null for silent ads.
class AdMusicTrack {
  const AdMusicTrack({
    required this.assetName,
    this.genre = AdMusicGenre.afrobeats,
    this.volume = 0.3,
  });

  final String assetName;
  final AdMusicGenre genre;
  final double volume;

  Map<String, dynamic> toJson() => {
    'assetName': assetName,
    'genre': genre.name,
    'volume': volume,
  };

  factory AdMusicTrack.fromJson(Map<String, dynamic> json) => AdMusicTrack(
    assetName: json['assetName'] as String,
    genre: AdMusicGenre.values.firstWhere(
      (e) => e.name == json['genre'],
      orElse: () => AdMusicGenre.afrobeats,
    ),
    volume: (json['volume'] as num?)?.toDouble() ?? 0.3,
  );
}

/// The complete, serializable video ad specification.
///
/// This replaces the old VideoAdGenerator + VideoAdRenderer split.
/// A simple slideshow is just a spec with one scene and no Ken Burns.
class VideoAdSpec {
  const VideoAdSpec({
    required this.scenes,
    this.format = AdFormat.status9x16,
    this.quality = RenderQuality.standard720,
    this.musicTrack,
    this.colorGrade = AdColorGrade.none,
    this.stickerText,
  });

  final List<AdScene> scenes;
  final AdFormat format;
  final RenderQuality quality;
  final AdMusicTrack? musicTrack;
  final AdColorGrade colorGrade;
  final String? stickerText; // e.g. "SALE 50% OFF" badge overlay

  double get totalDurationSeconds =>
      scenes.fold(0.0, (sum, s) => sum + s.durationSeconds);

  /// Total duration accounting for crossfade overlap.
  double get effectiveDurationSeconds {
    if (scenes.length <= 1) return totalDurationSeconds;
    // Each crossfade overlaps 0.5s between two scenes.
    final overlap = (scenes.length - 1) * 0.5;
    return totalDurationSeconds - overlap;
  }

  Map<String, dynamic> toJson() => {
    'scenes': scenes.map((s) => s.toJson()).toList(),
    'format': format.name,
    'quality': quality.name,
    'musicTrack': musicTrack?.toJson(),
    'colorGrade': colorGrade.name,
    'stickerText': stickerText,
  };

  String encodeJson() => jsonEncode(toJson());

  factory VideoAdSpec.fromJson(Map<String, dynamic> json) => VideoAdSpec(
    scenes: (json['scenes'] as List<dynamic>)
        .map((e) => AdScene.fromJson(e as Map<String, dynamic>))
        .toList(),
    format: AdFormat.values.firstWhere(
      (e) => e.name == json['format'],
      orElse: () => AdFormat.status9x16,
    ),
    quality: RenderQuality.values.firstWhere(
      (e) => e.name == json['quality'],
      orElse: () => RenderQuality.standard720,
    ),
    musicTrack: json['musicTrack'] != null
        ? AdMusicTrack.fromJson(json['musicTrack'] as Map<String, dynamic>)
        : null,
    colorGrade: AdColorGrade.values.firstWhere(
      (e) => e.name == json['colorGrade'],
      orElse: () => AdColorGrade.none,
    ),
    stickerText: json['stickerText'] as String?,
  );

  /// Convenience: build a single-product "quick ad" spec.
  factory VideoAdSpec.quickAd({
    required String imagePath,
    required String productName,
    required String price,
    AdFormat format = AdFormat.status9x16,
    RenderQuality quality = RenderQuality.standard720,
    AdColorGrade grade = AdColorGrade.none,
    AdMusicTrack? music,
  }) {
    return VideoAdSpec(
      format: format,
      quality: quality,
      colorGrade: grade,
      musicTrack: music,
      scenes: [
        AdScene(
          imagePath: imagePath,
          durationSeconds: 5,
          transitionIn: AdTransitionType.fade,
          transitionOut: AdTransitionType.fade,
          textOverlays: [
            AdTextOverlay(
              text: productName,
              fontSize: 72,
              colorHex: '#FFFFFF',
              animation: AdTextAnimation.fadeUp,
              strokeColorHex: '#000000',
              strokeWidth: 4,
              position: AdTextPosition.bottom,
              delaySeconds: 0.3,
              durationSeconds: 4,
            ),
            AdTextOverlay(
              text: price,
              fontSize: 96,
              colorHex: '#FFD700',
              animation: AdTextAnimation.popScale,
              strokeColorHex: '#000000',
              strokeWidth: 4,
              position: AdTextPosition.bottom,
              delaySeconds: 0.8,
              durationSeconds: 3.5,
            ),
          ],
          kenBurns: const AdKenBurns(
            startScale: 1.0,
            endScale: 1.08,
          ),
        ),
      ],
    );
  }
}
