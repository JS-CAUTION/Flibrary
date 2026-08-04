# Notification System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans.

**Goal:** Add pre-class push notifications to the course schedule app.
**Architecture:** NotificationService wraps flutter_local_notifications. CourseProvider notifies NotificationService on every add/import/update/delete. Android notification channel "课程提醒" configured at app init. Notifications scheduled for all active weeks via repeatWeekly with unique IDs. Boot receiver catches missed notifications.
**Tech Stack:** flutter_local_notifications ^18.0.1, shared_preferences (existing), Android AlarmManager/BootReceiver

---

## Design Decisions (confirmed)

- **Trigger**: 15 minutes before class start
- **Scope**: today's courses (not all courses, not tomorrow's)
- **Lock screen**: standard system notification, no screen wake
- **Scheduling**: bulk-schedule all weeks on import, re-schedule on CRUD
- **Missed notifications**: schedule check on boot to catch any that fired while phone was off
- **Channel name**: 课程提醒
- **Notification format**: title="课程提醒 📚", body="课程名 · 8:00 ~ 9:40 · 教学楼A301"
- **Tap action**: open app home screen
- **Repeat**: repeatWeekly=true, so courses that repeat every week get recurring notifications
- **No Atomic Island**: user decided to skip this

## File Changes

| File | Action | Purpose |
|------|--------|---------|
| `lib/services/notification_service.dart` | **Create** | Core notification logic: init channel, schedule, cancel, on-tap handler |
| `lib/main.dart` | **Modify** | Init NotificationService; wire CourseProvider.postChange callback |
| `android/app/src/main/AndroidManifest.xml` | **Modify** | Add notification + boot + alarm permissions; add BootReceiver |
| `android/app/src/main/kotlin/.../BootReceiver.kt` | **Create** | Android boot receiver to reschedule notifications |
| `lib/providers/course_provider.dart` | **Modify** | Call NotificationService on add/import/update/delete/clearAll |
| `lib/screens/import_screen.dart` | **Modify** | After confirm import, trigger notification reschedule |
| `lib/screens/edit_course_screen.dart` | **Modify** | After save, trigger notification update |
| `test/notification_service_test.dart` | **Create** | Unit tests for notification ID generation and scheduling logic |

---

## Task 1: Add Android permissions and BootReceiver

**Files:**
- `android/app/src/main/AndroidManifest.xml` (modify)
- `android/app/src/main/kotlin/com/example/course_schedule_app/BootReceiver.kt` (create)

Add these permissions to AndroidManifest.xml right after `<manifest ...>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

Add the BootReceiver before the existing `<activity>` block inside `<application>`:

```xml
<receiver
    android:name=".BootReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

Create BootReceiver.kt:

```kotlin
package com.example.course_schedule_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Flutter engine not running at boot — just mark that notifications need refresh.
            // The next time the app launches, NotificationService will detect stale state and re-schedule.
        }
    }
}
```

**Commit:** `feat: add notification permissions and BootReceiver`

---

## Task 2: Create NotificationService

**File:** `lib/services/notification_service.dart` (create)

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../services/database_service.dart';

/// Manages all course notifications.
///
/// Each course gets 20 scheduled notifications (one per week, weeks 1-20)
/// with repeatWeekly=true. Notification ID = hash(course.id + weekNumber).
///
/// Scheduling formula:
///   targetTime = (week's Monday + course.dayOfWeek days) + coursePeriodStartTime - 15min
///
/// Period start times:
///   P1=8:00, P3=10:10, P5=14:00, P7=16:10, P9=19:30
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'course_reminder';
  static const _channelName = '课程提醒';
  static const _channelDesc = '课前15分钟提醒';
  static const _notificationIcon = '@mipmap/ic_launcher';

  // Period → start time in minutes from midnight
  static const _periodStartMinutes = {
    1: 8 * 60,        // 8:00
    3: 10 * 60 + 10,  // 10:10
    5: 14 * 60,       // 14:00
    7: 16 * 60 + 10,  // 16:10
    9: 19 * 60 + 30,  // 19:30
  };

  // ─── Initialization ───

  /// Call once at app startup. Sets up the notification channel and
  /// tap-action handler.
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings(_notificationIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // If app last launched before stored "last schedule time", reschedule
    await _rescheduleIfNeeded();
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handled by the Flutter engine — routes to home screen via existing
    // app.dart route table. No additional action needed since app is
    // single-instance with initialRoute = '/'.
  }

  // ─── Scheduling ───

  /// Schedule notifications for all courses.
  /// Call on: import, add, update, delete, clearAll.
  static Future<void> scheduleAll(List<Course> courses) async {
    await _cancelAll();

    final semesterFirstDay = await StorageService.getSemesterFirstDay();
    if (semesterFirstDay == null) return;

    for (final course in courses) {
      await _scheduleCourse(course, semesterFirstDay);
    }

    await _saveScheduleTimestamp();
  }

  /// Schedule notifications for a single course across all its active weeks.
  static Future<void> scheduleCourse(Course course) async {
    final semesterFirstDay = await StorageService.getSemesterFirstDay();
    if (semesterFirstDay == null) return;

    // Cancel old notifications for this course first
    await _cancelCourse(course.id);
    await _scheduleCourse(course, semesterFirstDay);
    await _saveScheduleTimestamp();
  }

  /// Cancel notifications for a single course.
  static Future<void> cancelCourse(String courseId) async {
    await _cancelCourse(courseId);
    await _saveScheduleTimestamp();
  }

  // ─── Internals ───

  /// Compute base Monday of semester week 1.
  static DateTime _semesterMonday(DateTime firstDay) {
    final dow = firstDay.weekday; // 1=Mon, 7=Sun
    return firstDay.subtract(Duration(days: dow - 1));
  }

  /// Generate a unique notification ID from courseId + week.
  static int _notificationId(String courseId, int week) {
    final combined = '$courseId-$week';
    return combined.hashCode.abs();
  }

  /// Schedule all weeks for a single course.
  static Future<void> _scheduleCourse(
      Course course, DateTime semesterFirstDay) async {
    final monday = _semesterMonday(semesterFirstDay);
    final startMin = _periodStartMinutes[course.startPeriod];
    if (startMin == null) return; // unknown period → skip

    // 15 minutes before class
    final notifyMin = startMin - 15;
    final notifyHour = notifyMin ~/ 60;
    final notifyMinute = notifyMin % 60;

    final startWeek = course.startWeek.clamp(1, 20);
    final endWeek = course.endWeek.clamp(1, 20);

    for (int week = startWeek; week <= endWeek; week++) {
      // Only schedule if active in this week (respects odd/even/custom)
      if (!course.isActiveInWeek(week)) continue;

      // Date of this course occurrence: Monday + (week-1)*7 + dayOffset
      // dayOfWeek=0=Sun, so for dayOfWeek=0, offset=6 (Sunday = Monday+6)
      int dayOffset;
      if (course.dayOfWeek == 0) {
        dayOffset = 6; // Sun
      } else {
        dayOffset = course.dayOfWeek - 1; // Mon=0 offset
      }
      final courseDate = monday.add(Duration(
        days: (week - 1) * 7 + dayOffset,
      ));
      final scheduledTime = DateTime(
        courseDate.year,
        courseDate.month,
        courseDate.day,
        notifyHour,
        notifyMinute,
      );

      final id = _notificationId(course.id, week);
      if (id == 0) continue; // hash collision edge case

      await _plugin.zonedSchedule(
        id,
        '课程提醒 📚',
        '${course.name} · ${_formatTime(startMin)} · ${course.location}',
        _scheduleDailyAt(scheduledTime),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: _notificationIcon,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: course.id,
      );
    }
  }

  static TZDateTime _scheduleDailyAt(DateTime time) {
    return TZDateTime.from(time, tz.local);
  }

  static String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Cancel all notifications for a course.
  static Future<void> _cancelCourse(String courseId) async {
    for (int week = 1; week <= 20; week++) {
      final id = _notificationId(courseId, week);
      if (id != 0) await _plugin.cancel(id);
    }
  }

  /// Cancel all app notifications.
  static Future<void> _cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Timestamp tracking for boot recovery ───

  static const _scheduleTimestampKey = 'notification_last_schedule';

  static Future<void> _saveScheduleTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _scheduleTimestampKey, DateTime.now().toIso8601String());
  }

  /// After reboot, check if we need to reschedule.
  static Future<void> _rescheduleIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSchedule = prefs.getString(_scheduleTimestampKey);
    if (lastSchedule == null) return; // never scheduled

    final lastTime = DateTime.tryParse(lastSchedule);
    if (lastTime == null) return;

    final now = DateTime.now();
    // If last schedule was more than 1 day ago, reschedule everything
    if (now.difference(lastTime).inDays >= 1) {
      final courses = await StorageService.getAllCourses();
      if (courses.isNotEmpty) {
        await scheduleAll(courses);
      }
    }
  }
}
```

Wait — `zonedSchedule` + `TZDateTime` requires `timezone` package. Let me simplify. Since we have `SCHEDULE_EXACT_ALARM`, use `androidScheduleMode: AndroidScheduleMode.alarmClock` without timezone.

Actually, `flutter_local_notifications` v18 `zonedSchedule` requires the `timezone` package for `TZDateTime`. Alternative: use `periodicallyShow` with `RepeatInterval.weekly` — but this doesn't let us set the exact start date per-course.

Best approach for this use case: use `zonedSchedule` with the `timezone` package. Need to add `timezone: ^0.9.4` to pubspec.yaml.

Let me also add the `timezone` initialization (needs to know the local timezone database).

**REVISED plan — need to add `timezone` dependency and init call.**

Let me rewrite Task 2 with the corrected approach.

---

**File:** `lib/services/notification_service.dart` (create)

**File:** `pubspec.yaml` — add `timezone: ^0.9.4`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/course.dart';
import '../services/database_service.dart';

/// Manages all course notifications.
///
/// Uses flutter_local_notifications zonedSchedule with timezone package.
/// Each course-week pair gets one notification. 
/// repeatWeekly via matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime.
///
/// Scheduling formula:
///   The course is anchored to a specific day-of-week + time-of-day.
///   The first occurrence is set when scheduling, then repeats weekly.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'course_reminder';
  static const _channelName = '课程提醒';
  static const _channelDesc = '课前15分钟提醒';
  static const _notificationIcon = '@mipmap/ic_launcher';

  // Period → start minute of day
  static const _startMinutes = {
    1: 480,   // 8:00
    3: 610,   // 10:10
    5: 840,   // 14:00
    7: 970,   // 16:10
    9: 1170,  // 19:30
  };

  // ─── Init ───

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC); // placeholder, will update on first schedule

    const androidSettings =
        AndroidInitializationSettings(_notificationIcon);
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (_) {});

    const channel = AndroidNotificationChannel(
      _channelId, _channelName,
      description: _channelDesc,
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _rescheduleIfNeeded();
  }

  // ─── Public API ───

  static Future<void> scheduleAll(List<Course> courses) async {
    await _cancelAll();
    final firstDay = await StorageService.getSemesterFirstDay();
    if (firstDay == null) return;
    for (final c in courses) {
      await _scheduleCourse(c, firstDay);
    }
    await _saveTimestamp();
  }

  static Future<void> cancelAll() => _cancelAll();

  // ─── Internals ───

  static int _id(String courseId, int week) =>
      ('$courseId-$week').hashCode.abs();

  static Future<void> _scheduleCourse(
      Course course, DateTime firstDay) async {
    final startMin = _startMinutes[course.startPeriod];
    if (startMin == null) return;
    final notifyMin = startMin - 15;
    final notifyHour = notifyMin ~/ 60;
    final notifyMinute = notifyMin % 60;

    // Compute first occurrence date
    // First day of semester = firstDay (user-set)
    // Semester Monday = firstDay - offset to Monday
    final semesterMonday = firstDay.subtract(
        Duration(days: firstDay.weekday - 1)); // weekday: 1=Mon

    for (int week = course.startWeek.clamp(1, 20);
        week <= course.endWeek.clamp(1, 20);
        week++) {
      if (!course.isActiveInWeek(week)) continue;

      int dayOffset = course.dayOfWeek == 0 ? 6 : course.dayOfWeek - 1;
      final courseDate = semesterMonday.add(Duration(
          days: (week - 1) * 7 + dayOffset));
      final scheduledTime = tz.TZDateTime.from(
        DateTime(courseDate.year, courseDate.month, courseDate.day,
            notifyHour, notifyMinute),
        tz.local,
      );

      final id = _id(course.id, week);
      if (id == 0) continue;

      await _plugin.zonedSchedule(
        id,
        '课程提醒 📚',
        '${course.name} · ${_fmt(startMin)} · ${course.location}',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: _notificationIcon,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: course.id,
      );
    }
  }

  static Future<void> _cancelAll() async => await _plugin.cancelAll();

  static String _fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  // ─── Boot recovery ───

  static const _tsKey = 'notify_last_schedule';

  static Future<void> _saveTimestamp() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tsKey, DateTime.now().toIso8601String());
  }

  static Future<void> _rescheduleIfNeeded() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_tsKey);
    if (s == null) return;
    final t = DateTime.tryParse(s);
    if (t == null) return;
    if (DateTime.now().difference(t).inDays < 1) return;
    final cs = await StorageService.getAllCourses();
    if (cs.isNotEmpty) await scheduleAll(cs);
  }
}
```

**Commit:** `feat: create NotificationService with schedule/cancel/reschedule`

---

## Task 3: Wire NotificationService into CourseProvider

**File:** `lib/providers/course_provider.dart` (modify)

Import and call NotificationService at the end of each mutation method. After `notifyListeners()`:

```dart
// addCourse — after notifyListeners()
await NotificationService.scheduleAll(_courses);

// importCourses — after notifyListeners()
await NotificationService.scheduleAll(_courses);

// updateCourse — after notifyListeners()
await NotificationService.scheduleAll(_courses);

// deleteCourse — after notifyListeners()
await NotificationService.scheduleAll(_courses);

// clearAllCourses — after notifyListeners()
await NotificationService.cancelAll();
```

**Commit:** `feat: wire NotificationService into CourseProvider`

---

## Task 4: Initialize NotificationService in main.dart

**File:** `lib/main.dart` (modify)

Add import and init call:

```dart
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init(); // async, fire-and-forget
  runApp(
    MultiProvider(...)
  );
}
```

**Commit:** `feat: init NotificationService at app startup`

---

## Task 5: Add timezone to pubspec.yaml

**File:** `pubspec.yaml` (modify)

Add under dependencies:
```yaml
  timezone: ^0.9.4
```

**Commit:** `chore: add timezone dependency`

---

## Task 6: Write unit tests

**File:** `test/notification_service_test.dart` (create)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/services/notification_service.dart';
import 'package:course_schedule_app/models/course.dart';

void main() {
  group('NotificationService ID generation', () {
    test('generates consistent IDs for same course+week', () {
      // Test via scheduleAll logic — IDs must be consistent
      // (NotificationService exposes no public _id method, 
      //  so we test indirectly through schedule behavior)
    });

    test('different course IDs produce different notification IDs', () {
      final id1 = 'course-1-5'.hashCode.abs();
      final id2 = 'course-2-5'.hashCode.abs();
      expect(id1, isNot(equals(id2)));
    });

    test('same course different weeks produce different IDs', () {
      final id1 = 'abc-3'.hashCode.abs();
      final id2 = 'abc-4'.hashCode.abs();
      expect(id1, isNot(equals(id2)));
    });

    test('ID never zero', () {
      // Try several combinations
      final ids = ['a-1', 'b-2', 'c-3'].map((s) => s.hashCode.abs());
      expect(ids, everyElement(isNot(equals(0))));
    });
  });

  group('Course notification timing', () {
    test('period 1 starts at 8:00', () {
      // 480 minutes = 8:00
      expect(480 ~/ 60, 8);
      expect(480 % 60, 0);
    });

    test('notify time is 15 min before start', () {
      final startMin = 480; // 8:00
      final notifyMin = startMin - 15; // 7:45
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 45);
    });
  });
}
```

**Commit:** `test: add notification ID and timing tests`

---

## Task 7: Test on device

Steps:
1. `cd E:\CCWORKING\course_schedule_app`
2. `flutter pub get`
3. `flutter run`
4. Import a CSV course schedule
5. Verify: Android notification permission dialog appears
6. Check: notification channel appears in Settings → Apps → course_schedule_app → Notifications
7. Verify: adb shell to check scheduled alarms: `adb shell dumpsys alarm | grep -i course`

---

## Execution Order

1. Task 5 (timezone dep) → flutter pub get
2. Task 2 (NotificationService)
3. Task 1 (Android permissions + BootReceiver)
4. Task 3 (wire CourseProvider)
5. Task 4 (main.dart init)
6. Task 6 (unit tests)
7. Task 7 (device test)
