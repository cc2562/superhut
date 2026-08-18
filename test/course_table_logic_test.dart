import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/logic.dart';
import 'package:superhut/utils/course/class_time_table.dart';
import 'package:superhut/utils/course/coursemain.dart';

Course _course(String name, int startSection, {int duration = 1}) {
  return Course(
    name: name,
    teacherName: '教师',
    weekDuration: '1-20周',
    location: '教学楼',
    startSection: startSection,
    duration: duration,
  );
}

void main() {
  final day = DateTime(2026, 8, 17);

  test('view mode preference defaults to week and restores day', () {
    expect(courseTableViewModeFromPreference(null), CourseTableViewMode.week);
    expect(
      courseTableViewModeFromPreference('unexpected'),
      CourseTableViewMode.week,
    );
    expect(courseTableViewModeFromPreference('day'), CourseTableViewMode.day);
  });

  group('calculateSchoolWeekFromFirstDay', () {
    test(
      'returns null instead of failing when semester date is unavailable',
      () {
        expect(calculateSchoolWeekFromFirstDay(null, day), isNull);
        expect(calculateSchoolWeekFromFirstDay('invalid', day), isNull);
        expect(calculateSchoolWeekFromFirstDay('2026-99-99', day), isNull);
      },
    );

    test('calculates the school week from the first calendar week', () {
      expect(calculateSchoolWeekFromFirstDay('2026-08-03', day), 3);
      expect(
        calculateSchoolWeekFromFirstDay('2026-08-24', DateTime(2026, 8, 17)),
        0,
      );
    });
  });

  group('moveCourseTableDay', () {
    test('moves within a week without changing the week number', () {
      final result = moveCourseTableDay(
        date: DateTime(2026, 8, 18),
        currentWeek: 3,
        allWeeks: 20,
        dayDelta: 1,
      );

      expect(result.date, DateTime(2026, 8, 19));
      expect(result.week, 3);
    });

    test('updates the week number when crossing Sunday or Monday', () {
      final next = moveCourseTableDay(
        date: DateTime(2026, 8, 23),
        currentWeek: 3,
        allWeeks: 20,
        dayDelta: 1,
      );
      final previous = moveCourseTableDay(
        date: DateTime(2026, 8, 17),
        currentWeek: 3,
        allWeeks: 20,
        dayDelta: -1,
      );

      expect(next.date, DateTime(2026, 8, 24));
      expect(next.week, 4);
      expect(previous.date, DateTime(2026, 8, 16));
      expect(previous.week, 2);
    });

    test('stops at the semester boundaries', () {
      final firstDay = moveCourseTableDay(
        date: DateTime(2026, 8, 17),
        currentWeek: 1,
        allWeeks: 20,
        dayDelta: -1,
      );
      final lastDay = moveCourseTableDay(
        date: DateTime(2026, 8, 23),
        currentWeek: 20,
        allWeeks: 20,
        dayDelta: 1,
      );

      expect(firstDay.date, DateTime(2026, 8, 17));
      expect(firstDay.week, 1);
      expect(lastDay.date, DateTime(2026, 8, 23));
      expect(lastDay.week, 20);
    });
  });

  group('findNextCoursesForDay', () {
    test('returns the earliest course that has not started', () {
      final courses = [_course('第三节', 3), _course('第一节', 1)];

      final result = findNextCoursesForDay(
        day: day,
        now: DateTime(2026, 8, 17, 7, 30),
        courses: courses,
      );

      expect(result.map((course) => course.name), ['第一节']);
    });

    test('skips a course once its start time has arrived', () {
      final result = findNextCoursesForDay(
        day: day,
        now: DateTime(2026, 8, 17, 8),
        courses: [_course('第一节', 1), _course('第三节', 3)],
      );

      expect(result.map((course) => course.name), ['第三节']);
    });

    test('skips an ongoing multi-section course', () {
      final result = findNextCoursesForDay(
        day: day,
        now: DateTime(2026, 8, 17, 8, 30),
        courses: [_course('正在上课', 1, duration: 2), _course('下一门课', 3)],
      );

      expect(result.map((course) => course.name), ['下一门课']);
    });

    test('returns every course sharing the next start time', () {
      final result = findNextCoursesForDay(
        day: day,
        now: DateTime(2026, 8, 17, 9, 45),
        courses: [_course('课程B', 3), _course('课程A', 3), _course('稍后', 5)],
      );

      expect(result.map((course) => course.name), ['课程A', '课程B']);
    });

    test('returns empty after the final course and for another date', () {
      final courses = [_course('晚课', 9)];

      expect(
        findNextCoursesForDay(
          day: day,
          now: DateTime(2026, 8, 17, 21),
          courses: courses,
        ),
        isEmpty,
      );
      expect(
        findNextCoursesForDay(
          day: day,
          now: DateTime(2026, 8, 18, 7),
          courses: courses,
        ),
        isEmpty,
      );
    });
  });

  test('sortCoursesForDay returns a sorted copy', () {
    final original = [_course('晚课', 9), _course('早课', 1)];

    final sorted = sortCoursesForDay(original);

    expect(sorted.map((course) => course.name), ['早课', '晚课']);
    expect(original.map((course) => course.name), ['晚课', '早课']);
  });

  test('ClassTimeTable covers a multi-section course', () {
    final range = ClassTimeTable.getCourseTimeRange(
      day,
      _course('连续课程', 1, duration: 2),
    );

    expect(range['start'], DateTime(2026, 8, 17, 8));
    expect(range['end'], DateTime(2026, 8, 17, 9, 40));
  });
}
