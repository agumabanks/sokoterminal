import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

/// Studio appearance — monochrome keeps focus on the seller's work.
enum StudioAppearance {
  monochromeLight,
  monochromeDark,
  studioDark,
}

extension StudioAppearanceLabel on StudioAppearance {
  String get label => switch (this) {
        StudioAppearance.monochromeLight => 'Monochrome Light',
        StudioAppearance.monochromeDark => 'Monochrome Dark',
        StudioAppearance.studioDark => 'Studio Dark',
      };

  String get subtitle => switch (this) {
        StudioAppearance.monochromeLight =>
          'Clean book-like canvas — focus on your brand',
        StudioAppearance.monochromeDark =>
          'Dark editorial — minimal distraction',
        StudioAppearance.studioDark => 'Classic Soko Studio green accent',
      };
}

class StudioThemeData {
  const StudioThemeData({
    required this.appearance,
    required this.scaffold,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentMuted,
    required this.border,
    required this.heroGradient,
    required this.isMonochrome,
  });

  final StudioAppearance appearance;
  final Color scaffold;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentMuted;
  final Color border;
  final List<Color> heroGradient;
  final bool isMonochrome;

  static StudioThemeData forAppearance(StudioAppearance a) => switch (a) {
        StudioAppearance.monochromeLight => const StudioThemeData(
              appearance: StudioAppearance.monochromeLight,
              scaffold: DesignTokens.canvasCloud,
              surface: DesignTokens.canvas,
              surfaceElevated: Color(0xFFF4F4F5),
              textPrimary: Color(0xFF09090B),
              textSecondary: Color(0xFF3F3F46),
              textMuted: Color(0xFF71717A),
              accent: Color(0xFF09090B),
              accentMuted: Color(0xFFE4E4E7),
              border: Color(0xFFE4E4E7),
              heroGradient: [Color(0xFFF4F4F5), DesignTokens.canvasCloud, DesignTokens.canvas],
              isMonochrome: true,
            ),
        StudioAppearance.monochromeDark => const StudioThemeData(
              appearance: StudioAppearance.monochromeDark,
              scaffold: Color(0xFF09090B),
              surface: Color(0xFF18181B),
              surfaceElevated: Color(0xFF27272A),
              textPrimary: DesignTokens.canvasCloud,
              textSecondary: Color(0xFFD4D4D8),
              textMuted: Color(0xFF71717A),
              accent: DesignTokens.canvasCloud,
              accentMuted: Color(0xFF3F3F46),
              border: Color(0xFF3F3F46),
              heroGradient: [Color(0xFF18181B), Color(0xFF09090B), DesignTokens.brandPrimary],
              isMonochrome: true,
            ),
        StudioAppearance.studioDark => const StudioThemeData(
              appearance: StudioAppearance.studioDark,
              scaffold: DesignTokens.brandPrimary,
              surface: DesignTokens.brandPrimary,
              surfaceElevated: DesignTokens.brandPrimary,
              textPrimary: DesignTokens.canvas,
              textSecondary: Color(0xB3FFFFFF),
              textMuted: Color(0x66FFFFFF),
              accent: DesignTokens.brandAccent,
              accentMuted: Color(0x330EBE7E),
              border: Color(0x14FFFFFF),
              heroGradient: [DesignTokens.brandPrimary, DesignTokens.brandPrimary, DesignTokens.brandPrimary],
              isMonochrome: false,
            ),
      };
}

final studioAppearanceProvider =
    StateNotifierProvider<StudioAppearanceNotifier, StudioAppearance>((ref) {
  return StudioAppearanceNotifier(ref.read(sharedPreferencesProvider));
});

final studioThemeProvider = Provider<StudioThemeData>((ref) {
  return StudioThemeData.forAppearance(ref.watch(studioAppearanceProvider));
});

class StudioAppearanceNotifier extends StateNotifier<StudioAppearance> {
  StudioAppearanceNotifier(this._prefs)
      : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'studio_appearance_v1';

  static StudioAppearance _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    return StudioAppearance.values.firstWhere(
      (a) => a.name == raw,
      orElse: () => StudioAppearance.monochromeLight,
    );
  }

  Future<void> setAppearance(StudioAppearance value) async {
    state = value;
    await _prefs.setString(_key, value.name);
  }
}

/// Premium fade + slide transition for studio routes.
Route<T> studioPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}