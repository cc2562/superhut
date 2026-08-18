import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends GetxController {
  static const _modeKey = 'appThemeMode';
  static const _dynamicKey = 'appUseDynamicColor';
  static const _presetKey = 'appThemePreset';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool useDynamicColor = true.obs;
  final Rx<AppThemePreset> preset = AppThemePreset.indigo.obs;

  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;

  bool get dynamicColorAvailable =>
      _dynamicLight != null && _dynamicDark != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = _parseThemeMode(prefs.getString(_modeKey));
    useDynamicColor.value = prefs.getBool(_dynamicKey) ?? true;
    preset.value = _parsePreset(prefs.getString(_presetKey));
  }

  void configureDynamicSchemes(ColorScheme? light, ColorScheme? dark) {
    _dynamicLight = light;
    _dynamicDark = dark;
  }

  ThemeData get lightTheme => AppTheme.fromScheme(
    useDynamicColor.value && _dynamicLight != null
        ? _dynamicLight!
        : AppTheme.presetScheme(preset.value, Brightness.light),
  );

  ThemeData get darkTheme => AppTheme.fromScheme(
    useDynamicColor.value && _dynamicDark != null
        ? _dynamicDark!
        : AppTheme.presetScheme(preset.value, Brightness.dark),
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
