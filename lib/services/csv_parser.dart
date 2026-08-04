import '../models/course.dart';

/// Parses course schedule CSV files exported from Chinese university教务系统.
/// Format: 8-column CSV (time label + 7 days Sun-Sat).
/// Grid: Row 0-1=info, Row 2=day headers, Row 3-7=time slot rows.
///
/// Each course cell has the format:
///   课程名称
///   教师(职称)
///   N-M[周/单周/双周]
///   地点
///   [XX-XX]节
///
/// Some cells may contain MULTIPLE courses (when two courses share
/// the same time slot on the same day).
class ScheduleCsvParser {
  static List<Course> parse(String csvText) {
    // Strip BOM if present
    final cleaned = csvText.startsWith('﻿') ? csvText.substring(1) : csvText;
    final rows = _splitCsv(cleaned);
    if (rows.length < 3) return [];

    final courses = <Course>[];

    for (int r = 2; r < rows.length; r++) {
      final row = rows[r];
      // Skip empty or whitespace-only rows
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      final firstCol = row.isNotEmpty ? row[0] : '';
      final slotMatch = RegExp(r'第([一二三四五])大节').firstMatch(firstCol);
      if (slotMatch != null) {
        final numMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5};
        final slotNum = numMap[slotMatch.group(1)] ?? 1;
        final periodStart = (slotNum - 1) * 2 + 1;
        final periodEnd = slotNum * 2;

        // Columns 1-7 = Sun (0) through Sat (6)
        for (int col = 1; col <= 7 && col < row.length; col++) {
          final cellText = row[col].trim();
          if (cellText.isEmpty) continue;
          final parsed = _parseCellMulti(cellText, col - 1, periodStart, periodEnd, courses.length);
          courses.addAll(parsed);
        }
      } else if (firstCol.contains('备注') || row.any((c) => c.contains('备注'))) {
        for (int col = 0; col < row.length; col++) {
          if (row[col].contains('备注')) {
            courses.addAll(_parseRemarks(row[col], courses.length));
            break;
          }
        }
      }
    }

    return _deduplicate(courses);
  }

  /// Parse a cell that may contain 1 or 2 courses.
  /// Detects the second course by finding a second "[XX-XX]节" marker.
  static List<Course> _parseCellMulti(
    String cell, int dayOfWeek, int defPs, int defPe, int colorOff) {
    final results = <Course>[];

    // Split cell into individual course blocks.
    // A cell has 2 courses if it has TWO "[XX-XX]节" lines.
    final periodMatches = RegExp(r'\[\d{2}-\d{2}\]节').allMatches(cell).toList();

    if (periodMatches.length >= 2) {
      // Multiple courses: split at boundaries between them
      // Each course block: name → teacher → weeks → location → [periods]
      final blocks = _splitMultiCourseCell(cell);
      for (int bi = 0; bi < blocks.length; bi++) {
        final c = _parseSingleBlock(blocks[bi], dayOfWeek, defPs, defPe, colorOff + results.length);
        if (c != null) results.add(c);
      }
    } else {
      // Single course
      final c = _parseSingleBlock(cell, dayOfWeek, defPs, defPe, colorOff);
      if (c != null) results.add(c);
    }

    return results;
  }

  /// Split a multi-course cell into individual blocks.
  /// Strategy: find the second course name (text before the second occurrence of
  /// "teacher(职称)" pattern, then the rest follows).
  static List<String> _splitMultiCourseCell(String cell) {
    final lines = cell.split('\n');
    // Find the boundary: second occurrence of "教师(职称)" pattern
    final teacherPattern = RegExp(r'.+\([^)]+\)$');

    int firstTeacherIdx = -1;
    int secondTeacherIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].trim();
      if (teacherPattern.hasMatch(l)) {
        if (firstTeacherIdx == -1) {
          firstTeacherIdx = i;
        } else {
          secondTeacherIdx = i;
          break;
        }
      }
    }

    if (secondTeacherIdx == -1) return [cell];

    // Block 1: from start to just before the second course name
    // Block 2: from the second course name to end

    // Find the second course name (line before second teacher)
    int secondNameIdx = secondTeacherIdx - 1;
    while (secondNameIdx > firstTeacherIdx &&
        lines[secondNameIdx].trim().isEmpty) {
      secondNameIdx--;
    }

    final block1 = lines.sublist(0, secondNameIdx).join('\n');
    final block2 = lines.sublist(secondNameIdx).join('\n');

    return [block1.trim(), block2.trim()];
  }

  /// Parse a single course block.
  static Course? _parseSingleBlock(
    String blockText, int dayOfWeek, int defPs, int defPe, int colorOff) {
    final lines = blockText
        .replaceAll('\r', '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 3) return null;

    // ── Identify each field ──

    String? name;
    String? teacher;
    int sW = 1, eW = 16;
    WeekMode wm = WeekMode.all;
    int ps = defPs, pe = defPe;
    String? location;

    for (final l in lines) {
      final trimmed = l;

      // Period: [XX-XX]节
      final pm = RegExp(r'^\[(\d{2})-(\d{2})\]节$').firstMatch(trimmed);
      if (pm != null) {
        ps = int.tryParse(pm.group(1) ?? '') ?? defPs;
        pe = int.tryParse(pm.group(2) ?? '') ?? defPe;
        continue;
      }

      // Weeks: N-M[周/单周/双周]
      final wmMatch = RegExp(r'^(\d+)-(\d+)\[(.*?)周\s*\]$').firstMatch(trimmed);
      if (wmMatch != null) {
        sW = int.tryParse(wmMatch.group(1) ?? '1') ?? 1;
        eW = int.tryParse(wmMatch.group(2) ?? '16') ?? 16;
        final ms = wmMatch.group(3) ?? '';
        // Check for 单/双 in the full string including the bracket content
        if (ms.contains('单') || trimmed.contains('单周')) wm = WeekMode.odd;
        if (ms.contains('双') || trimmed.contains('双周')) wm = WeekMode.even;
        continue;
      }

      // Course name detection (must come BEFORE teacher)
      // The first non-meta, non-teacher, non-location line that isn't a week/period marker.
      if (name == null && !_looksLikeMeta(trimmed) && !trimmed.contains('[')) {
        // Not a teacher line if it doesn't contain a known title like (教授), (讲师) etc.
        final isNameLine = !_isTeacherLine(trimmed);
        if (isNameLine) {
          name = trimmed;
          continue;
        }
      }

      // Teacher: line with () containing known titles like (教授), (讲师), (副教授)
      if (_isTeacherLine(trimmed)) {
        teacher = trimmed;
        continue;
      }

      // Location heuristic: short line with building number pattern
      if (trimmed.length <= 20 &&
          RegExp(r'[金教综实工理文外信计网西田径场]').hasMatch(trimmed) &&
          !RegExp(r'[思毛习概义论治程序设计实验体育原理]').hasMatch(trimmed) &&
          (RegExp(r'\d').hasMatch(trimmed) || trimmed.contains('田径'))) {
        location = trimmed;
        continue;
      }

      // Fallback for name: first non-meta line
      if (name == null && trimmed.length >= 2 && !_looksLikeMeta(trimmed)) {
        name = trimmed;
      }
    }

    if (name == null || name.isEmpty) return null;

    // Fallback: if teacher is still null, try to find a teacher line
    if (teacher == null) {
      for (final l in lines) {
        if (_isTeacherLine(l)) {
          teacher = l;
          break;
        }
      }
    }

    // Fallback: if teacher is still null, try any line with ()
    if (teacher == null) {
      for (final l in lines) {
        if (l.contains('(') && l.contains(')') && !l.contains('[') && !l.startsWith('(')) {
          teacher = l;
          break;
        }
      }
    }

    // Clean up: strip class grouping suffixes like "(四)" from course names,
    // but preserve legitimate course name suffixes like "(A)", "(双语)", "(实验)".
    // Class grouping suffixes are typically a single Chinese numeral inside parens.
    if (name != null) {
      name = name!.replaceFirst(RegExp(r'[(（][一二三四五六七八九十]+[)）]$'), '').trim();
      if (name!.isEmpty) return null;
    }

    if (name == null || _isTeacherLine(name!)) {
      if (teacher != null) {
        final tIdx = lines.indexOf(teacher!);
        if (tIdx > 0) {
          final prev = lines[tIdx - 1];
          if (prev.isNotEmpty && !_looksLikeMeta(prev) && !_isTeacherLine(prev) && !prev.contains('[')) {
            name = prev;
            // Strip class suffix like "(四)" from name, but keep "(A)", "(双语)" etc.
            name = name!.replaceFirst(RegExp(r'[(（][一二三四五六七八九十]+[)）]$'), '').trim();
          }
        }
      }
      if (name == null && teacher != null) {
        name = teacher;
        teacher = null;
      }
    }

    if (name == null || name!.isEmpty) return null;

    return Course(
      id: '',
      name: name,
      teacher: teacher ?? '',
      location: location ?? '',
      dayOfWeek: dayOfWeek,
      startPeriod: ps,
      endPeriod: pe,
      startWeek: sW,
      endWeek: eW,
      weekMode: wm,
      colorIndex: colorOff % 6,
    );
  }

  static bool _isTeacherLine(String s) {
    final trimmed = s.trim();
    final hasTitle = trimmed.contains('教授') || trimmed.contains('讲师') || trimmed.contains('助教');
    // Lines that start with '(' and lack title keywords are not teacher names
    // e.g. "(24计外跆拳道21)" — class grouping
    if (trimmed.startsWith('(') && !hasTitle) {
      return false;
    }
    return trimmed.contains('(') && trimmed.contains(')') && !trimmed.contains('[') && hasTitle;
  }

  static bool _looksLikeMeta(String s) {
    if (s.startsWith('第') && s.contains('大')) return true;
    if (RegExp(r'^\d{2}:\d{2}').hasMatch(s)) return true;
    if (s.contains('[') && s.contains(']')) return true;
    return false;
  }

  static List<Course> _parseRemarks(String cell, int co) {
    // Skip remarks parsing — they contain practicum/course info that
    // doesn't have day/time/location like regular courses, causing
    // them to appear as phantom Friday P7-8 courses.
    return <Course>[];
  }

  /// CSV splitter handling quoted multiline fields.
  static List<List<String>> _splitCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    bool q = false;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (q) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            q = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          q = true;
        } else if (ch == ',') {
          row.add(field.toString());
          field = StringBuffer();
        } else if (ch == '\n') {
          row.add(field.toString());
          field = StringBuffer();
          rows.add(row);
          row = <String>[];
        } else if (ch != '\r') {
          field.write(ch);
        }
      }
    }
    row.add(field.toString());
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  static List<Course> _deduplicate(List<Course> cs) {
    final seen = <String>{};
    final rs = <Course>[];
    for (final c in cs) {
      final k = '${c.name}_${c.dayOfWeek}_${c.startPeriod}';
      if (!seen.contains(k)) {
        seen.add(k);
        rs.add(c);
      }
    }
    return rs;
  }

  static String? extractSemesterInfo(String csvText) {
    final cleaned = csvText.startsWith('﻿') ? csvText.substring(1) : csvText;
    final rows = _splitCsv(cleaned);
    if (rows.isEmpty) return null;
    // Row 1 has the semester info
    if (rows.length > 1 && rows[1].isNotEmpty) {
      final r1 = rows[1][0];
      final m = RegExp(r'学年学期：(\S+)').firstMatch(r1);
      if (m != null) {
        var info = m.group(0)!;
        final cm = RegExp(r'班级：(\S+)').firstMatch(r1);
        if (cm != null) info += ' ${cm.group(0)}';
        return info;
      }
    }
    // Also check row 0
    if (rows.isNotEmpty && rows[0].isNotEmpty) {
      final r0 = rows[0][0];
      final m = RegExp(r'学年学期：(\S+)').firstMatch(r0);
      if (m != null) return m.group(0)!;
    }
    return null;
  }
}