# Notification System Rewrite — Pre-class Reminder + Ongoing Banner

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans.

**Goal:** Replace the broken `periodicallyShow`-based notification system with `zonedSchedule` + `timezone`, achieving: pre-class reminder → ongoing banner (during class) → auto-dismiss (after class).
**Architecture:** Three `zonedSchedule` calls per course-week pair. Reminder uses `ongoing: false`. Ongoing banner uses `ongoing: true` (non-swipeable). Dismiss reuses the ongoing notification ID with `ongoing: false`, `priority: low`, silent — the Android notification framework replaces the old one, effectively "dismissing" the banner without running a line of Dart at dismissal time.
**Tech Stack:** flutter_local_notifications ^18.0.1 (zonedSchedule), timezone ^0.10.0, shared_preferences (existing)

---

## Why This Rewrite Is Necessary

The current code in `notification_service.dart` uses `_plugin.periodicallyShow(..., RepeatInterval.weekly)`. This API ignores the target date entirely — it starts repeating from the moment the function is called. If a user imports their schedule on Wednesday at 3pm, every notification fires "weekly on Wednesday at 3pm" instead of "Monday 7:45am for the 8:00 class." There is no workaround; `periodicallyShow` fundamentally cannot express "start repeating at this specific future date/time."

The correct API is `zonedSchedule`, which takes a `TZDateTime` for the first occurrence and uses `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` for weekly recurrence. This requires the `timezone` package (flutter_local_notifications hard-depends on it for `zonedSchedule`).

---

## Design Decisions (confirmed with user)

| Decision | Value |
|---|---|
| Pre-class reminder timing | Configurable (default 15 min), stored in SharedPreferences |
| Ongoing banner content | Course name + location + time range (e.g. "大学英语 · 教学楼A301 · 8:00~9:40") |
| Consecutive same-course periods | Each period is independent (not merged) |
| Ongoing dismissal mechanism | Same notification ID, replaced by silent low-priority notification at class end time |
| Reminder notification | Not ongoing, can be swiped away, with sound/vibration |
| Ongoing notification | `ongoing: true`, not swipable, `importance: low` (no sound on update) |
| Cancel notification | Same ID as ongoing, `ongoing: false`, `priority: min`, silent, no vibration |
| Notification IDs | Per (courseId, type, week) — hash-based |
| Android notification channel | Keep "课程提醒", `importance: high` for reminders |
| Boot recovery | Keep existing `_rescheduleIfNeeded()` pattern |

---

## Notification Timeline (per course-week)

```
  classStart - advanceMinutes   classStart              classEnd
       |                            |                       |
       ▼                            ▼                       ▼
  [Reminder]                   [Ongoing Banner]        [Silent Dismiss]
  ongoing: false               ongoing: true           ongoing: false
  has sound/vibrate            no sound               silent, priority:min
  swipeable                    NOT swipeable           swipeable
  ID: hash(id+reminder+week)   ID: hash(id+ongoing+week)  ID: same as ongoing
```

The dismiss notification overwrites the ongoing banner because they share the same notification ID — this is native Android behavior, no Dart code runs at dismissal time.

---

## File Changes Summary

| File | Action | Purpose |
|------|--------|---------|
| `pubspec.yaml` | Modify | Add `timezone: ^0.10.0` |
| `lib/services/notification_service.dart` | **Rewrite** | Full zonedSchedule-based implementation |
| `lib/main.dart` | Modify | Add timezone init; pass advanceMinutes callback |
| `lib/services/database_service.dart` | Modify | Add advanceMinutes read/write |
| `lib/screens/settings_screen.dart` | Modify | Add "提醒提前量" settings row |
| `lib/providers/course_provider.dart` | Modify | Update NotificationService API calls (scheduleAll signature changes) |
| `test/notification_service_test.dart` | **Rewrite** | Tests for new ID scheme, timing math, end times |
| (No Android manifest changes needed — permissions, receiver, channel already exist) |

---

## Task 1: Add timezone dependency

**File:** `pubspec.yaml` — modify `dependencies` block

Add after line 16 (`shared_preferences: ^2.3.3`):
```yaml
  timezone: ^0.10.0
```

Then run:
```bash
cd /sessions/stoic-serene-hawking/mnt/CCWORKING/course_schedule_app && flutter pub get
```

Expected: dependency resolves without conflicts.

**Commit:** `chore: add timezone dependency`

---

## Task 2: Add advanceMinutes storage to StorageService

**File:** `lib/services/database_service.dart` — modify

Add constant and two methods at the end of the class, before the closing `}`:

```dart
  // ── Notification Settings ──

  static const _advanceMinutesKey = 'notification_advance_minutes';

  static Future<int> getAdvanceMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_advanceMinutesKey) ?? 15;
  }

  static Future<void> setAdvanceMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_advanceMinutesKey, minutes);
  }
```

**Commit:** `feat: add advanceMinutes storage to StorageService`

---

## Task 3: Add "提醒提前量" row to Settings screen

**File:** `lib/screens/settings_screen.dart` — modify

Import at top:
```dart
import '../services/database_service.dart';
```

Add a new `SettingsCard` block in the `build` method Column children, after the "自定义" card and before "数据管理" card. Insert between the closing `),` of "自定义" SettingsCard and the `const SizedBox(height: AppSpacing.base),` before "数据管理":

```dart
                      const SizedBox(height: AppSpacing.base),

                      // ── 通知设置 ──
                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '提醒提前量',
                            value: '$_advanceMinutes分钟',
                            showChevron: true,
                            showDivider: false,
                            onTap: () => _pickAdvanceMinutes(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.base),

                      // ── 数据管理 ──
```

Add a state variable and init in `_SettingsScreenState`:

```dart
class _SettingsScreenState extends State<SettingsScreen> {
  int _advanceMinutes = 15;

  @override
  void initState() {
    super.initState();
    _loadAdvanceMinutes();
  }

  Future<void> _loadAdvanceMinutes() async {
    final m = await StorageService.getAdvanceMinutes();
    if (mounted) setState(() => _advanceMinutes = m);
  }
```

Reference `_advanceMinutes` in the value string (line shown above uses it directly).

Add the picker method to `_SettingsScreenState`:

```dart
  void _pickAdvanceMinutes(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('提醒提前量'),
        children: [5, 10, 15, 20, 30].map((m) {
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.setAdvanceMinutes(m);
              if (mounted) setState(() => _advanceMinutes = m);
            },
            child: Row(
              children: [
                Text('${m}分钟'),
                if (m == _advanceMinutes) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: AppColors.blue),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
```

No need to immediately reschedule notifications when the user changes this — notifications are already re-scheduled on every course CRUD operation, and the next CRUD will pick up the new value.

**Commit:** `feat: add advance minutes picker to settings`

---

## Task 4: Rewrite NotificationService

**File:** `lib/services/notification_service.dart` — full rewrite

This is the core change. Replace the entire file content:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/course.dart';
import '../services/database_service.dart';

/// Manages course push notifications — pre-class reminder + ongoing banner.
///
/// Three notifications per course-week pair:
///   1. Reminder (课前提醒): fires `advanceMinutes` before class start.
///      Swipeable, with sound/vibration.
///   2. Ongoing banner (上课常驻): fires at class start, `ongoing: true`.
///      Cannot be swiped away. Shows course name, location, time range.
///   3. Silent dismiss (下课消除): fires at class end, same ID as ongoing.
///      `ongoing: false`, `priority: min`, silent/no-vibration.
///      Overwrites the ongoing banner, making it dismissible.
///
/// Notification ID scheme:
///   reminderId = hash(courseId + '-reminder-' + week)
///   ongoingId  = hash(courseId + '-ongoing-'  + week)
///   dismiss reuses ongoingId
///
/// All scheduled via zonedSchedule with matchDateTimeComponents for
/// weekly recurrence.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'course_reminder';
  static const _channelName = '课程提醒';
  static const _channelDesc = '课前提醒与上课常驻通知';
  static const _notificationIcon = '@mipmap/ic_launcher';

  // Period → (start minute, end minute) of day
  static const _periodTimes = {
    1: (480, 580),    // 8:00–9:40
    3: (610, 710),    // 10:10–11:50
    5: (840, 940),    // 14:00–15:40
    7: (970, 1070),   // 16:10–17:50
    9: (1170, 1270),  // 19:30–21:10
  };

  // ─── Init ───

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidSettings =
        AndroidInitializationSettings(_notificationIcon);
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: _onTap);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(channel);

    await _rescheduleIfNeeded();
  }

  // ─── Public API ───

  /// Reschedule all notifications for the given courses.
  /// Call on: import, add, update, delete, load.
  static Future<void> scheduleAll(List<Course> courses) async {
    await _cancelAll();
    final firstDay = await StorageService.getSemesterFirstDay();
    if (firstDay == null) return;
    final advanceMinutes = await StorageService.getAdvanceMinutes();
    for (final c in courses) {
      await _scheduleCourse(c, firstDay, advanceMinutes);
    }
    await _saveTimestamp();
  }

  /// Cancel all scheduled notifications.
  static Future<void> cancelAll() async {
    await _cancelAll();
    await _saveTimestamp();
  }

  // ─── Tap handler ───

  static void _onTap(NotificationResponse response) {
    // Tapping notification opens the app (default behavior).
    // The MainActivity MethodChannel bringToForeground is kept
    // for compatibility but not strictly needed.
    try {
      // ignore: depend_on_referenced_packages
      import 'package:flutter/services.dart';
    } catch (_) {
      // MethodChannel not needed — notification tap opens app by default
    }
  }

  // ─── Internals: Scheduling ───

  static int _reminderId(String courseId, int week) =>
      ('$courseId-reminder-$week').hashCode.abs();

  static int _ongoingId(String courseId, int week) =>
      ('$courseId-ongoing-$week').hashCode.abs();

  static Future<void> _scheduleCourse(
      Course course, DateTime firstDay, int advanceMinutes) async {
    final times = _periodTimes[course.startPeriod];
    if (times == null) return;
    final (startMin, endMin) = times;

    // Reminder time: class start - advanceMinutes
    final reminderMin = startMin - advanceMinutes;
    final reminderHour = reminderMin ~/ 60;
    final reminderMinute = reminderMin % 60;

    // Class start time
    final startHour = startMin ~/ 60;
    final startMinute = startMin % 60;

    // Class end time
    final endHour = endMin ~/ 60;
    final endMinute = endMin % 60;

    // Compute first-occurrence base: semester Monday
    final semesterMonday =
        firstDay.subtract(Duration(days: firstDay.weekday - 1));

    final fromWeek = course.startWeek.clamp(1, 20);
    final toWeek = course.endWeek.clamp(1, 20);

    final dayOffset = course.dayOfWeek == 0 ? 6 : course.dayOfWeek - 1;

    for (int week = fromWeek; week <= toWeek; week++) {
      if (!course.isActiveInWeek(week)) continue;

      final courseDate = semesterMonday.add(
          Duration(days: (week - 1) * 7 + dayOffset));

      // ── 1. Reminder notification ──
      final reminderTime = tz.TZDateTime.local(
        courseDate.year, courseDate.month, courseDate.day,
        reminderHour, reminderMinute,
      );
      final rId = _reminderId(course.id, week);
      if (rId != 0) {
        await _plugin.zonedSchedule(
          rId,
          '课程提醒',
          '${course.name} · ${_fmt(startMin)} · ${course.location} · ${advanceMinutes}分钟后上课',
          reminderTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: _notificationIcon,
              visibility: NotificationVisibility.public,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }

      // ── 2. Ongoing banner ──
      final ongoingTime = tz.TZDateTime.local(
        courseDate.year, courseDate.month, courseDate.day,
        startHour, startMinute,
      );
      final oId = _ongoingId(course.id, week);
      if (oId != 0) {
        await _plugin.zonedSchedule(
          oId,
          '正在上课',
          '${course.name} · ${course.location} · ${_fmt(startMin)}~${_fmt(endMin)}',
          ongoingTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.low,        // no sound on ongoing
              priority: Priority.low,
              icon: _notificationIcon,
              ongoing: true,                      // cannot swipe away
              autoCancel: false,
              visibility: NotificationVisibility.public,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }

      // ── 3. Silent dismiss (same ID as ongoing → replaces it) ──
      final dismissTime = tz.TZDateTime.local(
        courseDate.year, courseDate.month, courseDate.day,
        endHour, endMinute,
      );
      if (oId != 0) {
        await _plugin.zonedSchedule(
          oId,                                // SAME ID as ongoing
          '课程已结束',
          '${course.name} · ${_fmt(startMin)}~${_fmt(endMin)}',
          dismissTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.min,       // silent, no heads-up
              priority: Priority.min,
              icon: _notificationIcon,
              ongoing: false,                   // now swipeable
              autoCancel: true,
              visibility: NotificationVisibility.public,
              playSound: false,
              enableVibration: false,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  // ─── Internals: Helpers ───

  static String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static Future<void> _cancelAll() async => await _plugin.cancelAll();

  // ─── Boot recovery ───

  static const _tsKey = 'notify_last_schedule';

  static Future<void> _saveTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tsKey, DateTime.now().toIso8601String());
  }

  static Future<void> _rescheduleIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tsKey);
    if (raw == null) return;
    final last = DateTime.tryParse(raw);
    if (last == null) return;
    if (DateTime.now().difference(last).inDays >= 1) {
      final courses = await StorageService.getAllCourses();
      if (courses.isNotEmpty) await scheduleAll(courses);
    }
  }
}
```

**Commit:** `feat: rewrite NotificationService with zonedSchedule for reminder+ongoing+dismiss`

---

## Task 5: Update main.dart — timezone init and dead import cleanup

**File:** `lib/main.dart` — modify

The `timezone` package needs initialization. Currently `NotificationService.init()` is called in main. The service now handles its own timezone init internally (see Task 4), so main.dart requires minimal changes.

The `_onTap` handler in the new NotificationService no longer uses MethodChannel (notifications opening the app is handled by flutter_local_notifications default behavior). We can optionally remove the `bringToForeground` code later, but it's harmless to keep in MainActivity.kt.

No changes needed to `main.dart` itself — `NotificationService.init()` is already called. Verify the import is still correct:

```dart
import 'services/notification_service.dart';
```

This line already exists at line 9. No changes needed to main.dart.

**Commit:** (skip — no changes needed; or fold into Task 4)

---

## Task 6: Rewrite unit tests

**File:** `test/notification_service_test.dart` — full rewrite

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';

void main() {
  group('NotificationService ID generation', () {
    // Reminder ID: hash(courseId + '-reminder-' + week)
    int reminderId(String courseId, int week) =>
        ('$courseId-reminder-$week').hashCode.abs();

    // Ongoing ID: hash(courseId + '-ongoing-' + week)
    int ongoingId(String courseId, int week) =>
        ('$courseId-ongoing-$week').hashCode.abs();

    test('reminder and ongoing IDs are different for same course+week', () {
      expect(reminderId('abc', 1), isNot(equals(ongoingId('abc', 1))));
    });

    test('different courses produce different ongoing IDs for same week', () {
      expect(ongoingId('abc', 1), isNot(equals(ongoingId('def', 1))));
    });

    test('same course different weeks produce different ongoing IDs', () {
      expect(ongoingId('abc', 3), isNot(equals(ongoingId('abc', 4))));
    });

    test('different courses produce different reminder IDs for same week', () {
      expect(reminderId('abc', 1), isNot(equals(reminderId('def', 1))));
    });

    test('same course different weeks produce different reminder IDs', () {
      expect(reminderId('abc', 3), isNot(equals(reminderId('abc', 4))));
    });

    test('no ID is ever zero (sentinel check)', () {
      final ids = <int>[];
      for (int w = 1; w <= 20; w++) {
        ids.add(reminderId('test', w));
        ids.add(ongoingId('test', w));
      }
      for (final id in ids) {
        expect(id, isNot(equals(0)),
            reason: 'Notification ID should never be 0');
      }
    });

    test('all IDs are positive', () {
      for (int w = 1; w <= 20; w++) {
        expect(reminderId('test', w), greaterThan(0));
        expect(ongoingId('test', w), greaterThan(0));
      }
    });
  });

  group('Period time constants', () {
    // Mirror of NotificationService._periodTimes
    const periodTimes = {
      1: (480, 580),    // 8:00–9:40
      3: (610, 710),    // 10:10–11:50
      5: (840, 940),    // 14:00–15:40
      7: (970, 1070),   // 16:10–17:50
      9: (1170, 1270),  // 19:30–21:10
    };

    test('period 1: 8:00–9:40', () {
      final (start, end) = periodTimes[1]!;
      expect(start ~/ 60, 8);
      expect(start % 60, 0);
      expect(end ~/ 60, 9);
      expect(end % 60, 40);
    });

    test('period 3: 10:10–11:50', () {
      final (start, end) = periodTimes[3]!;
      expect(start ~/ 60, 10);
      expect(start % 60, 10);
      expect(end ~/ 60, 11);
      expect(end % 60, 50);
    });

    test('period 5: 14:00–15:40', () {
      final (start, end) = periodTimes[5]!;
      expect(start ~/ 60, 14);
      expect(start % 60, 0);
      expect(end ~/ 60, 15);
      expect(end % 60, 40);
    });

    test('period 7: 16:10–17:50', () {
      final (start, end) = periodTimes[7]!;
      expect(start ~/ 60, 16);
      expect(start % 60, 10);
      expect(end ~/ 60, 17);
      expect(end % 60, 50);
    });

    test('period 9: 19:30–21:10', () {
      final (start, end) = periodTimes[9]!;
      expect(start ~/ 60, 19);
      expect(start % 60, 30);
      expect(end ~/ 60, 21);
      expect(end % 60, 10);
    });

    test('reminder time with default 15min advance: period 1 → 7:45', () {
      final (start, _) = periodTimes[1]!;
      const advance = 15;
      final notifyMin = start - advance;
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 45);
    });

    test('reminder time with 10min advance: period 1 → 7:50', () {
      final (start, _) = periodTimes[1]!;
      const advance = 10;
      final notifyMin = start - advance;
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 50);
    });

    test('reminder time with 30min advance: period 5 (14:00) → 13:30', () {
      final (start, _) = periodTimes[5]!;
      const advance = 30;
      final notifyMin = start - advance;
      expect(notifyMin ~/ 60, 13);
      expect(notifyMin % 60, 30);
    });
  });
}
```

Run tests:
```bash
cd /sessions/stoic-serene-hawking/mnt/CCWORKING/course_schedule_app && flutter test
```

Expected: all tests pass.

**Commit:** `test: rewrite notification tests for reminder+ongoing+dismiss ID scheme`

---

## Task 7: Build and verify on device

Steps:
1. `cd /sessions/stoic-serene-hawking/mnt/CCWORKING/course_schedule_app`
2. `flutter pub get`
3. `flutter run` (connect device or emulator)
4. Import a CSV course schedule (or add a course manually)
5. Verify notification channel appears: Settings → Apps → course_schedule_app → Notifications → "课程提醒"
6. Check scheduled alarms: `adb shell dumpsys alarm | grep -i course`
7. Verify scheduled notifications are listed: `adb shell dumpsys notification | grep course_schedule_app`
8. Set phone time to 1 minute before a scheduled class → verify reminder fires
9. Set phone time to class start → verify ongoing banner appears
10. Set phone time to class end → verify ongoing banner becomes dismissible

**Commit:** (no code changes, just verification)

---

## Execution Order

1. Task 1 — Add timezone dependency, `flutter pub get`
2. Task 2 — Add advanceMinutes storage
3. Task 3 — Add settings UI for advance minutes
4. Task 4 — Rewrite NotificationService (core change)
5. Task 5 — Verify main.dart (no changes needed)
6. Task 6 — Rewrite tests, run `flutter test`
7. Task 7 — Build and device test

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `zonedSchedule` can only schedule up to ~500 notifications on some Android versions | Each course × week generates 2 unique IDs + 1 reuse (ongoing+dimiss share). For 20 courses × avg 8 active weeks = 160 course-week pairs → 320 unique IDs + 160 reuse → ~480 zonedSchedule calls. Close to the limit. Mitigation: if we hit scheduling errors, we can reduce by collapsing single-week courses into `periodicallyShow` (correct start time doesn't matter as much for 1-week courses). **Monitor during device test.** |
| `timezone` package requires timezone database init | Done in `NotificationService.init()` — `tz_data.initializeTimeZones()` loads the full db, `tz.setLocalLocation(tz.local)` detects the device timezone. This is the standard approach. |
| Notification dismiss at class end replaces ongoing but leaves a swipeable notification | This is intentional — the user sees "课程已结束" and can swipe it away. `autoCancel: true` means tapping it also removes it. |
| Timezone detection may be wrong if device timezone is changed after scheduling | The `rescheduleIfNeeded` boot/timestamp check will catch this on next app launch. |
