import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soko Seller Terminal — Design System V4
///
/// Synthesis of Apple (photography-first, SF-Pro negative letter-spacing,
/// single quiet accent) × Nike (pill geometry everywhere, near-monochrome
/// chrome, editorial kinetic energy) — expressed as a B2B POS tool where
/// clarity = trust and speed = delight.
///
/// Rules:
///   • Brand teal (#0EBE7E) is the ONLY CTA color — treat it like Nike black.
///   • Premium black (#000000) lives on AppBars, headers, and dark surfaces only.
///   • Everything else: ink + canvas + cloud. No decorative gradients, ever.
///   • Pill radius for all buttons (full = 999). Card radius 14px (Apple lg).
///   • Negative letter-spacing on display + headline (Apple feel).
///   • Monospaced tabular figures for all financial amounts.
///   • Shadows only under bottom bars and modals — zero shadow on cards.
class DesignTokens {
  DesignTokens._();

  // ─── BRAND ────────────────────────────────────────────────────────────────
  // Premium monochrome black + teal accent. Primary black is reserved for
  // AppBars, headers, and high-contrast chrome; teal is reserved for CTAs.
  static const Color brandPrimary = Color(0xFF000000); // premium black — AppBar, dark surfaces
  static const Color brandAccent  = Color(0xFF0EBE7E); // teal — every CTA

  // Derived tints (backgrounds only — never on text unless disabled state)
  static const Color brandAccentSubtle = Color(0xFFE8FBF3); // 5% green tint bg
  static const Color brandAccentLight  = Color(0xFFE8FBF3); // alias for backward compat
  static const Color brandAccentDim    = Color(0x1A0EBE7E); // 10% alpha — selected chip bg

  // ─── CANVAS ───────────────────────────────────────────────────────────────
  // Clean monochrome: pure white surfaces, warm gray section backgrounds.
  static const Color canvas         = Color(0xFFFFFFFF); // pure surface
  static const Color canvasParchment = Color(0xFFF7F7F7); // section backgrounds
  static const Color canvasCloud     = Color(0xFFF0F0F0); // card image bg, chip bg

  // Legacy aliases — kept for backward compat with existing widget refs
  static const Color surface         = canvasParchment;
  static const Color surfaceWhite    = canvas;
  static const Color surfaceRaised   = canvas;
  static const Color surfaceCard     = canvas;
  static const Color surfaceElevated = canvas;
  static const Color surfaceElevated2 = canvasCloud;
  static const Color surfaceTint      = canvasParchment;
  static const Color surfaceGrouped   = canvasParchment;

  // ─── INK ──────────────────────────────────────────────────────────────────
  // Pure black ink for primary text and monochrome CTA on light surfaces.
  static const Color ink          = Color(0xFF000000); // primary text / dark CTA
  static const Color inkSubtle    = Color(0xFF3C3C43); // secondary text
  static const Color inkMuted     = Color(0xFF6E6E73); // tertiary — metadata, captions
  static const Color inkDisabled  = Color(0xFFAEAEB2); // disabled / placeholder

  // Legacy gray aliases
  static const Color textPrimary   = ink;
  static const Color textSecondary = inkSubtle;
  static const Color textTertiary  = inkMuted;
  static const Color grayDark      = inkSubtle;
  static const Color grayMedium    = inkMuted;
  static const Color grayLight     = Color(0xFFE5E5EA); // dividers, borders

  // ─── DIVIDERS ─────────────────────────────────────────────────────────────
  static const Color hairline     = Color(0xFFE5E5EA); // 1px cell dividers (Nike hairline)
  static const Color hairlineSoft = Color(0xFFF0F0F0); // inset shadows, tab strip underline
  static const Color dividerSolid = Color(0xFFC6C6C8); // stronger dividers

  // Tab bar
  static const Color tabBarBackground = canvas;
  static const Color tabBarBorder     = hairline;

  // ─── SEMANTIC ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF007D48); // Nike success green
  static const Color successBright = Color(0xFF0EBE7E); // same as brandAccent
  static const Color warning = Color(0xFFFF9500); // iOS amber
  static const Color error   = Color(0xFFD30005); // Nike sale red
  static const Color info    = Color(0xFF0066CC); // Apple action blue

  // ─── TYPOGRAPHY ───────────────────────────────────────────────────────────
  // Inter as a system-ui proxy for SF Pro. Negative letter-spacing at display
  // sizes mirrors Apple's "tight headline" signature.

  /// Hero numbers — dashboard totals, receipt amounts
  static TextStyle get textDisplay => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: ink,
    letterSpacing: -0.8,
    height: 1.06,
  );

  /// Page titles, modal headers
  static TextStyle get textHeadline => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: ink,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Section headers, card titles
  static TextStyle get textTitle => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: ink,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Primary body — list items, descriptions
  static TextStyle get textBody => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: inkSubtle,
    letterSpacing: -0.1,
    height: 1.5,
  );

  /// Secondary labels, metadata
  static TextStyle get textSmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: inkMuted,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Badges, timestamps, micro-copy
  static TextStyle get textCaption => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: inkMuted,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Financial amounts — tabular, monospaced, trustworthy
  static TextStyle get textMono => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
    letterSpacing: 0,
    height: 1.25,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Large financial display — receipt total, dashboard hero
  static TextStyle get textMonoDisplay => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: ink,
    letterSpacing: -0.5,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Semantic variants — generated from base styles
  static TextStyle get textTitleLight    => textTitle.copyWith(color: canvas);
  static TextStyle get textBodyLight     => textBody.copyWith(color: canvas);
  static TextStyle get textSmallLight    => textSmall.copyWith(color: canvas.withValues(alpha: 0.8));
  static TextStyle get textTitleMedium   => textTitle.copyWith(fontSize: 15, fontWeight: FontWeight.w600);
  static TextStyle get textBodyBold      => textBody.copyWith(fontWeight: FontWeight.w600, color: ink);
  static TextStyle get textSmallBold     => textSmall.copyWith(fontWeight: FontWeight.w600, color: inkSubtle);
  static TextStyle get textBodyMuted     => textBody.copyWith(color: inkMuted);

  // ─── SPACING — strict 8pt grid ────────────────────────────────────────────
  static const double spaceXxs = 2;
  static const double spaceXs  = 4;
  static const double spaceSm  = 8;
  static const double spaceMd  = 16;
  static const double spaceLg  = 24;
  static const double spaceXl  = 32;
  static const double spaceXxl = 48;
  static const double spaceXxl2 = 64;

  static const EdgeInsets paddingXs   = EdgeInsets.all(spaceXs);
  static const EdgeInsets paddingSm   = EdgeInsets.all(spaceSm);
  static const EdgeInsets paddingMd   = EdgeInsets.all(spaceMd);
  static const EdgeInsets paddingLg   = EdgeInsets.all(spaceLg);
  static const EdgeInsets paddingCard = EdgeInsets.all(20);

  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: spaceMd);
  static const EdgeInsets paddingVerticalSm   = EdgeInsets.symmetric(vertical: spaceSm);
  static const EdgeInsets paddingScreen       = EdgeInsets.all(spaceMd);
  static const EdgeInsets paddingPage         = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  // ─── RADII ────────────────────────────────────────────────────────────────
  // Nike: pill for all buttons. Apple: 14-18px for utility cards.
  static const double radiusXs   = 6;
  static const double radiusSm   = 10;
  static const double radiusMd   = 14;  // utility cards (Apple)
  static const double radiusLg   = 18;  // section cards, modals
  static const double radiusXl   = 24;  // bottom sheets
  static const double radiusFull = 999; // pills — every CTA button

  static const BorderRadius borderRadiusXs   = BorderRadius.all(Radius.circular(radiusXs));
  static const BorderRadius borderRadiusSm   = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd   = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg   = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl   = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));
  static const BorderRadius borderRadiusBottomSheet = BorderRadius.vertical(top: Radius.circular(radiusXl));

  // ─── SHADOWS ──────────────────────────────────────────────────────────────
  // Nike: shadows only where they signal floating — bottom bars, modals.
  // Zero shadow on card chrome (Apple: product imagery casts the shadow).

  /// Bottom bar / sticky header lift
  static List<BoxShadow> get shadowBar => [
    BoxShadow(color: const Color(0x0C000000), blurRadius: 12, offset: const Offset(0, -2)),
    BoxShadow(color: const Color(0x06000000), blurRadius: 1,  offset: const Offset(0, -1)),
  ];

  /// Modal / bottom sheet
  static List<BoxShadow> get shadowModal => [
    BoxShadow(color: const Color(0x18000000), blurRadius: 32, offset: const Offset(0, -8)),
  ];

  /// Legacy aliases
  static List<BoxShadow> get shadowSm  => shadowBar;
  static List<BoxShadow> get shadowMd  => shadowModal;
  static List<BoxShadow> get shadowLg  => shadowModal;

  // ─── GRADIENTS ────────────────────────────────────────────────────────────
  // Reserved for photo overlays only. Never on chrome.
  static const LinearGradient photoScrimBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x80000000)],
  );

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

  // ─── ANIMATION ────────────────────────────────────────────────────────────
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEnter    = Curves.easeOutQuart;
  static const Curve curveExit     = Curves.easeInCubic;
  static const Curve curveSpring   = Curves.elasticOut;

  static const Duration durationFast           = Duration(milliseconds: 120);
  static const Duration durationNormal         = Duration(milliseconds: 220);
  static const Duration durationSlow           = Duration(milliseconds: 350);
  static const Duration durationPage           = Duration(milliseconds: 400);
  static const Duration durationPageTransition = Duration(milliseconds: 350);

  // ─── ICON SIZES ───────────────────────────────────────────────────────────
  static const double iconSm = 16;
  static const double iconMd = 22;
  static const double iconLg = 32;
  static const double iconXl = 48;
}

extension DesignTokensExtension on BuildContext {
  DesignTokens get tokens => DesignTokens._();
}
