import 'package:get/get.dart';

import '../../utils/course/class_time_table.dart';
import '../../utils/course/coursemain.dart';
/*
 * 课程数据模型类
 * @param name 课程名称
 * @param startSection 课程开始的节数（1-based）
 * @param duration 课程持续节数
 */

class CourseTableViewLogic extends GetxController {}

enum CourseTableViewMode { week, day }

CourseTableViewMode courseTableViewModeFromPreference(String? value) {
  return value == CourseTableViewMode.day.name
      ? CourseTableViewMode.day
      : CourseTableViewMode.week;
}

class CourseDaySelection {
  final DateTime date;
  final int week;

  const CourseDaySelection({required this.date, required this.week});
}

DateTime normalizeCourseDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

int? calculateSchoolWeekFromFirstDay(String? firstDayValue, DateTime now) {
  if (firstDayValue == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(firstDayValue)) {
    return null;
  }

  final firstDay = DateTime.tryParse(firstDayValue);
  if (firstDay == null) {
    return null;
  }
  final dateParts = firstDayValue.split('-').map(int.parse).toList();
  if (firstDay.year != dateParts[0] ||
      firstDay.month != dateParts[1] ||
      firstDay.day != dateParts[2]) {
    return null;
  }
  final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
  final difference =
      normalizeCourseDate(now).difference(firstMonday).inDays + 1;
  if (difference < 0) {
    return 0;
  }
  return (difference / 7).ceil();
}

bool isSameCourseDate(DateTime first, DateTime second) {
  return normalizeCourseDate(first) == normalizeCourseDate(second);
}

CourseDaySelection moveCourseTableDay({
  required DateTime date,
  required int currentWeek,
  required int allWeeks,
  required int dayDelta,
}) {
  assert(dayDelta == -1 || dayDelta == 1);
  final normalizedDate = normalizeCourseDate(date);
  if (dayDelta < 0 &&
      currentWeek <= 1 &&
      normalizedDate.weekday == DateTime.monday) {
    return CourseDaySelection(date: normalizedDate, week: currentWeek);
  }
  if (dayDelta > 0 &&
      currentWeek >= allWeeks &&
      normalizedDate.weekday == DateTime.sunday) {
    return CourseDaySelection(date: normalizedDate, week: currentWeek);
  }

  final nextDate = normalizeCourseDate(
    normalizedDate.add(Duration(days: dayDelta)),
  );
  var nextWeek = currentWeek;
  if (dayDelta < 0 && normalizedDate.weekday == DateTime.monday) {
    nextWeek--;
  } else if (dayDelta > 0 && normalizedDate.weekday == DateTime.sunday) {
    nextWeek++;
  }
  return CourseDaySelection(date: nextDate, week: nextWeek);
}

List<Course> sortCoursesForDay(Iterable<Course> courses) {
  return courses.toList()..sort((first, second) {
    final sectionComparison = first.startSection.compareTo(second.startSection);
    if (sectionComparison != 0) {
      return sectionComparison;
    }
    return first.name.compareTo(second.name);
  });
}

/// Returns every course at the earliest start time that has not started yet.
List<Course> findNextCoursesForDay({
  required DateTime day,
  required DateTime now,
  required Iterable<Course> courses,
}) {
  if (!isSameCourseDate(day, now)) {
    return const [];
  }

  final sortedCourses = sortCoursesForDay(courses);
  DateTime? nextStart;
  final nextCourses = <Course>[];

  for (final course in sortedCourses) {
    final start = ClassTimeTable.getCourseTimeRange(day, course)['start']!;
    if (!start.isAfter(now)) {
      continue;
    }
    if (nextStart == null) {
      nextStart = start;
      nextCourses.add(course);
      continue;
    }
    if (start == nextStart) {
      nextCourses.add(course);
      continue;
    }
    break;
  }

  return nextCourses;
}
