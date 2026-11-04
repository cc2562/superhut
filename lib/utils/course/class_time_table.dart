import 'package:superhut/utils/course/coursemain.dart';

/// Defines the real-world start and end times for each class section (1-10)
class ClassTimeTable {
  // Key: section number (1-10)
  // Value: [startHour, startMinute, endHour, endMinute]
  static const Map<int, List<int>> _times = {
    1: [8, 0, 8, 45],
    2: [8, 55, 9, 40],
    3: [10, 0, 10, 45],
    4: [10, 55, 11, 40],
    5: [14, 0, 14, 45],
    6: [14, 55, 15, 40],
    7: [16, 0, 16, 45],
    8: [16, 55, 17, 40],
    9: [19, 0, 19, 45],
    10: [19, 55, 20, 40],
    // 学校实际只排到第 10 节。第 11、12 节是为自定义日程预留的显示范围（到 22:40），
    // 教务课程不会落在这些节次上。
    11: [20, 55, 21, 40],
    12: [21, 55, 22, 40],
  };

  /// 节次总数。课表页的时间轴据此生成左侧节次号。
  static const int sectionCount = 12;

  /// 单节时长（分钟）。时间轴密度按「一节 45 分钟 = 60px」换算。
  static const int sectionMinutes = 45;

  /// 某一节的原始时间表；越界返回 `null`。
  static List<int>? sectionTimes(int section) => _times[section];

  /// 某一节开始时刻距当天 00:00 的分钟数；越界按第 1 节处理。
  static int sectionStartMinute(int section) {
    final List<int> times = _times[section] ?? _times[1]!;
    return times[0] * 60 + times[1];
  }

  /// 某一节结束时刻距当天 00:00 的分钟数；越界按最后一节处理。
  static int sectionEndMinute(int section) {
    final List<int> times = _times[section] ?? _times[_times.length]!;
    return times[2] * 60 + times[3];
  }

  /// Calculates the exact start and end DateTime for a Course on a specific base Date.
  ///
  /// [baseDate] The calendar date (e.g. today or sometime this week) the class falls on.
  /// [course] The course object containing startSection and duration.
  ///
  /// Returns a Map with 'start' and 'end' DateTime objects.
  static Map<String, DateTime> getCourseTimeRange(
    DateTime baseDate,
    Course course,
  ) {
    int startSec = course.startSection;
    int endSec = course.startSection + course.duration - 1;

    // Fallback if section is out of bounds
    if (!_times.containsKey(startSec)) {
      startSec = 1;
    }
    if (!_times.containsKey(endSec)) {
      endSec = startSec;
    }

    final startList = _times[startSec]!;
    final endList = _times[endSec]!;

    final startTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      startList[0],
      startList[1],
    );

    final endTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      endList[2],
      endList[3],
    );

    return {'start': startTime, 'end': endTime};
  }
}
