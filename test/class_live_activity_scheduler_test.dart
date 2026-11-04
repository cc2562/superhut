import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/live_activity/class_live_activity_scheduler.dart';
import 'package:superhut/live_activity/class_live_activity_service.dart';
import 'package:superhut/utils/course/coursemain.dart';

/// 固定测试日期：2026-11-02（周一）。
const String _dateKey = '2026-11-02';

Course _course({
  required String name,
  required int startSection,
  int duration = 2,
  String location = 'A101',
}) {
  return Course(
    name: name,
    teacherName: '老师',
    weekDuration: '1-16',
    location: location,
    startSection: startSection,
    duration: duration,
  );
}

void main() {
  // 第一节 08:00-09:40，第五节 14:00-15:40；课前窗口各提前 10 分钟。
  final Course math = _course(name: '高等数学', startSection: 1);
  final Course english = _course(
    name: '大学英语',
    startSection: 5,
    location: 'B203',
  );
  final Map<String, List<Course>> schedule = <String, List<Course>>{
    _dateKey: <Course>[math, english],
  };

  DateTime at(int hour, int minute, {int second = 0, int day = 2}) =>
      DateTime(2026, 11, day, hour, minute, second);

  test('空课表不展示任何活动，也不需要唤醒', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(
          const <String, List<Course>>{},
          at(8, 0),
        );

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, isNull);
  });

  test('课前窗口前 1 秒不展示，但在窗口起点唤醒', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(7, 49));

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, at(7, 50));
  });

  test('窗口起点进入课前阶段，倒计时到上课时间', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(7, 50));

    expect(resolution.active, isNotNull);
    expect(resolution.active!.phase, ClassLiveActivityPhase.preClass);
    expect(resolution.active!.courseName, '高等数学');
    expect(resolution.active!.location, 'A101');
    expect(resolution.active!.start, at(8, 0));
    expect(resolution.active!.end, at(9, 40));
    expect(resolution.active!.nextTransition, at(8, 0));
    expect(resolution.nextWakeUp, at(8, 0));
  });

  test('上课前 1 秒仍是课前阶段', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(7, 59, second: 59));

    expect(resolution.active!.phase, ClassLiveActivityPhase.preClass);
    expect(resolution.nextWakeUp, at(8, 0));
  });

  test('上课时间点切换为上课中，倒计时到下课时间', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(8, 0));

    expect(resolution.active!.phase, ClassLiveActivityPhase.inClass);
    expect(resolution.active!.nextTransition, at(9, 40));
    expect(resolution.nextWakeUp, at(9, 40));
  });

  test('下课前 1 分钟仍是上课中', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(9, 39));

    expect(resolution.active!.phase, ClassLiveActivityPhase.inClass);
    expect(resolution.nextWakeUp, at(9, 40));
  });

  test('下课后立即收起，并指向下一节课的课前窗口', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(9, 40));

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, at(13, 50));
  });

  test('两节课之间的空档展示下一节课的窗口起点', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(12, 0));

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, at(13, 50));
  });

  test('下一节课的课前窗口按自身时间计算', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(13, 55));

    expect(resolution.active, isNotNull);
    expect(resolution.active!.courseName, '大学英语');
    expect(resolution.active!.location, 'B203');
    expect(resolution.active!.phase, ClassLiveActivityPhase.preClass);
    expect(resolution.nextWakeUp, at(14, 0));
  });

  test('当天最后一节课结束后不再唤醒', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(21, 0));

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, isNull);
  });

  test('课表没有当天数据时按无课处理', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(9, 0, day: 3));

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, isNull);
  });

  test('非法日期键被跳过，不影响其它条目', () {
    final Map<String, List<Course>> mixed = <String, List<Course>>{
      'not-a-date': <Course>[math],
      _dateKey: <Course>[english],
    };

    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(mixed, at(9, 0));

    expect(resolution.active, isNull);
    expect(resolution.nextWakeUp, at(13, 50));
  });

  test('courseId 区分日期与节次，避免把下周同名课当成同一场活动', () {
    final ClassLiveActivityResolution today =
        ClassLiveActivityScheduler.resolve(schedule, at(8, 30));

    expect(today.active!.courseId, '$_dateKey|1|高等数学');
    expect(today.active!.courseId, isNot(contains('大学英语')));
  });

  test('toRequest 透传阶段与时间，供原生构造 ContentState', () {
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(schedule, at(8, 30));
    final ClassLiveActivityRequest request = resolution.active!.toRequest();

    expect(request.phase, ClassLiveActivityPhase.inClass);
    expect(request.phase.wireValue, 'inClass');
    expect(request.courseId, '$_dateKey|1|高等数学');
    expect(request.start, at(8, 0));
    expect(request.end, at(9, 40));

    final Map<String, Object> map = request.toMap();
    expect(map['phase'], 'inClass');
    expect(map['courseName'], '高等数学');
    expect(map['location'], 'A101');
    expect(map['startTimeMs'], at(8, 0).millisecondsSinceEpoch);
    expect(map['endTimeMs'], at(9, 40).millisecondsSinceEpoch);
  });
}
