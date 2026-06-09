import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../checkout/checkout_screen.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'business_hub_templates.dart';
import 'studio_product_utils.dart';

/// A ready-to-post ad tailored to one catalog item.
class TodaysAdEntry {
  const TodaysAdEntry({
    required this.id,
    required this.itemName,
    required this.template,
    required this.isService,
    required this.itemId,
    this.imageUrl,
    this.caption = '',
  });

  final String id;
  final String itemName;
  final AdTemplate template;
  final bool isService;
  final String itemId;
  final String? imageUrl;
  final String caption;
}

const _productTemplateIds = [
  'tpl_sale_bold',
  'tpl_whatsapp',
  'tpl_new_arrival',
  'tpl_promo',
  'tpl_story',
  'tpl_minimal',
  'gen_hero_sale_sq_1',
  'gen_story_food_sq_37',
  'gen_badge_fashion_fb_46',
  'tpl_catalog',
];

const _serviceTemplateIds = [
  'tpl_booking',
  'hub_service_flyer',
  'gen_hero_service_banner_65',
  'gen_minimal_service_story_68',
  'tpl_professional',
  'hub_brochure_cover',
];

AdTemplate? _pickTemplate(String id) {
  final t = templateById(id);
  if (t != null) return t;
  for (final b in builtInTemplates) {
    if (b.id == id) return b;
  }
  return null;
}

String _rotateId(List<String> pool, int index) {
  if (pool.isEmpty) return 'tpl_sale_bold';
  return pool[index % pool.length];
}

TodaysAdEntry _entryForProduct({
  required Item item,
  required BrandKit kit,
  required int index,
}) {
  final base = _pickTemplate(_rotateId(_productTemplateIds, index)) ??
      builtInTemplates.first;
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
  final caption = StringBuffer()
    ..writeln('🛒 ${item.name}')
    ..writeln('💰 ${formatUgPrice(item.price)}')
    ..writeln()
    ..writeln('Order: ${kit.whatsapp.isNotEmpty ? kit.whatsapp : kit.phone}')
    ..writeln('🔗 $link');
  return TodaysAdEntry(
    id: 'today_product_${item.id}_$index',
    itemName: item.name,
    template: AdTemplate(
      id: 'today_product_${item.id}_${base.id}',
      name: "Today's Ad · ${item.name}",
      category: applied.category,
      canvasWidth: applied.canvasWidth,
      canvasHeight: applied.canvasHeight,
      background: applied.background,
      elements: applied.elements,
      previewColors: applied.previewColors,
    ),
    isService: false,
    itemId: item.id,
    imageUrl: item.imageUrl,
    caption: caption.toString().trim(),
  );
}

TodaysAdEntry _entryForService({
  required Service service,
  required BrandKit kit,
  required int index,
}) {
  final base = _pickTemplate(_rotateId(_serviceTemplateIds, index)) ??
      templateById('hub_service_flyer')!;
  final link = service.remoteId != null
      ? 'soko24.co/service/${service.remoteId}'
      : kit.website.isNotEmpty
          ? kit.website
          : 'soko24.co';
  final applied = base.applyProduct(
    productName: service.title,
    priceFormatted: formatUgPrice(service.price),
    imageUrl: service.imageUrl ?? '',
    shopUrl: link,
    whatsappNumber: kit.whatsapp,
    phoneNumber: kit.phone,
    businessName: kit.businessName,
    location: kit.location,
    tagline: kit.tagline,
    category: service.category ?? 'Service',
  );
  final caption = StringBuffer()
    ..writeln('✨ ${service.title}')
    ..writeln('💰 ${formatUgPrice(service.price)}')
    ..writeln()
    ..writeln('Book: ${kit.whatsapp.isNotEmpty ? kit.whatsapp : kit.phone}')
    ..writeln('🔗 $link');
  return TodaysAdEntry(
    id: 'today_service_${service.id}_$index',
    itemName: service.title,
    template: AdTemplate(
      id: 'today_service_${service.id}_${base.id}',
      name: "Today's Ad · ${service.title}",
      category: applied.category,
      canvasWidth: applied.canvasWidth,
      canvasHeight: applied.canvasHeight,
      background: applied.background,
      elements: applied.elements,
      previewColors: applied.previewColors,
    ),
    isService: true,
    itemId: service.id,
    imageUrl: service.imageUrl,
    caption: caption.toString().trim(),
  );
}

/// Builds ready-to-post ads from local catalog — works offline.
List<TodaysAdEntry> buildTodaysAds({
  required List<Item> items,
  required List<Service> services,
  required BrandKit kit,
}) {
  final daySeed = DateTime.now().day + DateTime.now().month * 31;
  final entries = <TodaysAdEntry>[];

  final products = [...items]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final svcs = [...services]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final productTake = products.take(4).toList();
  final serviceTake = svcs.take(2).toList();

  for (var i = 0; i < productTake.length; i++) {
    entries.add(_entryForProduct(
      item: productTake[i],
      kit: kit,
      index: daySeed + i,
    ));
  }
  for (var i = 0; i < serviceTake.length; i++) {
    entries.add(_entryForService(
      service: serviceTake[i],
      kit: kit,
      index: daySeed + i + 7,
    ));
  }

  if (entries.isEmpty && kit.businessName.isNotEmpty) {
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
    entries.add(TodaysAdEntry(
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
    ));
  }

  return entries;
}

final todaysAdsProvider = Provider<List<TodaysAdEntry>>((ref) {
  final items = ref.watch(itemsStreamProvider).valueOrNull ?? [];
  final services = ref.watch(servicesStreamProvider).valueOrNull ?? [];
  final kit = ref.watch(brandKitProvider);
  return buildTodaysAds(items: items, services: services, kit: kit);
});