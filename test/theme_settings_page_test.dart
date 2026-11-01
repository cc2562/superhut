import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/settings/theme_settings_page.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Get.deleteAll(force: true);
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
  });

  testWidgets('theme settings expose M3 controls and all presets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = Get.put(ThemeController());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: controller.lightTheme,
        home: const ThemeSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    for (final preset in AppThemePreset.values) {
      expect(find.text(preset.label), findsWidgets);
    }

    // 液态玻璃行：测试环境不支持玻璃，应说明原因并给出普通开关。
    expect(find.text('液态玻璃外观'), findsOneWidget);
    expect(find.text('当前平台不支持液态玻璃'), findsOneWidget);

    // 玻璃通透度：关闭玻璃时回落 Material Slider，说明文案常驻。
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('“透明” 更通透'), findsOneWidget);
  });

  testWidgets('通透度滑杆松手后提交到 controller', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = Get.put(ThemeController());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: controller.lightTheme,
        home: const ThemeSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider), const Offset(160, 0));
    await tester.pumpAndSettle();

    expect(controller.glassTint.value, greaterThan(0.5));
  });

  testWidgets('selecting a preset updates controller immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = Get.put(ThemeController());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: controller.lightTheme,
        home: const ThemeSettingsPage(),
      ),
    );
    await tester.tap(find.text('紫色').last);
    await tester.pump();

    expect(controller.preset.value, AppThemePreset.purple);
    expect(controller.useDynamicColor.value, isFalse);
  });
}
