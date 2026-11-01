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

  test('glass tint defaults to the neutral midpoint and clamps on set', () async {
    final controller = ThemeController();
    await controller.load();
    expect(controller.glassTint.value, 0.5);

    await controller.setGlassTint(0.8);
    final prefs = await SharedPreferences.getInstance();
    expect(controller.glassTint.value, 0.8);
    expect(prefs.getDouble('appGlassTint'), 0.8);

    await controller.setGlassTint(2.4);
    expect(controller.glassTint.value, 1.0);

    await controller.setGlassTint(-3);
    expect(controller.glassTint.value, 0.0);
  });

  test('glass tint is restored from preferences', () async {
    SharedPreferences.setMockInitialValues({'appGlassTint': 0.25});
    final controller = ThemeController();
    await controller.load();
    expect(controller.glassTint.value, 0.25);
  });

  test('tintStrength drives tint opacity monotonically', () {
    final clear = AppGlassTheme(
      enabled: true,
      brightness: Brightness.light,
      tintStrength: 0,
    );
    final neutral = AppGlassTheme(
      enabled: true,
      brightness: Brightness.light,
      tintStrength: 0.5,
    );
    final tinted = AppGlassTheme(
      enabled: true,
      brightness: Brightness.light,
      tintStrength: 1,
    );

    expect(clear.tint.a, lessThan(neutral.tint.a));
    expect(neutral.tint.a, lessThan(tinted.tint.a));
    expect(clear.elevatedTint.a, lessThan(tinted.elevatedTint.a));
    expect(neutral.copyWith(tintStrength: 1).tint.a, tinted.tint.a);
    // 通透度是标量，lerp 时连续插值。
    expect(neutral.lerp(tinted, 0.5).tintStrength, closeTo(0.75, 0.001));
  });

  test('tintStrength 同时压低模糊：最透明一档几乎不模糊', () {
    final clear = AppGlassTheme(
      enabled: true,
      brightness: Brightness.light,
      tintStrength: 0,
    );
    final neutral = AppGlassTheme(
      enabled: true,
      brightness: Brightness.light,
      tintStrength: 0.5,
    );
    final tinted = AppGlassTheme(
      enabled: true,
      brightness: Brightness.light,
      tintStrength: 1,
    );

    // 透明端几乎不模糊，默认档等于基值，色调端更雾化。
    expect(clear.blurFor(4), lessThan(0.5));
    expect(neutral.blurFor(4), closeTo(4, 0.001));
    expect(tinted.blurFor(4), closeTo(7.2, 0.001));
    expect(clear.blurFor(6), lessThan(neutral.blurFor(6)));
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
