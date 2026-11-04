import '../utils/course/class_time_table.dart';
import '../utils/course/coursemain.dart';
import 'class_live_activity_service.dart';

/// 某一时刻应当展示的实时活动。
class ClassLiveActivityPlan {
  const ClassLiveActivityPlan({
    required this.courseId,
    required this.courseName,
    required this.location,
    required this.start,
    required this.end,
    required this.phase,
  });

  final String courseId;
  final String courseName;
  final String location;
  final DateTime start;
  final DateTime end;
  final ClassLiveActivityPhase phase;

  /// 下一次阶段切换的时间：课前窗口结束于上课时间，上课中结束于下课时间。
  DateTime get nextTransition =>
      phase == ClassLiveActivityPhase.preClass ? start : end;

  ClassLiveActivityRequest toRequest() => ClassLiveActivityRequest(
    courseId: courseId,
    courseName: courseName,
    location: location,
    start: start,
    end: end,
    phase: phase,
  );
}

/// 一次计算的结果：当前要展示什么、下一次需要重新计算的时间。
class ClassLiveActivityResolution {
  const ClassLiveActivityResolution({this.active, this.nextWakeUp});

  final ClassLiveActivityPlan? active;
  final DateTime? nextWakeUp;
}

/// 把课表换算成实时活动的「当前阶段 + 下一次唤醒时间」。
///
/// 纯函数，不读时钟也不碰原生：`now` 由调用方传入，便于单测边界。
class ClassLiveActivityScheduler {
  const ClassLiveActivityScheduler._();

  /// 上课前多久开始展示倒计时。
  static const Duration preClassLead = Duration(minutes: 10);

  /// [schedule] 的 key 为 `yyyy-MM-dd`，与 `course_data.json` 一致。
  static ClassLiveActivityResolution resolve(
    Map<String, List<Course>> schedule,
    DateTime now,
  ) {
    final List<_ClassSlot> slots = <_ClassSlot>[];
    schedule.forEach((String dateKey, List<Course> courses) {
      final DateTime? date = DateTime.tryParse(dateKey);
      if (date == null) return;
      for (final Course course in courses) {
        final Map<String, DateTime> range = ClassTimeTable.getCourseTimeRange(
          date,
          course,
        );
        slots.add(
          _ClassSlot(
            dateKey: dateKey,
            course: course,
            start: range['start']!,
            end: range['end']!,
          ),
        );
      }
    });
    slots.sort((_ClassSlot a, _ClassSlot b) => a.start.compareTo(b.start));

    // 当前处在某个窗口内：课前 10 分钟 ~ 下课。
    for (final _ClassSlot slot in slots) {
      final DateTime windowStart = slot.start.subtract(preClassLead);
      if (now.isBefore(windowStart) || !now.isBefore(slot.end)) continue;
      final bool isPreClass = now.isBefore(slot.start);
      return ClassLiveActivityResolution(
        active: ClassLiveActivityPlan(
          courseId: slot.courseId,
          courseName: slot.course.name,
          location: slot.course.location,
          start: slot.start,
          end: slot.end,
          phase:
              isPreClass
                  ? ClassLiveActivityPhase.preClass
                  : ClassLiveActivityPhase.inClass,
        ),
        nextWakeUp: isPreClass ? slot.start : slot.end,
      );
    }

    // 不在任何窗口内：找到下一个窗口的起点，到点再计算一次。
    for (final _ClassSlot slot in slots) {
      final DateTime windowStart = slot.start.subtract(preClassLead);
      if (windowStart.isAfter(now)) {
        return ClassLiveActivityResolution(nextWakeUp: windowStart);
      }
    }

    return const ClassLiveActivityResolution();
  }
}

class _ClassSlot {
  const _ClassSlot({
    required this.dateKey,
    required this.course,
    required this.start,
    required this.end,
  });

  final String dateKey;
  final Course course;
  final DateTime start;
  final DateTime end;

  /// 同一门课在不同日期、不同节次要区分开，避免把下周的同名课当成同一场活动。
  String get courseId => '$dateKey|${course.startSection}|${course.name}';
}
