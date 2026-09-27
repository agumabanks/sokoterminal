import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import 'brand_kit_screen.dart';

/// Currency formatter for Ugandan Shillings (UGX).
///
/// Uses "/" as the UGX symbol suffix (market-standard shorthand) and
/// groups thousands with commas. Never invents a currency symbol.
final NumberFormat ugxFormat = NumberFormat('#,###', 'en_US');

/// Format a UGX price for display. Returns "N/A" for null/invalid prices.
String formatUgxPrice(num? price) {
  if (price == null || price < 0) return 'N/A';
  return '${ugxFormat.format(price.round())} /=';
}

/// The verified facts we extracted from a single catalog record.
///
/// Every field here comes from the database or brand kit — nothing invented.
/// Missing data stays null so downstream code can decide what to do.
@immutable
class CatalogFacts {
  const CatalogFacts({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.isService,
    required this.stockQty,
    required this.stockEnabled,
    required this.isPublished,
    required this.categoryName,
    required this.sellerName,
    required this.sellerPhone,
    required this.sellerWhatsapp,
    required this.sellerLocation,
    required this.shopUrl,
    required this.brandPrimaryColor,
    required this.brandAccentColor,
    required this.isDiscount,
    this.discountAmount,
    this.discountType,
    this.hasMultipleImages = false,
    this.imageCount = 0,
  });

  final String id;
  final String name;
  final num price;
  final String? description;
  final String? imageUrl;
  final bool isService;

  // Stock state
  final int stockQty;
  final bool stockEnabled;
  final bool isPublished;

  /// True when the item is buyable (published + in stock or stock disabled).
  bool get isAvailable => isPublished && (!stockEnabled || stockQty > 0);

  final String? categoryName;

  // Seller identity
  final String sellerName;
  final String? sellerPhone;
  final String? sellerWhatsapp;
  final String? sellerLocation;
  final String shopUrl;
  final String brandPrimaryColor;
  final String brandAccentColor;

  // Discount (only if the catalog actually has one)
  final bool isDiscount;
  final num? discountAmount;
  final String? discountType;

  // Media
  final bool hasMultipleImages;
  final int imageCount;

  /// True when this record has enough data to make a trustworthy ad.
  bool get isComplete =>
      name.isNotEmpty &&
      price > 0 &&
      imageUrl != null &&
      imageUrl!.isNotEmpty &&
      sellerName.isNotEmpty;

  /// Human-readable summary of what's missing (for owner correction).
  List<String> get missingFields {
    final m = <String>[];
    if (name.isEmpty) m.add('Product name');
    if (price <= 0) m.add('Price');
    if (imageUrl == null || imageUrl!.isEmpty) m.add('Product image');
    if (sellerName.isEmpty) m.add('Seller name');
    return m;
  }

  /// The verified "was" price — only when a real discount exists.
  String? get verifiedWasPrice {
    if (!isDiscount || discountAmount == null || discountAmount! <= 0) {
      return null;
    }
    if (discountType == 'percent') {
      final was = price / (1 - discountAmount! / 100);
      return 'Was ${formatUgxPrice(was)}';
    }
    return 'Was ${formatUgxPrice(price + discountAmount!)}';
  }
}

/// Extracts and validates facts from a catalog [Item].
///
/// All facts come from the database record — nothing invented.
CatalogFacts extractItemFacts({
  required Item item,
  required BrandKit kit,
  String? shopUrl,
}) {
  final isPublished = item.publishedOnline;

  return CatalogFacts(
    id: item.id,
    name: item.name,
    price: item.price,
    description: _cleanDescription(item.description),
    imageUrl: item.imageUrl ?? item.thumbnailUrl,
    isService: false,
    stockQty: item.stockQty,
    stockEnabled: item.stockEnabled,
    isPublished: isPublished,
    categoryName: item.categoryName,
    sellerName: kit.businessName,
    sellerPhone: kit.phone,
    sellerWhatsapp: kit.whatsapp,
    sellerLocation: kit.location,
    shopUrl: shopUrl ?? kit.website,
    brandPrimaryColor: kit.primaryColor,
    brandAccentColor: kit.accentColor,
    isDiscount: item.discount != null && item.discount! > 0,
    discountAmount: item.discount,
    discountType: item.discountType,
  );
}

/// Extracts and validates facts from a catalog [Service].
CatalogFacts extractServiceFacts({
  required Service service,
  required BrandKit kit,
  String? shopUrl,
}) {
  return CatalogFacts(
    id: service.id,
    name: service.title,
    price: service.price,
    description: _cleanDescription(service.summary ?? service.description),
    imageUrl: service.imageUrl,
    isService: true,
    stockQty: 0,
    stockEnabled: false,
    isPublished: service.publishedOnline,
    categoryName: service.category,
    sellerName: kit.businessName,
    sellerPhone: kit.phone,
    sellerWhatsapp: kit.whatsapp,
    sellerLocation: kit.location,
    shopUrl: shopUrl ?? kit.website,
    brandPrimaryColor: kit.primaryColor,
    brandAccentColor: kit.accentColor,
    isDiscount: false,
  );
}

String? _cleanDescription(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var value = raw
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  const maxLength = 240;
  if (value.length > maxLength) {
    value = '${value.substring(0, maxLength).trimRight()}…';
  }
  return value.isEmpty ? null : value;
}
