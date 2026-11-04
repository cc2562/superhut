import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_event_planner.dart';

/// 日历同步的全部持久化状态。
@immutable
class CalendarSyncSettings {
  const CalendarSyncSettings({
    this.enabled = false,
    this.reminderMinutes = CalendarSyncStore.defaultReminderMinutes,
    this.calendarId,
    this.lastSyncAtMillis,
    this.records = const <String, CalendarSyncRecord>{},
  });

  final bool enabled;
  final int reminderMinutes;
  final String? calendarId;
  final int? lastSyncAtMillis;

  /// 已写入日历的事件：key → 事件 id + 指纹。
  final Map<String, CalendarSyncRecord> records;

  int get syncedCount => records.length;

  CalendarSyncSettings copyWith({
    bool? enabled,
    int? reminderMinutes,
    Object? calendarId = _unset,
    Object? lastSyncAtMillis = _unset,
    Map<String, CalendarSyncRecord>? records,
  }) {
    return CalendarSyncSettings(
      enabled: enabled ?? this.enabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      calendarId:
          identical(calendarId, _unset)
              ? this.calendarId
              : calendarId as String?,
      lastSyncAtMillis:
          identical(lastSyncAtMillis, _unset)
              ? this.lastSyncAtMillis
              : lastSyncAtMillis as int?,
      records: records ?? this.records,
    );
  }

  static const Object _unset = Object();
}

/// 日历同步设置与簿记的读写（`SharedPreferences`）。
class CalendarSyncStore {
  const CalendarSyncStore();

  /// 系统日历里创建的专属日历名。
  static const String calendarName = '超级包菜课表';

  /// 专属日历的显示颜色（与主题主色一致）。
  static const int calendarColor = 0xFF3F51B5;

  static const int defaultReminderMinutes = 10;

  /// 可选提醒时间（分钟）；0 表示不提醒。
  static const List<int> reminderOptions = <int>[0, 5, 10, 15, 30, 60];

  static const String _enabledKey = 'calendarSync.enabled';
  static const String _reminderKey = 'calendarSync.reminderMinutes';
  static const String _calendarIdKey = 'calendarSync.calendarId';
  static const String _lastSyncKey = 'calendarSync.lastSyncAt';
  static const String _recordsKey = 'calendarSync.records';

  Future<CalendarSyncSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int reminder = prefs.getInt(_reminderKey) ?? defaultReminderMinutes;
    return CalendarSyncSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      reminderMinutes: reminderOptions.contains(reminder)
          ? reminder
          : defaultReminderMinutes,
      calendarId: prefs.getString(_calendarIdKey),
      lastSyncAtMillis: prefs.getInt(_lastSyncKey),
      records: _decodeRecords(prefs.getString(_recordsKey)),
    );
  }

  Future<void> saveEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> saveReminderMinutes(int minutes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderKey, minutes);
  }

  Future<void> saveCalendarId(String? calendarId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (calendarId == null || calendarId.isEmpty) {
      await prefs.remove(_calendarIdKey);
    } else {
      await prefs.setString(_calendarIdKey, calendarId);
    }
  }

  Future<void> saveAfterSync({
    required Map<String, CalendarSyncRecord> records,
    required int lastSyncAtMillis,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, _encodeRecords(records));
    await prefs.setInt(_lastSyncKey, lastSyncAtMillis);
  }

  Future<void> clearRecords() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
    await prefs.remove(_lastSyncKey);
  }

  String _encodeRecords(Map<String, CalendarSyncRecord> records) {
    return jsonEncode(<String, Object?>{
      for (final MapEntry<String, CalendarSyncRecord> entry in records.entries)
        entry.key: entry.value.toJson(),
    });
  }

  Map<String, CalendarSyncRecord> _decodeRecords(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <String, CalendarSyncRecord>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <String, CalendarSyncRecord>{};
      }
      final Map<String, CalendarSyncRecord> records =
          <String, CalendarSyncRecord>{};
      decoded.forEach((String key, Object? value) {
        final CalendarSyncRecord? record = CalendarSyncRecord.tryFromJson(value);
        if (record != null) records[key] = record;
      });
      return records;
    } catch (error) {
      debugPrint('读取日历同步簿记失败: $error');
      return const <String, CalendarSyncRecord>{};
    }
  }
}
