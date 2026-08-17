import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme preferences use Material You defaults', () async {
    final controller = ThemeController();

    await controller.load();

    expect(controller.themeMode.value, ThemeMode.system);
    expect(controller.useDynamicColor.value, isTrue);
    expect(controller.preset.value, AppThemePreset.indigo);
  });

  test('persisted theme preferences are restored', () async {
    SharedPreferences.setMockInitialValues({
      'appThemeMode': ThemeMode.dark.name,
      'appUseDynamicColor': false,
      'appThemePreset': AppThemePreset.rose.name,
    });
    final controller = ThemeController();

    await controller.load();

    expect(controller.themeMode.value, ThemeMode.dark);
    expect(controller.useDynamicColor.value, isFalse);
    expect(controller.preset.value, AppThemePreset.rose);
  });

  test('selecting a preset disables dynamic color and persists it', () async {
    final controller = ThemeController();
    await controller.load();

    await controller.selectPreset(AppThemePreset.teal);

    final prefs = await SharedPreferences.getInstance();
    expect(controller.preset.value, AppThemePreset.teal);
    expect(controller.useDynamicColor.value, isFalse);
    expect(prefs.getString('appThemePreset'), AppThemePreset.teal.name);
    expect(prefs.getBool('appUseDynamicColor'), isFalse);
  });

  test(
    'dynamic color is only enabled when system schemes are available',
    () async {
      final controller = ThemeController();
      await controller.load();
      await controller.selectPreset(AppThemePreset.orange);

      await controller.setDynamicColor(true);
      expect(controller.useDynamicColor.value, isFalse);

      controller.configureDynamicSchemes(
        AppTheme.presetScheme(AppThemePreset.blue, Brightness.light),
        AppTheme.presetScheme(AppThemePreset.blue, Brightness.dark),
      );
      await controller.setDynamicColor(true);
      expect(controller.useDynamicColor.value, isTrue);
    },
  );

  test('all presets produce light and dark M3 themes with semantic colors', () {
    for (final preset in AppThemePreset.values) {
      for (final brightness in Brightness.values) {
        final scheme = AppTheme.presetScheme(preset, brightness);
        final theme = AppTheme.fromScheme(scheme);

        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, brightness);
        expect(theme.extension<AppSemanticColors>(), isNotNull);
      }
    }
  });
}
