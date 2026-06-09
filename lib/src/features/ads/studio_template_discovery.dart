import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import 'ad_templates.dart';
import 'business_hub_config.dart';
import 'business_hub_templates.dart';

/// A curated row of templates from the backend catalog.
class TemplateDiscoverySection {
  const TemplateDiscoverySection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.templateIds,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> templateIds;

  List<AdTemplate> resolveTemplates() => templateIds
      .map(templateById)
      .whereType<AdTemplate>()
      .toList();

  factory TemplateDiscoverySection.fromJson(Map<String, dynamic> j) =>
      TemplateDiscoverySection(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        subtitle: j['subtitle']?.toString() ?? '',
        templateIds: (j['template_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// Offline fallback when catalog API is unreachable.
List<TemplateDiscoverySection> localTemplateDiscoveryFallback() {
  return templateDiscoverySections.map((meta) {
    final ids = switch (meta.id) {
      'todays_ads' => [
          'tpl_whatsapp',
          'tpl_sale_bold',
          'tpl_story',
          'gen_hero_sale_sq_1',
        ],
      'top_picks' => [
          'hub_logo_monogram',
          'hub_menu_classic',
          'hub_invoice_a4',
          'tpl_sale_bold',
          'tpl_story',
          'hub_business_card',
        ],
      'popular' => [
          'tpl_whatsapp',
          'tpl_promo',
          'hub_event_flyer',
          'hub_service_flyer',
          'tpl_new_arrival',
        ],
      'for_you' => [
          'hub_collage_grid',
          'tpl_minimal',
          'hub_brochure_cover',
          'tpl_booking',
        ],
      'business_hub' => businessHubTemplates.map((t) => t.id).toList(),
      'browse_all' => builtInTemplates
          .where((t) => t.category != 'blank' && t.category != 'photo')
          .map((t) => t.id)
          .take(48)
          .toList(),
      _ => <String>[],
    };
    return TemplateDiscoverySection(
      id: meta.id,
      title: meta.title,
      subtitle: meta.subtitle,
      templateIds: ids,
    );
  }).toList();
}

final templateDiscoveryProvider =
    FutureProvider.autoDispose<List<TemplateDiscoverySection>>((ref) async {
  final api = ref.watch(sellerApiProvider);
  try {
    final res = await api.fetchStudioCatalog();
    final body = res.data;
    if (body is Map && body['success'] == true && body['sections'] is List) {
      return (body['sections'] as List)
          .whereType<Map>()
          .map((m) => TemplateDiscoverySection.fromJson(
                Map<String, dynamic>.from(m),
              ))
          .where((s) => s.templateIds.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return localTemplateDiscoveryFallback();
});

final templateUseRecorderProvider = Provider<TemplateUseRecorder>((ref) {
  return TemplateUseRecorder(ref.read(sellerApiProvider));
});

class TemplateUseRecorder {
  TemplateUseRecorder(this._api);

  final SellerApi _api;

  Future<void> record(String templateId) async {
    try {
      await _api.recordStudioTemplateUse(templateId);
    } catch (_) {}
  }
}