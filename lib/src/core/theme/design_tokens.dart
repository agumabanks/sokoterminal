import 'package:flutter/material.dart';

/// Soko Seller Terminal Design System
/// 
/// This file defines all design tokens following strict constraints:
/// - 8pt grid for all spacing
/// - Only 3 font sizes
/// - Only 3 gray shades + brand colors
/// 
/// "Steve Jobs standard" - premium, minimal, consistent.

class DesignTokens {
  DesignTokens._();

  // ─────────────────────────────────────────────────────────────────────────
  // COLORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Brand colors
  static const Color brandPrimary = Color(0xFF0F1D40);
  static const Color brandAccent = Color(0xFF0EBE7E);
  static const Color brandAccentLight = Color(0xFFE8FBF3);

  /// Only 3 grays in the entire app
  static const Color grayDark = Color(0xFF2D3748);
  static const Color grayMedium = Color(0xFF718096);
  static const Color grayLight = Color(0xFFE2E8F0);

  /// Surface colors
  static const Color surface = Color(0xFFF6F7FB);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Semantic colors
  static const Color success = Color(0xFF0EBE7E);
  static const Color warning = Color(0xFFF6AD55);
  static const Color error = Color(0xFFE53E3E);
  static const Color info = Color(0xFF4299E1);

  /// Gradient for premium effects
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandAccent],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EBE7E), Color(0xFF0A9665)],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TYPOGRAPHY - Only 3 sizes
  // ─────────────────────────────────────────────────────────────────────────

  /// Title: 20-22px, bold
  static const TextStyle textTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: grayDark,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Body: 15-16px, regular
  static const TextStyle textBody = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: grayDark,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Small: 12-13px, regular
  static const TextStyle textSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: grayMedium,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Variants
  static TextStyle get textTitleLight => textTitle.copyWith(color: surfaceWhite);
  static TextStyle get textBodyLight => textBody.copyWith(color: surfaceWhite);
  static TextStyle get textSmallLight => textSmall.copyWith(color: surfaceWhite.withOpacity(0.8));

  static TextStyle get textTitleMedium => textTitle.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get textBodyBold => textBody.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get textSmallBold => textSmall.copyWith(fontWeight: FontWeight.w600);

  static TextStyle get textBodyMuted => textBody.copyWith(color: grayMedium);

  // ─────────────────────────────────────────────────────────────────────────
  // SPACING - 8pt grid
  // ─────────────────────────────────────────────────────────────────────────

  static const double spaceXxs = 2;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;

  /// Common edge insets
  static const EdgeInsets paddingXs = EdgeInsets.all(spaceXs);
  static const EdgeInsets paddingSm = EdgeInsets.all(spaceSm);
  static const EdgeInsets paddingMd = EdgeInsets.all(spaceMd);
  static const EdgeInsets paddingLg = EdgeInsets.all(spaceLg);

  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: spaceMd);
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: spaceSm);

  static const EdgeInsets paddingScreen = EdgeInsets.all(spaceMd);

  // ─────────────────────────────────────────────────────────────────────────
  // RADII
  // ─────────────────────────────────────────────────────────────────────────

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));

  /// Bottom sheet uses top-only radius
  static const BorderRadius borderRadiusBottomSheet = BorderRadius.vertical(
    top: Radius.circular(radiusXl),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SHADOWS
  // ─────────────────────────────────────────────────────────────────────────

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: grayDark.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: grayDark.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: grayDark.withOpacity(0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // ANIMATION DURATIONS
  // ─────────────────────────────────────────────────────────────────────────

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ─────────────────────────────────────────────────────────────────────────
  // ICON SIZES
  // ─────────────────────────────────────────────────────────────────────────

  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
}

/// Extension for quick access to design tokens via context
extension DesignTokensExtension on BuildContext {
  DesignTokens get tokens => DesignTokens._();
}
