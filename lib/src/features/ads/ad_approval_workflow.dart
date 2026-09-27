import 'package:flutter/foundation.dart';

import 'catalog_fact_extractor.dart';
import 'natural_copy_generator.dart';

/// Represents an ad that is awaiting owner approval.
///
/// The owner must review and approve before the ad can be published
/// or shared externally.
@immutable
class PendingAd {
  const PendingAd({
    required this.id,
    required this.catalogId,
    required this.catalogName,
    required this.platform,
    required this.headline,
    required this.body,
    required this.cta,
    required this.price,
    required this.imageUrl,
    required this.facts,
    required this.warnings,
    required this.createdAt,
    this.isApproved = false,
    this.approvedAt,
  });

  final String id;
  final String catalogId;
  final String catalogName;
  final AdPlatform platform;
  final String headline;
  final String body;
  final String cta;
  final num price;
  final String? imageUrl;
  final CatalogFacts facts;
  final List<String> warnings;
  final DateTime createdAt;
  final bool isApproved;
  final DateTime? approvedAt;

  PendingAd copyWith({bool? isApproved, DateTime? approvedAt}) => PendingAd(
        id: id,
        catalogId: catalogId,
        catalogName: catalogName,
        platform: platform,
        headline: headline,
        body: body,
        cta: cta,
        price: price,
        imageUrl: imageUrl,
        facts: facts,
        warnings: warnings,
        createdAt: createdAt,
        isApproved: isApproved ?? this.isApproved,
        approvedAt: approvedAt ?? this.approvedAt,
      );
}

/// Manages the approval workflow for generated ads.
///
/// Ads are held in a pending state until the owner explicitly approves
/// them. This prevents low-quality or incorrect ads from being shared.
class AdApprovalWorkflow {
  final List<PendingAd> _pending = [];

  /// All ads awaiting approval (not yet approved or rejected).
  List<PendingAd> get pending =>
      _pending.where((a) => !a.isApproved).toList();

  /// All approved ads.
  List<PendingAd> get approved =>
      _pending.where((a) => a.isApproved).toList();

  /// Add a new ad to the pending queue.
  void submit(PendingAd ad) {
    _pending.add(ad);
  }

  /// Approve an ad by ID. Returns true if found and approved.
  bool approve(String id) {
    final idx = _pending.indexWhere((a) => a.id == id);
    if (idx < 0) return false;
    _pending[idx] = _pending[idx].copyWith(
      isApproved: true,
      approvedAt: DateTime.now(),
    );
    return true;
  }

  /// Reject (remove) an ad by ID. Returns true if found and removed.
  bool reject(String id) {
    final idx = _pending.indexWhere((a) => a.id == id);
    if (idx < 0) return false;
    _pending.removeAt(idx);
    return true;
  }

  /// Clear all pending (unapproved) ads.
  void clearPending() {
    _pending.removeWhere((a) => !a.isApproved);
  }

  /// Clear all ads (pending and approved).
  void clearAll() {
    _pending.clear();
  }
}
