import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography scale extracted from the Ardot design.
/// Fonts: Outfit (titles) + Inter (body/UI text)
/// Loaded via google_fonts package in main.dart
class AppTypography {
  AppTypography._();

  // ── Outfit (Headlines & Titles) ──

  /// Outfit SemiBold 22px — greeting text on home screen
  static const TextStyle greeting = TextStyle(
    fontFamily: 'Outfit',
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Outfit SemiBold 20px — page titles
  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'Outfit',
    fontWeight: FontWeight.w600,
    fontSize: 20,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// Outfit SemiBold 16px — section headers (e.g. month label on schedule)
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: 'Outfit',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  // ── Inter (Body & UI) ──

  /// Inter Regular 16px — form labels, body text
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  /// Inter Regular 16px — form values (secondary color)
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.textSecondary,
  );

  /// Inter Medium 16px — save button text, emphasized body
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  /// Inter SemiBold 16px — save button text (semibold)
  static const TextStyle bodySemiBold = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  /// Inter Medium 14px — day labels on schedule grid
  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  /// Inter Regular 14px — date text, secondary descriptions
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  /// Inter Regular 14px — color card label
  static const TextStyle captionPrimary = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  /// Inter Regular 12px — time slot labels on schedule grid
  static const TextStyle timeSlot = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  /// Inter SemiBold 15px — status bar time
  static const TextStyle statusBarTime = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  // ── Course Card Text ──

  /// Inter SemiBold 16px — course name on card
  static const TextStyle courseName = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  /// Inter Regular 13px — course details (teacher, location)
  static const TextStyle courseDetail = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  // ── Lock Screen ──

  /// Outfit SemiBold 72px — lock screen large time
  static const TextStyle lockTime = TextStyle(
    fontFamily: 'Outfit',
    fontWeight: FontWeight.w600,
    fontSize: 72,
    color: AppColors.lockScreenText,
    height: 1.0,
  );

  /// Inter Regular 16px — lock screen date
  static const TextStyle lockDate = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.lockScreenTextSecondary,
  );

  // ── Delete Button ──

  /// Inter Regular 16px — delete course text
  static const TextStyle deleteText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.danger,
  );
}
