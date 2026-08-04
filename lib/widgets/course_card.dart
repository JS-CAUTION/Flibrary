import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';
import '../models/course.dart';

/// Course card component — used on the home screen (今日课程).
/// Design spec: 353x120, horizontal layout, white fill, cornerRadius 16,
/// blue-tinted shadow, left color strip + course info.
///
/// Matches Ardot component: Course Card (mainComponent 2:39)
class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final bool compact;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: AppSpacing.courseCardHeight,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.divider.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Left color strip
            Container(
              width: 4,
              height: double.infinity,
              decoration: BoxDecoration(
                color: course.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Course info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(course.name, style: AppTypography.courseName.copyWith(fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(course.teacher, style: AppTypography.courseDetail.copyWith(fontSize: 14)),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(course.location, style: AppTypography.courseDetail.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${course.timeText}', style: AppTypography.courseDetail.copyWith(fontSize: 14)),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: course.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course.dayText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: course.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact variant for notification center — single row layout
  Widget _buildCompact(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.notification,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('课程提醒', style: AppTypography.bodySemiBold),
              const Text(' 📚', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: Text(course.name, style: AppTypography.body, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.sm),
              Text(course.timeText.split(' ~ ').first, style: AppTypography.bodySecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(course.location, style: AppTypography.bodySecondary),
            ],
          ),
        ],
      ),
    );
  }
}
