import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';

void main() {
  group('NotificationService ID generation', () {
    int reminderId(String courseId, int week) =>
        ('$courseId-reminder-$week').hashCode.abs();

    int ongoingId(String courseId, int week) =>
        ('$courseId-ongoing-$week').hashCode.abs();

    test('reminder and ongoing IDs are different for same course+week', () {
      expect(reminderId('abc', 1), isNot(equals(ongoingId('abc', 1))));
    });

    test('different courses produce different ongoing IDs for same week', () {
      expect(ongoingId('abc', 1), isNot(equals(ongoingId('def', 1))));
    });

    test('same course different weeks produce different ongoing IDs', () {
      expect(ongoingId('abc', 3), isNot(equals(ongoingId('abc', 4))));
    });

    test('different courses produce different reminder IDs for same week', () {
      expect(reminderId('abc', 1), isNot(equals(reminderId('def', 1))));
    });

    test('same course different weeks produce different reminder IDs', () {
      expect(reminderId('abc', 3), isNot(equals(reminderId('abc', 4))));
    });

    test('no ID is ever zero (sentinel check)', () {
      final ids = <int>[];
      for (int w = 1; w <= 20; w++) {
        ids.add(reminderId('test', w));
        ids.add(ongoingId('test', w));
      }
      for (final id in ids) {
        expect(id, isNot(equals(0)),
            reason: 'Notification ID should never be 0');
      }
    });

    test('all IDs are positive', () {
      for (int w = 1; w <= 20; w++) {
        expect(reminderId('test', w), greaterThan(0));
        expect(ongoingId('test', w), greaterThan(0));
      }
    });
  });

  group('TimeSlot — source of truth for notification times', () {
    test('period 1: 8:00–9:40', () {
      final s = TimeSlot.forPeriod(1)!;
      expect(s.startTime, '8:00');
      expect(s.endTime, '9:40');
      expect(s.startMinuteOfDay, 480);
      expect(s.endMinuteOfDay, 580);
    });

    test('period 3: 10:10–11:50', () {
      final s = TimeSlot.forPeriod(3)!;
      expect(s.startTime, '10:10');
      expect(s.endTime, '11:50');
      expect(s.startMinuteOfDay, 610);
      expect(s.endMinuteOfDay, 710);
    });

    test('period 5: 14:00–15:40', () {
      final s = TimeSlot.forPeriod(5)!;
      expect(s.startTime, '14:00');
      expect(s.endTime, '15:40');
      expect(s.startMinuteOfDay, 840);
      expect(s.endMinuteOfDay, 940);
    });

    test('period 7: 16:10–17:50', () {
      final s = TimeSlot.forPeriod(7)!;
      expect(s.startTime, '16:10');
      expect(s.endTime, '17:50');
      expect(s.startMinuteOfDay, 970);
      expect(s.endMinuteOfDay, 1070);
    });

    test('period 9: 19:30–21:10', () {
      final s = TimeSlot.forPeriod(9)!;
      expect(s.startTime, '19:30');
      expect(s.endTime, '21:10');
      expect(s.startMinuteOfDay, 1170);
      expect(s.endMinuteOfDay, 1270);
    });

    test('reminder time with default 15min advance: period 1 → 7:45', () {
      final startMin = TimeSlot.forPeriod(1)!.startMinuteOfDay;
      const advance = 15;
      final notifyMin = startMin - advance;
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 45);
    });

    test('reminder time with 10min advance: period 1 → 7:50', () {
      final startMin = TimeSlot.forPeriod(1)!.startMinuteOfDay;
      const advance = 10;
      final notifyMin = startMin - advance;
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 50);
    });

    test('reminder time with 30min advance: period 5 (14:00) → 13:30', () {
      final startMin = TimeSlot.forPeriod(5)!.startMinuteOfDay;
      const advance = 30;
      final notifyMin = startMin - advance;
      expect(notifyMin ~/ 60, 13);
      expect(notifyMin % 60, 30);
    });
  });
}
