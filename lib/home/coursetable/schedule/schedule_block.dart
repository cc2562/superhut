import 'package:flutter/foundation.dart';

import '../../../utils/course/class_time_table.dart';
import '../../../utils/course/coursemain.dart';
import 'custom_schedule_event.dart';
import 'schedule_timeline.dart';

/// 课表页里的一个块：要么是教务课程，要么是用户自建日程。
enum DayBlockKind { course, schedule }

/// 周视图 / 日视图共用的块模型。
///
/// 只保存「什么时候、是什么」，颜色由外层按课程哈希或用户选色决定，
/// 因此布局纯函数可以脱离 BuildContext 单测。
@immutable
class DayBlock {
  const DayBlock({required this.kind, this.course, this.schedule});

  const DayBlock.course(Course this.course)
    : kind = DayBlockKind.course,
      schedule = null;

  const DayBlock.schedule(CustomScheduleEvent this.schedule)
    : kind = DayBlockKind.schedule,
      course = null;

  final DayBlockKind kind;
  final Course? course;
  final CustomScheduleEvent? schedule;

  bool get isCourse => kind == DayBlockKind.course;

  int get startMinute => isCourse
      ? courseStartMinute(course!)
      : schedule!.startMinuteOfDay;

  int get endMinute => isCourse
      ? courseEndMinute(course!)
      : scheduleEndMinute(schedule!);

  TimelineEntry get entry => TimelineEntry(startMinute, endMinute);

  String get title => isCourse ? course!.name : schedule!.title;

  String get location => isCourse ? course!.location : schedule!.location;

  /// 块上的次要信息：课程显示教师，日程显示地点。
  String get secondary {
    if (isCourse) return course!.teacherName;
    return schedule!.location;
  }

  String get note => isCourse ? '' : schedule!.note;

  /// 课程节次文本（日程没有节次概念，返回空串）。
  String get sectionLabel {
    if (!isCourse) return '';
    final int endSection = course!.startSection + course!.duration - 1;
    return '第${course!.startSection}–$endSection节';
  }
}

/// 课程起始分钟（按节次时间表换算）。
int courseStartMinute(Course course) =>
    ClassTimeTable.sectionStartMinute(course.startSection);

/// 课程结束分钟（含跨节内部的课间）。
int courseEndMinute(Course course) => ClassTimeTable.sectionEndMinute(
  course.startSection + course.duration - 1,
);

/// 日程结束分钟；跨零点时画到 24:00。
int scheduleEndMinute(CustomScheduleEvent event) {
  final int start = event.startMinuteOfDay;
  final int end = event.endMinuteOfDay;
  if (!event.spansMidnight && end > start) return end;
  return kMinutesPerDay;
}

/// 把某一天的课程与日程合并成统一的块列表（按开始时间升序）。
List<DayBlock> buildDayBlocks({
  required Iterable<Course> courses,
  required Iterable<CustomScheduleEvent> schedules,
}) {
  final List<DayBlock> blocks = <DayBlock>[
    for (final Course course in courses) DayBlock.course(course),
    for (final CustomScheduleEvent schedule in schedules)
      DayBlock.schedule(schedule),
  ];
  blocks.sort((DayBlock a, DayBlock b) {
    final int byStart = a.startMinute.compareTo(b.startMinute);
    if (byStart != 0) return byStart;
    // 同一时刻先画课程，日程叠在后面，视觉上「课表优先」。
    if (a.isCourse != b.isCourse) return a.isCourse ? -1 : 1;
    return a.title.compareTo(b.title);
  });
  return blocks;
}
