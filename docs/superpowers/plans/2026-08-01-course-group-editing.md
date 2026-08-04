# Course Group Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans.

**Goal:** Enable adding multiple courses to the same time-slot cell with different week ranges, displayed as groups with shared groupId.

**Architecture:** Add `groupId` field to `Course` model. Same cell + groupId courses form a group. Schedule grid shows only the currently active course with a dot indicator for extras. Edit screen becomes group-aware: shows group member list + add-to-group button. Save validates no overlapping weeks within a group.

**Tech Stack:** Flutter + Provider + SharedPreferences

---

## File Changes Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/models/course.dart` | Modify | Add `groupId`, static `newGroupId()` |
| `lib/providers/course_provider.dart` | Modify | Add `coursesForCellAndWeek`, `groupMembers`, `addToGroup` |
| `lib/services/database_service.dart` | Modify | Migration for existing courses |
| `lib/screens/edit_course_screen.dart` | Rewrite | Group-aware edit: member list + add button |
| `lib/screens/schedule_screen.dart` | Modify | Display logic: show active + dot; long-press → group edit |
| `lib/widgets/course_detail_sheet.dart` | Modify | Show all group members in detail |

---

## Task 1: Add `groupId` to Course model

**File:** `lib/models/course.dart`

Add the field and a static helper:

```dart
// Add to constructor params after customWeeks:
this.groupId,

// Add field:
final String? groupId;

// Add to copyWith:
String? groupId,

// In copyWith body:
groupId: groupId ?? this.groupId,

// Add helper:
static String newGroupId() => DateTime.now().microsecondsSinceEpoch.toString();

// In fromMap:
groupId: map['groupId'] as String?,

// In toMap:
'groupId': groupId,
```

**Commit:** `feat: add groupId field to Course model`

---

## Task 2: Migrate existing courses

**File:** `lib/services/database_service.dart`

Existing courses loaded from storage won't have `groupId`. Add a migration in `getAllCourses`:

```dart
static Future<List<Course>> getAllCourses() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_coursesKey);
  if (json == null || json.isEmpty) return [];
  final list = jsonDecode(json) as List<dynamic>;
  return list.map((m) {
    final map = m as Map<String, dynamic>;
    // Migration: ensure groupId exists for existing courses
    if (!map.containsKey('groupId') || map['groupId'] == null) {
      // Assign a unique groupId per course for solo courses
      // (cells with same slot will be merged later if needed)
      map['groupId'] = Course.newGroupId();
      // Save back immediately
      _needsMigration = true;
    }
    return Course.fromMap(map);
  }).toList();
}
```

Add migration save flag:
```dart
static bool _needsMigration = false;

// After loading, trigger save if migration happened
// In CourseProvider.loadCourses(), after load:
// if (StorageService._needsMigration) await StorageService._saveCourses(_courses);
```

**Commit:** `feat: migrate existing courses with groupId`

---

## Task 3: Add group-aware methods to CourseProvider

**File:** `lib/providers/course_provider.dart`

Add helper methods:

```dart
/// Get all courses sharing a cell (same dayOfWeek + startPeriod).
List<Course> coursesForCell(int dayOfWeek, int startPeriod) {
  return _courses
      .where((c) => c.dayOfWeek == dayOfWeek && c.startPeriod == startPeriod)
      .toList();
}

/// Get all group members for a given course.
List<Course> groupMembers(String groupId) {
  return _courses.where((c) => c.groupId == groupId).toList()
    ..sort((a, b) => a.startWeek.compareTo(b.startWeek));
}

/// Validate: no overlapping weeks within a group.
String? validateGroupWeeks(List<Course> groupCourses) {
  // Sort by startWeek
  final sorted = List<Course>.from(groupCourses)
    ..sort((a, b) => a.startWeek.compareTo(b.startWeek));
  for (int i = 0; i < sorted.length - 1; i++) {
    if (sorted[i].endWeek >= sorted[i + 1].startWeek) {
      return '${sorted[i].name}(${sorted[i].weekText}) 与 ${sorted[i + 1].name}(${sorted[i + 1].weekText}) 周次重叠';
    }
  }
  return null; // OK
}

/// Add a new course to an existing group (same dayOfWeek + startPeriod).
Future<void> addToGroup(Course course, String groupId) async {
  final updated = course.copyWith(groupId: groupId);
  await StorageService.insertCourse(updated);
  _courses.removeWhere((c) => c.id == updated.id);
  _courses.add(updated);
  notifyListeners();
  NotificationService.scheduleAll(_courses);
}
```

**Commit:** `feat: add group query methods to CourseProvider`

---

## Task 4: Update schedule grid display logic

**File:** `lib/screens/schedule_screen.dart`

Modify `_buildScheduleGrid` to show only the currently active course but keep the dot indicator:

Find the cell building section. Currently `active` = courses where `isActiveInWeek(displayWeek)`. The `allCourses` variable already covers all courses for the cell.

The existing code already has `_primary()` that picks the first active course. The dot indicator (`_total > 1`) already shows when multiple courses occupy the same cell. The display logic is mostly correct already — we just need to ensure the detail sheet and edit flow are group-aware.

**No display logic change needed** — the existing `_CourseCell` already:
- Shows first active course as primary
- Shows dot when `_total > 1`

The change is in what happens on long-press: instead of showing a single-course menu, show the group edit screen.

Update `_showCourseMenu` → `_showGroupMenu`:

```dart
void _showGroupMenu(BuildContext context, Course course) {
  final provider = context.read<CourseProvider>();
  final members = provider.groupMembers(course.groupId ?? '');
  final displayedMembers = members.isEmpty ? [course] : members;
  
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
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: AppSpacing.lg),
            // Group name (use first course name)
            Text(
              '${course.name} 等${displayedMembers.length}门课',
              style: AppTypography.bodySemiBold,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${course.dayText} ${course.periodText}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Member list
            ...displayedMembers.map((c) => ListTile(
              title: Text(c.name),
              subtitle: Text(c.weekText),
              trailing: Text(c.teacher, style: AppTypography.caption),
              onTap: () {
                Navigator.pop(ctx);
                _editGroup(context, displayedMembers);
              },
            )),
            const SizedBox(height: AppSpacing.sm),
            // Edit group button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _editGroup(context, displayedMembers);
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('编辑课程组'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Delete group button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除课程组'),
                      content: Text('确定删除「${course.name}」等${displayedMembers.length}门课吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          child: const Text('删除全部'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    for (final c in displayedMembers) {
                      context.read<CourseProvider>().deleteCourse(c.id);
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                label: const Text('删除课程组', style: TextStyle(color: AppColors.danger)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    ),
  );
}

void _editGroup(BuildContext context, List<Course> members) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => EditCourseScreen(groupMembers: members),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );
}
```

Update call sites:
- `onLongPress` in `_CourseCell` → now calls `_showGroupMenu(context, _primary(...))` instead of `_showCourseMenu`
- Keep `_showCourseMenu` for backward compat with `/edit-course` route

**Commit:** `feat: group-aware long-press menu in schedule grid`

---

## Task 5: Rewrite EditCourseScreen for group editing

**File:** `lib/screens/edit_course_screen.dart`

The screen now accepts an optional list of group members:

```dart
class EditCourseScreen extends StatefulWidget {
  final String? courseId;
  final int? prefillDayOfWeek;
  final int? prefillStartPeriod;
  final int? prefillEndPeriod;
  final List<Course>? groupMembers; // NEW: for group edit mode

  const EditCourseScreen({
    super.key,
    this.courseId,
    this.prefillDayOfWeek,
    this.prefillStartPeriod,
    this.prefillEndPeriod,
    this.groupMembers,
  });
  // ...
}
```

In `_EditCourseScreenState`:

```dart
late List<_CourseForm> _members;
int _activeMemberIndex = 0;
String? _groupId;
bool get _isGroupMode => widget.groupMembers != null && widget.groupMembers!.isNotEmpty;
bool get _isEditing => widget.courseId != null || _isGroupMode;

@override
void initState() {
  super.initState();
  _groupId = widget.groupMembers?.first.groupId;
  if (_isGroupMode) {
    _members = widget.groupMembers!.map((c) => _CourseForm.fromCourse(c)).toList();
  } else {
    _members = [_CourseForm.empty()];
    if (widget.prefillDayOfWeek != null) _members[0].dayOfWeek = widget.prefillDayOfWeek!;
    if (widget.prefillStartPeriod != null) _members[0].startPeriod = widget.prefillStartPeriod!;
    if (widget.prefillEndPeriod != null) _members[0].endPeriod = widget.prefillEndPeriod!;
  }
}

void _addMember() {
  setState(() {
    final last = _members.last;
    _members.add(_CourseForm.empty(
      dayOfWeek: last.dayOfWeek,
      startPeriod: last.startPeriod,
      endPeriod: last.endPeriod,
    ));
    _activeMemberIndex = _members.length - 1;
  });
}

void _removeMember(int index) {
  setState(() {
    _members.removeAt(index);
    if (_activeMemberIndex >= _members.length) {
      _activeMemberIndex = _members.length - 1;
    }
  });
}
```

Build method structure:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Column(
        children: [
          // Header with back + title + save
          _buildHeader(context),
          // Member tabs (if group mode or multi-member)
          if (_members.length > 1) _buildMemberTabs(),
          // Form for active member
          Expanded(
            child: _buildMemberForm(_members[_activeMemberIndex]),
          ),
          // Add member button
          _buildAddMemberButton(),
          // Save + Delete buttons
          _buildSaveDeleteButtons(),
        ],
      ),
    ),
  );
}

Widget _buildHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.contentPadding),
    child: Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, size: AppSpacing.iconSize),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              _isGroupMode ? '编辑课程组' : (_isEditing ? '编辑课程' : '添加课程'),
              style: AppTypography.pageTitle,
            ),
            const Spacer(),
            GestureDetector(
              onTap: _saveAll,
              child: Text('保存', style: AppTypography.bodySemiBold.copyWith(color: AppColors.blue)),
            ),
          ],
        ),
      ],
    ),
  );
}
```

`_CourseForm` helper class:

```dart
class _CourseForm {
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
  String? id; // existing course id (null = new)

  _CourseForm({
    required this.nameController,
    required this.teacherController,
    required this.locationController,
    this.dayOfWeek = 1,
    this.startPeriod = 1,
    this.endPeriod = 2,
    this.startWeek = 1,
    this.endWeek = 16,
    this.colorIndex = 0,
    this.weekMode = WeekMode.all,
    this.customWeeks = const [],
    this.id,
  });

  factory _CourseForm.empty({int? dayOfWeek, int? startPeriod, int? endPeriod}) {
    return _CourseForm(
      nameController: TextEditingController(),
      teacherController: TextEditingController(),
      locationController: TextEditingController(),
      dayOfWeek: dayOfWeek ?? 1,
      startPeriod: startPeriod ?? 1,
      endPeriod: endPeriod ?? 2,
    );
  }

  factory _CourseForm.fromCourse(Course c) {
    return _CourseForm(
      nameController: TextEditingController(text: c.name),
      teacherController: TextEditingController(text: c.teacher),
      locationController: TextEditingController(text: c.location),
      dayOfWeek: c.dayOfWeek,
      startPeriod: c.startPeriod,
      endPeriod: c.endPeriod,
      startWeek: c.startWeek,
      endWeek: c.endWeek,
      colorIndex: c.colorIndex,
      weekMode: c.weekMode,
      customWeeks: List.from(c.customWeeks),
      id: c.id,
    );
  }

  Course toCourse({required String groupId, int? colorIdx}) {
    return Course(
      id: id ?? Course.newGroupId(),
      name: nameController.text.trim(),
      teacher: teacherController.text.trim(),
      location: locationController.text.trim(),
      dayOfWeek: dayOfWeek,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      startWeek: startWeek,
      endWeek: endWeek,
      colorIndex: colorIdx ?? 0,
      weekMode: weekMode,
      customWeeks: customWeeks,
      groupId: groupId,
    );
  }

  void dispose() {
    nameController.dispose();
    teacherController.dispose();
    locationController.dispose();
  }
}
```

Save logic:

```dart
Future<void> _saveAll() async {
  // Validate names
  for (int i = 0; i < _members.length; i++) {
    if (_members[i].nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入第${i + 1}门课程名称')),
      );
      return;
    }
  }

  final provider = context.read<CourseProvider>();
  final gid = _groupId ?? Course.newGroupId();
  
  // Build course list
  final courses = <Course>[];
  for (int i = 0; i < _members.length; i++) {
    courses.add(_members[i].toCourse(
      groupId: gid,
      colorIdx: i % 6, // cycle colors
    ));
  }

  // Validate no overlapping weeks
  final error = provider.validateGroupWeeks(courses);
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('周次冲突：$error')),
    );
    return;
  }

  // Check for existing courses in the same cell
  final cell = courses.first;
  final existing = provider.coursesForCell(cell.dayOfWeek, cell.startPeriod);
  final existingOther = existing.where((c) => c.groupId != gid);
  if (existingOther.isNotEmpty) {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('该时段已有课程'),
        content: Text('该时段已有${existingOther.length}门课，是否添加第二门课？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定添加')),
        ],
      ),
    );
    if (confirm != true) return;
  }

  // Save all
  for (final c in courses) {
    if (c.id == _members.entries.where((e) => e.value.id == c.id).isNotEmpty) {
      await provider.updateCourse(c);
    } else {
      await provider.addCourse(c);
    }
  }

  // Delete removed members (courses that were in the group but no longer in _members)
  if (_isGroupMode) {
    final savedIds = courses.map((c) => c.id).toSet();
    for (final oldCourse in widget.groupMembers!) {
      if (!savedIds.contains(oldCourse.id)) {
        await provider.deleteCourse(oldCourse.id);
      }
    }
  }

  if (mounted) Navigator.pop(context, true);
}
```

**Commit:** `feat: group-aware EditCourseScreen with multi-member support`

---

## Task 6: Update CourseDetailSheet for group display

**File:** `lib/widgets/course_detail_sheet.dart`

Show all group members in the detail sheet:

```dart
// In build(), after showing current course details:
if (relatedCourses.isNotEmpty) {
  const SizedBox(height: AppSpacing.md),
  Text('同时段课程', style: AppTypography.sectionHeader),
  const SizedBox(height: AppSpacing.sm),
  // List all related courses
  ...relatedCourses.map((c) => ...),
}
```

The existing `_getRelatedCourses` in `schedule_screen.dart` already fetches same-cell courses. Just need to pass them through.

**Commit:** `feat: show group members in course detail sheet`

---

## Task 7: Update EditCourseScreenWire for group mode

**File:** `lib/widgets/edit_course_screen_wire.dart`

Add `groupMembers` parameter passthrough:

```dart
class EditCourseScreenWire extends StatelessWidget {
  final String? courseId;
  final int? prefillDayOfWeek;
  final int? prefillStartPeriod;
  final int? prefillEndPeriod;
  final List<Course>? groupMembers; // NEW

  const EditCourseScreenWire({
    super.key,
    this.courseId,
    this.prefillDayOfWeek,
    this.prefillStartPeriod,
    this.prefillEndPeriod,
    this.groupMembers,
  });

  @override
  Widget build(BuildContext context) {
    return EditCourseScreen(
      courseId: courseId,
      prefillDayOfWeek: prefillDayOfWeek,
      prefillStartPeriod: prefillStartPeriod,
      prefillEndPeriod: prefillEndPeriod,
      groupMembers: groupMembers,
    );
  }
}
```

**Commit:** `feat: pass groupMembers through EditCourseScreenWire`

---

## Task 8: Update add-course-from-empty-cell flow

**File:** `lib/screens/schedule_screen.dart`

In `_addCourseAtCell`, check for existing courses in the cell before navigating:

```dart
void _addCourseAtCell(BuildContext context, int dayOfWeek, int startPeriod, int endPeriod) {
  final provider = context.read<CourseProvider>();
  final existing = provider.coursesForCell(dayOfWeek, startPeriod);
  
  if (existing.isNotEmpty) {
    // Cell already has courses → ask user
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('该时段已有课程'),
        content: Text('该时段已有${existing.length}门课，如何操作？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddToGroupOrNew(context, dayOfWeek, startPeriod, endPeriod, existing);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  } else {
    _navigateToNewCourse(context, dayOfWeek, startPeriod, endPeriod);
  }
}

void _showAddToGroupOrNew(BuildContext context, int dayOfWeek, int startPeriod, int endPeriod, List<Course> existing) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择操作', style: AppTypography.bodySemiBold),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('添加新课到该时段'),
              subtitle: Text('已有${existing.length}门课'),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToNewCourse(context, dayOfWeek, startPeriod, endPeriod);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑已有课程组'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => EditCourseScreen(groupMembers: existing),
                    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                    transitionDuration: const Duration(milliseconds: 200),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _navigateToNewCourse(BuildContext context, int dayOfWeek, int startPeriod, int endPeriod) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => EditCourseScreenWire(
        prefillDayOfWeek: dayOfWeek,
        prefillStartPeriod: startPeriod,
        prefillEndPeriod: endPeriod,
      ),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );
}
```

**Commit:** `feat: group-aware add-from-empty-cell flow`

---

## Task 9: Verification checklist

Run the app and verify:
- [ ] Empty cell tap → new course form → save creates course with unique groupId
- [ ] Empty cell tap when cell has existing courses → dialog asks for operation
- [ ] Long press on course in schedule → shows group menu with all members listed
- [ ] Group menu → "编辑课程组" opens editor with all members loaded
- [ ] Edit course screen with group → member tabs at top, form for active member
- [ ] "+ 添加课程" button in editor → adds new blank member form
- [ ] Remove member (swipe or X) → deletes that course on save
- [ ] Save validates overlapping weeks → shows error SnackBar
- [ ] Schedule grid shows only currently active course with dot for extras
- [ ] Existing solo courses still work (no regression)

---

## Implementation Order

Tasks must run sequentially (each depends on prior): 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9
