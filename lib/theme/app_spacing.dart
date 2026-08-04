/// Spacing & layout constants extracted from the Ardot design.
/// Base unit: 4px (design uses 4px grid system)
class AppSpacing {
  AppSpacing._();

  // ── Base Scale ──
  static const double xs = 4;    // 4px
  static const double sm = 8;    // 8px
  static const double md = 12;   // 12px
  static const double base = 16; // 16px
  static const double lg = 20;   // 20px
  static const double xl = 24;   // 24px
  static const double xxl = 32;  // 32px
  static const double xxxl = 48; // 48px

  // ── Screen ──
  /// 393px — design screen width (iPhone 14 Pro reference)
  static const double screenWidth = 393;

  /// 852px — design screen height
  static const double screenHeight = 852;

  /// 62px — status bar height
  static const double statusBarHeight = 62;

  // ── Content Padding ──
  /// 10px — horizontal padding for content wrapper (tightened for phone screens)
  static const double contentPadding = 10;

  // ── Content Spacing ──
  /// 16px — default item spacing in content wrapper (home screen)
  static const double itemSpacingHome = 16;

  /// 24px — item spacing in some screens
  static const double itemSpacingAlt = 24;

  // ── Card ──
  /// 16px — card corner radius
  static const double cardRadius = 16;

  /// 16px — card internal padding
  static const double cardPadding = 16;

  // ── Schedule Grid ──
  /// 38px — time column width (tightened for phone screens)
  static const double timeColumnWidth = 38;

  /// 140px — each time slot height in the grid
  static const double timeSlotHeight = 140;

  /// 2px — gap between grid cells
  static const double gridGap = 2;

  /// 4px — gap between time column and days area
  static const double gridSpacing = 4;

  // ── Icons ──
  /// 24px — standard icon size (back, settings, calendar)
  static const double iconSize = 24;

  /// 20px — small icon size (chevrons)
  static const double iconSmall = 20;

  // ── Tab Bar ──
  /// 95px — tab bar container height (includes safe area)
  static const double tabBarHeight = 95;

  // ── Form Rows ──
  /// 52px — form row height in edit course screen
  static const double formRowHeight = 52;

  /// 1px — divider height between form rows
  static const double dividerHeight = 1;

  // ── Buttons ──
  /// 50px — button height
  static const double buttonHeight = 50;

  // ── Course Card ──
  /// 120px — course card height on home screen
  static const double courseCardHeight = 120;

  // ── Blur Decorations ──
  /// 380px — pink/blue/cyan blur circle size (enlarged)
  static const double blurCircleLarge = 380;

  /// 360px — cyan blur circle width
  static const double blurCyanWidth = 360;

  /// 350px — cyan blur circle height
  static const double blurCyanHeight = 350;

  /// 180px — pink blur corner radius
  static const double blurPinkRadius = 180;

  /// 160px — blue blur corner radius
  static const double blurBlueRadius = 160;

  /// 170px — cyan blur corner radius
  static const double blurCyanRadius = 170;
}
