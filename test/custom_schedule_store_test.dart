import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/schedule/custom_schedule_event.dart';
import 'package:superhut/home/coursetable/schedule/custom_schedule_store.dart';

void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('custom_schedule_test');
    file = File('${tempDir.path}/custom_schedules.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('文件不存在时返回空列表', () async {
    final CustomScheduleStore store = CustomScheduleStore(file: file);
    expect(await store.load(), isEmpty);
  });

  test('保存后可完整读回', () async {
    final CustomScheduleStore store = CustomScheduleStore(file: file);
    final CustomScheduleEvent event = CustomScheduleEvent(
      id: 'a',
      title: '值班',
      start: DateTime(2025, 3, 5, 8, 0),
      end: DateTime(2025, 3, 5, 10, 0),
      repeat: ScheduleRepeat.weekly,
      weeks: const <int>[1, 2],
    );

    await store.save(<CustomScheduleEvent>[event]);
    final List<CustomScheduleEvent> loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, '值班');
    expect(loaded.single.weeks, <int>[1, 2]);
    // 临时文件不应残留。
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('损坏的 JSON 返回空列表且不删除原文件', () async {
    await file.writeAsString('{ not json');
    final CustomScheduleStore store = CustomScheduleStore(file: file);

    expect(await store.load(), isEmpty);
    expect(await file.exists(), isTrue);
  });

  test('单条脏数据被跳过，其余照常读出', () async {
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'events': <Object?>[
          <String, Object?>{
            'id': 'ok',
            'title': '正常',
            'start': DateTime(2025, 3, 5, 8).millisecondsSinceEpoch,
            'end': DateTime(2025, 3, 5, 9).millisecondsSinceEpoch,
          },
          <String, Object?>{'id': 'bad'},
        ],
      }),
    );
    final CustomScheduleStore store = CustomScheduleStore(file: file);

    final List<CustomScheduleEvent> loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'ok');
  });
}
