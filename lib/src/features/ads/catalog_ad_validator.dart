import 'package:flutter/foundation.dart';

import 'catalog_fact_extractor.dart';

/// Result of validating a catalog record for ad generation.
@immutable
class CatalogValidationResult {
  const CatalogValidationResult({
    required this.isValid,
    required this.facts,
    required this.reasons,
    required this.warnings,
  });

  /// True when the record can be used to generate an ad.
  final bool isValid;

  /// The extracted facts (always present, even when invalid).
  final CatalogFacts facts;

  /// Reasons the record was rejected (only when invalid).
  final List<String> reasons;

  /// Non-fatal concerns (present even when valid).
  final List<String> warnings;
}

/// Validates catalog records before ad generation.
///
/// Prevents generating ads from incomplete or suspicious records.
/// Never invents missing data — flags it for owner correction.
class CatalogAdValidator {
  const CatalogAdValidator();

  /// Minimum price to consider an item valid (UGX).
  static const minValidPrice = 100;

  /// Maximum price to consider an item valid (UGX 100M).
  static const maxValidPrice = 100000000;

  /// Validate a catalog record for ad generation.
  CatalogValidationResult validate(CatalogFacts facts) {
    final reasons = <String>[];
    final warnings = <String>[];

    // ── Required fields ──────────────────────────────────────────────────
    if (facts.name.trim().isEmpty) {
      reasons.add('Missing product name');
    }
    if (facts.price <= 0) {
      reasons.add('Missing or zero price');
    } else if (facts.price < minValidPrice) {
      reasons.add('Price below minimum ($minValidPrice UGX)');
    } else if (facts.price > maxValidPrice) {
      reasons.add('Price exceeds maximum ($maxValidPrice UGX)');
    }
    if (facts.imageUrl == null || facts.imageUrl!.trim().isEmpty) {
      reasons.add('Missing product image');
    }
    if (facts.sellerName.trim().isEmpty) {
      reasons.add('Missing seller name');
    }

    // ── Availability ──────────────────────────────────────────────────────
    if (!facts.isPublished) {
      reasons.add('Item not published online');
    }
    if (facts.stockEnabled && facts.stockQty <= 0) {
      reasons.add('Out of stock');
    }

    // ── Warnings (non-fatal) ──────────────────────────────────────────────
    if (facts.description == null || facts.description!.isEmpty) {
      warnings.add('No product description');
    }
    if (facts.sellerPhone == null && facts.sellerWhatsapp == null) {
      warnings.add('No contact method (phone or WhatsApp)');
    }
    if (facts.sellerLocation == null || facts.sellerLocation!.isEmpty) {
      warnings.add('No seller location');
    }
    if (!facts.hasMultipleImages) {
      warnings.add('Only one product image');
    }

    return CatalogValidationResult(
      isValid: reasons.isEmpty,
      facts: facts,
      reasons: reasons,
      warnings: warnings,
    );
  }
}
