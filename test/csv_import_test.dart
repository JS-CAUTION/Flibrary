import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/services/database_service.dart';
import 'package:course_schedule_app/services/csv_parser.dart';
import 'package:course_schedule_app/models/course.dart';

void main() {
  group('CSV encoding fallback', () {
    test('parses GBK-encoded CSV (教务平台 original export)', () {
      const utf8Csv = '''
长沙理工大学 陈锦盛 学生个人课表,,,,,,,
学年学期：2026-2027-1        班级：网安24-1        专业：网络空间安全        学院：计算机学院        打印日期：2026-08-13,,,,,,,
,星期日,星期一,星期二,星期三,星期四,星期五,星期六
"第一大节
08:00-09:40", , ,"
物联网技术及安全
包博文(讲师)
1-14[周]
金13-208
[01-02]节
","
操作系统A
冯鹏(讲师)
1-16[周]
金13-404
[01-02]节
","
网络安全协议
谭晶晶(讲师)
1-16[周]
金13-405
[01-02]节
", , 
''';
      // Encode as GBK, exactly like the platform's original export.
      final gbkBytes = gbk.encode(utf8Csv);

      final courses = StorageService.parseXlsFromBytes(gbkBytes);

      expect(courses.length, 3);
      expect(courses[0].name, '物联网技术及安全');
      expect(courses[0].teacher, contains('包博文'));
      expect(courses[0].startWeek, 1);
      expect(courses[0].endWeek, 14);
      expect(courses[0].location, '金13-208');
      expect(courses[0].dayOfWeek, 2); // 星期二
      expect(courses[1].name, '操作系统A');
      expect(courses[1].dayOfWeek, 3); // 星期三
      expect(courses[2].name, '网络安全协议');
      expect(courses[2].dayOfWeek, 4); // 星期四
    });

    test('UTF-8 CSV still parses (with BOM)', () {
      const utf8Csv = '\uFEFF'
          '长沙理工大学 陈锦盛 学生个人课表,,,,,,,\n'
          '学年学期：2026-2027-1,,,,,,,\n'
          ',星期日,星期一,星期二,星期三,星期四,星期五,星期六\n'
          '"第一大节\n08:00-09:40", , ,'
          '"高等数学\n张老师(教授)\n1-16[周]\n教A301\n[01-02]节", , , , , \n';
      final courses =
          StorageService.parseXlsFromBytes(utf8.encode(utf8Csv));
      expect(courses.length, 1);
      expect(courses[0].name, '高等数学');
      expect(courses[0].dayOfWeek, 2); // 星期二
    });

    test('semester info extracted from GBK bytes', () {
      const utf8Csv =
          '长沙理工大学 陈锦盛 学生个人课表,,,,,,,\n'
          '学年学期：2026-2027-1        班级：网安24-1,,,,,,,\n'
          ',星期日,星期一,星期二,星期三,星期四,星期五,星期六\n';
      final info = StorageService.parseSemesterInfo(gbk.encode(utf8Csv));
      expect(info, contains('2026-2027-1'));
    });
  });

  group('CSV column layout', () {
    test('detects 8-column layout (slot label + Sun..Sat)', () {
      const csv = '''
,,
,,
,日,一,二,三,四,五,六
第一大节,"数学
王老师(讲师)
1-8[周]
B201
[01-02]节",,,,,,
第二大节,,,,,,,
''';
      final courses = ScheduleCsvParser.parse(csv);
      expect(courses.length, 1);
      expect(courses[0].dayOfWeek, 0); // 日 = col 1
    });

    test('adapts to shifted layout where Sun starts at col 2', () {
      // Some export variants insert an extra spacer column.
      const csv = '''
,,
, ,星期日,星期一,星期二,星期三,星期四,星期五,星期六
第一大节, ,"
数据库安全
冯鹏(讲师)
1-16[周]
金12-303
[01-02]节", , , , , 
''';
      final courses = ScheduleCsvParser.parse(csv);
      expect(courses.length, 1);
      expect(courses[0].name, '数据库安全');
      expect(courses[0].dayOfWeek, 0); // 星期日 = col 2
    });

    test('parses odd/even week modes and multi-course cells', () {
      const csv = '''
,,
,,
,日,一,二,三,四,五,六
第三大节,"网络安全协议
谭晶晶(讲师)
1-16[双周]
金13-405
[05-06]节
----------------------
计算机组成原理
龙际珍(讲师)
1-16[单周]
金13-102
[05-06]节",,,,,,
''';
      final courses = ScheduleCsvParser.parse(csv);
      expect(courses.length, 2);
      final even = courses.firstWhere((c) => c.name == '网络安全协议');
      final odd = courses.firstWhere((c) => c.name == '计算机组成原理');
      expect(even.weekMode, WeekMode.even);
      expect(odd.weekMode, WeekMode.odd);
      expect(even.startPeriod, 5);
      expect(even.endPeriod, 6);
    });
  });
}
