import 'catalog_fact_extractor.dart';

/// Generates natural, grounded marketing copy for catalog items.
///
/// Every claim in the generated copy comes from verified catalog facts.
/// Never invents prices, discounts, reviews, availability, or features.
class NaturalCopyGenerator {
  const NaturalCopyGenerator();

  /// Generate a natural headline for the catalog item.
  ///
  /// Uses the actual product name and category — no clickbait.
  String headline(CatalogFacts facts) {
    final name = facts.name;
    final category = facts.categoryName;

    if (facts.isService) {
      // Services: lead with the service name
      if (category != null && category.isNotEmpty) {
        return '$name · $category';
      }
      return name;
    }

    // Products: clean, specific headline
    if (category != null && category.isNotEmpty) {
      return '$name · $category';
    }
    return name;
  }

  /// Generate a benefit-led subheadline from the description.
  ///
  /// Returns null if no description is available — never invents benefits.
  String? subheadline(CatalogFacts facts) {
    final desc = facts.description;
    if (desc == null || desc.isEmpty) return null;

    // Use the first sentence of the description as the subheadline
    final firstSentence = desc.split('.').first.trim();
    if (firstSentence.length > 80) {
      return '${firstSentence.substring(0, 77)}...';
    }
    return firstSentence;
  }

  /// Generate a natural call-to-action based on available contact methods.
  ///
  /// Only suggests contact methods that actually exist.
  List<String> ctas(CatalogFacts facts) {
    final ctas = <String>[];

    if (facts.sellerWhatsapp != null && facts.sellerWhatsapp!.isNotEmpty) {
      ctas.add('Message us to order');
      ctas.add('WhatsApp to order');
    }
    if (facts.sellerPhone != null && facts.sellerPhone!.isNotEmpty) {
      ctas.add('Call to order');
    }
    if (ctas.isEmpty) {
      // Generic but honest — no fake contact method
      ctas.add('Ask about availability');
    }
    return ctas;
  }

  /// Generate a short, natural caption for a specific platform.
  ///
  /// The caption only includes verified facts. Missing data is omitted,
  /// never replaced with invented defaults.
  String caption({
    required CatalogFacts facts,
    required AdPlatform platform,
  }) {
    switch (platform) {
      case AdPlatform.whatsapp:
        return _whatsappCaption(facts);
      case AdPlatform.instagram:
        return _instagramCaption(facts);
      case AdPlatform.tiktok:
        return _tiktokCaption(facts);
      case AdPlatform.squarePost:
        return _squarePostCaption(facts);
    }
  }

  String _whatsappCaption(CatalogFacts facts) {
    final lines = <String>[];

    // Product name (bold in WhatsApp markdown)
    lines.add('*${facts.name}*');

    // Price (verified)
    if (facts.price > 0) {
      lines.add('');
      lines.add('Price: *${formatUgxPrice(facts.price)}*');
      final wasPrice = facts.verifiedWasPrice;
      if (wasPrice != null) {
        lines.add(wasPrice);
      }
    }

    // Description (if available)
    if (facts.description != null && facts.description!.isNotEmpty) {
      lines.add('');
      lines.add(facts.description!);
    }

    // Seller + contact (only verified methods)
    lines.add('');
    if (facts.sellerWhatsapp != null && facts.sellerWhatsapp!.isNotEmpty) {
      lines.add('WhatsApp: ${facts.sellerWhatsapp}');
    }
    if (facts.sellerPhone != null && facts.sellerPhone!.isNotEmpty) {
      lines.add('Call: ${facts.sellerPhone}');
    }
    if (facts.sellerLocation != null && facts.sellerLocation!.isNotEmpty) {
      lines.add('${facts.sellerLocation}');
    }

    // Seller attribution
    lines.add('');
    lines.add('— ${facts.sellerName}');

    return lines.join('\n');
  }

  String _instagramCaption(CatalogFacts facts) {
    final lines = <String>[];

    // Hook: product name, not clickbait
    lines.add(facts.name);
    lines.add('');

    // Description
    if (facts.description != null && facts.description!.isNotEmpty) {
      lines.add(facts.description!);
      lines.add('');
    }

    // Price
    if (facts.price > 0) {
      lines.add(formatUgxPrice(facts.price));
      final wasPrice = facts.verifiedWasPrice;
      if (wasPrice != null) {
        lines.add(wasPrice);
      }
      lines.add('');
    }

    // CTA (natural, not pushy)
    final availableCtas = ctas(facts);
    if (availableCtas.isNotEmpty) {
      lines.add(availableCtas.first);
    }

    // Seller
    lines.add('');
    lines.add('@${facts.sellerName.replaceAll(' ', '').toLowerCase()}');

    return lines.join('\n');
  }

  String _tiktokCaption(CatalogFacts facts) {
    final lines = <String>[];

    // Short, punchy — product name only
    lines.add(facts.name);
    lines.add('');

    if (facts.description != null && facts.description!.isNotEmpty) {
      // TikTok: keep it very short
      final short = facts.description!.length > 60
          ? '${facts.description!.substring(0, 57)}...'
          : facts.description!;
      lines.add(short);
      lines.add('');
    }

    if (facts.price > 0) {
      lines.add(formatUgxPrice(facts.price));
      lines.add('');
    }

    final availableCtas = ctas(facts);
    if (availableCtas.isNotEmpty) {
      lines.add(availableCtas.first);
    }

    return lines.join('\n');
  }

  String _squarePostCaption(CatalogFacts facts) {
    final lines = <String>[];

    lines.add(facts.name);
    lines.add('');

    if (facts.price > 0) {
      lines.add(formatUgxPrice(facts.price));
    }

    if (facts.description != null && facts.description!.isNotEmpty) {
      lines.add('');
      lines.add(facts.description!);
    }

    lines.add('');
    final availableCtas = ctas(facts);
    if (availableCtas.isNotEmpty) {
      lines.add(availableCtas.first);
    }

    lines.add('');
    lines.add('— ${facts.sellerName}');

    return lines.join('\n');
  }
}

/// Platforms that ads are generated for.
enum AdPlatform {
  whatsapp,
  instagram,
  tiktok,
  squarePost,
}
