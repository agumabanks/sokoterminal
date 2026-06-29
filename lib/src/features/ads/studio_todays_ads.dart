import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../checkout/checkout_screen.dart';
import 'ad_caption_generator.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'business_hub_templates.dart';
import 'smart_ad_engine.dart';

// ---------------------------------------------------------------------------
// Today's Ads — powered by Smart Ad Engine v2
// ---------------------------------------------------------------------------

/// A ready-to-post ad tailored to one catalog item or business context.
class TodaysAdEntry {
  const TodaysAdEntry({
    required this.id,
    required this.itemName,
    required this.template,
    required this.isService,
    required this.itemId,
    this.imageUrl,
    this.caption = '',
    this.source = SmartAdSource.product,
    this.whatsappCaption = '',
    this.instagramCaption = '',
    this.facebookCaption = '',
    this.xCaption = '',
  });

  final String id;
  final String itemName;
  final AdTemplate template;
  final bool isService;
  final String itemId;
  final String? imageUrl;
  final String caption;
  final SmartAdSource source;
  final String whatsappCaption;
  final String instagramCaption;
  final String facebookCaption;
  final String xCaption;
}

/// Builds ready-to-post ads from local catalog + business info + seasonal — works offline.
List<TodaysAdEntry> buildTodaysAds({
  required List<Item> items,
  required List<Service> services,
  required BrandKit kit,
}) {
  final daySeed = DateTime.now().day + DateTime.now().month * 31;
  final packages = buildSmartAds(
    items: items,
    services: services,
    kit: kit,
    daySeed: daySeed,
  );

  // Limit to a manageable daily feed: 4 product + 2 service + 2 business + 1 seasonal max
  final productAds = packages.where((p) => p.source == SmartAdSource.product).take(4);
  final serviceAds = packages.where((p) => p.source == SmartAdSource.service).take(2);
  final businessAds = packages.where((p) => p.source == SmartAdSource.businessInfo).take(2);
  final seasonalAds = packages.where((p) => p.source == SmartAdSource.seasonal).take(1);

  final selected = <SmartAdPackage>[
    ...productAds,
    ...serviceAds,
    ...businessAds,
    ...seasonalAds,
  ];

  // Fallback: if nothing else, generate a basic business ad
  if (selected.isEmpty && kit.businessName.isNotEmpty) {
    final fallback = templateById('tpl_whatsapp') ?? builtInTemplates.first;
    final applied = fallback.applyProduct(
      productName: kit.businessName,
      priceFormatted: 'See catalog',
      imageUrl: kit.logoNetworkUrl ?? '',
      shopUrl: kit.website.isNotEmpty ? kit.website : 'soko24.co',
      whatsappNumber: kit.whatsapp,
      phoneNumber: kit.phone,
      businessName: kit.businessName,
      location: kit.location,
      tagline: kit.tagline,
    );
    return [
      TodaysAdEntry(
        id: 'today_brand_fallback',
        itemName: kit.businessName,
        template: AdTemplate(
          id: 'today_brand_${fallback.id}',
          name: "Today's Ad · ${kit.businessName}",
          category: applied.category,
          canvasWidth: applied.canvasWidth,
          canvasHeight: applied.canvasHeight,
          background: applied.background,
          elements: applied.elements,
          previewColors: applied.previewColors,
        ),
        isService: false,
        itemId: 'brand',
        imageUrl: kit.logoNetworkUrl,
        caption: 'Shop ${kit.businessName} on Soko24',
        source: SmartAdSource.businessInfo,
      ),
    ];
  }

  return selected.map((p) {
    final wa = p.captions[CaptionPlatform.whatsapp];
    final ig = p.captions[CaptionPlatform.instagram];
    final fb = p.captions[CaptionPlatform.facebook];
    final x = p.captions[CaptionPlatform.x];
    return TodaysAdEntry(
      id: p.id,
      itemName: p.name,
      template: p.template,
      isService: p.isService,
      itemId: p.itemId ?? 'smart',
      imageUrl: p.template.elements
          .where((e) => e.type == 'image')
          .firstOrNull
          ?.src,
      caption: wa?.text ?? '',
      source: p.source,
      whatsappCaption: wa?.fullText ?? '',
      instagramCaption: ig?.fullText ?? '',
      facebookCaption: fb?.fullText ?? '',
      xCaption: x?.fullText ?? '',
    );
  }).toList();
}

final todaysAdsProvider = Provider<List<TodaysAdEntry>>((ref) {
  final items = ref.watch(itemsStreamProvider).valueOrNull ?? [];
  final services = ref.watch(servicesStreamProvider).valueOrNull ?? [];
  final kit = ref.watch(brandKitProvider);
  return buildTodaysAds(items: items, services: services, kit: kit);
});
