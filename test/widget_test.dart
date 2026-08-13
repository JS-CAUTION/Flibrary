import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';
import 'package:course_schedule_app/models/background_preset.dart';
import 'package:course_schedule_app/services/csv_parser.dart';

void main() {
  group('Course model', () {
    test('fromMap/toMap round-trip', () {
      final course = Course(
        id: 'test-1',
        name: '高等数学',
        teacher: '张老师(教授)',
        location: '教A301',
        dayOfWeek: 1,
        startPeriod: 1,
        endPeriod: 2,
        startWeek: 1,
        endWeek: 16,
        colorIndex: 0,
        weekMode: WeekMode.all,
      );
      final map = course.toMap();
      final restored = Course.fromMap(map);
      expect(restored.name, '高等数学');
      expect(restored.dayOfWeek, 1);
      expect(restored.isActiveInWeek(1), true);
      expect(restored.isActiveInWeek(17), false);
    });

    test('WeekMode odd/even', () {
      final odd = Course(
        id: 'o', name: 'T', teacher: '', location: '',
        dayOfWeek: 1, startPeriod: 1, endPeriod: 2,
        startWeek: 1, endWeek: 16, weekMode: WeekMode.odd);
      expect(odd.isActiveInWeek(1), true);
      expect(odd.isActiveInWeek(2), false);
    });

    test('copyWith does not share mutable list', () {
      final a = Course(
        id: 'a', name: 'A', teacher: '', location: '',
        dayOfWeek: 1, startPeriod: 1, endPeriod: 2,
        startWeek: 1, endWeek: 16, customWeeks: [1, 3, 5]);
      final b = a.copyWith(customWeeks: [2, 4]);
      expect(b.customWeeks, [2, 4]);
      expect(a.customWeeks, [1, 3, 5]); // original unchanged
    });
  });

  group('BackgroundPreset model', () {
    test('toMap/fromMap round-trip', () {
      final preset = BackgroundPreset(
        name: '测试',
        circles: [
          CircleConfig(x: 10, y: 20, width: 100, height: 100, radius: 50, colorValue: 0xFFFF0000),
        ],
        imagePath: '/tmp/test.jpg',
        imageScale: 1.5,
        imageOffsetX: 0.1,
        imageOffsetY: -0.2,
        imageOriginalW: 1920,
        imageOriginalH: 1080,
      );
      final map = preset.toMap();
      final restored = BackgroundPreset.fromMap(map);
      expect(restored.name, '测试');
      expect(restored.imageScale, 1.5);
      expect(restored.imageOriginalW, 1920);
      expect(restored.circles.length, 1);
      expect(restored.circles[0].colorValue, 0xFFFF0000);
    });

    test('defaultPreset has 3 circles and is active', () {
      final p = BackgroundPreset.defaultPreset();
      expect(p.isActive, true);
      expect(p.circles.length, 3);
    });

    test('plainWhite has 0 circles and is inactive', () {
      final p = BackgroundPreset.plainWhite();
      expect(p.isActive, false);
      expect(p.circles, isEmpty);
    });
  });

  group('CSV Parser', () {
    test('parses single course cell', () {
      const csv = '''
,,
,,
,日,一,二,三,四,五,六
第一大节,"高等数学
张老师(教授)
1-16[周]
教A301
[01-02]节",,,,,,
第二大节,,,,,,,
第三大节,,,,,,,
第四大节,,,,,,,
第五大节,,,,,,,
''';
      final courses = ScheduleCsvParser.parse(csv);
      expect(courses.length, 1);
      expect(courses[0].name, '高等数学');
      expect(courses[0].teacher, contains('张老师'));
      expect(courses[0].startWeek, 1);
      expect(courses[0].endWeek, 16);
      expect(courses[0].dayOfWeek, 0); // Sun = column 1 (index 0)
    });

    test('empty CSV returns empty list', () {
      expect(ScheduleCsvParser.parse(''), isEmpty);
    });

    test('deduplicates by name+day+period', () {
      const csv = '''
,,
,,
,日,一,二,三,四,五,六
第一大节,"数学
王老师(讲师)
1-8[周]
B201
[01-02]节",,,,,,
第一大节,"数学
王老师(讲师)
1-8[周]
B201
[01-02]节",,,,,,
第二大节,,,,,,,
第三大节,,,,,,,
第四大节,,,,,,,
第五大节,,,,,,,
''';
      final courses = ScheduleCsvParser.parse(csv);
      expect(courses.length, 1);
    });
  });
}
