import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/ads/business_hub_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_template_discovery.dart';

void main() {
  test('local discovery fallback resolves known template ids', () {
    final sections = localTemplateDiscoveryFallback();
    expect(sections, isNotEmpty);

    for (final section in sections) {
      expect(section.title, isNotEmpty);
      for (final id in section.templateIds) {
        expect(templateById(id), isNotNull, reason: 'Missing template $id');
      }
    }
  });

  test('business hub section includes all hub templates', () {
    final hub = localTemplateDiscoveryFallback()
        .firstWhere((s) => s.id == 'business_hub');
    expect(
      hub.templateIds.length,
      greaterThanOrEqualTo(businessHubTemplates.length),
    );
  });
}