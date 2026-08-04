import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/course.dart';
import '../services/database_service.dart';
import '../services/native_alarm_service.dart';
import '../services/foreground_service_manager.dart';

/// Manages course push notifications using periodic polling instead of AlarmManager.
///
/// A Dart Timer fires every ~30 seconds, checks the current time against the
/// course schedule, and posts/updates notifications through the native channel.
/// A persistent Foreground Service keeps the Dart isolate running when the app
/// is in the background on aggressive OEM firmware (vivo, Oppo, Xiaomi).
///
/// Architecture:
///   - Reminder: posted at (class start - advanceMinutes), non-swipeable
///   - Ongoing: posted at class start, overwrites reminder (same notifyId)
///   - Dismiss: posted at class end, overwrites ongoing (same notifyId)
class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelOngoingId = 'course_ongoing';
  static const _channelServiceId = 'course_service';
  static const _iconRes = 'ic_launcher';
  static const _pollInterval = Duration(seconds: 30);

  static bool _serviceStarted = false;
  static Timer? _pollTimer;
  static List<Course> _courses = [];
  static DateTime? _firstDay;
  static int _advanceMinutes = 15;

  // Track which notification state each course is currently showing, per week.
  // null = nothing shown; "reminder" / "ongoing" / "dismiss" = active.
  static final Map<String, String?> _activeNotification = {};

  // ─── Init ───

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: _onTap);

    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    // Course notifications channel
    const ongoingChannel = AndroidNotificationChannel(
      _channelOngoingId,
      '上课常驻',
      description: '上课期间常驻通知栏',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    await androidPlugin?.createNotificationChannel(ongoingChannel);

    await _rescheduleIfNeeded();
  }

  // ─── Public API ───

  static Future<void> scheduleAll(List<Course> courses) async {
    _courses = courses;
    _firstDay = await StorageService.getSemesterFirstDay();
    _advanceMinutes = await StorageService.getAdvanceMinutes();
    await _startPolling();
  }

  static Future<void> cancelAll() async {
    _stopPolling();
    _activeNotification.clear();
  }

  // ─── Tap handler ───

  static void _onTap(NotificationResponse response) {}

  // ─── Internals: IDs / helpers ───

  static int _reminderId(String courseId, int week) =>
      ('$courseId-reminder-$week').hashCode.abs();

  static int _ongoingId(String courseId, int week) =>
      ('$courseId-ongoing-$week').hashCode.abs();

  static int _dismissId(String courseId, int week) =>
      ('$courseId-dismiss-$week').hashCode.abs();

  static int _toEpochMs(DateTime dt) => dt.millisecondsSinceEpoch;

  static String _stateKey(String courseId, int week) => '$courseId-$week';

  static String _body(
      String name, String timeStr, String location, String suffix) {
    final parts = [name, timeStr];
    if (location.isNotEmpty) parts.add(location);
    if (suffix.isNotEmpty) parts.add(suffix);
    return parts.join(' · ');
  }

  // ─── Polling ───

  static Future<void> _startPolling() async {
    _pollTimer?.cancel();

    // Start foreground service first so it anchors the notification bar,
    // then course notifications stack on top.
    if (!_serviceStarted) {
      _serviceStarted = true;
      await ForegroundServiceManager.start();
      // Give Android time to spin up the Service and post its notification
      // before we fire course notifications via fireImmediate.
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _checkSchedule();

    // Align the periodic timer to wall-clock :00 and :30 seconds
    // so reminders fire at precise times (±0.2s) rather than up to 30s late.
    final now = DateTime.now();
    final offset = now.second % 30;
    final msToBoundary = (30 - offset) * 1000 - now.millisecond;
    final delay = msToBoundary > 0 ? msToBoundary : 30000;

    _pollTimer = Timer(Duration(milliseconds: delay), () {
      _checkSchedule();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _checkSchedule());
    });
  }

  static void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_serviceStarted) {
      _serviceStarted = false;
      ForegroundServiceManager.stop();
    }
  }

  static void _checkSchedule() {
    if (_firstDay == null || _courses.isEmpty) return;

    final now = DateTime.now();
    final semesterMonday =
        _firstDay!.subtract(Duration(days: _firstDay!.weekday - 1));

    for (final course in _courses) {
      final slot = TimeSlot.forPeriod(course.startPeriod);
      if (slot == null) continue;

      final startMin = slot.startMinuteOfDay;
      final endMin = slot.endMinuteOfDay;
      final reminderMin = startMin - _advanceMinutes;
      final dayOffset = course.dayOfWeek == 0 ? 6 : course.dayOfWeek - 1;

      final fromWeek = course.startWeek.clamp(1, 20);
      final toWeek = course.endWeek.clamp(1, 20);

      for (int week = fromWeek; week <= toWeek; week++) {
        if (!course.isActiveInWeek(week)) continue;

        final courseDate = semesterMonday.add(
            Duration(days: (week - 1) * 7 + dayOffset));

        final reminderDt = DateTime(
          courseDate.year, courseDate.month, courseDate.day,
          reminderMin ~/ 60, reminderMin % 60,
        );
        final startDt = DateTime(
          courseDate.year, courseDate.month, courseDate.day,
          startMin ~/ 60, startMin % 60,
        );
        final endDt = DateTime(
          courseDate.year, courseDate.month, courseDate.day,
          endMin ~/ 60, endMin % 60,
        );

        final key = _stateKey(course.id, week);
        final currentState = _activeNotification[key];
        final oId = _ongoingId(course.id, week);

        if (now.isAfter(endDt) || now.isAtSameMomentAs(endDt)) {
          // After class — cancel the notification card.
          if (currentState != null) {
            NativeAlarmService.cancelNotification(oId);
          }
          _activeNotification.remove(key);
        } else if (now.isAfter(startDt) || now.isAtSameMomentAs(startDt)) {
          // In class — show ongoing banner.
          if (currentState != "ongoing") {
            _fireNotification(
              id: oId,
              notifyId: oId,
              title: '正在上课',
              body: _body(course.name, '${slot.startTime}~${slot.endTime}',
                  course.location, ''),
            );
            _activeNotification[key] = "ongoing";
          }
        } else if (now.isAfter(reminderDt) ||
            now.isAtSameMomentAs(reminderDt)) {
          // Before class — show reminder.
          if (currentState != "reminder") {
            _fireNotification(
              id: _reminderId(course.id, week),
              notifyId: oId,
              title: '课程提醒',
              body: _body(course.name, slot.startTime, course.location, '即将上课'),
            );
            _activeNotification[key] = "reminder";
          }
        } else {
          // Out of class range — no notification.
          _activeNotification.remove(key);
        }
      }
    }
  }

  static Future<void> _fireNotification({
    required int id,
    required int notifyId,
    required String title,
    required String body,
  }) async {
    await NativeAlarmService.fireImmediate(
      id: id,
      notifyId: notifyId,
      title: title,
      body: body,
    );
  }

  // ─── Boot recovery ───

  static Future<void> _rescheduleIfNeeded() async {
    final courses = await StorageService.getAllCourses();
    if (courses.isNotEmpty) await scheduleAll(courses);
  }
}
