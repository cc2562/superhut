import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/glass/glass_theme.dart';
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

  test('liquid glass defaults to on but stays disabled under test', () async {
    final controller = ThemeController();
    await controller.load();

    expect(controller.useLiquidGlass.value, isTrue);
    // flutter_test 环境没有 shader 资源，始终回落到 Material 分支。
    expect(controller.liquidGlassSupported, isFalse);
    expect(controller.glassEnabled, isFalse);
    expect(controller.lightTheme.extension<AppGlassTheme>()?.enabled, isFalse);
  });

  test('liquid glass preference is restored and persisted', () async {
    SharedPreferences.setMockInitialValues({'appUseLiquidGlass': false});
    final controller = ThemeController();
    await controller.load();
    expect(controller.useLiquidGlass.value, isFalse);

    await controller.setLiquidGlass(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('appUseLiquidGlass'), isTrue);
  });

  test('AppGlassTheme carries neutral tokens and glass flag', () {
    final enabled = AppTheme.fromScheme(
      AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
      glassEnabled: true,
    );
    final extension = enabled.extension<AppGlassTheme>();

    expect(extension, isNotNull);
    expect(extension!.enabled, isTrue);
    expect(extension.isDark, isFalse);
    // 玻璃固定为中性白/黑，不跟随主题色相。
    expect(extension.tint.a, greaterThan(0));
    expect(extension.foreground, const Color(0xFF1B1B1F));

    final dark = AppGlassTheme(enabled: true, brightness: Brightness.dark);
    expect(dark.isDark, isTrue);
    expect(dark.foreground, const Color(0xFFF2F2F7));
    // lerp 不做样式插值，直接取一侧。
    expect(extension.lerp(dark, 0.2).brightness, Brightness.light);
    expect(extension.lerp(dark, 0.8).brightness, Brightness.dark);
  });
}
