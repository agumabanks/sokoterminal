import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';

/// Keys used to persist Studio onboarding state in SharedPreferences.
abstract class _StudioOnboardingKeys {
  static const String hasSeenStudioSplash = 'has_seen_studio_splash_v1';
  static const String hasSeenStudioOnboarding = 'has_seen_studio_onboarding_v1';
  static const String hasSeenStudioEditorHint = 'has_seen_studio_editor_hint_v1';
}

/// Whether the cinematic Studio splash has already been shown.
final hasSeenStudioSplashProvider =
    StateNotifierProvider<StudioOnboardingFlagNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StudioOnboardingFlagNotifier(
    prefs: prefs,
    key: _StudioOnboardingKeys.hasSeenStudioSplash,
  );
});

/// Whether the Studio hub coach-mark onboarding has been completed.
final hasSeenStudioOnboardingProvider =
    StateNotifierProvider<StudioOnboardingFlagNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StudioOnboardingFlagNotifier(
    prefs: prefs,
    key: _StudioOnboardingKeys.hasSeenStudioOnboarding,
  );
});

/// Whether the editor first-run hint overlay has been dismissed.
final hasSeenStudioEditorHintProvider =
    StateNotifierProvider<StudioOnboardingFlagNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StudioOnboardingFlagNotifier(
    prefs: prefs,
    key: _StudioOnboardingKeys.hasSeenStudioEditorHint,
  );
});

/// Simple persisted boolean flag backed by [SharedPreferences].
class StudioOnboardingFlagNotifier extends StateNotifier<bool> {
  StudioOnboardingFlagNotifier({
    required this.prefs,
    required this.key,
  }) : super(prefs.getBool(key) ?? false);

  final SharedPreferences prefs;
  final String key;

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await prefs.setBool(key, true);
  }

  /// Test helper to reset the flag.
  Future<void> reset() async {
    await prefs.setBool(key, false);
    state = false;
  }
}
