import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../widgets/diffuse_background.dart';
import '../widgets/settings_row.dart';

class EditCourseScreen extends StatefulWidget {
  final String? courseId;
  final int? prefillDayOfWeek;
  final int? prefillStartPeriod;
  final int? prefillEndPeriod;

  const EditCourseScreen({
    super.key,
    this.courseId,
    this.prefillDayOfWeek,
    this.prefillStartPeriod,
    this.prefillEndPeriod,
  });

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  // ── Group state ──
  List<_CourseEntry> _entries = [];
  int _activeEntryIndex = 0;

  bool get _isEditing => widget.courseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroup());
    } else {
      // New course — start with one entry
      _entries = [_CourseEntry()];
      if (widget.prefillDayOfWeek != null) {
        _entries[0].dayOfWeek = widget.prefillDayOfWeek!;
      }
      if (widget.prefillStartPeriod != null) {
        _entries[0].startPeriod = widget.prefillStartPeriod!;
        _entries[0].endPeriod = widget.prefillEndPeriod ?? widget.prefillStartPeriod! + 1;
      }
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _loadGroup() {
    final provider = context.read<CourseProvider>();
    final course = provider.getCourse(widget.courseId!);
    if (course == null) return;

    // Try groupId first, then cell-based fallback
    final gid = course.groupId.isNotEmpty ? course.groupId : '';
    var group = gid.isNotEmpty
        ? provider.courses
            .where((c) => c.groupId == gid)
            .toList()
        : <Course>[];

    // Fallback: if no group, check same-cell courses
    if (group.isEmpty) {
      group = provider.coursesForCell(course.dayOfWeek, course.startPeriod);
    }

    setState(() {
      if (group.isEmpty) {
        _entries = [_CourseEntry.fromCourse(course)];
      } else {
        _entries = group.map((c) => _CourseEntry.fromCourse(c)).toList();
      }
      _activeEntryIndex = 0;
    });
  }

  _CourseEntry get _activeEntry => _entries[_activeEntryIndex];

  // ── Conflict check ──
  bool _hasConflict(_CourseEntry entry, {int? skipIndex}) {
    for (int i = 0; i < _entries.length; i++) {
      if (i == skipIndex) continue;
      final other = _entries[i];
      if (_weeksOverlap(entry, other)) return true;
    }
    return false;
  }

  bool _weeksOverlap(_CourseEntry a, _CourseEntry b) {
    final aWeeks = a.activeWeeks;
    final bWeeks = b.activeWeeks;
    return aWeeks.any((w) => bWeeks.contains(w));
  }

  // ── Save all entries ──
  Future<void> _save() async {
    final groupId = DateTime.now().microsecondsSinceEpoch.toString();

    // Validate
    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].nameController.text.trim().isEmpty) {
        final label = _entries.length > 1 ? '课程${i + 1} 的名称不能为空' : '请输入课程名称';
        _showValidationDialog(
          title: '信息不完整',
          child: Text('$label\n\n请填写课程名称后再保存'),
        );
        _activeEntryIndex = i;
        setState(() {});
        return;
      }
      if (_hasConflict(_entries[i], skipIndex: i)) {
        final detail = _conflictDetail(i);
        _showConflictDialog(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '周次范围重叠\n\n'),
              TextSpan(
                text: detail,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
              const TextSpan(text: '\n请调整后再保存'),
            ]),
          ),
        );
        _activeEntryIndex = i;
        setState(() {});
        return;
      }
    }

    final provider = context.read<CourseProvider>();
    final existingGroupId = _isEditing
        ? (provider.getCourse(widget.courseId!)?.groupId ?? '')
        : '';
    final sharedGroup = existingGroupId.isNotEmpty ? existingGroupId : groupId;

    // Collect saved IDs for cleanup
    final savedIds = <String>{};

    // Single course entry
    if (_entries.length == 1) {
      final c = _entries[0].toCourse(
        id: _isEditing ? widget.courseId! : groupId,
        groupId: sharedGroup,
      );
      savedIds.add(c.id);
      if (_isEditing) {
        await provider.updateCourse(c);
      } else {
        // Check for existing courses at same slot
        final existing = provider.coursesForCell(c.dayOfWeek, c.startPeriod);
        if (existing.isNotEmpty) {
          final ok = await _confirmAddToGroup();
          if (ok != true) return;
          // Assign groupId of existing course
          final eg = existing.first.groupId.isNotEmpty
              ? existing.first.groupId
              : existing.first.id;
          final withGroup = c.copyWith(groupId: eg);
          savedIds.clear();
          savedIds.add(withGroup.id);
          await provider.addCourse(withGroup);
        } else {
          await provider.addCourse(c);
        }
      }
    } else {
      // Multi-course group
      for (final entry in _entries) {
        final course = entry.toCourse(
          id: entry.originalId ?? DateTime.now().microsecondsSinceEpoch.toString(),
          groupId: sharedGroup,
        );
        savedIds.add(course.id);
        if (entry.originalId != null) {
          await provider.updateCourse(course);
        } else {
          await provider.addCourse(course);
        }
      }
    }

    // Clean up removed members (when editing a group)
    if (_isEditing && sharedGroup.isNotEmpty) {
      final groupCourses = provider.courses
          .where((c) => c.groupId == sharedGroup)
          .toList();
      for (final old in groupCourses) {
        if (!savedIds.contains(old.id)) {
          await provider.deleteCourse(old.id);
        }
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<bool?> _confirmAddToGroup() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('该时段已有课程'),
        content: const Text('是否添加为同一格子的第二门课程？\n（请确保周次范围不重叠）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定添加')),
        ],
      ),
    );
  }

  String _conflictDetail(int index) {
    final entry = _entries[index];
    final buf = StringBuffer();
    for (int j = 0; j < _entries.length; j++) {
      if (j == index) continue;
      final other = _entries[j];
      if (_weeksOverlap(entry, other)) {
        final name1 = entry.nameController.text.isNotEmpty ? entry.nameController.text : '课程${index + 1}';
        final name2 = other.nameController.text.isNotEmpty ? other.nameController.text : '课程${j + 1}';
        buf.writeln('$name1（${_weekTextDisplay(entry)}）');
        buf.writeln('$name2（${_weekTextDisplay(other)}）');
        buf.writeln();
      }
    }
    return buf.toString().trimRight();
  }

  void _showValidationDialog({required String title, required Widget child}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9F43), size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 17)),
          ],
        ),
        content: child,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog({required Widget child}) {
    _showValidationDialog(title: '课程时间冲突', child: child);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final provider = context.read<CourseProvider>();
    final course = provider.getCourse(widget.courseId!);
    if (course == null) return;

    final gid = course.groupId.isNotEmpty ? course.groupId : course.id;
    final members = provider.groupMembers(gid);
    final allCell = provider.coursesForCell(course.dayOfWeek, course.startPeriod);
    final group = members.isNotEmpty ? members : (allCell.isNotEmpty ? allCell : [course]);

    if (group.length > 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除课程'),
          content: Text('该时段共有${group.length}门课程，确定删除全部吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('删除全部'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        for (final c in group) {
          await provider.deleteCourse(c.id);
        }
        if (mounted) Navigator.pop(context, true);
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除课程'),
          content: Text('确定删除「${course.name}」吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await provider.deleteCourse(widget.courseId!);
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  void _addEntry() {
    // New entry inherits day/period from first entry
    final base = _entries.isNotEmpty ? _entries[0] : _CourseEntry();
    setState(() {
      _entries.add(_CourseEntry.inherit(base));
      _activeEntryIndex = _entries.length - 1;
    });
  }

  void _removeEntry(int index) {
    if (_entries.length <= 1) return;
    final entry = _entries[index];
    entry.dispose();
    setState(() {
      _entries.removeAt(index);
      if (_activeEntryIndex >= _entries.length) {
        _activeEntryIndex = _entries.length - 1;
      }
    });
  }

  void _selectEntry(int index) {
    setState(() => _activeEntryIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: DiffuseBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.contentPadding),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_back, size: AppSpacing.iconSize),
                                const SizedBox(width: AppSpacing.md),
                                Text(_isEditing ? '编辑课程' : '添加课程', style: AppTypography.pageTitle),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // ── Entry Tabs ──
                          if (_entries.length > 1)
                            _buildEntryTabs(),

                          const SizedBox(height: AppSpacing.md),

                          // ── Active Entry Form ──
                          _buildEntryForm(_activeEntry, isActive: true),

                          const SizedBox(height: AppSpacing.base),

                          // ── Add Entry Button ──
                          GestureDetector(
                            onTap: _addEntry,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                                border: Border.all(color: AppColors.divider, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 18, color: AppColors.blue),
                                  const SizedBox(width: 6),
                                  Text('添加课程到该时段', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.blue)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // ── Save ──
                          GestureDetector(
                            onTap: _save,
                            child: Container(
                              width: double.infinity,
                              height: AppSpacing.buttonHeight,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                                boxShadow: AppShadows.button,
                              ),
                              child: Center(child: Text('保存', style: AppTypography.bodySemiBold)),
                            ),
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: AppSpacing.base),
                            GestureDetector(
                              onTap: _delete,
                              child: Container(
                                width: double.infinity,
                                height: AppSpacing.buttonHeight,
                                alignment: Alignment.center,
                                child: Text('删除课程', style: AppTypography.deleteText),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTabs() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = index == _activeEntryIndex;
          final entry = _entries[index];
          final label = entry.nameController.text.isNotEmpty
              ? entry.nameController.text
              : '课程${index + 1}';
          return GestureDetector(
            onTap: () => _selectEntry(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.blue : AppColors.divider.withOpacity(0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  if (_entries.length > 1) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeEntry(index),
                      child: Icon(Icons.close, size: 14, color: isActive ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntryForm(_CourseEntry entry, {bool isActive = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.formCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _FormTextField(controller: entry.nameController, label: '课程名称', hint: '请输入课程名称', showDivider: true),
          _FormTextField(controller: entry.teacherController, label: '授课教师', hint: '请输入教师姓名', showDivider: true),
          _FormTextField(controller: entry.locationController, label: '上课地点', hint: '请输入上课地点', showDivider: true),
          SettingsRow(label: '星期', value: _dayText(entry.dayOfWeek), showChevron: true, showDivider: true,
              onTap: () => _showDayPicker(entry)),
          SettingsRow(label: '节次', value: _periodText(entry), showChevron: true, showDivider: true,
              onTap: () => _showPeriodPicker(entry)),
          SettingsRow(label: '周次', value: _weekTextDisplay(entry), showChevron: true, showDivider: true,
              onTap: () => _showWeekPicker(entry)),
          // Color picker
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('课程颜色', style: AppTypography.captionPrimary),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: List.generate(6, (index) {
                    final color = AppColors.courseColors[index];
                    final isSelected = index == entry.colorIndex;
                    return GestureDetector(
                      onTap: () => setState(() => entry.colorIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: AppSpacing.base),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 36 : 32,
                          height: isSelected ? 36 : 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: isSelected ? Border.all(color: AppColors.background, width: 3) : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper strings ──

  String _dayText(int dow) {
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return days[dow.clamp(0, 6)];
  }

  String _periodText(_CourseEntry e) {
    if (e.startPeriod == e.endPeriod) return '第${e.startPeriod}节';
    return '第${e.startPeriod}-${e.endPeriod}节';
  }

  String _weekTextDisplay(_CourseEntry e) {
    if (e.weekMode == WeekMode.custom) {
      if (e.customWeeks.isEmpty) return '未选择周次';
      return '第${e.customWeeks.join('、')}周';
    }
    return '${e.startWeek}-${e.endWeek}周${e.weekMode.label}';
  }

  // ── Pickers ──

  void _showDayPicker(_CourseEntry entry) {
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择星期', style: AppTypography.bodySemiBold),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: List.generate(7, (i) {
                final isSelected = i == entry.dayOfWeek;
                return ChoiceChip(
                  label: Text(days[i]),
                  selected: isSelected,
                  onSelected: (_) { setState(() => entry.dayOfWeek = i); Navigator.pop(ctx); },
                  selectedColor: AppColors.blue.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.blue : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showPeriodPicker(_CourseEntry entry) {
    int tempStart = entry.startPeriod;
    int tempEnd = entry.endPeriod;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('选择节次', style: AppTypography.bodySemiBold),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Text('开始节次：'),
                  const SizedBox(width: AppSpacing.sm),
                  DropdownButton<int>(
                    value: tempStart,
                    items: List.generate(10, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('第$v节'))).toList(),
                    onChanged: (v) {
                      setModalState(() { tempStart = v!; if (tempEnd < tempStart) tempEnd = tempStart; });
                    },
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  const Text('结束节次：'),
                  const SizedBox(width: AppSpacing.sm),
                  DropdownButton<int>(
                    value: tempEnd,
                    items: List.generate(10, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('第$v节'))).toList(),
                    onChanged: (v) {
                      setModalState(() { tempEnd = v!; if (tempEnd < tempStart) tempStart = tempEnd; });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() { entry.startPeriod = tempStart; entry.endPeriod = tempEnd; });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
                  ),
                  child: const Text('确定'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _showWeekPicker(_CourseEntry entry) {
    int tempStart = entry.startWeek;
    int tempEnd = entry.endWeek;
    WeekMode tempMode = entry.weekMode;
    List<int> tempCustomWeeks = List.from(entry.customWeeks);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('选择周次', style: AppTypography.bodySemiBold),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Text('开始周：'),
                  const SizedBox(width: AppSpacing.sm),
                  DropdownButton<int>(
                    value: tempStart,
                    items: List.generate(20, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('第$v周'))).toList(),
                    onChanged: (v) {
                      setModalState(() { tempStart = v!; if (tempEnd < tempStart) tempEnd = tempStart; });
                    },
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  const Text('结束周：'),
                  const SizedBox(width: AppSpacing.sm),
                  DropdownButton<int>(
                    value: tempEnd,
                    items: List.generate(20, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('第$v周'))).toList(),
                    onChanged: (v) {
                      setModalState(() { tempEnd = v!; if (tempEnd < tempStart) tempStart = tempEnd; });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('周类型', style: AppTypography.bodySemiBold),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('全周'), selected: tempMode == WeekMode.all,
                    onSelected: (_) => setModalState(() => tempMode = WeekMode.all),
                    selectedColor: AppColors.blue.withOpacity(0.15),
                  ),
                  ChoiceChip(
                    label: const Text('单周'), selected: tempMode == WeekMode.odd,
                    onSelected: (_) => setModalState(() => tempMode = WeekMode.odd),
                    selectedColor: AppColors.blue.withOpacity(0.15),
                  ),
                  ChoiceChip(
                    label: const Text('双周'), selected: tempMode == WeekMode.even,
                    onSelected: (_) => setModalState(() => tempMode = WeekMode.even),
                    selectedColor: AppColors.blue.withOpacity(0.15),
                  ),
                  ChoiceChip(
                    label: const Text('自定义'), selected: tempMode == WeekMode.custom,
                    onSelected: (_) => setModalState(() => tempMode = WeekMode.custom),
                    selectedColor: AppColors.blue.withOpacity(0.15),
                  ),
                ],
              ),
              if (tempMode == WeekMode.custom) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ...List.generate(tempCustomWeeks.length, (i) {
                          final w = tempCustomWeeks[i];
                          return Chip(
                            label: Text('第$w周', style: const TextStyle(fontSize: 13)),
                            backgroundColor: AppColors.blue.withOpacity(0.12),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setModalState(() { tempCustomWeeks.removeAt(i); });
                            },
                          );
                        }),
                        ActionChip(
                          label: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            final next = tempCustomWeeks.isEmpty
                                ? 1
                                : (tempCustomWeeks.reduce((a, b) => a > b ? a : b) + 1);
                            setModalState(() { tempCustomWeeks.add(next); tempCustomWeeks.sort(); });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (tempMode != WeekMode.custom) const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      entry.startWeek = tempStart;
                      entry.endWeek = tempEnd;
                      entry.weekMode = tempMode;
                      entry.customWeeks = List.from(tempCustomWeeks);
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
                  ),
                  child: const Text('确定'),
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

// ═══ Internal mutable model for a single course entry in the group ═══

class _CourseEntry {
  final TextEditingController nameController;
  final TextEditingController teacherController;
  final TextEditingController locationController;
  int dayOfWeek;
  int startPeriod;
  int endPeriod;
  int startWeek;
  int endWeek;
  int colorIndex;
  WeekMode weekMode;
  List<int> customWeeks;
  final String? originalId; // non-null if editing an existing course

  _CourseEntry({
    String name = '',
    String teacher = '',
    String location = '',
    this.dayOfWeek = 1,
    this.startPeriod = 1,
    this.endPeriod = 2,
    this.startWeek = 1,
    this.endWeek = 16,
    this.colorIndex = 0,
    this.weekMode = WeekMode.all,
    this.customWeeks = const [],
    this.originalId,
  })  : nameController = TextEditingController(text: name),
        teacherController = TextEditingController(text: teacher),
        locationController = TextEditingController(text: location);

  factory _CourseEntry.fromCourse(Course c) {
    return _CourseEntry(
      name: c.name,
      teacher: c.teacher,
      location: c.location,
      dayOfWeek: c.dayOfWeek,
      startPeriod: c.startPeriod,
      endPeriod: c.endPeriod,
      startWeek: c.startWeek,
      endWeek: c.endWeek,
      colorIndex: c.colorIndex,
      weekMode: c.weekMode,
      customWeeks: List.from(c.customWeeks),
      originalId: c.id,
    );
  }

  factory _CourseEntry.inherit(_CourseEntry base) {
    // New entry inherits day/period from base, but fresh weeks/name
    return _CourseEntry(
      dayOfWeek: base.dayOfWeek,
      startPeriod: base.startPeriod,
      endPeriod: base.endPeriod,
      colorIndex: base.colorIndex,
    );
  }

  void dispose() {
    nameController.dispose();
    teacherController.dispose();
    locationController.dispose();
  }

  List<int> get activeWeeks {
    if (weekMode == WeekMode.custom) return customWeeks;
    final weeks = <int>[];
    for (int w = startWeek; w <= endWeek; w++) {
      if (weekMode == WeekMode.all) {
        weeks.add(w);
      } else if (weekMode == WeekMode.odd && w % 2 == 1) {
        weeks.add(w);
      } else if (weekMode == WeekMode.even && w % 2 == 0) {
        weeks.add(w);
      }
    }
    return weeks;
  }

  Course toCourse({required String id, String groupId = ''}) {
    return Course(
      id: id,
      name: nameController.text.trim(),
      teacher: teacherController.text.trim(),
      location: locationController.text.trim(),
      dayOfWeek: dayOfWeek,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      startWeek: startWeek,
      endWeek: endWeek,
      colorIndex: colorIndex,
      weekMode: weekMode,
      customWeeks: customWeeks,
      groupId: groupId,
    );
  }
}

// ═══ Form TextField ═══

class _FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool showDivider;

  const _FormTextField({required this.controller, required this.label, required this.hint, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: AppSpacing.formRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 80, child: Text(label, style: AppTypography.body)),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTypography.bodySecondary,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTypography.bodySecondary.copyWith(color: AppColors.textSecondary.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            height: AppSpacing.dividerHeight,
            color: AppColors.divider
          ),
      ],
    );
  }
}
