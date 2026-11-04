import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/analytics/umeng_event_tracker.dart';
import 'package:superhut/analytics/umeng_service.dart';

void main() {
  setUp(UmengService.resetForTest);

  test('测试环境不初始化友盟，避免污染 widget 测试', () async {
    expect(UmengService.isSupportedPlatform, isFalse);
    expect(await UmengService.start(), isFalse);
    expect(UmengService.isStarted, isFalse);
  });

  test('撤回同意后不再发起初始化', () async {
    await UmengService.withdraw();
    expect(UmengService.isRevoked, isTrue);
    expect(await UmengService.start(), isFalse);
    expect(await UmengService.enable(), isFalse);
    expect(UmengService.isStarted, isFalse);
  });

  test('未初始化时上报事件直接返回 false，不抛异常', () {
    expect(UmengEventTracker.track('unit_test_event'), isFalse);
    expect(
      UmengEventTracker.track(
        'unit_test_event',
        <String, Object?>{'from': 'test'},
      ),
      isFalse,
    );
  });

  test('空事件名被拒绝', () {
    expect(UmengEventTracker.track('   '), isFalse);
  });

  test('未初始化时转发未捕获异常不抛异常，也不上报', () {
    expect(
      () => UmengService.reportUncaughtError(
        StateError('未捕获的异步错误'),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('撤回同意后转发未捕获异常同样被丢弃', () async {
    await UmengService.withdraw();
    expect(
      () => UmengService.reportUncaughtError(
        Exception('撤回后产生的错误'),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });
}
