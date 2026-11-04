import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/settings/calendar_sync_page.dart';
import 'package:superhut/utils/course/calendar/calendar_gateway.dart';
import 'package:superhut/utils/course/calendar/calendar_sync_controller.dart';
import 'package:superhut/utils/course/coursemain.dart';

/// 以 Android 身份运行 [body]，并在返回前复位平台覆盖。
Future<void> _asAndroid(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const MaterialApp(home: CalendarSyncPage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryCalendarGateway gateway;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Get.deleteAll(force: true);
    gateway = InMemoryCalendarGateway();
    Get.put(
      CalendarSyncController(
        gateway: gateway,
        courseLoader: () async => const <String, List<Course>>{},
        scheduleProvider: () => const <Never>[],
      ),
    );
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('桌面端不提供日历同步入口', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(CalendarSyncPage.isAvailable, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('移动端显示同步开关与提醒设置', (WidgetTester tester) async {
    await _asAndroid(() async {
      expect(CalendarSyncPage.isAvailable, isTrue);

      await _pumpPage(tester);

      expect(find.text('日历同步'), findsOneWidget);
      expect(find.text('同步到系统日历'), findsOneWidget);
      expect(find.text('日历提醒'), findsOneWidget);
      expect(find.text('目标日历'), findsOneWidget);
      expect(find.text('立即同步'), findsOneWidget);
      // 未开启时按钮不可用。
      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '立即同步'),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('确认后开启同步会先申请权限再写入', (WidgetTester tester) async {
    await _asAndroid(() async {
      await _pumpPage(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('开启日历同步'), findsOneWidget);
      await tester.tap(find.text('开启'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(gateway.permissionRequests, greaterThanOrEqualTo(0));
      expect(Get.find<CalendarSyncController>().enabled, isTrue);
      expect(gateway.calendars, hasLength(1));
    });
  });
}
