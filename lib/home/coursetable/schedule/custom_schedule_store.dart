import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'custom_schedule_event.dart';

/// 自定义日程的本地存储。
///
/// 刻意与 `course_data.json` 分文件：刷新教务课表会整体覆写课表文件，
/// 但绝不能碰用户自己排的日程。
class CustomScheduleStore {
  CustomScheduleStore({File? file}) : _file = file;

  /// 文件格式版本；后续字段变化时按版本迁移。
  static const int formatVersion = 1;

  static const String fileName = 'custom_schedules.json';

  /// 测试可注入的文件；为 `null` 时落到应用文档目录。
  final File? _file;

  Future<File> _resolveFile() async {
    final File? injected = _file;
    if (injected != null) return injected;
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// 读取全部日程；文件缺失或损坏时返回空列表（不会删除原文件）。
  Future<List<CustomScheduleEvent>> load() async {
    final File file = await _resolveFile();
    if (!await file.exists()) return const <CustomScheduleEvent>[];

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const <CustomScheduleEvent>[];
      final Object? rawEvents = decoded['events'];
      if (rawEvents is! List) return const <CustomScheduleEvent>[];

      final List<CustomScheduleEvent> events = <CustomScheduleEvent>[];
      for (final Object? raw in rawEvents) {
        if (raw is! Map) continue;
        final CustomScheduleEvent? event = CustomScheduleEvent.tryFromJson(
          Map<String, dynamic>.from(raw),
        );
        if (event != null) events.add(event);
      }
      return events;
    } catch (error) {
      debugPrint('读取自定义日程失败: $error');
      return const <CustomScheduleEvent>[];
    }
  }

  /// 整体写回。先写临时文件再改名，避免中途异常留下半个 JSON。
  Future<void> save(List<CustomScheduleEvent> events) async {
    final File file = await _resolveFile();
    final String payload = jsonEncode(<String, Object?>{
      'version': formatVersion,
      'events': events.map((CustomScheduleEvent e) => e.toJson()).toList(),
    });

    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(payload, flush: true);
    try {
      await temp.rename(file.path);
    } on FileSystemException {
      // Windows 语义下目标已存在时 rename 会失败：删掉目标再改名。
      // 此时数据已在临时文件里完整落盘，不会出现「写了一半」的中间态。
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    }
  }
}
