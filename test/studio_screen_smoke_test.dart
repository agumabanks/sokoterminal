import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/ads/ad_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/brand_kit_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/business_hub_templates.dart';
import 'package:soko_seller_terminal/src/features/ads/graphics_workspace.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_theme.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_todays_ads.dart';

void main() {
  group('Studio screen smoke', () {
    testWidgets('GraphicsWorkspace renders hub header and quick start', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioThemeProvider.overrideWithValue(
              StudioThemeData.forAppearance(StudioAppearance.monochromeLight),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: GraphicsWorkspace(
                kit: const BrandKit(businessName: 'Sanaa Media'),
                selectedItem: null,
                onEditTemplate: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Business Hub'), findsOneWidget);
      expect(find.text('Quick start'), findsOneWidget);
    });

    test('buildTodaysAds entries have non-empty canvas elements', () {
      final entries = buildTodaysAds(
        items: const [],
        services: const [],
        kit: const BrandKit(
          businessName: 'Kampala Crafts',
          phone: '0700123456',
          whatsapp: '0700123456',
        ),
      );
      expect(entries, isNotEmpty);
      for (final entry in entries) {
        expect(entry.template.elements, isNotEmpty);
        expect(entry.caption, isNotEmpty);
      }
    });

    test('studio appearance presets include monochrome light default path', () {
      final light = StudioThemeData.forAppearance(StudioAppearance.monochromeLight);
      final dark = StudioThemeData.forAppearance(StudioAppearance.monochromeDark);
      expect(light.isMonochrome, isTrue);
      expect(dark.isMonochrome, isTrue);
      expect(allStudioTemplates.length, greaterThanOrEqualTo(200));
    });
  });
}