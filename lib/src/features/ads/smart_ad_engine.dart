import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../checkout/checkout_screen.dart';
import 'ad_caption_generator.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'business_ad_generator.dart';
import 'business_hub_templates.dart';
import 'seasonal_campaign_generator.dart';
import 'studio_overlay_helper.dart';
import 'studio_product_utils.dart';

// ---------------------------------------------------------------------------
// Smart Ad Engine v2 — 360-degree marketing ad generation
// ---------------------------------------------------------------------------

/// A complete smart ad package with template + captions.
class SmartAdPackage {
  const SmartAdPackage({
    required this.id,
    required this.name,
    required this.template,
    required this.captions,
    required this.source,
    this.isService = false,
    this.itemId,
  });

  final String id;
  final String name;
  final AdTemplate template;
  final Map<CaptionPlatform, GeneratedCaption> captions;
  final SmartAdSource source;
  final bool isService;
  final String? itemId;
}

enum SmartAdSource {
  product,
  service,
  businessInfo,
  seasonal,
  aiGenerated,
}

extension SmartAdSourceX on SmartAdSource {
  String get label => switch (this) {
    SmartAdSource.product => 'Product Ad',
    SmartAdSource.service => 'Service Ad',
    SmartAdSource.businessInfo => 'Business Ad',
    SmartAdSource.seasonal => 'Seasonal',
    SmartAdSource.aiGenerated => 'AI Generated',
  };

  String get iconEmoji => switch (this) {
    SmartAdSource.product => '🛒',
    SmartAdSource.service => '✨',
    SmartAdSource.businessInfo => '🏪',
    SmartAdSource.seasonal => '🎉',
    SmartAdSource.aiGenerated => '🤖',
  };
}

// ---------------------------------------------------------------------------
// Provider: All smart ads for today
// ---------------------------------------------------------------------------

final smartAdsProvider = Provider<List<SmartAdPackage>>((ref) {
  final items = ref.watch(itemsStreamProvider).valueOrNull ?? [];
  final services = ref.watch(servicesStreamProvider).valueOrNull ?? [];
  final kit = ref.watch(brandKitProvider);
  final daySeed = DateTime.now().day + DateTime.now().month * 31;

  return buildSmartAds(
    items: items,
    services: services,
    kit: kit,
    daySeed: daySeed,
  );
});

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

List<SmartAdPackage> buildSmartAds({
  required List<Item> items,
  required List<Service> services,
  required BrandKit kit,
  required int daySeed,
}) {
  final out = <SmartAdPackage>[];

  // ── Product ads (up to 4) ───────────────────────────────────────────────
  final products = [...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final productTake = products.take(4).toList();
  for (var i = 0; i < productTake.length; i++) {
    final item = productTake[i];
    final tpl = _pickProductTemplate(item, kit, daySeed + i);
    final captions = generateAllCaptions(
      productName: item.name,
      price: formatUgPrice(item.price),
      businessName: kit.businessName.isNotEmpty ? kit.businessName : 'Soko 24',
      shopUrl: item.remoteId != null ? 'soko24.co/p/${item.remoteId}' : 'soko24.co',
      whatsapp: kit.whatsapp,
      phone: kit.phone,
      location: kit.location,
      tagline: kit.tagline,
      seed: daySeed + i,
    );
    out.add(SmartAdPackage(
      id: 'smart_product_${item.id}_$i',
      name: item.name,
      template: tpl,
      captions: captions,
      source: SmartAdSource.product,
      isService: false,
      itemId: item.id,
    ));
  }

  // ── Service ads (up to 2) ───────────────────────────────────────────────
  final svcs = [...services]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final serviceTake = svcs.take(2).toList();
  for (var i = 0; i < serviceTake.length; i++) {
    final svc = serviceTake[i];
    final tpl = _pickServiceTemplate(svc, kit, daySeed + i + 100);
    final captions = generateAllCaptions(
      productName: svc.title,
      price: formatUgPrice(svc.price),
      businessName: kit.businessName.isNotEmpty ? kit.businessName : 'Soko 24',
      shopUrl: svc.remoteId != null ? 'soko24.co/service/${svc.remoteId}' : 'soko24.co',
      whatsapp: kit.whatsapp,
      phone: kit.phone,
      location: kit.location,
      tagline: kit.tagline,
      seed: daySeed + i + 100,
    );
    out.add(SmartAdPackage(
      id: 'smart_service_${svc.id}_$i',
      name: svc.title,
      template: tpl,
      captions: captions,
      source: SmartAdSource.service,
      isService: true,
      itemId: svc.id,
    ));
  }

  // ── Business-info ads (up to 3) ─────────────────────────────────────────
  if (kit.businessName.isNotEmpty) {
    final bizAds = generateBusinessAds(
      businessName: kit.businessName,
      tagline: kit.tagline,
      phone: kit.phone,
      whatsapp: kit.whatsapp,
      location: kit.location,
      website: kit.website,
      primaryColor: kit.primaryColor,
      accentColor: kit.accentColor,
      seed: daySeed,
    );
    final bizTake = bizAds.take(3).toList();
    for (var i = 0; i < bizTake.length; i++) {
      final tpl = bizTake[i];
      final captions = generateAllCaptions(
        productName: kit.businessName,
        price: 'See catalog',
        businessName: kit.businessName,
        shopUrl: kit.website.isNotEmpty ? kit.website : 'soko24.co',
        whatsapp: kit.whatsapp,
        phone: kit.phone,
        location: kit.location,
        tagline: kit.tagline,
        seed: daySeed + i + 200,
      );
      out.add(SmartAdPackage(
        id: 'smart_biz_${tpl.id}_$i',
        name: tpl.name,
        template: tpl,
        captions: captions,
        source: SmartAdSource.businessInfo,
        isService: false,
      ));
    }
  }

  // ── Seasonal ads (if active season) ─────────────────────────────────────
  final seasons = currentSeasons();
  if (seasons.isNotEmpty) {
    final season = seasons.first;
    final seasonalAds = generateSeasonalCampaign(
      season: season,
      businessName: kit.businessName.isNotEmpty ? kit.businessName : 'Soko 24',
      primaryColor: kit.primaryColor,
      accentColor: kit.accentColor,
      seed: daySeed,
    );
    final seasonTake = seasonalAds.take(2).toList();
    for (var i = 0; i < seasonTake.length; i++) {
      final tpl = seasonTake[i];
      final captions = generateAllCaptions(
        productName: season.name,
        price: 'Seasonal Offers',
        businessName: kit.businessName.isNotEmpty ? kit.businessName : 'Soko 24',
        shopUrl: kit.website.isNotEmpty ? kit.website : 'soko24.co',
        whatsapp: kit.whatsapp,
        phone: kit.phone,
        location: kit.location,
        tagline: kit.tagline,
        extraHashtags: season.suggestedHashtags,
        seed: daySeed + i + 300,
      );
      out.add(SmartAdPackage(
        id: 'smart_season_${season.id}_$i',
        name: tpl.name,
        template: tpl,
        captions: captions,
        source: SmartAdSource.seasonal,
        isService: false,
      ));
    }
  }

  return out;
}

// ---------------------------------------------------------------------------
// Overlay application
// ---------------------------------------------------------------------------

AdTemplate _applyOverlay(AdTemplate template, List<CanvasElement> overlays) {
  if (overlays.isEmpty) return template;

  final maxZ = template.elements.fold<int>(
    0,
    (max, el) => el.zIndex > max ? el.zIndex : max,
  );
  final nextZ = maxZ + 1;
  final stamped = overlays
      .map((el) => el.copyWith(zIndex: nextZ))
      .toList();

  return AdTemplate(
    id: template.id,
    name: template.name,
    category: template.category,
    canvasWidth: template.canvasWidth,
    canvasHeight: template.canvasHeight,
    background: template.background,
    elements: [...template.elements, ...stamped],
    previewColors: template.previewColors,
  );
}

// ---------------------------------------------------------------------------
// Template pickers
// ---------------------------------------------------------------------------

AdTemplate _pickProductTemplate(Item item, BrandKit kit, int seed) {
  final ids = [
    'tpl_sale_bold',
    'tpl_whatsapp',
    'tpl_new_arrival',
    'tpl_promo',
    'tpl_story',
    'tpl_minimal',
    'gen_hero_sale_sq',
    'gen_story_food_sq',
    'gen_badge_fashion_story',
    'tpl_catalog',
    'gen_diagonal_sale_sq',
    'gen_magazine_new_sq',
    'gen_polaroid_promo_sq',
    'gen_cinematic_story_sq',
    'gen_price_splash_sale_sq',
  ];
  final id = ids[seed % ids.length];
  final base = templateById(id) ?? builtInTemplates.first;
  final link = item.remoteId != null
      ? 'soko24.co/p/${item.remoteId}'
      : 'soko24.co';
  final applied = base.applyProduct(
    productName: item.name,
    priceFormatted: formatUgPrice(item.price),
    imageUrl: item.imageUrl ?? '',
    shopUrl: link,
    whatsappNumber: kit.whatsapp,
    phoneNumber: kit.phone,
    businessName: kit.businessName,
    location: kit.location,
    tagline: kit.tagline,
  );
  final overlays = pickOverlayForContext(
    product: item,
    service: null,
    kit: kit,
    canvasWidth: applied.canvasWidth,
    canvasHeight: applied.canvasHeight,
  );
  return _applyOverlay(applied, overlays);
}

AdTemplate _pickServiceTemplate(Service svc, BrandKit kit, int seed) {
  final ids = [
    'tpl_booking',
    'hub_service_flyer',
    'gen_hero_service_sq',
    'gen_minimal_service_story',
    'tpl_professional',
    'hub_brochure_cover',
    'gen_diagonal_service_sq',
    'gen_magazine_service_sq',
    'gen_process_service_sq',
    'gen_testimonial_service_sq',
  ];
  final id = ids[seed % ids.length];
  final base = templateById(id) ?? builtInTemplates.first;
  final link = svc.remoteId != null
      ? 'soko24.co/service/${svc.remoteId}'
      : kit.website.isNotEmpty ? kit.website : 'soko24.co';
  final applied = base.applyProduct(
    productName: svc.title,
    priceFormatted: formatUgPrice(svc.price),
    imageUrl: svc.imageUrl ?? '',
    shopUrl: link,
    whatsappNumber: kit.whatsapp,
    phoneNumber: kit.phone,
    businessName: kit.businessName,
    location: kit.location,
    tagline: kit.tagline,
    category: svc.category ?? 'Service',
  );
  final overlays = pickOverlayForContext(
    product: null,
    service: svc,
    kit: kit,
    canvasWidth: applied.canvasWidth,
    canvasHeight: applied.canvasHeight,
  );
  return _applyOverlay(applied, overlays);
}
