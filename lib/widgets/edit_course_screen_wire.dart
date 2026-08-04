import 'package:flutter/material.dart';
import '../screens/edit_course_screen.dart';

/// Simple wrapper for EditCourseScreen that passes constructor args.
/// Used when navigating with PageRouteBuilder (no named route).
class EditCourseScreenWire extends StatelessWidget {
  final String? courseId;
  final int? prefillDayOfWeek;
  final int? prefillStartPeriod;
  final int? prefillEndPeriod;

  const EditCourseScreenWire({
    super.key,
    this.courseId,
    this.prefillDayOfWeek,
    this.prefillStartPeriod,
    this.prefillEndPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return EditCourseScreen(
      courseId: courseId,
      prefillDayOfWeek: prefillDayOfWeek,
      prefillStartPeriod: prefillStartPeriod,
      prefillEndPeriod: prefillEndPeriod,
    );
  }
}
