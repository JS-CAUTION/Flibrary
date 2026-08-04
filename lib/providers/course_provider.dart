import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

/// State management for courses.
class CourseProvider extends ChangeNotifier {
  List<Course> _courses = [];
  bool _loaded = false;

  List<Course> get courses => List.unmodifiable(_courses);
  bool get loaded => _loaded;

  /// Filter courses for a specific day of week and week number.
  List<Course> coursesForDayAndWeek(int dayOfWeek, int week) {
    return _courses
        .where((c) {
          return c.dayOfWeek == dayOfWeek && c.isActiveInWeek(week);
        })
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
  }

  /// Get courses for today's day-of-week and given week number.
  List<Course> coursesForToday(int week) {
    final today = DateTime.now();
    final dayOfWeek = today.weekday % 7; // Sun=0
    return coursesForDayAndWeek(dayOfWeek, week);
  }

  /// Get a course by ID.
  Course? getCourse(String id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Load all courses from storage.
  Future<void> loadCourses() async {
    _courses = await StorageService.getAllCourses();
    _loaded = true;
    notifyListeners();
    // Re-schedule notifications after load (e.g. app just launched)
    NotificationService.scheduleAll(_courses);
  }

  /// Add a new course.
  Future<void> addCourse(Course course) async {
    await StorageService.insertCourse(course);
    _courses.removeWhere((c) => c.id == course.id);
    _courses.add(course);
    notifyListeners();
    NotificationService.scheduleAll(_courses);
  }

  /// Import multiple courses (from CSV).
  Future<void> importCourses(List<Course> courses) async {
    await StorageService.insertCourses(courses);
    for (final newCourse in courses) {
      _courses.removeWhere((c) => c.id == newCourse.id);
      _courses.add(newCourse);
    }
    notifyListeners();
    NotificationService.scheduleAll(_courses);
  }

  /// Update an existing course.
  Future<void> updateCourse(Course course) async {
    await StorageService.updateCourse(course);
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) _courses[index] = course;
    notifyListeners();
    NotificationService.scheduleAll(_courses);
  }

  /// Delete a course by ID.
  Future<void> deleteCourse(String id) async {
    await StorageService.deleteCourse(id);
    _courses.removeWhere((c) => c.id == id);
    notifyListeners();
    NotificationService.scheduleAll(_courses);
  }

  /// Clear all courses.
  Future<void> clearAllCourses() async {
    await StorageService.deleteAllCourses();
    _courses.clear();
    notifyListeners();
    NotificationService.cancelAll();
  }

  // ── Course Groups ──

  /// Get all courses sharing the same cell (dayOfWeek + startPeriod).
  List<Course> coursesForCell(int dayOfWeek, int startPeriod) {
    return _courses
        .where((c) => c.dayOfWeek == dayOfWeek && c.startPeriod == startPeriod)
        .toList()
      ..sort((a, b) => a.startWeek.compareTo(b.startWeek));
  }

  /// Get all members of a course group, sorted by startWeek.
  List<Course> groupMembers(String groupId) {
    if (groupId.isEmpty) return [];
    return _courses.where((c) => c.groupId == groupId).toList()
      ..sort((a, b) => a.startWeek.compareTo(b.startWeek));
  }

  /// Validate: no overlapping weeks within a group.
  /// Returns null if OK, or an error message describing the overlap.
  String? validateGroupWeeks(List<Course> groupCourses) {
    final sorted = List<Course>.from(groupCourses)
      ..sort((a, b) => a.startWeek.compareTo(b.startWeek));
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i].endWeek >= sorted[i + 1].startWeek) {
        return '${sorted[i].name}(${sorted[i].weekText}) 与 ${sorted[i + 1].name}(${sorted[i + 1].weekText}) 周次重叠';
      }
    }
    return null;
  }
}
