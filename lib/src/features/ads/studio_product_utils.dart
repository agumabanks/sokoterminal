import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import 'brand_kit_screen.dart';
import 'overlay_presets.dart';

/// Which product/shop fields to include when sharing an ad.
class StudioShareDetails {
  const StudioShareDetails({
    this.includeProductName = true,
    this.includePrice = true,
    this.includeProductLink = true,
    this.includeWhatsapp = true,
    this.includePhone = true,
    this.includeBusiness = true,
    this.includeLocation = true,
    this.includeTagline = true,
    this.includeCategory = false,
  });

  final bool includeProductName;
  final bool includePrice;
  final bool includeProductLink;
  final bool includeWhatsapp;
  final bool includePhone;
  final bool includeBusiness;
  final bool includeLocation;
  final bool includeTagline;
  final bool includeCategory;

  StudioShareDetails copyWith({
    bool? includeProductName,
    bool? includePrice,
    bool? includeProductLink,
    bool? includeWhatsapp,
    bool? includePhone,
    bool? includeBusiness,
    bool? includeLocation,
    bool? includeTagline,
    bool? includeCategory,
  }) =>
      StudioShareDetails(
        includeProductName: includeProductName ?? this.includeProductName,
        includePrice: includePrice ?? this.includePrice,
        includeProductLink: includeProductLink ?? this.includeProductLink,
        includeWhatsapp: includeWhatsapp ?? this.includeWhatsapp,
        includePhone: includePhone ?? this.includePhone,
        includeBusiness: includeBusiness ?? this.includeBusiness,
        includeLocation: includeLocation ?? this.includeLocation,
        includeTagline: includeTagline ?? this.includeTagline,
        includeCategory: includeCategory ?? this.includeCategory,
      );
}

String formatUgPrice(num price) {
  final fmt = NumberFormat('#,###', 'en_US');
  return 'UGX ${fmt.format(price.round())}';
}

/// Strikethrough "was" price when the catalog item has a discount.
String formatProductWasPrice(Item product) {
  final discount = product.discount;
  if (discount == null || discount <= 0) return '';
  if (product.discountType == 'percent') {
    final was = product.price / (1 - discount / 100);
    return 'Was ${formatUgPrice(was)}';
  }
  return 'Was ${formatUgPrice(product.price + discount)}';
}

OverlayBrandContext overlayContextFrom({
  required BrandKit kit,
  Item? product,
}) {
  return OverlayBrandContext(
    businessName: kit.businessName,
    tagline: kit.tagline,
    brandPrimary: _parseKitColor(kit.primaryColor),
    brandAccent: _parseKitColor(kit.accentColor),
    phone: kit.phone,
    whatsapp: kit.whatsapp,
    location: kit.location,
    website: kit.website.isNotEmpty ? kit.website : 'soko24.co',
    productName: product?.name ?? '',
    productPrice: product != null ? formatUgPrice(product.price) : '',
    productWasPrice: product != null ? formatProductWasPrice(product) : '',
  );
}

Color _parseKitColor(String hex) {
  try {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return const Color(0xFF0F1D40);
  }
}

String normalizeShareUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'https://soko24.co';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

/// Build a buyer-facing product URL (slug preferred).
Future<String> resolveProductShareLink({
  required Item? product,
  required BrandKit kit,
  SellerApi? api,
}) async {
  if (product?.remoteId != null && api != null) {
    try {
      final res = await api.fetchProductDetails(product!.remoteId!);
      final data = res.data;
      if (data is Map) {
        final payload = data['data'] ?? data;
        if (payload is Map) {
          final link = payload['link']?.toString();
          if (link != null && link.isNotEmpty) return normalizeShareUrl(link);
          final slug = payload['slug']?.toString();
          if (slug != null && slug.isNotEmpty) {
            return 'https://soko24.co/product/$slug';
          }
        }
      }
    } catch (_) {}
  }

  if (kit.website.isNotEmpty) return normalizeShareUrl(kit.website);
  return 'https://soko24.co';
}

String buildShareCaption({
  required BrandKit kit,
  required String templateName,
  required StudioShareDetails details,
  Item? product,
  String? productLink,
}) {
  final buf = StringBuffer();

  if (details.includeBusiness && kit.businessName.isNotEmpty) {
    buf.writeln('✨ ${kit.businessName}');
  }
  if (details.includeTagline && kit.tagline.isNotEmpty) {
    buf.writeln(kit.tagline);
  }
  buf.writeln();

  if (details.includeProductName && product != null) {
    buf.writeln('🛍️ ${product.name}');
  } else {
    buf.writeln('📌 $templateName');
  }

  if (details.includeCategory &&
      product?.categoryName != null &&
      product!.categoryName!.isNotEmpty) {
    buf.writeln('🏷️ ${product.categoryName}');
  }

  if (details.includePrice && product != null) {
    buf.writeln('💰 ${formatUgPrice(product.price)}');
  }

  if (details.includeLocation && kit.location.isNotEmpty) {
    buf.writeln('📍 ${kit.location}');
  }

  buf.writeln();
  if (details.includeProductLink && productLink != null && productLink.isNotEmpty) {
    buf.writeln('🔗 $productLink');
    buf.writeln();
  }

  if (details.includeWhatsapp && kit.whatsapp.isNotEmpty) {
    buf.writeln('💬 Order on WhatsApp: ${kit.whatsapp}');
  }
  if (details.includePhone && kit.phone.isNotEmpty) {
    buf.writeln('📞 ${kit.phone}');
  }

  buf.writeln();
  final tag = kit.businessName.replaceAll(RegExp(r'\s+'), '');
  buf.write('#Soko24 #SokoStudio${tag.isNotEmpty ? ' #$tag' : ''}');

  return buf.toString().trim();
}