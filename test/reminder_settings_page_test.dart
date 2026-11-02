import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/live_activity/class_live_activity_controller.dart';
import 'package:superhut/live_activity/class_live_activity_service.dart';
import 'package:superhut/pages/settings/reminder_settings_page.dart';
import 'package:superhut/utils/course/coursemain.dart';

const MethodChannel _channel = MethodChannel('com.zhiquxy.rice/live_activity');

/// 记录 Dart -> 原生的调用，并按需伪造「系统是否允许实时活动」。
List<MethodCall> _mockNative({required bool authorized}) {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
        calls.add(call);
        if (call.method == 'isSupported') return authorized;
        return true;
      });
  return calls;
}

/// 注入空课表：测试不该去读 path_provider，否则异步调用会一直挂住。
ClassLiveActivityController _controller() {
  return Get.put(
    ClassLiveActivityController(
      scheduleLoader: () async => const <String, List<Course>>{},
    ),
  );
}

/// 以 iOS 平台运行 [body]，并在结束前复位平台覆盖。
///
/// `testWidgets` 会在测试体外层校验 foundation 的 debug 变量，
/// 覆盖值必须在测试体返回前清掉，否则会报「debug variable was changed」。
Future<void> _asIos(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const MaterialApp(home: ReminderSettingsPage()));
  // 页面没有动画：固定 pump 两帧即可。pumpAndSettle 会等到「没有新帧」为止，
  // 一旦将来出现重复定时器就会无限循环，把整个测试套件拖住。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Get.deleteAll(force: true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
    await Get.deleteAll(force: true);
  });

  test('只有 iOS 认为具备实时活动能力', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ReminderSettingsPage.isAvailable, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(ReminderSettingsPage.isAvailable, isTrue);
  });

  test('Android 上不探测原生能力，保持「不支持」', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final List<MethodCall> calls = _mockNative(authorized: true);
    final ClassLiveActivityController controller = _controller();

    await controller.load();

    expect(controller.platformSupported, isFalse);
    expect(controller.systemSupported, isFalse);
    expect(ClassLiveActivityService.isPlatformSupported, isFalse);
    expect(calls, isEmpty);
  });

  testWidgets('iOS 上默认开启，关闭后立即持久化', (tester) async {
    await _asIos(() async {
      _mockNative(authorized: true);
      final ClassLiveActivityController controller = _controller();
      await controller.load();

      await _pumpPage(tester);

      expect(find.text('提醒设置'), findsOneWidget);
      expect(find.text('灵动岛课程提醒'), findsOneWidget);
      expect(find.text('课前 10 分钟显示倒计时与上课信息'), findsOneWidget);
      expect(controller.enabled, isTrue);

      final Switch beforeToggle = tester.widget<Switch>(find.byType(Switch));
      expect(beforeToggle.value, isTrue);
      expect(beforeToggle.onChanged, isNotNull);

      // 整行可点：点标题也能切换。
      await tester.tap(find.text('灵动岛课程提醒'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.enabled, isFalse);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ClassLiveActivityController.enabledKey), isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  testWidgets('系统未授权时开关置灰并提示去系统设置', (tester) async {
    await _asIos(() async {
      _mockNative(authorized: false);
      final ClassLiveActivityController controller = _controller();
      await controller.load();

      await _pumpPage(tester);

      expect(controller.systemSupported, isFalse);
      expect(find.text('系统未允许「实时活动」，请到「设置 > 超级包菜」中开启'), findsOneWidget);

      final Switch toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.onChanged, isNull);

      // 置灰时点击整行也不应改变状态。
      await tester.tap(find.text('灵动岛课程提醒'));
      await tester.pump();
      expect(controller.enabled, isTrue);
    });
  });
}
