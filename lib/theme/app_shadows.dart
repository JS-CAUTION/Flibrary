import 'package:flutter/material.dart';

/// Shadow definitions extracted from the Ardot design.
/// All shadows use a blue-tinted color: rgba(107, 138, 255, 0.08)
class AppShadows {
  AppShadows._();

  /// Shadow color: #6B8AFF at 8% opacity
  static const Color _shadowColor = Color(0x146B8AFF);

  /// Card shadow — used on course cards (home screen)
  /// Design: offset (0, 8), blurRadius 32, spread 0
  static const List<BoxShadow> card = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 8),
      blurRadius: 32,
       
    ),
  ];

  /// Form card shadow — used on settings/edit course form cards
  /// Design: offset (0, 2), blurRadius 12, spread 0
  static const List<BoxShadow> formCard = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 2),
      blurRadius: 12,
       
    ),
  ];

  /// Button shadow — same as form card (for white buttons matching card style)
  static const List<BoxShadow> button = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 2),
      blurRadius: 12,
       
    ),
  ];

  /// Notification card shadow — same subtle shadow
  static const List<BoxShadow> notification = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 2),
      blurRadius: 12,
       
    ),
  ];
}
