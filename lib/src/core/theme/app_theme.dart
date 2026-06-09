import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Soko Seller Terminal Theme V4
/// Apple × Nike design language applied to a B2B POS.
///
/// Rules carried from the design system:
///   • Pill geometry (radiusFull) on every CTA button.
///   • brandAccent is the ONLY CTA background — never brandPrimary.
///   • Zero elevation on cards — no card shadow, no fill-color drift.
///   • Bottom bars and modals get shadowBar / shadowModal.
///   • Typography uses Inter with negative letter-spacing on headlines.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      // ─── Color Scheme ───────────────────────────────────────────────────
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.brandAccent,
        primary: DesignTokens.brandAccent,
        secondary: DesignTokens.brandPrimary,
        surface: DesignTokens.canvas,
        error: DesignTokens.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DesignTokens.ink,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: DesignTokens.canvasParchment,

      // ─── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: DesignTokens.canvas,
        foregroundColor: DesignTokens.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: DesignTokens.textTitle,
        iconTheme: const IconThemeData(color: DesignTokens.ink, size: 22),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ─── Navigation Bar (M3) ────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.canvas,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: DesignTokens.brandAccentDim,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return DesignTokens.textCaption.copyWith(
            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
            color: on ? DesignTokens.brandAccent : DesignTokens.inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return IconThemeData(
            color: on ? DesignTokens.brandAccent : DesignTokens.inkMuted,
            size: 22,
          );
        }),
        height: 64,
      ),

      // ─── Bottom Nav Bar (legacy) ─────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: DesignTokens.canvas,
        selectedItemColor: DesignTokens.brandAccent,
        unselectedItemColor: DesignTokens.inkMuted,
        selectedLabelStyle: DesignTokens.textCaption.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: DesignTokens.textCaption,
        showUnselectedLabels: true,
        elevation: 0,
      ),

      // ─── Cards ──────────────────────────────────────────────────────────
      // Zero elevation, zero shadow — the product photo carries the weight.
      cardTheme: CardThemeData(
        elevation: 0,
        color: DesignTokens.canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          side: BorderSide(color: DesignTokens.hairline, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Buttons ────────────────────────────────────────────────
      // Pill shape, brandAccent fill — Nike primary CTA grammar.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.brandAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DesignTokens.hairline,
          disabledForegroundColor: DesignTokens.inkDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: DesignTokens.textBody.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0,
          ),
          minimumSize: const Size(0, 48),
        ),
      ),

      // ─── Outlined Buttons ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.ink,
          side: const BorderSide(color: DesignTokens.hairline, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w500),
          minimumSize: const Size(0, 44),
        ),
      ),

      // ─── Text Buttons ────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.brandAccent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),

      // ─── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: DesignTokens.brandAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),

      // ─── Chips ───────────────────────────────────────────────────────────
      // Nike filter-chip grammar: pill shape, soft-cloud bg, ink → accent when active.
      chipTheme: ChipThemeData(
        backgroundColor: DesignTokens.canvasCloud,
        selectedColor: DesignTokens.brandAccentDim,
        disabledColor: DesignTokens.hairline,
        labelStyle: DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w500),
        secondaryLabelStyle: DesignTokens.textSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: DesignTokens.brandAccent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
        showCheckmark: false,
      ),

      // ─── Input Decoration ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.canvasCloud,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.brandAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.error, width: 1.5),
        ),
        labelStyle: DesignTokens.textBody.copyWith(color: DesignTokens.inkMuted),
        hintStyle: DesignTokens.textBody.copyWith(color: DesignTokens.inkDisabled),
        prefixIconColor: DesignTokens.inkMuted,
        suffixIconColor: DesignTokens.inkMuted,
        errorStyle: DesignTokens.textCaption.copyWith(color: DesignTokens.error),
      ),

      // ─── Switch ──────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? DesignTokens.brandAccent : DesignTokens.hairline),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ─── Checkbox ────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? DesignTokens.brandAccent : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: DesignTokens.hairline, width: 1.5),
      ),

      // ─── Tab Bar ─────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: DesignTokens.brandAccent,
        unselectedLabelColor: DesignTokens.inkMuted,
        indicatorColor: DesignTokens.brandAccent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: DesignTokens.hairline,
        labelStyle: DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: DesignTokens.textSmall,
      ),

      // ─── Bottom Sheet ────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusBottomSheet,
        ),
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: DesignTokens.hairline,
      ),

      // ─── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: DesignTokens.canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusLg,
        ),
        elevation: 0,
        titleTextStyle: DesignTokens.textTitle,
        contentTextStyle: DesignTokens.textBody,
      ),

      // ─── Snackbar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DesignTokens.ink,
        contentTextStyle: DesignTokens.textSmall.copyWith(color: Colors.white),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),

      // ─── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        thickness: 0.5,
        color: DesignTokens.hairline,
        space: 0.5,
      ),

      // ─── List Tile ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: DesignTokens.textBody.copyWith(color: DesignTokens.ink),
        subtitleTextStyle: DesignTokens.textSmall,
        iconColor: DesignTokens.inkMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
      ),

      // ─── Tooltip ─────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: DesignTokens.ink.withValues(alpha: 0.92),
          borderRadius: DesignTokens.borderRadiusSm,
        ),
        textStyle: DesignTokens.textCaption.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // ─── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DesignTokens.brandAccent,
        linearTrackColor: DesignTokens.hairline,
        circularTrackColor: DesignTokens.hairline,
      ),

      // ─── Segmented Button ────────────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: DesignTokens.canvasCloud,
          foregroundColor: DesignTokens.inkMuted,
          selectedBackgroundColor: DesignTokens.brandAccent,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: DesignTokens.hairline, width: 0.5),
          shape: const StadiumBorder(),
          textStyle: DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // ─── Text Theme ──────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:  baseTextTheme.displayLarge?.copyWith(color: DesignTokens.ink, fontWeight: FontWeight.w700, letterSpacing: -1),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: DesignTokens.ink, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        displaySmall:  baseTextTheme.displaySmall?.copyWith(color: DesignTokens.ink, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge:  DesignTokens.textHeadline.copyWith(fontSize: 24),
        headlineMedium: DesignTokens.textHeadline,
        headlineSmall:  DesignTokens.textTitle.copyWith(fontSize: 19),
        titleLarge:   DesignTokens.textTitle,
        titleMedium:  DesignTokens.textBodyBold,
        titleSmall:   DesignTokens.textSmallBold,
        bodyLarge:    DesignTokens.textBody.copyWith(fontSize: 17, color: DesignTokens.ink),
        bodyMedium:   DesignTokens.textBody,
        bodySmall:    DesignTokens.textSmall,
        labelLarge:   DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600),
        labelMedium:  DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w500),
        labelSmall:   DesignTokens.textCaption,
      ),
    );
  }
}
