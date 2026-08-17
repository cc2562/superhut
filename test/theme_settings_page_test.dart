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
