import 'package:flutter/material.dart';

import '../logic.dart' show calculateSchoolWeekFromFirstDay;

/// 只保留年月日，便于比较「同一天」。
DateTime scheduleDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 自定义日程的重复方式。
enum ScheduleRepeat {
  none('不重复'),
  daily('每天'),
  weekly('每周'),
  monthly('每月');

  const ScheduleRepeat(this.label);

  final String label;

  static ScheduleRepeat parse(String? value) => values.firstWhere(
    (ScheduleRepeat repeat) => repeat.name == value,
    orElse: () => ScheduleRepeat.none,
  );
}

/// 日程可选的预设颜色（与课程名的哈希配色刻意区分：这组更饱和、更「记事本」）。
class ScheduleColors {
  const ScheduleColors._();

  static const List<int> presets = <int>[
    0xFFE53935, // 红
    0xFFFB8C00, // 橙
    0xFFFDD835, // 黄
    0xFF43A047, // 绿
    0xFF00ACC1, // 青
    0xFF1E88E5, // 蓝
    0xFF8E24AA, // 紫
    0xFFD81B60, // 玫红
  ];

  static const int defaultColor = 0xFF1E88E5;

  /// 把落盘的颜色还原成不透明色；越界值回落到默认色。
  static Color resolve(int? argb) {
    if (argb == null) return const Color(defaultColor);
    return Color(argb).withValues(alpha: 1);
  }
}

/// 用户自建的日程（与教务课程完全独立）。
///
/// 时间精确到分钟，保存的是本地时间；跨零点由编辑页拦截，不在这里纠正。
@immutable
class CustomScheduleEvent {
  const CustomScheduleEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.note = '',
    this.colorArgb = ScheduleColors.defaultColor,
    this.repeat = ScheduleRepeat.none,
    this.repeatUntil,
    this.weeks = const <int>[],
  });

  final String id;
  final String title;
  final String location;
  final String note;

  /// 首次发生的开始 / 结束时间（含时分）。
  final DateTime start;
  final DateTime end;

  /// ARGB 颜色值，见 [ScheduleColors]。
  final int colorArgb;

  final ScheduleRepeat repeat;

  /// 重复的结束日期（含当天）；`null` 表示不设上限。
  final DateTime? repeatUntil;

  /// 「每周」重复时选中的教学周（1-based）；空列表表示不限制周次。
  ///
  /// 仅在能算出教学周（[firstDay] 可用）时生效，否则退化为按日期每 7 天重复。
  final List<int> weeks;

  Color get color => ScheduleColors.resolve(colorArgb);

  bool get isValid =>
      title.trim().isNotEmpty && !end.isBefore(start) && end != start;

  /// 是否跨天（结束时间落到次日）。
  bool get spansMidnight => scheduleDateOnly(end) != scheduleDateOnly(start);

  /// 单次时长（分钟）。
  int get durationMinutes => end.difference(start).inMinutes;

  /// 当天在时间轴上的开始 / 结束分钟（0–1440）。
  int get startMinuteOfDay => start.hour * 60 + start.minute;
  int get endMinuteOfDay => end.hour * 60 + end.minute;

  /// 该日程是否发生在 [day] 这一天（考虑重复规则）。
  ///
  /// [firstDay] 是学期第一天（`yyyy-MM-dd`），用于把日期换算成教学周；
  /// 缺失时「指定周次」退化为普通每周重复。
  bool occursOn(DateTime day, {String? firstDay}) {
    final DateTime target = scheduleDateOnly(day);
    final DateTime first = scheduleDateOnly(start);
    if (target.isBefore(first)) return false;

    final DateTime? until =
        repeatUntil == null ? null : scheduleDateOnly(repeatUntil!);
    if (until != null && target.isAfter(until)) return false;

    switch (repeat) {
      case ScheduleRepeat.none:
        return target == first;
      case ScheduleRepeat.daily:
        return true;
      case ScheduleRepeat.weekly:
        if (target.weekday != first.weekday) return false;
        if (weeks.isEmpty) return true;
        if (firstDay == null || firstDay.isEmpty) return true;
        final int? week = calculateSchoolWeekFromFirstDay(firstDay, target);
        // 算不出教学周（学期起始日损坏）时按普通每周处理，避免日程整段消失。
        if (week == null) return true;
        if (week <= 0) return false;
        return weeks.contains(week);
      case ScheduleRepeat.monthly:
        return target.day == first.day;
    }
  }

  /// 落在 `[from, to]`（含两端）内的所有发生日期。
  List<DateTime> occurrencesBetween(
    DateTime from,
    DateTime to, {
    String? firstDay,
  }) {
    final DateTime startDay = scheduleDateOnly(from);
    final DateTime endDay = scheduleDateOnly(to);
    if (endDay.isBefore(startDay)) return const <DateTime>[];

    final List<DateTime> result = <DateTime>[];
    DateTime cursor = startDay;
    while (!cursor.isAfter(endDay)) {
      if (occursOn(cursor, firstDay: firstDay)) result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  /// 重复规则的人话描述（详情页与编辑页共用）。
  String describeRepeat() {
    switch (repeat) {
      case ScheduleRepeat.none:
        return '不重复';
      case ScheduleRepeat.daily:
        return repeatUntil == null
            ? '每天'
            : '每天，至 ${scheduleFormatDate(repeatUntil!)}';
      case ScheduleRepeat.weekly:
        final String base =
            weeks.isEmpty
                ? '每周'
                : '第 ${(weeks.toList()..sort()).join('、')} 周';
        return repeatUntil == null
            ? base
            : '$base，至 ${scheduleFormatDate(repeatUntil!)}';
      case ScheduleRepeat.monthly:
        return repeatUntil == null
            ? '每月'
            : '每月，至 ${scheduleFormatDate(repeatUntil!)}';
    }
  }

  CustomScheduleEvent copyWith({
    String? id,
    String? title,
    String? location,
    String? note,
    DateTime? start,
    DateTime? end,
    int? colorArgb,
    ScheduleRepeat? repeat,
    Object? repeatUntil = _unset,
    List<int>? weeks,
  }) {
    return CustomScheduleEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      note: note ?? this.note,
      start: start ?? this.start,
      end: end ?? this.end,
      colorArgb: colorArgb ?? this.colorArgb,
      repeat: repeat ?? this.repeat,
      repeatUntil:
          identical(repeatUntil, _unset)
              ? this.repeatUntil
              : repeatUntil as DateTime?,
      weeks: weeks ?? this.weeks,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'location': location,
    'note': note,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'color': colorArgb,
    'repeat': repeat.name,
    'repeatUntil': repeatUntil?.millisecondsSinceEpoch,
    'weeks': weeks,
  };

  /// 解析单条日程；字段缺失或时间非法时返回 `null`（由调用方跳过该条）。
  static CustomScheduleEvent? tryFromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? title = json['title'];
    final Object? startValue = json['start'];
    final Object? endValue = json['end'];
    if (id is! String || title is! String) return null;
    if (startValue is! int || endValue is! int) return null;

    final DateTime start = DateTime.fromMillisecondsSinceEpoch(startValue);
    final DateTime end = DateTime.fromMillisecondsSinceEpoch(endValue);
    if (end.isBefore(start)) return null;

    final Object? untilValue = json['repeatUntil'];
    final Object? weeksValue = json['weeks'];
    final List<int> weeks =
        weeksValue is List
            ? weeksValue.whereType<int>().where((int w) => w > 0).toList()
            : const <int>[];

    return CustomScheduleEvent(
      id: id,
      title: title,
      location: json['location'] is String ? json['location'] as String : '',
      note: json['note'] is String ? json['note'] as String : '',
      start: start,
      end: end,
      colorArgb:
          json['color'] is int
              ? json['color'] as int
              : ScheduleColors.defaultColor,
      repeat: ScheduleRepeat.parse(json['repeat'] as String?),
      repeatUntil:
          untilValue is int
              ? DateTime.fromMillisecondsSinceEpoch(untilValue)
              : null,
      weeks: weeks,
    );
  }

  static const Object _unset = Object();
}

/// `2026-11-03` 形式的日期文本（重复规则描述用）。
String scheduleFormatDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
