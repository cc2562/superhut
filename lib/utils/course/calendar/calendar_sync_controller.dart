import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../home/coursetable/schedule/custom_schedule_controller.dart';
import '../../../home/coursetable/schedule/custom_schedule_event.dart';
import '../coursemain.dart';
import 'calendar_event_planner.dart';
import 'calendar_gateway.dart';
import 'calendar_sync_store.dart';

/// 单向日历同步的调度中心。
///
/// 职责：串行执行、权限、差量写入、进度与错误状态。
/// 不读取日历内容，也不把日历里的改动回流到课表。
class CalendarSyncController extends GetxController {
  CalendarSyncController({
    CalendarGateway? gateway,
    CalendarSyncStore? store,
    Future<Map<String, List<Course>>> Function()? courseLoader,
    List<CustomScheduleEvent> Function()? scheduleProvider,
  }) : _gateway = gateway ?? const MethodChannelCalendarGateway(),
       _store = store ?? const CalendarSyncStore(),
       _courseLoader = courseLoader ?? loadClassFromLocal,
       _scheduleProvider = scheduleProvider;

  final CalendarGateway _gateway;
  final CalendarSyncStore _store;

  /// 课表数据来源；测试可注入，默认读 `course_data.json`。
  final Future<Map<String, List<Course>>> Function() _courseLoader;

  /// 自定义日程来源；测试可注入，默认读 GetX 控制器。
  final List<CustomScheduleEvent> Function()? _scheduleProvider;

  /// 单次通道调用的条数上限：一次写 200 条会让主线程等太久。
  static const int batchSize = 50;

  final Rx<CalendarSyncSettings> settings = const CalendarSyncSettings().obs;
  final RxBool syncing = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString lastError = ''.obs;
  final RxBool loaded = false.obs;

  static CalendarSyncController? get maybeInstance =>
      Get.isRegistered<CalendarSyncController>()
          ? Get.find<CalendarSyncController>()
          : null;

  Timer? _debounce;
  bool _rerunRequested = false;

  bool get isSupported => _gateway.isSupported;
  bool get enabled => settings.value.enabled;
  int get reminderMinutes => settings.value.reminderMinutes;
  int get syncedCount => settings.value.syncedCount;
  DateTime? get lastSyncAt {
    final int? millis = settings.value.lastSyncAtMillis;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    settings.value = await _store.load();
    loaded.value = true;
  }

  /// 打开 / 关闭同步。开启时会先申请权限，被拒则自动回弹。
  Future<bool> setEnabled(bool value) async {
    if (!isSupported) return false;
    if (!value) {
      await _store.saveEnabled(false);
      settings.value = settings.value.copyWith(enabled: false);
      return true;
    }

    final bool granted =
        await _gateway.hasPermission() || await _gateway.requestPermission();
    if (!granted) {
      lastError.value = '系统未授予日历权限';
      await _store.saveEnabled(false);
      settings.value = settings.value.copyWith(enabled: false);
      return false;
    }

    await _store.saveEnabled(true);
    settings.value = settings.value.copyWith(enabled: true);
    lastError.value = '';
    await syncNow();
    return true;
  }

  Future<void> setReminderMinutes(int minutes) async {
    await _store.saveReminderMinutes(minutes);
    settings.value = settings.value.copyWith(reminderMinutes: minutes);
    // 提醒时间参与指纹：改完要重新写一遍事件才能生效。
    if (enabled) await syncNow();
  }

  /// 日程增删改后调用：800ms 内的多次变化合并成一次同步。
  void notifyScheduleChanged() {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(syncNow());
    });
  }

  /// 预计会写入多少条事件（开启前的提示用）。
  Future<int> estimateEventCount() async {
    final PlannedData data = await _loadPlannedData();
    return data.desired.length;
  }

  /// 立即同步；并发调用会合并成「跑完再跑一次」。
  Future<void> syncNow() async {
    if (!isSupported || !enabled) return;
    if (syncing.value) {
      _rerunRequested = true;
      return;
    }

    syncing.value = true;
    progress.value = 0;
    try {
      await _syncOnce();
    } catch (error, stackTrace) {
      lastError.value = '同步失败：$error';
      debugPrint('日历同步失败: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      syncing.value = false;
    }

    if (_rerunRequested) {
      _rerunRequested = false;
      await syncNow();
    }
  }

  /// 删除本 App 写入的全部事件，但保留专属日历本身。
  Future<void> clearSyncedEvents() async {
    final CalendarSyncSettings current = settings.value;
    final String? calendarId = current.calendarId;
    if (calendarId != null) {
      final List<String> ids =
          current.records.values
              .map((CalendarSyncRecord record) => record.eventId)
              .toList();
      for (final List<String> chunk in _chunks(ids, batchSize)) {
        await _gateway.deleteEvents(calendarId: calendarId, eventIds: chunk);
      }
    }
    await _store.clearRecords();
    settings.value = current.copyWith(
      records: const <String, CalendarSyncRecord>{},
      lastSyncAtMillis: null,
    );
    progress.value = 0;
  }

  Future<void> _syncOnce() async {
    final bool granted =
        await _gateway.hasPermission() || await _gateway.requestPermission();
    if (!granted) {
      lastError.value = '系统未授予日历权限';
      await _store.saveEnabled(false);
      settings.value = settings.value.copyWith(enabled: false);
      return;
    }

    final String? calendarId = await _gateway.ensureCalendar(
      name: CalendarSyncStore.calendarName,
      color: CalendarSyncStore.calendarColor,
    );
    if (calendarId == null) {
      lastError.value = '创建「${CalendarSyncStore.calendarName}」日历失败';
      return;
    }

    CalendarSyncSettings current = settings.value;
    Map<String, CalendarSyncRecord> records = current.records;
    if (current.calendarId != calendarId) {
      // 用户可能在系统日历里删掉了专属日历：旧事件已经不存在，簿记作废后全量补齐。
      if (current.calendarId != null) {
        records = const <String, CalendarSyncRecord>{};
        await _store.clearRecords();
      }
      await _store.saveCalendarId(calendarId);
      current = current.copyWith(calendarId: calendarId, records: records);
      settings.value = current;
    }

    final PlannedData data = await _loadPlannedData();
    final CalendarSyncPlan plan = planCalendarSync(
      desired: data.desired,
      records: records,
    );

    final int total =
        plan.inserts.length + plan.updates.length + plan.deleteEventIds.length;
    int done = 0;
    void advance(int count) {
      done += count;
      progress.value = total == 0 ? 1 : (done / total).clamp(0.0, 1.0);
    }

    if (plan.isEmpty) {
      progress.value = 1;
      await _saveSyncResult(records: records);
      return;
    }

    for (final List<String> chunk in _chunks(plan.deleteEventIds, batchSize)) {
      await _gateway.deleteEvents(calendarId: calendarId, eventIds: chunk);
      advance(chunk.length);
    }

    final Map<String, CalendarSyncRecord> nextRecords =
        <String, CalendarSyncRecord>{...plan.unchanged};

    // 更新沿用原事件 id：日历里不会出现「删掉再建」的抖动。
    for (final List<PlannedCalendarEvent> chunk in _chunks(
      plan.updates,
      batchSize,
    )) {
      final List<String?> ids = await _gateway.writeEvents(
        calendarId: calendarId,
        events:
            chunk.map((PlannedCalendarEvent event) => event.toPayload()).toList(),
      );
      for (int i = 0; i < chunk.length; i++) {
        final String? id = ids[i] ?? chunk[i].eventId;
        if (id != null && id.isNotEmpty) {
          nextRecords[chunk[i].key] = CalendarSyncRecord(
            eventId: id,
            fingerprint: chunk[i].fingerprint,
          );
        }
      }
      advance(chunk.length);
    }

    for (final List<PlannedCalendarEvent> chunk in _chunks(
      plan.inserts,
      batchSize,
    )) {
      final List<String?> ids = await _gateway.writeEvents(
        calendarId: calendarId,
        events:
            chunk.map((PlannedCalendarEvent event) => event.toPayload()).toList(),
      );
      for (int i = 0; i < chunk.length; i++) {
        final String? id = ids[i];
        // 写入失败的条目不进簿记，下次同步会重新补上。
        if (id != null && id.isNotEmpty) {
          nextRecords[chunk[i].key] = CalendarSyncRecord(
            eventId: id,
            fingerprint: chunk[i].fingerprint,
          );
        }
      }
      advance(chunk.length);
    }

    await _saveSyncResult(records: nextRecords);
    lastError.value = '';
    debugPrint(
      '日历同步完成：新增 ${plan.inserts.length}、更新 ${plan.updates.length}、'
      '删除 ${plan.deleteEventIds.length}',
    );
  }

  Future<void> _saveSyncResult({
    required Map<String, CalendarSyncRecord> records,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _store.saveAfterSync(records: records, lastSyncAtMillis: now);
    settings.value = settings.value.copyWith(
      records: records,
      lastSyncAtMillis: now,
    );
  }

  Future<PlannedData> _loadPlannedData() async {
    final List<CustomScheduleEvent> schedules =
        _scheduleProvider?.call() ?? await _loadSchedules();

    final Map<String, List<Course>> courseData = await _courseLoader();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    return PlannedData(
      buildDesiredCalendarEvents(
        courseData: courseData,
        schedules: schedules,
        reminderMinutes: settings.value.reminderMinutes,
        firstDay: prefs.getString('firstDay'),
      ),
    );
  }

  Future<List<CustomScheduleEvent>> _loadSchedules() async {
    final CustomScheduleController? scheduleController =
        CustomScheduleController.maybeInstance;
    await scheduleController?.ensureLoaded();
    return scheduleController?.events.toList() ?? const <CustomScheduleEvent>[];
  }

  Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
    for (int start = 0; start < items.length; start += size) {
      yield items.sublist(start, math.min(start + size, items.length));
    }
  }
}

/// 期望事件集的包装：留出后续扩展（比如同步窗口）的位置。
@immutable
class PlannedData {
  const PlannedData(this.desired);

  final List<PlannedCalendarEvent> desired;
}
