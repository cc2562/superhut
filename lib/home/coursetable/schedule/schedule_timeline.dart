import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../utils/course/class_time_table.dart';

/// 时间轴密度：一节 45 分钟 = 60px。
///
/// 取这个值是为了让单节课程块的高度与改造前（每节 60px）完全一致；
/// 课间因此拿到与真实时长成比例的空白，午休 140 分钟 ≈ 187px。
const double kPixelsPerMinute = 60 / ClassTimeTable.sectionMinutes;

/// 时间轴最少显示高度：极端情况下（一天只有 20 分钟的事）也不会缩成一条线。
const double kMinTimelineHeight = 240;

/// 一整天可用的分钟数。
const int kMinutesPerDay = 24 * 60;

/// 表示一天内某个区间的分钟数（距 00:00）。
@immutable
class TimelineEntry {
  const TimelineEntry(this.startMinute, this.endMinute);

  final int startMinute;
  final int endMinute;

  /// 把跨零点 / 越界的时间夹回当天，并保证结束晚于开始。
  TimelineEntry normalized() {
    final int start = startMinute.clamp(0, kMinutesPerDay - 1);
    int end = endMinute;
    if (end <= start) {
      // 跨零点（如 23:00 → 01:00）在课表页只画到 24:00。
      end = end < start ? kMinutesPerDay : start + 1;
    }
    return TimelineEntry(start, end.clamp(start + 1, kMinutesPerDay));
  }

  int get clampedStart => normalized().startMinute;
  int get clampedEnd => normalized().endMinute;
}

/// 时间轴上被「折叠」的区间：这段时间在显示时不占高度。
///
/// 目前用于午休（11:40–14:00）与晚饭（17:40–19:00）：跨越这些空档的自定义日程
/// 不会被撑长，上下两段直接紧贴。
@immutable
class TimelineFold {
  const TimelineFold({required this.startMinute, required this.endMinute});

  final int startMinute;
  final int endMinute;

  int get foldedMinutes => math.max(0, endMinute - startMinute);

  @override
  bool operator ==(Object other) =>
      other is TimelineFold &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}

/// 周视图纵向坐标系：把「当天的分钟」映射到日列里的像素。
@immutable
class TimelineWindow {
  const TimelineWindow({
    required this.startMinute,
    required this.endMinute,
    this.folds = const <TimelineFold>[],
  });

  /// 周视图固定窗口：第 1 节开始到最后一节结束，折叠午休与晚饭两段空档。
  ///
  /// 固定而非按当周内容收缩，是为了让没课的节次也保留空格子（节次是刻度），
  /// 同时让自定义日程的显示范围始终覆盖到第 12 节。
  factory TimelineWindow.weekGrid() {
    return TimelineWindow(
      startMinute: ClassTimeTable.sectionStartMinute(1),
      endMinute: ClassTimeTable.sectionEndMinute(ClassTimeTable.sectionCount),
      folds: <TimelineFold>[
        // 午休：第 4 节结束 → 第 5 节开始。
        TimelineFold(
          startMinute: ClassTimeTable.sectionEndMinute(4),
          endMinute: ClassTimeTable.sectionStartMinute(5),
        ),
        // 晚饭：第 8 节结束 → 第 9 节开始。
        TimelineFold(
          startMinute: ClassTimeTable.sectionEndMinute(8),
          endMinute: ClassTimeTable.sectionStartMinute(9),
        ),
      ],
    );
  }

  /// 没有任何内容时的兜底窗口（08:00–20:40，与节次表一致）。
  static const TimelineWindow fallback = TimelineWindow(
    startMinute: 8 * 60,
    endMinute: 20 * 60 + 40,
  );

  final int startMinute;
  final int endMinute;

  /// 不占高度的区间（午休、晚饭）；为空表示整条时间轴线性。
  final List<TimelineFold> folds;

  int get durationMinutes => math.max(1, endMinute - startMinute);

  /// 折叠后实际占用的分钟数：扣掉所有 [folds] 落在窗口内的部分。
  int get visibleMinutes {
    int total = durationMinutes;
    for (final TimelineFold fold in folds) {
      final int overlapStart = math.max(startMinute, fold.startMinute);
      final int overlapEnd = math.min(endMinute, fold.endMinute);
      if (overlapEnd > overlapStart) total -= overlapEnd - overlapStart;
    }
    return math.max(1, total);
  }

  /// 像素密度恒为 [kPixelsPerMinute]：节次高度不随当天内容多少而变。
  ///
  /// 「内容太少」由 [buildTimelineWindow] 向两侧补足时间解决，而不是放大比例，
  /// 否则一天只有一节课时，那块课程会被拉成一整屏。
  double get pixelsPerMinute => kPixelsPerMinute;

  double get height => visibleMinutes * pixelsPerMinute;

  /// 某个分钟数在日列中的纵坐标（越界钳到窗口内，折叠区间按 0 高度计）。
  double topFor(int minute) =>
      _minutesAbove(minute.clamp(startMinute, endMinute)) * pixelsPerMinute;

  /// 某个区间的显示高度（越界部分被裁掉，午休/晚饭等折叠区间不占高度）。
  double heightForRange(int start, int end) {
    final int from = math.max(start, startMinute);
    final int to = math.min(end, endMinute);
    if (to <= from) return 0;
    final int visible = _minutesAbove(to) - _minutesAbove(from);
    if (visible <= 0) return 0;
    return visible * pixelsPerMinute;
  }

  /// 窗口起点到 [minute] 之间实际占用的分钟数（折叠区间按 0 计）。
  int _minutesAbove(int minute) {
    int base = minute - startMinute;
    for (final TimelineFold fold in folds) {
      final int overlapStart = math.max(startMinute, fold.startMinute);
      final int overlapEnd = math.min(minute, fold.endMinute);
      if (overlapEnd > overlapStart) base -= overlapEnd - overlapStart;
    }
    return base;
  }

  @override
  bool operator ==(Object other) =>
      other is TimelineWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      listEquals(other.folds, folds);

  @override
  int get hashCode =>
      Object.hash(startMinute, endMinute, Object.hashAll(folds));
}

/// 由当周（或当天）的全部区间算出显示窗口。
///
/// 规则：取最早开始与最晚结束，上下各留 [padMinutes]，再向外对齐到 5 分钟；
/// 没有任何内容时回退到 [TimelineWindow.fallback]，避免整页空白一条细线。
TimelineWindow buildTimelineWindow(
  Iterable<TimelineEntry> entries, {
  int padMinutes = 15,
}) {
  final List<TimelineEntry> normalized = entries
      .map((TimelineEntry entry) => entry.normalized())
      .toList();
  if (normalized.isEmpty) return TimelineWindow.fallback;

  int start =
      normalized
          .map((TimelineEntry entry) => entry.startMinute)
          .reduce(math.min) -
      padMinutes;
  int end =
      normalized.map((TimelineEntry entry) => entry.endMinute).reduce(math.max) +
      padMinutes;

  // 内容太少时对称补足时间，让窗口至少能铺满 [kMinTimelineHeight]；
  // 补的是空白而不是放大比例，节次高度因此始终是 60px。
  final int minMinutes = (kMinTimelineHeight / kPixelsPerMinute).ceil();
  final int duration = end - start;
  if (duration < minMinutes) {
    final int extra = minMinutes - duration;
    start -= extra ~/ 2;
    end += extra - extra ~/ 2;
  }

  // 起点向下、终点向上对齐 5 分钟，刻度读起来不零碎。
  start = (start / 5).floor() * 5;
  end = (end / 5).ceil() * 5;

  // 夹回当天；贴到 00:00 / 24:00 时把缺口补到另一侧，尽量保持最小高度。
  if (start < 0) {
    end += -start;
    start = 0;
  }
  if (end > kMinutesPerDay) {
    start -= end - kMinutesPerDay;
    end = kMinutesPerDay;
  }
  start = start.clamp(0, kMinutesPerDay - 30);
  end = end.clamp(start + 30, kMinutesPerDay);
  return TimelineWindow(startMinute: start, endMinute: end);
}

/// 一簇在时间上互相重叠（含传递重叠）的条目。
@immutable
class TimelineCluster<T> {
  const TimelineCluster({
    required this.items,
    required this.startMinute,
    required this.endMinute,
  });

  final List<T> items;
  final int startMinute;
  final int endMinute;

  bool get hasOverlap => items.length > 1;
}

/// 把条目按时间重叠关系聚成一簇簇。
///
/// 簇内沿用课表原有的「同格纵向均分」布局；簇与簇之间按真实时间定位。
List<TimelineCluster<T>> clusterTimelineItems<T>(
  Iterable<T> items, {
  required int Function(T item) startOf,
  required int Function(T item) endOf,
}) {
  final List<T> sorted = items.toList()
    ..sort((T a, T b) {
      final int byStart = startOf(a).compareTo(startOf(b));
      if (byStart != 0) return byStart;
      return endOf(b).compareTo(endOf(a));
    });

  final List<TimelineCluster<T>> clusters = <TimelineCluster<T>>[];
  List<T> current = <T>[];
  int? currentStart;
  int? currentEnd;

  void flush() {
    if (current.isEmpty) return;
    clusters.add(
      TimelineCluster<T>(
        items: List<T>.unmodifiable(current),
        startMinute: currentStart!,
        endMinute: currentEnd!,
      ),
    );
    current = <T>[];
    currentStart = null;
    currentEnd = null;
  }

  for (final T item in sorted) {
    final int start = startOf(item);
    final int end = math.max(start + 1, endOf(item));
    if (current.isEmpty) {
      current = <T>[item];
      currentStart = start;
      currentEnd = end;
      continue;
    }
    if (start < currentEnd!) {
      current.add(item);
      currentEnd = math.max(currentEnd!, end);
      continue;
    }
    flush();
    current = <T>[item];
    currentStart = start;
    currentEnd = end;
  }
  flush();
  return clusters;
}

/// 重叠块「扇出」的横向步长。
///
/// 参考系统日历：时间重叠的块向右错开，右侧统一对齐，后开始的压在上层。
/// 缩进深度最多一层：第 0 层全宽，其余层都缩进同一格，
/// 层数再多也不继续收窄，最上层始终有可读宽度。
double cascadeStep({
  required double columnWidth,
  double minTopWidth = 26,
  double maxStep = 20,
}) {
  return math.min(maxStep, math.max(0, columnWidth - minTopWidth));
}

/// 左栏的一个节次标记（用于「1…10」的定位）。
@immutable
class TimelineSection {
  const TimelineSection({
    required this.section,
    required this.startMinute,
    required this.endMinute,
  });

  final int section;
  final int startMinute;
  final int endMinute;
}

/// 落在时间窗口内的节次（完全可见或部分可见）。
List<TimelineSection> sectionsInsideWindow(TimelineWindow window) {
  final List<TimelineSection> result = <TimelineSection>[];
  for (int section = 1; section <= ClassTimeTable.sectionCount; section++) {
    final int start = ClassTimeTable.sectionStartMinute(section);
    final int end = ClassTimeTable.sectionEndMinute(section);
    if (end <= window.startMinute || start >= window.endMinute) continue;
    result.add(
      TimelineSection(section: section, startMinute: start, endMinute: end),
    );
  }
  return result;
}
