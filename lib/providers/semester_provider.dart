import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

/// State management for semester info and current week calculation.
class SemesterProvider extends ChangeNotifier {
  DateTime? _firstDay;
  int _currentWeek = 1;

  DateTime? get firstDay => _firstDay;
  int get currentWeek => _currentWeek;
  bool get isSet => _firstDay != null;

  /// Load saved semester first day.
  Future<void> load() async {
    _firstDay = await StorageService.getSemesterFirstDay();
    if (_firstDay != null) {
      _currentWeek = StorageService.calculateWeekNumber(_firstDay!);
    }
    notifyListeners();
  }

  /// Set the first day of the semester.
  Future<void> setFirstDay(DateTime date) async {
    _firstDay = DateTime(date.year, date.month, date.day);
    await StorageService.setSemesterFirstDay(_firstDay!);
    _currentWeek = StorageService.calculateWeekNumber(_firstDay!);
    notifyListeners();
    // Re-schedule notifications now that semester is set
    final courses = await StorageService.getAllCourses();
    if (courses.isNotEmpty) await NotificationService.scheduleAll(courses);
  }

  /// Recalculate current week number.
  void refreshWeek() {
    if (_firstDay != null) {
      _currentWeek = StorageService.calculateWeekNumber(_firstDay!);
      notifyListeners();
    }
  }

  /// Clear semester data (called when clearing all data).
  void reset() {
    _firstDay = null;
    _currentWeek = 1;
    notifyListeners();
  }
}
