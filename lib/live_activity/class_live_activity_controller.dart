import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/course/coursemain.dart';
import 'class_live_activity_scheduler.dart';
import 'class_live_activity_service.dart';

/// 灵动岛课程提醒的状态机：开关 + 课表快照 + 单定时器。
///
/// 触发时机只有两种：
/// * 定时器到点（App 在前台或尚未被系统挂起）；
/// * App 回到前台（`resumed`）时立刻重算，补齐后台期间错过的窗口。
///
/// App 被系统杀死后不会再触发，这是 iOS 的限制，不做额外兜底。
class ClassLiveActivityController extends GetxController
    with WidgetsBindingObserver {
  /// [scheduleLoader] 允许注入课表来源：默认读本地缓存文件（path_provider），
  /// 测试里换成固定快照，避免 widget 测试依赖原生插件与真实文件。
  ClassLiveActivityController({
    Future<Map<String, List<Course>>> Function()? scheduleLoader,
  }) : _scheduleLoader = scheduleLoader ?? loadClassFromLocal;

  final Future<Map<String, List<Course>>> Function() _scheduleLoader;

  /// 开关的持久化键，与「提醒设置」页共享。
  static const String enabledKey = 'liveActivity.enabled';

  /// 页面通过 GetX 注册后才能拿到；未注册时返回 null，便于课表页安全调用。
  static ClassLiveActivityController? get maybeInstance =>
      Get.isRegistered<ClassLiveActivityController>()
          ? Get.find<ClassLiveActivityController>()
          : null;

  final RxBool _enabled = true.obs;
  final RxBool _systemSupported = false.obs;

  /// 用户是否开启了灵动岛提醒（默认开启）。
  bool get enabled => _enabled.value;

  /// 系统是否允许实时活动（用户在系统设置里关掉后为 false）。
  bool get systemSupported => _systemSupported.value;

  /// 当前平台是否具备能力（只有 iOS 有 ActivityKit）。
  bool get platformSupported => ClassLiveActivityService.isPlatformSupported;

  /// 当前正在展示的课程 id，便于测试与排查。
  String? get activeCourseId => _activeCourseId;

  Map<String, List<Course>> _schedule = const <String, List<Course>>{};
  Timer? _timer;
  String? _activeCourseId;
  ClassLiveActivityPhase? _activePhase;
  bool _loaded = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 后台被挂起时 Dart 定时器不走，回到前台立刻补齐当前阶段；
      // 顺带重新探测一次系统开关，用户刚在「设置 > 实时活动」打开时立即生效。
      unawaited(refreshSystemSupport());
    }
  }

  /// 重新探测系统是否允许实时活动，并重算当前阶段。重复调用无副作用。
  Future<void> refreshSystemSupport() async {
    if (!ClassLiveActivityService.isPlatformSupported) return;
    final bool supported = await ClassLiveActivityService.isSupported();
    _systemSupported.value = supported;
    _reschedule();
  }

  /// 读取开关、补一份课表快照并探测系统能力；重复调用无副作用。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _enabled.value = prefs.getBool(enabledKey) ?? true;
    } catch (error) {
      debugPrint('读取灵动岛开关失败：$error');
    }
    // 快照恢复放后台跑：读本地文件失败或很慢都不该拖住开关与授权探测。
    unawaited(_restoreSchedule());
    await refreshSystemSupport();
  }

  /// 冷启动后用户可能还没进过课表页，这里直接从本地缓存补一份快照，
  /// 让「回到前台补发」在没有课表页的情况下也能工作。读取失败按无课处理。
  Future<void> _restoreSchedule() async {
    if (!ClassLiveActivityService.isPlatformSupported || _schedule.isNotEmpty) {
      return;
    }
    try {
      final Map<String, List<Course>> cached = await _scheduleLoader();
      if (cached.isEmpty) return;
      _schedule = cached;
      // 快照晚于首次计算到达：补一次计算，把当前应该展示的活动发出去。
      _reschedule();
    } catch (error) {
      debugPrint('读取本地课表失败，实时活动暂不展示：$error');
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled.value == value) return;
    _enabled.value = value;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledKey, value);
    } catch (error) {
      debugPrint('保存灵动岛开关失败：$error');
    }

    if (value) {
      _reschedule();
      return;
    }
    // 关闭后立刻收起，不停留在屏幕上。
    _timer?.cancel();
    _timer = null;
    await _endActive();
  }

  /// 课表加载/刷新后调用，替换快照并重新计算当前阶段。
  void syncSchedule(Map<String, List<Course>> schedule) {
    _schedule = schedule;
    _reschedule();
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!_enabled.value || !ClassLiveActivityService.isPlatformSupported) {
      return;
    }

    final DateTime now = DateTime.now();
    final ClassLiveActivityResolution resolution =
        ClassLiveActivityScheduler.resolve(_schedule, now);

    final ClassLiveActivityPlan? active = resolution.active;
    if (active == null) {
      unawaited(_endActive());
    } else {
      unawaited(_apply(active));
    }

    final DateTime? wakeUp = resolution.nextWakeUp;
    if (wakeUp == null) return;
    Duration delay = wakeUp.difference(now);
    // 至少 1 秒：系统时钟回拨等异常情况下，避免 0 延迟定时器自触发把主线程拖住。
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _timer = Timer(delay, _reschedule);
  }

  Future<void> _apply(ClassLiveActivityPlan plan) async {
    final bool sameCourse = _activeCourseId == plan.courseId;
    if (sameCourse && _activePhase == plan.phase) return;

    if (!sameCourse) {
      // 换课前必须先收掉上一节课的活动：原生 start 只会结束课程 id 相同的
      // 活动，上一节课（例如 08:45 结束、下一节同时进入提醒窗口）会一直留在
      // 灵动岛/通知栏；而 _activeCourseId 被覆盖后就再也找不到它来收尾了。
      await _endActive();
    }

    // 同一门课只做 update（阶段切换），避免反复 request 让灵动岛闪烁。
    final bool ok =
        sameCourse
            ? await ClassLiveActivityService.update(plan.toRequest())
            : await ClassLiveActivityService.start(plan.toRequest());
    if (!ok) {
      // 系统未授权或原生不可用：本次不展示，等下次重算再试。
      debugPrint('灵动岛提醒未展示：请检查系统「实时活动」设置');
      return;
    }
    _activeCourseId = plan.courseId;
    _activePhase = plan.phase;
  }

  Future<void> _endActive() async {
    final String? courseId = _activeCourseId;
    _activeCourseId = null;
    _activePhase = null;
    if (courseId == null) return;
    await ClassLiveActivityService.end(courseId);
  }
}
