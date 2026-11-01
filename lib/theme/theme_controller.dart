import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends GetxController {
  static const _modeKey = 'appThemeMode';
  static const _dynamicKey = 'appUseDynamicColor';
  static const _presetKey = 'appThemePreset';
  static const _glassKey = 'appUseLiquidGlass';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool useDynamicColor = true.obs;
  final Rx<AppThemePreset> preset = AppThemePreset.indigo.obs;

  /// 「液态玻璃外观」开关，默认开启；仅在 Android / iOS 上生效。
  final RxBool useLiquidGlass = true.obs;

  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;

  bool get dynamicColorAvailable =>
      _dynamicLight != null && _dynamicDark != null;

  /// 当前平台是否支持液态玻璃（Impeller 实时背景 + 非测试环境）。
  bool get liquidGlassSupported {
    if (kIsWeb) return false;
    // flutter_test 里的 defaultTargetPlatform 同样是 android/iOS，
    // 但测试环境没有 shader 资源，玻璃只会退化成磨砂并引入动画，
    // 因此测试中一律走 Material 分支。
    if (Platform.environment['FLUTTER_TEST'] == 'true') return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// 实际是否渲染液态玻璃：开关打开且平台支持。
  bool get glassEnabled => useLiquidGlass.value && liquidGlassSupported;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = _parseThemeMode(prefs.getString(_modeKey));
    useDynamicColor.value = prefs.getBool(_dynamicKey) ?? true;
    preset.value = _parsePreset(prefs.getString(_presetKey));
    useLiquidGlass.value = prefs.getBool(_glassKey) ?? true;
  }

  void configureDynamicSchemes(ColorScheme? light, ColorScheme? dark) {
    _dynamicLight = light;
    _dynamicDark = dark;
  }

  ThemeData get lightTheme => AppTheme.fromScheme(
    useDynamicColor.value && _dynamicLight != null
        ? _dynamicLight!
        : AppTheme.presetScheme(preset.value, Brightness.light),
    glassEnabled: glassEnabled,
  );

  ThemeData get darkTheme => AppTheme.fromScheme(
    useDynamicColor.value && _dynamicDark != null
        ? _dynamicDark!
        : AppTheme.presetScheme(preset.value, Brightness.dark),
    glassEnabled: glassEnabled,
  );

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value.name);
  }

  Future<void> setDynamicColor(bool value) async {
    if (value && !dynamicColorAvailable) return;
    useDynamicColor.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dynamicKey, value);
  }

  Future<void> setLiquidGlass(bool value) async {
    useLiquidGlass.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassKey, value);
  }

  Future<void> selectPreset(AppThemePreset value) async {
    preset.value = value;
    useDynamicColor.value = false;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_presetKey, value.name),
      prefs.setBool(_dynamicKey, false),
    ]);
  }

  static ThemeMode _parseThemeMode(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  static AppThemePreset _parsePreset(String? value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => AppThemePreset.indigo,
    );
  }
}
