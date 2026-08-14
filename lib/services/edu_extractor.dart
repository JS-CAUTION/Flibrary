import 'dart:convert';
import '../models/course.dart';

/// 教务在线导入的 DOM 提取核心。
///
/// 设计原则:
/// - 注入 JS 只做「原始文本提取」(轻量、不易出错,无法单测)
/// - 解析逻辑全部在 Dart(与 CSV 解析器同构,可用 flutter test 覆盖)
///
/// DOM 事实(2026-08-13 调研确认):
/// - 课表表格 `table#kbtable`,表头 7 列(周日~周六),行 = 5 大节
/// - 每格 td 内 `div.kbcontent`(完整版:课程名/老师/周次(节次)/教室)
///   与 `div.kbcontent1`(简版,无老师)
/// - 同格多门课用 `---------------------` 分隔
/// - 周次格式 `1-14(周)[01-02节]`、`1-16(双周)`、`1-16(单周)`
/// - 老师字段「姓名+职称」连写(如 `包博文讲师`)
/// - td 内 hidden input value=`{GUID}-{星期}-{序号}`,星期编码:7=周日,1=周一…6=周六
class EduExtractor {
  EduExtractor._();

  /// 注入 WebView 的 JS 脚本。
  /// 在主文档与所有 iframe 中寻找 `table#kbtable`,提取每个课程格的
  /// textContent 与 hidden input 编码,并提取所选学期,返回 JSON 字符串:
  ///   {"items":[{"cell":列索引,"slot":"第一大节 08:00-09:40","hidden":"GUID-2-1","text":"..."}],"semester":"2026-2027-1"}
  /// 找不到表格时返回 {"error":"no_table"}。
  static const String injectionScript = r'''
(function() {
  function findTable(d) { return d.getElementById('kbtable'); }
  function deepFind(d) {
    var frames = d.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      try {
        var t = findTable(frames[i].contentDocument);
        if (t) return t;
        t = deepFind(frames[i].contentDocument);
        if (t) return t;
      } catch (e) {}
    }
    return null;
  }
  var table = findTable(document) || deepFind(document);
  if (!table) return JSON.stringify({error: 'no_table'});
  var doc = table.ownerDocument;
  var semester = '';
  var sel = doc.querySelector('select[name="xnxq01id"]');
  if (sel && sel.selectedIndex >= 0) semester = sel.options[sel.selectedIndex].textContent.trim();
  var items = [];
  var rows = table.querySelectorAll('tr');
  for (var r = 0; r < rows.length; r++) {
    var ths = rows[r].querySelectorAll('th');
    var slot = ths.length > 0 ? ths[0].textContent.replace(/\s+/g, ' ').trim() : '';
    var tds = rows[r].querySelectorAll('td');
    for (var c = 0; c < tds.length; c++) {
      var divs = tds[c].querySelectorAll('div.kbcontent');
      for (var d = 0; d < divs.length; d++) {
        // innerHTML 处理: textContent 不含 <br> 换行,行结构会丢失
        var text = divs[d].innerHTML
          .replace(/<br\s*\/?>/gi, '\n')
          .replace(/<[^>]*>/g, '')
          .replace(/&nbsp;/g, ' ')
          .trim();
        if (!text || text === '\u00a0') continue;
        var inputs = tds[c].querySelectorAll('input[name^="jx0415zbdiv"]');
        var hidden = inputs.length > 0 ? inputs[0].value : '';
        items.push({cell: tds[c].cellIndex, slot: slot, hidden: hidden, text: text});
      }
    }
  }
  return JSON.stringify({items: items, semester: semester});
})();
''';

  static final RegExp _weekPattern =
      RegExp(r'^(\d+)-(\d+)\((周|单周|双周)\)(?:\[(\d{2})-(\d{2})节\])?$');

  /// 职称后缀,从长到短匹配(避免「教授」误匹配「副教授」)。
  static const List<String> _titleSuffixes = [
    '高级实验师', '副研究员', '助理研究员', '高级工程师', '高级经济师',
    '副教授', '助理教授', '实验师', '工程师', '经济师', '研究员',
    '教授', '讲师', '助教',
  ];

  /// 归一化 runJavaScriptReturningResult 的返回值:
  /// iOS 返回 JSON 编码字符串(带引号),Android 返回原始字符串。
  static String normalizeResult(String raw) {
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      try {
        final inner = jsonDecode(s);
        if (inner is String) return inner;
      } catch (_) {}
    }
    return s;
  }

  /// 从注入脚本返回的 JSON 中提取所选学期文本(如 "2026-2027-1")。
  static String? parseSemester(String scriptResult) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(normalizeResult(scriptResult));
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final semester = decoded['semester'];
    if (semester is! String || semester.isEmpty) return null;
    return '学年学期：$semester';
  }

  /// 解析注入脚本返回的 JSON → `List<Course>`。
  /// 解析失败或无数据时返回空列表。
  static List<Course> parseCourses(String scriptResult) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(normalizeResult(scriptResult));
    } catch (_) {
      return [];
    }
    if (decoded is! Map<String, dynamic>) return [];
    if (decoded.containsKey('error')) return [];
    final items = decoded['items'];
    if (items is! List) return [];

    final courses = <Course>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final cell = (item['cell'] as num?)?.toInt() ?? -1;
      final slot = (item['slot'] as String?) ?? '';
      final hidden = (item['hidden'] as String?) ?? '';
      final text = (item['text'] as String?) ?? '';
      if (cell < 0 || text.isEmpty) continue;

      final day = _dayFromHidden(hidden) ?? (cell - 1);

      // 同格多门课: `---------------------` 分隔
      for (final block in text.split(RegExp(r'-{8,}'))) {
        final course =
            _parseBlock(block, day, slot, courses.length);
        if (course != null) courses.add(course);
      }
    }
    return courses;
  }

  /// 从 hidden input 编码 `{GUID}-{星期}-{序号}` 提取星期(7=周日,1=周一…6=周六)。
  static int? _dayFromHidden(String hidden) {
    final parts = hidden.split('-');
    if (parts.length < 2) return null;
    final code = int.tryParse(parts[parts.length - 2]);
    if (code == null) return null;
    if (code == 7) return 0;
    if (code >= 1 && code <= 6) return code;
    return null;
  }

  /// 解析单个课程块(文本行: 课程名 / 老师 / 周次(节次) / 教室)。
  static Course? _parseBlock(
      String rawBlock, int day, String slotLabel, int colorOffset) {
    final lines = rawBlock
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final name = _cleanName(lines.first);
    if (name.isEmpty) return null;

    String teacher = '';
    int startWeek = 1, endWeek = 16;
    WeekMode weekMode = WeekMode.all;
    int? startPeriod, endPeriod;
    String location = '';

    for (final line in lines.skip(1)) {
      final teacherFormatted = _formatTeacher(line);
      if (teacherFormatted != null) {
        teacher = teacherFormatted;
        continue;
      }
      final weekMatch = _weekPattern.firstMatch(line);
      if (weekMatch != null) {
        startWeek = int.tryParse(weekMatch.group(1)!) ?? 1;
        endWeek = int.tryParse(weekMatch.group(2)!) ?? 16;
        final mode = weekMatch.group(3);
        if (mode == '单周') weekMode = WeekMode.odd;
        if (mode == '双周') weekMode = WeekMode.even;
        final ps = int.tryParse(weekMatch.group(4) ?? '');
        final pe = int.tryParse(weekMatch.group(5) ?? '');
        if (ps != null && pe != null) {
          startPeriod = ps;
          endPeriod = pe;
        }
        continue;
      }
      // 剩余非空行视为教室
      if (location.isEmpty && line.length <= 20) {
        location = line;
      }
    }

    // 简版(kbcontent1)周次行无节次后缀,从节次标签推导
    if (startPeriod == null || endPeriod == null) {
      final derived = _periodFromSlotLabel(slotLabel);
      startPeriod = derived.$1;
      endPeriod = derived.$2;
    }

    return Course(
      id: '',
      name: name,
      teacher: teacher,
      location: location,
      dayOfWeek: day,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      startWeek: startWeek,
      endWeek: endWeek,
      weekMode: weekMode,
      colorIndex: colorOffset % 6,
    );
  }

  /// 拆分「姓名+职称」连写字段,拼成与 CSV 导入一致的括号格式
  /// `姓名(职称)`(如 `包博文(讲师)`);非教师行返回 null。
  static String? _formatTeacher(String line) {
    for (final suffix in _titleSuffixes) {
      if (line.endsWith(suffix) && line.length > suffix.length) {
        final name = line.substring(0, line.length - suffix.length);
        return '$name($suffix)';
      }
    }
    return null;
  }

  /// 节次标签 → 起止节次:「第一大节」→ (1,2)…「第五大节」→ (9,10)。
  static (int, int) _periodFromSlotLabel(String slotLabel) {
    const map = {'一': (1, 2), '二': (3, 4), '三': (5, 6), '四': (7, 8), '五': (9, 10)};
    final m = RegExp(r'第([一二三四五])大节').firstMatch(slotLabel);
    return map[m?.group(1)] ?? (1, 2);
  }

  static String _cleanName(String raw) {
    var name = raw.trim();
    // 剥离班级分组后缀 (四) 等,保留 (A)/(双语) 等合法后缀
    name = name.replaceFirst(RegExp(r'[(（][一二三四五六七八九十]+[)）]$'), '').trim();
    return name;
  }
}
