import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import 'csv_parser.dart';

/// Storage service using SharedPreferences.
/// Works on web (Chrome) and mobile (Android/iOS).
///
/// Import flow:
///   User saves .xls as .csv in Excel/WPS → imports .csv file → accurate parse.
class StorageService {
  static const _coursesKey = 'courses_json';
  static const _semesterKey = 'semester_first_day';

  // ── Courses ──

  static Future<List<Course>> getAllCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_coursesKey);
    if (json == null || json.isEmpty) return [];
    final list = jsonDecode(json) as List<dynamic>;
    var needsSave = false;
    final result = <Course>[];
    for (final m in list) {
      final map = m as Map<String, dynamic>;
      // Migration: ensure groupId exists for existing courses
      final gid = map['groupId'] as String? ?? '';
      if (gid.isEmpty) {
        map['groupId'] = Course.newGroupId();
        needsSave = true;
      }
      result.add(Course.fromMap(map));
    }
    if (needsSave) {
      await _saveCourses(result);
    }
    return result;
  }

  static Future<Course?> getCourse(String id) async {
    final courses = await getAllCourses();
    try {
      return courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCourses(List<Course> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _coursesKey, jsonEncode(courses.map((c) => c.toMap()).toList()));
  }

  static Future<void> insertCourse(Course c) async {
    final cs = await getAllCourses();
    cs.removeWhere((x) => x.id == c.id);
    cs.add(c);
    await _saveCourses(cs);
  }

  static Future<void> insertCourses(List<Course> newCourses) async {
    final cs = await getAllCourses();
    for (final nc in newCourses) {
      cs.removeWhere((x) => x.id == nc.id);
      cs.add(nc);
    }
    await _saveCourses(cs);
  }

  static Future<void> updateCourse(Course c) async => await insertCourse(c);

  static Future<void> deleteCourse(String id) async {
    final cs = await getAllCourses();
    cs.removeWhere((x) => x.id == id);
    await _saveCourses(cs);
  }

  static Future<void> deleteAllCourses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coursesKey);
  }

  static Future<void> deleteAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coursesKey);
    await prefs.remove(_semesterKey);
  }

  // ── Semester ──

  static Future<void> setSemesterFirstDay(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final ds =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await prefs.setString(_semesterKey, ds);
  }

  static Future<DateTime?> getSemesterFirstDay() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_semesterKey);
    if (s == null) return null;
    return DateTime.parse(s);
  }

  static int calculateWeekNumber(DateTime firstDay) {
    final today = DateTime.now();
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final todayMonday = today.subtract(Duration(days: today.weekday - 1));
    return (todayMonday.difference(firstMonday).inDays ~/ 7) + 1;
  }

  // ── CSV Parsing ──

  /// Decode CSV bytes with encoding fallback:
  /// the教务平台 exports GBK-encoded CSVs; users may also save UTF-8.
  /// Try UTF-8 strictly first, fall back to GBK when invalid.
  static String decodeCsvText(List<int> bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      try {
        text = gbk.decode(bytes);
      } on FormatException {
        // Last resort: replace invalid sequences so parsing can still run.
        text = utf8.decode(bytes, allowMalformed: true);
      }
    }
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return text;
  }

  /// Parse CSV file bytes. Accepts:
  ///   1. UTF-8 CSV (Excel/WPS "Save As → CSV UTF-8")
  ///   2. GBK CSV (教务平台 original export encoding)
  static List<Course> parseXlsFromBytes(List<int> bytes) {
    return ScheduleCsvParser.parse(decodeCsvText(bytes));
  }

  static String? parseSemesterInfo(List<int> bytes) {
    return ScheduleCsvParser.extractSemesterInfo(decodeCsvText(bytes));
  }

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
}
