import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Combined ThemeData for the app.
/// Fonts are loaded via google_fonts in main.dart (AppFonts helper).
/// The theme uses fontFamilyFallback so text widgets work even before
/// google_fonts resolves (e.g. during first frame).
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        primary: AppColors.blue,
        secondary: AppColors.pink,
        surface: AppColors.background,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        // Outfit is set as default; google_fonts overrides at widget level
        bodyLarge: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        bodySmall: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelLarge: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
      ),
      dividerColor: AppColors.divider,
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),
    );
  }
}
