import 'catalog_fact_extractor.dart';
import 'video_ad_spec.dart';

/// Builds a structured video ad scene sequence.
///
/// Structure: hook → product benefit → verified details → gentle CTA
///
/// Uses only verified catalog facts — never invents claims or uses fake
/// presenters/testimonials.
class VideoSceneBuilder {
  const VideoSceneBuilder();

  /// Build a 4-scene video spec for a catalog item.
  ///
  /// Each scene is 3-5 seconds, total ~15 seconds.
  /// Uses Ken Burns on single images rather than pretending there are
  /// multiple photos.
  VideoAdSpec buildStructuredAd({
    required CatalogFacts facts,
    AdFormat format = AdFormat.status9x16,
    RenderQuality quality = RenderQuality.standard720,
  }) {
    final imagePath = facts.imagePath;
    final scenes = <AdScene>[];

    // Scene 1: Hook (0-3s) — product name as bold text
    scenes.add(AdScene(
      imagePath: imagePath,
      durationSeconds: 3,
      transitionIn: AdTransitionType.fade,
      transitionOut: AdTransitionType.crossfade,
      textOverlays: [
        AdTextOverlay(
          text: facts.name,
          fontSize: 72,
          colorHex: '#FFFFFF',
          animation: AdTextAnimation.fadeUp,
          strokeColorHex: '#000000',
          strokeWidth: 3,
          position: AdTextPosition.center,
          delaySeconds: 0.3,
          durationSeconds: 2.5,
        ),
      ],
      kenBurns: const AdKenBurns(
        startScale: 1.0,
        endScale: 1.08,
      ),
    ));

    // Scene 2: Product benefit (3-7s) — description or category
    final benefitText = facts.description ?? facts.categoryName;
    if (benefitText != null && benefitText.isNotEmpty) {
      scenes.add(AdScene(
        imagePath: imagePath,
        durationSeconds: 4,
        transitionIn: AdTransitionType.crossfade,
        transitionOut: AdTransitionType.crossfade,
        textOverlays: [
          AdTextOverlay(
            text: _truncate(benefitText, 80),
            fontSize: 56,
            colorHex: '#FFFFFF',
            animation: AdTextAnimation.fadeUp,
            strokeColorHex: '#000000',
            strokeWidth: 3,
            position: AdTextPosition.center,
            delaySeconds: 0.3,
            durationSeconds: 3.5,
          ),
        ],
        kenBurns: const AdKenBurns(
          startScale: 1.08,
          endScale: 1.0,
        ),
      ));
    }

    // Scene 3: Verified details (7-11s) — price + seller
    final priceText = facts.price > 0 ? formatUgxPrice(facts.price) : '';
    final detailsOverlays = <AdTextOverlay>[];
    if (priceText.isNotEmpty) {
      detailsOverlays.add(AdTextOverlay(
        text: priceText,
        fontSize: 80,
        colorHex: '#FFD700',
        animation: AdTextAnimation.popScale,
        strokeColorHex: '#000000',
        strokeWidth: 3,
        position: AdTextPosition.bottom,
        delaySeconds: 0.3,
        durationSeconds: 3.5,
      ));
    }
    if (detailsOverlays.isNotEmpty) {
      scenes.add(AdScene(
        imagePath: imagePath,
        durationSeconds: 4,
        transitionIn: AdTransitionType.crossfade,
        transitionOut: AdTransitionType.crossfade,
        textOverlays: detailsOverlays,
        kenBurns: const AdKenBurns(
          startScale: 1.0,
          endScale: 1.05,
        ),
      ));
    }

    // Scene 4: CTA (11-15s) — natural call to action
    final ctaText = _naturalCta(facts);
    scenes.add(AdScene(
      imagePath: imagePath,
      durationSeconds: 4,
      transitionIn: AdTransitionType.crossfade,
      transitionOut: AdTransitionType.fade,
      textOverlays: [
        AdTextOverlay(
          text: ctaText,
          fontSize: 56,
          colorHex: '#FFFFFF',
          animation: AdTextAnimation.fadeUp,
          strokeColorHex: '#000000',
          strokeWidth: 3,
          position: AdTextPosition.bottom,
          delaySeconds: 0.3,
          durationSeconds: 3.5,
        ),
      ],
      kenBurns: const AdKenBurns(
        startScale: 1.05,
        endScale: 1.0,
      ),
    ));

    return VideoAdSpec(
      format: format,
      quality: quality,
      scenes: scenes,
    );
  }

  /// Build a simple single-scene ad for items with minimal data.
  VideoAdSpec buildSimpleAd({
    required CatalogFacts facts,
    AdFormat format = AdFormat.status9x16,
    RenderQuality quality = RenderQuality.standard720,
  }) {
    final imagePath = facts.imagePath;
    final overlays = <AdTextOverlay>[];

    // Product name
    overlays.add(AdTextOverlay(
      text: facts.name,
      fontSize: 72,
      colorHex: '#FFFFFF',
      animation: AdTextAnimation.fadeUp,
      strokeColorHex: '#000000',
      strokeWidth: 3,
      position: AdTextPosition.bottom,
      delaySeconds: 0.3,
      durationSeconds: 4,
    ));

    // Price (if available)
    if (facts.price > 0) {
      overlays.add(AdTextOverlay(
        text: formatUgxPrice(facts.price),
        fontSize: 96,
        colorHex: '#FFD700',
        animation: AdTextAnimation.popScale,
        strokeColorHex: '#000000',
        strokeWidth: 3,
        position: AdTextPosition.bottom,
        delaySeconds: 0.8,
        durationSeconds: 3.5,
      ));
    }

    return VideoAdSpec(
      format: format,
      quality: quality,
      scenes: [
        AdScene(
          imagePath: imagePath,
          durationSeconds: 5,
          transitionIn: AdTransitionType.fade,
          transitionOut: AdTransitionType.fade,
          textOverlays: overlays,
          kenBurns: const AdKenBurns(
            startScale: 1.0,
            endScale: 1.08,
          ),
        ),
      ],
    );
  }

  String _naturalCta(CatalogFacts facts) {
    if (facts.sellerWhatsapp != null && facts.sellerWhatsapp!.isNotEmpty) {
      return 'Message us to order';
    }
    if (facts.sellerPhone != null && facts.sellerPhone!.isNotEmpty) {
      return 'Call to order';
    }
    return 'Ask about availability';
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 3)}...';
  }
}

extension on CatalogFacts {
  String get imagePath => imageUrl ?? '';
}
