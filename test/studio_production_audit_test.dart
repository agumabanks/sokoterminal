import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/ads/ad_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/ad_caption_generator.dart';
import 'package:soko_seller_terminal/src/features/ads/brand_kit_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/business_hub_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_template_discovery.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_todays_ads.dart';
import 'package:soko_seller_terminal/src/features/ads/smart_ad_engine.dart';

/// Production-readiness gate for Soko Studio templates & discovery.
void main() {
  group('Studio production audit', () {
    test('every catalog template id resolves locally', () {
      final sections = localTemplateDiscoveryFallback();
      final missing = <String>[];

      for (final section in sections) {
        for (final id in section.templateIds) {
          if (templateById(id) == null) missing.add('${section.id}:$id');
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Unresolved template IDs: ${missing.join(', ')}',
      );
    });

    test('generatedTemplateId resolves layout category pairs', () {
      expect(generatedTemplateId('story', 'food'), 'gen_story_food_sq');
      expect(
        generatedTemplateId('badge', 'fashion'),
        'gen_badge_fashion_story',
      );
      expect(generatedTemplateId('hero', 'service'), 'gen_hero_service_sq');
      expect(
        generatedTemplateId('minimal', 'service'),
        'gen_minimal_service_a6',
      );
    });

    test('todays ads template pool ids all exist', () {
      const pool = [..._productTemplateIds, ..._serviceTemplateIds];
      final missing = pool.where((id) => templateById(id) == null).toList();
      expect(missing, isEmpty, reason: 'Missing today pool: $missing');
    });

    test('handcrafted templates have preview colors and content', () {
      final issues = <String>[];
      for (final t in builtInTemplates) {
        if (t.previewColors == null || t.previewColors!.isEmpty) {
          issues.add('${t.id}: no previewColors');
        }
        if (t.elements.isEmpty) {
          issues.add('${t.id}: no elements');
        }
        if (t.canvasWidth < 100 || t.canvasHeight < 100) {
          issues.add('${t.id}: tiny canvas');
        }
      }
      expect(issues, isEmpty, reason: issues.join('\n'));
    });

    test('business hub templates are print-ready quality bar', () {
      final issues = <String>[];
      for (final t in businessHubTemplates) {
        if (t.elements.length < 3) {
          issues.add('${t.id}: only ${t.elements.length} elements');
        }
        final hasBrandToken = t.elements.any(
          (e) =>
              (e.text ?? '').contains('{{BUSINESS}}') ||
              (e.text ?? '').contains('{{PHONE}}') ||
              (e.text ?? '').contains('{{WHATSAPP}}'),
        );
        if (!hasBrandToken && t.category != 'collage') {
          issues.add('${t.id}: no brand variable tokens');
        }
      }
      expect(issues, isEmpty, reason: issues.join('\n'));
    });

    test('todays ads builds valid entries from sample catalog', () {
      final entries = buildTodaysAds(
        items: const [],
        services: const [],
        kit: const BrandKit(businessName: 'Sanaa Media', phone: '0706121211'),
      );
      expect(entries, isNotEmpty);
      for (final e in entries) {
        expect(e.template.elements, isNotEmpty);
        expect(e.template.name, isNotEmpty);
        expect(e.caption, isNotEmpty);
      }
    });

    test('daily product ads never apply an unrelated industry campaign', () {
      final item = Item(
        id: 'office-product',
        name: 'Thermal Mini Printer',
        price: 120000,
        stockEnabled: true,
        stockQty: 12,
        publishedOnline: true,
        categoryName: 'Office Equipment',
        minPurchaseQty: 1,
        refundable: false,
        cashOnDelivery: true,
        updatedAt: DateTime(2026, 7, 30),
        synced: true,
      );

      for (var seed = 0; seed < 40; seed++) {
        final package = buildSmartAds(
          items: [item],
          services: const [],
          kit: const BrandKit(businessName: 'Sanaa Media'),
          daySeed: seed,
        ).first;
        final copy = package.template.elements
            .map((element) => element.text ?? '')
            .join(' ')
            .toUpperCase();
        expect(copy, isNot(contains('FOOD SPECIAL')));
        expect(copy, isNot(contains('FASHION EDIT')));
      }
    });

    test('daily offer captions use each offer, never the shop description', () {
      final first = Item(
        id: 'first',
        remoteId: 2684,
        name: 'Id Card Holder',
        description: 'Durable holder with a clear protective face.',
        price: 12000,
        stockEnabled: true,
        stockQty: 12,
        publishedOnline: true,
        minPurchaseQty: 1,
        refundable: false,
        cashOnDelivery: true,
        updatedAt: DateTime(2026, 7, 30),
        synced: true,
      );
      final second = Item(
        id: 'second',
        remoteId: 2682,
        name: 'Thermal Mini Printer',
        description: 'Compact receipt printer for a busy counter.',
        price: 120000,
        stockEnabled: true,
        stockQty: 6,
        publishedOnline: true,
        minPurchaseQty: 1,
        refundable: false,
        cashOnDelivery: true,
        updatedAt: DateTime(2026, 7, 29),
        synced: true,
      );
      const shopDescription =
          'Generic shop description must never lead an offer.';
      final packages = buildSmartAds(
        items: [first, second],
        services: const [],
        kit: const BrandKit(
          businessName: 'Sanaa Media',
          tagline: shopDescription,
        ),
        daySeed: 4,
      ).where((ad) => ad.source == SmartAdSource.product).toList();

      final firstCaption =
          packages[0].captions[CaptionPlatform.whatsapp]!.fullText;
      final secondCaption =
          packages[1].captions[CaptionPlatform.whatsapp]!.fullText;
      expect(firstCaption, contains('Id Card Holder'));
      expect(firstCaption, contains('Durable holder'));
      expect(firstCaption, contains('https://www.soko24.co/p/2684'));
      expect(firstCaption, isNot(contains(shopDescription)));
      expect(secondCaption, contains('Thermal Mini Printer'));
      expect(secondCaption, contains('Compact receipt printer'));
      expect(secondCaption, contains('https://www.soko24.co/p/2682'));
      expect(secondCaption, isNot(contains(shopDescription)));
      expect(firstCaption, isNot(equals(secondCaption)));
    });

    test('no duplicate template ids in catalog', () {
      final ids = allStudioTemplates.map((t) => t.id).toList();
      final seen = <String>{};
      final dupes = <String>[];
      for (final id in ids) {
        if (!seen.add(id)) dupes.add(id);
      }
      expect(dupes, isEmpty, reason: 'Duplicate ids: $dupes');
    });

    test('catalog has minimum template volume', () {
      expect(allStudioTemplates.length, greaterThanOrEqualTo(200));
      expect(builtInTemplates.length, greaterThanOrEqualTo(180));
      expect(businessHubTemplates.length, greaterThanOrEqualTo(14));
    });
  });
}

// Expose private pools from studio_todays_ads for audit — mirror the lists.
const _productTemplateIds = [
  'tpl_sale_bold',
  'tpl_whatsapp',
  'tpl_new_arrival',
  'tpl_promo',
  'tpl_story',
  'tpl_minimal',
  'gen_hero_sale_pin',
  'gen_story_food_sq',
  'gen_badge_fashion_story',
  'tpl_catalog',
];

const _serviceTemplateIds = [
  'tpl_booking',
  'hub_service_flyer',
  'gen_hero_service_sq',
  'gen_minimal_service_a6',
  'tpl_professional',
  'hub_brochure_cover',
];
