import 'package:flutter/foundation.dart';

/// A unique fingerprint for a generated ad, used to detect duplicates.
///
/// Two ads are duplicates if they target the same catalog item with the same
/// platform and core message — even if the visual layout differs.
@immutable
class AdFingerprint {
  const AdFingerprint({
    required this.catalogId,
    required this.platform,
    required this.headline,
    required this.price,
  });

  final String catalogId;
  final String platform;
  final String headline;
  final num price;

  @override
  bool operator ==(Object other) =>
      other is AdFingerprint &&
      other.catalogId == catalogId &&
      other.platform == platform &&
      other.headline == headline &&
      other.price == price;

  @override
  int get hashCode => Object.hash(catalogId, platform, headline, price);
}

/// Prevents generating duplicate ads for the same catalog item.
///
/// Tracks which (item, platform, headline, price) combinations have already
/// been generated so the owner doesn't see the same ad twice.
class AdDeduplicator {
  final Set<AdFingerprint> _seen = {};

  /// Clear all tracked fingerprints (e.g., when starting a new batch).
  void reset() => _seen.clear();

  /// Returns true if this combination has already been generated.
  bool isDuplicate({
    required String catalogId,
    required String platform,
    required String headline,
    required num price,
  }) {
    return _seen.contains(
      AdFingerprint(
        catalogId: catalogId,
        platform: platform,
        headline: headline,
        price: price,
      ),
    );
  }

  /// Mark a combination as seen so future calls return true.
  void markSeen({
    required String catalogId,
    required String platform,
    required String headline,
    required num price,
  }) {
    _seen.add(
      AdFingerprint(
        catalogId: catalogId,
        platform: platform,
        headline: headline,
        price: price,
      ),
    );
  }

  /// Number of unique ads tracked.
  int get count => _seen.length;
}
