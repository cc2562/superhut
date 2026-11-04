import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/coursetable/schedule/custom_schedule_event.dart';
import 'package:superhut/utils/course/calendar/calendar_gateway.dart';
import 'package:superhut/utils/course/calendar/calendar_sync_controller.dart';
import 'package:superhut/utils/course/coursemain.dart';

Course buildCourse({String location = '公共222'}) {
  return Course(
    name: '包装材料学',
    teacherName: '何新快',
    weekDuration: '1-16',
    location: location,
    startSection: 3,
    duration: 2,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryCalendarGateway gateway;
  late Map<String, List<Course>> courseData;
  late List<CustomScheduleEvent> schedules;
  late CalendarSyncController controller;

  Map<String, List<Course>> baseCourseData() => <String, List<Course>>{
    '2025-03-03': <Course>[buildCourse()],
    '2025-03-04': <Course>[buildCourse()],
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    gateway = InMemoryCalendarGateway();
    courseData = baseCourseData();
    schedules = <CustomScheduleEvent>[];
    controller = CalendarSyncController(
      gateway: gateway,
      courseLoader: () async => courseData,
      scheduleProvider: () => schedules,
    );
    await controller.load();
  });

  test('开启后写入整学期事件并记录簿记', () async {
    final bool ok = await controller.setEnabled(true);

    expect(ok, isTrue);
    expect(controller.enabled, isTrue);
    expect(gateway.calendars, hasLength(1));
    expect(gateway.calendars.values.single, hasLength(2));
    expect(controller.syncedCount, 2);
    expect(controller.lastSyncAt, isNotNull);
  });

  test('没有变化时二次同步不重写任何事件', () async {
    await controller.setEnabled(true);
    final int before = gateway.calendars.values.single.length;

    await controller.syncNow();

    expect(gateway.calendars.values.single.length, before);
    expect(gateway.deletedEventIds, isEmpty);
  });

  test('内容变化走更新而不是删了重建', () async {
    await controller.setEnabled(true);
    final List<String> idsBefore = gateway.calendars.values.single.toList();

    courseData = <String, List<Course>>{
      '2025-03-03': <Course>[buildCourse(location: '公共301')],
      '2025-03-04': <Course>[buildCourse(location: '公共301')],
    };
    await controller.syncNow();

    expect(gateway.deletedEventIds, isEmpty);
    expect(gateway.calendars.values.single, idsBefore);
  });

  test('课程移除后删除对应日历事件', () async {
    await controller.setEnabled(true);

    courseData = <String, List<Course>>{};
    await controller.syncNow();

    expect(gateway.deletedEventIds, hasLength(2));
    expect(gateway.calendars.values.single, isEmpty);
    expect(controller.syncedCount, 0);
  });

  test('新增日程后同步到日历', () async {
    await controller.setEnabled(true);

    schedules = <CustomScheduleEvent>[
      CustomScheduleEvent(
        id: 'schedule-1',
        title: '社团例会',
        start: DateTime(2025, 3, 5, 14),
        end: DateTime(2025, 3, 5, 16),
      ),
    ];
    await controller.syncNow();

    expect(gateway.calendars.values.single, hasLength(3));
    expect(controller.syncedCount, 3);
  });

  test('用户删掉专属日历后自动重建并补齐', () async {
    await controller.setEnabled(true);
    final String oldCalendarId = gateway.calendars.keys.single;
    gateway.calendars.remove(oldCalendarId);

    await controller.syncNow();

    expect(gateway.calendars, hasLength(1));
    expect(gateway.calendars.keys.single, isNot(oldCalendarId));
    expect(gateway.calendars.values.single, hasLength(2));
    expect(controller.syncedCount, 2);
  });

  test('权限被拒时开关回弹', () async {
    gateway.permissionGranted = false;

    final bool ok = await controller.setEnabled(true);

    expect(ok, isFalse);
    expect(controller.enabled, isFalse);
    expect(controller.lastError.value, isNotEmpty);
    expect(gateway.calendars, isEmpty);
  });

  test('清除已同步事件只删事件不删日历', () async {
    await controller.setEnabled(true);

    await controller.clearSyncedEvents();

    expect(gateway.deletedEventIds, hasLength(2));
    expect(gateway.calendars, hasLength(1));
    expect(controller.syncedCount, 0);
    expect(controller.lastError.value, isEmpty);
  });

  test('手动清除失败时保留簿记并提示不完整', () async {
    await controller.setEnabled(true);
    gateway.failDeletes = true;

    await controller.clearSyncedEvents();

    expect(controller.syncedCount, 2, reason: '删除失败的记录不能随清除一起丢掉');
    expect(controller.lastError.value, isNotEmpty);

    gateway.failDeletes = false;
    await controller.clearSyncedEvents();

    expect(controller.syncedCount, 0);
    expect(controller.lastError.value, isEmpty);
    expect(gateway.calendars.values.single, isEmpty);
  });

  test('写入失败时不写簿记，下次同步补写', () async {
    gateway.failWrites = true;
    await controller.setEnabled(true);

    expect(controller.syncedCount, 0);
    expect(gateway.calendars.values.single, isEmpty);

    gateway.failWrites = false;
    await controller.syncNow();

    expect(controller.syncedCount, 2);
    expect(gateway.calendars.values.single, hasLength(2));
  });

  test('更新失败时不推进指纹，下次同步会重试', () async {
    await controller.setEnabled(true);
    // 插入两条：一次批量写入。
    expect(gateway.writeCalls, 1);

    courseData = <String, List<Course>>{
      '2025-03-03': <Course>[buildCourse(location: '公共301')],
      '2025-03-04': <Course>[buildCourse(location: '公共301')],
    };
    gateway.failWrites = true;
    await controller.syncNow();
    // 这一轮尝试更新（失败），指纹不能被前移。
    expect(gateway.writeCalls, 2);
    expect(controller.syncedCount, 2);

    gateway.failWrites = false;
    await controller.syncNow();
    // 若失败时把新指纹写进了簿记，这一轮会判成「内容未变」而不再写入。
    expect(gateway.writeCalls, 3, reason: '更新失败的条目必须留在更新队列里');
  });

  test('删除失败时保留簿记，权限恢复后重试删除', () async {
    await controller.setEnabled(true);
    expect(controller.syncedCount, 2);

    courseData = <String, List<Course>>{};
    gateway.failDeletes = true;
    await controller.syncNow();

    expect(
      controller.syncedCount,
      2,
      reason: '删除失败的记录必须留在簿记里，否则日历里的残留事件再也无法清理',
    );
    expect(controller.lastError.value, isNotEmpty);

    gateway.failDeletes = false;
    await controller.syncNow();

    expect(controller.syncedCount, 0);
    expect(gateway.calendars.values.single, isEmpty);
  });
}
