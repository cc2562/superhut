import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_schedule_event.dart';
import 'custom_schedule_store.dart';

/// 自定义日程的内存状态与增删改入口。
///
/// 数据层不认识日历同步：增删改成功后只回调 [onScheduleChanged]，
/// 由同步控制器在启动时挂上，避免这里反向依赖同步实现。
class CustomScheduleController extends GetxController {
  CustomScheduleController({CustomScheduleStore? store})
    : _store = store ?? CustomScheduleStore();

  final CustomScheduleStore _store;

  /// 全部日程（按开始时间升序）。
  final RxList<CustomScheduleEvent> events = <CustomScheduleEvent>[].obs;

  final RxBool loaded = false.obs;

  /// 学期起始日（`yyyy-MM-dd`），用于「指定周次」重复。
  final RxString semesterFirstDay = ''.obs;

  /// 学期总周数，编辑页的周次多选范围。
  final RxInt semesterMaxWeek = 0.obs;

  /// 日程发生变化后的回调（日历同步挂载点）。
  static void Function()? onScheduleChanged;

  static CustomScheduleController? get maybeInstance =>
      Get.isRegistered<CustomScheduleController>()
          ? Get.find<CustomScheduleController>()
          : null;

  /// 首次进入时加载；已加载过则直接返回。
  Future<void> ensureLoaded() async {
    if (loaded.value) return;
    await load();
  }

  Future<void> load() async {
    await reloadSemesterInfo();
    final List<CustomScheduleEvent> stored = await _store.load();
    events.assignAll(_sorted(stored));
    loaded.value = true;
  }

  /// 学期信息在 `firstWeek` / `maxWeek` / `firstDay` 里，刷新课表后会变。
  Future<void> reloadSemesterInfo() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    semesterFirstDay.value = prefs.getString('firstDay') ?? '';
    semesterMaxWeek.value = prefs.getInt('maxWeek') ?? 0;
  }

  /// [day] 当天生效的日程（已处理重复规则），按开始时间排序。
  List<CustomScheduleEvent> eventsOn(DateTime day) {
    final List<CustomScheduleEvent> matched = events
        .where(
          (CustomScheduleEvent event) =>
              event.occursOn(day, firstDay: semesterFirstDay.value),
        )
        .toList();
    matched.sort(
      (CustomScheduleEvent a, CustomScheduleEvent b) =>
          a.startMinuteOfDay.compareTo(b.startMinuteOfDay),
    );
    return matched;
  }

  CustomScheduleEvent? findById(String id) {
    for (final CustomScheduleEvent event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// 新增或按 id 覆盖；写盘失败时回滚内存状态。
  Future<void> upsert(CustomScheduleEvent event) async {
    final List<CustomScheduleEvent> next = events.toList();
    final int index = next.indexWhere(
      (CustomScheduleEvent item) => item.id == event.id,
    );
    if (index >= 0) {
      next[index] = event;
    } else {
      next.add(event);
    }
    await _commit(next);
  }

  Future<void> remove(String id) async {
    final List<CustomScheduleEvent> next = events
        .where((CustomScheduleEvent item) => item.id != id)
        .toList();
    if (next.length == events.length) return;
    await _commit(next);
  }

  Future<void> _commit(List<CustomScheduleEvent> next) async {
    final List<CustomScheduleEvent> previous = events.toList();
    events.assignAll(_sorted(next));
    try {
      await _store.save(events);
    } catch (error) {
      events.assignAll(previous);
      rethrow;
    }
    onScheduleChanged?.call();
  }

  List<CustomScheduleEvent> _sorted(Iterable<CustomScheduleEvent> source) {
    return source.toList()..sort(
      (CustomScheduleEvent a, CustomScheduleEvent b) =>
          a.start.compareTo(b.start),
    );
  }
}
