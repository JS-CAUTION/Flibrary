import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../providers/semester_provider.dart';
import '../services/database_service.dart';
import '../widgets/course_detail_sheet.dart';
import '../widgets/edit_course_screen_wire.dart';
import '../widgets/edge_aware_physics.dart';

/// 课程表 — Schedule Screen
/// Horizontal swipe to change weeks (1-20).
class ScheduleScreen extends StatefulWidget {
  final VoidCallback? onNavigateBack;
  const ScheduleScreen({super.key, this.onNavigateBack});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? _selectedCourseId;
  String? _selectedEmptyCell;
  PageController? _pageController;
  int _displayWeek = 1;
  static const _weekMin = 1;
  static const _weekMax = 20;

  static const _dayLabels = ['日', '一', '二', '三', '四', '五', '六'];

  void _clearEmptySelection() {
    if (_selectedEmptyCell != null) {
      setState(() => _selectedEmptyCell = null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sp = context.read<SemesterProvider>();
    final w = sp.currentWeek.clamp(_weekMin, _weekMax);
    if (_pageController == null) {
      _displayWeek = w;
      _pageController = PageController(initialPage: _displayWeek - 1);
    } else if (_displayWeek != w) {
      _displayWeek = w;
      _pageController!.jumpToPage(w - 1);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = _pageController;
    if (pc == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Consumer2<CourseProvider, SemesterProvider>(
          builder: (context, cp, sp, _) {
            final today = DateTime.now();

            return GestureDetector(
              onTap: _clearEmptySelection,
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  /// ── Fixed top panel (header + date row, single rounded overlay) ──
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.contentPadding,
                      right: AppSpacing.contentPadding,
                      top: AppSpacing.md,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x80FFFFFF),
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeaderRow(context, sp),
                          _buildDateRow(sp, today),
                        ],
                      ),
                    ),
                  ),

                  /// ── Scrollable grid ──
                  Expanded(
                    child: PageView.builder(
                      controller: pc,
                      physics: EdgeAwarePhysics(
                        atLeftEdge: _displayWeek == _weekMin,
                        atRightEdge: _displayWeek == _weekMax,
                      ),
                      itemCount: _weekMax,
                      onPageChanged: (page) {
                        setState(() {
                          _displayWeek = page + 1;
                          _selectedCourseId = null;
                          _selectedEmptyCell = null;
                        });
                      },
                      itemBuilder: (context, index) {
                        final w = index + 1;

                        return SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.contentPadding),
                            child: Column(
                              children: [
                                const SizedBox(height: AppSpacing.md),
                                _buildScheduleGrid(context, cp.courses, w),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ── Date row (50% white overlay, fixed below header) ──
  Widget _buildDateRow(SemesterProvider sp, DateTime today) {
    final wo = _displayWeek - sp.currentWeek;
    final todayDow = today.weekday % 7;
    final thisWeekSunday = today.subtract(Duration(days: todayDow));
    final displaySunday = thisWeekSunday.add(Duration(days: wo * 7));
    final dates = List.generate(7, (i) => displaySunday.add(Duration(days: i)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.timeColumnWidth,
            child: Transform.translate(
              offset: const Offset(6, 0),
              child: Text(
                '${displaySunday.month}月',
                style: AppTypography.sectionHeader,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.gridSpacing),
          Expanded(
            child: Row(
              children: List.generate(7, (i) {
                final isToday = dates[i].day == today.day && wo == 0;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                      Text(_dayLabels[i],
                          style: AppTypography.labelMedium, textAlign: TextAlign.center),
                      Text(
                        '${dates[i].day}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 11,
                          color: isToday ? AppColors.blue : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Header row (← arrows, week title, +) ──
  Widget _buildHeaderRow(BuildContext context, SemesterProvider sp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onNavigateBack ?? () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: AppSpacing.iconSize),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _displayWeek > _weekMin
                ? () => _pageController?.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
            child: Icon(Icons.chevron_left,
                size: 24,
                color: _displayWeek > _weekMin ? AppColors.textPrimary : AppColors.divider),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showSemesterPicker(context),
            child: Text(
              sp.isSet ? '第$_displayWeek周' : '选择学期第一天',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _displayWeek < _weekMax
                ? () => _pageController?.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
            child: Icon(Icons.chevron_right,
                size: 24,
                color: _displayWeek < _weekMax ? AppColors.textPrimary : AppColors.divider),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showAddMenu(context),
            child: const Icon(Icons.add, size: AppSpacing.iconSize),
          ),
        ],
      ),
    );
  }

  // ═══ Add / Import / Semester menu ═══

  void _showAddMenu(BuildContext context) {
    final hasExisting = context.read<CourseProvider>().courses.isNotEmpty;
    if (!hasExisting) {
      _pickImportSource(context);
      return;
    }

    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入新课表'),
        content: const Text('检测到已有课程数据，请选择导入方式：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Text('直接导入'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('清空并导入'),
          ),
        ],
      ),
    ).then((action) {
      if (action == 0 || action == null || !context.mounted) return;
      if (action == 1) {
        context.read<CourseProvider>().clearAllCourses();
        context.read<SemesterProvider>().reset();
        StorageService.deleteAllData();
      }
      _pickImportSource(context);
    });
  }

  void _pickImportSource(BuildContext context) {
    showModalBottomSheet<_ImportSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择导入方式',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('导入 CSV 文件'),
              subtitle: const Text('Excel/WPS 另存为 CSV 后导入'),
              onTap: () => Navigator.pop(ctx, _ImportSource.csv),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('教务在线导入'),
              subtitle: const Text('内置浏览器登录教务，直接提取课表'),
              onTap: () => Navigator.pop(ctx, _ImportSource.online),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((source) {
      if (source == null || !context.mounted) return;
      _checkSemesterThenImport(context, source);
    });
  }

  void _checkSemesterThenImport(BuildContext context, _ImportSource source) {
    final sp = context.read<SemesterProvider>();
    if (sp.isSet) {
      Navigator.pushNamed(
        context,
        source == _ImportSource.csv ? '/import' : '/edu-webview',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未设置学期第一天'),
        content: const Text('请先设置学期第一天，否则周次计算可能不准确。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSemesterPicker(context);
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showSemesterPicker(BuildContext context) async {
    final sp = context.read<SemesterProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: sp.firstDay ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: '选择学期第一天',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) await sp.setFirstDay(picked);
  }

  // ═══ Schedule Grid ═══

  Widget _buildScheduleGrid(
      BuildContext context, List<Course> allCourses, int displayWeek) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0x80FFFFFF),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: SizedBox(
          width: AppSpacing.timeColumnWidth,
          child: Column(
            children: TimeSlot.slots
                .map((s) => Container(
                      width: AppSpacing.timeColumnWidth,
                      height: AppSpacing.timeSlotHeight,
                      alignment: Alignment.center,
                      child: Text(s.label,
                          style: AppTypography.timeSlot, textAlign: TextAlign.center),
                    ))
                .toList(),
          ),
          ),
        ),
        const SizedBox(width: AppSpacing.gridSpacing),
        Expanded(
          child: Row(
            children: List.generate(
              7,
              (dayIndex) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: List.generate(5, (slotIndex) {
                      final slot = TimeSlot.slots[slotIndex];

                      final active = allCourses
                          .where((c) =>
                              c.dayOfWeek == dayIndex &&
                              c.startPeriod == slot.period &&
                              c.isActiveInWeek(displayWeek))
                          .toList();

                      final inactive = allCourses
                          .where((c) =>
                              c.dayOfWeek == dayIndex &&
                              c.startPeriod == slot.period &&
                              c.startWeek <= displayWeek &&
                              c.endWeek >= displayWeek &&
                              !c.isActiveInWeek(displayWeek))
                          .toList();

                      final other = allCourses
                          .where((c) =>
                              c.dayOfWeek == dayIndex &&
                              c.startPeriod == slot.period &&
                              (c.endWeek < displayWeek || c.startWeek > displayWeek))
                          .toList();

                      final hasContent =
                          active.isNotEmpty || inactive.isNotEmpty || other.isNotEmpty;
                      final selId = _selectedCourseId;
                      final isSel = selId != null &&
                          (active.any((c) => c.id == selId) ||
                              inactive.any((c) => c.id == selId) ||
                              other.any((c) => c.id == selId));

                      return Container(
                        width: double.infinity,
                        height: AppSpacing.timeSlotHeight,
                        margin: const EdgeInsets.only(bottom: AppSpacing.gridGap),
                        child: hasContent
                            ? _CourseCell(
                                activeCourses: active,
                                inactiveCourses: inactive,
                                otherWeekCourses: other,
                                isSelected: isSel,
                                onTap: () {
                                  final c = _primary(active, inactive, other);
                                  setState(() {
                                    _selectedCourseId = c.id;
                                    _selectedEmptyCell = null;
                                  });
                                  _showDetail(context, c);
                                },
                                onLongPress: () =>
                                    _showCourseMenu(context, _primary(active, inactive, other)),
                              )
                            : _EmptyCell(
                                isSelected: _selectedEmptyCell == '${dayIndex}_$slotIndex',
                                onTap: () {
                                  final key = '${dayIndex}_$slotIndex';
                                  if (_selectedEmptyCell == key) {
                                    _selectedEmptyCell = null;
                                    _addCourseAtCell(
                                        context, dayIndex, slot.period, slot.period + 1);
                                  } else {
                                    setState(() {
                                      _selectedCourseId = null;
                                      _selectedEmptyCell = key;
                                    });
                                  }
                                },
                              ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Course _primary(List<Course> a, List<Course> i, List<Course> o) {
    if (a.isNotEmpty) return a.first;
    if (i.isNotEmpty) return i.first;
    return o.first;
  }

  void _addCourseAtCell(BuildContext context, int dayOfWeek, int startPeriod, int endPeriod) {
    final provider = context.read<CourseProvider>();
    final existing = provider.coursesForCell(dayOfWeek, startPeriod);

    if (existing.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('该时段已有${existing.length}门课', style: AppTypography.bodySemiBold),
                const SizedBox(height: AppSpacing.sm),
                Text(existing.map((c) => c.name).join('、'), style: AppTypography.caption),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ListTile(
                    leading: const Icon(Icons.add, color: AppColors.blue),
                    title: const Text('添加新课到该时段'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToNewCourse(
                          context, dayOfWeek, startPeriod, endPeriod);
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ListTile(
                    leading: const Icon(Icons.edit, color: AppColors.blue),
                    title: const Text('编辑已有课程组'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              EditCourseScreenWire(courseId: existing.first.id),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      );
    } else {
      _navigateToNewCourse(context, dayOfWeek, startPeriod, endPeriod);
    }
  }

  void _navigateToNewCourse(
      BuildContext context, int dayOfWeek, int startPeriod, int endPeriod) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => EditCourseScreenWire(
            prefillDayOfWeek: dayOfWeek,
            prefillStartPeriod: startPeriod,
            prefillEndPeriod: endPeriod),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _showDetail(BuildContext context, Course course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => CourseDetailSheet(
          course: course,
          relatedCourses: _getRelatedCourses(course),
          scrollController: scrollController,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedCourseId = null;
          _selectedEmptyCell = null;
        });
      }
    });
  }

  List<Course> _getRelatedCourses(Course course) {
    final provider = context.read<CourseProvider>();
    return provider.courses
        .where((c) =>
            c.dayOfWeek == course.dayOfWeek &&
            c.startPeriod == course.startPeriod &&
            c.id != course.id)
        .toList();
  }

  void _showCourseMenu(BuildContext context, Course course) {
    final provider = context.read<CourseProvider>();
    final gid = course.groupId.isNotEmpty ? course.groupId : course.id;
    final allCell = provider.coursesForCell(course.dayOfWeek, course.startPeriod);
    final members = provider.groupMembers(gid);
    final displayed = members.isEmpty ? allCell : members;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: AppSpacing.lg),
              Text(
                displayed.length > 1 ? '${course.name} 等${displayed.length}门课' : course.name,
                style: AppTypography.bodySemiBold,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${course.dayText} ${course.periodText}', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.lg),
              if (displayed.length > 1) ...[
                ...List.generate(displayed.length, (i) {
                  final c = displayed[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.name, style: AppTypography.bodyMedium)),
                        Text(c.weekText, style: AppTypography.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            EditCourseScreenWire(courseId: course.id),
                        transitionsBuilder: (_, a, __, c) =>
                            FadeTransition(opacity: a, child: c),
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(displayed.length > 1 ? '编辑课程组' : '编辑课程'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final label = displayed.length > 1
                        ? '确定删除「${course.name}」等${displayed.length}门课程吗？'
                        : '确定删除「${course.name}」吗？';
                    final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              title: const Text('删除课程'),
                              content: Text(label),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.danger),
                                    child: const Text('删除全部')),
                              ],
                            ));
                    if (ok == true) {
                      final cp = context.read<CourseProvider>();
                      for (final c in displayed) {
                        cp.deleteCourse(c.id);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  label: Text(
                    displayed.length > 1 ? '删除课程组' : '删除课程',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══ Cell widgets ═══

class _CourseCell extends StatelessWidget {
  final List<Course> activeCourses;
  final List<Course> inactiveCourses;
  final List<Course> otherWeekCourses;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CourseCell({
    required this.activeCourses,
    required this.inactiveCourses,
    required this.otherWeekCourses,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  Course? get _primary {
    if (activeCourses.isNotEmpty) return activeCourses.first;
    if (inactiveCourses.isNotEmpty) return inactiveCourses.first;
    if (otherWeekCourses.isNotEmpty) return otherWeekCourses.first;
    return null;
  }

  bool get _isActive => activeCourses.isNotEmpty;
  int get _total =>
      activeCourses.length + inactiveCourses.length + otherWeekCourses.length;

  bool get _isOngoing {
    final c = _primary;
    if (c == null) return false;
    final now = DateTime.now();
    final dow = now.weekday % 7;
    final hour = now.hour;
    final minute = now.minute;
    final currentMin = hour * 60 + minute;

    const slotTimes = {
      1: {'start': 8 * 60, 'end': 9 * 60 + 40},
      3: {'start': 10 * 60 + 10, 'end': 11 * 60 + 50},
      5: {'start': 14 * 60, 'end': 15 * 60 + 40},
      7: {'start': 16 * 60 + 10, 'end': 17 * 60 + 50},
      9: {'start': 19 * 60 + 30, 'end': 21 * 60 + 10},
    };

    if (c.dayOfWeek != dow) return false;
    final slot = slotTimes[c.startPeriod];
    if (slot == null) return false;
    return currentMin >= slot['start']! && currentMin < slot['end']!;
  }

  @override
  Widget build(BuildContext context) {
    final c = _primary;
    if (c == null) return const SizedBox.shrink();

    final ba = isSelected
        ? AppColors.cellBorderSelected
        : _isActive
            ? AppColors.cellBorderActive
            : AppColors.cellBorderInactive;
    final bw =
        isSelected ? AppColors.cellSelectedBorderWidth : AppColors.cellBorderWidth;

    final border = Border.all(color: c.color.withOpacity(ba), width: bw);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: _isOngoing && !isSelected
          ? _PulsingCell(
              child: buildCellContent(c), color: c.color, borderWidth: bw)
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.divider.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: border,
              ),
              child: buildCellContent(c),
            ),
    );
  }

  Widget buildCellContent(Course c) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: c.color,
                      decoration: _isActive ? null : TextDecoration.lineThrough),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              if (c.teacher.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(c.teacher,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: c.color.withOpacity(_isActive ? 0.6 : 0.3)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              if (c.location.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text('@${c.location}',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: c.color.withOpacity(_isActive ? 0.55 : 0.25))),
              ],
            ],
          ),
        ),
        if (_total > 1)
          Positioned(
            top: 1,
            left: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

class _PulsingCell extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderWidth;

  const _PulsingCell(
      {required this.child, required this.color, required this.borderWidth});

  @override
  State<_PulsingCell> createState() => _PulsingCellState();
}

class _PulsingCellState extends State<_PulsingCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _cycleColors = [
    Color(0xFF6B8AFF),
    Color(0xFFFF6B9D),
    Color(0xFFFAD700),
    Color(0xFF4ECDC4),
    Color(0xFFA78BFA),
    Color(0xFFFF9F43),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final idx = (t * _cycleColors.length).floor() % _cycleColors.length;
        final nextIdx = (idx + 1) % _cycleColors.length;
        final fraction = (t * _cycleColors.length) - idx;
        final currentColor =
            Color.lerp(_cycleColors[idx], _cycleColors[nextIdx], fraction)!;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.divider.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: currentColor, width: widget.borderWidth + 0.5),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _EmptyCell extends StatelessWidget {
  final VoidCallback onTap;
  final bool isSelected;

  const _EmptyCell({required this.onTap, this.isSelected = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.divider.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: AppColors.textSecondary.withOpacity(0.6), width: 2.0)
                : null,
          ),
        ),
      );
}

enum _ImportSource { csv, online }
