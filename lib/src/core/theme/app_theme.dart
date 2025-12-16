import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Soko Seller Terminal Theme
/// 
/// Premium theme following "Steve Jobs standard" design principles:
/// - Clean, minimal aesthetics
/// - Consistent spacing (8pt grid)
/// - Limited color palette
/// - Refined typography
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.brandPrimary,
        primary: DesignTokens.brandPrimary,
        secondary: DesignTokens.brandAccent,
        surface: DesignTokens.surface,
        background: DesignTokens.surface,
        error: DesignTokens.error,
        onPrimary: DesignTokens.surfaceWhite,
        onSecondary: DesignTokens.surfaceWhite,
        onSurface: DesignTokens.grayDark,
        onBackground: DesignTokens.grayDark,
      ),

      // Scaffold
      scaffoldBackgroundColor: DesignTokens.surface,

      // App Bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: DesignTokens.surfaceWhite,
        foregroundColor: DesignTokens.grayDark,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: DesignTokens.textTitle,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: DesignTokens.surfaceWhite,
        selectedItemColor: DesignTokens.brandPrimary,
        unselectedItemColor: DesignTokens.grayMedium,
        selectedLabelStyle: DesignTokens.textSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: DesignTokens.textSmall,
        showUnselectedLabels: true,
        elevation: 8,
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: DesignTokens.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.brandPrimary,
          foregroundColor: DesignTokens.surfaceWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLg,
            vertical: DesignTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.borderRadiusMd,
          ),
          textStyle: DesignTokens.textBody.copyWith(
            fontWeight: FontWeight.w600,
            color: DesignTokens.surfaceWhite,
          ),
        ),
      ),

      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.brandPrimary,
          side: const BorderSide(color: DesignTokens.grayLight, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLg,
            vertical: DesignTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.borderRadiusMd,
          ),
          textStyle: DesignTokens.textBody.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.brandPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceSm,
          ),
          textStyle: DesignTokens.textBody.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon Buttons
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: DesignTokens.grayDark,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: DesignTokens.brandAccent,
        foregroundColor: DesignTokens.surfaceWhite,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.grayLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.grayLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.brandPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.error, width: 2),
        ),
        labelStyle: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
        hintStyle: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
        prefixIconColor: DesignTokens.grayMedium,
        suffixIconColor: DesignTokens.grayMedium,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: DesignTokens.grayLight.withOpacity(0.5),
        labelStyle: DesignTokens.textSmall.copyWith(
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSm,
          vertical: DesignTokens.spaceXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusSm,
        ),
        side: BorderSide.none,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return DesignTokens.brandAccent;
          }
          return DesignTokens.grayMedium;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return DesignTokens.brandAccent.withOpacity(0.3);
          }
          return DesignTokens.grayLight;
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: DesignTokens.grayLight.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceXs,
        ),
        titleTextStyle: DesignTokens.textBody,
        subtitleTextStyle: DesignTokens.textSmall,
        leadingAndTrailingTextStyle: DesignTokens.textSmall,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusBottomSheet,
        ),
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: DesignTokens.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusLg,
        ),
        titleTextStyle: DesignTokens.textTitle,
        contentTextStyle: DesignTokens.textBody,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DesignTokens.grayDark,
        contentTextStyle: DesignTokens.textBody.copyWith(
          color: DesignTokens.surfaceWhite,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // Text Theme
      textTheme: TextTheme(
        headlineLarge: DesignTokens.textTitle.copyWith(fontSize: 24),
        headlineMedium: DesignTokens.textTitle,
        headlineSmall: DesignTokens.textTitle.copyWith(fontSize: 18),
        titleLarge: DesignTokens.textTitle,
        titleMedium: DesignTokens.textBodyBold,
        titleSmall: DesignTokens.textSmallBold,
        bodyLarge: DesignTokens.textBody,
        bodyMedium: DesignTokens.textBody,
        bodySmall: DesignTokens.textSmall,
        labelLarge: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600),
        labelMedium: DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w500),
        labelSmall: DesignTokens.textSmall,
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DesignTokens.brandAccent,
        linearTrackColor: DesignTokens.grayLight,
      ),
    );
  }
}
