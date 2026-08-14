import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/services/edu_extractor.dart';
import 'package:course_schedule_app/models/course.dart';

/// 模拟注入脚本返回的 JSON(结构与真实 xskb_list.do 的 DOM 一致)。
String scriptResult(List<Map<String, dynamic>> items) {
  return '{"items":${_jsonList(items)}}';
}

String _jsonList(List<Map<String, dynamic>> items) {
  final buf = StringBuffer('[');
  for (var i = 0; i < items.length; i++) {
    if (i > 0) buf.write(',');
    final m = items[i];
    buf.write(
        '{"cell":${m['cell']},"slot":"${m['slot']}","hidden":"${m['hidden']}","text":${_jsonEscape(m['text'] as String)}}');
  }
  buf.write(']');
  return buf.toString();
}

String _jsonEscape(String s) {
  return '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
}

void main() {
  group('EduExtractor.parseCourses', () {
    test('parses single course block with all fields', () {
      final result = scriptResult([
        {
          'cell': 3,
          'slot': '第一大节 08:00-09:40',
          'hidden': '3614288860E94191B52F3B6AD6CB80A0-2-1',
          'text': '物联网技术及安全 \n包博文讲师\n1-14(周)[01-02节]\n金13-208\n',
        },
      ]);

      final courses = EduExtractor.parseCourses(result);

      expect(courses.length, 1);
      final c = courses[0];
      expect(c.name, '物联网技术及安全');
      expect(c.teacher, '包博文(讲师)'); // 与 CSV 导入一致的括号职称格式
      expect(c.location, '金13-208');
      expect(c.dayOfWeek, 2); // hidden 编码 2 = 周二
      expect(c.startPeriod, 1);
      expect(c.endPeriod, 2);
      expect(c.startWeek, 1);
      expect(c.endWeek, 14);
      expect(c.weekMode, WeekMode.all);
    });

    test('splits multi-course cell on dash separator', () {
      final result = scriptResult([
        {
          'cell': 2,
          'slot': '第三大节 14:00-15:40',
          'hidden': '6C661E60EC524AFEAA378CE2B3CF0AB1-1-1',
          'text': '网络安全协议 \n谭晶晶讲师\n1-16(双周)[05-06节]\n金13-405\n'
              '----------------------\n'
              '计算机组成原理 \n龙际珍讲师\n1-16(单周)[05-06节]\n金13-102\n',
        },
      ]);

      final courses = EduExtractor.parseCourses(result);

      expect(courses.length, 2);
      final even = courses.firstWhere((c) => c.name == '网络安全协议');
      final odd = courses.firstWhere((c) => c.name == '计算机组成原理');
      expect(even.weekMode, WeekMode.even);
      expect(even.dayOfWeek, 1); // hidden 编码 1 = 周一
      expect(odd.weekMode, WeekMode.odd);
      expect(odd.startPeriod, 5);
      expect(odd.endPeriod, 6);
    });

    test('day code mapping: 7=Sunday, 1=Monday ... 6=Saturday', () {
      final result = scriptResult([
        {
          'cell': 8,
          'slot': '第二大节 10:10-11:50',
          'hidden': '64DE2E6C287D42989CB671298FD0F563-7-1',
          'text': '物联网技术及安全实验 \n包博文讲师\n2-16(周)[03-04节]\n',
        },
        {
          'cell': 4,
          'slot': '第一大节 08:00-09:40',
          'hidden': '3614288860E94191B52F3B6AD6CB80A0-3-1',
          'text': '操作系统A \n冯鹏讲师\n1-16(周)[01-02节]\n金13-404\n',
        },
      ]);

      final courses = EduExtractor.parseCourses(result);

      final sun = courses.firstWhere((c) => c.name == '物联网技术及安全实验');
      final wed = courses.firstWhere((c) => c.name == '操作系统A');
      expect(sun.dayOfWeek, 0); // hidden 编码 7 = 周日
      expect(wed.dayOfWeek, 3); // hidden 编码 3 = 周三
    });

    test('falls back to slot label when period suffix missing (kbcontent1)', () {
      final result = scriptResult([
        {
          'cell': 5,
          'slot': '第四大节 16:10-17:50',
          'hidden': '0E099D9C9F85476A814CBE85ECF494A1-4-1',
          'text': '计算机组成原理 \n龙际珍讲师\n1-16(周)\n金13-102\n',
        },
      ]);

      final courses = EduExtractor.parseCourses(result);

      expect(courses.length, 1);
      expect(courses[0].startPeriod, 7);
      expect(courses[0].endPeriod, 8);
    });

    test('formats teacher titles as 姓名(职称) matching CSV import', () {
      final result = scriptResult([
        {
          'cell': 2,
          'slot': '第一大节 08:00-09:40',
          'hidden': 'G-1-1',
          'text': '计算机网络原理与技术 \n熊兵副教授\n1-14(周)[01-02节]\n金6-204\n',
        },
        {
          'cell': 3,
          'slot': '第一大节 08:00-09:40',
          'hidden': 'G-2-1',
          'text': '毛泽东思想和中国特色社会主义理论体系概论 \n赵玲玲教授\n1-11(周)[01-02节]\n金6-308\n',
        },
      ]);

      final courses = EduExtractor.parseCourses(result);

      final c1 = courses.firstWhere((c) => c.name == '计算机网络原理与技术');
      final c2 = courses.firstWhere(
          (c) => c.name == '毛泽东思想和中国特色社会主义理论体系概论');
      expect(c1.teacher, '熊兵(副教授)');
      expect(c2.teacher, '赵玲玲(教授)');
    });

    test('returns empty on no_table error', () {
      expect(EduExtractor.parseCourses('{"error":"no_table"}'), isEmpty);
    });

    test('returns empty on malformed input', () {
      expect(EduExtractor.parseCourses('not json'), isEmpty);
      expect(EduExtractor.parseCourses('{"items":[]}'), isEmpty);
    });
  });

  group('EduExtractor.injectionScript', () {
    test('is non-empty and syntactically structured', () {
      expect(EduExtractor.injectionScript, isNotEmpty);
      expect(EduExtractor.injectionScript, contains('kbtable'));
      expect(EduExtractor.injectionScript, contains('no_table'));
      expect(EduExtractor.injectionScript, contains('JSON.stringify'));
    });
  });
}
