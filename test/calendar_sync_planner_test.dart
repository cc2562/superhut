import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/schedule/custom_schedule_event.dart';
import 'package:superhut/utils/course/calendar/calendar_event_planner.dart';
import 'package:superhut/utils/course/coursemain.dart';

Course buildCourse({
  String name = '包装材料学',
  String teacher = '何新快',
  String location = '公共222',
  int startSection = 3,
  int duration = 2,
}) {
  return Course(
    name: name,
    teacherName: teacher,
    weekDuration: '1-16',
    location: location,
    startSection: startSection,
    duration: duration,
  );
}

void main() {
  group('期望事件生成', () {
    test('课程按日期展开，时间与节次表一致', () {
      final List<PlannedCalendarEvent> events = buildDesiredCalendarEvents(
        courseData: <String, List<Course>>{
          '2025-03-03': <Course>[buildCourse()],
        },
        schedules: const <CustomScheduleEvent>[],
        reminderMinutes: 10,
      );

      expect(events, hasLength(1));
      final PlannedCalendarEvent event = events.single;
      expect(event.key, 'course|2025-03-03|包装材料学|3|0');
      expect(
        event.startMillis,
        DateTime(2025, 3, 3, 10).millisecondsSinceEpoch,
      );
      expect(
        event.endMillis,
        DateTime(2025, 3, 3, 11, 40).millisecondsSinceEpoch,
      );
      expect(event.reminderMinutes, 10);
      expect(event.title, '包装材料学');
      expect(event.location, '公共222');
      expect(event.description, contains('教师：何新快'));
      expect(event.description, contains('节次：第3–4节'));
    });

    test('同日同名同节的重复课程用序号区分', () {
      final List<PlannedCalendarEvent> events = buildDesiredCalendarEvents(
        courseData: <String, List<Course>>{
          '2025-03-03': <Course>[buildCourse(), buildCourse(teacher: '张老师')],
        },
        schedules: const <CustomScheduleEvent>[],
        reminderMinutes: 0,
      );

      expect(
        events.map((PlannedCalendarEvent event) => event.key),
        <String>[
          'course|2025-03-03|包装材料学|3|0',
          'course|2025-03-03|包装材料学|3|1',
        ],
      );
    });

    test('自定义日程按指定周次展开', () {
      final CustomScheduleEvent schedule = CustomScheduleEvent(
        id: 'schedule-1',
        title: '社团例会',
        location: '活动中心',
        start: DateTime(2025, 3, 5, 14),
        end: DateTime(2025, 3, 5, 16),
        repeat: ScheduleRepeat.weekly,
        repeatUntil: DateTime(2025, 3, 21),
        weeks: const <int>[1, 3],
      );

      final List<PlannedCalendarEvent> events = buildDesiredCalendarEvents(
        courseData: <String, List<Course>>{
          '2025-03-21': <Course>[buildCourse()],
        },
        schedules: <CustomScheduleEvent>[schedule],
        reminderMinutes: 5,
        firstDay: '2025-03-03',
      );

      final List<PlannedCalendarEvent> scheduleEvents = events
          .where((PlannedCalendarEvent event) => event.key.startsWith('custom|'))
          .toList();

      expect(scheduleEvents, hasLength(2));
      expect(
        scheduleEvents.map((PlannedCalendarEvent event) => event.key),
        <String>['custom|schedule-1|2025-03-05', 'custom|schedule-1|2025-03-19'],
      );
      expect(
        scheduleEvents.first.endMillis -
            scheduleEvents.first.startMillis,
        const Duration(hours: 2).inMilliseconds,
      );
    });

    test('不重复的日程只生成一天', () {
      final CustomScheduleEvent schedule = CustomScheduleEvent(
        id: 'once',
        title: '体检',
        start: DateTime(2025, 4, 8, 9, 30),
        end: DateTime(2025, 4, 8, 10, 30),
      );

      final List<PlannedCalendarEvent> events = buildDesiredCalendarEvents(
        courseData: const <String, List<Course>>{},
        schedules: <CustomScheduleEvent>[schedule],
        reminderMinutes: 0,
      );

      expect(events, hasLength(1));
      expect(events.single.key, 'custom|once|2025-04-08');
    });
  });

  group('差量', () {
    PlannedCalendarEvent desired(String key, int fingerprint) {
      return PlannedCalendarEvent(
        key: key,
        title: key,
        location: '',
        description: '',
        startMillis: 0,
        endMillis: 1,
        reminderMinutes: 0,
        fingerprint: fingerprint,
      );
    }

    test('新增 / 更新 / 删除 / 不变 四类分开', () {
      final CalendarSyncPlan plan = planCalendarSync(
        desired: <PlannedCalendarEvent>[
          desired('a', 1),
          desired('b', 2),
        ],
        records: <String, CalendarSyncRecord>{
          'a': const CalendarSyncRecord(eventId: 'id-a', fingerprint: 1),
          'c': const CalendarSyncRecord(eventId: 'id-c', fingerprint: 9),
        },
      );

      expect(plan.inserts.map((PlannedCalendarEvent e) => e.key), <String>['b']);
      expect(plan.updates, isEmpty);
      expect(plan.deleteEventIds, <String>['id-c']);
      expect(plan.unchanged.keys, <String>['a']);
      expect(plan.changeCount, 2);
    });

    test('指纹变化走更新并沿用原事件 id', () {
      final CalendarSyncPlan plan = planCalendarSync(
        desired: <PlannedCalendarEvent>[desired('a', 42)],
        records: <String, CalendarSyncRecord>{
          'a': const CalendarSyncRecord(eventId: 'id-a', fingerprint: 1),
        },
      );

      expect(plan.inserts, isEmpty);
      expect(plan.deleteEventIds, isEmpty);
      expect(plan.updates.single.eventId, 'id-a');
    });

    test('内容没变时整轮为空', () {
      final CalendarSyncPlan plan = planCalendarSync(
        desired: <PlannedCalendarEvent>[desired('a', 7)],
        records: <String, CalendarSyncRecord>{
          'a': const CalendarSyncRecord(eventId: 'id-a', fingerprint: 7),
        },
      );

      expect(plan.isEmpty, isTrue);
    });

    test('指纹对提醒时间敏感', () {
      int fingerprint(int reminder) => calendarFingerprint(
        <String>['t', 'l', 'd', '1', '2', '$reminder'].join('|'),
      );

      expect(fingerprint(10), isNot(fingerprint(15)));
      expect(fingerprint(10), fingerprint(10));
    });
  });
}
