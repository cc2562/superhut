import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 写入系统日历的一条事件载荷。
@immutable
class CalendarEventPayload {
  const CalendarEventPayload({
    required this.title,
    required this.startMillis,
    required this.endMillis,
    this.eventId,
    this.location = '',
    this.description = '',
    this.reminderMinutes = 0,
  });

  /// 已存在的事件 id；为空表示新建。
  final String? eventId;

  final String title;
  final String location;
  final String description;

  /// epoch 毫秒，原生侧按设备默认时区落库。
  final int startMillis;
  final int endMillis;

  /// 提前提醒分钟数；`<= 0` 表示不提醒。
  final int reminderMinutes;

  Map<String, Object?> toMap() => <String, Object?>{
    'eventId': eventId,
    'title': title,
    'location': location,
    'description': description,
    'startMillis': startMillis,
    'endMillis': endMillis,
    'reminderMinutes': reminderMinutes,
  };
}

/// 系统日历能力抽象。
///
/// 只暴露「写」：创建专属日历、写入 / 更新 / 删除本 App 的事件。
/// 不提供读取日历事件的能力，从接口层面保证单向同步。
abstract interface class CalendarGateway {
  /// 当前平台是否具备写入系统日历的能力。
  bool get isSupported;

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  /// 按名称查找或创建专属日历，返回日历 id；失败返回 `null`。
  Future<String?> ensureCalendar({required String name, required int color});

  /// 批量写入：返回与 [events] 等长的 id 列表，失败项为 `null`。
  Future<List<String?>> writeEvents({
    required String calendarId,
    required List<CalendarEventPayload> events,
  });

  /// 批量删除，返回成功删除的条数。
  Future<int> deleteEvents({required String calendarId, required List<String> eventIds});

  Future<bool> deleteCalendar(String calendarId);
}

/// 通过 MethodChannel 调用原生（Android CalendarContract / iOS EventKit）。
class MethodChannelCalendarGateway implements CalendarGateway {
  const MethodChannelCalendarGateway();

  static const MethodChannel _channel = MethodChannel(
    'com.superhut.rice.superhut/calendar_sync',
  );

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException catch (error) {
      debugPrint('日历权限查询失败: ${error.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException catch (error) {
      debugPrint('日历权限申请失败: ${error.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String?> ensureCalendar({
    required String name,
    required int color,
  }) async {
    if (!isSupported) return null;
    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'ensureCalendar',
        <String, Object?>{'name': name, 'color': color},
      );
      if (result == null) return null;
      return result.toString();
    } on PlatformException catch (error) {
      debugPrint('创建日历失败: ${error.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<List<String?>> writeEvents({
    required String calendarId,
    required List<CalendarEventPayload> events,
  }) async {
    if (!isSupported) return List<String?>.filled(events.length, null);
    try {
      final List<Object?>? result = await _channel.invokeListMethod<Object?>(
        'writeEvents',
        <String, Object?>{
          'calendarId': calendarId,
          'events': events.map((CalendarEventPayload event) => event.toMap()).toList(),
        },
      );
      if (result == null) return List<String?>.filled(events.length, null);
      return <String?>[
        for (int i = 0; i < events.length; i++)
          i < result.length && result[i] != null ? result[i].toString() : null,
      ];
    } on PlatformException catch (error) {
      debugPrint('写入日历失败: ${error.code}');
      return List<String?>.filled(events.length, null);
    } on MissingPluginException {
      return List<String?>.filled(events.length, null);
    }
  }

  @override
  Future<int> deleteEvents({
    required String calendarId,
    required List<String> eventIds,
  }) async {
    if (!isSupported || eventIds.isEmpty) return 0;
    try {
      return await _channel.invokeMethod<int>(
            'deleteEvents',
            <String, Object?>{'calendarId': calendarId, 'eventIds': eventIds},
          ) ??
          0;
    } on PlatformException catch (error) {
      debugPrint('删除日历事件失败: ${error.code}');
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  @override
  Future<bool> deleteCalendar(String calendarId) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'deleteCalendar',
            <String, Object?>{'calendarId': calendarId},
          ) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('删除日历失败: ${error.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// 内存实现：供单元测试与 widget 测试注入，不触碰任何系统能力。
class InMemoryCalendarGateway implements CalendarGateway {
  InMemoryCalendarGateway({
    this.supported = true,
    this.permissionGranted = true,
    this.failWrites = false,
    this.failDeletes = false,
  });

  final bool supported;

  bool permissionGranted;
  bool failWrites;

  /// 为 true 时删除全部失败：对应原生侧把异常吞掉、只返回 0 条的情况。
  bool failDeletes;

  /// [writeEvents] 的调用次数（含失败的那些），用于验证失败后是否重试。
  int writeCalls = 0;

  /// calendarId → 事件 id 列表。
  final Map<String, List<String>> calendars = <String, List<String>>{};
  final List<String> deletedEventIds = <String>[];
  final Map<String, String> _calendarIdsByName = <String, String>{};
  int permissionRequests = 0;
  int _nextId = 1;
  int _nextCalendarId = 1;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return permissionGranted;
  }

  @override
  Future<String?> ensureCalendar({
    required String name,
    required int color,
  }) async {
    final String? existing = _calendarIdsByName[name];
    if (existing != null && calendars.containsKey(existing)) return existing;

    final String id = 'calendar-${_nextCalendarId++}';
    _calendarIdsByName[name] = id;
    calendars[id] = <String>[];
    return id;
  }

  @override
  Future<List<String?>> writeEvents({
    required String calendarId,
    required List<CalendarEventPayload> events,
  }) async {
    writeCalls += 1;
    if (failWrites) {
      return List<String?>.filled(events.length, null);
    }
    if (!calendars.containsKey(calendarId)) {
      return List<String?>.filled(events.length, null);
    }
    final List<String> stored = calendars[calendarId]!;
    final List<String?> ids = <String?>[];
    for (final CalendarEventPayload event in events) {
      final String? existingId = event.eventId;
      if (existingId != null &&
          existingId.isNotEmpty &&
          stored.contains(existingId)) {
        ids.add(existingId);
        continue;
      }
      final String id = 'event-${_nextId++}';
      stored.add(id);
      ids.add(id);
    }
    return ids;
  }

  @override
  Future<int> deleteEvents({
    required String calendarId,
    required List<String> eventIds,
  }) async {
    if (failDeletes) return 0;
    deletedEventIds.addAll(eventIds);
    final List<String>? stored = calendars[calendarId];
    if (stored == null) return 0;
    int deleted = 0;
    for (final String id in eventIds) {
      if (stored.remove(id)) deleted += 1;
    }
    return deleted;
  }

  @override
  Future<bool> deleteCalendar(String calendarId) async {
    return calendars.remove(calendarId) != null;
  }
}
