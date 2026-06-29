import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_onboarding_overlay.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_onboarding_prefs.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_splash.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_theme.dart';

void main() {
  group('Studio onboarding', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('splash flag persists across reads', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(hasSeenStudioSplashProvider), isFalse);

      await container.read(hasSeenStudioSplashProvider.notifier).markSeen();

      expect(container.read(hasSeenStudioSplashProvider), isTrue);
      expect(prefs.getBool('has_seen_studio_splash_v1'), isTrue);
    });

    testWidgets('StudioSplashScreen reports ready and can mark flag seen',
        (tester) async {
      var ready = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: StudioSplashScreen(
              onReady: () => ready = true,
            ),
          ),
        ),
      );

      expect(find.byType(StudioSplashScreen), findsOneWidget);
      expect(find.text('SOKO STUDIO'), findsOneWidget);

      // The splash sequence is ~6 s of chained animations/delays.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(ready, isTrue);
    });

    test('onboarding and editor-hint flags persist', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(hasSeenStudioOnboardingProvider), isFalse);
      expect(container.read(hasSeenStudioEditorHintProvider), isFalse);

      await container
          .read(hasSeenStudioOnboardingProvider.notifier)
          .markSeen();
      await container
          .read(hasSeenStudioEditorHintProvider.notifier)
          .markSeen();

      expect(container.read(hasSeenStudioOnboardingProvider), isTrue);
      expect(container.read(hasSeenStudioEditorHintProvider), isTrue);
    });

    testWidgets('coach-mark overlay renders and advances', (tester) async {
      final theme =
          StudioThemeData.forAppearance(StudioAppearance.monochromeLight);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            studioThemeProvider.overrideWithValue(theme),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudioOnboardingOverlay()),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Switch Studio modes'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap through the four steps.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Switch Studio modes'), findsNothing);
      expect(prefs.getBool('has_seen_studio_onboarding_v1'), isTrue);
    });

    testWidgets('coach-mark overlay can be dismissed by tapping scrim',
        (tester) async {
      final theme =
          StudioThemeData.forAppearance(StudioAppearance.monochromeLight);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            studioThemeProvider.overrideWithValue(theme),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudioOnboardingOverlay()),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Switch Studio modes'), findsOneWidget);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(find.text('Switch Studio modes'), findsNothing);
      expect(prefs.getBool('has_seen_studio_onboarding_v1'), isTrue);
    });
  });
}
