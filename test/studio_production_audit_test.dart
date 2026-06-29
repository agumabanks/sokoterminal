import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/ads/ad_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/brand_kit_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/business_hub_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_template_discovery.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_todays_ads.dart';

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
      expect(generatedTemplateId('badge', 'fashion'), 'gen_badge_fashion_story');
      expect(generatedTemplateId('hero', 'service'), 'gen_hero_service_sq');
      expect(generatedTemplateId('minimal', 'service'), 'gen_minimal_service_a6');
    });

    test('todays ads template pool ids all exist', () {
      const pool = [
        ..._productTemplateIds,
        ..._serviceTemplateIds,
      ];
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
          (e) => (e.text ?? '').contains('{{BUSINESS}}') ||
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