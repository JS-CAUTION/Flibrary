import 'package:flutter/material.dart';

/// All color values extracted precisely from the Ardot design file.
/// Source: 课程表App.ardot (fileId: c84a89aae8aeb0df30638fb6b60bd326)
class AppColors {
  AppColors._();

  // ── Backgrounds ──
  static const Color background = Color(0xFFFFFFFF);

  // ── Text ──
  /// #1A1A2E — primary text (titles, body, icons)
  static const Color textPrimary = Color(0xFF1A1A2E);

  /// #6B6B8A — secondary text (labels, descriptions, time slots)
  static const Color textSecondary = Color(0xFF6B6B8A);

  // ── Accent Colors ──
  /// #6B8AFF — blue accent (primary brand color)
  static const Color blue = Color(0xFF6B8AFF);

  /// #FF6B9D — pink accent
  static const Color pink = Color(0xFFFF6B9D);

  /// #FAD700 — golden yellow
  static const Color deepGold = Color(0xFFFAD700);

  /// #FAD700 — golden yellow accent
  static const Color yellow = Color(0xFFFAD700);

  /// #4ECDC4 — green accent
  static const Color green = Color(0xFF4ECDC4);

  /// #A78BFA — purple accent
  static const Color purple = Color(0xFFA78BFA);

  /// #FF9F43 — orange accent
  static const Color orange = Color(0xFFFF9F43);

  // ── Semantic ──
  /// #FF3B30 — delete / danger
  static const Color danger = Color(0xFFFF3B30);

  // ── Dividers & Borders ──
  /// #F0F0F5 — divider lines
  static const Color divider = Color(0xFFF0F0F5);

  // ── Diffuse Background Gradients ──
  /// Pink radial gradient: #FFE3F0 → transparent
  static const Color blurPinkCenter = Color(0xFFFFE3F0);

  /// Blue radial gradient: #E0EBFF → transparent
  static const Color blurBlueCenter = Color(0xFFE0EBFF);

  /// Cyan radial gradient: #D6FFF5 → transparent
  static const Color blurCyanCenter = Color(0xFFD6FFF5);

  // ── Course Cell Colors (4 states from design) ──
  static const List<Color> courseColors = [
    blue,    // Blue (default/selected)
    pink,    // Pink
    yellow,  // Yellow
    green,   // Green
    purple,  // Purple
    orange,  // Orange
  ];

  /// Opacity levels for course cells in different states
  static const double cellActiveOpacity = 0.15;   // 本课程在本周上课
  static const double cellInactiveOpacity = 0.05; // 本课程不在本周但存在
  static const double cellSelectedOpacity = 0.30;  // 被选中时
  static const double cellBorderActive = 0.3;
  static const double cellBorderInactive = 0.15;
  static const double cellBorderSelected = 0.8;
  static const double cellBorderWidth = 1.0;
  static const double cellSelectedBorderWidth = 2.0;

  // ── Lock Screen (Push Notification) ──
  /// Dark gradient background for lock screen
  static const Color lockScreenTop = Color(0xFF1A1A2E);
  static const Color lockScreenBottom = Color(0xFF0D0D1A);
  static const Color lockScreenText = Color(0xFFFFFFFF);
  static const Color lockScreenTextSecondary = Color(0x99FFFFFF);
}
