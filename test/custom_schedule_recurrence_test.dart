import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/schedule/custom_schedule_event.dart';

CustomScheduleEvent buildEvent({
  DateTime? start,
  DateTime? end,
  ScheduleRepeat repeat = ScheduleRepeat.none,
  DateTime? repeatUntil,
  List<int> weeks = const <int>[],
}) {
  final DateTime startTime = start ?? DateTime(2025, 3, 5, 14, 0);
  return CustomScheduleEvent(
    id: 'event-1',
    title: '社团例会',
    start: startTime,
    end: end ?? startTime.add(const Duration(minutes: 90)),
    repeat: repeat,
    repeatUntil: repeatUntil,
    weeks: weeks,
  );
}

void main() {
  group('不重复', () {
    test('只在开始当天发生', () {
      final CustomScheduleEvent event = buildEvent();
      expect(event.occursOn(DateTime(2025, 3, 5)), isTrue);
      expect(event.occursOn(DateTime(2025, 3, 5, 23, 59)), isTrue);
      expect(event.occursOn(DateTime(2025, 3, 6)), isFalse);
      expect(event.occursOn(DateTime(2025, 3, 4)), isFalse);
    });
  });

  group('每天', () {
    test('没有结束日期时每天都发生', () {
      final CustomScheduleEvent event = buildEvent(repeat: ScheduleRepeat.daily);
      expect(event.occursOn(DateTime(2025, 3, 6)), isTrue);
      expect(event.occursOn(DateTime(2025, 6, 1)), isTrue);
      expect(event.occursOn(DateTime(2025, 3, 4)), isFalse);
    });

    test('结束日期当天仍然发生，次日停止', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.daily,
        repeatUntil: DateTime(2025, 3, 8),
      );
      expect(event.occursOn(DateTime(2025, 3, 8)), isTrue);
      expect(event.occursOn(DateTime(2025, 3, 9)), isFalse);
    });
  });

  group('每周', () {
    test('同星期才发生', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.weekly,
        repeatUntil: DateTime(2025, 4, 30),
      );
      expect(event.occursOn(DateTime(2025, 3, 12)), isTrue);
      expect(event.occursOn(DateTime(2025, 3, 13)), isFalse);
    });

    test('指定教学周时只在选中周发生', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.weekly,
        repeatUntil: DateTime(2025, 6, 30),
        weeks: <int>[1, 3],
      );
      const String firstDay = '2025-03-03';
      expect(
        event.occursOn(DateTime(2025, 3, 5), firstDay: firstDay),
        isTrue,
        reason: '第 1 周',
      );
      expect(
        event.occursOn(DateTime(2025, 3, 12), firstDay: firstDay),
        isFalse,
        reason: '第 2 周未选中',
      );
      expect(
        event.occursOn(DateTime(2025, 3, 19), firstDay: firstDay),
        isTrue,
        reason: '第 3 周',
      );
    });

    test('没有学期起始日时退化为普通每周重复', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.weekly,
        weeks: <int>[1],
      );
      expect(event.occursOn(DateTime(2025, 3, 12)), isTrue);
      expect(event.occursOn(DateTime(2025, 3, 13)), isFalse);
    });
  });

  group('每月', () {
    test('同一天号才发生', () {
      final CustomScheduleEvent event = buildEvent(
        start: DateTime(2025, 1, 15, 9, 0),
        repeat: ScheduleRepeat.monthly,
      );
      expect(event.occursOn(DateTime(2025, 2, 15)), isTrue);
      expect(event.occursOn(DateTime(2025, 2, 16)), isFalse);
      expect(event.occursOn(DateTime(2025, 1, 14)), isFalse);
    });

    test('没有 31 号的月份自动跳过', () {
      final CustomScheduleEvent event = buildEvent(
        start: DateTime(2025, 1, 31, 9, 0),
        repeat: ScheduleRepeat.monthly,
      );
      expect(event.occursOn(DateTime(2025, 2, 28)), isFalse);
      expect(event.occursOn(DateTime(2025, 3, 31)), isTrue);
    });
  });

  group('区间展开', () {
    test('只返回区间内的发生日期', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.daily,
        repeatUntil: DateTime(2025, 3, 10),
      );
      final List<DateTime> days = event.occurrencesBetween(
        DateTime(2025, 3, 6),
        DateTime(2025, 3, 9),
      );
      expect(days, <DateTime>[
        DateTime(2025, 3, 6),
        DateTime(2025, 3, 7),
        DateTime(2025, 3, 8),
        DateTime(2025, 3, 9),
      ]);
    });

    test('区间反向时返回空列表', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.daily,
      );
      expect(
        event.occurrencesBetween(
          DateTime(2025, 3, 9),
          DateTime(2025, 3, 6),
        ),
        isEmpty,
      );
    });
  });

  group('JSON', () {
    test('往返不丢字段', () {
      final CustomScheduleEvent event = buildEvent(
        repeat: ScheduleRepeat.weekly,
        repeatUntil: DateTime(2025, 6, 30),
        weeks: <int>[3, 5, 7],
      ).copyWith(location: '公共 302', note: '带材料');

      final CustomScheduleEvent? restored =
          CustomScheduleEvent.tryFromJson(event.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, event.id);
      expect(restored.title, event.title);
      expect(restored.location, '公共 302');
      expect(restored.note, '带材料');
      expect(restored.start, event.start);
      expect(restored.end, event.end);
      expect(restored.repeat, ScheduleRepeat.weekly);
      expect(restored.repeatUntil, DateTime(2025, 6, 30));
      expect(restored.weeks, <int>[3, 5, 7]);
    });

    test('结束早于开始的脏数据被丢弃', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'bad',
        'title': '坏数据',
        'start': DateTime(2025, 3, 5, 12).millisecondsSinceEpoch,
        'end': DateTime(2025, 3, 5, 11).millisecondsSinceEpoch,
      };
      expect(CustomScheduleEvent.tryFromJson(json), isNull);
    });
  });
}
