import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Course {
  final String id;
  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final int startPeriod;
  final int endPeriod;
  final int startWeek;
  final int endWeek;
  final int colorIndex;
  final WeekMode weekMode;
  final List<int> customWeeks;
  final String groupId;

  const Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    required this.startWeek,
    required this.endWeek,
    this.colorIndex = 0,
    this.weekMode = WeekMode.all,
    this.customWeeks = const [],
    this.groupId = '',
  });

  Color get color => AppColors.courseColors[colorIndex.clamp(0, 5)];

  /// Generate a unique group ID for new course groups.
  static String newGroupId() => DateTime.now().microsecondsSinceEpoch.toString();

  String get dayText {
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return days[dayOfWeek.clamp(0, 6)];
  }

  String get periodText {
    if (startPeriod == endPeriod) return '第$startPeriod节';
    return '第$startPeriod-${endPeriod}节';
  }

  String get weekText {
    if (weekMode == WeekMode.custom) {
      return '第${customWeeks.join('、')}周';
    }
    final modeText = weekMode.label;
    return '$startWeek-${endWeek}周$modeText';
  }

  bool isActiveInWeek(int week) {
    if (weekMode == WeekMode.custom) {
      return customWeeks.contains(week);
    }
    if (week < startWeek || week > endWeek) return false;
    if (weekMode == WeekMode.odd && week % 2 == 0) return false;
    if (weekMode == WeekMode.even && week % 2 == 1) return false;
    return true;
  }

  String get timeText {
    const slots = ['', '8:00', '10:10', '14:00', '16:10', '19:30'];
    const endSlots = ['', '9:40', '11:50', '15:40', '17:50', '21:10'];
    final slotIndex = ((startPeriod - 1) ~/ 2).clamp(0, 4) + 1;
    final start = slotIndex <= 5 ? slots[slotIndex] : '';
    final end = slotIndex <= 5 ? endSlots[slotIndex] : '';
    return '$start ~ $end';
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String,
      name: map['name'] as String,
      teacher: map['teacher'] as String? ?? '',
      location: map['location'] as String? ?? '',
      dayOfWeek: map['dayOfWeek'] as int,
      startPeriod: map['startPeriod'] as int,
      endPeriod: map['endPeriod'] as int,
      startWeek: map['startWeek'] as int,
      endWeek: map['endWeek'] as int,
      colorIndex: map['colorIndex'] as int? ?? 0,
      weekMode: WeekMode.fromValue(map['weekMode'] as int? ?? 0),
      customWeeks: (map['customWeeks'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      groupId: map['groupId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'location': location,
      'dayOfWeek': dayOfWeek,
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'colorIndex': colorIndex,
      'weekMode': weekMode.value,
      'customWeeks': customWeeks,
      'groupId': groupId,
    };
  }

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? location,
    int? dayOfWeek,
    int? startPeriod,
    int? endPeriod,
    int? startWeek,
    int? endWeek,
    int? colorIndex,
    WeekMode? weekMode,
    List<int>? customWeeks,
    String? groupId,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      colorIndex: colorIndex ?? this.colorIndex,
      weekMode: weekMode ?? this.weekMode,
      customWeeks: customWeeks ?? List.from(this.customWeeks),
      groupId: groupId ?? this.groupId,
    );
  }
}

enum WeekMode {
  all(0, ''),
  odd(1, '单周'),
  even(2, '双周'),
  custom(3, '自定义');

  final int value;
  final String label;
  const WeekMode(this.value, this.label);

  static WeekMode fromValue(int value) {
    return WeekMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => WeekMode.all,
    );
  }
}

class TimeSlot {
  final int period;
  final String startTime;
  final String endTime;

  const TimeSlot(this.period, this.startTime, this.endTime);

  String get label => '$startTime\n$endTime';

  static const List<TimeSlot> slots = [
    TimeSlot(1, '8:00', '9:40'),
    TimeSlot(3, '10:10', '11:50'),
    TimeSlot(5, '14:00', '15:40'),
    TimeSlot(7, '16:10', '17:50'),
    TimeSlot(9, '19:30', '21:10'),
  ];

  int get startMinuteOfDay {
    final parts = startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get endMinuteOfDay {
    final parts = endTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static TimeSlot? forPeriod(int period) {
    try {
      return slots.firstWhere((s) => s.period == period);
    } catch (_) {
      return null;
    }
  }

  static int slotIndexForPeriod(int period) {
    if (period <= 2) return 0;
    if (period <= 4) return 1;
    if (period <= 6) return 2;
    if (period <= 8) return 3;
    return 4;
  }
}

const List<String> dayLabels = ['日', '一', '二', '三', '四', '五', '六'];
