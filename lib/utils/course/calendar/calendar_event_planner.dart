import 'package:flutter/foundation.dart';

import '../../../home/coursetable/schedule/custom_schedule_event.dart';
import '../class_time_table.dart';
import '../coursemain.dart';
import 'calendar_gateway.dart';

/// 系统日历里的一条「期望事件」。
///
/// 只有期望集是纯数据，具体写入交给 [CalendarGateway]，因此整个差量算法
/// 可以在没有平台能力的环境里单测。
@immutable
class PlannedCalendarEvent {
  const PlannedCalendarEvent({
    required this.key,
    required this.title,
    required this.location,
    required this.description,
    required this.startMillis,
    required this.endMillis,
    required this.reminderMinutes,
    required this.fingerprint,
    this.eventId,
  });

  /// 稳定标识：同一门课 / 同一次日程重复展开在每次同步里都得到同一个 key。
  final String key;

  final String title;
  final String location;
  final String description;
  final int startMillis;
  final int endMillis;
  final int reminderMinutes;

  /// 内容指纹；变了才需要更新日历事件。
  final int fingerprint;

  /// 已经写入过的事件 id；只在「更新」清单里出现。
  final String? eventId;

  PlannedCalendarEvent withEventId(String? id) => PlannedCalendarEvent(
    key: key,
    title: title,
    location: location,
    description: description,
    startMillis: startMillis,
    endMillis: endMillis,
    reminderMinutes: reminderMinutes,
    fingerprint: fingerprint,
    eventId: id,
  );

  CalendarEventPayload toPayload() => CalendarEventPayload(
    eventId: eventId,
    title: title,
    location: location,
    description: description,
    startMillis: startMillis,
    endMillis: endMillis,
    reminderMinutes: reminderMinutes,
  );
}

/// 已写入日历的事件簿记。
@immutable
class CalendarSyncRecord {
  const CalendarSyncRecord({required this.eventId, required this.fingerprint});

  final String eventId;
  final int fingerprint;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'fingerprint': fingerprint,
  };

  static CalendarSyncRecord? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? eventId = raw['eventId'];
    final Object? fingerprint = raw['fingerprint'];
    if (eventId is! String || eventId.isEmpty) return null;
    if (fingerprint is! int) return null;
    return CalendarSyncRecord(eventId: eventId, fingerprint: fingerprint);
  }
}

/// 一轮同步的差量结果。
@immutable
class CalendarSyncPlan {
  const CalendarSyncPlan({
    required this.inserts,
    required this.updates,
    required this.deleteEventIds,
    required this.unchanged,
  });

  final List<PlannedCalendarEvent> inserts;

  /// 需要原地更新的条目（[PlannedCalendarEvent.eventId] 已带上）。
  final List<PlannedCalendarEvent> updates;

  final List<String> deleteEventIds;

  /// 内容没变、可以原样保留的簿记。
  final Map<String, CalendarSyncRecord> unchanged;

  int get changeCount =>
      inserts.length + updates.length + deleteEventIds.length;

  bool get isEmpty => changeCount == 0;
}

/// FNV-1a 32 位指纹：只在内部分组比较，不需要密码学强度。
int calendarFingerprint(String value) {
  int hash = 0x811C9DC5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// 差量：期望集 vs 已写入簿记。
///
/// * 期望里没有、簿记里有的 → 删除；
/// * 期望里没有簿记的 → 新建；
/// * 指纹变了的 → 更新（沿用原事件 id，日历里不会出现删了又建的抖动）；
/// * 指纹相同 → 保持不动。
CalendarSyncPlan planCalendarSync({
  required List<PlannedCalendarEvent> desired,
  required Map<String, CalendarSyncRecord> records,
}) {
  final List<PlannedCalendarEvent> inserts = <PlannedCalendarEvent>[];
  final List<PlannedCalendarEvent> updates = <PlannedCalendarEvent>[];
  final Map<String, CalendarSyncRecord> unchanged =
      <String, CalendarSyncRecord>{};
  final Set<String> desiredKeys = <String>{};

  for (final PlannedCalendarEvent event in desired) {
    desiredKeys.add(event.key);
    final CalendarSyncRecord? record = records[event.key];
    if (record == null) {
      inserts.add(event);
      continue;
    }
    if (record.fingerprint != event.fingerprint) {
      updates.add(event.withEventId(record.eventId));
      continue;
    }
    unchanged[event.key] = record;
  }

  final List<String> deleteEventIds = <String>[];
  records.forEach((String key, CalendarSyncRecord record) {
    if (!desiredKeys.contains(key)) deleteEventIds.add(record.eventId);
  });

  return CalendarSyncPlan(
    inserts: inserts,
    updates: updates,
    deleteEventIds: deleteEventIds,
    unchanged: unchanged,
  );
}

/// 把课表与自定义日程展开成期望事件集。
///
/// [courseData] 的 key 是 `yyyy-MM-dd`，与 `course_data.json` 一致；
/// 自定义日程按自身重复规则展开，范围截止到学期末或它自己的结束日期。
List<PlannedCalendarEvent> buildDesiredCalendarEvents({
  required Map<String, List<Course>> courseData,
  required List<CustomScheduleEvent> schedules,
  required int reminderMinutes,
  String? firstDay,
}) {
  final List<PlannedCalendarEvent> events = <PlannedCalendarEvent>[];
  final List<String> dateKeys = courseData.keys.toList()..sort();
  final DateTime? semesterEnd = _semesterEnd(dateKeys);

  for (final String dateKey in dateKeys) {
    final DateTime? day = DateTime.tryParse(dateKey);
    if (day == null) continue;
    final List<Course> courses = courseData[dateKey] ?? const <Course>[];
    final Map<String, int> duplicateCounter = <String, int>{};

    for (final Course course in courses) {
      final Map<String, DateTime> range = ClassTimeTable.getCourseTimeRange(
        day,
        course,
      );
      final String baseKey =
          'course|$dateKey|${course.name}|${course.startSection}';
      final int index = duplicateCounter[baseKey] ?? 0;
      duplicateCounter[baseKey] = index + 1;

      final String description = <String>[
        if (course.teacherName.isNotEmpty) '教师：${course.teacherName}',
        if (course.weekDuration.isNotEmpty) '周次：${course.weekDuration}',
        '节次：第${course.startSection}–${course.startSection + course.duration - 1}节',
      ].join('\n');

      events.add(
        _buildEvent(
          key: '$baseKey|$index',
          title: course.name,
          location: course.location,
          description: description,
          startMillis: range['start']!.millisecondsSinceEpoch,
          endMillis: range['end']!.millisecondsSinceEpoch,
          reminderMinutes: reminderMinutes,
        ),
      );
    }
  }

  for (final CustomScheduleEvent schedule in schedules) {
    final DateTime startDay = scheduleDateOnly(schedule.start);
    DateTime endDay =
        schedule.repeatUntil ?? semesterEnd ?? schedule.start.add(const Duration(days: 180));
    if (endDay.isBefore(startDay)) endDay = startDay;

    final List<DateTime> occurrences = schedule.occurrencesBetween(
      startDay,
      endDay,
      firstDay: firstDay,
    );
    final Duration duration = schedule.end.difference(schedule.start);

    for (final DateTime day in occurrences) {
      final DateTime start = DateTime(
        day.year,
        day.month,
        day.day,
        schedule.start.hour,
        schedule.start.minute,
      );
      final DateTime end = start.add(duration);
      events.add(
        _buildEvent(
          key: 'custom|${schedule.id}|${scheduleFormatDate(day)}',
          title: schedule.title,
          location: schedule.location,
          description: schedule.note,
          startMillis: start.millisecondsSinceEpoch,
          endMillis: end.millisecondsSinceEpoch,
          reminderMinutes: reminderMinutes,
        ),
      );
    }
  }

  return events;
}

PlannedCalendarEvent _buildEvent({
  required String key,
  required String title,
  required String location,
  required String description,
  required int startMillis,
  required int endMillis,
  required int reminderMinutes,
}) {
  final int fingerprint = calendarFingerprint(
    <String>[
      title,
      location,
      description,
      '$startMillis',
      '$endMillis',
      '$reminderMinutes',
    ].join('|'),
  );
  return PlannedCalendarEvent(
    key: key,
    title: title,
    location: location,
    description: description,
    startMillis: startMillis,
    endMillis: endMillis,
    reminderMinutes: reminderMinutes,
    fingerprint: fingerprint,
  );
}

DateTime? _semesterEnd(List<String> sortedDateKeys) {
  for (int i = sortedDateKeys.length - 1; i >= 0; i--) {
    final DateTime? parsed = DateTime.tryParse(sortedDateKeys[i]);
    if (parsed != null) return parsed;
  }
  return null;
}
