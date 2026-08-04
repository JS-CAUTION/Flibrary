import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../models/course.dart';

/// Bottom sheet showing course details + any related courses at the same slot.
class CourseDetailSheet extends StatelessWidget {
  final Course course;
  final List<Course> relatedCourses;
  final ScrollController? scrollController;

  const CourseDetailSheet({
    super.key,
    required this.course,
    this.relatedCourses = const [],
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final all = [course, ...relatedCourses];

    final children = <Widget>[];
    for (int i = 0; i < all.length; i++) {
      if (i > 0) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          height: 1,
          color: AppColors.divider,
        ));
      }
      children.add(_CourseInfo(course: all[i], index: i + 1, total: all.length));
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _CourseInfo extends StatelessWidget {
  final Course course;
  final int index;
  final int total;

  const _CourseInfo(
      {required this.course, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 32,
              decoration: BoxDecoration(
                color: course.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child:
                    Text(course.name, style: AppTypography.greeting)),
            if (total > 1)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: course.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$index/$total',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: course.color,
                    )),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _DetailRow(
            icon: Icons.person_outline,
            label: '授课教师',
            value: course.teacher),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(
            icon: Icons.location_on_outlined,
            label: '上课地点',
            value: course.location.isNotEmpty ? course.location : '未设置'),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(
            icon: Icons.calendar_today,
            label: '星期',
            value: course.dayText),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(
            icon: Icons.access_time,
            label: '节次',
            value: course.periodText),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(
            icon: Icons.date_range,
            label: '周次',
            value: course.weekText),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: course.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${course.timeText} · ${course.weekText}',
            style: AppTypography.caption.copyWith(color: course.color),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text('$label：', style: AppTypography.caption),
        Expanded(
            child: Text(value,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.end)),
      ],
    );
  }
}
