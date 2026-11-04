import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeng_apm_sdk/src/event/router_event.dart';
import 'package:umeng_apm_sdk/src/recorder/page_perf_recorder.dart';
import 'package:umeng_apm_sdk/src/store/global.dart';

/// 回归测试：第三方组件原本用 `pageStack.remove(route)` 移除页面栈，
/// 但栈里存的是 `{'route': ..., 'pvId': ...}` 映射，永远匹配不到，
/// 导致被弹出的路由一直留在栈里（内存无上限增长 + 每帧全量扫描）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GlobalStore.singleInstance.setProperty(
      name: 'enableTrackingPagePerf',
      value: true,
    );
  });

  test('页面弹出后对应条目会真正从 pageStack 中移除', () {
    final PagePerfRecorder recorder = PagePerfRecorder();
    final Route<void> pushed = _timerFreeRoute();
    final Route<void> another = _timerFreeRoute();

    recorder.pageStack.add(<String, Object>{'route': pushed, 'pvId': 'pv-1'});
    recorder.pageStack.add(<String, Object>{'route': another, 'pvId': 'pv-2'});
    expect(recorder.pageStack.length, 2);

    recorder.onReceivedEvent(RouterEvent(RouterEventType.pop, pushed, null));

    expect(recorder.pageStack.length, 1);
    expect(recorder.pageStack.single['route'], same(another));
  });

  test('反复开关页面不会让 pageStack 无限增长', () {
    final PagePerfRecorder recorder = PagePerfRecorder();

    for (int i = 0; i < 50; i++) {
      final Route<void> route = _timerFreeRoute();
      recorder.pageStack.add(<String, Object>{'route': route, 'pvId': 'pv-$i'});
      recorder.onReceivedEvent(RouterEvent(RouterEventType.pop, route, null));
    }

    expect(recorder.pageStack, isEmpty);
  });
}

/// PageRouteBuilder 的 transitionDuration 是普通字段，不依赖 Navigator 是否挂载；
/// MaterialPageRoute 在未挂载取值时会因为内部 page 为空而抛异常。
PageRouteBuilder<void> _timerFreeRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}
